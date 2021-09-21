import Foundation
import Postbox

public struct AppConfiguration: Codable, Equatable {
    public var data: JSON?
    
    public static var defaultValue: AppConfiguration {
        return AppConfiguration(data: nil)
    }
    
    init(data: JSON?) {
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.data = try container.decodeIfPresent(JSON.self, forKey: "data")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.data, forKey: "data")
    }
}
