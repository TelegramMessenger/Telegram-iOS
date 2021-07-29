import Foundation

public class AdaptedPostboxEncoder {
    func encode(_ value: Encodable) throws -> Data {
        let encoder = _AdaptedPostboxEncoder()
        try value.encode(to: encoder)
        return encoder.data
    }
}

final class _AdaptedPostboxEncoder {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    fileprivate var container: AdaptedPostboxEncodingContainer?

    var data: Data {
        return self.container!.makeData()
    }
}

extension _AdaptedPostboxEncoder: Encoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()
        
        let container = KeyedContainer<Key>(codingPath: self.codingPath, userInfo: self.userInfo)
        self.container = container
        
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        preconditionFailure()
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        preconditionFailure()
    }
}

protocol AdaptedPostboxEncodingContainer: AnyObject {
    func makeData() -> Data
}
