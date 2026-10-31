use std::cell::RefCell;
use std::collections::{HashMap, HashSet};

use chrono::{Local, TimeZone};
use qmetaobject::*;
use tokio::sync::mpsc;

use crate::config::AppConfig;
use crate::formatting::colors::{
    deterministic_nick_color, map_named_weechat_color, strip_weechat_formatting,
};
use crate::formatting::urls::format_weechat_message;
use crate::relay::client::{
    ClientCommand, ConnectionConfig, RelayBuffer, RelayEvent, RelayFilter, RelayLine, RelayNick,
    determine_buffer_type, extract_server_name, extract_short_name, run_relay_session,
};
use crate::relay::types::normalize_ptr;

use super::models::{BufferItem, FilterItem, MessageItem, NickItem, ServerProfileItem};
use crate::servers::{ServerProfile, ServerStore};

#[derive(QObject)]
pub struct RelayController {
    base: qt_base_class!(trait QObject),

    // Connection state properties
    pub connection_state: qt_property!(QString; NOTIFY connection_state_changed),
    pub status_detail: qt_property!(QString; NOTIFY connection_state_changed),
    pub server_version: qt_property!(QString; NOTIFY connection_state_changed),
    pub error_message: qt_property!(QString; NOTIFY error_message_changed),
    pub latency_ms: qt_property!(i32; NOTIFY latency_changed),
    pub is_demo_mode: qt_property!(bool; NOTIFY connection_state_changed),

    // Saved connection and UI preferences
    pub saved_host: qt_property!(QString; NOTIFY config_changed),
    pub saved_port: qt_property!(i32; NOTIFY config_changed),
    pub saved_use_tls: qt_property!(bool; NOTIFY config_changed),
    pub saved_verify_tls: qt_property!(bool; NOTIFY config_changed),
    pub show_join_part_quit: qt_property!(bool; NOTIFY preferences_changed),
    pub show_media_previews: qt_property!(bool; NOTIFY preferences_changed),
    pub desktop_notifications: qt_property!(bool; NOTIFY preferences_changed),
    pub theme_name: qt_property!(QString; NOTIFY preferences_changed),
    pub font_family: qt_property!(QString; NOTIFY preferences_changed),
    pub font_size: qt_property!(i32; NOTIFY preferences_changed),
    pub timestamp_format: qt_property!(QString; NOTIFY preferences_changed),
    pub initial_lines_fetch: qt_property!(i32; NOTIFY preferences_changed),
    pub auto_reconnect: qt_property!(bool; NOTIFY preferences_changed),
    pub confirm_on_quit: qt_property!(bool; NOTIFY preferences_changed),
    pub close_to_tray: qt_property!(bool; NOTIFY preferences_changed),
    pub custom_browser: qt_property!(QString; NOTIFY preferences_changed),
    pub classic_mode: qt_property!(bool; NOTIFY preferences_changed),
    pub alternating_row_colors: qt_property!(bool; NOTIFY preferences_changed),
    pub auto_save_weechat_filters: qt_property!(bool; NOTIFY preferences_changed),
    pub active_filter_count: qt_property!(i32; NOTIFY filters_changed),
    pub filters_global_enabled: qt_property!(bool; NOTIFY filters_changed),
    pub filter_save_status: qt_property!(QString; NOTIFY filter_save_status_changed),

    // Active buffer metadata properties
    pub active_buffer_ptr: qt_property!(QString; NOTIFY active_buffer_changed),
    pub active_buffer_name: qt_property!(QString; NOTIFY active_buffer_changed),
    pub active_buffer_server: qt_property!(QString; NOTIFY active_buffer_changed),
    pub active_buffer_type: qt_property!(QString; NOTIFY active_buffer_changed),
    pub active_buffer_topic: qt_property!(QString; NOTIFY active_buffer_changed),
    pub active_buffer_nick_count: qt_property!(i32; NOTIFY nick_count_changed),
    pub active_buffer_is_operator: qt_property!(bool; NOTIFY nick_count_changed),
    pub active_buffer_has_older: qt_property!(bool; NOTIFY active_buffer_changed),
    pub total_unread_count: qt_property!(i32; NOTIFY hotlist_summary_changed),
    pub total_highlight_count: qt_property!(i32; NOTIFY hotlist_summary_changed),
    pub search_match_count: qt_property!(i32; NOTIFY search_changed),

    // Active Server Profile
    pub active_server_id: qt_property!(QString; NOTIFY active_server_changed),
    pub active_server_name: qt_property!(QString; NOTIFY active_server_changed),
    pub active_server_has_password: qt_property!(bool; NOTIFY active_server_changed),

    // Reactive QAbstractListModels exposed directly to QML ListViews
    pub buffer_model: qt_property!(RefCell<SimpleListModel<BufferItem>>; CONST),
    pub message_model: qt_property!(RefCell<SimpleListModel<MessageItem>>; CONST),
    pub nick_model: qt_property!(RefCell<SimpleListModel<NickItem>>; CONST),
    pub server_model: qt_property!(RefCell<SimpleListModel<ServerProfileItem>>; CONST),
    pub filter_model: qt_property!(RefCell<SimpleListModel<FilterItem>>; CONST),

    // Signals
    pub connection_state_changed: qt_signal!(),
    pub error_message_changed: qt_signal!(),
    pub latency_changed: qt_signal!(),
    pub config_changed: qt_signal!(),
    pub preferences_changed: qt_signal!(),
    pub active_buffer_changed: qt_signal!(),
    pub nick_count_changed: qt_signal!(),
    pub hotlist_summary_changed: qt_signal!(),
    pub search_changed: qt_signal!(),
    pub new_message_arrived: qt_signal!(),
    pub active_server_changed: qt_signal!(),
    pub server_list_changed: qt_signal!(),
    pub filters_changed: qt_signal!(),
    pub filter_save_status_changed: qt_signal!(),

    // Invokable methods callable from QML
    pub init_controller: qt_method!(fn(&mut self)),
    pub connect_to_relay: qt_method!(
        fn(
            &mut self,
            host: QString,
            port: i32,
            password: QString,
            use_tls: bool,
            verify_tls: bool,
            totp: QString,
        )
    ),
    pub start_demo_mode: qt_method!(fn(&mut self)),
    pub disconnect_relay: qt_method!(fn(&mut self)),
    pub select_buffer: qt_method!(fn(&mut self, buffer_ptr: QString)),
    pub close_buffer: qt_method!(fn(&mut self, buffer_ptr: QString)),
    pub select_next_unread_buffer: qt_method!(fn(&mut self)),
    pub select_next_buffer: qt_method!(fn(&mut self)),
    pub select_previous_buffer: qt_method!(fn(&mut self)),
    pub select_buffer_by_number: qt_method!(fn(&mut self, number: i32)),
    pub select_buffer_by_filtered_index: qt_method!(fn(&mut self, index: i32) -> bool),
    pub active_buffer_filtered_index: qt_method!(fn(&self) -> i32),
    pub send_input: qt_method!(fn(&mut self, text: QString)),
    pub load_more_history: qt_method!(fn(&mut self)),
    pub toggle_join_part_quit: qt_method!(fn(&mut self)),
    pub set_show_join_part_quit: qt_method!(fn(&mut self, enabled: bool)),
    pub toggle_media_previews: qt_method!(fn(&mut self)),
    pub set_show_media_previews: qt_method!(fn(&mut self, enabled: bool)),
    pub toggle_desktop_notifications: qt_method!(fn(&mut self)),
    pub set_desktop_notifications: qt_method!(fn(&mut self, enabled: bool)),
    pub set_theme: qt_method!(fn(&mut self, theme: QString)),
    pub set_font_size: qt_method!(fn(&mut self, size: i32)),
    pub set_initial_lines_fetch: qt_method!(fn(&mut self, count: i32)),
    pub set_timestamp_format: qt_method!(fn(&mut self, format: QString)),
    pub toggle_auto_reconnect: qt_method!(fn(&mut self)),
    pub set_auto_reconnect: qt_method!(fn(&mut self, enabled: bool)),
    pub toggle_confirm_on_quit: qt_method!(fn(&mut self)),
    pub set_confirm_on_quit: qt_method!(fn(&mut self, enabled: bool)),
    pub toggle_close_to_tray: qt_method!(fn(&mut self)),
    pub set_close_to_tray: qt_method!(fn(&mut self, enabled: bool)),
    pub set_custom_browser: qt_method!(fn(&mut self, browser: QString)),
    pub toggle_classic_mode: qt_method!(fn(&mut self)),
    pub set_classic_mode: qt_method!(fn(&mut self, enabled: bool)),
    pub toggle_alternating_row_colors: qt_method!(fn(&mut self)),
    pub set_alternating_row_colors: qt_method!(fn(&mut self, enabled: bool)),
    pub open_url: qt_method!(fn(&self, url: QString)),
    pub filter_buffers: qt_method!(fn(&mut self, query: QString)),
    pub search_in_buffer: qt_method!(fn(&mut self, query: QString)),
    pub complete_input: qt_method!(fn(&mut self, text: QString, cursor_pos: i32) -> QString),
    pub open_query_with_nick: qt_method!(fn(&mut self, nick: QString)),
    pub whois_nick: qt_method!(fn(&mut self, nick: QString)),
    pub play_with_mpv: qt_method!(fn(&mut self, url: QString)),
    pub resolve_media_stream: qt_method!(fn(&mut self, media_url: QString, target_id: QString)),
    pub media_stream_resolved: qt_signal!(target_id: QString, stream_url: QString, audio_url: QString),
    pub media_stream_error: qt_signal!(target_id: QString, error_msg: QString),

    // Collapsed server sections
    pub collapsed_servers_changed: qt_signal!(),
    pub is_server_collapsed: qt_method!(fn(&self, server_name: QString) -> bool),
    pub toggle_server_collapsed: qt_method!(fn(&mut self, server_name: QString) -> bool),
    pub set_server_collapsed: qt_method!(fn(&mut self, server_name: QString, collapsed: bool)),
    pub get_collapsed_servers: qt_method!(fn(&self) -> QStringList),
    pub server_unread_count: qt_method!(fn(&self, server_name: QString) -> i32),
    pub server_highlight_count: qt_method!(fn(&self, server_name: QString) -> i32),
    pub server_buffer_count: qt_method!(fn(&self, server_name: QString) -> i32),

    // Persistent Server Manager Methods
    pub load_servers: qt_method!(fn(&mut self)),
    pub connect_server_profile:
        qt_method!(fn(&mut self, server_id: QString, password_override: QString)),
    pub save_server_profile: qt_method!(
        fn(
            &mut self,
            id: QString,
            name: QString,
            host: QString,
            port: i32,
            password: QString,
            use_tls: bool,
            verify_tls: bool,
            save_password: bool,
            auto_connect: bool,
            totp: QString,
        )
    ),
    pub delete_server_profile: qt_method!(fn(&mut self, server_id: QString)),
    pub get_saved_password_for_server: qt_method!(fn(&mut self, server_id: QString) -> QString),
    pub select_active_server: qt_method!(fn(&mut self, server_id: QString)),
    pub should_show_server_manager_on_startup: qt_method!(fn(&self) -> bool),
    pub copy_to_clipboard: qt_method!(fn(&self, text: QString)),

    // WeeChat Server-Side Filters
    pub request_filters: qt_method!(fn(&mut self)),
    pub toggle_weechat_filter: qt_method!(fn(&mut self, name: QString)),
    pub add_weechat_filter:
        qt_method!(fn(&mut self, name: QString, buffer: QString, tags: QString, regex: QString)),
    pub delete_weechat_filter: qt_method!(fn(&mut self, name: QString)),
    pub toggle_all_filters: qt_method!(fn(&mut self)),
    pub save_weechat_config: qt_method!(fn(&mut self)),
    pub toggle_preset_filter: qt_method!(fn(&mut self, preset_id: QString)),
    pub has_filter: qt_method!(fn(&self, name: QString) -> bool),
    pub is_filter_enabled: qt_method!(fn(&self, name: QString) -> bool),
    pub set_auto_save_weechat_filters: qt_method!(fn(&mut self, enabled: bool)),
    pub is_nick_muted: qt_method!(fn(&self, nick: QString) -> bool),
    pub is_valid_nick_for_mute: qt_method!(fn(&self, nick: QString) -> bool),
    pub toggle_mute_nick: qt_method!(fn(&mut self, nick: QString)),

    // Internal Rust state
    cmd_tx: Option<mpsc::UnboundedSender<ClientCommand>>,
    buffers_cache: Vec<RelayBuffer>,
    filters_cache: Vec<RelayFilter>,
    filters_version: u64,
    buffer_filters_version: HashMap<String, u64>,
    lines_cache: HashMap<String, Vec<RelayLine>>,
    message_items_cache: HashMap<String, Vec<MessageItem>>,
    nicks_cache: HashMap<String, Vec<RelayNick>>,
    nick_items_cache: HashMap<String, (Vec<NickItem>, bool)>,
    unread_map: HashMap<String, (i32, i32)>, // buffer_ptr -> (unread, highlight)
    buffer_filter_query: String,
    message_search_query: String,
    active_buffer_view_limit: usize,
    server_store: ServerStore,
    sidebar_server_order: Vec<String>,
    pub collapsed_servers: HashSet<String>,
}

