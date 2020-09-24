//
//  IgnoreTranslateController.swift
//  ChatListUI
//
//  Created by Sergey Akentev on 1/21/20.
//

import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import TelegramNotices
import NGData
import NGStrings

private final class IgnoreTranslateArguments {
    let updateData: (String, Bool) -> Void
    
    init(updateData: @escaping (String, Bool) -> Void) {
        self.updateData = updateData
    }
}

private enum sections: Int32 {
    case lowPower
    case header
    case commonLanguages
    case languages
}


private enum Entry: ItemListNodeEntry {
    case trButtonLowPowerMode(PresentationTheme, String, Bool)
    case trButtonLowPowerModeNotice(PresentationTheme, String)
    case header(PresentationTheme, String)
    case commonlanguageToggle(PresentationTheme, String, String, Bool, Int32)
    case languageToggle(PresentationTheme, String, String, Bool, Int32)
    case footer(PresentationTheme, String)
    
    
    var section: ItemListSectionId {
        switch self {
        case .trButtonLowPowerMode, .trButtonLowPowerModeNotice:
            return sections.lowPower.rawValue
        case .header, .commonlanguageToggle:
            return sections.commonLanguages.rawValue
        default:
            return sections.languages.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .trButtonLowPowerMode:
            return -2
        case .trButtonLowPowerModeNotice:
            return -1
        case .header:
            return 0
        case let .commonlanguageToggle(_, _, _, _, id):
             return 1000 + id
        case let .languageToggle(_, _, _, _, id):
            return 1000 + id
        case .footer:
            return 10000
        }
    }
    
    
    static func < (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! IgnoreTranslateArguments
        switch self {
            case let .trButtonLowPowerMode(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    NGSettings.oneTapTrButtonLowPowerMode = value
                })
            case let .trButtonLowPowerModeNotice(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
            case let .header(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .commonlanguageToggle(theme, text, langCode, value, id):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateData(langCode, value)
            })
        case let .languageToggle(theme, text, langCode, value, id):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateData(langCode, value)
            })
        case let .footer(theme, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func getLocaleName(_ langCode: String, _ systemLang: Locale) -> String {
    var screenName = langCode
    if let parsedName = (systemLang as NSLocale).displayName(forKey: NSLocale.Key.identifier, value: langCode) {
        screenName = parsedName
    }
    return screenName
}


private func ignoreTranslateControllerEntries(presentationData: PresentationData) -> [Entry] {
    var entries: [Entry] = []
    let theme = presentationData.theme
    let strings = presentationData.strings
    let locale = presentationData.strings.baseLanguageCode
    
    let ignoredTranslations = NGSettings.ignoreTranslate
    
    entries.append(.trButtonLowPowerMode(theme, l("Premium.OnetapTranslate.LowPower", locale), NGSettings.oneTapTrButtonLowPowerMode))
    entries.append(.trButtonLowPowerModeNotice(theme, l("Premium.OnetapTranslate.LowPower.Notice", locale)))
    
    entries.append(.header(theme, l("Premium.IgnoreTranslate.Header", locale)))
    
    let pre = Locale.preferredLanguages
    var preLangs: [String] = []
    var counter: Int32 = 0
    for lang in pre {
        let parsedLocale = Locale(identifier: lang)
        var addScript = ""
        if let scriptCode = parsedLocale.scriptCode {
            addScript = "-\(scriptCode)"
        }
        var langCode = parsedLocale.languageCode ?? lang
        
        if parsedLocale.languageCode != nil {
            langCode = langCode + addScript
        }
        
        if !preLangs.contains(langCode) {
            let screenName = getLocaleName(langCode, Locale.current)
            entries.append(.commonlanguageToggle(theme, screenName, langCode, ignoredTranslations.contains(langCode), counter))
            preLangs.append(langCode)
            counter += 1
        }
    }
    
    
    var processedLangs: [String] = []
    
    var sanitizedLangs: [String] = []
    for lang in NSLocale.availableLocaleIdentifiers {
        let parsedLocale = Locale(identifier: lang)
        var addScript = ""
        if let scriptCode = parsedLocale.scriptCode {
            addScript = "-\(scriptCode)"
        }
        var langCode = parsedLocale.languageCode ?? lang
        
        if parsedLocale.languageCode != nil {
            langCode = langCode + addScript
        }

        sanitizedLangs.append(langCode)
    }
    
    
    var otherLangsArray: [(String, String)] = []
    
    for langCode in sanitizedLangs {
        if !preLangs.contains(langCode) && !processedLangs.contains(langCode) {
            let screenName = getLocaleName(langCode, Locale.current)
            otherLangsArray.append((langCode, screenName))
            processedLangs.append(langCode)
        }
    }
    
    let sortedOtherLangs = otherLangsArray.sorted { $0.1 < $1.1 }
    
    for entry in sortedOtherLangs {
        entries.append(.languageToggle(theme, entry.1, entry.0, ignoredTranslations.contains(entry.0), counter))
        counter += 1
    }
    
    entries.append(.footer(theme, "Hello :)"))
    
    
    return entries
}

private struct SelectionState: Equatable {
}


public func ignoreTranslateController(context: AccountContext) -> ViewController {
    
    
    var dismissImpl: (() -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
    let statePromise = ValuePromise(SelectionState(), ignoreRepeated: false)
    let stateValue = Atomic(value: SelectionState())
    let updateState: ((SelectionState) -> SelectionState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = IgnoreTranslateArguments(updateData: { langCode, isIgnoring in
        if isIgnoring {
            if !NGSettings.ignoreTranslate.contains(langCode) {
                NGSettings.ignoreTranslate.append(langCode)
            }
        } else {
            if let index = NGSettings.ignoreTranslate.index(of: langCode) {
                    NGSettings.ignoreTranslate.remove(at: index)
                }
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> map {presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let entries = ignoreTranslateControllerEntries(presentationData: presentationData)
            
            
            var index = 0
            var scrollToItem: ListViewScrollToItem?
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(l("Premium.IgnoreTranslate.Title", presentationData.strings.baseLanguageCode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: scrollToItem)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
