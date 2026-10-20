use std::collections::HashMap;
use std::io::Read;

use anyhow::{Context, Result, anyhow, bail};
use flate2::read::ZlibDecoder;

use super::types::{HdataItem, HdataObject, InfolistObject, RelayMessage, RelayValue};

/// Compression flags in the 5th byte of a WeeChat Relay packet header.
pub const COMPRESSION_OFF: u8 = 0;
pub const COMPRESSION_ZLIB: u8 = 1;
pub const COMPRESSION_ZSTD: u8 = 2;

/// Parses a complete raw WeeChat Relay frame (including its 5-byte header).
pub fn parse_frame(frame: &[u8]) -> Result<RelayMessage> {
    if frame.len() < 5 {
        bail!("Relay frame too short ({} bytes, minimum 5)", frame.len());
    }

    let declared_len = u32::from_be_bytes([frame[0], frame[1], frame[2], frame[3]]) as usize;
    if declared_len != frame.len() {
        bail!(
            "Relay frame length mismatch: header says {}, slice has {}",
            declared_len,
            frame.len()
        );
    }

    let compression = frame[4];
    let payload = &frame[5..];

    let decompressed: Vec<u8> = match compression {
        COMPRESSION_OFF => payload.to_vec(),
        COMPRESSION_ZLIB => {
            let mut decoder = ZlibDecoder::new(payload);
            let mut out = Vec::new();
            decoder
                .read_to_end(&mut out)
                .context("Failed to decompress zlib relay payload")?;
            out
        }
        COMPRESSION_ZSTD => {
            zstd::stream::decode_all(payload).context("Failed to decompress zstd relay payload")?
        }
        other => bail!("Unsupported WeeChat Relay compression flag: {}", other),
    };

    parse_decompressed_payload(&decompressed)
}

/// Parses an uncompressed payload starting at the message ID string.
pub fn parse_decompressed_payload(data: &[u8]) -> Result<RelayMessage> {
    let mut cursor = BinaryCursor::new(data);
    let id = cursor.read_string()?.unwrap_or_default();

    let mut objects = Vec::new();
    while cursor.remaining() >= 3 {
        let typ = cursor.read_type_tag()?;
        let val = cursor.read_value_by_type(&typ)?;
        objects.push(val);
    }

    Ok(RelayMessage { id, objects })
}

