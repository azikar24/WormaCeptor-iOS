import Foundation

/// A parsed JSON body. Objects keep their key order, which `JSONSerialization` drops.
indirect enum JsonValue: Equatable {
    case object([JsonMember])
    case array([JsonValue])
    case string(String)
    /// The number as written, so `1.0` and big integers read back unchanged.
    case number(String)
    case bool(Bool)
    case null

    /// Single-line JSON, for the raw view.
    var compact: String {
        var out = ""
        write(to: &out)
        return out
    }

    private func write(to out: inout String) {
        switch self {
        case .object(let members):
            out += "{"
            for (index, member) in members.enumerated() {
                if index > 0 { out += "," }
                out += JsonValue.quoted(member.key) + ":"
                member.value.write(to: &out)
            }
            out += "}"
        case .array(let items):
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += "," }
                item.write(to: &out)
            }
            out += "]"
        case .string(let text): out += JsonValue.quoted(text)
        case .number(let text): out += text
        case .bool(let value): out += value ? "true" : "false"
        case .null: out += "null"
        }
    }

    static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

struct JsonMember: Equatable {
    let key: String
    let value: JsonValue
}

/// A small recursive-descent parser over UTF-8 bytes. Returns nil for anything that isn't one JSON object or array.
struct JsonParser {
    private let bytes: [UInt8]
    private var position = 0

    static func parse(_ text: String) -> JsonValue? {
        var parser = JsonParser(bytes: Array(text.utf8))
        parser.skipWhitespace()
        guard let first = parser.peek, first == UInt8(ascii: "{") || first == UInt8(ascii: "[") else { return nil }
        guard let value = parser.value() else { return nil }
        parser.skipWhitespace()
        return parser.position == parser.bytes.count ? value : nil
    }

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    private var peek: UInt8? {
        position < bytes.count ? bytes[position] : nil
    }

    private mutating func skipWhitespace() {
        while let byte = peek, byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
            position += 1
        }
    }

    private mutating func consume(_ literal: String) -> Bool {
        let expected = Array(literal.utf8)
        guard position + expected.count <= bytes.count,
              Array(bytes[position..<position + expected.count]) == expected else { return false }
        position += expected.count
        return true
    }

    private mutating func value() -> JsonValue? {
        skipWhitespace()
        switch peek {
        case UInt8(ascii: "{"): return object()
        case UInt8(ascii: "["): return array()
        case UInt8(ascii: "\""): return string().map(JsonValue.string)
        case UInt8(ascii: "t"): return consume("true") ? .bool(true) : nil
        case UInt8(ascii: "f"): return consume("false") ? .bool(false) : nil
        case UInt8(ascii: "n"): return consume("null") ? .null : nil
        case .some: return number()
        case .none: return nil
        }
    }

    private mutating func object() -> JsonValue? {
        position += 1
        var members: [JsonMember] = []
        skipWhitespace()
        if peek == UInt8(ascii: "}") {
            position += 1
            return .object(members)
        }
        while true {
            skipWhitespace()
            guard peek == UInt8(ascii: "\""), let key = string() else { return nil }
            skipWhitespace()
            guard peek == UInt8(ascii: ":") else { return nil }
            position += 1
            guard let item = value() else { return nil }
            members.append(JsonMember(key: key, value: item))
            skipWhitespace()
            switch peek {
            case UInt8(ascii: ","): position += 1
            case UInt8(ascii: "}"):
                position += 1
                return .object(members)
            default: return nil
            }
        }
    }

    private mutating func array() -> JsonValue? {
        position += 1
        var items: [JsonValue] = []
        skipWhitespace()
        if peek == UInt8(ascii: "]") {
            position += 1
            return .array(items)
        }
        while true {
            guard let item = value() else { return nil }
            items.append(item)
            skipWhitespace()
            switch peek {
            case UInt8(ascii: ","): position += 1
            case UInt8(ascii: "]"):
                position += 1
                return .array(items)
            default: return nil
            }
        }
    }

    private mutating func number() -> JsonValue? {
        let start = position
        while let byte = peek, (0x30...0x39).contains(byte) || "+-.eE".utf8.contains(byte) {
            position += 1
        }
        guard position > start else { return nil }
        return .number(String(decoding: bytes[start..<position], as: UTF8.self))
    }

    private mutating func string() -> String? {
        position += 1
        var out: [UInt8] = []
        while let byte = peek {
            position += 1
            switch byte {
            case UInt8(ascii: "\""):
                return String(decoding: out, as: UTF8.self)
            case UInt8(ascii: "\\"):
                guard let escaped = escape() else { return nil }
                out.append(contentsOf: escaped)
            default:
                out.append(byte)
            }
        }
        return nil
    }

    private mutating func escape() -> [UInt8]? {
        guard let byte = peek else { return nil }
        position += 1
        switch byte {
        case UInt8(ascii: "n"): return [0x0A]
        case UInt8(ascii: "r"): return [0x0D]
        case UInt8(ascii: "t"): return [0x09]
        case UInt8(ascii: "b"): return [0x08]
        case UInt8(ascii: "f"): return [0x0C]
        case UInt8(ascii: "u"): return unicodeEscape()
        default: return [byte]
        }
    }

    private mutating func unicodeEscape() -> [UInt8]? {
        guard var code = hex4() else { return nil }
        if (0xD800...0xDBFF).contains(code), consume("\\u"), let low = hex4(), (0xDC00...0xDFFF).contains(low) {
            code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
        }
        let scalar = Unicode.Scalar(code) ?? "\u{FFFD}"
        return Array(String(scalar).utf8)
    }

    private mutating func hex4() -> UInt32? {
        guard position + 4 <= bytes.count,
              let value = UInt32(String(decoding: bytes[position..<position + 4], as: UTF8.self), radix: 16)
        else { return nil }
        position += 4
        return value
    }
}
