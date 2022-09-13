import Foundation
import AccountContext
import Display
import ItemListUI
import PresentationDataUtils
import SwiftSignalKit
import TelegramPresentationData
import TranslateUI

private final class LanguageListControllerArguments {
    let selectLanguage: (String) -> Void
    
    init(selectLanguage: @escaping (String) -> Void) {
        self.selectLanguage = selectLanguage
    }
}

private enum LanguageListControllerSection: Int32 {
    case languages
}

private enum LanguageListControllerEntry: ItemListNodeEntry {
    case language(Int32, PresentationTheme, LanguageInfo, Bool)
   
    var section: ItemListSectionId {
        switch self {
        case .language:
            return LanguageListControllerSection.languages.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case let .language(index, _, _, _):
                return index
        }
    }
    
    static func <(lhs: LanguageListControllerEntry, rhs: LanguageListControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! LanguageListControllerArguments
        switch self {
            case let .language(_, _, info, value):
            return LocalizationListItem(presentationData: presentationData, id: info.code, title: info.title, subtitle: info.subtitle, checked: value, activity: false, loading: false, editing: LocalizationListItemEditing(editable: false, editing: false, revealed: false, reorderable: false), sectionId: self.section, alwaysPlain: false, action: {
                    if !value {
                        arguments.selectLanguage(info.code)
                    }
                }, setItemWithRevealedOptions: { _, _ in }, removeItem: { _ in })
        }
    }
}

private struct LanguageInfo: Hashable {
    let code: String
    let title: String
    let subtitle: String
}

private struct LanguageListControllerState: Equatable {
    var languages: [LanguageInfo]
    var selectedLanguageCode: String?
}

private func languageListControllerEntries(theme: PresentationTheme, state: LanguageListControllerState) -> [LanguageListControllerEntry] {
    var entries: [LanguageListControllerEntry] = []
  
    var index: Int32 = 0
    let (languages, selectedCode) = (state.languages, state.selectedLanguageCode)
    for lang in languages {
        entries.append(.language(index, theme, lang, lang.code == selectedCode))
        index += 1
    }
  
    return entries
}

public func languageListController(context: AccountContext, selectedLanguageCode: String?, selectLanguage: @escaping (String) -> Void) -> ViewController {
    let primaryLanguageCodes = [selectedLanguageCode].compactMap{$0} + popularTranslationLanguages
    let supportedTranslationLanguageCodes = supportedTranslationLanguages
    
    let primaryLanguages = primaryLanguageCodes.compactMap { mapLangCode($0) }
    let supportedTranslationLanguages = supportedTranslationLanguageCodes
        .compactMap { mapLangCode($0) }
        .sorted(by: { $0.title < $1.title })
    
    let languages = (primaryLanguages + supportedTranslationLanguages).uniqued()
    
    let initialState = LanguageListControllerState(languages: languages, selectedLanguageCode: selectedLanguageCode)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((LanguageListControllerState) -> LanguageListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = LanguageListControllerArguments(
        selectLanguage: { code in
            updateState { state in
                var state = state
                state.selectedLanguageCode = code
                return state
            }
            selectLanguage(code)
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state  -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Settings_AppLanguage), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: languageListControllerEntries(theme: presentationData.theme, state: state), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}

private func mapLangCode(_ code: String) -> LanguageInfo? {
    let enLocale = Locale(identifier: "en")
    let langLocale = Locale(identifier: code)
    
    guard let title = enLocale.localizedString(forLanguageCode: code) else {
        return nil
    }
    
    let subtitle = langLocale.localizedString(forLanguageCode: code) ?? title
    
    return LanguageInfo(code: code, title: title, subtitle: subtitle)
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var result = [Element]()
        var set = Set<Element>()
        for item in self {
            if !set.contains(item) {
                result.append(item)
                set.insert(item)
            }
        }
        return result
    }
}
