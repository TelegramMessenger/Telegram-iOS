import Foundation

extension _AdaptedPostboxEncoder {
    final class UnkeyedContainer {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        var count: Int {
            preconditionFailure()
        }
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AdaptedPostboxEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        preconditionFailure()
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        preconditionFailure()
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        preconditionFailure()
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        preconditionFailure()
    }
    
    func superEncoder() -> Encoder {
        preconditionFailure()
    }
}

extension _AdaptedPostboxEncoder.UnkeyedContainer: AdaptedPostboxEncodingContainer {
    func makeData() -> Data {
        preconditionFailure()
    }
}
