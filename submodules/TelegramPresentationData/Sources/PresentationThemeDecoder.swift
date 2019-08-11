import Foundation

public enum PresentationThemeDecodingError: Error {
    case generic
    case dataCorrupted
    case valueNotFound
    case typeMismatch
    case keyNotFound
}

internal protocol _YAMLStringDictionaryDecodableMarker {
    static var elementType: Decodable.Type { get }
}

extension Dictionary : _YAMLStringDictionaryDecodableMarker where Key == String, Value: Decodable {
    static var elementType: Decodable.Type { return Value.self }
}

open class PresentationThemeDecoder {
    public init() {}

    open func decode<T : Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let topLevel: Any
        do {
            topLevel = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw PresentationThemeDecodingError.dataCorrupted
        }

        let decoder = PresentationThemeDecoding(referencing: topLevel)
        guard let value = try decoder.unbox(topLevel, as: type) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        return value
    }
}

fileprivate class PresentationThemeDecoding : Decoder {
    fileprivate var storage: PresentationThemeDecodingStorage

    fileprivate(set) public var codingPath: [CodingKey]

    public var userInfo: [CodingUserInfoKey : Any] {
        return [:]
    }

    fileprivate init(referencing container: Any, at codingPath: [CodingKey] = []) {
        self.storage = PresentationThemeDecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
    }

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard !(self.storage.topContainer is NSNull) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        guard let topContainer = self.storage.topContainer as? [String : Any] else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        let container = PresentationThemeKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !(self.storage.topContainer is NSNull) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        guard let topContainer = self.storage.topContainer as? [Any] else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        return PresentationThemeUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

fileprivate struct PresentationThemeDecodingStorage {
    private(set) fileprivate var containers: [Any] = []

    fileprivate init() {}

    fileprivate var count: Int {
        return self.containers.count
    }

    fileprivate var topContainer: Any {
        return self.containers.last!
    }

    fileprivate mutating func push(container: __owned Any) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() {
        self.containers.removeLast()
    }
}

fileprivate struct PresentationThemeKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K

    private let decoder: PresentationThemeDecoding
    private let container: [String : Any]
    private(set) public var codingPath: [CodingKey]

    fileprivate init(referencing decoder: PresentationThemeDecoding, wrapping container: [String : Any]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }

    public var allKeys: [Key] {
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }

    public func contains(_ key: Key) -> Bool {
        return self.container[key.stringValue] != nil
    }

    private func _errorDescription(of key: CodingKey) -> String {
        return "\(key) (\"\(key.stringValue)\")"
    }

    public func decodeNil(forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        return entry is NSNull
    }

    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        return value
    }

    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let entry = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try self.decoder.unbox(entry, as: Int32.self) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        return value
    }

    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let entry = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try self.decoder.unbox(entry, as: String.self) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        return value
    }

    public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let entry = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = try self.decoder.unbox(entry, as: type) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        return value
    }

    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        guard let dictionary = value as? [String : Any] else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        let container = PresentationThemeKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
        return KeyedDecodingContainer(container)
    }

    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        guard let value = self.container[key.stringValue] else {
            throw PresentationThemeDecodingError.keyNotFound
        }

        guard let array = value as? [Any] else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        return PresentationThemeUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
    }

    private func _superDecoder(forKey key: __owned CodingKey) throws -> Decoder {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }

        let value: Any = self.container[key.stringValue] ?? NSNull()
        return PresentationThemeDecoding(referencing: value, at: self.decoder.codingPath)
    }

    public func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: YAMLKey.super)
    }

    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}

fileprivate struct PresentationThemeUnkeyedDecodingContainer : UnkeyedDecodingContainer {
    private let decoder: PresentationThemeDecoding
    
    private let container: [Any]

    private(set) public var codingPath: [CodingKey]
    private(set) public var currentIndex: Int

    fileprivate init(referencing decoder: PresentationThemeDecoding, wrapping container: [Any]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
    }

    public var count: Int? {
        return self.container.count
    }

    public var isAtEnd: Bool {
        return self.currentIndex >= self.count!
    }

    public mutating func decodeNil() throws -> Bool {
        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        if self.container[self.currentIndex] is NSNull {
            self.currentIndex += 1
            return true
        } else {
            return false
        }
    }

    public mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Bool.self) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int32.self) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.currentIndex += 1
        return decoded
    }

    public mutating func decode(_ type: String.Type) throws -> String {
        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: String.self) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.currentIndex += 1
        return decoded
    }

    public mutating func decode<T : Decodable>(_ type: T.Type) throws -> T {
        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: type) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        self.currentIndex += 1
        return decoded
    }

    public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        guard let dictionary = value as? [String : Any] else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        self.currentIndex += 1
        let container = PresentationThemeKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
        return KeyedDecodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        guard let array = value as? [Any] else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        self.currentIndex += 1
        return PresentationThemeUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
    }

    public mutating func superDecoder() throws -> Decoder {
        self.decoder.codingPath.append(YAMLKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }

        guard !self.isAtEnd else {
            throw PresentationThemeDecodingError.valueNotFound
        }

        let value = self.container[self.currentIndex]
        self.currentIndex += 1
        return PresentationThemeDecoding(referencing: value, at: self.decoder.codingPath)
    }
}

