import Foundation
import Postbox

public enum LocalizationEntry: Equatable {
    case string(key: String, value: String)
    case pluralizedString(key: String, zero: String?, one: String?, two: String?, few: String?, many: String?, other: String)
    
    public var key: String {
        switch self {
        case let .string(key, _):
            return key
        case let .pluralizedString(key, _, _, _, _, _, _):
            return key
        }
    }
}

private struct LocalizationEntryFlags: OptionSet {
    var rawValue: Int8
    
    init(rawValue: Int8) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    static let pluralized = LocalizationEntryFlags(rawValue: (1 << 0))
    static let hasZero = LocalizationEntryFlags(rawValue: (1 << 1))
    static let hasOne = LocalizationEntryFlags(rawValue: (1 << 2))
    static let hasTwo = LocalizationEntryFlags(rawValue: (1 << 3))
    static let hasFew = LocalizationEntryFlags(rawValue: (1 << 4))
    static let hasMany = LocalizationEntryFlags(rawValue: (1 << 5))
}

private func writeString(_ buffer: WriteBuffer, _ string: String) {
    if let data = string.data(using: .utf8) {
        var length: Int32 = Int32(data.count)
        buffer.write(&length, offset: 0, length: 4)
        buffer.write(data)
    } else {
        var length: Int32 = 0
        buffer.write(&length, offset: 0, length: 4)
    }
}

public final class Localization: Codable, Equatable {
    public let version: Int32
    public let entries: [LocalizationEntry]
    
    public init(version: Int32, entries: [LocalizationEntry]) {
        self.version = version
        self.entries = entries
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.version = (try? container.decode(Int32.self, forKey: "v")) ?? 0

        let count = (try? container.decode(Int32.self, forKey: "c")) ?? 0
        var entries: [LocalizationEntry] = []
        if count >= 0, let rawData = try? container.decodeIfPresent(Data.self, forKey: "d") {
            let data = ReadBuffer(data: rawData)

            // This buffer is persisted (and can arrive via a server-pushed
            // localization update), so a truncated or corrupt record must
            // not be trusted blindly: ReadBuffer.read() does a raw memcpy
            // with no bounds check, and `0 ..< count` traps on a negative
            // count. A bad record previously crashed on decode and then
            // crash-looped on every relaunch since the record persists.
            // Bail out of the whole parse (keeping entries decoded so far)
            // as soon as a length-prefixed read would go out of bounds;
            // invalid UTF-8 in an otherwise in-bounds string is unrelated
            // to buffer safety and only drops that one entry, as before.
            func readLengthPrefixedData() -> Data? {
                guard data.offset + 4 <= data.length else { return nil }
                var length: Int32 = 0
                data.read(&length, offset: 0, length: 4)
                guard length >= 0, data.offset + Int(length) <= data.length else { return nil }
                let valueData = Data(bytes: data.memory.advanced(by: data.offset), count: Int(length))
                data.skip(Int(length))
                return valueData
            }

            outer: for _ in 0 ..< count {
                guard data.offset + 1 <= data.length else { break }
                var flagsValue: Int8 = 0
                data.read(&flagsValue, offset: 0, length: 1)
                let flags = LocalizationEntryFlags(rawValue: flagsValue)

                guard let keyData = readLengthPrefixedData() else { break }
                let key = String(data: keyData, encoding: .utf8)

                if flags.contains(.pluralized) {
                    var zero: String?
                    var one: String?
                    var two: String?
                    var few: String?
                    var many: String?
                    var other: String?

                    if flags.contains(.hasZero) {
                        guard let valueData = readLengthPrefixedData() else { break outer }
                        zero = String(data: valueData, encoding: .utf8)
                    }

                    if flags.contains(.hasOne) {
                        guard let valueData = readLengthPrefixedData() else { break outer }
                        one = String(data: valueData, encoding: .utf8)
                    }

                    if flags.contains(.hasTwo) {
                        guard let valueData = readLengthPrefixedData() else { break outer }
                        two = String(data: valueData, encoding: .utf8)
                    }

                    if flags.contains(.hasFew) {
                        guard let valueData = readLengthPrefixedData() else { break outer }
                        few = String(data: valueData, encoding: .utf8)
                    }

                    if flags.contains(.hasMany) {
                        guard let valueData = readLengthPrefixedData() else { break outer }
                        many = String(data: valueData, encoding: .utf8)
                    }

                    guard let otherData = readLengthPrefixedData() else { break outer }
                    other = String(data: otherData, encoding: .utf8)

                    if let key = key, let other = other {
                        entries.append(.pluralizedString(key: key, zero: zero, one: one, two: two, few: few, many: many, other: other))
                    }
                } else {
                    guard let valueData = readLengthPrefixedData() else { break }
                    let value = String(data: valueData, encoding: .utf8)

                    if let key = key, let value = value {
                        entries.append(.string(key: key, value: value))
                    }
                }
            }
        }
        self.entries = entries
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.version, forKey: "v")
        try container.encode(Int32(self.entries.count), forKey: "c")
        
        let buffer = WriteBuffer()
        for entry in self.entries {
            var flags: LocalizationEntryFlags = []
            switch entry {
                case .string:
                    flags = []
                case let .pluralizedString(_, zero, one, two, few, many, _):
                    flags.insert(.pluralized)
                    if zero != nil {
                        flags.insert(.hasZero)
                    }
                    if one != nil {
                        flags.insert(.hasOne)
                    }
                    if two != nil {
                        flags.insert(.hasTwo)
                    }
                    if few != nil {
                        flags.insert(.hasFew)
                    }
                    if many != nil {
                        flags.insert(.hasMany)
                    }
            }
            var flagsValue: Int8 = flags.rawValue
            buffer.write(&flagsValue, offset: 0, length: 1)
            
            switch entry {
                case let .string(key, value):
                    writeString(buffer, key)
                    writeString(buffer, value)
                case let .pluralizedString(key, zero, one, two, few, many, other):
                    writeString(buffer, key)
                    if let zero = zero {
                        writeString(buffer, zero)
                    }
                    if let one = one {
                        writeString(buffer, one)
                    }
                    if let two = two {
                        writeString(buffer, two)
                    }
                    if let few = few {
                        writeString(buffer, few)
                    }
                    if let many = many {
                        writeString(buffer, many)
                    }
                    writeString(buffer, other)
            }
        }
        try container.encode(buffer.makeData(), forKey: "d")
    }
    
    public static func ==(lhs: Localization, rhs: Localization) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.entries == rhs.entries {
            return true
        }
        return false
    }
}
