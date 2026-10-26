import Foundation

public final class AdaptedPostboxDecoder {
    enum ContentType {
        case object
        case int32Array
        case int64Array
        case objectArray
        case stringArray
        case dataArray
        case objectDict
    }

    public final class RawObjectData: Decodable {
        public let data: Data
        public let typeHash: Int32

        public init(data: Data, typeHash: Int32) {
            self.data = data
            self.typeHash = typeHash
        }

        public init(from decoder: Decoder) throws {
            preconditionFailure()
        }
    }

    public init() {
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        return try self.decode(type, from: data, contentType: .object)
    }

    func decode<T>(_ type: T.Type, from data: Data, contentType: ContentType) throws -> T where T : Decodable {
        if type == AdaptedPostboxDecoder.RawObjectData.self {
            if case .object = contentType {
                return AdaptedPostboxDecoder.RawObjectData(data: data, typeHash: 0) as! T
            } else {
                preconditionFailure()
            }
        }
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
            self = .objectDict
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

        // Every raw reader returns nil for a malformed value. `unkeyedContainer()`
        // cannot throw, so the container is created empty with `isCorrupted` set and
        // reports the corruption from its first `decode` instead.
        var content: UnkeyedContainer.Content?
        var isCorrupted = false
        switch self.contentType {
        case .object:
            preconditionFailure()
        case .int32Array:
            if let array = decoder.decodeInt32ArrayRaw() {
                content = .int32Array(array)
            } else {
                content = .int32Array([])
                isCorrupted = true
            }
        case .int64Array:
            if let array = decoder.decodeInt64ArrayRaw() {
                content = .int64Array(array)
            } else {
                content = .int64Array([])
                isCorrupted = true
            }
        case .objectArray:
            if let array = decoder.decodeObjectDataArrayRaw() {
                content = .objectArray(array)
            } else {
                content = .objectArray([])
                isCorrupted = true
            }
        case .stringArray:
            if let array = decoder.decodeStringArrayRaw() {
                content = .stringArray(array)
            } else {
                content = .stringArray([])
                isCorrupted = true
            }
        case .dataArray:
            if let array = decoder.decodeBytesArrayRaw() {
                content = .dataArray(array.map { $0.makeData() })
            } else {
                content = .dataArray([])
                isCorrupted = true
            }
        case .objectDict:
            if let dict = decoder.decodeObjectDataDictRaw() {
                content = .objectDict(dict)
            } else {
                content = .objectDict([])
                isCorrupted = true
            }
        }

        if let content = content {
            let container = UnkeyedContainer(data: self.data, codingPath: self.codingPath, userInfo: self.userInfo, content: content, isCorrupted: isCorrupted)
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
