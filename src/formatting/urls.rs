use super::colors::{StyledSpan, escape_styled_text, parse_weechat_spans};

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MediaPreviewInfo {
    /// "none", "image", "youtube"
    pub media_type: String,
    pub media_url: String,
    pub thumbnail_url: String,
    pub video_id: String,
}

#[derive(Debug, Clone)]
pub struct FormattedMessage {
    /// Clean plain text with all WeeChat/IRC control bytes stripped
    pub plain_text: String,
    /// Native QtQuick `Text.StyledText` markup (`<font color="...">`, `<b>`, `<i>`, `<u>`, `<a href="...">`)
    pub styled_text: String,
    /// First direct image URL found in the message (for backwards-compatibility)
    pub image_url: String,
    /// Rich media preview descriptor (direct image or YouTube video)
    pub media: MediaPreviewInfo,
}

/// Formats a raw WeeChat message string into plain text, QtQuick `Text.StyledText` markup,
/// and extracts rich media previews (images, YouTube).
pub fn format_weechat_message(raw: &str) -> FormattedMessage {
    let spans = parse_weechat_spans(raw);
    let mut plain_text = String::new();
    let mut styled_text = String::new();
    let mut first_media: Option<MediaPreviewInfo> = None;

    for span in &spans {
        plain_text.push_str(&span.text);
        let segment = linkify_and_escape(&span.text, &mut first_media);
        styled_text.push_str(&wrap_with_style(&segment, span));
    }

    let media = first_media.unwrap_or_default();
    let image_url = if media.media_type == "image" {
        media.media_url.clone()
    } else {
        String::new()
    };

    FormattedMessage {
        plain_text,
        styled_text,
        image_url,
        media,
    }
}

fn wrap_with_style(inner: &str, span: &StyledSpan) -> String {
    if inner.is_empty() {
        return String::new();
    }
    let mut out = inner.to_string();
    if span.style.underline {
        out = format!("<u>{}</u>", out);
    }
    if span.style.italic {
        out = format!("<i>{}</i>", out);
    }
    if span.style.bold {
        out = format!("<b>{}</b>", out);
    }
    if let Some(fg) = &span.style.fg_color {
        out = format!("<font color=\"{}\">{}</font>", fg, out);
    }
    out
}

fn linkify_and_escape(text: &str, first_media: &mut Option<MediaPreviewInfo>) -> String {
    let mut out = String::with_capacity(text.len());
    let mut remaining = text;

    while let Some(pos) = find_url_start(remaining) {
        let (before, from_url) = remaining.split_at(pos);
        out.push_str(&escape_styled_text(before));

        let url_len = from_url
            .find(|c: char| c.is_whitespace() || matches!(c, '<' | '>' | '"' | '\''))
            .unwrap_or(from_url.len());

        let mut url = &from_url[..url_len];
        // Trim trailing sentence punctuation that isn't part of the URL
        while url.ends_with(['.', ',', ';', ')', ']']) {
            url = &url[..url.len() - 1];
        }

        let escaped_url = escape_styled_text(url);
        out.push_str(&format!(
            "<a href=\"{}\"><font color=\"#38bdf8\">{}</font></a>",
            escaped_url, escaped_url
        ));

        if first_media.is_none() {
            if let Some((vid, yt_url)) = extract_youtube_info(url) {
                *first_media = Some(MediaPreviewInfo {
                    media_type: "youtube".to_string(),
                    media_url: yt_url,
                    thumbnail_url: format!("https://img.youtube.com/vi/{}/hqdefault.jpg", vid),
                    video_id: vid,
                });
            } else if is_wikimedia_file_page(url) {
                *first_media = Some(MediaPreviewInfo {
                    media_type: "image".to_string(),
                    media_url: url.to_string(),
                    thumbnail_url: url.to_string(),
                    video_id: String::new(),
                });
            } else if is_direct_image_url(url) {
                *first_media = Some(MediaPreviewInfo {
                    media_type: "image".to_string(),
                    media_url: url.to_string(),
                    thumbnail_url: url.to_string(),
                    video_id: String::new(),
                });
            }
        }

        remaining = &from_url[url.len()..];
    }

    out.push_str(&escape_styled_text(remaining));
    out
}

fn find_url_start(s: &str) -> Option<usize> {
    let http = s.find("http://");
    let https = s.find("https://");
    match (http, https) {
        (Some(a), Some(b)) => Some(a.min(b)),
        (Some(a), None) => Some(a),
        (None, Some(b)) => Some(b),
        (None, None) => None,
    }
}