extension PresentationThemeDecoding : SingleValueDecodingContainer {
    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw PresentationThemeDecodingError.valueNotFound
        }
    }

    public func decodeNil() -> Bool {
        return self.storage.topContainer is NSNull
    }

    public func decode(_ type: Bool.Type) throws -> Bool {
        try expectNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Bool.self)!
    }
    
    public func decode(_ type: Int32.Type) throws -> Int32 {
        try expectNonNull(Int32.self)
        return try self.unbox(self.storage.topContainer, as: Int32.self)!
    }

    public func decode(_ type: String.Type) throws -> String {
        try expectNonNull(String.self)
        return try self.unbox(self.storage.topContainer, as: String.self)!
    }

    public func decode<T : Decodable>(_ type: T.Type) throws -> T {
        try expectNonNull(type)
        return try self.unbox(self.storage.topContainer, as: type)!
    }
}

extension PresentationThemeDecoding {
    fileprivate func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
        guard !(value is NSNull) else { return nil }

        if let number = value as? NSNumber {
            if number === kCFBooleanTrue as NSNumber {
                return true
            } else if number === kCFBooleanFalse as NSNumber {
                return false
            }
        }

        throw PresentationThemeDecodingError.typeMismatch
    }

    fileprivate func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
        guard !(value is NSNull) else { return nil }

        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        let int32 = number.int32Value
        guard NSNumber(value: int32) == number else {
            throw PresentationThemeDecodingError.dataCorrupted
        }

        return int32
    }

    fileprivate func unbox(_ value: Any, as type: String.Type) throws -> String? {
        guard !(value is NSNull) else { return nil }

        guard let string = value as? String else {
            throw PresentationThemeDecodingError.typeMismatch
        }

        return string
    }

    fileprivate func unbox<T>(_ value: Any, as type: _YAMLStringDictionaryDecodableMarker.Type) throws -> T? {
        guard !(value is NSNull) else { return nil }

        var result = [String : Any]()
        guard let dict = value as? NSDictionary else {
            throw PresentationThemeDecodingError.typeMismatch
        }
        let elementType = type.elementType
        for (key, value) in dict {
            let key = key as! String
            self.codingPath.append(YAMLKey(stringValue: key, intValue: nil))
            defer { self.codingPath.removeLast() }

            result[key] = try unbox_(value, as: elementType)
        }

        return result as? T
    }

    fileprivate func unbox<T : Decodable>(_ value: Any, as type: T.Type) throws -> T? {
        return try unbox_(value, as: type) as? T
    }

    fileprivate func unbox_(_ value: Any, as type: Decodable.Type) throws -> Any? {
        if type == Date.self || type == NSDate.self {
            return try self.unbox(value, as: Date.self)
        } else if type == Data.self || type == NSData.self {
            return try self.unbox(value, as: Data.self)
        } else if type == URL.self || type == NSURL.self {
            guard let urlString = try self.unbox(value, as: String.self) else {
                return nil
            }

            guard let url = URL(string: urlString) else {
                throw PresentationThemeDecodingError.dataCorrupted
            }
            return url
        } else if type == Decimal.self || type == NSDecimalNumber.self {
            return try self.unbox(value, as: Decimal.self)
        } else if let stringKeyedDictType = type as? _YAMLStringDictionaryDecodableMarker.Type {
            return try self.unbox(value, as: stringKeyedDictType)
        } else {
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try type.init(from: self)
        }
    }
}

fileprivate struct YAMLKey : CodingKey {
    public var stringValue: String
    public var intValue: Int?
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }
    
    fileprivate init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
    
    fileprivate static let `super` = YAMLKey(stringValue: "super")!
}
