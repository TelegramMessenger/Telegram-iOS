import Foundation
import Postbox

public enum AccountEnvironment: Int32 {
    case production = 0
    case test = 1
}

public final class AccountEnvironmentAttribute: AccountRecordAttribute {
    public let environment: AccountEnvironment
    
    public init(environment: AccountEnvironment) {
        self.environment = environment
    }
    
    public init(decoder: PostboxDecoder) {
        self.environment = AccountEnvironment(rawValue: decoder.decodeInt32ForKey("environment", orElse: 0)) ?? .production
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.environment.rawValue, forKey: "environment")
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        guard let to = to as? AccountEnvironmentAttribute else {
            return false
        }
        if self.environment != to.environment {
            return false
        }
        return true
    }
}
