import Foundation

extension _AdaptedPostboxDecoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
    

        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
}

extension _AdaptedPostboxDecoder.SingleValueContainer: SingleValueDecodingContainer {    
    func decodeNil() -> Bool {
        preconditionFailure()
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        preconditionFailure()
    }
    
    func decode(_ type: String.Type) throws -> String {
        preconditionFailure()
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        preconditionFailure()
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        preconditionFailure()
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        preconditionFailure()
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        preconditionFailure()
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        preconditionFailure()
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        preconditionFailure()
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        preconditionFailure()
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        preconditionFailure()
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        preconditionFailure()
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        preconditionFailure()
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        preconditionFailure()
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        preconditionFailure()
    }
  
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        preconditionFailure()
    }
}

extension _AdaptedPostboxDecoder.SingleValueContainer: AdaptedPostboxDecodingContainer {}
