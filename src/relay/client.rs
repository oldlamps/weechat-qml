use std::collections::HashMap;
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use pbkdf2::pbkdf2_hmac;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256, Sha512};
use tokio::sync::mpsc;

use super::transport::{RelayStream, read_relay_message, write_relay_command};
use super::types::{HdataObject, RelayMessage, RelayValue};

#[derive(Debug, Clone)]
pub struct ConnectionConfig {
    pub host: String,
    pub port: u16,
    pub password: String,
    pub use_tls: bool,
    pub verify_tls: bool,
    pub totp: String,
    pub initial_lines: usize,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct RelayBuffer {
    pub ptr: String,
    pub number: i32,
    pub full_name: String,
    pub short_name: String,
    pub server_name: String,
    pub buffer_type: String, // "server", "channel", "private", "core"
    pub title: String,
    pub notify_level: i32,
    pub local_vars: HashMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct RelayLine {
    pub buffer_ptr: String,
    pub line_ptr: String,
    pub timestamp: i64,
    pub displayed: bool,
    pub prefix: String,
    pub message: String,
    pub highlight: bool,
    pub notify_level: i32,
    pub tags: Vec<String>,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct RelayNick {
    pub buffer_ptr: String,
    pub group_name: String,
    pub name: String,
    pub prefix: String,
    pub color: String,
    pub visible: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RelayFilter {
    pub name: String,
    pub buffer: String,
    pub tags: String,
    pub regex: String,
    pub enabled: bool,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct RelayNickDiff {
    pub buffer_ptr: String,
    pub diff_op: char, // '+', '-', '*'
    pub nick: RelayNick,
}

/// Commands sent from the UI/Bridge thread to the async WeeChat Relay task.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub enum ClientCommand {
    SendInput { buffer_ptr: String, text: String },
    FetchBufferLines { buffer_ptr: String, count: usize },
    MarkBufferRead { buffer_ptr: String },
    RequestNicklist { buffer_ptr: Option<String> },
    RequestFilters,
    Ping,
    Disconnect,
}

/// Events emitted by the async WeeChat Relay task back to the UI/Bridge thread.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub enum RelayEvent {
    StateChanged {
        state: String,
        detail: String,
    },
    Connected {
        version: String,
    },
    Error(String),
    BuffersListed(Vec<RelayBuffer>),
    HotlistUpdated(HashMap<String, (i32, i32)>), // buffer_ptr -> (unread_count, highlight_count)
    FiltersFetched(Vec<RelayFilter>),
    BufferLinesFetched {
        buffer_ptr: String,
        lines: Vec<RelayLine>,
        prepend: bool,
    },
    LineAdded(RelayLine),
    BufferOpened(RelayBuffer),
    BufferUpdated(RelayBuffer),
    BufferMoved {
        buffer_ptr: String,
        number: i32,
    },
    BufferRenamed {
        buffer_ptr: String,
        full_name: String,
        short_name: String,
    },
    BufferLocalVarsUpdated {
        buffer_ptr: String,
        local_vars: HashMap<String, String>,
    },
    BufferTitleChanged {
        buffer_ptr: String,
        title: String,
    },
    BufferCleared {
        buffer_ptr: String,
    },
    BufferClosed {
        buffer_ptr: String,
        full_name: String,
    },
    NicklistFull {
        buffer_ptr: String,
        nicks: Vec<RelayNick>,
    },
    NicklistDiff {
        buffer_ptr: String,
        diffs: Vec<RelayNickDiff>,
    },
    Pong {
        latency_ms: i32,
    },
}

/// Computes the WeeChat `init` command authentication string based on the server's `(handshake)` response.
pub fn build_auth_init_command(
    password: &str,
    totp: &str,
    handshake_attrs: &HashMap<String, String>,
) -> String {
    let algo = handshake_attrs
        .get("password_hash_algo")
        .map(|s| s.as_str())
        .unwrap_or("plain");
    let server_nonce_hex = handshake_attrs
        .get("nonce")
        .map(|s| s.as_str())
        .unwrap_or("");
    let iterations: u32 = handshake_attrs
        .get("password_hash_iterations")
        .and_then(|s| s.parse().ok())
        .unwrap_or(100_000);

    let mut params = Vec::new();

    if !server_nonce_hex.is_empty()
        && (algo.starts_with("pbkdf2+") || algo == "sha512" || algo == "sha256")
    {
        // Generate a 16-character (8 bytes) random hex client nonce
        let client_nonce_bytes: [u8; 8] = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos().to_be_bytes()[..8].try_into().unwrap())
            .unwrap_or([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]);
        let client_nonce_hex = hex::encode(client_nonce_bytes);

        // WeeChat requires salt = server_nonce + client_nonce in hex
        let salt_hex = format!("{}{}", server_nonce_hex, client_nonce_hex);

        // WeeChat base16-decodes salt_hex to raw bytes before hashing
        let salt_bytes = hex::decode(&salt_hex).unwrap_or_else(|_| salt_hex.as_bytes().to_vec());

        if algo == "pbkdf2+sha512" {
            let mut out = [0u8; 64];
            pbkdf2_hmac::<Sha512>(password.as_bytes(), &salt_bytes, iterations, &mut out);
            params.push(format!(
                "password_hash=pbkdf2+sha512:{}:{}:{}",
                salt_hex,
                iterations,
                hex::encode(out)
            ));
        } else if algo == "pbkdf2+sha256" {
            let mut out = [0u8; 32];
            pbkdf2_hmac::<Sha256>(password.as_bytes(), &salt_bytes, iterations, &mut out);
            params.push(format!(
                "password_hash=pbkdf2+sha256:{}:{}:{}",
                salt_hex,
                iterations,
                hex::encode(out)
            ));
        } else if algo == "sha512" {
            let mut hasher = Sha512::new();
            hasher.update(&salt_bytes);
            hasher.update(password.as_bytes());
            let digest = hasher.finalize();
            params.push(format!(
                "password_hash=sha512:{}:{}",
                salt_hex,
                hex::encode(digest)
            ));
        } else if algo == "sha256" {
            let mut hasher = Sha256::new();
            hasher.update(&salt_bytes);
            hasher.update(password.as_bytes());
            let digest = hasher.finalize();
            params.push(format!(
                "password_hash=sha256:{}:{}",
                salt_hex,
                hex::encode(digest)
            ));
        }
    }

    if params.is_empty() {
        let escaped = password.replace('\\', "\\\\").replace(',', "\\,");
        params.push(format!("password={}", escaped));
        if !handshake_attrs.contains_key("compression") {
            params.push("compression=zstd".to_string());
        }
    }

    if !totp.trim().is_empty() {
        params.push(format!("totp={}", totp.trim()));
    }

    format!("init {}", params.join(","))
}

/// Runs the full WeeChat Relay client session loop over a native TCP/TLS socket.
pub async fn run_relay_session(
    config: ConnectionConfig,
    mut cmd_rx: mpsc::UnboundedReceiver<ClientCommand>,
    event_tx: mpsc::UnboundedSender<RelayEvent>,
) -> Result<()> {
    let _ = event_tx.send(RelayEvent::StateChanged {
        state: "Connecting".to_string(),
        detail: format!(
            "Connecting to {}:{} ({})...",
            config.host,
            config.port,
            if config.use_tls { "TLS" } else { "TCP" }
        ),
    });

    let mut stream =
        RelayStream::connect(&config.host, config.port, config.use_tls, config.verify_tls).await?;

    let _ = event_tx.send(RelayEvent::StateChanged {
        state: "Authenticating".to_string(),
        detail: "Negotiating WeeChat handshake...".to_string(),
    });

    // Step 1: Send modern handshake
    write_relay_command(
        &mut stream,
        "(handshake) handshake password_hash_algo=pbkdf2+sha512:pbkdf2+sha256:sha512:sha256:plain,compression=zstd:zlib",
    )
    .await?;

    // Wait briefly for handshake response; if server is older and doesn't reply immediately, fallback
    let handshake_msg =
        tokio::time::timeout(Duration::from_secs(4), read_relay_message(&mut stream))
            .await
            .context("Timed out waiting for WeeChat relay handshake response")??;

    let mut handshake_attrs = HashMap::new();
    if handshake_msg.id == "handshake"
        && let Some(first) = handshake_msg.objects.first()
    {
        handshake_attrs = first.as_string_map();
    }

    // Step 2: Send init authentication command + version query
    let init_cmd = build_auth_init_command(&config.password, &config.totp, &handshake_attrs);
    write_relay_command(&mut stream, &init_cmd).await?;
    write_relay_command(&mut stream, "(version) info version").await?;

    // Step 3: Read version response to verify authentication succeeded
    let ver_msg = tokio::time::timeout(Duration::from_secs(5), read_relay_message(&mut stream))
        .await
        .context("Authentication failed or connection closed by WeeChat relay")??;

    let mut version = "WeeChat".to_string();
    for obj in &ver_msg.objects {
        if let RelayValue::Info(k, v) = obj
            && k == "version"
        {
            version = v.clone();
        }
    }

    let _ = event_tx.send(RelayEvent::StateChanged {
        state: "Synchronizing".to_string(),
        detail: format!("Authenticated with WeeChat {}. Syncing buffers...", version),
    });

    // Step 4: Request buffer list, hotlist, nicklists, and start live sync
    write_relay_command(
        &mut stream,
        "(listbuffers) hdata buffer:gui_buffers(*) number,full_name,short_name,type,nicklist,title,local_variables,notify",
    )
    .await?;
    write_relay_command(
        &mut stream,
        "(hotlist) hdata hotlist:gui_hotlist(*) buffer,count",
    )
    .await?;
    write_relay_command(&mut stream, "(filters) infolist filter").await?;
    write_relay_command(&mut stream, "(nicklist) nicklist").await?;
    write_relay_command(&mut stream, "sync *").await?;

    let _ = event_tx.send(RelayEvent::Connected { version });

    let mut last_ping_sent: Option<Instant> = None;
    let mut ping_interval = tokio::time::interval(Duration::from_secs(30));
    ping_interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
    // consume initial tick
    ping_interval.tick().await;

    loop {
        tokio::select! {
            incoming = read_relay_message(&mut stream) => {
                let msg = incoming?;
                handle_incoming_message(msg, &mut stream, &config, &event_tx, &mut last_ping_sent).await?;
            }
            Some(cmd) = cmd_rx.recv() => {
                match cmd {
                    ClientCommand::SendInput { buffer_ptr, text } => {
                        for line in text.lines() {
                            if !line.is_empty() {
                                let wire = format!("input {} {}", buffer_ptr, line);
                                write_relay_command(&mut stream, &wire).await?;
                            }
                        }
                    }
                    ClientCommand::FetchBufferLines { buffer_ptr, count } => {
                        let wire = format!(
                            "(lines:{}) hdata buffer:{}/own_lines/last_line(-{})/data date,displayed,prefix,message,highlight,notify_level,tags_array",
                            buffer_ptr, buffer_ptr, count
                        );
                        write_relay_command(&mut stream, &wire).await?;
                    }
                    ClientCommand::MarkBufferRead { buffer_ptr } => {
                        let wire = format!("input {} /buffer set hotlist -1", buffer_ptr);
                        write_relay_command(&mut stream, &wire).await?;
                    }
                    ClientCommand::RequestNicklist { buffer_ptr } => {
                        let wire = match buffer_ptr {
                            Some(ptr) => format!("(nicklist:{}) nicklist {}", ptr, ptr),
                            None => "(nicklist) nicklist".to_string(),
                        };
                        write_relay_command(&mut stream, &wire).await?;
                    }
                    ClientCommand::RequestFilters => {
                        write_relay_command(&mut stream, "(filters) infolist filter").await?;
                    }
                    ClientCommand::Ping => {
                        last_ping_sent = Some(Instant::now());
                        write_relay_command(&mut stream, "ping keepalive").await?;
                    }
                    ClientCommand::Disconnect => {
                        let _ = write_relay_command(&mut stream, "quit").await;
                        break;
                    }
                }
            }
            _ = ping_interval.tick() => {
                last_ping_sent = Some(Instant::now());
                let _ = write_relay_command(&mut stream, "ping keepalive").await;
            }
        }
    }

    Ok(())
}

async fn handle_incoming_message(
    msg: RelayMessage,
    stream: &mut RelayStream,
    config: &ConnectionConfig,
    event_tx: &mpsc::UnboundedSender<RelayEvent>,
    last_ping_sent: &mut Option<Instant>,
) -> Result<()> {
    let id = msg.id.as_str();

    if id == "listbuffers" {
        let mut buffers = Vec::new();
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let buf = parse_buffer_item(item);
                    buffers.push(buf);
                }
            }
        }
        // Request recent lines for all buffers immediately so UI is populated with backlogs
        let line_count = config.initial_lines.max(50);
        for buf in &buffers {
            let wire = format!(
                "(lines:{}) hdata buffer:{}/own_lines/last_line(-{})/data date,displayed,prefix,message,highlight,notify_level,tags_array",
                buf.ptr, buf.ptr, line_count
            );
            let _ = write_relay_command(stream, &wire).await;
        }
        let _ = event_tx.send(RelayEvent::BuffersListed(buffers));
    } else if id == "hotlist" {
        let mut hotlist_map = HashMap::new();
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let buf_ptr = super::types::normalize_ptr(&item.get_str("buffer"));
                    if let Some(counts) = item.values.get("count").map(|v| v.as_int_vec()) {
                        // WeeChat hotlist count array: [0: low/join/part, 1: message, 2: private, 3: highlight]
                        let msg_count = counts.get(1).copied().unwrap_or(0)
                            + counts.get(2).copied().unwrap_or(0);
                        let highlight_count = counts.get(3).copied().unwrap_or(0);
                        hotlist_map.insert(buf_ptr, (msg_count + highlight_count, highlight_count));
                    }
                }
            }
        }
        let _ = event_tx.send(RelayEvent::HotlistUpdated(hotlist_map));
    } else if id == "filters" || id.starts_with("filters") {
        let mut filters = Vec::new();
        for obj in &msg.objects {
            if let RelayValue::Infolist(inl) = obj {
                for item in &inl.items {
                    let name = item
                        .get("name")
                        .map(|v| v.as_string_lossy())
                        .unwrap_or_default();
                    let buffer = item
                        .get("buffer")
                        .map(|v| v.as_string_lossy())
                        .unwrap_or_default();
                    let tags = item
                        .get("tags")
                        .map(|v| v.as_string_lossy())
                        .unwrap_or_default();
                    let regex = item
                        .get("regex")
                        .map(|v| v.as_string_lossy())
                        .unwrap_or_default();
                    let enabled = item.get("enabled").and_then(|v| v.as_i32()).unwrap_or(0) != 0;
                    if !name.is_empty() {
                        filters.push(RelayFilter {
                            name,
                            buffer,
                            tags,
                            regex,
                            enabled,
                        });
                    }
                }
            }
        }
        let _ = event_tx.send(RelayEvent::FiltersFetched(filters));
    } else if let Some(buf_ptr) = id.strip_prefix("lines:") {
        let norm_buf_ptr = super::types::normalize_ptr(buf_ptr);
        let mut lines = Vec::new();
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let mut line = parse_line_item(item);
                    line.buffer_ptr = norm_buf_ptr.clone();
                    lines.push(line);
                }
            }
        }
        // WeeChat last_line(-N) returns newest-first; reverse into chronological order
        lines.reverse();
        let _ = event_tx.send(RelayEvent::BufferLinesFetched {
            buffer_ptr: norm_buf_ptr,
            lines,
            prepend: false,
        });
    } else if id == "_buffer_line_added" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let mut line = parse_line_item(item);
                    line.buffer_ptr = super::types::normalize_ptr(&line.buffer_ptr);
                    line.line_ptr = super::types::normalize_ptr(&line.line_ptr);
                    let _ = event_tx.send(RelayEvent::LineAdded(line));
                }
            }
        }
    } else if id == "_buffer_opened" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let buf = parse_buffer_item(item);
                    let line_count = config.initial_lines.max(50);
                    let wire_lines = format!(
                        "(lines:{}) hdata buffer:{}/own_lines/last_line(-{})/data date,displayed,prefix,message,highlight,notify_level,tags_array",
                        buf.ptr, buf.ptr, line_count
                    );
                    let _ = write_relay_command(stream, &wire_lines).await;
                    let wire_info = format!(
                        "(bufinfo:{}) hdata buffer:{} number,full_name,short_name,type,nicklist,title,local_variables,notify",
                        buf.ptr, buf.ptr
                    );
                    let _ = write_relay_command(stream, &wire_info).await;
                    let wire_nicks = format!("(nicklist:{}) nicklist {}", buf.ptr, buf.ptr);
                    let _ = write_relay_command(stream, &wire_nicks).await;
                    let _ = event_tx.send(RelayEvent::BufferOpened(buf));
                }
            }
        }
    } else if let Some(buf_ptr) = id.strip_prefix("bufinfo:") {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let mut buf = parse_buffer_item(item);
                    if buf.ptr == "0x0" || buf.ptr.is_empty() {
                        buf.ptr = super::types::normalize_ptr(buf_ptr);
                    }
                    let _ = event_tx.send(RelayEvent::BufferUpdated(buf));
                }
            }
        }
    } else if id == "_buffer_moved" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let ptr = super::types::normalize_ptr(item.first_ptr());
                    let number = item.get_i32("number");
                    let wire_info = format!(
                        "(bufinfo:{}) hdata buffer:{} number,full_name,short_name,type,nicklist,title,local_variables,notify",
                        ptr, ptr
                    );
                    let _ = write_relay_command(stream, &wire_info).await;
                    if number > 0 {
                        let _ = event_tx.send(RelayEvent::BufferMoved {
                            buffer_ptr: ptr,
                            number,
                        });
                    }
                }
            }
        }
    } else if id == "_buffer_localvar_added"
        || id == "_buffer_localvar_changed"
        || id == "_buffer_localvar_removed"
    {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let ptr = super::types::normalize_ptr(item.first_ptr());
                    let local_vars = item
                        .values
                        .get("local_variables")
                        .map(|v| v.as_string_map())
                        .unwrap_or_default();
                    if !local_vars.is_empty() {
                        let _ = event_tx.send(RelayEvent::BufferLocalVarsUpdated {
                            buffer_ptr: ptr.clone(),
                            local_vars,
                        });
                    }
                    let wire_info = format!(
                        "(bufinfo:{}) hdata buffer:{} number,full_name,short_name,type,nicklist,title,local_variables,notify",
                        ptr, ptr
                    );
                    let _ = write_relay_command(stream, &wire_info).await;
                }
            }
        }
    } else if id == "_buffer_type_changed" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let ptr = super::types::normalize_ptr(item.first_ptr());
                    let wire_info = format!(
                        "(bufinfo:{}) hdata buffer:{} number,full_name,short_name,type,nicklist,title,local_variables,notify",
                        ptr, ptr
                    );
                    let _ = write_relay_command(stream, &wire_info).await;
                }
            }
        }
    } else if id == "_buffer_renamed" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let _ = event_tx.send(RelayEvent::BufferRenamed {
                        buffer_ptr: super::types::normalize_ptr(item.first_ptr()),
                        full_name: item.get_str("full_name"),
                        short_name: item.get_str("short_name"),
                    });
                }
            }
        }
    } else if id == "_buffer_title_changed" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let _ = event_tx.send(RelayEvent::BufferTitleChanged {
                        buffer_ptr: super::types::normalize_ptr(item.first_ptr()),
                        title: item.get_str("title"),
                    });
                }
            }
        }
    } else if id == "_buffer_cleared" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let ptr = if item.values.contains_key("buffer") {
                        let b = item.get_str("buffer");
                        if !b.is_empty() && b != "0x0" {
                            super::types::normalize_ptr(&b)
                        } else {
                            super::types::normalize_ptr(item.first_ptr())
                        }
                    } else {
                        super::types::normalize_ptr(item.first_ptr())
                    };
                    let _ = event_tx.send(RelayEvent::BufferCleared { buffer_ptr: ptr });
                }
            }
        }
    } else if id == "_buffer_closing" || id == "_buffer_closed" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for item in &hda.items {
                    let raw_ptr = if item.values.contains_key("buffer") {
                        let b = item.get_str("buffer");
                        if !b.is_empty() && b != "0x0" {
                            b
                        } else {
                            item.first_ptr().to_string()
                        }
                    } else {
                        item.first_ptr().to_string()
                    };
                    let ptr = super::types::normalize_ptr(&raw_ptr);
                    let full_name = item.get_str("full_name");
                    let _ = event_tx.send(RelayEvent::BufferClosed {
                        buffer_ptr: ptr,
                        full_name,
                    });
                }
            }
        }
    } else if id == "nicklist" || id.starts_with("nicklist:") || id == "_nicklist" {
        let fallback_ptr = id.strip_prefix("nicklist:");
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for (buf_ptr, nicks) in parse_nicklist_hdata(hda, fallback_ptr) {
                    let _ = event_tx.send(RelayEvent::NicklistFull {
                        buffer_ptr: buf_ptr,
                        nicks,
                    });
                }
            }
        }
    } else if id == "_nicklist_diff" {
        for obj in &msg.objects {
            if let RelayValue::Hdata(hda) = obj {
                for (buf_ptr, diffs) in parse_nicklist_diff_hdata(hda) {
                    let _ = event_tx.send(RelayEvent::NicklistDiff {
                        buffer_ptr: buf_ptr,
                        diffs,
                    });
                }
            }
        }
    } else if id == "_pong"
        && let Some(sent_at) = last_ping_sent.take()
    {
        let latency_ms = sent_at.elapsed().as_millis() as i32;
        let _ = event_tx.send(RelayEvent::Pong { latency_ms });
    }

    Ok(())
}

