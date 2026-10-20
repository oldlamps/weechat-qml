use qmetaobject::*;

#[derive(SimpleListItem, Default, Clone, Debug)]
pub struct BufferItem {
    pub ptr: QString,
    pub number: i32,
    pub short_name: QString,
    pub full_name: QString,
    pub server_name: QString,
    pub buffer_type: QString, // "core", "server", "channel", "private"
    pub title: QString,
    pub unread_count: i32,
    pub highlight_count: i32,
    pub is_active: bool,
    pub matches_filter: bool,
}

#[derive(SimpleListItem, Default, Clone, Debug)]
pub struct MessageItem {
    pub line_ptr: QString,
    pub timestamp: i64,
    pub time_str: QString,
    pub date_header: QString,
    pub prefix_plain: QString,
    pub role_badge: QString,
    pub nick_color: QString,
    pub styled_text: QString,
    pub plain_text: QString,
    pub is_highlight: bool,
    pub is_action: bool,
    pub is_system: bool,
    pub is_grouped: bool,
    pub image_url: QString,
    pub matches_search: bool,
}

#[derive(SimpleListItem, Default, Clone, Debug)]
pub struct NickItem {
    pub name: QString,
    pub prefix: QString,
    pub color: QString,
    pub group_label: QString,
    pub role_rank: i32, // 0 = op (@/~), 1 = halfop (%), 2 = voice (+), 3 = normal
}

#[derive(SimpleListItem, Default, Clone, Debug)]
pub struct ServerProfileItem {
    pub id: QString,
    pub name: QString,
    pub host: QString,
    pub port: i32,
    pub use_tls: bool,
    pub verify_tls: bool,
    pub save_password: bool,
    pub auto_connect: bool,
    pub totp: QString,
    pub is_active: bool,
    pub has_saved_password: bool,
}