pub fn sort_buffers_by_server_and_number(
    buffers: &mut Vec<RelayBuffer>,
    server_order: &mut Vec<String>,
) {
    if buffers.is_empty() {
        return;
    }

    // 1. Group by lowercase trimmed server name
    let mut groups: HashMap<String, Vec<RelayBuffer>> = HashMap::new();
    for buf in buffers.drain(..) {
        let raw_key = buf.server_name.trim().to_lowercase();
        let key = if raw_key.is_empty() || raw_key == "core" {
            "weechat".to_string()
        } else {
            raw_key
        };
        groups.entry(key).or_default().push(buf);
    }

    // 2. Sort each group internally:
    // Positive buffer numbers in ascending order; 0 or negative numbers at the end.
    // Within same number, server buffers come before channels, then by short_name.
    let mut group_info_map: HashMap<String, (i32, String, Vec<RelayBuffer>)> = HashMap::new();

    for (key, mut items) in groups {
        items.sort_by(|a, b| {
            let a_is_srv = a.buffer_type == "server";
            let b_is_srv = b.buffer_type == "server";

            let a_num = if a.number > 0 { a.number } else { i32::MAX };
            let b_num = if b.number > 0 { b.number } else { i32::MAX };

            a_num
                .cmp(&b_num)
                .then_with(|| b_is_srv.cmp(&a_is_srv))
                .then_with(|| {
                    a.short_name
                        .to_lowercase()
                        .cmp(&b.short_name.to_lowercase())
                })
        });

        let min_pos_number = items
            .iter()
            .filter(|b| b.number > 0)
            .map(|b| b.number)
            .min()
            .unwrap_or(i32::MAX);

        let canonical_name = if key == "weechat" {
            "WeeChat".to_string()
        } else {
            items
                .iter()
                .find(|b| {
                    b.server_name
                        .chars()
                        .next()
                        .map(|c| c.is_uppercase())
                        .unwrap_or(false)
                })
                .map(|b| b.server_name.clone())
                .unwrap_or_else(|| items[0].server_name.clone())
        };

        for b in &mut items {
            b.server_name = canonical_name.clone();
        }

        group_info_map.insert(key, (min_pos_number, canonical_name, items));
    }

    // 3. Ensure "weechat" is always first in server_order if present
    if !server_order.contains(&"weechat".to_string()) {
        server_order.insert(0, "weechat".to_string());
    }

    // 4. Find all server keys in group_info_map that are NOT yet in server_order
    let mut new_keys: Vec<String> = group_info_map
        .keys()
        .filter(|k| !server_order.contains(k))
        .cloned()
        .collect();

    // Sort newly discovered servers by minimum positive buffer number, then alphabetically
    new_keys.sort_by(|a, b| {
        let (min_a, _, _) = &group_info_map[a];
        let (min_b, _, _) = &group_info_map[b];
        min_a.cmp(min_b).then_with(|| a.cmp(b))
    });

    server_order.extend(new_keys);

    // 5. Order groups strictly according to their established index in server_order
    let mut ordered_groups: Vec<(usize, String, Vec<RelayBuffer>)> = Vec::new();
    for (order_idx, key) in server_order.iter().enumerate() {
        if let Some((_, canonical_name, items)) = group_info_map.remove(key) {
            ordered_groups.push((order_idx, canonical_name, items));
        }
    }

    // Any remaining items (if any) placed at the end
    for (_, (_, canonical_name, items)) in group_info_map {
        ordered_groups.push((usize::MAX, canonical_name, items));
    }

    ordered_groups.sort_by_key(|(idx, _, _)| *idx);

    // Flatten back into buffers
    for (_, _, items) in ordered_groups {
        buffers.extend(items);
    }
}

impl Default for RelayController {
    fn default() -> Self {
        let mut controller = Self {
            base: Default::default(),
            connection_state: "Disconnected".into(),
            status_detail: "Select a server profile to connect".into(),
            server_version: QString::default(),
            error_message: QString::default(),
            latency_ms: 0,
            is_demo_mode: false,
            saved_host: QString::default(),
            saved_port: 9000,
            saved_use_tls: false,
            saved_verify_tls: true,
            show_join_part_quit: false,
            show_media_previews: true,
            desktop_notifications: true,
            theme_name: "Catppuccin Mocha".into(),
            font_family: "Inter, Noto Sans, Cantarell, sans-serif".into(),
            font_size: 13,
            timestamp_format: "%H:%M".into(),
            initial_lines_fetch: 150,
            auto_reconnect: true,
            confirm_on_quit: true,
            close_to_tray: true,
            custom_browser: QString::default(),
            classic_mode: false,
            alternating_row_colors: true,
            auto_save_weechat_filters: true,
            active_filter_count: 0,
            filters_global_enabled: true,
            filter_save_status: QString::default(),
            active_buffer_ptr: QString::default(),
            active_buffer_name: QString::default(),
            active_buffer_server: QString::default(),
            active_buffer_type: QString::default(),
            active_buffer_topic: QString::default(),
            active_buffer_nick_count: 0,
            active_buffer_is_operator: false,
            active_buffer_has_older: false,
            total_unread_count: 0,
            total_highlight_count: 0,
            search_match_count: 0,
            active_server_id: QString::default(),
            active_server_name: QString::default(),
            active_server_has_password: false,
            buffer_model: Default::default(),
            message_model: Default::default(),
            nick_model: Default::default(),
            server_model: Default::default(),
            filter_model: Default::default(),
            connection_state_changed: Default::default(),
            error_message_changed: Default::default(),
            latency_changed: Default::default(),
            config_changed: Default::default(),
            preferences_changed: Default::default(),
            active_buffer_changed: Default::default(),
            nick_count_changed: Default::default(),
            hotlist_summary_changed: Default::default(),
            search_changed: Default::default(),
            new_message_arrived: Default::default(),
            active_server_changed: Default::default(),
            server_list_changed: Default::default(),
            filters_changed: Default::default(),
            filter_save_status_changed: Default::default(),
            init_controller: Default::default(),
            connect_to_relay: Default::default(),
            start_demo_mode: Default::default(),
            disconnect_relay: Default::default(),
            select_buffer: Default::default(),
            close_buffer: Default::default(),
            select_next_unread_buffer: Default::default(),
            select_next_buffer: Default::default(),
            select_previous_buffer: Default::default(),
            select_buffer_by_number: Default::default(),
            select_buffer_by_filtered_index: Default::default(),
            active_buffer_filtered_index: Default::default(),
            send_input: Default::default(),
            load_more_history: Default::default(),
            toggle_join_part_quit: Default::default(),
            set_show_join_part_quit: Default::default(),
            toggle_media_previews: Default::default(),
            set_show_media_previews: Default::default(),
            toggle_desktop_notifications: Default::default(),
            set_desktop_notifications: Default::default(),
            set_theme: Default::default(),
            set_font_size: Default::default(),
            set_initial_lines_fetch: Default::default(),
            set_timestamp_format: Default::default(),
            toggle_auto_reconnect: Default::default(),
            set_auto_reconnect: Default::default(),
            toggle_confirm_on_quit: Default::default(),
            set_confirm_on_quit: Default::default(),
            toggle_close_to_tray: Default::default(),
            set_close_to_tray: Default::default(),
            set_custom_browser: Default::default(),
            toggle_classic_mode: Default::default(),
            set_classic_mode: Default::default(),
            toggle_alternating_row_colors: Default::default(),
            set_alternating_row_colors: Default::default(),
            open_url: Default::default(),
            filter_buffers: Default::default(),
            search_in_buffer: Default::default(),
            complete_input: Default::default(),
            open_query_with_nick: Default::default(),
            whois_nick: Default::default(),
            play_with_mpv: Default::default(),
            resolve_media_stream: Default::default(),
            media_stream_resolved: Default::default(),
            media_stream_error: Default::default(),
            collapsed_servers_changed: Default::default(),
            is_server_collapsed: Default::default(),
            toggle_server_collapsed: Default::default(),
            set_server_collapsed: Default::default(),
            get_collapsed_servers: Default::default(),
            server_unread_count: Default::default(),
            server_highlight_count: Default::default(),
            server_buffer_count: Default::default(),
            load_servers: Default::default(),
            connect_server_profile: Default::default(),
            save_server_profile: Default::default(),
            delete_server_profile: Default::default(),
            get_saved_password_for_server: Default::default(),
            select_active_server: Default::default(),
            should_show_server_manager_on_startup: Default::default(),
            copy_to_clipboard: Default::default(),
            request_filters: Default::default(),
            toggle_weechat_filter: Default::default(),
            add_weechat_filter: Default::default(),
            delete_weechat_filter: Default::default(),
            toggle_all_filters: Default::default(),
            save_weechat_config: Default::default(),
            toggle_preset_filter: Default::default(),
            has_filter: Default::default(),
            is_filter_enabled: Default::default(),
            set_auto_save_weechat_filters: Default::default(),
            is_nick_muted: Default::default(),
            is_valid_nick_for_mute: Default::default(),
            toggle_mute_nick: Default::default(),
            cmd_tx: None,
            buffers_cache: Vec::new(),
            filters_cache: Vec::new(),
            filters_version: 0,
            buffer_filters_version: HashMap::new(),
            lines_cache: HashMap::new(),
            message_items_cache: HashMap::new(),
            nicks_cache: HashMap::new(),
            nick_items_cache: HashMap::new(),
            unread_map: HashMap::new(),
            buffer_filter_query: String::new(),
            message_search_query: String::new(),
            active_buffer_view_limit: 0,
            server_store: ServerStore::default(),
            sidebar_server_order: Vec::new(),
            collapsed_servers: HashSet::new(),
        };
        let cfg = AppConfig::load();
        controller.apply_config(&cfg);
        controller
    }
}

impl RelayController {
    pub fn apply_config(&mut self, cfg: &AppConfig) {
        self.saved_host = cfg.host.clone().into();
        self.saved_port = cfg.port as i32;
        self.saved_use_tls = cfg.use_tls;
        self.saved_verify_tls = cfg.verify_tls;
        self.show_join_part_quit = cfg.show_join_part_quit;
        self.auto_save_weechat_filters = cfg.auto_save_weechat_filters;
        self.show_media_previews = cfg.show_media_previews;
        self.desktop_notifications = cfg.desktop_notifications;
        self.theme_name = cfg.theme_name.clone().into();
        self.font_family = cfg.font_family.clone().into();
        self.font_size = cfg.font_size;
        self.timestamp_format = cfg.timestamp_format.clone().into();
        self.initial_lines_fetch = cfg.initial_lines_fetch;
        self.auto_reconnect = cfg.auto_reconnect;
        self.confirm_on_quit = cfg.confirm_on_quit;
        self.close_to_tray = cfg.close_to_tray;
        self.custom_browser = cfg.custom_browser.clone().into();
        self.classic_mode = cfg.classic_mode;
        self.alternating_row_colors = cfg.alternating_row_colors;
        self.sidebar_server_order = cfg.sidebar_server_order.clone();
        self.collapsed_servers = cfg.collapsed_servers.iter().cloned().collect();
        self.preferences_changed();
        self.config_changed();
        self.collapsed_servers_changed();
    }

    pub fn init_controller(&mut self) {
        let cfg = AppConfig::load();
        self.apply_config(&cfg);
        self.connection_state = "Disconnected".into();
        self.status_detail = "Select a server profile to connect".into();

        // Load Persistent Server Profiles
        self.server_store = ServerStore::load();
        if self.server_store.servers.is_empty() {
            // Migrate initial single config to first profile
            let default_profile = ServerProfile {
                id: uuid::Uuid::new_v4().to_string(),
                name: "Primary Relay".to_string(),
                host: cfg.host.clone(),
                port: cfg.port,
                use_tls: cfg.use_tls,
                verify_tls: cfg.verify_tls,
                save_password: true,
                auto_connect: false,
                totp: String::new(),
            };
            self.server_store.servers.push(default_profile);
            self.server_store.active_server_id = Some(self.server_store.servers[0].id.clone());
            self.server_store.save();
        }

        self.rebuild_server_model();

        if let Some(active) = self.server_store.get_active_or_first().cloned() {
            self.active_server_id = active.id.clone().into();
            self.active_server_name = active.name.clone().into();
            self.saved_host = active.host.clone().into();
            self.saved_port = active.port as i32;
            self.saved_use_tls = active.use_tls;
            self.saved_verify_tls = active.verify_tls;
            self.active_server_has_password = active.get_keyring_password().is_some();

            if active.auto_connect && self.active_server_has_password {
                let s_id = active.id.clone().into();
                self.connect_server_profile(s_id, QString::default());
            }
        }

        self.config_changed();
        self.preferences_changed();
        self.connection_state_changed();
        self.active_server_changed();
    }

