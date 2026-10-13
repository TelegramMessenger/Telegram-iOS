import Postbox

public struct NetworkEngineSettings: Codable, Equatable {
    public var engine: NetworkEngineKind
    
    public static var defaultSettings: NetworkEngineSettings {
        #if os(macOS)
        return NetworkEngineSettings(engine: .rust)
        #else
        return NetworkEngineSettings(engine: .mtProtoKit)
        #endif
    }
    
    public init(engine: NetworkEngineKind) {
        self.engine = engine
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let rawValue = try? container.decode(String.self, forKey: "engine_v2")
        self.engine = rawValue.flatMap(NetworkEngineKind.init(rawValue:)) ?? NetworkEngineSettings.defaultSettings.engine
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.engine.rawValue, forKey: "engine_v2")
    }
}
