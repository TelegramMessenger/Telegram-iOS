import Foundation
import Postbox

public final class EngineEncoder {
    public static func encode(_ value: Encodable) throws -> Data {
        return try AdaptedPostboxEncoder().encode(value)
    }
}

public final class EngineDecoder {
    public static func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        return try AdaptedPostboxDecoder().decode(type, from: data)
    }
}