pub fn normalize_server_name(raw: &str, full_name: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty()
        || trimmed.eq_ignore_ascii_case("weechat")
        || full_name == "core.weechat"
        || full_name.starts_with("core.")
    {
        return "WeeChat".to_string();
    }
    let mut chars = trimmed.chars();
    match chars.next() {
        None => "WeeChat".to_string(),
        Some(first) => {
            let mut s = first.to_uppercase().collect::<String>();
            s.push_str(chars.as_str());
            s
        }
    }
}

pub fn extract_short_name(full_name: &str, raw_short_name: &str) -> String {
    let trimmed = raw_short_name.trim();
    if !trimmed.is_empty() {
        return trimmed.to_string();
    }

    if let Some(rest) = full_name.strip_prefix("irc.server.") {
        return rest.to_string();
    }
    if let Some(rest) = full_name.strip_prefix("irc.")
        && let Some((_server, target)) = rest.split_once('.')
        && !target.is_empty()
    {
        return target.to_string();
    }
    if let Some(idx) = full_name.rfind(".#") {
        return full_name[idx + 1..].to_string();
    }
    if let Some(idx) = full_name.rfind(".&") {
        return full_name[idx + 1..].to_string();
    }
    if let Some((_, last)) = full_name.rsplit_once('.')
        && !last.is_empty()
    {
        return last.to_string();
    }
    full_name.to_string()
}

