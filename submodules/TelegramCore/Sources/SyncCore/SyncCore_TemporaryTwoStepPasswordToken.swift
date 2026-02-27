import Foundation
import Postbox

public struct TemporaryTwoStepPasswordToken: Codable, Equatable {
    public let token: Data
    public let validUntilDate: Int32
    public let requiresBiometrics: Bool
    
    public init(token: Data, validUntilDate: Int32, requiresBiometrics: Bool) {
        self.token = token
        self.validUntilDate = validUntilDate
        self.requiresBiometrics = requiresBiometrics
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.token = try container.decode(Data.self, forKey: "t")
        self.validUntilDate = try container.decode(Int32.self, forKey: "d")
        self.requiresBiometrics = try container.decode(Int32.self, forKey: "b") != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.token, forKey: "t")
        try container.encode(self.validUntilDate, forKey: "d")
        try container.encode((self.requiresBiometrics ? 1 : 0) as Int32, forKey: "b")
    }
    
    public static func ==(lhs: TemporaryTwoStepPasswordToken, rhs: TemporaryTwoStepPasswordToken) -> Bool {
        return lhs.token == rhs.token && lhs.validUntilDate == rhs.validUntilDate && lhs.requiresBiometrics == rhs.requiresBiometrics
    }
}
