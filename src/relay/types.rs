use std::collections::HashMap;

/// Normalizes a WeeChat memory pointer into canonical `0x<lowercase-hex>` form.
pub fn normalize_ptr(ptr: &str) -> String {
    let trimmed = ptr.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let clean = trimmed
        .trim_start_matches("0x")
        .trim_start_matches("0X")
        .to_ascii_lowercase();
    if clean.is_empty() || clean == "0" {
        "0x0".to_string()
    } else {
        format!("0x{}", clean)
    }
}

/// Represents all 14 native binary types in the WeeChat Relay Protocol.
#[derive(Debug, Clone, PartialEq)]
pub enum RelayValue {
    /// `chr`: 1-byte signed/unsigned char
    Char(u8),
    /// `int`: 32-bit big-endian signed integer
    Int(i32),
    /// `lon`: length-prefixed ASCII representation of a 64-bit integer
    Long(i64),
    /// `str`: length-prefixed UTF-8 string (or None when length == -1)
    Str(Option<String>),
    /// `buf`: length-prefixed raw byte buffer (or None when length == -1)
    Buf(Option<Vec<u8>>),
    /// `ptr`: length-prefixed hex pointer string (`0x...`, or `0x0` for null)
    Ptr(String),
    /// `tim`: length-prefixed ASCII Unix timestamp
    Time(i64),
    /// `htb`: Hashtable mapping RelayValue keys to RelayValue values
    HashTable(Vec<(RelayValue, RelayValue)>),
    /// `hda`: Hdata hierarchical table structure
    Hdata(HdataObject),
    /// `inf`: Single (name, value) info pair
    Info(String, String),
    /// `inl`: Infolist containing named items of key-value maps
    Infolist(InfolistObject),
    /// `arr`: Homogeneous array of RelayValues
    Array(Vec<RelayValue>),
}

impl RelayValue {
    pub fn as_string_lossy(&self) -> String {
        match self {
            RelayValue::Str(Some(s)) => s.clone(),
            RelayValue::Str(None) => String::new(),
            RelayValue::Ptr(p) => p.clone(),
            RelayValue::Int(i) => i.to_string(),
            RelayValue::Long(l) => l.to_string(),
            RelayValue::Time(t) => t.to_string(),
            RelayValue::Char(c) => (*c as char).to_string(),
            RelayValue::Buf(Some(b)) => String::from_utf8_lossy(b).into_owned(),
            _ => String::new(),
        }
    }

    pub fn as_i32(&self) -> Option<i32> {
        match self {
            RelayValue::Int(v) => Some(*v),
            RelayValue::Char(v) => Some(*v as i32),
            RelayValue::Long(v) => Some(*v as i32),
            _ => None,
        }
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            RelayValue::Time(v) | RelayValue::Long(v) => Some(*v),
            RelayValue::Int(v) => Some(*v as i64),
            RelayValue::Char(v) => Some(*v as i64),
            _ => None,
        }
    }

    pub fn as_char(&self) -> Option<char> {
        match self {
            RelayValue::Char(c) => Some(*c as char),
            _ => None,
        }
    }

    pub fn as_string_map(&self) -> HashMap<String, String> {
        let mut map = HashMap::new();
        if let RelayValue::HashTable(entries) = self {
            for (k, v) in entries {
                map.insert(k.as_string_lossy(), v.as_string_lossy());
            }
        }
        map
    }

    pub fn as_string_vec(&self) -> Vec<String> {
        match self {
            RelayValue::Array(items) => items.iter().map(|i| i.as_string_lossy()).collect(),
            _ => Vec::new(),
        }
    }

    pub fn as_int_vec(&self) -> Vec<i32> {
        match self {
            RelayValue::Array(items) => items.iter().filter_map(|i| i.as_i32()).collect(),
            _ => Vec::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct HdataObject {
    /// Path such as `"buffer"` or `"buffer/own_lines/line/data"`
    pub hpath: String,
    /// Ordered list of `(key_name, value_type)`
    pub keys: Vec<(String, String)>,
    /// Rows of data in the Hdata
    pub items: Vec<HdataItem>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct HdataItem {
    /// One pointer per path component in `hpath`
    pub pointers: Vec<String>,
    /// Key -> value map for this row
    pub values: HashMap<String, RelayValue>,
}

impl HdataItem {
    pub fn last_ptr(&self) -> &str {
        self.pointers.last().map(|s| s.as_str()).unwrap_or("0x0")
    }

    pub fn first_ptr(&self) -> &str {
        self.pointers.first().map(|s| s.as_str()).unwrap_or("0x0")
    }

    pub fn get_str(&self, key: &str) -> String {
        self.values
            .get(key)
            .map(|v| v.as_string_lossy())
            .unwrap_or_default()
    }

    pub fn get_i32(&self, key: &str) -> i32 {
        self.values.get(key).and_then(|v| v.as_i32()).unwrap_or(0)
    }

    pub fn get_i64(&self, key: &str) -> i64 {
        self.values.get(key).and_then(|v| v.as_i64()).unwrap_or(0)
    }

    pub fn get_char(&self, key: &str) -> char {
        self.values
            .get(key)
            .and_then(|v| v.as_char())
            .unwrap_or('\0')
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct InfolistObject {
    pub name: String,
    pub items: Vec<HashMap<String, RelayValue>>,
}

/// A complete decoded WeeChat Relay message frame.
#[derive(Debug, Clone, PartialEq)]
pub struct RelayMessage {
    /// Message identifier (e.g. `"listbuffers"`, `"_buffer_line_added"`, or `""`)
    pub id: String,
    /// Decoded objects in the message payload
    pub objects: Vec<RelayValue>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_ptr_canonical_formatting() {
        assert_eq!(normalize_ptr("0x55AA12"), "0x55aa12");
        assert_eq!(normalize_ptr("55aa12"), "0x55aa12");
        assert_eq!(normalize_ptr("0X55aa12"), "0x55aa12");
        assert_eq!(normalize_ptr("  0x1a2b  "), "0x1a2b");
        assert_eq!(normalize_ptr("0x0"), "0x0");
        assert_eq!(normalize_ptr("0"), "0x0");
        assert_eq!(normalize_ptr(""), "");
    }
}
