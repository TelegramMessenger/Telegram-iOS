//
//  LanguagePackInfo.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a language pack
public struct LanguagePackInfo: Codable, Equatable, Hashable {

    /// Identifier of a base language pack; may be empty. If a string is missed in the language pack, then it must be fetched from base language pack. Unsupported in custom language packs
    public let baseLanguagePackId: String

    /// Unique language pack identifier
    public let id: String

    /// True, if the language pack is a beta language pack
    public let isBeta: Bool

    /// True, if the language pack is installed by the current user
    public let isInstalled: Bool

    /// True, if the language pack is official
    public let isOfficial: Bool

    /// True, if the language pack strings are RTL
    public let isRtl: Bool

    /// Total number of non-deleted strings from the language pack available locally
    public let localStringCount: Int

    /// Language name
    public let name: String

    /// Name of the language in that language
    public let nativeName: String

    /// A language code to be used to apply plural forms. See https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html for more information
    public let pluralCode: String

    /// Total number of non-deleted strings from the language pack
    public let totalStringCount: Int

    /// Total number of translated strings from the language pack
    public let translatedStringCount: Int

    /// Link to language translation interface; empty for custom local language packs
    public let translationUrl: String


    public init(
        baseLanguagePackId: String,
        id: String,
        isBeta: Bool,
        isInstalled: Bool,
        isOfficial: Bool,
        isRtl: Bool,
        localStringCount: Int,
        name: String,
        nativeName: String,
        pluralCode: String,
        totalStringCount: Int,
        translatedStringCount: Int,
        translationUrl: String
    ) {
        self.baseLanguagePackId = baseLanguagePackId
        self.id = id
        self.isBeta = isBeta
        self.isInstalled = isInstalled
        self.isOfficial = isOfficial
        self.isRtl = isRtl
        self.localStringCount = localStringCount
        self.name = name
        self.nativeName = nativeName
        self.pluralCode = pluralCode
        self.totalStringCount = totalStringCount
        self.translatedStringCount = translatedStringCount
        self.translationUrl = translationUrl
    }
}

