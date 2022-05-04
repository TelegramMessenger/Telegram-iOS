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
    "zh-Hans",
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
    "zh-Hans",
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

public struct TextTranslationResult: Equatable {
    let text: String
    let detectedLanguage: String?
}

public enum TextTranslationError {
    case generic
}

private let userAgents: [String] = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36", // 13.5%
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36", // 6.6%
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:94.0) Gecko/20100101 Firefox/94.0", // 6.4%
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:95.0) Gecko/20100101 Firefox/95.0", // 6.2%
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.93 Safari/537.36", // 5.2%
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.55 Safari/537.36" // 4.8%
]

public func translateText(context: AccountContext, text: String, from: String?, to: String) -> Signal<TextTranslationResult, TextTranslationError> {
    return Signal { subscriber in
        var uri = "https://translate.goo";
        uri += "gleapis.com/transl";
        uri += "ate_a";
        uri += "/singl";
        uri += "e?client=gtx&sl=" + (from ?? "auto") + "&tl=" + to + "&dt=t" + "&ie=UTF-8&oe=UTF-8&otf=1&ssel=0&tsel=0&kc=7&dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&q=";
        uri += text.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        
        var request = URLRequest(url: URL(string: uri)!)
        request.httpMethod = "GET"
        request.setValue(userAgents[Int.random(in: 0 ..< userAgents.count)], forHTTPHeaderField: "User-Agent")
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            if let _ = error {
                subscriber.putError(.generic)
            } else if let data = data {
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSArray
                if let json = json, json.count > 0 {
                    let array = json[0] as? NSArray ?? NSArray()
                    var result: String = ""
                    for i in 0 ..< array.count {
                        let blockText = array[i] as? NSArray
                        if let blockText = blockText, blockText.count > 0 {
                            let value = blockText[0] as? String
                            if let value = value, value != "null" {
                                result += value
                            }
                        }
                    }
                    
                    let translationResult = TextTranslationResult(text: result, detectedLanguage: json[2] as? String)
                    
                    var fromLang: String?
                    if let lang = translationResult.detectedLanguage {
                        fromLang = lang
                    } else if let lang = from {
                        fromLang = lang
                    }
                    if let fromLang = fromLang {
                        let _ = context.engine.messages.translate(text: text, fromLang: fromLang, toLang: to).start()
                    }
                    
                    subscriber.putNext(translationResult)
                    subscriber.putCompletion()
                } else {
                    subscriber.putError(.generic)
                }
            }
        })
        task.resume()
                
        return ActionDisposable {
            task.cancel()
        }
    }
}
