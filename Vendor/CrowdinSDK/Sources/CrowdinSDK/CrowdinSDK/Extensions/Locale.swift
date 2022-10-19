//
//  Locale.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 2/5/19.
//

import Foundation

extension Locale {
	private enum Keys: String {
		case kCFLocaleLanguageCodeKey
		case kCFLocaleCountryCodeKey
		case kCFLocaleScriptCodeKey
	}
    
    /// Returns ordered list of preffered language codes detected from iOS language settings.
	static var preferredLocalizations: [String] {
        var localizations: [String] = Locale.preferredLanguages.compactMap ({
			var components = Locale.components(fromIdentifier: $0)
			if let regionCode = Locale.current.regionCode, let countryCode = components[Keys.kCFLocaleCountryCodeKey.rawValue], regionCode == countryCode {
				components[Keys.kCFLocaleCountryCodeKey.rawValue] = nil
			}
			// TODO: find a better way of getting language identifiers without replacing "_" to "-".
			return Locale.identifier(fromComponents: components).replacingOccurrences(of: "_", with: "-")
		})
        
        // Also add language code from localization with regions: "en-US" -> "en", "uk-UA" -> "uk".
        localizations.forEach {
            if let language = $0.split(separator: "-").map({ String($0) }).first, language != $0, !localizations.contains(language) {
                if let index = localizations.firstIndex(of: $0) {
                    // Insert language code without region after current localization, as this is prioritized array.
                    localizations.insert(language, at: index + 1)
                }
            }
        }
        
        // Add region code to localizations without region: "en" -> "en-US".
        if let regionCode = Locale.current.regionCode {
            localizations.forEach({
                if !$0.hasLocaleId {
                    localizations.append("\($0)-\(regionCode)")
                }
            })
        }
        return localizations
	}
    
}

private extension String {
    var hasLocaleId: Bool { split(separator: "-").count > 1 }
}
