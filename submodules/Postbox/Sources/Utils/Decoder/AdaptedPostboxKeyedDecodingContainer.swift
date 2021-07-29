import Foundation

extension _AdaptedPostboxDecoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        let decoder: PostboxDecoder

        init(data: Data, codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.decoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        }
    }
}

extension _AdaptedPostboxDecoder.KeyedContainer: KeyedDecodingContainerProtocol {
    var allKeys: [Key] {
        preconditionFailure()
    }
    
    func contains(_ key: Key) -> Bool {
        return self.decoder.containsKey(key.stringValue)
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        return self.decoder.decodeNilForKey(key.stringValue)
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        preconditionFailure()
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        if let value = self.decoder.decodeOptionalInt32ForKey(key.stringValue) {
            return value
        } else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int32 {
        if let value = self.decoder.decodeOptionalInt64ForKey(key.stringValue) {
            return value
        } else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Int32 {
        if let value = self.decoder.decodeOptionalBoolForKey(key.stringValue) {
            return value
        } else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> Int32 {
        if let value = self.decoder.decodeOptionalStringForKey(key.stringValue) {
            return value
        } else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }
 
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        preconditionFailure()
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure()
    }
    
    func superDecoder() throws -> Decoder {
        preconditionFailure()
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        preconditionFailure()
    }
}

extension _AdaptedPostboxDecoder.KeyedContainer: AdaptedPostboxDecodingContainer {}
