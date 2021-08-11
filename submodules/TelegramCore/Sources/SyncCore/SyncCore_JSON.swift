import Postbox

public indirect enum JSON: PostboxCoding, Equatable {
    case null
    case number(Double)
    case string(String)
    case bool(Bool)
    case array([JSON])
    case dictionary([String: JSON])
    
    private enum ValueType: Int32 {
        case null = 0
        case number = 1
        case string = 2
        case bool = 3
        case array = 4
        case dictionary = 5
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case ValueType.null.rawValue:
                self = .null
            case ValueType.number.rawValue:
                self = .number(decoder.decodeDoubleForKey("v", orElse: 0.0))
            case ValueType.string.rawValue:
                self = .string(decoder.decodeStringForKey("v", orElse: ""))
            case ValueType.bool.rawValue:
                self = .bool(decoder.decodeBoolForKey("v", orElse: false))
            case ValueType.array.rawValue:
                self = .array(decoder.decodeObjectArrayForKey("v"))
            case ValueType.dictionary.rawValue:
                self = .dictionary(decoder.decodeObjectDictionaryForKey("v", keyDecoder: { $0.decodeStringForKey("k", orElse: "")
                }, valueDecoder: { JSON(decoder: $0) }))
            default:
                self = .null
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .null:
                encoder.encodeInt32(ValueType.null.rawValue, forKey: "r")
            case let .number(value):
                encoder.encodeInt32(ValueType.number.rawValue, forKey: "r")
                encoder.encodeDouble(value, forKey: "v")
            case let .string(value):
                encoder.encodeInt32(ValueType.string.rawValue, forKey: "r")
                encoder.encodeString(value, forKey: "v")
            case let .bool(value):
                encoder.encodeInt32(ValueType.bool.rawValue, forKey: "r")
                encoder.encodeBool(value, forKey: "v")
            case let .array(value):
                encoder.encodeInt32(ValueType.array.rawValue, forKey: "r")
                encoder.encodeObjectArray(value, forKey: "v")
            case let .dictionary(value):
                encoder.encodeInt32(ValueType.dictionary.rawValue, forKey: "r")
                encoder.encodeObjectDictionary(value, forKey: "v") { key, encoder in
                    encoder.encodeString(key, forKey: "k")
                }
        }
    }
    
    public enum Index: Comparable {
        case array(Int)
        case dictionary(DictionaryIndex<String, JSON>)
        case null
        
        static public func ==(lhs: Index, rhs: Index) -> Bool {
            switch (lhs, rhs) {
                case let (.array(lhs), .array(rhs)):
                    return lhs == rhs
                case let (.dictionary(lhs), .dictionary(rhs)):
                    return lhs == rhs
                case (.null, .null):
                    return true
                default:
                    return false
            }
        }
        
        static public func <(lhs: Index, rhs: Index) -> Bool {
            switch (lhs, rhs) {
                case let (.array(lhs), .array(rhs)):
                    return lhs < rhs
                case let (.dictionary(lhs), .dictionary(rhs)):
                    return lhs < rhs
                default:
                    return false
            }
        }
    }
}
