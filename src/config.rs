use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
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
    pub confirm_on_quit: bool,
    pub close_to_tray: bool,
    pub custom_browser: String,
    #[serde(default)]
    pub sidebar_server_order: Vec<String>,
    #[serde(default)]
    pub collapsed_servers: Vec<String>,
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
            confirm_on_quit: true,
            close_to_tray: true,
            custom_browser: String::new(),
            sidebar_server_order: Vec::new(),
            collapsed_servers: Vec::new(),
        }
    }
}

impl AppConfig {
    pub fn config_path() -> Option<PathBuf> {
        #[cfg(test)]
        {
            let mut p = std::env::temp_dir();
            let thread_name = format!("{:?}", std::thread::current().id());
            let clean_thread = thread_name.replace(['(', ')', ' '], "");
            p.push(format!("weechat-qml-test-{}", clean_thread));
            let _ = fs::create_dir_all(&p);
            p.push("config.json");
            Some(p)
        }
        #[cfg(not(test))]
        {
            dirs::config_dir().map(|mut p| {
                p.push("weechat-qml");
                let _ = fs::create_dir_all(&p);
                p.push("config.json");
                p
            })
        }
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
        self.custom_browser = self.custom_browser.trim().to_string();

        let mut clean_order = Vec::new();
        for s in self.sidebar_server_order.drain(..) {
            let trimmed = s.trim().to_lowercase();
            if !trimmed.is_empty() && !clean_order.contains(&trimmed) {
                clean_order.push(trimmed);
            }
        }
        self.sidebar_server_order = clean_order;

        let mut clean_collapsed = Vec::new();
        for s in self.collapsed_servers.drain(..) {
            let trimmed = s.trim().to_string();
            if !trimmed.is_empty()
                && !clean_collapsed
                    .iter()
                    .any(|existing: &String| existing.eq_ignore_ascii_case(&trimmed))
            {
                clean_collapsed.push(trimmed);
            }
        }
        self.collapsed_servers = clean_collapsed;
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
            confirm_on_quit: false,
            close_to_tray: false,
            custom_browser: "  firefox --private  ".to_string(),
            sidebar_server_order: vec![
                "Libera".to_string(),
                " LIBERA ".to_string(),
                "".to_string(),
            ],
            collapsed_servers: vec![
                "Libera".to_string(),
                " LIBERA ".to_string(),
                "".to_string(),
                "OFTC".to_string(),
            ],
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
        assert_eq!(cfg.custom_browser, "firefox --private");
        assert_eq!(cfg.sidebar_server_order, vec!["libera".to_string()]);
        assert_eq!(
            cfg.collapsed_servers,
            vec!["Libera".to_string(), "OFTC".to_string()]
        );
        // Valid boolean changes must be preserved
        assert!(cfg.use_tls);
        assert!(!cfg.verify_tls);
        assert!(cfg.show_join_part_quit);
        assert!(!cfg.show_media_previews);
        assert!(!cfg.desktop_notifications);
        assert!(!cfg.auto_reconnect);
        assert!(!cfg.confirm_on_quit);
        assert!(!cfg.close_to_tray);
    }
}
