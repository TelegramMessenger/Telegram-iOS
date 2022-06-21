import Foundation
import UIKit
import TelegramCore
import TelegramUIPreferences

public func encodePresentationTheme(_ theme: PresentationTheme) -> String? {
    let encoding = PresentationThemeEncoding()
    if let _ = try? theme.encode(to: encoding) {
        return encoding.data.formatted
    } else {
        return nil
    }
}

private func renderNodes(string: inout String, nodes: [PresentationThemeEncoding.Node], level: Int = 0) {
    for node in nodes {
        if level > 1 {
            string.append(String(repeating: "  ", count: level - 1))
        }
        switch node.value {
        case let .string(value):
            if let key = node.key {
                string.append("\(key): \(value)\n")
            }
        case let .subnode(nodes):
            if let key = node.key {
                string.append("\(key):\n")
            }
            renderNodes(string: &string, nodes: nodes, level: level + 1)
        }
    }
}

fileprivate class PresentationThemeEncoding: Encoder {
    fileprivate enum NodeValue {
        case string(String)
        case subnode([Node])
    }
    
    fileprivate final class Node {
        var key: String?
        var value: NodeValue
        
        init(key: String? = nil, value: NodeValue) {
            self.key = key
            self.value = value
        }
    }
    
    fileprivate final class Data {
        private(set) var rootNode = Node(value: .subnode([]))
        
        func encode(key codingKey: [CodingKey], value: String) {
            var currentNode: Node = self.rootNode
            for i in 0 ..< codingKey.count {
                let key = codingKey[i].stringValue
                var found = false
                switch currentNode.value {
                    case var .subnode(nodes):
                        for node in nodes {
                            if node.key == key {
                                currentNode = node
                                found = true
                            }
                        }
                        if !found {
                            let newNode: Node
                            if i == codingKey.count - 1 {
                                newNode = Node(key: key, value: .string(value))
                            } else {
                                newNode = Node(key: key, value: .subnode([]))
                            }
                            nodes.append(newNode)
                            currentNode.value = .subnode(nodes)
                            currentNode = newNode
                        }
                    case .string:
                        break
                }
            }
        }
        
        var formatted: String {
            var result = ""
            renderNodes(string: &result, nodes: [self.rootNode])
            return result
        }
    }
    
    fileprivate var data: Data
    var codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey : Any] = [:]
    
    init(to encodedData: Data = Data()) {
        self.data = encodedData
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        var container = StringsKeyedEncoding<Key>(to: self.data)
        container.codingPath = self.codingPath
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: self.data)
        container.codingPath = self.codingPath
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        var container = StringsSingleValueEncoding(to: self.data)
        container.codingPath = self.codingPath
        return container
    }
    
    private func dictionaryForNodes(_ nodes: [Node]) -> [String: Any] {
        var dictionary: [String: Any] = [:]
        for node in nodes {
            var value: Any?
            switch node.value {
                case let .string(string):
                    value = string
                case let .subnode(subnodes):
                    value = dictionaryForNodes(subnodes)
            }
            if let key = node.key {
                dictionary[key] = value
            }
        }
        return dictionary
    }
    
    func entry(for codingKey: [String]) -> Any? {
        var currentNode: Node = self.data.rootNode
        for component in codingKey {
            switch currentNode.value {
                case let .subnode(nodes):
                    inner: for node in nodes {
                        if node.key == component {
                            if component == codingKey.last {
                                if case let .string(string) = node.value {
                                    return string
                                } else if case let .subnode(nodes) = node.value {
                                    return dictionaryForNodes(nodes)
                                }
                            } else {
                                currentNode = node
                                break inner
                            }
                        }
                    }
                case let .string(string):
                    if component == codingKey.last {
                        return string
                    }
            }
        }
        return nil
    }
}

fileprivate struct StringsKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let data: PresentationThemeEncoding.Data
    var codingPath: [CodingKey] = []
    
    init(to data: PresentationThemeEncoding.Data) {
        self.data = data
    }
    
    mutating func encodeNil(forKey key: Key) throws {
    }
    
    mutating func encode(_ value: Bool, forKey key: Key) throws {
        self.data.encode(key: self.codingPath + [key], value: value.description)
    }
    
    mutating func encode(_ value: String, forKey key: Key) throws {
        self.data.encode(key: self.codingPath + [key], value: value)
    }
    
    mutating func encode(_ value: Int32, forKey key: Key) throws {
        self.data.encode(key: self.codingPath + [key], value: value.description)
    }
    
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let stringsEncoding = PresentationThemeEncoding(to: self.data)
        stringsEncoding.codingPath = self.codingPath + [key]
        try value.encode(to: stringsEncoding)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        var container = StringsKeyedEncoding<NestedKey>(to: self.data)
        container.codingPath = self.codingPath + [key]
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: data)
        container.codingPath = self.codingPath + [key]
        return container
    }
    
    mutating func superEncoder() -> Encoder {
        let superKey = Key(stringValue: "super")!
        return superEncoder(forKey: superKey)
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        let stringsEncoding = PresentationThemeEncoding(to: self.data)
        stringsEncoding.codingPath = self.codingPath + [key]
        return stringsEncoding
    }
}

