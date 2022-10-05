import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import NaturalLanguage
import TelegramCore

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public var supportedTranslationLanguages = [
    "af",
    "sq",
    "am",
    "ar",
    "hy",
    "az",
    "eu",
    "be",
    "bn",
    "bs",
    "bg",
    "ca",
    "ceb",
    "zh",
//    "zh-Hant",
//    "zh-CN", "zh"
//    "zh-TW"
    "co",
    "hr",
    "cs",
    "da",
    "nl",
    "en",
    "eo",
    "et",
    "fi",
    "fr",
    "fy",
    "gl",
    "ka",
    "de",
    "el",
    "gu",
    "ht",
    "ha",
    "haw",
    "he",
    "hi",
    "hmn",
    "hu",
    "is",
    "ig",
    "id",
    "ga",
    "it",
    "ja",
    "jv",
    "kn",
    "kk",
    "km",
    "rw",
    "ko",
    "ku",
    "ky",
    "lo",
    "lv",
    "lt",
    "lb",
    "mk",
    "mg",
    "ms",
    "ml",
    "mt",
    "mi",
    "mr",
    "mn",
    "my",
    "ne",
    "no",
    "ny",
    "or",
    "ps",
    "fa",
    "pl",
    "pt",
    "pa",
    "ro",
    "ru",
    "sm",
    "gd",
    "sr",
    "st",
    "sn",
    "sd",
    "si",
    "sk",
    "sl",
    "so",
    "es",
    "su",
    "sw",
    "sv",
    "tl",
    "tg",
    "ta",
    "tt",
    "te",
    "th",
    "tr",
    "tk",
    "uk",
    "ur",
    "ug",
    "uz",
    "vi",
    "cy",
    "xh",
    "yi",
    "yo",
    "zu"
]

public var popularTranslationLanguages = [
    "en",
    "ar",
    "zh",
//    "zh-Hant",
    "fr",
    "de",
    "it",
    "ja",
    "ko",
    "pt",
    "ru",
    "es"
]

@available(iOS 12.0, *)
private let languageRecognizer = NLLanguageRecognizer()

public func canTranslateText(context: AccountContext, text: String, showTranslate: Bool, showTranslateIfTopical: Bool = false, ignoredLanguages: [String]?) -> (canTranslate: Bool, language: String?) {
    guard showTranslate || showTranslateIfTopical, text.count > 0 else {
        return (false, nil)
    }

    if #available(iOS 12.0, *) {
        var dontTranslateLanguages: [String] = []
        if let ignoredLanguages = ignoredLanguages {
            dontTranslateLanguages = ignoredLanguages
        } else {
            dontTranslateLanguages = [context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode]
        }
        
        let text = String(text.prefix(64))
        languageRecognizer.processString(text)
        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
        languageRecognizer.reset()
        
        var supportedTranslationLanguages = supportedTranslationLanguages
        if !showTranslate && showTranslateIfTopical {
            supportedTranslationLanguages = ["uk", "ru"]
        }
        
        let filteredLanguages = hypotheses.filter { supportedTranslationLanguages.contains($0.key.rawValue) }.sorted(by: { $0.value > $1.value })
        if let language = filteredLanguages.first(where: { supportedTranslationLanguages.contains($0.key.rawValue) }) {
            return (!dontTranslateLanguages.contains(language.key.rawValue), language.key.rawValue)
        } else {
            return (false, nil)
        }
    } else {
        return (false, nil)
    }
}
