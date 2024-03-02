import Foundation
import Postbox

public enum AccountEnvironment: Int32 {
    case production = 0
    case test = 1
}

public final class AccountEnvironmentAttribute: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case environment
        case isSupportAccount
    }

    public let environment: AccountEnvironment
    public let isSupportAccount: Bool
    
    public init(environment: AccountEnvironment, isSupportAccount: Bool) {
        self.environment = environment
        self.isSupportAccount = isSupportAccount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let environmentValue: Int32 = (try? container.decode(Int32.self, forKey: .environment)) ?? 0

        self.environment = AccountEnvironment(rawValue: environmentValue) ?? .production
        self.isSupportAccount = (try? container.decode(Bool.self, forKey: .isSupportAccount)) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.environment.rawValue, forKey: .environment)
        try container.encode(self.isSupportAccount, forKey: .isSupportAccount)
    }

    public static func ==(lhs: AccountEnvironmentAttribute, rhs: AccountEnvironmentAttribute) -> Bool {
        if lhs.environment != rhs.environment {
            return false
        }
        if lhs.isSupportAccount != rhs.isSupportAccount {
            return false
        }
        return true
    }
}
