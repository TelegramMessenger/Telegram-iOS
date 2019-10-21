import Postbox

public struct LocalizationListState: PreferencesEntry, Equatable {
    public var availableOfficialLocalizations: [LocalizationInfo]
    public var availableSavedLocalizations: [LocalizationInfo]
    
    public static var defaultSettings: LocalizationListState {
        return LocalizationListState(availableOfficialLocalizations: [], availableSavedLocalizations: [])
    }
    
    public init(availableOfficialLocalizations: [LocalizationInfo], availableSavedLocalizations: [LocalizationInfo]) {
        self.availableOfficialLocalizations = availableOfficialLocalizations
        self.availableSavedLocalizations = availableSavedLocalizations
    }
    
    public init(decoder: PostboxDecoder) {
        self.availableOfficialLocalizations = decoder.decodeObjectArrayWithDecoderForKey("availableOfficialLocalizations")
        self.availableSavedLocalizations = decoder.decodeObjectArrayWithDecoderForKey("availableSavedLocalizations")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.availableOfficialLocalizations, forKey: "availableOfficialLocalizations")
        encoder.encodeObjectArray(self.availableSavedLocalizations, forKey: "availableSavedLocalizations")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? LocalizationListState else {
            return false
        }
        
        return self == to
    }
}