fileprivate struct StringsUnkeyedEncoding: UnkeyedEncodingContainer {
    private let data: PresentationThemeEncoding.Data
    var codingPath: [CodingKey] = []
    private(set) var count: Int = 0
    
    init(to data: PresentationThemeEncoding.Data) {
        self.data = data
    }
    
    private mutating func nextIndexedKey() -> CodingKey {
        let nextCodingKey = IndexedCodingKey(intValue: count)!
        self.count += 1
        return nextCodingKey
    }
    
    private struct IndexedCodingKey: CodingKey {
        let intValue: Int?
        let stringValue: String
        
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = intValue.description
        }
        
        init?(stringValue: String) {
            return nil
        }
    }
    
    mutating func encodeNil() throws {
    }
    
    mutating func encode(_ value: Bool) throws {
        self.data.encode(key: self.codingPath + [self.nextIndexedKey()], value: value.description)
    }
    
    mutating func encode(_ value: String) throws {
        self.data.encode(key: self.codingPath + [self.nextIndexedKey()], value: value)
    }
    
    mutating func encode(_ value: Int32) throws {
        self.data.encode(key: self.codingPath + [self.nextIndexedKey()], value: value.description)
    }
    
    mutating func encode<T: Encodable>(_ value: T) throws {
        let stringsEncoding = PresentationThemeEncoding(to: self.data)
        stringsEncoding.codingPath = self.codingPath + [self.nextIndexedKey()]
        try value.encode(to: stringsEncoding)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        var container = StringsKeyedEncoding<NestedKey>(to: self.data)
        container.codingPath = self.codingPath + [self.nextIndexedKey()]
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: self.data)
        container.codingPath = self.codingPath + [self.nextIndexedKey()]
        return container
    }
    
    mutating func superEncoder() -> Encoder {
        let stringsEncoding = PresentationThemeEncoding(to: self.data)
        stringsEncoding.codingPath = self.codingPath
        return stringsEncoding
    }
}

fileprivate struct StringsSingleValueEncoding: SingleValueEncodingContainer {
    private let data: PresentationThemeEncoding.Data
    var codingPath: [CodingKey] = []
    
    init(to data: PresentationThemeEncoding.Data) {
        self.data = data
    }
    
    mutating func encodeNil() throws {
    }
    
    mutating func encode(_ value: Bool) throws {
        self.data.encode(key: self.codingPath, value: value.description)
    }
    
    mutating func encode(_ value: String) throws {
        self.data.encode(key: self.codingPath, value: value)
    }
    
    mutating func encode(_ value: Int32) throws {
        self.data.encode(key: self.codingPath, value: value.description)
    }
    
    mutating func encode<T: Encodable>(_ value: T) throws {
        let stringsEncoding = PresentationThemeEncoding(to: self.data)
        stringsEncoding.codingPath = self.codingPath
        try value.encode(to: stringsEncoding)
    }
}


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

private class PresentationThemeDecodingLevel {
    let data: NSMutableDictionary
    let index: Int
    let previous: PresentationThemeDecodingLevel?
    
    init(data: NSMutableDictionary, index: Int, previous: PresentationThemeDecodingLevel?) {
        self.data = data
        self.index = index
        self.previous = previous
    }
}

public func makePresentationTheme(data: Data, themeReference: PresentationThemeReference? = nil, resolvedWallpaper: TelegramWallpaper? = nil) -> PresentationTheme? {
    guard let string = String(data: data, encoding: .utf8) else {
        return nil
    }
    let lines = string.split { $0.isNewline }
    
    let topLevel = PresentationThemeDecodingLevel(data: NSMutableDictionary(), index: 0, previous: nil)
    var currentLevel = topLevel
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        if trimmedLine.hasPrefix("#") || trimmedLine.hasPrefix("//") {
            continue
        }
        if let rangeOfColon = line.firstIndex(of: ":") {
            let key = line.prefix(upTo: rangeOfColon)
            
            var lineLevel = 0
            inner: for c in key {
                if c == " " {
                    lineLevel += 1
                } else {
                    break inner
                }
            }
            guard lineLevel % 2 == 0 else {
                return nil
            }
            lineLevel = lineLevel / 2
            guard lineLevel <= currentLevel.index else {
                return nil
            }
            
            while lineLevel < currentLevel.index, let previous = currentLevel.previous {
                currentLevel = previous
            }
            
            let value: String?
            if let valueStartIndex = line.index(rangeOfColon, offsetBy: 1, limitedBy: line.endIndex) {
                let substring = line.suffix(from: valueStartIndex).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !substring.isEmpty {
                    value = substring
                } else {
                    value = nil
                }
            } else {
                value = nil
            }
            
            let trimmedKey = key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let value = value {
                currentLevel.data[trimmedKey] = value
            } else {
                let newLevel = PresentationThemeDecodingLevel(data: NSMutableDictionary(), index: currentLevel.index + 1, previous: currentLevel)
                currentLevel.data[trimmedKey] = newLevel.data
                currentLevel = newLevel
            }
        }
    }
    
    let decoder = PresentationThemeDecoding(referencing: topLevel.data)
    decoder.reference = themeReference
    decoder.resolvedWallpaper = resolvedWallpaper
    if let value = try? decoder.unbox(topLevel.data, as: PresentationTheme.self) {
        return value
    }
    return nil
}

