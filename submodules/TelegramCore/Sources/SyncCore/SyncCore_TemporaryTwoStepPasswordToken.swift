import Foundation
import Postbox

public struct TemporaryTwoStepPasswordToken: PostboxCoding, Equatable {
    public let token: Data
    public let validUntilDate: Int32
    public let requiresBiometrics: Bool
    
    public init(token: Data, validUntilDate: Int32, requiresBiometrics: Bool) {
        self.token = token
        self.validUntilDate = validUntilDate
        self.requiresBiometrics = requiresBiometrics
    }
    
    public init(decoder: PostboxDecoder) {
        self.token = decoder.decodeBytesForKey("t")!.makeData()
        self.validUntilDate = decoder.decodeInt32ForKey("d", orElse: 0)
        self.requiresBiometrics = decoder.decodeInt32ForKey("b", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBytes(MemoryBuffer(data: self.token), forKey: "t")
        encoder.encodeInt32(self.validUntilDate, forKey: "d")
        encoder.encodeInt32(self.requiresBiometrics ? 1 : 0, forKey: "b")
    }
    
    public static func ==(lhs: TemporaryTwoStepPasswordToken, rhs: TemporaryTwoStepPasswordToken) -> Bool {
        return lhs.token == rhs.token && lhs.validUntilDate == rhs.validUntilDate && lhs.requiresBiometrics == rhs.requiresBiometrics
    }
}
