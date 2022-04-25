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

private final class LanguageSelectionControllerArguments {
    let context: AccountContext
    let updateLanguageSelected: (String) -> Void
    
    init(context: AccountContext, updateLanguageSelected: @escaping (String) -> Void) {
        self.context = context
        self.updateLanguageSelected = updateLanguageSelected
    }
}

private enum LanguageSelectionControllerSection: Int32 {
    case languages
}

private enum LanguageSelectionControllerEntry: ItemListNodeEntry {
    case language(Int32, PresentationTheme, String, String,  Bool, String)
   
    var section: ItemListSectionId {
        switch self {
        case .language:
            return LanguageSelectionControllerSection.languages.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case let .language(index, _, _, _, _, _):
                return index
        }
    }
    
    static func ==(lhs: LanguageSelectionControllerEntry, rhs: LanguageSelectionControllerEntry) -> Bool {
        switch lhs {
            case let .language(lhsIndex, lhsTheme, lhsTitle, lhsSubtitle, lhsValue, lhsCode):
                if case let .language(rhsIndex, rhsTheme, rhsTitle, rhsSubtitle, rhsValue, rhsCode) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsValue == rhsValue, lhsCode == rhsCode {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: LanguageSelectionControllerEntry, rhs: LanguageSelectionControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! LanguageSelectionControllerArguments
        switch self {
            case let .language(_, _, title, subtitle, value, code):
                return LocalizationListItem(presentationData: presentationData, id: code, title: title, subtitle: subtitle, checked: value, activity: false, loading: false, editing: LocalizationListItemEditing(editable: false, editing: false, revealed: false, reorderable: false), sectionId: self.section, alwaysPlain: false, action: {
                    arguments.updateLanguageSelected(code)
                }, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in })
        }
    }
}

private func languageSelectionControllerEntries(theme: PresentationTheme, strings: PresentationStrings, selectedLanguage: String, languages: [(String, String, String)]) -> [LanguageSelectionControllerEntry] {
    var entries: [LanguageSelectionControllerEntry] = []
  
    var index: Int32 = 0
    for (code, title, subtitle) in languages {
        entries.append(.language(index, theme, title, subtitle, code == selectedLanguage, code))
        index += 1
    }
  
    return entries
}

private struct LanguageSelectionControllerState: Equatable {
    enum Section {
        case original
        case translation
    }
    
    var section: Section
    var fromLanguage: String
    var toLanguage: String
}

public func languageSelectionController(context: AccountContext, fromLanguage: String, toLanguage: String, completion: @escaping (String, String) -> Void) -> ViewController {
    let statePromise = ValuePromise(LanguageSelectionControllerState(section: .translation, fromLanguage: fromLanguage, toLanguage: toLanguage), ignoreRepeated: true)
    let stateValue = Atomic(value: LanguageSelectionControllerState(section: .translation, fromLanguage: fromLanguage, toLanguage: toLanguage))
    let updateState: ((LanguageSelectionControllerState) -> LanguageSelectionControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let interfaceLanguageCode = presentationData.strings.baseLanguageCode
    
    var dismissImpl: (() -> Void)?
    
    let arguments = LanguageSelectionControllerArguments(context: context, updateLanguageSelected: { code in
        updateState { current in
            var updated = current
            switch updated.section {
            case .original:
                updated.fromLanguage = code
            case .translation:
                updated.toLanguage = code
            }
            return updated
        }
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

    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .sectionControl([presentationData.strings.Translate_Languages_Original, presentationData.strings.Translate_Languages_Translation], 1), leftNavigationButton: ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {}), rightNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
            completion(state.fromLanguage, state.toLanguage)
            dismissImpl?()
        }), backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        
        let selectedLanguage: String
        switch state.section {
            case.original:
                selectedLanguage = state.fromLanguage
            case .translation:
                selectedLanguage = state.toLanguage
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: languageSelectionControllerEntries(theme: presentationData.theme, strings: presentationData.strings, selectedLanguage: selectedLanguage, languages: languages), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.titleControlValueChanged = {  value in
        updateState { current in
            var updated = current
            if value == 0 {
                updated.section = .original
            } else {
                updated.section = .translation
            }
            return updated
        }
    }
    controller.alwaysSynchronous = true
    controller.navigationPresentation = .modal
    
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true, completion: nil)
    }
    
    return controller
}
