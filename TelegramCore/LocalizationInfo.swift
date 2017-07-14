import Foundation

public final class LocalizationInfo {
    public let languageCode: String
    public let title: String
    public let localizedTitle: String
    
    public init(languageCode: String, title: String, localizedTitle: String) {
        self.languageCode = languageCode
        self.title = title
        self.localizedTitle = localizedTitle
    }
}

public final class SuggestedLocalizationInfo {
    public let languageCode: String
    public let extractedEntries: [LocalizationEntry]
    
    public let availableLocalizations: [LocalizationInfo]
    
    init(languageCode: String, extractedEntries: [LocalizationEntry], availableLocalizations: [LocalizationInfo]) {
        self.languageCode = languageCode
        self.extractedEntries = extractedEntries
        self.availableLocalizations = availableLocalizations
    }
}
