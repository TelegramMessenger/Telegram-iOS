import Foundation
import Postbox

public enum AccountEnvironment: Int32 {
    case production = 0
    case test = 1
}

public final class AccountEnvironmentAttribute: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case environment
    }

    public let environment: AccountEnvironment
    
    public init(environment: AccountEnvironment) {
        self.environment = environment
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let environmentValue: Int32 = (try? container.decode(Int32.self, forKey: .environment)) ?? 0

        self.environment = AccountEnvironment(rawValue: environmentValue) ?? .production
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.environment.rawValue, forKey: .environment)
    }

    public static func ==(lhs: AccountEnvironmentAttribute, rhs: AccountEnvironmentAttribute) -> Bool {
        if lhs.environment != rhs.environment {
            return false
        }
        return true
    }
}
