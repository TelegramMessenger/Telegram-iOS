import Foundation
import MurMurHash32

public class AdaptedPostboxEncoder {
    public init() {
    }

    public func encode(_ value: Encodable) throws -> Data {
        let typeHash: Int32 = murMurHashString32("\(type(of: value))")

        let encoder = _AdaptedPostboxEncoder(typeHash: typeHash)
        try value.encode(to: encoder)
        return encoder.makeData(addHeader: false).0
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

    func makeData(addHeader: Bool) -> (Data, ValueType) {
        return self.container!.makeData(addHeader: addHeader)
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
    func makeData(addHeader: Bool) -> (Data, ValueType)
}