pub fn determine_buffer_type(
    full_name: &str,
    short_name: &str,
    local_vars: &HashMap<String, String>,
) -> String {
    // 1. Explicit local variable "type" (e.g. from WeeChat buffer local variables)
    if let Some(t) = local_vars.get("type") {
        let t_lower = t.to_lowercase();
        if t_lower == "channel" || t_lower == "private" || t_lower == "server" || t_lower == "core"
        {
            return t_lower;
        }
    }

    // 2. Core buffer check
    if full_name == "core.weechat" || full_name == "weechat" || full_name.starts_with("core.") {
        return "core".to_string();
    }

    // 3. Server buffer check
    if full_name.starts_with("irc.server.") || full_name.starts_with("server.") {
        return "server".to_string();
    }

    // 4. Channel buffer check:
    // RFC 2812 channel prefixes: '#', '&', '+', '!'
    let is_chan_prefix = |s: &str| {
        s.starts_with('#') || s.starts_with('&') || s.starts_with('+') || s.starts_with('!')
    };

    if is_chan_prefix(short_name) {
        return "channel".to_string();
    }

    if is_chan_prefix(full_name)
        || full_name.contains(".#")
        || full_name.contains(".&")
        || full_name.contains(".+")
        || full_name.contains(".!")
    {
        return "channel".to_string();
    }

    if let Some(chan) = local_vars.get("channel")
        && is_chan_prefix(chan)
    {
        return "channel".to_string();
    }

    // Default to private query
    "private".to_string()
}