/// Detects Wikipedia and Wikimedia Commons File pages (e.g. `https://en.wikipedia.org/wiki/File:Foo.png`).
pub fn is_wikimedia_file_page(url: &str) -> bool {
    let lower = url.to_ascii_lowercase();
    (lower.contains("wikipedia.org/wiki/file:") || lower.contains("wikimedia.org/wiki/file:"))
        && (lower.ends_with(".png")
            || lower.ends_with(".jpg")
            || lower.ends_with(".jpeg")
            || lower.ends_with(".gif")
            || lower.ends_with(".webp")
            || lower.ends_with(".svg")
            || lower.ends_with(".bmp")
            || lower.ends_with(".tif")
            || lower.ends_with(".tiff"))
}

/// Detects whether a URL is a direct raw image file supported by Qt 6.
/// Excludes HTML viewer pages (Wikipedia file pages, GitHub blob views, Imgur galleries).
pub fn is_direct_image_url(url: &str) -> bool {
    let lower = url.to_ascii_lowercase();

    // Exclude known HTML wrapper pages that end with an image extension in the path
    if lower.contains("wikipedia.org/wiki/")
        || lower.contains("wikimedia.org/wiki/")
        || (lower.contains("github.com/") && lower.contains("/blob/"))
        || (lower.contains("gitlab.com/") && lower.contains("/blob/"))
        || lower.contains("imgur.com/gallery/")
        || lower.contains("imgur.com/a/")
    {
        return false;
    }

    // Query parameter formats (e.g. pbs.twimg.com/media/xyz?format=jpg)
    if lower.contains("format=jpg")
        || lower.contains("format=jpeg")
        || lower.contains("format=png")
        || lower.contains("format=webp")
        || lower.contains("ext=jpg")
        || lower.contains("ext=png")
    {
        return true;
    }

    // Extract path before query string or fragment
    let path = lower
        .split('?')
        .next()
        .unwrap_or(&lower)
        .split('#')
        .next()
        .unwrap_or(&lower);

    // Support all common formats Qt 6 can decode
    path.ends_with(".png")
        || path.ends_with(".jpg")
        || path.ends_with(".jpeg")
        || path.ends_with(".gif")
        || path.ends_with(".webp")
        || path.ends_with(".svg")
        || path.ends_with(".bmp")
        || path.ends_with(".ico")
        || path.ends_with(".avif")
        || path.ends_with(".jxl")
        || path.ends_with(".tiff")
        || path.ends_with(".tif")
}

/// Detects YouTube video URLs and returns `(video_id, normalized_url)`.
pub fn extract_youtube_info(url: &str) -> Option<(String, String)> {
    let lower = url.to_ascii_lowercase();
    if !lower.contains("youtube.com") && !lower.contains("youtu.be") {
        return None;
    }

    let after_scheme = if let Some(rest) = url.strip_prefix("https://") {
        rest
    } else if let Some(rest) = url.strip_prefix("http://") {
        rest
    } else {
        url
    };

    let (host, path_and_query) = match after_scheme.find('/') {
        Some(idx) => (&after_scheme[..idx], &after_scheme[idx..]),
        None => (after_scheme, ""),
    };
    let host_lower = host.to_ascii_lowercase();

    // 1. youtu.be/<id>
    if host_lower == "youtu.be" || host_lower.ends_with(".youtu.be") {
        let clean_path = path_and_query.trim_start_matches('/');
        let id_part = clean_path
            .split(&['?', '&', '#'][..])
            .next()
            .unwrap_or("")
            .trim();
        if is_valid_youtube_id(id_part) {
            return Some((id_part.to_string(), url.to_string()));
        }
    }

    // 2. youtube.com
    if host_lower == "youtube.com"
        || host_lower == "www.youtube.com"
        || host_lower == "m.youtube.com"
    {
        // /watch?v=<id>
        if let Some(query_start) = path_and_query.find('?') {
            let query = &path_and_query[query_start + 1..];
            for param in query.split('&') {
                if let Some(val) = param.strip_prefix("v=") {
                    let id = val.split('#').next().unwrap_or(val).trim();
                    if is_valid_youtube_id(id) {
                        return Some((id.to_string(), url.to_string()));
                    }
                }
            }
        }

        // /shorts/<id> or /embed/<id> or /live/<id>
        for prefix in ["/shorts/", "/embed/", "/live/"] {
            if let Some(rest) = path_and_query.strip_prefix(prefix) {
                let id = rest
                    .split(&['?', '&', '/', '#'][..])
                    .next()
                    .unwrap_or("")
                    .trim();
                if is_valid_youtube_id(id) {
                    return Some((id.to_string(), url.to_string()));
                }
            }
        }
    }

    None
}

fn is_valid_youtube_id(id: &str) -> bool {
    id.len() >= 8
        && id.len() <= 20
        && id
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}
