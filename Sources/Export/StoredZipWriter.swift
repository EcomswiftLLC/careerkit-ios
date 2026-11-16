import Foundation

/// CRC-32 (IEEE 802.3, the one ZIP uses). Pure Swift, table driven.
enum CRC32 {
    private static let table: [UInt32] = {
        var values: [UInt32] = []
        values.reserveCapacity(256)
        for i in 0..<256 {
            var c: UInt32 = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) != 0 {
                    c = 0xEDB8_8320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            values.append(c)
        }
        return values
    }()

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        let lookup: [UInt32] = table
        for byte in data {
            let index: Int = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = lookup[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        return checksum(Data(bytes))
    }
}

/// Writes a ZIP archive with every entry STORED (no compression). That is all a .docx package needs,
/// and it keeps the writer small and easy to verify.
struct StoredZipWriter {
    struct Entry {
        let name: String
        let data: Data
    }

    private(set) var entries: [Entry] = []
    /// Modification time written into every entry.
    var date: Date

    init(date: Date = Date()) {
        self.date = date
    }

    mutating func add(_ name: String, data: Data) {
        entries.append(Entry(name: name, data: data))
    }

    mutating func add(_ name: String, text: String) {
        entries.append(Entry(name: name, data: Data(text.utf8)))
    }

    /// MS-DOS time and date fields.
    static func dosDateTime(_ date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone.current
        let c: DateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year: Int = min(max((c.year ?? 1980) - 1980, 0), 127)
        let month: Int = c.month ?? 1
        let day: Int = c.day ?? 1
        let hour: Int = c.hour ?? 0
        let minute: Int = c.minute ?? 0
        let second: Int = (c.second ?? 0) / 2
        let time: UInt16 = UInt16(truncatingIfNeeded: (hour << 11) | (minute << 5) | second)
        let day16: UInt16 = UInt16(truncatingIfNeeded: (year << 9) | (month << 5) | day)
        return (time, day16)
    }

    func archive() -> Data {
        var out: [UInt8] = []
        var central: [UInt8] = []
        let stamp = StoredZipWriter.dosDateTime(date)

        for entry in entries {
            let nameBytes: [UInt8] = Array(entry.name.utf8)
            let crc: UInt32 = CRC32.checksum(entry.data)
            let size: UInt32 = UInt32(truncatingIfNeeded: entry.data.count)
            let offset: UInt32 = UInt32(truncatingIfNeeded: out.count)
            // Bit 11: file names are UTF-8.
            let flags: UInt16 = 0x0800

            // Local file header.
            appendLE32(&out, 0x0403_4B50)
            appendLE16(&out, 20)            // version needed to extract
            appendLE16(&out, flags)
            appendLE16(&out, 0)             // method: stored
            appendLE16(&out, stamp.time)
            appendLE16(&out, stamp.date)
            appendLE32(&out, crc)
            appendLE32(&out, size)          // compressed size
            appendLE32(&out, size)          // uncompressed size
            appendLE16(&out, UInt16(truncatingIfNeeded: nameBytes.count))
            appendLE16(&out, 0)             // extra field length
            out.append(contentsOf: nameBytes)
            out.append(contentsOf: [UInt8](entry.data))

            // Central directory record.
            appendLE32(&central, 0x0201_4B50)
            appendLE16(&central, 20)        // version made by
            appendLE16(&central, 20)        // version needed to extract
            appendLE16(&central, flags)
            appendLE16(&central, 0)
            appendLE16(&central, stamp.time)
            appendLE16(&central, stamp.date)
            appendLE32(&central, crc)
            appendLE32(&central, size)
            appendLE32(&central, size)
            appendLE16(&central, UInt16(truncatingIfNeeded: nameBytes.count))
            appendLE16(&central, 0)         // extra field length
            appendLE16(&central, 0)         // comment length
            appendLE16(&central, 0)         // disk number start
            appendLE16(&central, 0)         // internal attributes
            appendLE32(&central, 0)         // external attributes
            appendLE32(&central, offset)
            central.append(contentsOf: nameBytes)
        }

        let centralOffset: UInt32 = UInt32(truncatingIfNeeded: out.count)
        let centralSize: UInt32 = UInt32(truncatingIfNeeded: central.count)
        out.append(contentsOf: central)

        // End of central directory record.
        let count: UInt16 = UInt16(truncatingIfNeeded: entries.count)
        appendLE32(&out, 0x0605_4B50)
        appendLE16(&out, 0)                 // this disk
        appendLE16(&out, 0)                 // disk with the central directory
        appendLE16(&out, count)
        appendLE16(&out, count)
        appendLE32(&out, centralSize)
        appendLE32(&out, centralOffset)
        appendLE16(&out, 0)                 // comment length
        return Data(out)
    }

    private func appendLE16(_ bytes: inout [UInt8], _ value: UInt16) {
        bytes.append(UInt8(truncatingIfNeeded: value))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private func appendLE32(_ bytes: inout [UInt8], _ value: UInt32) {
        bytes.append(UInt8(truncatingIfNeeded: value))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value >> 16))
        bytes.append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