pub fn extract_server_name(full_name: &str, local_vars: &HashMap<String, String>) -> String {
    let raw_server = local_vars.get("server").cloned().unwrap_or_else(|| {
        if let Some(rest) = full_name.strip_prefix("irc.server.") {
            rest.to_string()
        } else if let Some(rest) = full_name.strip_prefix("irc.") {
            rest.split('.').next().unwrap_or("WeeChat").to_string()
        } else {
            "WeeChat".to_string()
        }
    });

    normalize_server_name(&raw_server, full_name)
}

pub fn parse_buffer_item(item: &super::types::HdataItem) -> RelayBuffer {
    let ptr = super::types::normalize_ptr(item.first_ptr());
    let number = item.get_i32("number");
    let full_name = item.get_str("full_name");
    let raw_short_name = item.get_str("short_name");
    let short_name = extract_short_name(&full_name, &raw_short_name);
    let title = item.get_str("title");
    let notify_level = item.get_i32("notify");
    let local_vars = item
        .values
        .get("local_variables")
        .map(|v| v.as_string_map())
        .unwrap_or_default();

    let server_name = extract_server_name(&full_name, &local_vars);
    let buffer_type = determine_buffer_type(&full_name, &short_name, &local_vars);

    RelayBuffer {
        ptr,
        number,
        full_name,
        short_name,
        server_name,
        buffer_type,
        title,
        notify_level,
        local_vars,
    }
}

