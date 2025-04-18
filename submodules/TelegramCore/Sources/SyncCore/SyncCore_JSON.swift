import Postbox

public indirect enum JSON: Codable, Equatable {
    private struct DictionaryKey: Codable, Hashable {
        var key: String

        init(_ key: String) {
            self.key = key
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.key = try container.decode(String.self, forKey: "k")
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.key, forKey: "k")
        }
    }

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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch try container.decode(Int32.self, forKey: "r") {
            case ValueType.null.rawValue:
                self = .null
            case ValueType.number.rawValue:
                self = .number(try container.decode(Double.self, forKey: "v"))
            case ValueType.string.rawValue:
                self = .string(try container.decode(String.self, forKey: "v"))
            case ValueType.bool.rawValue:
                self = .bool(try container.decode(Bool.self, forKey: "v"))
            case ValueType.array.rawValue:
                self = .array(try container.decode([JSON].self, forKey: "v"))
            case ValueType.dictionary.rawValue:
                let dict = try container.decode([DictionaryKey: JSON].self, forKey: "v")
                var mappedDict: [String: JSON] = [:]
                for (key, value) in dict {
                    mappedDict[key.key] = value
                }
                self = .dictionary(mappedDict)
            default:
                self = .null
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
            case .null:
                try container.encode(ValueType.null.rawValue, forKey: "r")
            case let .number(value):
                try container.encode(ValueType.number.rawValue, forKey: "r")
                try container.encode(value, forKey: "v")
            case let .string(value):
                try container.encode(ValueType.string.rawValue, forKey: "r")
                try container.encode(value, forKey: "v")
            case let .bool(value):
                try container.encode(ValueType.bool.rawValue, forKey: "r")
                try container.encode(value, forKey: "v")
            case let .array(value):
                try container.encode(ValueType.array.rawValue, forKey: "r")
                try container.encode(value, forKey: "v")
            case let .dictionary(value):
                try container.encode(ValueType.dictionary.rawValue, forKey: "r")
                var mappedDict: [DictionaryKey: JSON] = [:]
                for (k, v) in value {
                    mappedDict[DictionaryKey(k)] = v
                }
                try container.encode(mappedDict, forKey: "v")
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
