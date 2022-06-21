import Foundation
import Postbox
import TelegramApi

extension JSON {
    private init?(_ object: Any) {
        if let object = object as? JSONValue {
            self = object.jsonValue
        } else if let dict = object as? [String: Any] {
            var values: [String: JSON] = [:]
            for (key, value) in dict {
                if let v = JSON(value) {
                    values[key] = v
                } else {
                    return nil
                }
            }
            self = .dictionary(values)
        } else if let array = object as? [Any] {
            var values: [JSON] = []
            for value in array {
                if let v = JSON(value) {
                    values.append(v)
                } else {
                    return nil
                }
            }
            self = .array(values)
        } else if let value = object as? String {
            self = .string(value)
        } else if let value = object as? Int {
            self = .number(Double(value))
        } else {
            return nil
        }
    }
    
    public init?(data: Data) {
        if let object = try? JSONSerialization.jsonObject(with: data, options: []) {
            self.init(object)
        } else {
            return nil
        }
    }
    
    public init?(string: String) {
        if let data = string.data(using: .utf8) {
            self.init(data: data)
        } else {
            return nil
        }
    }
}

extension JSON: Collection {
    public var startIndex: Index {
        switch self {
            case let .array(value):
                return .array(value.startIndex)
            case let .dictionary(value):
                return .dictionary(value.startIndex)
            default:
                return .null
        }
    }
    
    public var endIndex: Index {
        switch self {
            case let .array(value):
                return .array(value.endIndex)
            case let .dictionary(value):
                return .dictionary(value.endIndex)
            default:
                return .null
        }
    }
    
    public func index(after i: Index) -> Index {
        switch (i, self) {
            case let (.array(index), .array(value)):
                return .array(value.index(after: index))
            case let (.dictionary(index), .dictionary(value)):
                return .dictionary(value.index(after: index))
            default:
                return .null
        }
    }
    
    public subscript (position: Index) -> (String, JSON) {
        switch (position, self) {
            case let (.array(index), .array(value)):
                return (String(index), value[index])
            case let (.dictionary(index), .dictionary(value)):
                let (key, value) = value[index]
                return (key, value)
            default:
                return ("", .null)
        }
    }
}

public enum JSONKey {
    case index(Int)
    case key(String)
}

public protocol JSONSubscriptType {
    var jsonKey: JSONKey { get }
}

extension Int: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return .index(self)
    }
}

extension String: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return .key(self)
    }
}

extension JSON {
    fileprivate var value: JSONElement {
        get {
            switch self {
                case .null:
                    return 0
                case let .number(value):
                    return value
                case let .string(value):
                    return value
                case let .bool(value):
                    return value
                case let .array(values):
                    var array: [JSONElement] = []
                    for value in values {
                        array.append(value.value)
                    }
                    return array
                case let .dictionary(values):
                    var dictionary: [String: JSONElement] = [:]
                    for (key, value) in values {
                        dictionary[key] = value.value
                    }
                    return dictionary
            }
        }
    }
}

extension JSON {
    public subscript(key: JSONSubscriptType) -> JSONElement? {
        get {
            switch (key.jsonKey, self) {
                case let (.index(index), .array(value)):
                    if value.indices.contains(index) {
                        return value[index].value
                    } else {
                        return nil
                    }
                case let (.key(key), .dictionary(value)):
                    if let value = value[key] {
                        return value.value
                    } else {
                        return nil
                    }
                default:
                    return nil
            }
        }
    }
}

extension JSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self = .dictionary(elements.reduce([String: JSON]()) { (dictionary, element) in
            var dictionary = dictionary
            if let value = JSON(element.1) {
                dictionary[element.0] = value
            }
            return dictionary
        })
    }
}

extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self = .array(elements.compactMap { JSON($0) })
    }
}

public protocol JSONElement {}
private protocol JSONValue {
    var jsonValue: JSON { get }
}

extension Int: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension Int8: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension Int16: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension Int32: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension Int64: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension UInt: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension UInt8: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension UInt16: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension UInt32: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension UInt64: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(Double(self))
    }
}

extension Double: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .number(self)
    }
}

extension String: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .string(self)
    }
}

extension Bool: JSONElement, JSONValue {
    var jsonValue: JSON {
        return .bool(self)
    }
}

extension Array: JSONElement where Element == JSONElement {
}

extension Array: JSONValue where Element == JSONValue {
    var jsonValue: JSON {
        return .array(self.map { $0.jsonValue })
    }
}

extension Dictionary: JSONElement where Key == String, Value == JSONElement {
}

extension Dictionary: JSONValue where Key == String, Value == JSONValue {
    var jsonValue: JSON {
        return .dictionary(self.mapValues { $0.jsonValue })
    }
}

private extension Bool {
    init(apiBool: Api.Bool) {
        switch apiBool {
            case .boolTrue:
                self.init(true)
            case .boolFalse:
                self.init(false)
        }
    }
    
    var apiBool: Api.Bool {
        if self {
            return .boolTrue
        } else {
            return .boolFalse
        }
    }
}

public extension JSON {
    private init?(apiJson: Api.JSONValue, root: Bool) {
        switch (apiJson, root) {
            case (.jsonNull, false):
                self = .null
            case let (.jsonNumber(value), false):
                self = .number(value)
            case let (.jsonString(value), false):
                self = .string(value)
            case let (.jsonBool(value), false):
                self = .bool(Bool(apiBool: value))
            case let (.jsonArray(value), _):
                self = .array(value.compactMap { JSON(apiJson: $0, root: false) })
            case let (.jsonObject(value), _):
                self = .dictionary(value.reduce([String: JSON]()) { dictionary, value in
                    var dictionary = dictionary
                    switch value {
                        case let .jsonObjectValue(key, value):
                            if let value = JSON(apiJson: value, root: false) {
                                dictionary[key] = value
                            }
                    }
                    return dictionary
                })
            default:
                return nil
        }
    }
    
    init?(apiJson: Api.JSONValue) {
        self.init(apiJson: apiJson, root: true)
    }
}

private func apiJson(_ json: JSON, root: Bool) -> Api.JSONValue? {
    switch (json, root) {
        case (.null, false):
            return .jsonNull
        case let (.number(value), false):
            return .jsonNumber(value: value)
        case let (.string(value), false):
            return .jsonString(value: value)
        case let (.bool(value), false):
            return .jsonBool(value: value.apiBool)
        case let (.array(value), _):
            return .jsonArray(value: value.compactMap { apiJson($0, root: false) })
        case let (.dictionary(value), _):
            return .jsonObject(value: value.reduce([Api.JSONObjectValue]()) { objectValues, keyAndValue in
                var objectValues = objectValues
                if let value = apiJson(keyAndValue.value, root: false) {
                    objectValues.append(.jsonObjectValue(key: keyAndValue.key, value: value))
                }
                return objectValues
            })
        default:
            return nil
    }
}

func apiJson(_ json: JSON) -> Api.JSONValue? {
    return apiJson(json, root: true)
}
