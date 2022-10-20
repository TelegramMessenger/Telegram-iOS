import Foundation
import UIKit
import Display
import SwiftSignalKit
import ItemListUI
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListPeerActionItem
import NGStrings

private let quickReplyMaxLength = 4095

private final class QuickSettingsSettingsControllerArguments {
    let addNewPreset: () -> Void
    let updatePreset: (String, String) -> Void
    let deletePreset: (String) -> Void
    let presetFocusChanged: (String, Bool) -> Void
    
    init(addNewPreset: @escaping () -> Void, updatePreset: @escaping (String, String) -> Void, deletePreset: @escaping (String) -> Void, presetFocusChanged: @escaping (String, Bool) -> Void) {
        self.addNewPreset = addNewPreset
        self.updatePreset = updatePreset
        self.deletePreset = deletePreset
        self.presetFocusChanged = presetFocusChanged
    }
}

private enum QuickRepliesSection: Int32 {
    case replyPresets
}

private enum QuickRepliesControllerEntryTag: Equatable, ItemListItemTag {
    case preset(String)
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? QuickRepliesControllerEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum QuickRepliesControllerEntry: ItemListNodeEntry {
    case replyPresetsHeader(String)
    case addNewPreset(String)
    case replyPreset(String, String, String, Int)
    
    var section: ItemListSectionId {
        switch self {
            case .replyPresetsHeader, .addNewPreset, .replyPreset:
                return QuickRepliesSection.replyPresets.rawValue
        }
    }
    
    var stableId: String {
        switch self {
        case .replyPresetsHeader:
            return "replyPresetsHeader"
        case .addNewPreset:
            return "addNewPreset"
        case let .replyPreset(id, _, _, _):
            return "preset \(id)"
        }
    }
    
    var orderId: Int {
        switch self {
        case .replyPresetsHeader:
            return 0
        case .addNewPreset:
            return 1
        case let .replyPreset(_, _, _, index):
            return 100 + index
        }
    }
    
    static func ==(lhs: QuickRepliesControllerEntry, rhs: QuickRepliesControllerEntry) -> Bool {
        switch lhs {
            case let .replyPresetsHeader(lhsText):
                if case let .replyPresetsHeader(rhsText) = rhs, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addNewPreset(lhsText):
                if case let .addNewPreset(rhsText) = rhs, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .replyPreset(lhsIdentifier, lhsPlaceholder, lhsValue, _):
                if case let .replyPreset(rhsIdentifier, rhsPlaceholder, rhsValue, _) = rhs, lhsIdentifier == rhsIdentifier, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: QuickRepliesControllerEntry, rhs: QuickRepliesControllerEntry) -> Bool {
        return lhs.orderId < rhs.orderId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! QuickSettingsSettingsControllerArguments
        switch self {
            case let .replyPresetsHeader(text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .addNewPreset(text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .peerList, editing: false, action: {
                    arguments.addNewPreset()
                })
            case let .replyPreset(id, placeholder, value, _):
                return QuickReplyItem(
                    presentationData: presentationData,
                    id: id,
                    placeholder: placeholder,
                    value: value,
                    isSelected: nil,
                    maxLength: quickReplyMaxLength,
                    sectionId: self.section,
                    updated: { text, _ in
                        arguments.updatePreset(id, text)
                    }, delete: { _ in
                        arguments.deletePreset(id)
                    }, canDelete: true,
                    canMove: false,
                    focused: { isFocused in
                        arguments.presetFocusChanged(id, isFocused)
                    },
                    toggleSelected: { },
                    tag: QuickRepliesControllerEntryTag.preset(id)
                )
        }
    }
}

private struct QuickRepliesControllerState: Equatable {
    var items: [QuickReply]
    var focusPresetId: String?
}

private func quickRepliesControllerEntries(presentationData: PresentationData, state: QuickRepliesControllerState) -> [QuickRepliesControllerEntry] {
    let locale = presentationData.strings.baseLanguageCode
    
    var entries: [QuickRepliesControllerEntry] = []
    
    entries.append(.replyPresetsHeader(l("NiceFeatures.QuickReplies.Description", locale)))
    
    entries.append(.addNewPreset(l("NiceFeatures.QuickReplies.AddNew", locale)))
    
    let customPresets = state.items
    for (index, preset) in customPresets.enumerated() {
        entries.append(.replyPreset(preset.id, l("NiceFeatures.QuickReplies.Placeholder", locale), preset.text, index))
    }
    
    return entries
}

public func quickRepliesController(context: AccountContext) -> ViewController {
    let repository: QuickRepliesRepository = QuickRepliesRepositoryImpl()
    
    let addUseCase: AddQuickReplyUseCase = AddQuickReplyUseCaseImpl(
        accountContext: context,
        quickRepliesRepository: repository
    )
    let deleteUseCase: DeleteQuickReplyUseCase = DeleteQuickReplyUseCaseImpl(
        quickRepliesRepository: repository
    )
    let getUseCase: GetUserQuickRepliesUseCase = GetUserQuickRepliesUseCaseImpl(
        accountContext: context,
        quickRepliesRepository: repository
    )
    let updateUseCase: UpdateQuickReplyUseCase = UpdateQuickReplyUseCaseImpl(
        quickRepliesRepository: repository,
        addUseCase: addUseCase
    )
    
    let initialState = QuickRepliesControllerState(items: getUseCase.getQuickReplies())
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((QuickRepliesControllerState) -> QuickRepliesControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let updatePreset: (String, (QuickReply) -> QuickReply) -> Void = { id, f in
        updateState { state in
            var state = state
            guard let index = state.items.firstIndex(where: { $0.id == id }) else {
                return state
            }
            let oldItem = state.items[index]
            let updatedItem = f(oldItem)
            state.items[index] = updatedItem
            return state
        }
    }
    
    var ensurePresetVisibleImpl: ((String) -> Void)?
    
    let arguments = QuickSettingsSettingsControllerArguments(
        addNewPreset: {
            updateState { state in
                var state = state
                if let firstItem = state.items.first,
                   firstItem.text.isEmpty {
                } else {
                    let reply = QuickReply(id: UUID().uuidString, telegramUserId: context.account.peerId.id._internalGetInt64Value(), text: "", createdAt: Date(), updatedAt: Date())
                    state.items.insert(reply, at: 0)
                }
                return state
            }
        },
        updatePreset: {id, text in
            let updatedItem = updateUseCase.updateQuickReply(id: id, text: text)
            updatePreset(id) { _ in
                return updatedItem
            }
            ensurePresetVisibleImpl?(updatedItem.id)
        },
        deletePreset: { id in
            deleteUseCase.deleteQuickReply(id: id)
            updateState { state in
                var state = state
                if let index = state.items.firstIndex(where: { $0.id == id}) {
                    state.items.remove(at: index)
                }
                return state
            }
        },
        presetFocusChanged: { id, isFocused in
            updateState { state in
                var state = state
                state.focusPresetId = isFocused ? id : nil
                return state
            }
            if isFocused {
                ensurePresetVisibleImpl?(id)
            }
        }
    )
    
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let locale = presentationData.strings.baseLanguageCode
        
        let focusItemTag: ItemListItemTag?
        if let focusPresetId = state.focusPresetId {
            focusItemTag = QuickRepliesControllerEntryTag.preset(focusPresetId)
        } else {
            focusItemTag = nil
        }
        let ensureVisibleItemTag = focusItemTag
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(l("NiceFeatures.QuickReplies", locale)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: quickRepliesControllerEntries(presentationData: presentationData, state: state), style: .blocks, focusItemTag: focusItemTag, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    ensurePresetVisibleImpl = { [weak controller] id in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            if resultItemNode == nil {
                let _ = controller.frameForItemNode({ itemNode in
                    if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag {
                        if tag.isEqual(to: QuickRepliesControllerEntryTag.preset(id)) {
                            resultItemNode = itemNode as? ListViewItemNode
                            return true
                        }
                    }
                    return false
                })
            }
                
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode)
            }
        })
    }
    
    return controller
}

