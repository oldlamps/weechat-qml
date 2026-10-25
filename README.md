# WeeChat QML

WeeChat QML is a fast, native Linux desktop client for WeeChat. It connects to a local or remote WeeChat instance via the Relay protocol, offering a responsive GUI while letting WeeChat manage your IRC connections, bouncers, and logs.

<img width="1576" height="1036" alt="weechat-qml" src="https://github.com/user-attachments/assets/66cb37ad-0a29-4db8-bed8-d5d92e6a8f54" />

## Highlights

- **Modern & Classic Views**: Toggle between a modern chat layout with inline previews and avatars, or a compact, dense layout for traditional IRC users.
- **Fast Navigation**: Fuzzy channel search (`Ctrl+K`), quick jump to unreads (`Ctrl+U`), and organized server channel lists.
- **Curated Themes**: Multiple built-in dark and light themes with optional alternating row colors for readability.
- **Linux Integration**: System tray support, desktop notifications for highlights and private messages, and secure password storage in the system keyring.

## Installation

### Pre-built Binary
Download the latest executable from the [GitHub Releases](https://github.com/oldlamps/weechat-qml/releases) page.

### Building from Source

**Prerequisites**:
- Rust (latest stable)
- Qt 6 (Declarative, Quick Controls)
- C++ build tools (`cmake`, `pkg-config`)

```bash
git clone https://github.com/oldlamps/weechat-qml.git
cd weechat-qml
cargo build --release
```

The compiled binary will be located at `target/release/weechat-qml`.

## Connecting to WeeChat

1. In WeeChat, configure a TLS relay port and password:
   ```text
   /relay add tls.weechat 9000
   /set relay.network.password "your_password"
   ```

2. Launch WeeChat QML and enter your host, port, and password in the connection manager.

## Key Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+K` | Quick channel switcher |
| `Ctrl+U` | Jump to next unread / highlight |
| `Ctrl+Tab` | Cycle channels |
| `Tab` | Nick and command completion |
| `Ctrl+F` | Search buffer |
| `Ctrl+Q` | Quit |

## License

MIT