class PresentationThemeDecoding: Decoder {
    fileprivate var storage: PresentationThemeDecodingStorage

    fileprivate(set) public var codingPath: [CodingKey]

    public var userInfo: [CodingUserInfoKey : Any] {
        return [:]
    }
    
    var reference: PresentationThemeReference?
    var referenceTheme: PresentationTheme?
    var serviceBackgroundColor: UIColor?
    var resolvedWallpaper: TelegramWallpaper?
    var fallbackKeys: [String: String] = [:]

    private var _referenceCoding: PresentationThemeEncoding?
    fileprivate var referenceCoding: PresentationThemeEncoding? {
        if let referenceCoding = self._referenceCoding {
            return referenceCoding
        }
        
        let encoding = PresentationThemeEncoding()
        if let theme = self.referenceTheme, let _ = try? theme.encode(to: encoding) {
            self._referenceCoding = encoding
            return encoding
        } else {
            return nil
        }
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
            if let topContainer = self.storage.topContainer as? [String : Any] {
                let sortedKeys = topContainer.keys.sorted(by: { lhs, rhs in
                    if let lhsValue = Int(lhs), let rhsValue = Int(rhs), lhsValue < rhsValue {
                        return true
                    } else {
                        return false
                    }
                })
                var array: [Any] = []
                for key in sortedKeys {
                    if let value = topContainer[key] {
                        array.append(value)
                    }
                }
                return PresentationThemeUnkeyedDecodingContainer(referencing: self, wrapping: array)
            }
            
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

fileprivate struct PresentationThemeKeyedDecodingContainer<K : CodingKey>: KeyedDecodingContainerProtocol {
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
        
    private func storageEntry(forKey key: [String]) -> Any? {
        if let container = self.decoder.storage.containers.first as? [String: Any] {
            func entry(container: [String: Any], forKey key: [String]) -> Any? {
                if let keyComponent = key.first, let value = container[keyComponent] {
                    if key.count == 1 {
                        return value
                    } else if let subContainer = value as? [String: Any] {
                        return entry(container: subContainer, forKey: Array(key.suffix(from: 1)))
                    }
                }
                return nil
            }
            return entry(container: container, forKey: key)
        } else {
            return nil
        }
    }
    
    private func containerEntry(forKey key: Key) -> Any? {
        var containerEntry: Any? = self.container[key.stringValue]
        if containerEntry == nil {
            let initialKey = self.codingPath.map { $0.stringValue } + [key.stringValue]
            let initialKeyString = initialKey.joined(separator: ".")
            if let fallbackKeyString = self.decoder.fallbackKeys[initialKeyString] {
                let fallbackKey = fallbackKeyString.components(separatedBy: ".")
                containerEntry = self.storageEntry(forKey: fallbackKey)
            }
            if containerEntry == nil {
                containerEntry = self.decoder.referenceCoding?.entry(for: initialKey)
            }
        }
        return containerEntry
    }
    
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = self.containerEntry(forKey: key) else {
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
        guard let entry = self.containerEntry(forKey: key) else {
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
        guard let entry = self.containerEntry(forKey: key) else {
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
        guard let entry = self.containerEntry(forKey: key) else {
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

fileprivate struct PresentationThemeUnkeyedDecodingContainer: UnkeyedDecodingContainer {
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

extension PresentationThemeDecoding: SingleValueDecodingContainer {
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
        } else if let string = value as? String {
            if string.lowercased() == "true" {
                return true
            } else if string.lowercased() == "false" {
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
        if type == Decimal.self || type == NSDecimalNumber.self {
            if let value = value as? String {
                return Decimal(string: value)
            } else {
                return try self.unbox(value, as: Decimal.self)
            }
        } else if let stringKeyedDictType = type as? _YAMLStringDictionaryDecodableMarker.Type {
            return try self.unbox(value, as: stringKeyedDictType)
        } else {
            self.storage.push(container: value)
            defer { self.storage.popContainer() }
            return try type.init(from: self)
        }
    }
}

fileprivate struct YAMLKey: CodingKey {
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
