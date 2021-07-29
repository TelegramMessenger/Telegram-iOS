import Foundation

extension _AdaptedPostboxEncoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]

        let encoder: PostboxEncoder
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo

            self.encoder = PostboxEncoder()
        }

        func makeData() -> Data {
            return self.encoder.makeData()
        }
    }
}

extension _AdaptedPostboxEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        let innerEncoder = _AdaptedPostboxEncoder()
        try! value.encode(to: innerEncoder)

        self.encoder.encodeInnerObjectData(innerEncoder.data, forKey: key.stringValue)
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
