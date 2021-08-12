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

private func decodingErrorBreakpoint() {
    #if DEBUG
    print("Decoding error. Install a breakpoint at decodingErrorBreakpoint to debug.")
    #endif
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
        if let (data, valueType) = self.decoder.decodeObjectDataForKey(key.stringValue) {
            if type == AdaptedPostboxDecoder.RawObjectData.self {
                if case let .Object(typeHash) = valueType {
                    return AdaptedPostboxDecoder.RawObjectData(data: data, typeHash: typeHash) as! T
                } else {
                    decodingErrorBreakpoint()
                    throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
                }
            }
            if let mappedType = AdaptedPostboxDecoder.ContentType(valueType: valueType) {
                return try AdaptedPostboxDecoder().decode(T.self, from: data, contentType: mappedType)
            } else {
                switch valueType {
                case .Bytes:
                    guard let resultData = PostboxDecoder.parseDataRaw(data: data) else {
                        decodingErrorBreakpoint()
                        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
                    }
                    if let resultData = resultData as? T {
                        return resultData
                    } else {
                        decodingErrorBreakpoint()
                        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
                    }
                default:
                    decodingErrorBreakpoint()
                    throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
                }
            }
        } else {
            decodingErrorBreakpoint()
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        if let value = self.decoder.decodeOptionalInt32ForKey(key.stringValue) {
            return value
        } else {
            decodingErrorBreakpoint()
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        if let value = self.decoder.decodeOptionalInt64ForKey(key.stringValue) {
            return value
        } else {
            decodingErrorBreakpoint()
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        if let value = self.decoder.decodeOptionalBoolForKey(key.stringValue) {
            return value
        } else {
            decodingErrorBreakpoint()
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        if let value = self.decoder.decodeOptionalStringForKey(key.stringValue) {
            return value
        } else {
            decodingErrorBreakpoint()
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: ""))
        }
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        if let value = self.decoder.decodeOptionalDoubleForKey(key.stringValue) {
            return value
        } else {
            decodingErrorBreakpoint()
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
