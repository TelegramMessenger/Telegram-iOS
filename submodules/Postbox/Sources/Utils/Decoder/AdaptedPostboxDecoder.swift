import Foundation

final public class AdaptedPostboxDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        let decoder = _AdaptedPostboxDecoder(data: data)
        return try T(from: decoder)
    }
}

final class _AdaptedPostboxDecoder {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    var container: AdaptedPostboxDecodingContainer?
    fileprivate var data: Data
    
    init(data: Data) {
        self.data = data
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
        preconditionFailure()
    }
    
    func singleValueContainer() -> SingleValueDecodingContainer {
        preconditionFailure()
    }
}

protocol AdaptedPostboxDecodingContainer: AnyObject {
}