fn parse_line_item(item: &super::types::HdataItem) -> RelayLine {
    let buffer_ptr = if item.values.contains_key("buffer") {
        super::types::normalize_ptr(&item.get_str("buffer"))
    } else {
        super::types::normalize_ptr(item.first_ptr())
    };
    let line_ptr = super::types::normalize_ptr(item.last_ptr());
    let timestamp = item.get_i64("date");
    let displayed = item
        .values
        .get("displayed")
        .map(|v| v.as_i32().unwrap_or(1) != 0)
        .unwrap_or(true);
    let prefix = item.get_str("prefix");
    let message = item.get_str("message");
    let highlight = item.get_i32("highlight") != 0;
    let notify_level = item.get_i32("notify_level");
    let tags = item
        .values
        .get("tags_array")
        .map(|v| v.as_string_vec())
        .unwrap_or_default();

    RelayLine {
        buffer_ptr,
        line_ptr,
        timestamp,
        displayed,
        prefix,
        message,
        highlight,
        notify_level,
        tags,
    }
}

fn parse_nicklist_hdata(
    hda: &HdataObject,
    default_buf_ptr: Option<&str>,
) -> HashMap<String, Vec<RelayNick>> {
    let mut by_buffer: HashMap<String, Vec<RelayNick>> = HashMap::new();
    let mut current_group = String::new();

    for item in &hda.items {
        let raw_ptr = item.first_ptr();
        let buf_ptr = if (raw_ptr == "0x0" || raw_ptr.is_empty())
            && let Some(def_ptr) = default_buf_ptr
        {
            super::types::normalize_ptr(def_ptr)
        } else {
            super::types::normalize_ptr(raw_ptr)
        };
        let is_group = item.get_i32("group") != 0;
        let visible = item.get_i32("visible") != 0;
        let name = item.get_str("name");

        if is_group {
            current_group = name;
            by_buffer.entry(buf_ptr).or_default();
        } else if visible && !name.is_empty() {
            let prefix = item.get_str("prefix");
            let color = item.get_str("color");
            by_buffer
                .entry(buf_ptr.clone())
                .or_default()
                .push(RelayNick {
                    buffer_ptr: buf_ptr,
                    group_name: current_group.clone(),
                    name,
                    prefix,
                    color,
                    visible,
                });
        }
    }

    by_buffer
}

