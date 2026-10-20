use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context as TaskContext, Poll};

use anyhow::{Context, Result, bail};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, ReadBuf};
use tokio::net::TcpStream;
use tokio_rustls::TlsConnector;
use tokio_rustls::client::TlsStream;
use tokio_rustls::rustls::client::danger::{
    HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier,
};
use tokio_rustls::rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use tokio_rustls::rustls::{ClientConfig, DigitallySignedStruct, RootCertStore, SignatureScheme};

use super::parser::parse_frame;
use super::types::RelayMessage;

/// Native socket stream supporting direct TCP and TLS connections to WeeChat Relay.
pub enum RelayStream {
    Plain(TcpStream),
    Tls(Box<TlsStream<TcpStream>>),
}

impl AsyncRead for RelayStream {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut TaskContext<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<std::io::Result<()>> {
        match self.get_mut() {
            RelayStream::Plain(s) => Pin::new(s).poll_read(cx, buf),
            RelayStream::Tls(s) => Pin::new(s).poll_read(cx, buf),
        }
    }
}

impl AsyncWrite for RelayStream {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut TaskContext<'_>,
        buf: &[u8],
    ) -> Poll<std::io::Result<usize>> {
        match self.get_mut() {
            RelayStream::Plain(s) => Pin::new(s).poll_write(cx, buf),
            RelayStream::Tls(s) => Pin::new(s).poll_write(cx, buf),
        }
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut TaskContext<'_>) -> Poll<std::io::Result<()>> {
        match self.get_mut() {
            RelayStream::Plain(s) => Pin::new(s).poll_flush(cx),
            RelayStream::Tls(s) => Pin::new(s).poll_flush(cx),
        }
    }

    fn poll_shutdown(self: Pin<&mut Self>, cx: &mut TaskContext<'_>) -> Poll<std::io::Result<()>> {
        match self.get_mut() {
            RelayStream::Plain(s) => Pin::new(s).poll_shutdown(cx),
            RelayStream::Tls(s) => Pin::new(s).poll_shutdown(cx),
        }
    }
}

/// Custom certificate verifier when the user connects to a self-signed WeeChat TLS relay.
#[derive(Debug)]
struct NoCertificateVerification;

impl ServerCertVerifier for NoCertificateVerification {
    fn verify_server_cert(
        &self,
        _end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> std::result::Result<ServerCertVerified, tokio_rustls::rustls::Error> {
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, tokio_rustls::rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, tokio_rustls::rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![
            SignatureScheme::RSA_PKCS1_SHA256,
            SignatureScheme::RSA_PKCS1_SHA384,
            SignatureScheme::RSA_PKCS1_SHA512,
            SignatureScheme::ECDSA_NISTP256_SHA256,
            SignatureScheme::ECDSA_NISTP384_SHA384,
            SignatureScheme::ECDSA_NISTP521_SHA512,
            SignatureScheme::RSA_PSS_SHA256,
            SignatureScheme::RSA_PSS_SHA384,
            SignatureScheme::RSA_PSS_SHA512,
            SignatureScheme::ED25519,
        ]
    }
}

impl RelayStream {
    pub async fn connect(host: &str, port: u16, use_tls: bool, verify_tls: bool) -> Result<Self> {
        let addr = format!("{}:{}", host, port);
        let tcp = TcpStream::connect(&addr)
            .await
            .with_context(|| format!("Failed to connect TCP socket to {}", addr))?;
        let _ = tcp.set_nodelay(true);

        if !use_tls {
            return Ok(RelayStream::Plain(tcp));
        }

        let _ = tokio_rustls::rustls::crypto::aws_lc_rs::default_provider().install_default();

        let config = if verify_tls {
            let mut root_store = RootCertStore::empty();
            let native_certs = rustls_native_certs::load_native_certs();
            for cert in native_certs.certs {
                let _ = root_store.add(cert);
            }
            ClientConfig::builder()
                .with_root_certificates(root_store)
                .with_no_client_auth()
        } else {
            ClientConfig::builder()
                .dangerous()
                .with_custom_certificate_verifier(Arc::new(NoCertificateVerification))
                .with_no_client_auth()
        };

        let connector = TlsConnector::from(Arc::new(config));
        let server_name = ServerName::try_from(host.to_string())
            .unwrap_or_else(|_| ServerName::try_from("localhost".to_string()).unwrap());

        let tls_stream = connector
            .connect(server_name, tcp)
            .await
            .with_context(|| format!("TLS handshake failed with {}", addr))?;

        Ok(RelayStream::Tls(Box::new(tls_stream)))
    }
}

/// Reads a single binary WeeChat Relay frame from an async reader and parses it.
pub async fn read_relay_message<R: AsyncRead + Unpin>(reader: &mut R) -> Result<RelayMessage> {
    let mut len_bytes = [0u8; 4];
    reader
        .read_exact(&mut len_bytes)
        .await
        .context("Connection closed or failed reading frame length")?;

    let total_len = u32::from_be_bytes(len_bytes) as usize;
    if !(5..=64 * 1024 * 1024).contains(&total_len) {
        bail!("Invalid WeeChat Relay frame size: {} bytes", total_len);
    }

    let mut frame = vec![0u8; total_len];
    frame[..4].copy_from_slice(&len_bytes);
    reader
        .read_exact(&mut frame[4..])
        .await
        .context("Failed reading relay frame body")?;

    parse_frame(&frame)
}

/// Writes a newline-terminated WeeChat Relay command to an async writer.
pub async fn write_relay_command<W: AsyncWrite + Unpin>(writer: &mut W, cmd: &str) -> Result<()> {
    let line = if cmd.ends_with('\n') {
        cmd.to_string()
    } else {
        format!("{}\n", cmd)
    };
    writer
        .write_all(line.as_bytes())
        .await
        .context("Failed writing command to relay socket")?;
    writer
        .flush()
        .await
        .context("Failed flushing relay socket")?;
    Ok(())
}
