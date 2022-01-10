import Postbox

public struct LocalizationListState: Codable {
    public var availableOfficialLocalizations: [LocalizationInfo]
    public var availableSavedLocalizations: [LocalizationInfo]
    
    public static var defaultSettings: LocalizationListState {
        return LocalizationListState(availableOfficialLocalizations: [], availableSavedLocalizations: [])
    }
    
    public init(availableOfficialLocalizations: [LocalizationInfo], availableSavedLocalizations: [LocalizationInfo]) {
        self.availableOfficialLocalizations = availableOfficialLocalizations
        self.availableSavedLocalizations = availableSavedLocalizations
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.availableOfficialLocalizations = (try? container.decode([LocalizationInfo].self, forKey: "availableOfficialLocalizations")) ?? []
        self.availableSavedLocalizations = (try? container.decode([LocalizationInfo].self, forKey: "availableSavedLocalizations")) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.availableOfficialLocalizations, forKey: "availableOfficialLocalizations")
        try container.encode(self.availableSavedLocalizations, forKey: "availableSavedLocalizations")
    }
}
