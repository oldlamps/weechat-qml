use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub host: String,
    pub port: u16,
    pub use_tls: bool,
    pub verify_tls: bool,
    pub show_join_part_quit: bool,
    pub show_media_previews: bool,
    pub desktop_notifications: bool,
    pub theme_name: String,
    pub font_family: String,
    pub font_size: i32,
    pub timestamp_format: String,
    pub initial_lines_fetch: i32,
    pub auto_reconnect: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            host: "localhost".to_string(),
            port: 9000,
            use_tls: false,
            verify_tls: true,
            show_join_part_quit: false,
            show_media_previews: true,
            desktop_notifications: true,
            theme_name: "Catppuccin Mocha".to_string(),
            font_family: "Inter, Noto Sans, Cantarell, sans-serif".to_string(),
            font_size: 13,
            timestamp_format: "%H:%M".to_string(),
            initial_lines_fetch: 150,
            auto_reconnect: true,
        }
    }
}

impl AppConfig {
    pub fn config_path() -> Option<PathBuf> {
        dirs::config_dir().map(|mut p| {
            p.push("weechat-qml");
            let _ = fs::create_dir_all(&p);
            p.push("config.json");
            p
        })
    }

    pub fn sanitize(&mut self) {
        let defaults = Self::default();
        if self.theme_name.trim().is_empty() {
            self.theme_name = defaults.theme_name;
        }
        if self.font_family.trim().is_empty() {
            self.font_family = defaults.font_family;
        }
        if self.font_size <= 0 {
            self.font_size = defaults.font_size;
        }
        if self.timestamp_format.trim().is_empty() {
            self.timestamp_format = defaults.timestamp_format;
        }
        if self.initial_lines_fetch <= 0 {
            self.initial_lines_fetch = defaults.initial_lines_fetch;
        }
        if self.host.trim().is_empty() {
            self.host = defaults.host;
        }
        if self.port == 0 {
            self.port = defaults.port;
        }
    }

    pub fn load() -> Self {
        if let Some(path) = Self::config_path()
            && let Ok(content) = fs::read_to_string(path)
            && let Ok(mut cfg) = serde_json::from_str::<Self>(&content)
        {
            cfg.sanitize();
            return cfg;
        }
        Self::default()
    }

    pub fn save(&self) {
        let mut sanitized = self.clone();
        sanitized.sanitize();
        if let Some(path) = Self::config_path()
            && let Ok(json) = serde_json::to_string_pretty(&sanitized)
        {
            let _ = fs::write(path, json);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_app_config_sanitize_replaces_empty_or_zero_values_with_defaults() {
        let mut cfg = AppConfig {
            host: "   ".to_string(),
            port: 0,
            use_tls: true,
            verify_tls: false,
            show_join_part_quit: true,
            show_media_previews: false,
            desktop_notifications: false,
            theme_name: "".to_string(),
            font_family: "   ".to_string(),
            font_size: 0,
            timestamp_format: "".to_string(),
            initial_lines_fetch: -5,
            auto_reconnect: false,
        };

        cfg.sanitize();

        let defaults = AppConfig::default();
        assert_eq!(cfg.host, defaults.host);
        assert_eq!(cfg.port, defaults.port);
        assert_eq!(cfg.theme_name, defaults.theme_name);
        assert_eq!(cfg.font_family, defaults.font_family);
        assert_eq!(cfg.font_size, defaults.font_size);
        assert_eq!(cfg.timestamp_format, defaults.timestamp_format);
        assert_eq!(cfg.initial_lines_fetch, defaults.initial_lines_fetch);
        // Valid boolean changes must be preserved
        assert!(cfg.use_tls);
        assert!(!cfg.verify_tls);
        assert!(cfg.show_join_part_quit);
        assert!(!cfg.show_media_previews);
        assert!(!cfg.desktop_notifications);
        assert!(!cfg.auto_reconnect);
    }
}
