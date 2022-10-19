//
//  CrowdinPathsParser.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/10/19.
//

import Foundation

fileprivate enum Paths: String {
    case language = "%language%"
    case locale = "%locale%"
    case localeWithUnderscore = "%locale_with_underscore%"
    case osxCode = "%osx_code%"
    case osxLocale = "%osx_locale%"
    case twoLettersCode = "%two_letters_code%"
    
    static var all: [Paths] = [.language, .locale, .localeWithUnderscore, .osxCode, .osxLocale, .twoLettersCode]
    
    func value(for localization: String, languageResolver: LanguageResolver) -> String {
        guard let language = languageResolver.crowdinSupportedLanguage(for: localization) else { return "" }
        switch self {
        case .language:
            return language.name
        case .locale:
            return language.locale
        case .localeWithUnderscore:
            return language.locale.replacingOccurrences(of: "-", with: "_")
        case .osxCode:
            return language.osxCode
        case .osxLocale:
            return language.osxLocale
        case .twoLettersCode:
            return language.twoLettersCode
        }
    }
}

class CrowdinPathsParser {
    let languageResolver: LanguageResolver
    
    init(languageResolver: LanguageResolver) {
        self.languageResolver = languageResolver
    }
    
	func parse(_ path: String, localization: String) -> String {
        var resultPath = path
        if CrowdinPathsParser.containsCustomPath(path) {
            Paths.all.forEach { (path) in
                resultPath = resultPath.replacingOccurrences(of: path.rawValue, with: path.value(for: localization, languageResolver: languageResolver))
            }
        } else {
            // Add localization code to file name
            let crowdinLocalization = languageResolver.crowdinLanguageCode(for: localization) ?? localization
            resultPath = "/\(crowdinLocalization)\(path)"
        }
        return resultPath
    }
    
    static func containsCustomPath(_ filePath: String) -> Bool {
        var contains = false
        Paths.all.forEach { (path) in
            if filePath.contains(path.rawValue) {
                contains = true
                return
            }
        }
        return contains
    }
}
