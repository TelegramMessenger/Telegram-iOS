import Foundation
import Postbox
import TelegramApi

import SyncCore

extension LocalizationInfo {
    init(apiLanguage: Api.LangPackLanguage) {
        switch apiLanguage {
            case let .langPackLanguage(language):
                self.init(languageCode: language.langCode, baseLanguageCode: language.baseLangCode, customPluralizationCode: language.pluralCode, title: language.name, localizedTitle: language.nativeName, isOfficial: (language.flags & (1 << 0)) != 0, totalStringCount: language.stringsCount, translatedStringCount: language.translatedCount, platformUrl: language.translationsUrl)
        }
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

// MARK: Nicegram Chinese locales
public let niceLocalizations: [LocalizationInfo] = [
    LocalizationInfo(languageCode: "zhcncc", baseLanguageCode: "zh-hans-raw", customPluralizationCode: "zh", title: "Chinese (Simplified) @congcong", localizedTitle: "简体中文 (聪聪)", isOfficial: false, totalStringCount: 3178, translatedStringCount: 3173, platformUrl: "https://translations.telegram.org/zhcncc/"),
    LocalizationInfo(languageCode: "taiwan", baseLanguageCode: "zh-hant-raw", customPluralizationCode: "zh", title: "Chinese (zh-Hant-TW)", localizedTitle: "正體中文", isOfficial: false, totalStringCount: 3178, translatedStringCount: 3173, platformUrl: "https://translations.telegram.org/taiwan/")
]
