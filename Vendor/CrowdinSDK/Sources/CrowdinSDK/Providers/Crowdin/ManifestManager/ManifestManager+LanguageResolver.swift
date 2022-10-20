//
//  LanguageResolver.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 02.11.2021.
//

import Foundation

extension ManifestManager: LanguageResolver {
    var allLanguages: [CrowdinLanguage] {
        let crowdinLanguages: [CrowdinLanguage] = CrowdinSupportedLanguages.shared.supportedLanguages?.data.map({ $0.data }) ?? []
        let customLaguages: [CrowdinLanguage] = customLanguages ?? []
        let allLanguages: [CrowdinLanguage] = crowdinLanguages + customLaguages
        return allLanguages
    }
    /// Get crowdin language locale code for iOS localization code.
    /// - Parameter localization: iOS localization identifier. (List of all - Locale.availableIdentifiers).
    /// - Returns: Id of iOS localization code in crowdin system.
    func crowdinLanguageCode(for localization: String) -> String? {
        crowdinSupportedLanguage(for: localization)?.id
    }
    
    func crowdinSupportedLanguage(for localization: String) -> CrowdinLanguage? {
        var language = allLanguages.first(where: { $0.iOSLanguageCode == localization })
        if language == nil {
            // This is possible for languages ​​with regions. In case we didn't find Crowdin language mapping, try to replace _ in location code with -
            let alternateiOSLocaleCode = localization.replacingOccurrences(of: "_", with: "-")
            language = allLanguages.first(where: { $0.iOSLanguageCode == alternateiOSLocaleCode })
        }
        if language == nil {
            // This is possible for languages ​​with regions. In case we didn't find Crowdin language mapping, try to get localization code and search again
            let alternateiOSLocaleCode = localization.split(separator: "_").map({ String($0) }).first
            language = allLanguages.first(where: { $0.iOSLanguageCode == alternateiOSLocaleCode })
        }
        return language
    }
    
    func iOSLanguageCode(for crowdinLocalization: String) -> String? {
        allLanguages.first(where: { $0.id == crowdinLocalization })?.osxLocale
    }
}