pub struct BinaryCursor<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> BinaryCursor<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Self { data, pos: 0 }
    }

    pub fn remaining(&self) -> usize {
        self.data.len().saturating_sub(self.pos)
    }

    pub fn read_exact(&mut self, len: usize) -> Result<&'a [u8]> {
        if self.pos + len > self.data.len() {
            bail!(
                "Unexpected EOF reading {} bytes at pos {} (total {})",
                len,
                self.pos,
                self.data.len()
            );
        }
        let slice = &self.data[self.pos..self.pos + len];
        self.pos += len;
        Ok(slice)
    }

    pub fn read_u8(&mut self) -> Result<u8> {
        let b = self.read_exact(1)?;
        Ok(b[0])
    }

    pub fn read_i32(&mut self) -> Result<i32> {
        let b = self.read_exact(4)?;
        Ok(i32::from_be_bytes([b[0], b[1], b[2], b[3]]))
    }

    pub fn read_type_tag(&mut self) -> Result<String> {
        let b = self.read_exact(3)?;
        Ok(String::from_utf8_lossy(b).into_owned())
    }

    pub fn read_buffer(&mut self) -> Result<Option<Vec<u8>>> {
        let len = self.read_i32()?;
        if len < 0 {
            return Ok(None);
        }
        let bytes = self.read_exact(len as usize)?;
        Ok(Some(bytes.to_vec()))
    }

    pub fn read_string(&mut self) -> Result<Option<String>> {
        let buf = self.read_buffer()?;
        Ok(buf.map(|b| String::from_utf8_lossy(&b).into_owned()))
    }

    pub fn read_short_ascii(&mut self) -> Result<String> {
        let len = self.read_u8()? as usize;
        let bytes = self.read_exact(len)?;
        Ok(String::from_utf8_lossy(bytes).into_owned())
    }

    pub fn read_pointer(&mut self) -> Result<String> {
        let raw = self.read_short_ascii()?;
        Ok(super::types::normalize_ptr(&raw))
    }

    pub fn read_long(&mut self) -> Result<i64> {
        let s = self.read_short_ascii()?;
        s.parse::<i64>()
            .with_context(|| format!("Invalid lon value '{}'", s))
    }

    pub fn read_time(&mut self) -> Result<i64> {
        let s = self.read_short_ascii()?;
        s.parse::<i64>()
            .with_context(|| format!("Invalid tim value '{}'", s))
    }

    pub fn read_value_by_type(&mut self, typ: &str) -> Result<RelayValue> {
        match typ {
            "chr" => Ok(RelayValue::Char(self.read_u8()?)),
            "int" => Ok(RelayValue::Int(self.read_i32()?)),
            "lon" => Ok(RelayValue::Long(self.read_long()?)),
            "str" => Ok(RelayValue::Str(self.read_string()?)),
            "buf" => Ok(RelayValue::Buf(self.read_buffer()?)),
            "ptr" => Ok(RelayValue::Ptr(self.read_pointer()?)),
            "tim" => Ok(RelayValue::Time(self.read_time()?)),
            "htb" => {
                let key_type = self.read_type_tag()?;
                let val_type = self.read_type_tag()?;
                let count = self.read_i32()?;
                if count < 0 {
                    bail!("Negative hashtable count: {}", count);
                }
                let mut entries = Vec::with_capacity(count as usize);
                for _ in 0..count {
                    let k = self.read_value_by_type(&key_type)?;
                    let v = self.read_value_by_type(&val_type)?;
                    entries.push((k, v));
                }
                Ok(RelayValue::HashTable(entries))
            }
            "hda" => {
                let hpath = self.read_string()?.unwrap_or_default();
                let keys_spec = self.read_string()?.unwrap_or_default();
                let count = self.read_i32()?;
                if count < 0 {
                    bail!("Negative hdata count: {}", count);
                }

                let path_depth = if hpath.is_empty() {
                    0
                } else {
                    hpath.split('/').count()
                };

                let mut keys = Vec::new();
                if !keys_spec.is_empty() {
                    for pair in keys_spec.split(',') {
                        let (k, t) = pair
                            .split_once(':')
                            .ok_or_else(|| anyhow!("Invalid hdata key spec '{}'", pair))?;
                        keys.push((k.to_string(), t.to_string()));
                    }
                }

                let mut items = Vec::with_capacity(count as usize);
                for _ in 0..count {
                    let mut pointers = Vec::with_capacity(path_depth);
                    for _ in 0..path_depth {
                        pointers.push(self.read_pointer()?);
                    }
                    let mut values = HashMap::with_capacity(keys.len());
                    for (k, t) in &keys {
                        let v = self.read_value_by_type(t)?;
                        values.insert(k.clone(), v);
                    }
                    items.push(HdataItem { pointers, values });
                }

                Ok(RelayValue::Hdata(HdataObject { hpath, keys, items }))
            }
            "inf" => {
                let name = self.read_string()?.unwrap_or_default();
                let value = self.read_string()?.unwrap_or_default();
                Ok(RelayValue::Info(name, value))
            }
            "inl" => {
                let name = self.read_string()?.unwrap_or_default();
                let item_count = self.read_i32()?;
                if item_count < 0 {
                    bail!("Negative infolist item count: {}", item_count);
                }
                let mut items = Vec::with_capacity(item_count as usize);
                for _ in 0..item_count {
                    let var_count = self.read_i32()?;
                    if var_count < 0 {
                        bail!("Negative infolist variable count: {}", var_count);
                    }
                    let mut map = HashMap::with_capacity(var_count as usize);
                    for _ in 0..var_count {
                        let var_name = self.read_string()?.unwrap_or_default();
                        let var_type = self.read_type_tag()?;
                        let var_val = self.read_value_by_type(&var_type)?;
                        map.insert(var_name, var_val);
                    }
                    items.push(map);
                }
                Ok(RelayValue::Infolist(InfolistObject { name, items }))
            }
            "arr" => {
                let elem_type = self.read_type_tag()?;
                let count = self.read_i32()?;
                if count < 0 {
                    bail!("Negative array count: {}", count);
                }
                let mut arr = Vec::with_capacity(count as usize);
                for _ in 0..count {
                    arr.push(self.read_value_by_type(&elem_type)?);
                }
                Ok(RelayValue::Array(arr))
            }
            other => bail!("Unknown WeeChat binary type tag '{}'", other),
        }
    }
}

/// Helper to build binary WeeChat Relay frames for unit and integration tests.
#[cfg(test)]
pub struct FrameBuilder {
    payload: Vec<u8>,
}

#[cfg(test)]
impl FrameBuilder {
    pub fn new(id: &str) -> Self {
        let mut b = Self {
            payload: Vec::new(),
        };
        b.write_str_raw(Some(id));
        b
    }

    pub fn write_u8(&mut self, v: u8) {
        self.payload.push(v);
    }

    pub fn write_i32(&mut self, v: i32) {
        self.payload.extend_from_slice(&v.to_be_bytes());
    }

    pub fn write_tag(&mut self, tag: &[u8; 3]) {
        self.payload.extend_from_slice(tag);
    }

    pub fn write_str_raw(&mut self, s: Option<&str>) {
        match s {
            Some(text) => {
                let bytes = text.as_bytes();
                self.write_i32(bytes.len() as i32);
                self.payload.extend_from_slice(bytes);
            }
            None => self.write_i32(-1),
        }
    }

