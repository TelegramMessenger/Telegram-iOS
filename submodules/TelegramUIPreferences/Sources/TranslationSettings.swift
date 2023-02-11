import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct TranslationSettings: Codable, Equatable {
    public var showTranslate: Bool
    public var translateChats: Bool
    public var ignoredLanguages: [String]?
    
    public static var defaultSettings: TranslationSettings {
        return TranslationSettings(showTranslate: false, translateChats: true, ignoredLanguages: nil)
    }
    
    init(showTranslate: Bool, translateChats: Bool, ignoredLanguages: [String]?) {
        self.showTranslate = showTranslate
        self.translateChats = translateChats
        self.ignoredLanguages = ignoredLanguages
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.showTranslate = try container.decodeIfPresent(Bool.self, forKey: "showTranslate") ?? false
        self.translateChats = try container.decodeIfPresent(Bool.self, forKey: "translateChats") ?? true
        self.ignoredLanguages = try container.decodeIfPresent([String].self, forKey: "ignoredLanguages")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.showTranslate, forKey: "showTranslate")
        try container.encode(self.translateChats, forKey: "translateChats")
        try container.encodeIfPresent(self.ignoredLanguages, forKey: "ignoredLanguages")
    }
    
    public static func ==(lhs: TranslationSettings, rhs: TranslationSettings) -> Bool {
        return lhs.showTranslate == rhs.showTranslate && lhs.translateChats == rhs.translateChats && lhs.ignoredLanguages == rhs.ignoredLanguages
    }
    
    public func withUpdatedShowTranslate(_ showTranslate: Bool) -> TranslationSettings {
        return TranslationSettings(showTranslate: showTranslate, translateChats: self.translateChats, ignoredLanguages: self.ignoredLanguages)
    }
    
    public func withUpdatedTranslateChats(_ translateChats: Bool) -> TranslationSettings {
        return TranslationSettings(showTranslate: self.showTranslate, translateChats: translateChats, ignoredLanguages: self.ignoredLanguages)
    }
    
    public func withUpdatedIgnoredLanguages(_ ignoredLanguages: [String]?) -> TranslationSettings {
        return TranslationSettings(showTranslate: self.showTranslate, translateChats: self.translateChats, ignoredLanguages: ignoredLanguages)
    }
}

public func updateTranslationSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (TranslationSettings) -> TranslationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.translationSettings, { entry in
            let currentSettings: TranslationSettings
            if let entry = entry?.get(TranslationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = TranslationSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
