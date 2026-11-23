import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import SupportTemplates
import ChatListUI

private final class SupportTemplateFileControllerArguments {
    let updateState: ((SupportTemplateFileState) -> SupportTemplateFileState) -> Void

    init(updateState: @escaping ((SupportTemplateFileState) -> SupportTemplateFileState) -> Void) {
        self.updateState = updateState
    }
}

private struct SupportTemplateFileState: Equatable {
    var name: String
    var url: String
    var isSaving: Bool
}

private enum SupportTemplateFileSection: Int32 {
    case name
    case url
}

private enum SupportTemplateFileEntry: ItemListNodeEntry {
    case nameHeader
    case name(String, isEnabled: Bool)
    case nameInfo
    case urlHeader
    case url(String, isEnabled: Bool)
    case urlInfo

    var section: ItemListSectionId {
        switch self {
        case .nameHeader, .name, .nameInfo:
            return SupportTemplateFileSection.name.rawValue
        case .urlHeader, .url, .urlInfo:
            return SupportTemplateFileSection.url.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .nameHeader:
            return 0
        case .name:
            return 1
        case .nameInfo:
            return 2
        case .urlHeader:
            return 3
        case .url:
            return 4
        case .urlInfo:
            return 5
        }
    }

    static func <(lhs: SupportTemplateFileEntry, rhs: SupportTemplateFileEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportTemplateFileControllerArguments
        switch self {
        case .nameHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Support_Templates_FileNameHeader, sectionId: self.section)
        case let .name(text, isEnabled):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "tl_name.txt", type: .regular(capitalization: false, autocorrection: false), clearType: .onFocus, enabled: isEnabled, sectionId: self.section, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.name = value
                    return state
                }
            }, action: {
            })
        case .nameInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(presentationData.strings.Support_Templates_FileNameInfo), sectionId: self.section)
        case .urlHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Support_Templates_FileUrlHeader, sectionId: self.section)
        case let .url(text, isEnabled):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "https://", type: .regular(capitalization: false, autocorrection: false), clearType: .onFocus, enabled: isEnabled, sectionId: self.section, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.url = value
                    return state
                }
            }, action: {
            })
        case .urlInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(presentationData.strings.Support_Templates_FileUrlInfo), sectionId: self.section)
        }
    }
}

private func supportTemplateFileEntries(state: SupportTemplateFileState) -> [SupportTemplateFileEntry] {
    return [
        .nameHeader,
        .name(state.name, isEnabled: !state.isSaving),
        .nameInfo,
        .urlHeader,
        .url(state.url, isEnabled: !state.isSaving),
        .urlInfo
    ]
}

func supportTemplateFileController(context: AccountContext, manager: SupportTemplatesManager, name: String, url: String, changed: @escaping (String) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let initialState = SupportTemplateFileState(name: name, url: url, isSaving: false)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SupportTemplateFileState) -> SupportTemplateFileState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let arguments = SupportTemplateFileControllerArguments(updateState: updateState)

    let save: () -> Void = {
        let state = stateValue.with { $0 }
        if state.isSaving {
            return
        }
        let newName = supportTemplatesFileNameNormalized(state.name)
        let newUrl = state.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if newName == name && newUrl == url {
            dismissImpl?()
            return
        }
        updateState { state in
            var state = state
            state.isSaving = true
            return state
        }
        manager.changeFile(name: name, newName: newName, url: newUrl, completion: { result in
            updateState { state in
                var state = state
                state.isSaving = false
                return state
            }
            switch result {
            case .success:
                changed(newName)
                dismissImpl?()
            case let .failure(error):
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Support_Templates_FileErrorTitle, text: supportTemplatesFileChangeErrorText(error, presentationData: presentationData), actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                })]))
            }
        })
    }

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightButton: ItemListNavigationButton
        if state.isSaving {
            rightButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {
            })
        } else {
            rightButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: {
                save()
            })
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Support_Templates_FileTitle), leftNavigationButton: leftButton, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportTemplateFileEntries(state: state), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.navigationController?.popViewController(animated: true)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
