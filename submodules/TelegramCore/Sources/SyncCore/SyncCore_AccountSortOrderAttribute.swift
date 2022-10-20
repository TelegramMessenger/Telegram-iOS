import Foundation
import Postbox

public final class AccountSortOrderAttribute: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case order
    }

    public let order: Int32
    
    public init(order: Int32) {
        self.order = order
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.order = (try? container.decode(Int32.self, forKey: .order)) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.order, forKey: .order)
    }

    public static func ==(lhs: AccountSortOrderAttribute, rhs: AccountSortOrderAttribute) -> Bool {
        if lhs.order != rhs.order {
            return false
        }
        return true
    }
}