fn parse_nicklist_diff_hdata(hda: &HdataObject) -> HashMap<String, Vec<RelayNickDiff>> {
    let mut by_buffer: HashMap<String, Vec<RelayNickDiff>> = HashMap::new();
    let mut current_group = String::new();

    for item in &hda.items {
        let buf_ptr = super::types::normalize_ptr(item.first_ptr());
        let diff_op = item.get_char("_diff");
        let is_group = item.get_i32("group") != 0;
        let visible = item.get_i32("visible") != 0;
        let name = item.get_str("name");

        if diff_op == '^' || is_group {
            current_group = name;
        } else if matches!(diff_op, '+' | '-' | '*') && !name.is_empty() {
            let prefix = item.get_str("prefix");
            let color = item.get_str("color");
            by_buffer
                .entry(buf_ptr.clone())
                .or_default()
                .push(RelayNickDiff {
                    buffer_ptr: buf_ptr,
                    diff_op,
                    nick: RelayNick {
                        buffer_ptr: item.first_ptr().to_string(),
                        group_name: current_group.clone(),
                        name,
                        prefix,
                        color,
                        visible,
                    },
                });
        }
    }

    by_buffer
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_short_name_and_determine_buffer_type() {
        let empty_vars = HashMap::new();

        // Case 1: Newly opened channel with empty short_name
        let short = extract_short_name("irc.libera.#rust", "");
        assert_eq!(short, "#rust");
        let btype = determine_buffer_type("irc.libera.#rust", &short, &empty_vars);
        assert_eq!(btype, "channel");

        // Case 2: Channel starting with '&' and empty short_name
        let short = extract_short_name("irc.oftc.&secret", "");
        assert_eq!(short, "&secret");
        let btype = determine_buffer_type("irc.oftc.&secret", &short, &empty_vars);
        assert_eq!(btype, "channel");

        // Case 3: Channel with dots in channel name
        let short = extract_short_name("irc.libera.#c++.chat", "");
        assert_eq!(short, "#c++.chat");
        let btype = determine_buffer_type("irc.libera.#c++.chat", &short, &empty_vars);
        assert_eq!(btype, "channel");

        // Case 4: Private query with empty short_name
        let short = extract_short_name("irc.libera.alice", "");
        assert_eq!(short, "alice");
        let btype = determine_buffer_type("irc.libera.alice", &short, &empty_vars);
        assert_eq!(btype, "private");

        // Case 5: IRC server buffer with empty short_name
        let short = extract_short_name("irc.server.libera", "");
        assert_eq!(short, "libera");
        let btype = determine_buffer_type("irc.server.libera", &short, &empty_vars);
        assert_eq!(btype, "server");

        // Case 6: Core weechat buffer
        let short = extract_short_name("core.weechat", "");
        assert_eq!(short, "weechat");
        let btype = determine_buffer_type("core.weechat", &short, &empty_vars);
        assert_eq!(btype, "core");

        // Case 7: Explicit local_variables override
        let mut vars = HashMap::new();
        vars.insert("type".to_string(), "channel".to_string());
        let btype = determine_buffer_type("custom.buffer", "custom", &vars);
        assert_eq!(btype, "channel");

        // Case 8: Explicit local variable "channel"
        let mut vars = HashMap::new();
        vars.insert("channel".to_string(), "#custom".to_string());
        let btype = determine_buffer_type("matrix.server.room123", "room123", &vars);
        assert_eq!(btype, "channel");
    }
}
