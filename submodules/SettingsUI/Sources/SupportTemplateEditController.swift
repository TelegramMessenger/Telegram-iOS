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

enum SupportTemplateEditTarget {
    case newOwn
    case own(SupportOwnTemplate)
    case file(name: String, entry: SupportTemplatesListEntry)
}

private final class SupportTemplateEditControllerArguments {
    let context: AccountContext
    let updateState: ((SupportTemplateEditState) -> SupportTemplateEditState) -> Void
    let restoreDefault: () -> Void
    let delete: () -> Void

    init(context: AccountContext, updateState: @escaping ((SupportTemplateEditState) -> SupportTemplateEditState) -> Void, restoreDefault: @escaping () -> Void, delete: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.restoreDefault = restoreDefault
        self.delete = delete
    }
}

private struct SupportTemplateEditState: Equatable {
    var question: String
    var keys: [String]
    var pendingKey: String
    var value: String

    var keyList: [String] {
        let pending = self.pendingKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if pending.isEmpty {
            return self.keys
        }
        return supportTemplateKeysAdding(pending, to: self.keys)
    }

    var canSave: Bool {
        let hasQuestion = !self.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValue = !supportTemplatesValueDroppingTrailingNewlines(self.value).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasValue && (hasQuestion || !self.keyList.isEmpty)
    }
}

private enum SupportTemplateEditSection: Int32 {
    case question
    case keys
    case value
    case actions
}

private enum SupportTemplateEditEntry: ItemListNodeEntry {
    case questionHeader
    case question(String)
    case keysHeader
    case keys([String])
    case keysInfo
    case valueHeader
    case value(String)
    case valueInfo(String)
    case restoreDefault
    case delete

    var section: ItemListSectionId {
        switch self {
        case .questionHeader, .question:
            return SupportTemplateEditSection.question.rawValue
        case .keysHeader, .keys, .keysInfo:
            return SupportTemplateEditSection.keys.rawValue
        case .valueHeader, .value, .valueInfo:
            return SupportTemplateEditSection.value.rawValue
        case .restoreDefault, .delete:
            return SupportTemplateEditSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .questionHeader:
            return 0
        case .question:
            return 1
        case .keysHeader:
            return 2
        case .keys:
            return 3
        case .keysInfo:
            return 4
        case .valueHeader:
            return 5
        case .value:
            return 6
        case .valueInfo:
            return 7
        case .restoreDefault:
            return 8
        case .delete:
            return 9
        }
    }

    static func <(lhs: SupportTemplateEditEntry, rhs: SupportTemplateEditEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportTemplateEditControllerArguments
        switch self {
        case .questionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Support_Templates_QuestionHeader, sectionId: self.section)
        case let .question(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: presentationData.strings.Support_Templates_QuestionPlaceholder, sectionId: self.section, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.question = value
                    return state
                }
            }, action: {
            })
        case .keysHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Support_Templates_KeysHeader, sectionId: self.section)
        case let .keys(keys):
            return SupportTemplateKeysItem(context: arguments.context, presentationData: presentationData, keys: keys, sectionId: self.section, addKey: { key in
                arguments.updateState { state in
                    var state = state
                    state.keys = supportTemplateKeysAdding(key, to: state.keys)
                    state.pendingKey = ""
                    return state
                }
            }, removeKey: { key in
                arguments.updateState { state in
                    var state = state
                    state.keys.removeAll(where: { $0 == key })
                    return state
                }
            }, pendingTextUpdated: { text in
                arguments.updateState { state in
                    var state = state
                    state.pendingKey = text
                    return state
                }
            })
        case .keysInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(presentationData.strings.Support_Templates_KeysInfo), sectionId: self.section)
        case .valueHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Support_Templates_AnswerHeader, sectionId: self.section)
        case let .value(text):
            return ItemListMultilineInputItem(presentationData: presentationData, systemStyle: .glass, text: text, placeholder: presentationData.strings.Support_Templates_AnswerPlaceholder, maxLength: nil, sectionId: self.section, style: .blocks, minimalHeight: 120.0, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.value = value
                    return state
                }
            })
        case let .valueInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .restoreDefault:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Templates_RestoreDefault, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.restoreDefault()
            })
        case .delete:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Templates_Delete, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.delete()
            })
        }
    }
}

