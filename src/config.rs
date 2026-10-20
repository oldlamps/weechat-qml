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

    pub fn load() -> Self {
        if let Some(path) = Self::config_path()
            && let Ok(content) = fs::read_to_string(path)
            && let Ok(cfg) = serde_json::from_str::<Self>(&content)
        {
            return cfg;
        }
        Self::default()
    }

    pub fn save(&self) {
        if let Some(path) = Self::config_path()
            && let Ok(json) = serde_json::to_string_pretty(self)
        {
            let _ = fs::write(path, json);
        }
    }
}
