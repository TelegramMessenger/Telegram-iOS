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
    let useIgnoreLanguages: (Bool) -> Void
    let updateData: (String, Bool) -> Void
    
    init(useIgnoreLanguages: @escaping (Bool) -> Void, updateData: @escaping (String, Bool) -> Void) {
        self.useIgnoreLanguages = useIgnoreLanguages
        self.updateData = updateData
    }
}

private enum sections: Int32 {
    case useIgnoreLanguages
    case header
    case commonLanguages
    case languages
}


private enum Entry: ItemListNodeEntry {
    case useIgnoreLanguages(PresentationTheme, String, Bool)
    case useIgnoreLanguagesNote(PresentationTheme, String)
    case header(PresentationTheme, String)
    case commonlanguageToggle(PresentationTheme, String, String, Bool, Int32)
    case languageToggle(PresentationTheme, String, String, Bool, Int32)
    case footer(PresentationTheme, String)
    
    
    var section: ItemListSectionId {
        switch self {
        case .useIgnoreLanguages, .useIgnoreLanguagesNote:
            return sections.useIgnoreLanguages.rawValue
        case .header, .commonlanguageToggle:
            return sections.commonLanguages.rawValue
        default:
            return sections.languages.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .useIgnoreLanguages:
            return -2
        case .useIgnoreLanguagesNote:
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
            case let .useIgnoreLanguages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.useIgnoreLanguages(value)
                })
            case let .useIgnoreLanguagesNote(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
            case let .header(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .commonlanguageToggle(_, text, langCode, value, id):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateData(langCode, value)
            })
        case let .languageToggle(_, text, langCode, value, _):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateData(langCode, value)
            })
        case let .footer(_, text):
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
    let _ = presentationData.strings
    let locale = presentationData.strings.baseLanguageCode
    
    let ignoredTranslations = NGSettings.ignoreTranslate
    entries.append(.useIgnoreLanguages(theme, l("Premium.OnetapTranslate.UseIgnoreLanguages", locale), NGSettings.useIgnoreLanguages))
    entries.append(.useIgnoreLanguagesNote(theme, l("Premium.OnetapTranslate.UseIgnoreLanguages.Note", locale)))
    if !NGSettings.useIgnoreLanguages {
        return entries
    }
    
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
    
    let arguments = IgnoreTranslateArguments(useIgnoreLanguages: { value in
        NGSettings.useIgnoreLanguages = value
        // Trigger ItemListController state update
        updateState {$0}
    }, updateData: { langCode, isIgnoring in
        if isIgnoring {
            if !NGSettings.ignoreTranslate.contains(langCode) {
                NGSettings.ignoreTranslate.append(langCode)
            }
        } else {
            if let index = NGSettings.ignoreTranslate.firstIndex(of: langCode) {
                    NGSettings.ignoreTranslate.remove(at: index)
                }
        }
        // Trigger ItemListController state update
        updateState {$0}
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> map {presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let entries = ignoreTranslateControllerEntries(presentationData: presentationData)
            
            
            var scrollToItem: ListViewScrollToItem?
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(l("Premium.IgnoreTranslate.Title", presentationData.strings.baseLanguageCode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: scrollToItem, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
