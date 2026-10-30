use std::fs;
use std::path::PathBuf;

use anyhow::Result;
use keyring::Entry;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

const KEYRING_SERVICE: &str = "weechat-qml";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerProfile {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub use_tls: bool,
    pub verify_tls: bool,
    pub save_password: bool,
    pub auto_connect: bool,
    pub totp: String,
}

impl Default for ServerProfile {
    fn default() -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: "Default Relay".to_string(),
            host: "localhost".to_string(),
            port: 9000,
            use_tls: false,
            verify_tls: true,
            save_password: true,
            auto_connect: true,
            totp: String::new(),
        }
    }
}

impl ServerProfile {
    /// Retrieve stored password from the Freedesktop Secret Service / KWallet keychain
    pub fn get_keyring_password(&self) -> Option<String> {
        if !self.save_password {
            return None;
        }
        let entry = Entry::new(KEYRING_SERVICE, &self.id).ok()?;
        entry.get_password().ok()
    }

    /// Save password securely into the Freedesktop Secret Service / KWallet keychain
    pub fn set_keyring_password(&self, password: &str) -> Result<()> {
        let entry = Entry::new(KEYRING_SERVICE, &self.id)?;
        if password.is_empty() {
            let _ = entry.delete_credential();
        } else {
            entry.set_password(password)?;
        }
        Ok(())
    }

    /// Remove password from keychain when profile is deleted or remember-password is unticked
    pub fn delete_keyring_password(&self) {
        if let Ok(entry) = Entry::new(KEYRING_SERVICE, &self.id) {
            let _ = entry.delete_credential();
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ServerStore {
    pub active_server_id: Option<String>,
    pub servers: Vec<ServerProfile>,
}

impl ServerStore {
    pub fn store_path() -> Option<PathBuf> {
        dirs::config_dir().map(|mut p| {
            p.push("weechat-qml");
            let _ = fs::create_dir_all(&p);
            p.push("servers.json");
            p
        })
    }

    pub fn load() -> Self {
        if let Some(path) = Self::store_path()
            && let Ok(content) = fs::read_to_string(&path)
            && let Ok(store) = serde_json::from_str::<Self>(&content)
        {
            return store;
        }
        Self::default()
    }

    pub fn save(&self) {
        if let Some(path) = Self::store_path()
            && let Ok(json) = serde_json::to_string_pretty(self)
        {
            let _ = fs::write(&path, json);
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
            }
        }
    }

    pub fn get_active_or_first(&self) -> Option<&ServerProfile> {
        if let Some(active_id) = &self.active_server_id
            && let Some(p) = self.servers.iter().find(|s| &s.id == active_id)
        {
            return Some(p);
        }
        self.servers.first()
    }
}
