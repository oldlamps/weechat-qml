pub mod client;
pub mod parser;
pub mod transport;
pub mod types;

#[cfg(test)]
mod integration_tests {
    use super::client::{ClientCommand, ConnectionConfig, RelayEvent, run_relay_session};
    use super::parser::FrameBuilder;
    use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
    use tokio::net::TcpListener;
    use tokio::sync::mpsc;

    #[tokio::test]
    async fn test_mock_weechat_tcp_relay_handshake_and_sync() {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();

        // Spawn an in-process mock WeeChat Relay TCP server
        let server_task = tokio::spawn(async move {
            let (socket, _) = listener.accept().await.unwrap();
            let (read_half, mut write_half) = tokio::io::split(socket);
            let mut reader = BufReader::new(read_half);
            let mut line = String::new();

            // 1. Read handshake command
            reader.read_line(&mut line).await.unwrap();
            assert!(line.contains("handshake"));

            // Reply with handshake hashtable (sha256 + nonce)
            let mut hs = FrameBuilder::new("handshake");
            hs.write_tag(b"htb");
            hs.write_tag(b"str");
            hs.write_tag(b"str");
            hs.write_i32(3);
            hs.write_str_raw(Some("password_hash_algo"));
            hs.write_str_raw(Some("sha256"));
            hs.write_str_raw(Some("nonce"));
            hs.write_str_raw(Some("01020304"));
            hs.write_str_raw(Some("compression"));
            hs.write_str_raw(Some("zstd"));
            write_half.write_all(&hs.finish_zstd()).await.unwrap();

            // 2. Read init and version commands
            line.clear();
            reader.read_line(&mut line).await.unwrap();
            assert!(line.starts_with("init password_hash=sha256:01020304"));

            line.clear();
            reader.read_line(&mut line).await.unwrap();
            assert!(line.contains("(version) info version"));

            let mut ver = FrameBuilder::new("version");
            ver.add_info("version", "4.4.2");
            write_half.write_all(&ver.finish_zstd()).await.unwrap();

            // 3. Read listbuffers, hotlist, nicklist, sync
            for _ in 0..4 {
                line.clear();
                reader.read_line(&mut line).await.unwrap();
            }

            // Send a buffer list frame
            let mut bufs = FrameBuilder::new("listbuffers");
            bufs.write_tag(b"hda");
            bufs.write_str_raw(Some("buffer"));
            bufs.write_str_raw(Some(
                "number:int,full_name:str,short_name:str,title:str,notify:int,local_variables:htb",
            ));
            bufs.write_i32(1);
            bufs.write_ptr_raw("0x112233");
            bufs.write_i32(1);
            bufs.write_str_raw(Some("irc.libera.#rust"));
            bufs.write_str_raw(Some("#rust"));
            bufs.write_str_raw(Some("Welcome to #rust"));
            bufs.write_i32(3);
            bufs.write_tag(b"str");
            bufs.write_tag(b"str");
            bufs.write_i32(2);
            bufs.write_str_raw(Some("type"));
            bufs.write_str_raw(Some("channel"));
            bufs.write_str_raw(Some("server"));
            bufs.write_str_raw(Some("libera"));
            write_half.write_all(&bufs.finish_zstd()).await.unwrap();

            // Send a live _buffer_line_added event
            let mut live_line = FrameBuilder::new("_buffer_line_added");
            live_line.write_tag(b"hda");
            live_line.write_str_raw(Some("line_data"));
            live_line.write_str_raw(Some("buffer:ptr,date:tim,displayed:chr,prefix:str,message:str,highlight:chr,notify_level:int"));
            live_line.write_i32(1);
            live_line.write_ptr_raw("0x998877");
            live_line.write_ptr_raw("0x112233");
            live_line.write_short_ascii("1729368000");
            live_line.write_u8(1);
            live_line.write_str_raw(Some("ferris"));
            live_line.write_str_raw(Some("Hello from native TCP relay!"));
            live_line.write_u8(1);
            live_line.write_i32(2);
            write_half
                .write_all(&live_line.finish_zstd())
                .await
                .unwrap();
        });

        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel();
        let (event_tx, mut event_rx) = mpsc::unbounded_channel();

        let config = ConnectionConfig {
            host: "127.0.0.1".to_string(),
            port,
            password: "secret".to_string(),
            use_tls: false,
            verify_tls: false,
            totp: String::new(),
            initial_lines: 50,
        };

        let client_task = tokio::spawn(async move {
            let _ = run_relay_session(config, cmd_rx, event_tx).await;
        });

        let mut got_connected = false;
        let mut got_buffers = false;
        let mut got_live_line = false;

        while let Some(ev) = event_rx.recv().await {
            match ev {
                RelayEvent::Connected { version } => {
                    assert_eq!(version, "4.4.2");
                    got_connected = true;
                }
                RelayEvent::BuffersListed(buffers) => {
                    assert_eq!(buffers.len(), 1);
                    assert_eq!(buffers[0].short_name, "#rust");
                    got_buffers = true;
                }
                RelayEvent::LineAdded(line) => {
                    assert_eq!(line.message, "Hello from native TCP relay!");
                    assert!(line.highlight);
                    got_live_line = true;
                    let _ = cmd_tx.send(ClientCommand::Disconnect);
                    break;
                }
                _ => {}
            }
        }

        assert!(got_connected);
        assert!(got_buffers);
        assert!(got_live_line);

        let _ = server_task.await;
        let _ = client_task.await;
    }
}
