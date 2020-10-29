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

public var gTranslateSeparator = "🗨 GTranslate"

public let trRegexp = try! NSRegularExpression(pattern: "<div dir=\"(ltr|rtl)\" class=\"t0\">([\\s\\S]+)</div><form action=")
public let modertTrRegexp = try! NSRegularExpression(pattern: "<div class=\"result-container\">([\\s\\S]+)</div><div class=")

public func getTranslateUrl(_ message: String,_ toLang: String) -> String {
    var sanitizedMessage = message.replaceCharactersFromSet(characterSet:CharacterSet.newlines, replacementString: "¦")
    
    if let dotRange = sanitizedMessage.range(of: "\n\n" + gTranslateSeparator) {
        sanitizedMessage.removeSubrange(dotRange.lowerBound..<sanitizedMessage.endIndex)
    }
    
    var queryCharSet = NSCharacterSet.urlQueryAllowed
    queryCharSet.remove(charactersIn: "+&")
    return "https://translate.google.com/m?hl=\(toLang)&sl=auto&q=\(sanitizedMessage.addingPercentEncoding(withAllowedCharacters: queryCharSet) ?? "")"
}

public func parseTranslateResponse(_ data: String) -> String {
    if data.contains("class=\"t0\">") {
        if let match = trRegexp.firstMatch(in: data, options: [], range: NSRange(location: 0, length: data.utf16.count)) {
            if let translatedString = Range(match.range(at: 2), in: data) {
                return "\(data[translatedString])".htmlDecoded.replacingOccurrences(of: " ¦", with: "\n").replacingOccurrences(of: "¦ ", with: "\n").replacingOccurrences(of: "¦", with: "\n")
            }
        }
    } else if data.contains("<div class=\"result-container\">") {
        if let match = modertTrRegexp.firstMatch(in: data, options: [], range: NSRange(location: 0, length: data.utf16.count)) {
            if let translatedString = Range(match.range(at: 1), in: data) {
                return "\(data[translatedString])".htmlDecoded.replacingOccurrences(of: " ¦", with: "\n").replacingOccurrences(of: "¦ ", with: "\n").replacingOccurrences(of: "¦", with: "\n")
            }
        }
    } else {
        return ""
    }
    return ""
}

public func getGoogleLang(_ userLang: String) -> String {
    var lang = userLang
    let rawSuffix = "-raw"
    if lang.hasSuffix(rawSuffix) {
        lang = String(lang.dropLast(rawSuffix.count))
    }
    if ["zh-hans", "zh-hant"].contains(lang) {
        if lang == "zh-hans" {
            return "zh-CN"
        } else if lang == "zh-hant" {
            return "zh-TW"
        }
    }
    
    return userLang
}


public enum TranslateFetchError {
    case network
}


public func requestTranslateUrl(url: URL) -> Signal<String, TranslateFetchError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        var request = URLRequest(url: url)
        // Set headers
        request.setValue("Mozilla/4.0 (compatible;MSIE 6.0;Windows NT 5.1;SV1;.NET CLR 1.1.4322;.NET CLR 2.0.50727;.NET CLR 3.0.04506.30)", forHTTPHeaderField: "User-Agent")
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
        let url = URL(string: getTranslateUrl(text, getGoogleLang(toLang)))!
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
