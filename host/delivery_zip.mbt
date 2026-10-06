///|
fn delivery_crc32(bytes : Bytes) -> UInt {
  let mut crc = 0xffffffffU
  for byte in bytes {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) != 0U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc ^ 0xffffffffU
}

///|
// Standard ZIP store format. Fixed ASCII filenames, UTF-8 flag, deterministic
// 1980-01-01 timestamp, no compression and no platform executable attributes.
fn delivery_zip(files : Array[(String, Bytes)]) -> Bytes {
  let zip = @buffer.Buffer()
  let central = @buffer.Buffer()
  for item in files {
    let (name, bytes) = item
    let filename = @utf8.encode(name)
    let offset = zip.length()
    let crc = delivery_crc32(bytes)
    zip.write_uint_le(0x04034b50U)
    zip.write_uint16_le(20)
    zip.write_uint16_le(0x0800)
    zip.write_uint16_le(0)
    zip.write_uint16_le(0)
    zip.write_uint16_le(33)
    zip.write_uint_le(crc)
    zip.write_int_le(bytes.length())
    zip.write_int_le(bytes.length())
    zip.write_uint16_le(filename.length().to_uint16())
    zip.write_uint16_le(0)
    zip.write_bytes(filename)
    zip.write_bytes(bytes)
    central.write_uint_le(0x02014b50U)
    central.write_uint16_le(20)
    central.write_uint16_le(20)
    central.write_uint16_le(0x0800)
    central.write_uint16_le(0)
    central.write_uint16_le(0)
    central.write_uint16_le(33)
    central.write_uint_le(crc)
    central.write_int_le(bytes.length())
    central.write_int_le(bytes.length())
    central.write_uint16_le(filename.length().to_uint16())
    central.write_uint16_le(0)
    central.write_uint16_le(0)
    central.write_uint16_le(0)
    central.write_uint16_le(0)
    central.write_uint_le(0U)
    central.write_int_le(offset)
    central.write_bytes(filename)
  }
  let start = zip.length()
  zip.write_bytes(central.to_bytes())
  zip.write_uint_le(0x06054b50U)
  zip.write_uint16_le(0)
  zip.write_uint16_le(0)
  zip.write_uint16_le(files.length().to_uint16())
  zip.write_uint16_le(files.length().to_uint16())
  zip.write_int_le(central.length())
  zip.write_int_le(start)
  zip.write_uint16_le(0)
  zip.to_bytes()
}