    pub fn connect_to_relay(
        &mut self,
        host: QString,
        port: i32,
        password: QString,
        use_tls: bool,
        verify_tls: bool,
        totp: QString,
    ) {
        self.disconnect_relay();
        self.is_demo_mode = false;
        self.error_message = QString::default();
        self.error_message_changed();
        self.lines_cache.clear();
        self.message_items_cache.clear();
        self.buffer_filters_version.clear();
        self.unread_map.clear();
        self.nicks_cache.clear();
        self.nick_items_cache.clear();
        self.filters_cache.clear();
        self.filter_model.borrow_mut().reset_data(Vec::new());
        self.active_filter_count = 0;
        self.filters_changed();

        let host_str = host.to_string().trim().to_string();
        let port_u16 = (port.clamp(1, 65535)) as u16;

        // Save connection preferences
        self.saved_host = host_str.clone().into();
        self.saved_port = port_u16 as i32;
        self.saved_use_tls = use_tls;
        self.saved_verify_tls = verify_tls;
        self.save_current_config();
        self.config_changed();

        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel();
        let (event_tx, mut event_rx) = mpsc::unbounded_channel();
        self.cmd_tx = Some(cmd_tx);

        let initial_lines = if self.initial_lines_fetch > 0 {
            self.initial_lines_fetch as usize
        } else {
            150
        };
        let conn_cfg = ConnectionConfig {
            host: host_str,
            port: port_u16,
            password: password.to_string(),
            use_tls,
            verify_tls,
            totp: totp.to_string(),
            initial_lines,
        };

        let qptr = QPointer::from(&*self);
        let deliver_event = qmetaobject::queued_callback(move |ev: RelayEvent| {
            if let Some(this) = qptr.as_pinned() {
                this.borrow_mut().handle_relay_event(ev);
            }
        });

        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("Failed to build Tokio runtime");

            rt.block_on(async move {
                let forward_tx = event_tx.clone();
                let session_handle = tokio::spawn(async move {
                    if let Err(err) = run_relay_session(conn_cfg, cmd_rx, forward_tx.clone()).await
                    {
                        let _ = forward_tx.send(RelayEvent::Error(format!("{:#}", err)));
                    }
                });

                while let Some(ev) = event_rx.recv().await {
                    deliver_event(ev);
                }

                let _ = session_handle.await;
            });
        });
    }

    pub fn disconnect_relay(&mut self) {
        if let Some(tx) = self.cmd_tx.take() {
            let _ = tx.send(ClientCommand::Disconnect);
        }
        self.is_demo_mode = false;
        self.filters_cache.clear();
        self.filter_model.borrow_mut().reset_data(Vec::new());
        self.active_filter_count = 0;
        self.filters_changed();
        self.connection_state = "Disconnected".into();
        self.status_detail = "Disconnected".into();
        self.connection_state_changed();
    }

    fn max_buffer_lines(&self) -> usize {
        let init = if self.initial_lines_fetch > 0 {
            self.initial_lines_fetch as usize
        } else {
            150
        };
        (init * 10).clamp(1500, 5000)
    }

    fn max_view_lines(&self) -> usize {
        let init = if self.initial_lines_fetch > 0 {
            self.initial_lines_fetch as usize
        } else {
            150
        };
        init.clamp(100, 500)
    }

    fn min_visible_backlog(&self) -> usize {
        let init = if self.initial_lines_fetch > 0 {
            self.initial_lines_fetch as usize
        } else {
            150
        };
        init.clamp(40, 200)
    }

    fn merge_lines(&mut self, buffer_ptr: &str, new_lines: Vec<RelayLine>) {
        let norm_ptr = normalize_ptr(buffer_ptr);
        if norm_ptr.is_empty() || norm_ptr == "0x0" {
            return;
        }

        let max_lines = self.max_buffer_lines();
        let entry = self.lines_cache.entry(norm_ptr).or_default();
        if entry.is_empty() {
            *entry = new_lines;
            if entry.len() > max_lines {
                let excess = entry.len() - max_lines;
                entry.drain(0..excess);
            }
            return;
        }

        if new_lines.is_empty() {
            return;
        }

        for new_line in new_lines {
            let existing_idx = if !new_line.line_ptr.is_empty() && new_line.line_ptr != "0x0" {
                entry.iter().position(|l| l.line_ptr == new_line.line_ptr)
            } else {
                entry
                    .iter()
                    .rev()
                    .take(100)
                    .position(|existing| {
                        existing.timestamp == new_line.timestamp
                            && existing.prefix == new_line.prefix
                            && existing.message == new_line.message
                    })
                    .map(|rev_pos| entry.len() - 1 - rev_pos)
            };

            if let Some(idx) = existing_idx {
                entry[idx].displayed = new_line.displayed;
                entry[idx].highlight = new_line.highlight;
                entry[idx].notify_level = new_line.notify_level;
                entry[idx].tags = new_line.tags;
            } else {
                entry.push(new_line);
            }
        }

        entry.sort_by_key(|l| l.timestamp);

        if entry.len() > max_lines {
            let excess = entry.len() - max_lines;
            entry.drain(0..excess);
        }
    }

    pub fn handle_relay_event(&mut self, ev: RelayEvent) {
        match ev {
            RelayEvent::StateChanged { state, detail } => {
                self.connection_state = state.into();
                self.status_detail = detail.into();
                self.connection_state_changed();
            }
            RelayEvent::Connected { version } => {
                self.connection_state = "Connected".into();
                self.server_version = version.clone().into();
                self.status_detail = format!("Connected to WeeChat {}", version).into();
                self.error_message = QString::default();
                self.connection_state_changed();
                self.error_message_changed();
            }
            RelayEvent::Error(err) => {
                self.connection_state = "Error".into();
                self.status_detail = "Connection error".into();
                self.error_message = err.into();
                self.connection_state_changed();
                self.error_message_changed();
            }
            RelayEvent::BuffersListed(mut buffers) => {
                for b in &mut buffers {
                    b.ptr = normalize_ptr(&b.ptr);
                }
                self.buffers_cache = buffers;
                self.sort_buffers();
                self.rebuild_buffer_model();

                let active_norm = normalize_ptr(&self.active_buffer_ptr.to_string());
                let active_valid = !active_norm.is_empty()
                    && self.buffers_cache.iter().any(|b| b.ptr == active_norm);

                if !active_valid {
                    if let Some(first) = self
                        .buffers_cache
                        .iter()
                        .find(|b| b.buffer_type == "channel")
                        .or_else(|| self.buffers_cache.first())
                        .cloned()
                    {
                        self.select_buffer(first.ptr.into());
                    }
                } else {
                    self.select_buffer(active_norm.into());
                }

                // Queue background backlog pre-fetches and nicklist fetches for all non-active buffers
                // after the active buffer's backlog and nicklist have been requested first,
                // ensuring all channels populate their user lists and history on startup.
                let selected_norm = normalize_ptr(&self.active_buffer_ptr.to_string());
                let fetch_count = (self.initial_lines_fetch as usize).clamp(50, 2000);
                if let Some(tx) = &self.cmd_tx {
                    for b in &self.buffers_cache {
                        if b.ptr != selected_norm {
                            let _ = tx.send(ClientCommand::FetchBufferLines {
                                buffer_ptr: b.ptr.clone(),
                                count: fetch_count,
                            });
                            let is_channel = b.buffer_type == "channel"
                                || b.short_name.starts_with('#')
                                || b.short_name.starts_with('&')
                                || b.full_name.contains(".#")
                                || b.full_name.contains(".&");
                            if is_channel {
                                let _ = tx.send(ClientCommand::RequestNicklist {
                                    buffer_ptr: Some(b.ptr.clone()),
                                });
                            }
                        }
                    }
                }
            }
            RelayEvent::HotlistUpdated(map) => {
                let mut norm_map = HashMap::with_capacity(map.len());
                for (k, v) in map {
                    norm_map.insert(normalize_ptr(&k), v);
                }
                self.unread_map = norm_map;
                self.rebuild_buffer_model();
            }
            RelayEvent::FiltersFetched(filters) => {
                if let Some(f) = filters
                    .iter()
                    .find(|f| f.name.eq_ignore_ascii_case("join_part_quit"))
                {
                    let should_show = !f.enabled;
                    if self.show_join_part_quit != should_show {
                        self.show_join_part_quit = should_show;
                        self.preferences_changed();
                    }
                }
                self.filters_cache = filters.clone();
                self.rebuild_filter_model();
                self.active_filter_count = filters.iter().filter(|f| f.enabled).count() as i32;
                self.filters_changed();
                self.filters_version += 1;
                self.message_items_cache.clear();
                self.refetch_active_buffer_backlog();
            }
            RelayEvent::BufferLinesFetched {
                buffer_ptr,
                lines,
                prepend: _,
            } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                let is_current = !active_str.is_empty() && active_str == norm_ptr;
                let fetched_len = lines.len();
                self.merge_lines(&norm_ptr, lines);
                self.buffer_filters_version
                    .insert(norm_ptr.clone(), self.filters_version);
                let items = self.build_items_for_buffer(&norm_ptr);
                let visible_len = items.len();
                self.message_items_cache
                    .insert(norm_ptr.clone(), items);
                if is_current {
                    self.rebuild_message_model();
                    self.new_message_arrived();

                    // If WeeChat filters hid most of the fetched raw lines (e.g., 145 join/part
                    // lines out of 150 raw lines, leaving only 5 visible messages) and WeeChat
                    // likely has older lines in the buffer, automatically fetch a deeper window
                    // once so the channel history populates completely on startup.
                    let min_visible = self.min_visible_backlog();
                    let cached_raw = self
                        .lines_cache
                        .get(&norm_ptr)
                        .map(|l| l.len())
                        .unwrap_or(0);
                    let max_lines = self.max_buffer_lines();
                    let initial_req = (self.initial_lines_fetch as usize).max(50);
                    if visible_len < min_visible
                        && fetched_len >= initial_req
                        && cached_raw < max_lines
                        && let Some(tx) = &self.cmd_tx
                    {
                        let deeper_count = (cached_raw * 4).max(600).min(max_lines);
                        if deeper_count > cached_raw {
                            let _ = tx.send(ClientCommand::FetchBufferLines {
                                buffer_ptr: norm_ptr,
                                count: deeper_count,
                            });
                        }
                    }
                }
            }
            RelayEvent::LineAdded(mut line) => {
                line.buffer_ptr = normalize_ptr(&line.buffer_ptr);
                line.line_ptr = normalize_ptr(&line.line_ptr);
                let buf_ptr = line.buffer_ptr.clone();
                let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
                let is_active = !active_ptr.is_empty() && active_ptr == buf_ptr;
                let is_private = self
                    .buffers_cache
                    .iter()
                    .find(|b| b.ptr == buf_ptr)
                    .map(|b| b.buffer_type == "private")
                    .unwrap_or(false);

                // Trigger native Linux desktop notification on highlights or private messages
                if line.displayed && (line.highlight || is_private) && self.desktop_notifications {
                    let buf_name = self
                        .buffers_cache
                        .iter()
                        .find(|b| b.ptr == buf_ptr)
                        .map(|b| b.short_name.clone())
                        .unwrap_or_else(|| "WeeChat".to_string());
                    let sender = strip_weechat_formatting(&line.prefix);
                    let body = strip_weechat_formatting(&line.message);
                    let summary = format!("{} ({})", sender, buf_name);
                    std::thread::spawn(move || {
                        let _ = notify_rust::Notification::new()
                            .appname("WeeChat QML")
                            .summary(&summary)
                            .body(&body)
                            .show();
                    });
                }

                let max_lines = self.max_buffer_lines();
                let already_exists = {
                    let lines = self.lines_cache.entry(buf_ptr.clone()).or_default();
                    lines.iter().rev().take(50).any(|l| {
                        if !l.line_ptr.is_empty()
                            && l.line_ptr != "0x0"
                            && !line.line_ptr.is_empty()
                            && line.line_ptr != "0x0"
                        {
                            l.line_ptr == line.line_ptr
                        } else {
                            l.timestamp == line.timestamp
                                && l.prefix == line.prefix
                                && l.message == line.message
                        }
                    })
                };

                if !already_exists {
                    {
                        let lines = self.lines_cache.entry(buf_ptr.clone()).or_default();
                        lines.push(line.clone());
                        if lines.len() > max_lines {
                            let excess = lines.len() - max_lines;
                            lines.drain(0..excess);
                        }
                    }

                    if is_active {
                        if !self.is_line_filtered(&line, "") {
                            self.append_single_message_to_model(&line);
                            self.new_message_arrived();
                        }
                    } else if self.message_items_cache.contains_key(&buf_ptr)
                        && !self.is_line_filtered(&line, "")
                    {
                        let (mut prev_sender, mut prev_ts, mut prev_date_str) = {
                            let cached = self.message_items_cache.get(&buf_ptr).unwrap();
                            let mut s = String::new();
                            let mut ts = 0;
                            let mut d = String::new();
                            if let Some(last) = cached.last() {
                                if !self.classic_mode && !last.is_system && !last.is_action {
                                    s = last.prefix_plain.to_string();
                                    ts = last.timestamp;
                                }
                                d = format_date_header(last.timestamp);
                            }
                            (s, ts, d)
                        };
                        let mut match_count = 0;
                        let item = self.convert_line_to_item(
                            &line,
                            &mut prev_sender,
                            &mut prev_ts,
                            &mut prev_date_str,
                            &mut match_count,
                        );
                        if let Some(cached) = self.message_items_cache.get_mut(&buf_ptr) {
                            cached.push(item);
                            if cached.len() > max_lines {
                                let excess = cached.len() - max_lines;
                                cached.drain(0..excess);
                            }
                        }
                    }
                }

                if !is_active && (line.notify_level >= 1 || line.highlight || is_private) {
                    let entry = self.unread_map.entry(buf_ptr.clone()).or_insert((0, 0));
                    if line.notify_level >= 1 || line.highlight {
                        entry.0 += 1;
                    }
                    if line.highlight || is_private {
                        entry.1 += 1;
                    }
                    let (new_u, new_h) = *entry;
                    let mut updated_in_place = false;
                    {
                        let mut model = self.buffer_model.borrow_mut();
                        let count = model.row_count() as usize;
                        for i in 0..count {
                            if model[i].ptr.to_string() == buf_ptr {
                                let mut item = model[i].clone();
                                let delta_u = new_u - item.unread_count;
                                let delta_h = new_h - item.highlight_count;
                                item.unread_count = new_u;
                                item.highlight_count = new_h;
                                model.change_line(i, item);
                                self.total_unread_count += delta_u;
                                self.total_highlight_count += delta_h;
                                updated_in_place = true;
                                break;
                            }
                        }
                    }
                    if updated_in_place {
                        self.hotlist_summary_changed();
                    } else {
                        self.rebuild_buffer_model();
                    }
                }
            }
            RelayEvent::BufferOpened(mut buf) => {
                buf.ptr = normalize_ptr(&buf.ptr);
                let mut active_changed = false;
                if let Some(existing) = self.buffers_cache.iter_mut().find(|b| b.ptr == buf.ptr) {
                    if buf.number > 0 {
                        existing.number = buf.number;
                    }
                    if !buf.full_name.is_empty() {
                        existing.full_name = buf.full_name;
                    }
                    if !buf.short_name.is_empty() {
                        existing.short_name = buf.short_name;
                    }
                    if !buf.server_name.is_empty() {
                        existing.server_name = buf.server_name;
                    }
                    if !buf.buffer_type.is_empty() {
                        existing.buffer_type = buf.buffer_type;
                    }
                    if !buf.title.is_empty() {
                        existing.title = buf.title;
                    }
                    existing.notify_level = buf.notify_level;
                    existing.local_vars.extend(buf.local_vars);

                    let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                    if active_str == buf.ptr {
                        self.active_buffer_name = existing.short_name.clone().into();
                        self.active_buffer_server = existing.server_name.clone().into();
                        self.active_buffer_type = existing.buffer_type.clone().into();
                        let topic_fmt = format_weechat_message(&existing.title);
                        self.active_buffer_topic = topic_fmt.styled_text.into();
                        active_changed = true;
                    }
                } else {
                    self.buffers_cache.push(buf);
                }
                self.sort_buffers();
                self.rebuild_buffer_model();
                if active_changed {
                    self.active_buffer_changed();
                }
            }
            RelayEvent::BufferUpdated(mut buf) => {
                buf.ptr = normalize_ptr(&buf.ptr);
                let mut active_changed = false;
                if let Some(existing) = self.buffers_cache.iter_mut().find(|b| b.ptr == buf.ptr) {
                    if buf.number > 0 {
                        existing.number = buf.number;
                    }
                    if !buf.full_name.is_empty() {
                        existing.full_name = buf.full_name;
                    }
                    if !buf.short_name.is_empty() {
                        existing.short_name = buf.short_name;
                    }
                    if !buf.server_name.is_empty() {
                        existing.server_name = buf.server_name;
                    }
                    if !buf.buffer_type.is_empty() {
                        existing.buffer_type = buf.buffer_type;
                    }
                    if !buf.title.is_empty() {
                        existing.title = buf.title;
                    }
                    existing.notify_level = buf.notify_level;
                    existing.local_vars.extend(buf.local_vars);

                    let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                    if active_str == buf.ptr {
                        self.active_buffer_name = existing.short_name.clone().into();
                        self.active_buffer_server = existing.server_name.clone().into();
                        self.active_buffer_type = existing.buffer_type.clone().into();
                        let topic_fmt = format_weechat_message(&existing.title);
                        self.active_buffer_topic = topic_fmt.styled_text.into();
                        active_changed = true;
                    }
                } else {
                    self.buffers_cache.push(buf);
                }
                self.sort_buffers();
                self.rebuild_buffer_model();
                if active_changed {
                    self.active_buffer_changed();
                }
            }
            RelayEvent::BufferMoved { buffer_ptr, number } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                if number > 0
                    && let Some(b) = self.buffers_cache.iter_mut().find(|b| b.ptr == norm_ptr)
                {
                    b.number = number;
                }
                self.sort_buffers();
                self.rebuild_buffer_model();
            }
            RelayEvent::BufferRenamed {
                buffer_ptr,
                full_name,
                short_name,
            } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                let mut type_or_name_changed = false;
                if let Some(b) = self.buffers_cache.iter_mut().find(|b| b.ptr == norm_ptr) {
                    b.full_name = full_name;
                    b.short_name = if short_name.is_empty() {
                        extract_short_name(&b.full_name, "")
                    } else {
                        short_name
                    };
                    b.server_name = extract_server_name(&b.full_name, &b.local_vars);
                    b.buffer_type =
                        determine_buffer_type(&b.full_name, &b.short_name, &b.local_vars);
                    let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                    if active_str == norm_ptr {
                        self.active_buffer_name = b.short_name.clone().into();
                        self.active_buffer_server = b.server_name.clone().into();
                        self.active_buffer_type = b.buffer_type.clone().into();
                        type_or_name_changed = true;
                    }
                }
                self.sort_buffers();
                self.rebuild_buffer_model();
                if type_or_name_changed {
                    self.active_buffer_changed();
                }
            }
            RelayEvent::BufferLocalVarsUpdated {
                buffer_ptr,
                local_vars,
            } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                self.nick_items_cache.remove(&norm_ptr);
                let mut active_changed = false;
                if let Some(b) = self.buffers_cache.iter_mut().find(|b| b.ptr == norm_ptr) {
                    b.local_vars.extend(local_vars);
                    b.server_name = extract_server_name(&b.full_name, &b.local_vars);
                    b.buffer_type =
                        determine_buffer_type(&b.full_name, &b.short_name, &b.local_vars);
                    let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                    if active_str == norm_ptr {
                        self.active_buffer_server = b.server_name.clone().into();
                        self.active_buffer_type = b.buffer_type.clone().into();
                        active_changed = true;
                    }
                }
                self.sort_buffers();
                self.rebuild_buffer_model();
                if active_changed {
                    self.active_buffer_changed();
                }
            }
            RelayEvent::BufferTitleChanged { buffer_ptr, title } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                if let Some(b) = self.buffers_cache.iter_mut().find(|b| b.ptr == norm_ptr) {
                    b.title = title.clone();
                }
                let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                if active_str == norm_ptr {
                    let formatted = format_weechat_message(&title);
                    self.active_buffer_topic = formatted.styled_text.into();
                    self.active_buffer_changed();
                }
            }
            RelayEvent::BufferCleared { buffer_ptr } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                self.lines_cache.remove(&norm_ptr);
                self.message_items_cache.remove(&norm_ptr);
                let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                if active_str == norm_ptr {
                    self.rebuild_message_model();
                }
            }
            RelayEvent::BufferClosed {
                buffer_ptr,
                full_name,
            } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                let is_active = (!active_str.is_empty() && active_str == norm_ptr)
                    || (!full_name.is_empty()
                        && self
                            .buffers_cache
                            .iter()
                            .any(|b| b.full_name == full_name && b.ptr == active_str));

                let current_idx = self.buffers_cache.iter().position(|b| {
                    b.ptr == norm_ptr || (!full_name.is_empty() && b.full_name == full_name)
                });

                self.buffers_cache.retain(|b| {
                    b.ptr != norm_ptr && (full_name.is_empty() || b.full_name != full_name)
                });
                self.lines_cache.remove(&norm_ptr);
                self.message_items_cache.remove(&norm_ptr);
                self.nicks_cache.remove(&norm_ptr);
                self.nick_items_cache.remove(&norm_ptr);
                self.unread_map.remove(&norm_ptr);

                if is_active {
                    if !self.buffers_cache.is_empty() {
                        let next_idx = match current_idx {
                            Some(idx) => idx.min(self.buffers_cache.len() - 1),
                            None => 0,
                        };
                        let next_ptr = self.buffers_cache[next_idx].ptr.clone();
                        self.select_buffer(next_ptr.into());
                    } else {
                        self.active_buffer_ptr = QString::default();
                        self.active_buffer_name = QString::default();
                        self.active_buffer_server = QString::default();
                        self.active_buffer_topic = QString::default();
                        self.active_buffer_type = QString::default();
                        self.rebuild_message_model();
                        self.rebuild_nick_model();
                        self.active_buffer_changed();
                    }
                }

                self.rebuild_buffer_model();
            }
            RelayEvent::NicklistFull { buffer_ptr, nicks } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                self.nicks_cache.insert(norm_ptr.clone(), nicks);
                self.nick_items_cache.remove(&norm_ptr);
                let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                if active_str == norm_ptr {
                    self.rebuild_nick_model();
                }
            }
            RelayEvent::NicklistDiff { buffer_ptr, diffs } => {
                let norm_ptr = normalize_ptr(&buffer_ptr);
                let list = self.nicks_cache.entry(norm_ptr.clone()).or_default();
                for d in diffs {
                    match d.diff_op {
                        '+' => {
                            if !list.iter().any(|n| n.name == d.nick.name) {
                                list.push(d.nick);
                            }
                        }
                        '-' => {
                            list.retain(|n| n.name != d.nick.name);
                        }
                        '*' => {
                            if let Some(existing) = list.iter_mut().find(|n| n.name == d.nick.name)
                            {
                                *existing = d.nick;
                            }
                        }
                        _ => {}
                    }
                }
                self.nick_items_cache.remove(&norm_ptr);
                let active_str = normalize_ptr(&self.active_buffer_ptr.to_string());
                if active_str == norm_ptr {
                    self.rebuild_nick_model();
                }
            }
            RelayEvent::Pong { latency_ms } => {
                self.latency_ms = latency_ms;
                self.latency_changed();
            }
        }
    }

    pub fn load_servers(&mut self) {
        self.server_store = ServerStore::load();
        self.rebuild_server_model();
    }

    pub fn select_active_server(&mut self, server_id: QString) {
        let sid = server_id.to_string();
        if let Some(p) = self
            .server_store
            .servers
            .iter()
            .find(|s| s.id == sid)
            .cloned()
        {
            self.server_store.active_server_id = Some(sid);
            self.server_store.save();
            self.active_server_has_password = p.get_keyring_password().is_some();
            self.active_server_id = p.id.into();
            self.active_server_name = p.name.into();
            self.saved_host = p.host.into();
            self.saved_port = p.port as i32;
            self.saved_use_tls = p.use_tls;
            self.saved_verify_tls = p.verify_tls;
            self.config_changed();
            self.active_server_changed();
            self.rebuild_server_model();
        }
    }

    pub fn connect_server_profile(&mut self, server_id: QString, password_override: QString) {
        let sid = server_id.to_string();
        let maybe_profile = self
            .server_store
            .servers
            .iter()
            .find(|s| s.id == sid)
            .cloned();
        if let Some(p) = maybe_profile {
            self.select_active_server(server_id);
            let pwd = if !password_override.to_string().is_empty() {
                password_override.to_string()
            } else {
                p.get_keyring_password().unwrap_or_default()
            };

            self.connect_to_relay(
                p.host.into(),
                p.port as i32,
                pwd.into(),
                p.use_tls,
                p.verify_tls,
                p.totp.into(),
            );
        }
    }

    pub fn save_server_profile(
        &mut self,
        id: QString,
        name: QString,
        host: QString,
        port: i32,
        password: QString,
        use_tls: bool,
        verify_tls: bool,
        save_password: bool,
        auto_connect: bool,
        totp: QString,
    ) {
        let mut id_str = id.to_string().trim().to_string();
        if id_str.is_empty() {
            id_str = uuid::Uuid::new_v4().to_string();
        }

        let name_str = {
            let n = name.to_string().trim().to_string();
            if n.is_empty() { host.to_string() } else { n }
        };

        let profile = ServerProfile {
            id: id_str.clone(),
            name: name_str,
            host: host.to_string().trim().to_string(),
            port: (port.clamp(1, 65535)) as u16,
            use_tls,
            verify_tls,
            save_password,
            auto_connect,
            totp: totp.to_string().trim().to_string(),
        };

        let pwd_str = password.to_string();
        if save_password && !pwd_str.is_empty() {
            let _ = profile.set_keyring_password(&pwd_str);
        } else if !save_password {
            profile.delete_keyring_password();
        }

        if let Some(existing) = self
            .server_store
            .servers
            .iter_mut()
            .find(|s| s.id == id_str)
        {
            *existing = profile;
        } else {
            self.server_store.servers.push(profile);
        }

        self.server_store.active_server_id = Some(id_str.clone());
        self.server_store.save();
        self.rebuild_server_model();
        self.select_active_server(id_str.into());
    }

    pub fn delete_server_profile(&mut self, server_id: QString) {
        let sid = server_id.to_string();
        if let Some(p) = self.server_store.servers.iter().find(|s| s.id == sid) {
            p.delete_keyring_password();
        }
        self.server_store.servers.retain(|s| s.id != sid);
        if self.server_store.active_server_id.as_deref() == Some(&sid) {
            self.server_store.active_server_id =
                self.server_store.servers.first().map(|s| s.id.clone());
        }
        self.server_store.save();
        self.rebuild_server_model();

        if let Some(first) = self.server_store.get_active_or_first().cloned() {
            self.select_active_server(first.id.into());
        } else {
            self.active_server_id = QString::default();
            self.active_server_name = QString::default();
            self.active_server_changed();
        }
    }

    pub fn get_saved_password_for_server(&mut self, server_id: QString) -> QString {
        let sid = server_id.to_string();
        if let Some(p) = self.server_store.servers.iter().find(|s| s.id == sid) {
            return p.get_keyring_password().unwrap_or_default().into();
        }
        QString::default()
    }

    pub fn should_show_server_manager_on_startup(&self) -> bool {
        if let Some(active) = self.server_store.get_active_or_first() {
            !(active.auto_connect && self.active_server_has_password)
        } else {
            true
        }
    }

    pub fn copy_to_clipboard(&self, text: QString) {
        crate::copy_to_clipboard(&text.to_string());
    }

    // --- WeeChat Server-Side Filters ---

    pub fn rebuild_filter_model(&mut self) {
        let items: Vec<FilterItem> = self
            .filters_cache
            .iter()
            .map(|f| FilterItem {
                name: f.name.clone().into(),
                buffer: f.buffer.clone().into(),
                tags: f.tags.clone().into(),
                regex: f.regex.clone().into(),
                enabled: f.enabled,
            })
            .collect();
        self.filter_model.borrow_mut().reset_data(items);
    }

    pub fn request_filters(&mut self) {
        if let Some(tx) = &self.cmd_tx {
            let _ = tx.send(ClientCommand::RequestFilters);
        }
    }

    pub fn toggle_weechat_filter(&mut self, name: QString) {
        let name_str = name.to_string();
        if name_str.is_empty() {
            return;
        }
        if let Some(idx) = self
            .filters_cache
            .iter()
            .position(|f| f.name.eq_ignore_ascii_case(&name_str))
        {
            self.filters_cache[idx].enabled = !self.filters_cache[idx].enabled;
            self.active_filter_count =
                self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
            self.rebuild_filter_model();
            self.filters_changed();
        }
        self.send_input(format!("/filter toggle {}", name_str).into());
        if self.auto_save_weechat_filters {
            self.send_input("/save".into());
            self.filter_save_status = "Saved to WeeChat!".into();
            self.filter_save_status_changed();
        }
        self.filters_version += 1;
        self.message_items_cache.clear();
        self.refetch_active_buffer_backlog();
    }

    pub fn add_weechat_filter(
        &mut self,
        name: QString,
        buffer: QString,
        tags: QString,
        regex: QString,
    ) {
        let n = name.to_string().trim().to_string();
        let b = buffer.to_string().trim().to_string();
        let t = tags.to_string().trim().to_string();
        let r = regex.to_string().trim().to_string();
        if n.is_empty() {
            return;
        }
        let b = if b.is_empty() { "*".to_string() } else { b };
        let t = if t.is_empty() { "*".to_string() } else { t };
        let r = if r.is_empty() { "*".to_string() } else { r };

        if let Some(existing) = self
            .filters_cache
            .iter_mut()
            .find(|f| f.name.eq_ignore_ascii_case(&n))
        {
            existing.buffer = b.clone();
            existing.tags = t.clone();
            existing.regex = r.clone();
            existing.enabled = true;
        } else {
            self.filters_cache.push(RelayFilter {
                name: n.clone(),
                buffer: b.clone(),
                tags: t.clone(),
                regex: r.clone(),
                enabled: true,
            });
        }
        self.active_filter_count = self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
        self.rebuild_filter_model();
        self.filters_changed();

        self.send_input(format!("/filter add {} {} {} {}", n, b, t, r).into());
        if self.auto_save_weechat_filters {
            self.send_input("/save".into());
            self.filter_save_status = "Saved to WeeChat!".into();
            self.filter_save_status_changed();
        }
        self.filters_version += 1;
        self.message_items_cache.clear();
        self.refetch_active_buffer_backlog();
    }

    pub fn delete_weechat_filter(&mut self, name: QString) {
        let name_str = name.to_string();
        if name_str.is_empty() {
            return;
        }
        self.filters_cache
            .retain(|f| !f.name.eq_ignore_ascii_case(&name_str));
        self.active_filter_count = self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
        self.rebuild_filter_model();
        self.filters_changed();

        self.send_input(format!("/filter del {}", name_str).into());
        if self.auto_save_weechat_filters {
            self.send_input("/save".into());
            self.filter_save_status = "Saved to WeeChat!".into();
            self.filter_save_status_changed();
        }
        self.filters_version += 1;
        self.message_items_cache.clear();
        self.refetch_active_buffer_backlog();
    }

    pub fn toggle_all_filters(&mut self) {
        self.filters_global_enabled = !self.filters_global_enabled;
        self.send_input("/filter toggle".into());
        self.request_filters();
        self.filters_changed();
        self.filters_version += 1;
        self.message_items_cache.clear();
        self.rebuild_message_model();
        self.refetch_active_buffer_backlog();
    }

    pub fn save_weechat_config(&mut self) {
        self.send_input("/save".into());
        self.filter_save_status = "Saved to WeeChat!".into();
        self.filter_save_status_changed();
    }

    pub fn toggle_preset_filter(&mut self, preset_id: QString) {
        let id_str = preset_id.to_string();
        let (name, buffer, tags, regex, is_smart_filter) = match id_str.as_str() {
            "smart_filter" => ("irc_smart_filter", "*", "irc_smart_filter", "*", true),
            "join_part_quit" => (
                "join_part_quit",
                "*",
                "irc_join,irc_part,irc_quit",
                "*",
                false,
            ),
            "nick_changes" => ("nick_changes", "*", "irc_nick", "*", false),
            "channel_modes" => ("channel_modes", "*", "irc_mode", "*", false),
            "topic_changes" => ("topic_changes", "*", "irc_topic", "*", false),
            "service_bots" => (
                "service_bots",
                "*",
                "nick_chanserv,nick_nickserv",
                "*",
                false,
            ),
            _ => return,
        };

        if is_smart_filter {
            self.send_input("/set irc.look.smart_filter on".into());
        }

        let existing_idx = self
            .filters_cache
            .iter()
            .position(|f| f.name.eq_ignore_ascii_case(name));

        if let Some(idx) = existing_idx {
            self.filters_cache[idx].enabled = !self.filters_cache[idx].enabled;
            let filter_name = self.filters_cache[idx].name.clone();
            self.send_input(format!("/filter toggle {}", filter_name).into());
        } else {
            self.filters_cache.push(RelayFilter {
                name: name.to_string(),
                buffer: buffer.to_string(),
                tags: tags.to_string(),
                regex: regex.to_string(),
                enabled: true,
            });
            self.send_input(format!("/filter add {} {} {} {}", name, buffer, tags, regex).into());
        }

        self.active_filter_count = self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
        self.rebuild_filter_model();
        self.filters_changed();

        if self.auto_save_weechat_filters {
            self.send_input("/save".into());
            self.filter_save_status = "Saved to WeeChat!".into();
            self.filter_save_status_changed();
        }

        self.filters_version += 1;
        self.message_items_cache.clear();
        self.refetch_active_buffer_backlog();
    }

    pub fn has_filter(&self, name: QString) -> bool {
        let n = name.to_string();
        self.filters_cache
            .iter()
            .any(|f| f.name.eq_ignore_ascii_case(&n))
    }

    pub fn is_filter_enabled(&self, name: QString) -> bool {
        let n = name.to_string();
        self.filters_cache
            .iter()
            .find(|f| f.name.eq_ignore_ascii_case(&n))
            .map(|f| f.enabled)
            .unwrap_or(false)
    }

    pub fn set_auto_save_weechat_filters(&mut self, enabled: bool) {
        self.auto_save_weechat_filters = enabled;
        let mut cfg = AppConfig::load();
        cfg.auto_save_weechat_filters = enabled;
        cfg.save();
        self.preferences_changed();
    }

    pub fn is_valid_nick_for_mute(&self, nick: QString) -> bool {
        is_valid_nick_for_mute_str(&nick.to_string())
    }

    pub fn is_nick_muted(&self, nick: QString) -> bool {
        let clean = clean_nickname_for_filter(&nick.to_string());
        if clean.is_empty() {
            return false;
        }
        let filter_name = mute_filter_name(&clean);
        let tag_match = format!("nick_{}", clean);
        let tag_match_lower = format!("nick_{}", clean.to_lowercase());

        self.filters_cache.iter().any(|f| {
            f.enabled
                && (f.name.eq_ignore_ascii_case(&filter_name)
                    || f.tags.split(',').any(|t| {
                        let t = t.trim();
                        t.eq_ignore_ascii_case(&tag_match)
                            || t.eq_ignore_ascii_case(&tag_match_lower)
                    }))
        })
    }

    pub fn toggle_mute_nick(&mut self, nick: QString) {
        let clean = clean_nickname_for_filter(&nick.to_string());
        if clean.is_empty() || !is_valid_nick_for_mute_str(&clean) {
            return;
        }
        let clean_lower = clean.to_lowercase();
        let filter_name = mute_filter_name(&clean);
        let tag_match = format!("nick_{}", clean);
        let tag_match_lower = format!("nick_{}", clean_lower);

        let is_currently_muted = self.is_nick_muted(nick);

        if is_currently_muted {
            if let Some(idx) = self.filters_cache.iter().position(|f| {
                f.name.eq_ignore_ascii_case(&filter_name)
                    || f.tags.split(',').any(|t| {
                        let t = t.trim();
                        t.eq_ignore_ascii_case(&tag_match)
                            || t.eq_ignore_ascii_case(&tag_match_lower)
                    })
            }) {
                self.filters_cache[idx].enabled = false;
                let name_to_toggle = self.filters_cache[idx].name.clone();
                self.active_filter_count =
                    self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
                self.rebuild_filter_model();
                self.filters_changed();
                self.send_input(format!("/filter toggle {}", name_to_toggle).into());
                if self.auto_save_weechat_filters {
                    self.send_input("/save".into());
                    self.filter_save_status = "Saved to WeeChat!".into();
                    self.filter_save_status_changed();
                }
            }
        } else {
            let existing_idx = self.filters_cache.iter().position(|f| {
                f.name.eq_ignore_ascii_case(&filter_name)
                    || f.tags.split(',').any(|t| {
                        let t = t.trim();
                        t.eq_ignore_ascii_case(&tag_match)
                            || t.eq_ignore_ascii_case(&tag_match_lower)
                    })
            });

            if let Some(idx) = existing_idx {
                self.filters_cache[idx].enabled = true;
                let name_to_toggle = self.filters_cache[idx].name.clone();
                self.active_filter_count =
                    self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
                self.rebuild_filter_model();
                self.filters_changed();
                self.send_input(format!("/filter toggle {}", name_to_toggle).into());
            } else {
                let tags = if clean.eq_ignore_ascii_case(&clean_lower) {
                    format!("nick_{}", clean_lower)
                } else {
                    format!("nick_{},nick_{}", clean, clean_lower)
                };
                self.filters_cache.push(RelayFilter {
                    name: filter_name.clone(),
                    buffer: "*".to_string(),
                    tags: tags.clone(),
                    regex: "*".to_string(),
                    enabled: true,
                });
                self.active_filter_count =
                    self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
                self.rebuild_filter_model();
                self.filters_changed();
                self.send_input(format!("/filter add {} * {} *", filter_name, tags).into());
            }

            if self.auto_save_weechat_filters {
                self.send_input("/save".into());
                self.filter_save_status = "Saved to WeeChat!".into();
                self.filter_save_status_changed();
            }
        }

        self.filters_version += 1;
        self.message_items_cache.clear();
        self.refetch_active_buffer_backlog();
    }

    fn refetch_active_buffer_backlog(&self) {
        let active = normalize_ptr(&self.active_buffer_ptr.to_string());
        if let (false, Some(tx)) = (active.is_empty(), &self.cmd_tx) {
            let current_raw = self.lines_cache.get(&active).map(|l| l.len()).unwrap_or(0);
            let visible_count = self
                .lines_cache
                .get(&active)
                .map(|lines| lines.iter().filter(|l| !self.is_line_filtered(l, "")).count())
                .unwrap_or(0);
            let min_visible = self.min_visible_backlog();
            let base_count = current_raw
                .max(self.initial_lines_fetch as usize)
                .clamp(50, 2000);
            let count = if current_raw >= 50 && visible_count < min_visible {
                (base_count * 4).max(600).min(self.max_buffer_lines())
            } else {
                base_count
            };
            let _ = tx.send(ClientCommand::FetchBufferLines {
                buffer_ptr: active,
                count,
            });
        }
    }

    fn is_line_filtered(&self, line: &RelayLine, _buf_full_name: &str) -> bool {
        if !self.filters_global_enabled {
            return false;
        }
        !line.displayed
    }

    fn rebuild_server_model(&mut self) {
        let active_id = self.server_store.active_server_id.as_deref().unwrap_or("");
        let items: Vec<ServerProfileItem> = self
            .server_store
            .servers
            .iter()
            .map(|s| {
                let has_pwd = s.get_keyring_password().is_some();
                ServerProfileItem {
                    id: s.id.clone().into(),
                    name: s.name.clone().into(),
                    host: s.host.clone().into(),
                    port: s.port as i32,
                    use_tls: s.use_tls,
                    verify_tls: s.verify_tls,
                    save_password: s.save_password,
                    auto_connect: s.auto_connect,
                    totp: s.totp.clone().into(),
                    is_active: s.id == active_id,
                    has_saved_password: has_pwd,
                }
            })
            .collect();

        self.server_model.borrow_mut().reset_data(items);
        self.server_list_changed();
    }

    pub fn select_buffer(&mut self, buffer_ptr: QString) {
        let ptr_str = buffer_ptr.to_string();
        if ptr_str.is_empty() {
            return;
        }
        let norm_ptr = normalize_ptr(&ptr_str);
        let prev_active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());

        self.active_buffer_ptr = norm_ptr.clone().into();
        self.active_buffer_view_limit = self.max_view_lines();
        let had_unread = self.unread_map.remove(&norm_ptr);

        if let Some(buf) = self.buffers_cache.iter().find(|b| b.ptr == norm_ptr) {
            self.active_buffer_name = buf.short_name.clone().into();
            self.active_buffer_server = buf.server_name.clone().into();
            self.active_buffer_type = buf.buffer_type.clone().into();
            let topic_fmt = format_weechat_message(&buf.title);
            self.active_buffer_topic = topic_fmt.styled_text.into();

            // Auto-expand server section if collapsed so the selected channel is immediately visible
            let srv_name = buf.server_name.clone();
            let was_collapsed = self
                .collapsed_servers
                .iter()
                .any(|s| s.eq_ignore_ascii_case(&srv_name));
            if was_collapsed {
                self.collapsed_servers
                    .retain(|s| !s.eq_ignore_ascii_case(&srv_name));
                self.collapsed_servers_changed();
                self.save_current_config();
            }
        }

        // If lines are not yet cached or empty, if filters changed since last fetch,
        // or if filtered lines left the visible backlog sparse despite a full initial fetch, fetch backlog
        let raw_len = self
            .lines_cache
            .get(&norm_ptr)
            .map(|l| l.len())
            .unwrap_or(0);
        let visible_len = self
            .lines_cache
            .get(&norm_ptr)
            .map(|lines| lines.iter().filter(|l| !self.is_line_filtered(l, "")).count())
            .unwrap_or(0);
        let min_visible = self.min_visible_backlog();
        let initial_req = (self.initial_lines_fetch as usize).max(50);
        let sparse_due_to_filters = raw_len >= initial_req
            && visible_len < min_visible
            && raw_len < 600.min(self.max_buffer_lines());
        let needs_fetch = raw_len == 0
            || self.buffer_filters_version.get(&norm_ptr) != Some(&self.filters_version)
            || sparse_due_to_filters;
        if needs_fetch && let Some(tx) = &self.cmd_tx {
            let base_count = raw_len
                .max(self.initial_lines_fetch as usize)
                .clamp(50, 2000);
            let fetch_count = if raw_len >= initial_req && visible_len < min_visible {
                (base_count * 4).max(600).min(self.max_buffer_lines())
            } else {
                base_count
            };
            let _ = tx.send(ClientCommand::FetchBufferLines {
                buffer_ptr: norm_ptr.clone(),
                count: fetch_count,
            });
        }

        if let Some(tx) = &self.cmd_tx {
            let _ = tx.send(ClientCommand::MarkBufferRead {
                buffer_ptr: norm_ptr.clone(),
            });

            // If nicks are not yet cached or empty for a channel, request nicklist
            let is_channel = self.active_buffer_type.to_string() == "channel"
                || self
                    .buffers_cache
                    .iter()
                    .find(|b| b.ptr == norm_ptr)
                    .map(|b| {
                        b.buffer_type == "channel"
                            || b.short_name.starts_with('#')
                            || b.short_name.starts_with('&')
                            || b.full_name.contains(".#")
                            || b.full_name.contains(".&")
                    })
                    .unwrap_or(false);
            let needs_nicks = self
                .nicks_cache
                .get(&norm_ptr)
                .map(|n| n.is_empty())
                .unwrap_or(true);
            if needs_nicks && is_channel {
                let _ = tx.send(ClientCommand::RequestNicklist {
                    buffer_ptr: Some(norm_ptr.clone()),
                });
            }
        }

        // Fast O(1) in-place update on buffer_model if already populated
        let mut updated_in_place = false;
        {
            let mut model = self.buffer_model.borrow_mut();
            let count = model.row_count() as usize;
            if count > 0 {
                for i in 0..count {
                    let row_ptr = model[i].ptr.to_string();
                    if row_ptr == prev_active_ptr && prev_active_ptr != norm_ptr {
                        let mut item = model[i].clone();
                        if item.is_active {
                            item.is_active = false;
                            model.change_line(i, item);
                        }
                    } else if row_ptr == norm_ptr {
                        let mut item = model[i].clone();
                        item.is_active = true;
                        item.unread_count = 0;
                        item.highlight_count = 0;
                        model.change_line(i, item);
                        updated_in_place = true;
                    }
                }
            }
        }
        if updated_in_place {
            if let Some((u, h)) = had_unread {
                self.total_unread_count = (self.total_unread_count - u).max(0);
                self.total_highlight_count = (self.total_highlight_count - h).max(0);
                self.hotlist_summary_changed();
            }
        } else {
            self.rebuild_buffer_model();
        }

        self.rebuild_message_model();
        self.rebuild_nick_model();
        self.active_buffer_changed();
    }

    pub fn close_buffer(&mut self, buffer_ptr: QString) {
        let ptr_str = buffer_ptr.to_string();
        let target_ptr = if ptr_str.is_empty() {
            normalize_ptr(&self.active_buffer_ptr.to_string())
        } else {
            normalize_ptr(&ptr_str)
        };
        if target_ptr.is_empty() || target_ptr == "0x0" {
            return;
        }
        if let Some(tx) = &self.cmd_tx {
            let _ = tx.send(ClientCommand::SendInput {
                buffer_ptr: target_ptr,
                text: "/close".to_string(),
            });
        }
    }

    pub fn select_next_unread_buffer(&mut self) {
        if self.buffers_cache.is_empty() {
            return;
        }
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        let current_idx = self
            .buffers_cache
            .iter()
            .position(|b| b.ptr == active_ptr)
            .unwrap_or(0);

        let count = self.buffers_cache.len();
        // Check buffers cyclically starting from the one right after the current active buffer
        let ordered_indices: Vec<usize> = (1..=count)
            .map(|offset| (current_idx + offset) % count)
            .collect();

        // 1. Prioritize chat channels & private queries with highlights (mentions) first
        let highlight_channel = ordered_indices
            .iter()
            .map(|&idx| &self.buffers_cache[idx])
            .find(|b| {
                b.ptr != active_ptr
                    && b.buffer_type != "server"
                    && self
                        .unread_map
                        .get(&b.ptr)
                        .map(|u| u.1 > 0)
                        .unwrap_or(false)
            });

        // 2. Any other buffer with highlights
        let any_highlight = highlight_channel.or_else(|| {
            ordered_indices
                .iter()
                .map(|&idx| &self.buffers_cache[idx])
                .find(|b| {
                    b.ptr != active_ptr
                        && self
                            .unread_map
                            .get(&b.ptr)
                            .map(|u| u.1 > 0)
                            .unwrap_or(false)
                })
        });

        // 3. Prioritize chat channels & private queries with regular unread messages
        let unread_channel = any_highlight.or_else(|| {
            ordered_indices
                .iter()
                .map(|&idx| &self.buffers_cache[idx])
                .find(|b| {
                    b.ptr != active_ptr
                        && b.buffer_type != "server"
                        && self
                            .unread_map
                            .get(&b.ptr)
                            .map(|u| u.0 > 0)
                            .unwrap_or(false)
                })
        });

        // 4. Any other buffer with regular unread messages
        let target_buf = unread_channel.or_else(|| {
            ordered_indices
                .iter()
                .map(|&idx| &self.buffers_cache[idx])
                .find(|b| {
                    b.ptr != active_ptr
                        && self
                            .unread_map
                            .get(&b.ptr)
                            .map(|u| u.0 > 0)
                            .unwrap_or(false)
                })
        });

        if let Some(buf) = target_buf.cloned() {
            self.select_buffer(buf.ptr.into());
        }
    }

    pub fn select_next_buffer(&mut self) {
        if self.buffers_cache.is_empty() {
            return;
        }
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        let current_idx = self
            .buffers_cache
            .iter()
            .position(|b| b.ptr == active_ptr)
            .unwrap_or(0);
        let next_idx = (current_idx + 1) % self.buffers_cache.len();
        let target_ptr = self.buffers_cache[next_idx].ptr.clone();
        self.select_buffer(target_ptr.into());
    }

    pub fn select_previous_buffer(&mut self) {
        if self.buffers_cache.is_empty() {
            return;
        }
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        let current_idx = self
            .buffers_cache
            .iter()
            .position(|b| b.ptr == active_ptr)
            .unwrap_or(0);
        let prev_idx = if current_idx == 0 {
            self.buffers_cache.len().saturating_sub(1)
        } else {
            current_idx - 1
        };
        let target_ptr = self.buffers_cache[prev_idx].ptr.clone();
        self.select_buffer(target_ptr.into());
    }

    pub fn select_buffer_by_number(&mut self, number: i32) {
        if let Some(buf) = self
            .buffers_cache
            .iter()
            .find(|b| b.number == number)
            .cloned()
        {
            self.select_buffer(buf.ptr.into());
        }
    }

    pub fn select_buffer_by_filtered_index(&mut self, index: i32) -> bool {
        if index < 0 {
            return false;
        }
        let ptr = {
            let model = self.buffer_model.borrow();
            model
                .iter()
                .nth(index as usize)
                .map(|item| item.ptr.clone())
        };
        if let Some(ptr) = ptr {
            self.select_buffer(ptr);
            true
        } else {
            false
        }
    }

    pub fn active_buffer_filtered_index(&self) -> i32 {
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        if active_ptr.is_empty() {
            return -1;
        }
        let model = self.buffer_model.borrow();
        for (idx, item) in model.iter().enumerate() {
            if item.is_active || normalize_ptr(&item.ptr.to_string()) == active_ptr {
                return idx as i32;
            }
        }
        -1
    }

    pub fn send_input(&mut self, text: QString) {
        let raw = text.to_string();
        if raw.trim().is_empty() {
            return;
        }
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        let target_buf = if active_ptr.is_empty() || active_ptr == "0x0" {
            self.buffers_cache
                .first()
                .map(|b| b.ptr.clone())
                .unwrap_or_else(|| "core.weechat".to_string())
        } else {
            active_ptr
        };

        if let Some(tx) = &self.cmd_tx {
            let _ = tx.send(ClientCommand::SendInput {
                buffer_ptr: target_buf,
                text: raw,
            });
        }
    }

    pub fn load_more_history(&mut self) {
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        if active_ptr.is_empty() || active_ptr == "0x0" {
            return;
        }
        let view_limit = if self.active_buffer_view_limit > 0 {
            self.active_buffer_view_limit
        } else {
            self.max_view_lines()
        };
        let next_view_limit = (view_limit + 150).min(self.max_buffer_lines());
        self.active_buffer_view_limit = next_view_limit;

        let cached_count = self
            .message_items_cache
            .get(&active_ptr)
            .map(|c| c.len())
            .unwrap_or(0);
        if cached_count > view_limit {
            self.rebuild_message_model();
            if cached_count >= next_view_limit {
                return;
            }
        }

        let current_len = self
            .lines_cache
            .get(&active_ptr)
            .map(|l| l.len())
            .unwrap_or(100);
        let next_count = (current_len + 150).min(self.max_buffer_lines());
        if let Some(tx) = &self.cmd_tx {
            let _ = tx.send(ClientCommand::FetchBufferLines {
                buffer_ptr: active_ptr,
                count: next_count,
            });
        }
    }

    pub fn toggle_join_part_quit(&mut self) {
        self.set_show_join_part_quit(!self.show_join_part_quit);
    }

    pub fn set_show_join_part_quit(&mut self, enabled: bool) {
        self.show_join_part_quit = enabled;
        self.save_current_config();
        self.preferences_changed();

        let has_filter = self
            .filters_cache
            .iter()
            .any(|f| f.name.eq_ignore_ascii_case("join_part_quit"));
        let is_enabled = self
            .filters_cache
            .iter()
            .any(|f| f.name.eq_ignore_ascii_case("join_part_quit") && f.enabled);

        if !enabled {
            if !is_enabled {
                if has_filter {
                    self.send_input("/filter toggle join_part_quit".into());
                } else {
                    self.send_input(
                        "/filter add join_part_quit * irc_join,irc_part,irc_quit *".into(),
                    );
                }
                if let Some(f) = self
                    .filters_cache
                    .iter_mut()
                    .find(|f| f.name.eq_ignore_ascii_case("join_part_quit"))
                {
                    f.enabled = true;
                } else {
                    self.filters_cache.push(RelayFilter {
                        name: "join_part_quit".to_string(),
                        buffer: "*".to_string(),
                        tags: "irc_join,irc_part,irc_quit".to_string(),
                        regex: "*".to_string(),
                        enabled: true,
                    });
                }
                self.active_filter_count =
                    self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
                self.rebuild_filter_model();
                self.filters_changed();
                if self.auto_save_weechat_filters {
                    self.send_input("/save".into());
                }
            }
        } else {
            if is_enabled {
                self.send_input("/filter toggle join_part_quit".into());
                if let Some(f) = self
                    .filters_cache
                    .iter_mut()
                    .find(|f| f.name.eq_ignore_ascii_case("join_part_quit"))
                {
                    f.enabled = false;
                }
                self.active_filter_count =
                    self.filters_cache.iter().filter(|f| f.enabled).count() as i32;
                self.rebuild_filter_model();
                self.filters_changed();
                if self.auto_save_weechat_filters {
                    self.send_input("/save".into());
                }
            }
        }

        self.filters_version += 1;
        self.message_items_cache.clear();
        self.refetch_active_buffer_backlog();
    }

    pub fn toggle_media_previews(&mut self) {
        self.set_show_media_previews(!self.show_media_previews);
    }

    pub fn set_show_media_previews(&mut self, enabled: bool) {
        self.show_media_previews = enabled;
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn toggle_desktop_notifications(&mut self) {
        self.set_desktop_notifications(!self.desktop_notifications);
    }

    pub fn set_desktop_notifications(&mut self, enabled: bool) {
        self.desktop_notifications = enabled;
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn set_theme(&mut self, theme: QString) {
        self.theme_name = theme;
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn set_font_size(&mut self, size: i32) {
        self.font_size = size.clamp(10, 24);
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn set_initial_lines_fetch(&mut self, count: i32) {
        self.initial_lines_fetch = count.clamp(20, 1000);
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn set_timestamp_format(&mut self, format: QString) {
        self.timestamp_format = format;
        self.save_current_config();
        self.preferences_changed();
        self.message_items_cache.clear();
        self.rebuild_message_model();
    }

    pub fn toggle_auto_reconnect(&mut self) {
        self.set_auto_reconnect(!self.auto_reconnect);
    }

    pub fn set_auto_reconnect(&mut self, enabled: bool) {
        self.auto_reconnect = enabled;
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn toggle_confirm_on_quit(&mut self) {
        self.set_confirm_on_quit(!self.confirm_on_quit);
    }

    pub fn set_confirm_on_quit(&mut self, enabled: bool) {
        self.confirm_on_quit = enabled;
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn toggle_close_to_tray(&mut self) {
        self.set_close_to_tray(!self.close_to_tray);
    }

    pub fn set_close_to_tray(&mut self, enabled: bool) {
        self.close_to_tray = enabled;
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn set_custom_browser(&mut self, browser: QString) {
        self.custom_browser = browser.to_string().trim().into();
        self.save_current_config();
        self.preferences_changed();
    }

    pub fn toggle_classic_mode(&mut self) {
        self.set_classic_mode(!self.classic_mode);
    }

    pub fn set_classic_mode(&mut self, enabled: bool) {
        self.classic_mode = enabled;
        self.save_current_config();
        self.preferences_changed();
        self.message_items_cache.clear();
        self.rebuild_message_model();
    }

    pub fn toggle_alternating_row_colors(&mut self) {
        self.set_alternating_row_colors(!self.alternating_row_colors);
    }

    pub fn set_alternating_row_colors(&mut self, enabled: bool) {
        if self.alternating_row_colors != enabled {
            self.alternating_row_colors = enabled;
            self.save_current_config();
            self.preferences_changed();
        }
    }

    pub fn open_url(&self, url: QString) {
        let u = url.to_string();
        if u.is_empty() {
            return;
        }
        let browser = self.custom_browser.to_string();
        std::thread::spawn(move || {
            open_url_with_browser(&u, &browser);
        });
    }

    pub fn filter_buffers(&mut self, query: QString) {
        self.buffer_filter_query = query.to_string().trim().to_lowercase();
        self.rebuild_buffer_model();
    }

    pub fn search_in_buffer(&mut self, query: QString) {
        self.message_search_query = query.to_string().to_lowercase();
        self.message_items_cache.clear();
        self.rebuild_message_model();
    }

    pub fn open_query_with_nick(&mut self, nick: QString) {
        let nick_str = nick.to_string();
        if nick_str.is_empty() {
            return;
        }
        // Check if buffer already exists
        if let Some(existing) = self
            .buffers_cache
            .iter()
            .find(|b| b.short_name.eq_ignore_ascii_case(&nick_str))
            .cloned()
        {
            self.select_buffer(existing.ptr.into());
            return;
        }
        self.send_input(format!("/query {}", nick_str).into());
    }

    pub fn whois_nick(&mut self, nick: QString) {
        let nick_str = nick.to_string();
        if !nick_str.is_empty() {
            self.send_input(format!("/whois {}", nick_str).into());
        }
    }

    pub fn play_with_mpv(&mut self, url: QString) {
        let u = url.to_string();
        if u.is_empty() {
            return;
        }
        let browser = self.custom_browser.to_string();
        std::thread::spawn(move || {
            let res = std::process::Command::new("mpv").arg(&u).spawn();
            if res.is_err() {
                open_url_with_browser(&u, &browser);
            }
        });
    }

    pub fn resolve_media_stream(&mut self, media_url: QString, target_id: QString) {
        let u = media_url.to_string();
        let tid = target_id.to_string();
        if u.is_empty() {
            return;
        }

        let qptr = QPointer::from(&*self);
        let on_resolved =
            qmetaobject::queued_callback(move |(id, stream, audio): (String, String, String)| {
                if let Some(this) = qptr.as_pinned() {
                    this.borrow()
                        .media_stream_resolved(id.into(), stream.into(), audio.into());
                }
            });
        let qptr2 = QPointer::from(&*self);
        let on_error = qmetaobject::queued_callback(move |(id, err): (String, String)| {
            if let Some(this) = qptr2.as_pinned() {
                this.borrow().media_stream_error(id.into(), err.into());
            }
        });

        std::thread::spawn(move || {
            let output = std::process::Command::new("yt-dlp")
                .args([
                    "--no-warnings",
                    "--no-playlist",
                    "-g",
                    "-f",
                    "best[acodec!=none][vcodec!=none]/bestvideo[height<=720]+bestaudio/bestvideo+bestaudio/best[height<=720]/best/b*[height<=720]/b*",
                    &u,
                ])
                .output();

            match output {
                Ok(out) if out.status.success() => {
                    let stdout_str = String::from_utf8_lossy(&out.stdout);
                    let mut lines = stdout_str
                        .lines()
                        .map(|l| l.trim().to_string())
                        .filter(|l| !l.is_empty());

                    let video_stream = lines.next().unwrap_or_default();
                    let audio_stream = lines.next().unwrap_or_default();

                    if !video_stream.is_empty() {
                        on_resolved((tid, video_stream, audio_stream));
                    } else {
                        on_error((tid, "yt-dlp returned an empty stream URL".to_string()));
                    }
                }
                Ok(out) => {
                    let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
                    let msg = if err.is_empty() {
                        "yt-dlp failed to resolve stream URL".to_string()
                    } else {
                        // Extract first non-empty line or the line containing ERROR:
                        err.lines()
                            .find(|l| l.contains("ERROR:"))
                            .or_else(|| err.lines().find(|l| !l.trim().is_empty()))
                            .unwrap_or(&err)
                            .trim()
                            .to_string()
                    };
                    on_error((tid, msg));
                }
                Err(e) => {
                    let err = format!("yt-dlp not available: {}", e);
                    on_error((tid, err));
                }
            }
        });
    }

    pub fn complete_input(&mut self, text: QString, cursor_pos: i32) -> QString {
        let input = text.to_string();
        let cursor = (cursor_pos.max(0) as usize).min(input.len());
        let before = &input[..cursor];
        let after = &input[cursor..];

        let word_start = before
            .rfind(|c: char| c.is_whitespace())
            .map(|idx| idx + 1)
            .unwrap_or(0);
        let prefix_word = &before[word_start..];
        if prefix_word.is_empty() {
            return text;
        }

        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());

        // Slash command completion at start of line
        if word_start == 0 && prefix_word.starts_with('/') {
            let commands = [
                "/join ", "/part ", "/msg ", "/query ", "/whois ", "/nick ", "/topic ", "/me ",
                "/away ", "/clear", "/close", "/buffer ", "/help", "/quit",
            ];
            let lower = prefix_word.to_lowercase();
            if let Some(cmd) = commands.iter().find(|c| c.starts_with(&lower)) {
                return format!("{}{}", cmd, after).into();
            }
            return text;
        }

        let clean_prefix = prefix_word.trim_start_matches('@').to_lowercase();
        let nicks = self.nicks_cache.get(&active_ptr);
        let mut candidates: Vec<String> = nicks
            .map(|list| {
                list.iter()
                    .filter(|n| n.name.to_lowercase().starts_with(&clean_prefix))
                    .map(|n| n.name.clone())
                    .collect()
            })
            .unwrap_or_default();

        if candidates.is_empty() {
            return text;
        }
        candidates.sort_by_key(|a| a.to_lowercase());

        let chosen = &candidates[0];
        let replacement = if word_start == 0 {
            format!("{}: ", chosen)
        } else if prefix_word.starts_with('@') {
            format!("@{} ", chosen)
        } else {
            format!("{} ", chosen)
        };

        format!("{}{}{}", &before[..word_start], replacement, after).into()
    }

    fn rebuild_buffer_model(&mut self) {
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        let filter = &self.buffer_filter_query;
        let mut total_unread = 0;
        let mut total_highlights = 0;

        let items: Vec<BufferItem> = self
            .buffers_cache
            .iter()
            .filter_map(|b| {
                let (unread, highlights) = self.unread_map.get(&b.ptr).copied().unwrap_or((0, 0));
                total_unread += unread;
                total_highlights += highlights;

                let matches = filter.is_empty()
                    || b.short_name.to_lowercase().contains(filter)
                    || b.server_name.to_lowercase().contains(filter)
                    || b.full_name.to_lowercase().contains(filter)
                    || (b.number > 0 && b.number.to_string() == *filter);

                if !matches {
                    return None;
                }

                Some(BufferItem {
                    ptr: b.ptr.clone().into(),
                    number: b.number,
                    short_name: b.short_name.clone().into(),
                    full_name: b.full_name.clone().into(),
                    server_name: b.server_name.clone().into(),
                    buffer_type: b.buffer_type.clone().into(),
                    title: strip_weechat_formatting(&b.title).into(),
                    unread_count: unread,
                    highlight_count: highlights,
                    is_active: b.ptr == active_ptr,
                    matches_filter: true,
                })
            })
            .collect();

        self.sync_buffer_model(items);
        self.total_unread_count = total_unread;
        self.total_highlight_count = total_highlights;
        self.hotlist_summary_changed();
    }

    fn sync_buffer_model(&mut self, items: Vec<BufferItem>) {
        let mut model = self.buffer_model.borrow_mut();
        let cur_count = model.row_count() as usize;

        if cur_count == 0 {
            model.reset_data(items);
            return;
        }

        // Fast path: identical sequence of buffers (clicking a buffer, message arrival, hotlist update)
        if cur_count == items.len() && (0..cur_count).all(|i| model[i].ptr == items[i].ptr) {
            for (i, item) in items.into_iter().enumerate() {
                if model[i] != item {
                    model.change_line(i, item);
                }
            }
            return;
        }

        // General reconciliation for additions, removals, renames, and filtering without resetting the view
        // 1. Remove items no longer present
        let new_ptrs: HashSet<String> = items.iter().map(|it| it.ptr.to_string()).collect();
        let mut i = model.row_count() as usize;
        while i > 0 {
            i -= 1;
            if !new_ptrs.contains(&model[i].ptr.to_string()) {
                model.remove(i);
            }
        }

        // 2. Insert, move, or update items to align with target sequence
        for (target_idx, target_item) in items.into_iter().enumerate() {
            let cur_len = model.row_count() as usize;
            if target_idx < cur_len {
                if model[target_idx].ptr == target_item.ptr {
                    if model[target_idx] != target_item {
                        model.change_line(target_idx, target_item);
                    }
                } else {
                    let mut found_at = None;
                    for scan in (target_idx + 1)..cur_len {
                        if model[scan].ptr == target_item.ptr {
                            found_at = Some(scan);
                            break;
                        }
                    }
                    if let Some(pos) = found_at {
                        model.remove(pos);
                        model.insert(target_idx, target_item);
                    } else {
                        model.insert(target_idx, target_item);
                    }
                }
            } else {
                model.push(target_item);
            }
        }
    }

    fn rebuild_message_model(&mut self) {
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        if active_ptr.is_empty() || active_ptr == "0x0" {
            self.message_model.borrow_mut().reset_data(Vec::new());
            self.active_buffer_has_older = false;
            self.search_match_count = 0;
            self.search_changed();
            return;
        }

        let view_limit = if self.active_buffer_view_limit > 0 {
            self.active_buffer_view_limit
        } else {
            self.max_view_lines()
        };

        if !self.message_items_cache.contains_key(&active_ptr) {
            let items = self.build_items_for_buffer(&active_ptr);
            self.message_items_cache.insert(active_ptr.clone(), items);
        }

        let (slice, match_count, total_cached) = {
            let cached_items = self.message_items_cache.get(&active_ptr).unwrap();
            let total = cached_items.len();
            let start = total.saturating_sub(view_limit);
            let mut slice_vec: Vec<MessageItem> = cached_items[start..].to_vec();
            if start > 0 && let Some(first) = slice_vec.first_mut() {
                first.is_grouped = false;
                if first.date_header.is_empty() {
                    first.date_header = format_date_header(first.timestamp).into();
                }
            }
            let mc = if !self.message_search_query.is_empty() {
                slice_vec.iter().filter(|i| i.matches_search).count() as i32
            } else {
                0
            };
            (slice_vec, mc, total)
        };

        let has_older = total_cached > slice.len() || slice.len() >= 50;
        if self.active_buffer_has_older != has_older {
            self.active_buffer_has_older = has_older;
        }

        self.message_model.borrow_mut().reset_data(slice);
        self.search_match_count = match_count;
        self.search_changed();
    }

    fn build_items_for_buffer(&self, buffer_ptr: &str) -> Vec<MessageItem> {
        let norm_ptr = normalize_ptr(buffer_ptr);
        let Some(raw_lines) = self.lines_cache.get(&norm_ptr) else {
            return Vec::new();
        };

        let buf_full_name = self
            .buffers_cache
            .iter()
            .find(|b| b.ptr == norm_ptr)
            .map(|b| b.full_name.clone())
            .unwrap_or_default();

        let mut items = Vec::with_capacity(raw_lines.len());
        let mut prev_sender = String::new();
        let mut prev_ts: i64 = 0;
        let mut prev_date_str = String::new();
        let mut match_count = 0;

        for line in raw_lines {
            if self.is_line_filtered(line, &buf_full_name) {
                continue;
            }

            let item = self.convert_line_to_item(
                line,
                &mut prev_sender,
                &mut prev_ts,
                &mut prev_date_str,
                &mut match_count,
            );
            items.push(item);
        }

        items
    }

    fn append_single_message_to_model(&mut self, line: &RelayLine) {
        let buf_full_name = self
            .buffers_cache
            .iter()
            .find(|b| b.ptr == line.buffer_ptr)
            .map(|b| b.full_name.clone())
            .unwrap_or_default();

        if self.is_line_filtered(line, &buf_full_name) {
            return;
        }

        let mut prev_sender = String::new();
        let mut prev_ts = 0;
        let mut prev_date_str = String::new();

        {
            let model = self.message_model.borrow();
            let count = model.row_count() as usize;
            if count > 0 {
                let last = &model[count - 1];
                if !self.classic_mode && !last.is_system && !last.is_action {
                    prev_sender = last.prefix_plain.to_string();
                    prev_ts = last.timestamp;
                }
                prev_date_str = format_date_header(last.timestamp);
            }
        }

        let mut match_count = self.search_match_count;
        let item = self.convert_line_to_item(
            line,
            &mut prev_sender,
            &mut prev_ts,
            &mut prev_date_str,
            &mut match_count,
        );

        let max_lines = self.max_buffer_lines();
        let view_limit = if self.active_buffer_view_limit > 0 {
            self.active_buffer_view_limit
        } else {
            self.max_view_lines()
        };
        {
            let mut model = self.message_model.borrow_mut();
            model.push(item.clone());
            while model.row_count() as usize > view_limit {
                model.remove(0);
            }
            if model.row_count() > 0 && model[0].is_grouped {
                let mut first = model[0].clone();
                first.is_grouped = false;
                if first.date_header.is_empty() {
                    first.date_header = format_date_header(first.timestamp).into();
                }
                model.change_line(0, first);
            }
        }

        if let Some(cached) = self.message_items_cache.get_mut(&line.buffer_ptr) {
            cached.push(item);
            if cached.len() > max_lines {
                let excess = cached.len() - max_lines;
                cached.drain(0..excess);
            }
        }

        self.search_match_count = match_count;
        self.search_changed();
    }

    fn convert_line_to_item(
        &self,
        line: &RelayLine,
        prev_sender: &mut String,
        prev_ts: &mut i64,
        prev_date_str: &mut String,
        match_count: &mut i32,
    ) -> MessageItem {
        let raw_prefix_stripped = strip_weechat_formatting(&line.prefix);
        let trimmed_prefix = raw_prefix_stripped.trim();

        let (role_badge, clean_nick) = if let Some(rest) = trimmed_prefix.strip_prefix('@') {
            ("@".to_string(), rest.to_string())
        } else if let Some(rest) = trimmed_prefix.strip_prefix('+') {
            ("+".to_string(), rest.to_string())
        } else if let Some(rest) = trimmed_prefix.strip_prefix('%') {
            ("%".to_string(), rest.to_string())
        } else if let Some(rest) = trimmed_prefix.strip_prefix('~') {
            ("~".to_string(), rest.to_string())
        } else if let Some(rest) = trimmed_prefix.strip_prefix('&') {
            ("&".to_string(), rest.to_string())
        } else {
            (String::new(), trimmed_prefix.to_string())
        };

        let is_action = line.tags.iter().any(|t| t == "irc_action") || clean_nick == "*";
        let is_system = clean_nick.is_empty()
            || matches!(
                clean_nick.as_str(),
                "--" | "<--" | "-->" | "=!=" | "irc" | "weechat"
            )
            || line.tags.iter().any(|t| {
                matches!(
                    t.as_str(),
                    "irc_join" | "irc_part" | "irc_quit" | "irc_mode" | "irc_topic" | "irc_nick"
                )
            });

        let formatted = format_weechat_message(&line.message);
        let time_format_str = self.timestamp_format.to_string();
        let time_str = format_timestamp_custom(line.timestamp, &time_format_str);
        let current_date = format_date_header(line.timestamp);
        let date_header = if current_date != *prev_date_str {
            *prev_date_str = current_date.clone();
            current_date
        } else {
            String::new()
        };

        let is_grouped = !self.classic_mode
            && !is_system
            && !is_action
            && date_header.is_empty()
            && !clean_nick.is_empty()
            && clean_nick == *prev_sender
            && (line.timestamp - *prev_ts).abs() < 300;

        if !is_system && !is_action {
            *prev_sender = clean_nick.clone();
            *prev_ts = line.timestamp;
        } else {
            prev_sender.clear();
            *prev_ts = 0;
        }

        let nick_color = deterministic_nick_color(&clean_nick);
        let matches_search = !self.message_search_query.is_empty()
            && (formatted
                .plain_text
                .to_lowercase()
                .contains(&self.message_search_query)
                || clean_nick
                    .to_lowercase()
                    .contains(&self.message_search_query));

        if matches_search {
            *match_count += 1;
        }

        MessageItem {
            line_ptr: line.line_ptr.clone().into(),
            timestamp: line.timestamp,
            time_str: time_str.into(),
            date_header: date_header.into(),
            prefix_plain: clean_nick.into(),
            role_badge: role_badge.into(),
            nick_color: nick_color.into(),
            styled_text: formatted.styled_text.into(),
            plain_text: formatted.plain_text.into(),
            is_highlight: line.highlight,
            is_action,
            is_system,
            is_grouped,
            image_url: formatted.image_url.into(),
            media_type: formatted.media.media_type.into(),
            media_url: formatted.media.media_url.into(),
            media_thumbnail: formatted.media.thumbnail_url.into(),
            media_id: formatted.media.video_id.into(),
            matches_search,
        }
    }

    fn rebuild_nick_model(&mut self) {
        let active_ptr = normalize_ptr(&self.active_buffer_ptr.to_string());
        let is_channel = self.active_buffer_type.to_string() == "channel";

        if active_ptr.is_empty() || active_ptr == "0x0" {
            self.active_buffer_nick_count = 0;
            self.active_buffer_is_operator = false;
            self.nick_model.borrow_mut().reset_data(Vec::new());
            self.nick_count_changed();
            return;
        }

        if let Some((cached_items, cached_is_op)) = self.nick_items_cache.get(&active_ptr) {
            self.active_buffer_nick_count = cached_items.len() as i32;
            self.active_buffer_is_operator = is_channel && *cached_is_op;
            self.nick_model.borrow_mut().reset_data(cached_items.clone());
            self.nick_count_changed();
            return;
        }

        let mut raw_nicks = self
            .nicks_cache
            .get(&active_ptr)
            .cloned()
            .unwrap_or_default();

        raw_nicks.sort_by(|a, b| {
            let rank_a = nick_role_rank(&a.prefix, &a.group_name);
            let rank_b = nick_role_rank(&b.prefix, &b.group_name);
            rank_a
                .cmp(&rank_b)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
        });

        let items: Vec<NickItem> = raw_nicks
            .iter()
            .map(|n| {
                let rank = nick_role_rank(&n.prefix, &n.group_name);
                let group_label = match rank {
                    0 => "OPERATORS",
                    1 => "HALF-OPS",
                    2 => "VOICED",
                    _ => "USERS",
                };
                let color = map_named_weechat_color(&n.color)
                    .unwrap_or_else(|| deterministic_nick_color(&n.name));

                NickItem {
                    name: n.name.clone().into(),
                    prefix: n.prefix.trim().to_string().into(),
                    color: color.into(),
                    group_label: group_label.into(),
                    role_rank: rank,
                }
            })
            .collect();

        self.active_buffer_nick_count = items.len() as i32;

        let own_nick = self
            .buffers_cache
            .iter()
            .find(|b| b.ptr == active_ptr)
            .and_then(|b| {
                b.local_vars.get("nick").cloned().or_else(|| {
                    let s = &b.server_name;
                    self.buffers_cache
                        .iter()
                        .find(|other| {
                            &other.server_name == s && other.local_vars.contains_key("nick")
                        })
                        .and_then(|other| other.local_vars.get("nick").cloned())
                })
            });

        let is_op_in_list = if let Some(nick) = &own_nick {
            raw_nicks
                .iter()
                .find(|n| n.name.eq_ignore_ascii_case(nick))
                .map(|n| nick_role_rank(&n.prefix, &n.group_name) == 0)
                .unwrap_or(false)
        } else {
            false
        };
        self.active_buffer_is_operator = is_channel && is_op_in_list;
        if !raw_nicks.is_empty() {
            self.nick_items_cache
                .insert(active_ptr, (items.clone(), is_op_in_list));
        }

        self.nick_model.borrow_mut().reset_data(items);
        self.nick_count_changed();
    }

    fn sort_buffers(&mut self) {
        let prev_order = self.sidebar_server_order.clone();
        sort_buffers_by_server_and_number(&mut self.buffers_cache, &mut self.sidebar_server_order);
        if self.sidebar_server_order != prev_order {
            self.save_current_config();
        }
    }

    fn save_current_config(&self) {
        let cfg = AppConfig {
            host: self.saved_host.to_string(),
            port: self.saved_port.clamp(1, 65535) as u16,
            use_tls: self.saved_use_tls,
            verify_tls: self.saved_verify_tls,
            show_join_part_quit: self.show_join_part_quit,
            auto_save_weechat_filters: self.auto_save_weechat_filters,
            show_media_previews: self.show_media_previews,
            desktop_notifications: self.desktop_notifications,
            theme_name: self.theme_name.to_string(),
            font_family: self.font_family.to_string(),
            font_size: self.font_size,
            timestamp_format: self.timestamp_format.to_string(),
            initial_lines_fetch: self.initial_lines_fetch,
            auto_reconnect: self.auto_reconnect,
            confirm_on_quit: self.confirm_on_quit,
            close_to_tray: self.close_to_tray,
            custom_browser: self.custom_browser.to_string(),
            classic_mode: self.classic_mode,
            alternating_row_colors: self.alternating_row_colors,
            sidebar_server_order: self.sidebar_server_order.clone(),
            collapsed_servers: self.collapsed_servers.iter().cloned().collect(),
        };
        cfg.save();
    }

    pub fn is_server_collapsed(&self, server_name: QString) -> bool {
        let name = server_name.to_string();
        self.collapsed_servers
            .iter()
            .any(|s| s.eq_ignore_ascii_case(&name))
    }

    pub fn toggle_server_collapsed(&mut self, server_name: QString) -> bool {
        let name = server_name.to_string();
        let mut was_collapsed = false;
        let mut found_key = None;
        for s in &self.collapsed_servers {
            if s.eq_ignore_ascii_case(&name) {
                was_collapsed = true;
                found_key = Some(s.clone());
                break;
            }
        }
        let is_now_collapsed = if was_collapsed {
            if let Some(k) = found_key {
                self.collapsed_servers.remove(&k);
            }
            false
        } else {
            self.collapsed_servers.insert(name);
            true
        };
        self.collapsed_servers_changed();
        self.save_current_config();
        is_now_collapsed
    }

    pub fn set_server_collapsed(&mut self, server_name: QString, collapsed: bool) {
        let name = server_name.to_string();
        if collapsed {
            if !self
                .collapsed_servers
                .iter()
                .any(|s| s.eq_ignore_ascii_case(&name))
            {
                self.collapsed_servers.insert(name);
                self.collapsed_servers_changed();
                self.save_current_config();
            }
        } else {
            let to_remove: Vec<String> = self
                .collapsed_servers
                .iter()
                .filter(|s| s.eq_ignore_ascii_case(&name))
                .cloned()
                .collect();
            if !to_remove.is_empty() {
                for k in to_remove {
                    self.collapsed_servers.remove(&k);
                }
                self.collapsed_servers_changed();
                self.save_current_config();
            }
        }
    }

    pub fn get_collapsed_servers(&self) -> QStringList {
        let list: Vec<QString> = self
            .collapsed_servers
            .iter()
            .map(|s| s.as_str().into())
            .collect();
        QStringList::from(list)
    }

    pub fn server_unread_count(&self, server_name: QString) -> i32 {
        let name = server_name.to_string();
        let mut count = 0;
        for b in &self.buffers_cache {
            if b.server_name.eq_ignore_ascii_case(&name)
                && let Some((u, _)) = self.unread_map.get(&b.ptr)
            {
                count += u;
            }
        }
        count
    }

    pub fn server_highlight_count(&self, server_name: QString) -> i32 {
        let name = server_name.to_string();
        let mut count = 0;
        for b in &self.buffers_cache {
            if b.server_name.eq_ignore_ascii_case(&name)
                && let Some((_, h)) = self.unread_map.get(&b.ptr)
            {
                count += h;
            }
        }
        count
    }

    pub fn server_buffer_count(&self, server_name: QString) -> i32 {
        let name = server_name.to_string();
        self.buffers_cache
            .iter()
            .filter(|b| b.server_name.eq_ignore_ascii_case(&name))
            .count() as i32
    }

    pub fn start_demo_mode(&mut self) {}
}

pub fn clean_nickname_for_filter(nick: &str) -> String {
    let trimmed = nick.trim();
    let stripped = trimmed.trim_start_matches(['@', '+', '%', '~', '&', '!', '*', '<', '>']);
    stripped.trim_end_matches('>').trim().to_string()
}

pub fn is_valid_nick_for_mute_str(nick: &str) -> bool {
    let clean = clean_nickname_for_filter(nick);
    !clean.is_empty()
        && !matches!(
            clean.as_str(),
            "--" | "<--" | "-->" | "=!=" | "irc" | "weechat" | "*" | "chan" | "server"
        )
}

pub fn mute_filter_name(clean_nick: &str) -> String {
    let sanitized: String = clean_nick
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '_' || c == '-' {
                c
            } else {
                '_'
            }
        })
        .collect();
    format!("mute_{}", sanitized.to_ascii_lowercase())
}

fn nick_role_rank(prefix: &str, group_name: &str) -> i32 {
    let p = prefix.trim();
    if p.starts_with('~') || p.starts_with('&') || p.starts_with('@') || group_name.contains("|o") {
        0
    } else if p.starts_with('%') || group_name.contains("|h") {
        1
    } else if p.starts_with('+') || group_name.contains("|v") {
        2
    } else {
        3
    }
}

fn format_timestamp_custom(ts: i64, format_pattern: &str) -> String {
    if let Some(dt) = Local.timestamp_opt(ts, 0).single() {
        let pattern = if format_pattern.is_empty() {
            "%H:%M"
        } else {
            format_pattern
        };
        dt.format(pattern).to_string()
    } else {
        "--:--".to_string()
    }
}

fn format_date_header(ts: i64) -> String {
    if let Some(dt) = Local.timestamp_opt(ts, 0).single() {
        dt.format("%A, %B %-d, %Y").to_string()
    } else {
        String::new()
    }
}

pub fn split_command_args(cmd: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut in_single_quote = false;
    let mut in_double_quote = false;
    let mut escaped = false;

    for ch in cmd.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
        } else if ch == '\\' {
            escaped = true;
        } else if ch == '\'' && !in_double_quote {
            in_single_quote = !in_single_quote;
        } else if ch == '"' && !in_single_quote {
            in_double_quote = !in_double_quote;
        } else if ch.is_whitespace() && !in_single_quote && !in_double_quote {
            if !current.is_empty() {
                args.push(current);
                current = String::new();
            }
        } else {
            current.push(ch);
        }
    }
    if !current.is_empty() {
        args.push(current);
    }
    args
}

pub fn open_url_with_browser(url: &str, custom_browser: &str) {
    let url = url.trim();
    if url.is_empty() {
        return;
    }

    let custom = custom_browser.trim();
    let is_default = custom.is_empty()
        || custom.eq_ignore_ascii_case("default")
        || custom.eq_ignore_ascii_case("system");

    if !is_default {
        let parts = split_command_args(custom);
        if let Some((program, args)) = parts.split_first() {
            let mut cmd = std::process::Command::new(program);
            cmd.args(args);
            cmd.arg(url);
            match cmd.spawn() {
                Ok(_) => return,
                Err(e) => {
                    eprintln!(
                        "Failed to launch custom browser '{}': {}. Falling back to system default.",
                        custom, e
                    );
                }
            }
        }
    }

    // System default fallback: xdg-open on Linux, or gio open
    let res = std::process::Command::new("xdg-open").arg(url).spawn();
    if res.is_err() {
        let _ = std::process::Command::new("gio")
            .args(["open", url])
            .spawn();
    }
}
