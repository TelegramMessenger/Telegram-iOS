//
//  GTranslate.swift
//  NicegramLib
//
//  Created by Sergey Akentev on 20.11.2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import UIKit
import NGData
import NGLogging

fileprivate let LOGTAG = extractNameFromPath(#file)

public var gTranslateSeparator = "🗨 GTranslate"

public func getTranslateUrl(_ message: String,_ toLang: String) -> String {
    var sanitizedMessage = message.replaceCharactersFromSet(characterSet:CharacterSet.newlines, replacementString: "¦")
    
    if let dotRange = sanitizedMessage.range(of: "\n\n" + gTranslateSeparator) {
        sanitizedMessage.removeSubrange(dotRange.lowerBound..<sanitizedMessage.endIndex)
    }
    
    var queryCharSet = NSCharacterSet.urlQueryAllowed
    queryCharSet.remove(charactersIn: "+&")
    return "https://translate.google.com/m?hl=en&tl=\(toLang)&sl=auto&q=\(sanitizedMessage.addingPercentEncoding(withAllowedCharacters: queryCharSet) ?? "")"
}

func prepareResultString(_ str: String) -> String {
    return str.htmlDecoded.replacingOccurrences(of: " ¦", with: "\n").replacingOccurrences(of: "¦ ", with: "\n").replacingOccurrences(of: "¦", with: "\n")
}

public func parseTranslateResponse(_ data: String) -> String {
    for rule in VarGNGSettings.translate_rules {
        if data.contains(rule.data_check) {
            do {
                let regexp = try NSRegularExpression(pattern: rule.pattern)
                if let match = regexp.firstMatch(in: data, options: [], range: NSRange(location: 0, length: data.utf16.count)) {
                    if let translatedString = Range(match.range(at: rule.match_group), in: data) {
                        return prepareResultString(String(data[translatedString]))
                    }
                }
            } catch let error as NSError {
                ngLog("Error processing '\(rule.name)' regexp \(error.localizedDescription)", LOGTAG)
                continue
            }
        }
    }
    return ""
}

public func getGoogleLang(_ userLang: String) -> String {
    var lang = userLang
    let rawSuffix =  "-raw"
    if lang.hasSuffix(rawSuffix) {
        lang = String(lang.dropLast(rawSuffix.count))
    }
    
    // Google lang for Chineses
    switch (lang) {
        case "zh-hans":
            return "zh-CN"
        case "zh-hant":
            return "zh-TW"
        default:
            break
    }
    
    
    // Fix for pt-br and other non Chinese langs
    // https://cloud.google.com/translate/docs/languages
    lang = lang.components(separatedBy: "-")[0].components(separatedBy: "_")[0]
    
    return lang
}


public enum TranslateFetchError {
    case network
}


public func requestTranslateUrl(url: URL) -> Signal<String, TranslateFetchError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Set headers
        request.setValue("Mozilla/4.0 (compatible;MSIE 6.0;Windows NT 5.1;SV1;.NET CLR 1.1.4322;.NET CLR 2.0.50727;.NET CLR 3.0.04506.30)", forHTTPHeaderField: "User-Agent")
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)
        let downloadTask = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            let _ = completed.swap(true)
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    if let data = data {
                        if let result = String(data: data, encoding: .utf8) {
                            subscriber.putNext(result)
                            subscriber.putCompletion()
                        } else {
                            subscriber.putError(.network)
                        }
                    } else {
                        subscriber.putError(.network)
                    }
                } else {
                    subscriber.putError(.network)
                }
            } else {
                subscriber.putError(.network)
            }
        })
        downloadTask.resume()
        
        return ActionDisposable {
            if !completed.with({ $0 }) {
                downloadTask.cancel()
            }
        }
    }
}


public func gtranslate(_ text: String, _ toLang: String) -> Signal<String, TranslateFetchError> {
    return Signal { subscriber in
        let urlString = getTranslateUrl(text, getGoogleLang(toLang))
        let url = URL(string: urlString)!
        let translateSignal = requestTranslateUrl(url: url)
        
        let _ = (translateSignal |> deliverOnMainQueue).start(next: {
            translatedHtml in
            let result = parseTranslateResponse(translatedHtml)
            if result.isEmpty {
                subscriber.putError(.network) // Fake
            } else {
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            
        }, error: { _ in
            subscriber.putError(.network)
        })
        
        return ActionDisposable {
        }
    }
}


extension String {
    var htmlDecoded: String {
        
        
        let attributedOptions: [NSAttributedString.DocumentReadingOptionKey : Any] = [
            
            NSAttributedString.DocumentReadingOptionKey.documentType : NSAttributedString.DocumentType.html,
            NSAttributedString.DocumentReadingOptionKey.characterEncoding : String.Encoding.utf8.rawValue
        ]
        
        
        let decoded = try? NSAttributedString(data: Data(utf8), options: attributedOptions
            , documentAttributes: nil).string
        
        return decoded ?? self
    }
    
    func replaceCharactersFromSet(characterSet: CharacterSet, replacementString: String = "") -> String {
        return components(separatedBy: characterSet).joined(separator: replacementString)
    }
}
