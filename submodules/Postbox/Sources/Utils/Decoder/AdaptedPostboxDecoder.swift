import Foundation

final public class AdaptedPostboxDecoder {
    enum ContentType {
        case object
        case int32Array
        case int64Array
        case objectArray
        case stringArray
        case dataArray
    }

    public final class RawObjectData: Codable {
        public let data: Data
        public let typeHash: Int32

        public init(data: Data, typeHash: Int32) {
            self.data = data
            self.typeHash = typeHash
        }
    }

    public init() {
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        return try self.decode(type, from: data, contentType: .object)
    }

    func decode<T>(_ type: T.Type, from data: Data, contentType: ContentType) throws -> T where T : Decodable {
        let decoder = _AdaptedPostboxDecoder(data: data, contentType: contentType)
        return try T(from: decoder)
    }
}

extension AdaptedPostboxDecoder.ContentType {
    init?(valueType: ObjectDataValueType) {
        switch valueType {
        case .Int32:
            return nil
        case .Int64:
            return nil
        case .Bool:
            return nil
        case .Double:
            return nil
        case .String:
            return nil
        case .Object:
            self = .object
        case .Int32Array:
            self = .int32Array
        case .Int64Array:
            self = .int64Array
        case .ObjectArray:
            self = .objectArray
        case .ObjectDictionary:
            return nil
        case .Bytes:
            return nil
        case .Nil:
            return nil
        case .StringArray:
            self = .stringArray
        case .BytesArray:
            self = .dataArray
        }
    }
}

final class _AdaptedPostboxDecoder {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    var container: AdaptedPostboxDecodingContainer?

    fileprivate let data: Data
    fileprivate let contentType: AdaptedPostboxDecoder.ContentType
    
    init(data: Data, contentType: AdaptedPostboxDecoder.ContentType) {
        self.data = data
        self.contentType = contentType
    }
}

extension _AdaptedPostboxDecoder: Decoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }
        
    func container<Key>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()

        let container = KeyedContainer<Key>(data: self.data, codingPath: self.codingPath, userInfo: self.userInfo)
        self.container = container

        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedDecodingContainer {
        assertCanCreateContainer()

        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: self.data))

        var content: UnkeyedContainer.Content?
        switch self.contentType {
        case .object:
            preconditionFailure()
        case .int32Array:
            content = .int32Array(decoder.decodeInt32ArrayRaw())
        case .int64Array:
            content = .int64Array(decoder.decodeInt64ArrayRaw())
        case .objectArray:
            content = .objectArray(decoder.decodeObjectDataArrayRaw())
        case .stringArray:
            content = .stringArray(decoder.decodeStringArrayRaw())
        case .dataArray:
            content = .dataArray(decoder.decodeBytesArrayRaw().map { $0.makeData() })
        }

        if let content = content {
            let container = UnkeyedContainer(data: self.data, codingPath: self.codingPath, userInfo: self.userInfo, content: content)
            self.container = container

            return container
        } else {
            preconditionFailure()
        }
    }
    
    func singleValueContainer() -> SingleValueDecodingContainer {
        preconditionFailure()
    }
}

protocol AdaptedPostboxDecodingContainer: AnyObject {
}
