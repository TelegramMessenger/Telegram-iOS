import Foundation

public final class PresentationThemeEncoder {
    public init() {
    }
    
    public func encode<T: Encodable>(_ value: T) throws -> String {
        let encoding = PresentationThemeEncoding()
        try value.encode(to: encoding)
        return encoding.data.formatted
    }
    
    private func stringsFormat(from strings: [(String, String)]) -> String {
        let strings = strings.map { "\($0.0): \($0.1)" }
        return strings.joined(separator: "\n")
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
        var container = StringsKeyedEncoding<Key>(to: data)
        container.codingPath = self.codingPath
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        var container = StringsUnkeyedEncoding(to: data)
        container.codingPath = self.codingPath
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        var container = StringsSingleValueEncoding(to: data)
        container.codingPath = self.codingPath
        return container
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
        self.data.encode(key: codingPath + [key], value: value.description)
    }
    
    mutating func encode(_ value: String, forKey key: Key) throws {
        self.data.encode(key: codingPath + [key], value: value)
    }
    
    mutating func encode(_ value: Int32, forKey key: Key) throws {
        self.data.encode(key: codingPath + [key], value: value.description)
    }
        
    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let stringsEncoding = PresentationThemeEncoding(to: self.data)
        stringsEncoding.codingPath = self.codingPath + [key]
        try value.encode(to: stringsEncoding)
    }
    
    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
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
