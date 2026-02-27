import Foundation
import MurMurHash32

public class AdaptedPostboxEncoder {
    public final class RawObjectData: Encodable {
        public let typeHash: Int32
        public let data: Data

        public init(typeHash: Int32, data: Data) {
            self.typeHash = typeHash
            self.data = data
        }

        public func encode(to encoder: Encoder) throws {
            preconditionFailure()
        }
    }
    
    public init() {
    }

    public func encode(_ value: Encodable) throws -> Data {
        let typeHash: Int32 = murMurHashString32("\(type(of: value))")

        let encoder = _AdaptedPostboxEncoder(typeHash: typeHash)
        try value.encode(to: encoder)
        return encoder.makeData(addHeader: false, isDictionary: false).0
    }
}

final class _AdaptedPostboxEncoder {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]

    let typeHash: Int32
    
    fileprivate var container: AdaptedPostboxEncodingContainer?

    init(typeHash: Int32) {
        self.typeHash = typeHash
    }

    func makeData(addHeader: Bool, isDictionary: Bool) -> (Data, ValueType) {
        if let container = self.container {
            return container.makeData(addHeader: addHeader, isDictionary: isDictionary)
        } else {
            let buffer = WriteBuffer()

            if addHeader {
                var typeHash: Int32 = self.typeHash
                buffer.write(&typeHash, offset: 0, length: 4)
            }

            let innerEncoder = PostboxEncoder()
            let data = innerEncoder.makeData()

            if addHeader {
                var length: Int32 = Int32(data.count)
                buffer.write(&length, offset: 0, length: 4)
            }

            buffer.write(data)

            return (buffer.makeData(), .Object)
        }
    }
}

extension _AdaptedPostboxEncoder: Encoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()

        let container = KeyedContainer<Key>(codingPath: self.codingPath, userInfo: self.userInfo, typeHash: self.typeHash)
        self.container = container
        
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        assertCanCreateContainer()

        let container = UnkeyedContainer(codingPath: self.codingPath, userInfo: self.userInfo)
        self.container = container

        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        preconditionFailure()
    }
}

protocol AdaptedPostboxEncodingContainer: AnyObject {
    func makeData(addHeader: Bool, isDictionary: Bool) -> (Data, ValueType)
}
