import Postbox

public struct AppChangelogState: Codable {
    public var checkedVersion: String
    public var previousVersion: String
    
    public static var `default` = AppChangelogState(checkedVersion: "", previousVersion: "5.0.8")
    
    public init(checkedVersion: String, previousVersion: String) {
        self.checkedVersion = checkedVersion
        self.previousVersion = previousVersion
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.checkedVersion = (try? container.decode(String.self, forKey: "checkedVersion")) ?? ""
        self.previousVersion = (try? container.decode(String.self, forKey: "previousVersion")) ?? ""
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.checkedVersion, forKey: "checkedVersion")
        try container.encode(self.previousVersion, forKey: "previousVersion")
    }
}
