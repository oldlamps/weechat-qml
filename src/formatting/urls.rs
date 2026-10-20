use super::colors::{StyledSpan, escape_styled_text, parse_weechat_spans};

#[derive(Debug, Clone)]
pub struct FormattedMessage {
    /// Clean plain text with all WeeChat/IRC control bytes stripped
    pub plain_text: String,
    /// Native QtQuick `Text.StyledText` markup (`<font color="...">`, `<b>`, `<i>`, `<u>`, `<a href="...">`)
    pub styled_text: String,
    /// First direct image URL found in the message (for optional QtQuick `Image` preview)
    pub image_url: String,
}

/// Formats a raw WeeChat message string into plain text, QtQuick `Text.StyledText` markup,
/// and extracts any direct image URL.
pub fn format_weechat_message(raw: &str) -> FormattedMessage {
    let spans = parse_weechat_spans(raw);
    let mut plain_text = String::new();
    let mut styled_text = String::new();
    let mut first_image_url = String::new();

    for span in &spans {
        plain_text.push_str(&span.text);
        let segment = linkify_and_escape(&span.text, &mut first_image_url);
        styled_text.push_str(&wrap_with_style(&segment, span));
    }

    FormattedMessage {
        plain_text,
        styled_text,
        image_url: first_image_url,
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

fn linkify_and_escape(text: &str, first_image_url: &mut String) -> String {
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

        if first_image_url.is_empty() && is_direct_image_url(url) {
            *first_image_url = url.to_string();
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

pub fn is_direct_image_url(url: &str) -> bool {
    let path = url.split('?').next().unwrap_or(url).to_ascii_lowercase();
    path.ends_with(".png")
        || path.ends_with(".jpg")
        || path.ends_with(".jpeg")
        || path.ends_with(".gif")
        || path.ends_with(".webp")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_url_and_image_extraction() {
        let msg = "Check out https://example.com/screenshot.png, looks great!";
        let formatted = format_weechat_message(msg);
        assert_eq!(formatted.image_url, "https://example.com/screenshot.png");
        assert!(
            formatted
                .styled_text
                .contains("<a href=\"https://example.com/screenshot.png\">")
        );
    }
}
