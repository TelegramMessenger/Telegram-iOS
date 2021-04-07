import Postbox

public struct AppChangelogState: PreferencesEntry, Equatable {
    public var checkedVersion: String
    public var previousVersion: String
    
    public static var `default` = AppChangelogState(checkedVersion: "", previousVersion: "5.0.8")
    
    public init(checkedVersion: String, previousVersion: String) {
        self.checkedVersion = checkedVersion
        self.previousVersion = previousVersion
    }
    
    public init(decoder: PostboxDecoder) {
        self.checkedVersion = decoder.decodeStringForKey("checkedVersion", orElse: "")
        self.previousVersion = decoder.decodeStringForKey("previousVersion", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.checkedVersion, forKey: "checkedVersion")
        encoder.encodeString(self.previousVersion, forKey: "previousVersion")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? AppChangelogState else {
            return false
        }
        
        return self == to
    }
}
