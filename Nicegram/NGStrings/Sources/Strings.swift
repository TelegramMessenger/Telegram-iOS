//
//  Strings.swift
//  NGStrings
//
//  Created by Sergey Akentev on 10/07/2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import AppBundle
import NGLogging

fileprivate let LOGTAG = extractNameFromPath(#file)

private func gd(locale: String) -> [String : String] {
    return NSDictionary(contentsOf: URL(fileURLWithPath: getAppBundle().path(forResource: "NiceLocalizable", ofType: "strings", inDirectory: nil, forLocalization: locale)!)) as! [String : String]
}

let niceLocales: [String : [String : String]] = [
    "en" : gd(locale: "en"),
    "ru": gd(locale: "ru"),
    "ar": gd(locale: "ar"),
    "de": gd(locale: "de"),
    "it": gd(locale: "it"),
    "es": gd(locale: "es"),
    "uk": gd(locale: "uk"),
    
    // Chinese
    // Simplified
    "zh-hans": gd(locale: "zh-hans"),
    // Traditional
    "zh-hant": gd(locale: "zh-hant"),
    
    "fa": gd(locale: "fa"),
    "pl": gd(locale: "pl"),
    "sk": gd(locale: "sk"),
    "tr": gd(locale: "tr"),
    "ro": gd(locale: "ro"),
    "ko": gd(locale: "ko"),
    "ku": gd(locale: "ku"),
    "be": [:],
]

public func getLangFallback(_ lang: String) -> String {
    switch (lang) {
    case "zh-hant":
        return "zh-hans"
    case "uk", "be":
        return "ru"
    case "ckb":
        return "ku"
    case "sdh": // Need investigate
        return "ku"
    default:
        return "en"
    }
}

func getFallbackKey(_ key: String) -> String {
    switch (key) {
    case "NicegramSettings.Notifications.hideAccountInNotification":
        return "NiceFeatures.Notifications.HideNotifyAccount"
    case "NicegramSettings.Notifications.hideAccountInNotificationNotice":
        return "NiceFeatures.Notifications.HideNotifyAccountNotice"
    case "NicegramSettings.Tabs":
        return "NiceFeatures.Tabs.Header"
    case "NicegramSettings.Tabs.showContactsTab":
        return "NiceFeatures.Tabs.ShowContacts"
    case "NicegramSettings.Tabs.showTabNames":
        return "NiceFeatures.Tabs.ShowNames"
    case "NicegramSettings.Folders":
        return "NiceFeatures.Folders.Header"
    case "NicegramSettings.Folders.foldersAtBottom":
        return "NiceFeatures.Folders.TgFolders"
    case "NicegramSettings.Folders.foldersAtBottomNotice":
        return "NiceFeatures.Folders.TgFolders.Notice"
    case "NicegramSettings.RoundVideos":
        return "NiceFeatures.RoundVideos.Header"
    case "NicegramSettings.RoundVideos.startWithRearCam":
        return "NiceFeatures.RoundVideos.UseRearCamera"
    case "NicegramSettings.Other.hidePhoneInSettings":
        return "NiceFeatures.HideNumber"
        
    default:
        return key
    }
}

public func l(_ key: String, _ locale: String = "en") -> String {
    var lang = locale
    let key = getFallbackKey(key)
    let rawSuffix = "-raw"
    if lang.hasSuffix(rawSuffix) {
        lang = String(lang.dropLast(rawSuffix.count))
    }
    
    if !niceLocales.keys.contains(lang) {
        lang = "en"
    }
    
    var result = "[MISSING STRING. PLEASE UPDATE APP]"
    
    if let res = niceWebLocales[lang]?[key], !res.isEmpty {
        result = res
    } else if let res = niceLocales[lang]?[key], !res.isEmpty {
        result = res
    } else if let res = niceLocales[getLangFallback(lang)]?[key], !res.isEmpty {
        result = res
    } else if let res = niceLocales["en"]?[key], !res.isEmpty {
        result = res
    } else if !key.isEmpty {
        result = key
    }
    
    return result
}


public func getStringsUrl(_ lang: String) -> String {
    return "https://raw.githubusercontent.com/nicegram/translations/master/Telegram-iOS/" + lang + ".lproj/NiceLocalizable.strings"
}


var niceWebLocales: [String: [String: String]] = [:]

func getWebDict(_ lang: String) -> [String : String]? {
    return NSDictionary(contentsOf: URL(string: getStringsUrl(lang))!) as? [String : String]
}

public func downloadLocale(_ locale: String) -> Void {
    ngLog("Downloading \(locale)", LOGTAG)
    do {
        var lang = locale
        let rawSuffix = "-raw"
        if lang.hasSuffix(rawSuffix) {
            lang = String(lang.dropLast(rawSuffix.count))
        }
        if let localeDict = try getWebDict(lang) {
            niceWebLocales[lang] = localeDict
            ngLog("Successfully downloaded locale \(lang)", LOGTAG)
        } else {
            ngLog("Failed to download \(locale)", LOGTAG)
        }
    } catch {
        return
    }
}
