import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting
import AccountContext
import TranslateUI

private final class TranslationSettingsControllerArguments {
    let context: AccountContext
    let updateLanguageSelected: (String, Bool) -> Void
    
    init(context: AccountContext, updateLanguageSelected: @escaping (String, Bool) -> Void) {
        self.context = context
        self.updateLanguageSelected = updateLanguageSelected
    }
}

private enum TranslationSettingsControllerSection: Int32 {
    case languages
}

private enum TranslationSettingsControllerEntry: ItemListNodeEntry {
    case language(Int32, PresentationTheme, String, String,  Bool, String)
   
    var section: ItemListSectionId {
        switch self {
        case .language:
            return TranslationSettingsControllerSection.languages.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case let .language(index, _, _, _, _, _):
                return index
        }
    }
    
    static func ==(lhs: TranslationSettingsControllerEntry, rhs: TranslationSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .language(lhsIndex, lhsTheme, lhsTitle, lhsSubtitle, lhsValue, lhsCode):
                if case let .language(rhsIndex, rhsTheme, rhsTitle, rhsSubtitle, rhsValue, rhsCode) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsValue == rhsValue, lhsCode == rhsCode {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: TranslationSettingsControllerEntry, rhs: TranslationSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TranslationSettingsControllerArguments
        switch self {
            case let .language(_, _, title, subtitle, value, code):
                return LocalizationListItem(presentationData: presentationData, id: code, title: title, subtitle: subtitle, checked: value, activity: false, loading: false, editing: LocalizationListItemEditing(editable: false, editing: false, revealed: false, reorderable: false), sectionId: self.section, alwaysPlain: false, action: {
                    arguments.updateLanguageSelected(code, !value)
                }, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in })
        }
    }
}

private func translationSettingsControllerEntries(theme: PresentationTheme, strings: PresentationStrings, settings: TranslationSettings, languages: [(String, String, String)]) -> [TranslationSettingsControllerEntry] {
    var entries: [TranslationSettingsControllerEntry] = []
  
    var index: Int32 = 0
    var selectedLanguages: Set<String>
    if let ignoredLanguages = settings.ignoredLanguages {
        selectedLanguages = Set(ignoredLanguages)
    } else {
        selectedLanguages = Set([strings.baseLanguageCode])
    }
    for (code, title, subtitle) in languages {
        entries.append(.language(index, theme, title, subtitle, selectedLanguages.contains(code), code))
        index += 1
    }
  
    return entries
}

public func translationSettingsController(context: AccountContext) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let interfaceLanguageCode = presentationData.strings.baseLanguageCode
    
    let arguments = TranslationSettingsControllerArguments(context: context, updateLanguageSelected: { code, value in
        let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            var updated = current
            var updatedIgnoredLanguages = updated.ignoredLanguages ?? []
            if value {
                if current.ignoredLanguages == nil {
                    updatedIgnoredLanguages.append(interfaceLanguageCode)
                }
                if !updatedIgnoredLanguages.contains(code) {
                    updatedIgnoredLanguages.append(code)
                }
            } else {
                updatedIgnoredLanguages.removeAll(where: { $0 == code })
            }
            updated = updated.withUpdatedIgnoredLanguages(updatedIgnoredLanguages)
            return updated
        }).start()
    })
    
    let enLocale = Locale(identifier: "en")
    var languages: [(String, String, String)] = []
    var addedLanguages = Set<String>()
    for code in popularTranslationLanguages {
        if let title = enLocale.localizedString(forLanguageCode: code) {
            let languageLocale = Locale(identifier: code)
            let subtitle = languageLocale.localizedString(forLanguageCode: code) ?? title
            let value = (code, title.capitalized, subtitle.capitalized)
            if code == interfaceLanguageCode {
                languages.insert(value, at: 0)
            } else {
                languages.append(value)
            }
            addedLanguages.insert(code)
        }
    }

    for code in supportedTranslationLanguages {
        if !addedLanguages.contains(code), let title = enLocale.localizedString(forLanguageCode: code) {
            let languageLocale = Locale(identifier: code)
            let subtitle = languageLocale.localizedString(forLanguageCode: code) ?? title
            let value = (code, title.capitalized, subtitle.capitalized)
            if code == interfaceLanguageCode {
                languages.insert(value, at: 0)
            } else {
                languages.append(value)
            }
        }
    }

    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, sharedData)
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) ?? TranslationSettings.defaultSettings
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.DoNotTranslate_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: translationSettingsControllerEntries(theme: presentationData.theme, strings: presentationData.strings, settings: settings, languages: languages), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    return controller
}
