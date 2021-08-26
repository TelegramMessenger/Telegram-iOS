import Foundation
import MurMurHash32

extension _AdaptedPostboxEncoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        let typeHash: Int32

        let encoder: PostboxEncoder
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any], typeHash: Int32) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.typeHash = typeHash

            self.encoder = PostboxEncoder()
        }

        func makeData(addHeader: Bool) -> (Data, ValueType) {
            let buffer = WriteBuffer()

            if addHeader {
                var typeHash: Int32 = self.typeHash
                buffer.write(&typeHash, offset: 0, length: 4)
            }

            let data = self.encoder.makeData()

            if addHeader {
                var length: Int32 = Int32(data.count)
                buffer.write(&length, offset: 0, length: 4)
            }

            buffer.write(data)

            return (buffer.makeData(), .Object)
        }
    }
}

extension _AdaptedPostboxEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        if let value = value as? Data {
            self.encoder.encodeData(value, forKey: key.stringValue)
        } else {
            let typeHash: Int32 = murMurHashString32("\(type(of: value))")
            let innerEncoder = _AdaptedPostboxEncoder(typeHash: typeHash)
            try! value.encode(to: innerEncoder)

            let (data, valueType) = innerEncoder.makeData(addHeader: true)
            self.encoder.encodeInnerObjectData(data, valueType: valueType, forKey: key.stringValue)
        }
    }

    func encodeNil(forKey key: Key) throws {
        self.encoder.encodeNil(forKey: key.stringValue)
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        self.encoder.encodeInt32(value, forKey: key.stringValue)
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        self.encoder.encodeInt64(value, forKey: key.stringValue)
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        self.encoder.encodeBool(value, forKey: key.stringValue)
    }

    func encode(_ value: Double, forKey key: Key) throws {
        self.encoder.encodeDouble(value, forKey: key.stringValue)
    }

    func encode(_ value: String, forKey key: Key) throws {
        self.encoder.encodeString(value, forKey: key.stringValue)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        preconditionFailure()
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure()
    }
    
    func superEncoder() -> Encoder {
        preconditionFailure()
    }
    
    func superEncoder(forKey key: Key) -> Encoder {
        preconditionFailure()
    }
}

extension _AdaptedPostboxEncoder.KeyedContainer: AdaptedPostboxEncodingContainer {}