private func supportTemplateEditEntries(strings: PresentationStrings, target: SupportTemplateEditTarget, state: SupportTemplateEditState) -> [SupportTemplateEditEntry] {
    var result: [SupportTemplateEditEntry] = [
        .questionHeader,
        .question(state.question),
        .keysHeader,
        .keys(state.keys),
        .keysInfo,
        .valueHeader,
        .value(state.value)
    ]
    switch target {
    case .newOwn:
        break
    case .own:
        result.append(.delete)
    case let .file(name, entry):
        switch entry.status {
        case .original:
            result.append(.valueInfo(strings.Support_Templates_FromFileInfo.replacingOccurrences(of: "{name}", with: name)))
            result.append(.delete)
        case .edited:
            result.append(.valueInfo(strings.Support_Templates_EditedInfo.replacingOccurrences(of: "{name}", with: name)))
            result.append(.restoreDefault)
            result.append(.delete)
        case .removed:
            result.append(.valueInfo(strings.Support_Templates_DeletedInfo.replacingOccurrences(of: "{name}", with: name)))
            result.append(.restoreDefault)
        }
    }
    return result
}

private func supportTemplateKeysAdding(_ key: String, to keys: [String]) -> [String] {
    let normalized = supportTemplatesNormalizedKey(key)
    if normalized.isEmpty || keys.contains(where: { supportTemplatesNormalizedKey($0) == normalized }) {
        return keys
    }
    return keys + [key]
}

private func supportTemplateKeysDeduplicated(_ keys: [String]) -> [String] {
    return keys.reduce(into: [String]()) { result, key in
        result = supportTemplateKeysAdding(key, to: result)
    }
}

private func supportTemplateEditInitialState(_ target: SupportTemplateEditTarget) -> SupportTemplateEditState {
    switch target {
    case .newOwn:
        return SupportTemplateEditState(question: "", keys: [], pendingKey: "", value: "")
    case let .own(template):
        return SupportTemplateEditState(question: template.question, keys: supportTemplateKeysDeduplicated(template.keys), pendingKey: "", value: template.value)
    case let .file(_, entry):
        return SupportTemplateEditState(question: entry.template.question, keys: supportTemplateKeysDeduplicated(entry.template.originalKeys), pendingKey: "", value: entry.template.value)
    }
}

func supportTemplateEditController(context: AccountContext, manager: SupportTemplatesManager, target: SupportTemplateEditTarget) -> ViewController {
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let initialState = supportTemplateEditInitialState(target)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SupportTemplateEditState) -> SupportTemplateEditState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let arguments = SupportTemplateEditControllerArguments(context: context, updateState: updateState, restoreDefault: {
        if case let .file(name, entry) = target {
            manager.setEdit(file: name, id: entry.id, edit: nil)
        }
        dismissImpl?()
    }, delete: {
        switch target {
        case .newOwn:
            dismissImpl?()
        case let .own(template):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Support_Templates_DeleteConfirm, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            }), TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                manager.removeOwnTemplate(id: template.id)
                dismissImpl?()
            })]))
        case let .file(name, entry):
            manager.setEdit(file: name, id: entry.id, edit: .removal)
            dismissImpl?()
        }
    })

    let save: () -> Void = {
        let state = stateValue.with { $0 }
        guard state.canSave else {
            return
        }
        switch target {
        case .newOwn:
            manager.saveOwnTemplate(SupportOwnTemplate(question: state.question, keys: state.keyList, value: state.value))
        case let .own(template):
            manager.saveOwnTemplate(SupportOwnTemplate(id: template.id, question: state.question, keys: state.keyList, value: state.value))
        case let .file(name, entry):
            if let original = entry.original {
                manager.setEdit(file: name, id: entry.id, edit: SupportTemplateEdit(original: original, question: state.question, keys: state.keyList, value: state.value))
            }
        }
        dismissImpl?()
    }

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let title: String
        switch target {
        case .newOwn:
            title = presentationData.strings.Support_Templates_NewTitle
        case .own, .file:
            title = presentationData.strings.Support_Templates_EditTitle
        }
        let leftButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.canSave, action: {
            save()
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftButton, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportTemplateEditEntries(strings: presentationData.strings, target: target, state: state), style: .blocks, animateChanges: false)
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
