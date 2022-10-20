//
//  LanguageResolver.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 02.11.2021.
//

import Foundation

protocol LanguageResolver {
    /// Get crowdin language locale code for iOS localization code.
    /// - Parameter localization: iOS localization identifier. (List of all - Locale.availableIdentifiers).
    /// - Returns: Id of iOS localization code in crowdin system.
    func crowdinLanguageCode(for localization: String) -> String?
    
    /// Get crowdin supported language with iOS localization code.
    /// - Parameter localization: iOS localization identifier. (List of all - Locale.availableIdentifiers).
    /// - Returns: SupportedLanguage value in crowdin system.
    func crowdinSupportedLanguage(for localization: String) -> CrowdinLanguage?
    
    /// Get iOS language code from crowdin localization code. Needs for presenting correct localization codes to users.
    /// - Returns: iOS localization code or nil, if it is not found.
    func iOSLanguageCode(for crowdinLocalization: String) -> String?
}
