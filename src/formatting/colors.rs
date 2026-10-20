/// WeeChat internal color control bytes:
/// - `0x19`: Color code prefix (standard `00`-`15`, extended `@00000`-`@00255`, `F` fg, `B` bg, `*` fg*bg, `b` bar, `E` emphasis, `\x1C` reset)
/// - `0x1A`: Set attribute (`*` bold, `/` italic, `_` underline, `!` reverse, `|` keep)
/// - `0x1B`: Remove attribute
/// - `0x1C`: Reset all colors and attributes

#[derive(Debug, Clone, Default, PartialEq)]
pub struct TextStyle {
    pub fg_color: Option<String>,
    pub bg_color: Option<String>,
    pub bold: bool,
    pub italic: bool,
    pub underline: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct StyledSpan {
    pub text: String,
    pub style: TextStyle,
}

/// High-contrast modern dark palette mapped to WeeChat's 16 standard colors (00..15).
const WEECHAT_STD_COLORS: [&str; 16] = [
    "#d8dee9", // 00: default
    "#4c566a", // 01: black (readable slate on dark bg)
    "#bf616a", // 02: darkred
    "#f43f5e", // 03: lightred
    "#a3be8c", // 04: darkgreen
    "#4ade80", // 05: lightgreen
    "#d08770", // 06: brown
    "#facc15", // 07: yellow
    "#5e81ac", // 08: darkblue
    "#38bdf8", // 09: lightblue
    "#b48ead", // 10: darkmagenta
    "#e879f9", // 11: lightmagenta
    "#88c0d0", // 12: darkcyan
    "#2dd4bf", // 13: lightcyan
    "#94a3b8", // 14: gray
    "#f8fafc", // 15: white
];

/// Vibrant, high-contrast nick colors for dark UI backgrounds.
const NICK_PALETTE: [&str; 16] = [
    "#38bdf8", // sky
    "#4ade80", // emerald
    "#f472b6", // pink
    "#fb923c", // orange
    "#a78bfa", // violet
    "#2dd4bf", // teal
    "#facc15", // yellow
    "#60a5fa", // blue
    "#f87171", // coral
    "#c084fc", // purple
    "#34d399", // mint
    "#fbbf24", // amber
    "#818cf8", // indigo
    "#fb7185", // rose
    "#22d3ee", // cyan
    "#a3e635", // lime
];

/// Deterministic nick color hash so every IRC nickname gets a consistent, readable color.
pub fn deterministic_nick_color(nick: &str) -> String {
    let trimmed = nick.trim_start_matches(['@', '+', '%', '~', '&', ' ']);
    if trimmed.is_empty()
        || trimmed == "*"
        || trimmed == "--"
        || trimmed == "<--"
        || trimmed == "-->"
    {
        return "#64748b".to_string();
    }
    let mut hash: u32 = 5381;
    for b in trimmed.bytes() {
        hash = ((hash << 5).wrapping_add(hash)).wrapping_add(b.to_ascii_lowercase() as u32);
    }
    NICK_PALETTE[(hash as usize) % NICK_PALETTE.len()].to_string()
}

/// Maps a WeeChat color name (e.g. `"green"`, `"lightblue"`, `"bar_fg"`, `"214"`) to a hex color string.
pub fn map_named_weechat_color(name: &str) -> Option<String> {
    let clean = name.trim_start_matches(['*', '!', '/', '_', '|']);
    match clean {
        "default" | "reset" => None,
        "black" => Some(WEECHAT_STD_COLORS[1].to_string()),
        "red" | "darkred" => Some(WEECHAT_STD_COLORS[2].to_string()),
        "lightred" => Some(WEECHAT_STD_COLORS[3].to_string()),
        "green" | "darkgreen" => Some(WEECHAT_STD_COLORS[4].to_string()),
        "lightgreen" => Some(WEECHAT_STD_COLORS[5].to_string()),
        "brown" => Some(WEECHAT_STD_COLORS[6].to_string()),
        "yellow" => Some(WEECHAT_STD_COLORS[7].to_string()),
        "blue" | "darkblue" => Some(WEECHAT_STD_COLORS[8].to_string()),
        "lightblue" => Some(WEECHAT_STD_COLORS[9].to_string()),
        "magenta" | "darkmagenta" => Some(WEECHAT_STD_COLORS[10].to_string()),
        "lightmagenta" => Some(WEECHAT_STD_COLORS[11].to_string()),
        "cyan" | "darkcyan" => Some(WEECHAT_STD_COLORS[12].to_string()),
        "lightcyan" => Some(WEECHAT_STD_COLORS[13].to_string()),
        "gray" | "darkgray" => Some(WEECHAT_STD_COLORS[14].to_string()),
        "white" => Some(WEECHAT_STD_COLORS[15].to_string()),
        num_str => {
            if let Ok(code) = num_str.parse::<u8>() {
                Some(xterm_256_to_hex(code))
            } else {
                None
            }
        }
    }
}

/// Converts an xterm 256-color index (0..=255) to a `#rrggbb` hex color string.
pub fn xterm_256_to_hex(idx: u8) -> String {
    if idx < 16 {
        return WEECHAT_STD_COLORS[idx as usize].to_string();
    }
    if idx < 232 {
        let n = idx - 16;
        let r_idx = n / 36;
        let g_idx = (n % 36) / 6;
        let b_idx = n % 6;
        let step = [0u8, 95, 135, 175, 215, 255];
        return format!(
            "#{:02x}{:02x}{:02x}",
            step[r_idx as usize], step[g_idx as usize], step[b_idx as usize]
        );
    }
    let gray = 8 + (idx - 232) * 10;
    format!("#{:02x}{:02x}{:02x}", gray, gray, gray)
}

/// Strips all WeeChat and IRC control codes, returning clean plain text.
pub fn strip_weechat_formatting(input: &str) -> String {
    parse_weechat_spans(input)
        .into_iter()
        .map(|s| s.text)
        .collect::<Vec<_>>()
        .join("")
}

/// Parses a string containing WeeChat (`\x19`..`\x1C`) and IRC (`\x02`, `\x03`, `\x0F`, `\x1D`, `\x1F`)
/// formatting codes into a sequence of `StyledSpan`s.
pub fn parse_weechat_spans(input: &str) -> Vec<StyledSpan> {
    let chars: Vec<char> = input.chars().collect();
    let mut pos = 0;
    let mut style = TextStyle::default();
    let mut current_text = String::new();
    let mut spans = Vec::new();

    let flush = |text: &mut String, st: &TextStyle, out: &mut Vec<StyledSpan>| {
        if !text.is_empty() {
            out.push(StyledSpan {
                text: std::mem::take(text),
                style: st.clone(),
            });
        }
    };

    while pos < chars.len() {
        let ch = chars[pos];
        match ch {
            '\x19' => {
                flush(&mut current_text, &style, &mut spans);
                pos += 1;
                if pos >= chars.len() {
                    break;
                }
                match chars[pos] {
                    '\x1C' => {
                        style.fg_color = None;
                        style.bg_color = None;
                        pos += 1;
                    }
                    'b' => {
                        // Bar item control code, skip next char
                        pos += 1;
                        if pos < chars.len() {
                            pos += 1;
                        }
                    }
                    'E' => {
                        style.bold = true;
                        pos += 1;
                    }
                    'F' => {
                        pos += 1;
                        parse_attr_flags(&chars, &mut pos, &mut style, true);
                        style.fg_color = parse_single_color(&chars, &mut pos);
                    }
                    'B' => {
                        pos += 1;
                        parse_attr_flags(&chars, &mut pos, &mut style, true);
                        style.bg_color = parse_single_color(&chars, &mut pos);
                    }
                    '*' => {
                        pos += 1;
                        parse_attr_flags(&chars, &mut pos, &mut style, true);
                        style.fg_color = parse_single_color(&chars, &mut pos);
                        if pos < chars.len() && (chars[pos] == ',' || chars[pos] == '~') {
                            pos += 1;
                            style.bg_color = parse_single_color(&chars, &mut pos);
                        }
                    }
                    '@' => {
                        style.fg_color = parse_single_color(&chars, &mut pos);
                    }
                    c if c.is_ascii_digit() => {
                        style.fg_color = parse_single_color(&chars, &mut pos);
                    }
                    _ => {
                        parse_attr_flags(&chars, &mut pos, &mut style, true);
                        style.fg_color = parse_single_color(&chars, &mut pos);
                    }
                }
            }
            '\x1A' => {
                flush(&mut current_text, &style, &mut spans);
                pos += 1;
                if pos < chars.len() {
                    apply_attr_char(chars[pos], &mut style, true);
                    pos += 1;
                }
            }
            '\x1B' => {
                flush(&mut current_text, &style, &mut spans);
                pos += 1;
                if pos < chars.len() {
                    apply_attr_char(chars[pos], &mut style, false);
                    pos += 1;
                }
            }
            '\x1C' | '\x0F' => {
                flush(&mut current_text, &style, &mut spans);
                style = TextStyle::default();
                pos += 1;
            }
            '\x02' => {
                flush(&mut current_text, &style, &mut spans);
                style.bold = !style.bold;
                pos += 1;
            }
            '\x1D' => {
                flush(&mut current_text, &style, &mut spans);
                style.italic = !style.italic;
                pos += 1;
            }
            '\x1F' => {
                flush(&mut current_text, &style, &mut spans);
                style.underline = !style.underline;
                pos += 1;
            }
            '\x03' => {
                flush(&mut current_text, &style, &mut spans);
                pos += 1;
                let mut fg_digits = String::new();
                while pos < chars.len() && chars[pos].is_ascii_digit() && fg_digits.len() < 2 {
                    fg_digits.push(chars[pos]);
                    pos += 1;
                }
                if fg_digits.is_empty() {
                    style.fg_color = None;
                    style.bg_color = None;
                } else if let Ok(code) = fg_digits.parse::<usize>() {
                    style.fg_color = Some(WEECHAT_STD_COLORS[code % 16].to_string());
                }
            }
            _ => {
                current_text.push(ch);
                pos += 1;
            }
        }
    }

    flush(&mut current_text, &style, &mut spans);
    spans
}

fn parse_attr_flags(chars: &[char], pos: &mut usize, style: &mut TextStyle, enable: bool) {
    while *pos < chars.len() {
        match chars[*pos] {
            '*' | '/' | '_' | '!' | '|' => {
                apply_attr_char(chars[*pos], style, enable);
                *pos += 1;
            }
            _ => break,
        }
    }
}

fn apply_attr_char(c: char, style: &mut TextStyle, enable: bool) {
    match c {
        '*' => style.bold = enable,
        '/' => style.italic = enable,
        '_' => style.underline = enable,
        '|' => {}
        _ => {}
    }
}

fn parse_single_color(chars: &[char], pos: &mut usize) -> Option<String> {
    if *pos >= chars.len() {
        return None;
    }
    if chars[*pos] == '@' {
        *pos += 1;
        parse_attr_flags(chars, pos, &mut TextStyle::default(), true);
        let mut digits = String::new();
        while *pos < chars.len() && digits.len() < 5 && chars[*pos].is_ascii_digit() {
            digits.push(chars[*pos]);
            *pos += 1;
        }
        if let Ok(code) = digits.parse::<u16>() {
            if code == 0 {
                return None;
            }
            return Some(xterm_256_to_hex((code.min(255)) as u8));
        }
        None
    } else {
        let mut digits = String::new();
        while *pos < chars.len() && digits.len() < 2 && chars[*pos].is_ascii_digit() {
            digits.push(chars[*pos]);
            *pos += 1;
        }
        if let Ok(code) = digits.parse::<usize>() {
            if code == 0 {
                return None;
            }
            return Some(WEECHAT_STD_COLORS[code % 16].to_string());
        }
        None
    }
}

/// Escapes special characters for QtQuick `Text.StyledText` markup (`<font color="...">`, `<b>`, `<i>`, `<u>`, `<a href="...">`).
pub fn escape_styled_text(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            _ => out.push(c),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_weechat_color_and_attribute_parsing() {
        let raw = "\x19F*05Hello \x19@00214world\x1C normal";
        let spans = parse_weechat_spans(raw);
        assert_eq!(spans.len(), 3);
        assert_eq!(spans[0].text, "Hello ");
        assert!(spans[0].style.bold);
        assert_eq!(spans[0].style.fg_color.as_deref(), Some("#4ade80"));

        assert_eq!(spans[1].text, "world");
        assert_eq!(spans[1].style.fg_color.as_deref(), Some("#ffaf00"));

        assert_eq!(spans[2].text, " normal");
        assert!(!spans[2].style.bold);
        assert_eq!(spans[2].style.fg_color, None);
    }

    #[test]
    fn test_strip_weechat_formatting() {
        let raw = "\x19F09@ferris\x1C";
        assert_eq!(strip_weechat_formatting(raw), "@ferris");
    }
}
