import Foundation

extension _AdaptedPostboxEncoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AdaptedPostboxEncoder.SingleValueContainer: SingleValueEncodingContainer {
    func encodeNil() throws {
        preconditionFailure()
    }
    
    func encode(_ value: Bool) throws {
        preconditionFailure()
    }
    
    func encode(_ value: String) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Double) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Float) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Int) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Int8) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Int16) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Int32) throws {
        preconditionFailure()
    }
    
    func encode(_ value: Int64) throws {
        preconditionFailure()
    }
    
    func encode(_ value: UInt) throws {
        preconditionFailure()
    }
    
    func encode(_ value: UInt8) throws {
        preconditionFailure()
    }
    
    func encode(_ value: UInt16) throws {
        preconditionFailure()
    }
    
    func encode(_ value: UInt32) throws {
        preconditionFailure()
    }
    
    func encode(_ value: UInt64) throws {
        preconditionFailure()
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        preconditionFailure()
    }
}

extension _AdaptedPostboxEncoder.SingleValueContainer: AdaptedPostboxEncodingContainer {
    func makeData(addHeader: Bool, isDictionary: Bool) -> (Data, ValueType) {
        preconditionFailure()
    }
}
