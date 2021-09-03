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
    
    public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeObjectForKey("data", decoder: { JSON(decoder: $0) }) as? JSON
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let data = self.data {
            encoder.encodeObject(data, forKey: "data")
        } else {
            encoder.encodeNil(forKey: "data")
        }
    }
}