    pub fn write_short_ascii(&mut self, s: &str) {
        let bytes = s.as_bytes();
        self.write_u8(bytes.len() as u8);
        self.payload.extend_from_slice(bytes);
    }

    pub fn write_ptr_raw(&mut self, ptr: &str) {
        let stripped = ptr.strip_prefix("0x").unwrap_or(ptr);
        self.write_short_ascii(stripped);
    }

    pub fn add_str(&mut self, s: Option<&str>) -> &mut Self {
        self.write_tag(b"str");
        self.write_str_raw(s);
        self
    }

    pub fn add_int(&mut self, v: i32) -> &mut Self {
        self.write_tag(b"int");
        self.write_i32(v);
        self
    }

    pub fn add_info(&mut self, name: &str, value: &str) -> &mut Self {
        self.write_tag(b"inf");
        self.write_str_raw(Some(name));
        self.write_str_raw(Some(value));
        self
    }

    pub fn finish_uncompressed(&self) -> Vec<u8> {
        let total_len = (5 + self.payload.len()) as u32;
        let mut frame = Vec::with_capacity(total_len as usize);
        frame.extend_from_slice(&total_len.to_be_bytes());
        frame.push(COMPRESSION_OFF);
        frame.extend_from_slice(&self.payload);
        frame
    }

    pub fn finish_zlib(&self) -> Vec<u8> {
        use flate2::Compression;
        use flate2::write::ZlibEncoder;
        use std::io::Write;

        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(&self.payload).unwrap();
        let compressed = encoder.finish().unwrap();

        let total_len = (5 + compressed.len()) as u32;
        let mut frame = Vec::with_capacity(total_len as usize);
        frame.extend_from_slice(&total_len.to_be_bytes());
        frame.push(COMPRESSION_ZLIB);
        frame.extend_from_slice(&compressed);
        frame
    }

    pub fn finish_zstd(&self) -> Vec<u8> {
        let compressed = zstd::stream::encode_all(self.payload.as_slice(), 3).unwrap();
        let total_len = (5 + compressed.len()) as u32;
        let mut frame = Vec::with_capacity(total_len as usize);
        frame.extend_from_slice(&total_len.to_be_bytes());
        frame.push(COMPRESSION_ZSTD);
        frame.extend_from_slice(&compressed);
        frame
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_uncompressed_zlib_and_zstd_frames() {
        let mut builder = FrameBuilder::new("test_id");
        builder
            .add_int(42)
            .add_str(Some("hello weechat"))
            .add_str(None)
            .add_info("version", "4.4.0");

        for frame in [
            builder.finish_uncompressed(),
            builder.finish_zlib(),
            builder.finish_zstd(),
        ] {
            let msg = parse_frame(&frame).expect("Should parse frame");
            assert_eq!(msg.id, "test_id");
            assert_eq!(msg.objects.len(), 4);
            assert_eq!(msg.objects[0], RelayValue::Int(42));
            assert_eq!(
                msg.objects[1],
                RelayValue::Str(Some("hello weechat".to_string()))
            );
            assert_eq!(msg.objects[2], RelayValue::Str(None));
            assert_eq!(
                msg.objects[3],
                RelayValue::Info("version".to_string(), "4.4.0".to_string())
            );
        }
    }

    #[test]
    fn test_parse_hdata_and_hashtable() {
        let mut b = FrameBuilder::new("listbuffers");
        b.write_tag(b"hda");
        b.write_str_raw(Some("buffer"));
        b.write_str_raw(Some("number:int,short_name:str,local_variables:htb"));
        b.write_i32(1); // 1 row
        b.write_ptr_raw("0x55aabbcc");
        b.write_i32(2);
        b.write_str_raw(Some("#rust"));
        // local_variables hashtable
        b.write_tag(b"str");
        b.write_tag(b"str");
        b.write_i32(2);
        b.write_str_raw(Some("type"));
        b.write_str_raw(Some("channel"));
        b.write_str_raw(Some("server"));
        b.write_str_raw(Some("libera"));

        let msg = parse_frame(&b.finish_uncompressed()).unwrap();
        assert_eq!(msg.id, "listbuffers");
        match &msg.objects[0] {
            RelayValue::Hdata(hda) => {
                assert_eq!(hda.hpath, "buffer");
                assert_eq!(hda.items.len(), 1);
                let item = &hda.items[0];
                assert_eq!(item.last_ptr(), "0x55aabbcc");
                assert_eq!(item.get_i32("number"), 2);
                assert_eq!(item.get_str("short_name"), "#rust");
                let vars = item.values.get("local_variables").unwrap().as_string_map();
                assert_eq!(vars.get("type").map(|s| s.as_str()), Some("channel"));
                assert_eq!(vars.get("server").map(|s| s.as_str()), Some("libera"));
            }
            other => panic!("Expected Hdata, got {:?}", other),
        }
    }
}
