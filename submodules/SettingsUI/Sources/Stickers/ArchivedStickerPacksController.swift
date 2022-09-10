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
import OverlayStatusController
import AccountContext
import StickerPackPreviewUI
import ItemListStickerPackItem
import UndoUI

public enum ArchivedStickerPacksControllerMode {
    case stickers
    case masks
    case emoji
}

private final class ArchivedStickerPacksControllerArguments {
    let account: Account
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let addPack: (StickerPackCollectionInfo) -> Void
    let removePack: (StickerPackCollectionInfo) -> Void
    
    init(account: Account, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, addPack: @escaping (StickerPackCollectionInfo) -> Void, removePack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.account = account
        self.openStickerPack = openStickerPack
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.addPack = addPack
        self.removePack = removePack
    }
}

private enum ArchivedStickerPacksSection: Int32 {
    case stickers
}

private enum ArchivedStickerPacksEntryId: Hashable {
    case index(Int32)
    case pack(ItemCollectionId)
}

private enum ArchivedStickerPacksEntry: ItemListNodeEntry {
    case info(PresentationTheme, String)
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, Bool, ItemListStickerPackItemEditing)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .pack:
                return ArchivedStickerPacksSection.stickers.rawValue
        }
    }
    
    var stableId: ArchivedStickerPacksEntryId {
        switch self {
            case .info:
                return .index(0)
            case let .pack(_, _, _, info, _, _, _, _, _):
                return .pack(info.id)
        }
    }
    
    static func ==(lhs: ArchivedStickerPacksEntry, rhs: ArchivedStickerPacksEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsText):
                if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .pack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsTopItem, lhsCount, lhsPlayAnimatedStickers, lhsEnabled, lhsEditing):
                if case let .pack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsTopItem, rhsCount, rhsPlayAnimatedStickers, rhsEnabled, rhsEditing) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsInfo != rhsInfo {
                        return false
                    }
                    if lhsTopItem != rhsTopItem {
                        return false
                    }
                    if lhsCount != rhsCount {
                        return false
                    }
                    if lhsPlayAnimatedStickers != rhsPlayAnimatedStickers {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ArchivedStickerPacksEntry, rhs: ArchivedStickerPacksEntry) -> Bool {
        switch lhs {
            case .info:
                switch rhs {
                    case .info:
                        return false
                    default:
                        return true
                }
            case let .pack(lhsIndex, _, _, _, _, _, _, _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return false
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ArchivedStickerPacksControllerArguments
        switch self {
            case let .info(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .pack(_, _, _, info, topItem, count, animatedStickers, enabled, editing):
                return ItemListStickerPackItem(presentationData: presentationData, account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: false, control: .installation(installed: false), editing: editing, enabled: enabled, playAnimatedStickers: animatedStickers, sectionId: self.section, action: {
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { current, previous in
                    arguments.setPackIdWithRevealedOptions(current, previous)
                }, addPack: {
                    arguments.addPack(info)
                }, removePack: {
                    arguments.removePack(info)
                }, toggleSelected: {
                })
        }
    }
}

private struct ArchivedStickerPacksControllerState: Equatable {
    let editing: Bool
    let packIdWithRevealedOptions: ItemCollectionId?
    let removingPackIds: Set<ItemCollectionId>
    
    init() {
        self.editing = false
        self.packIdWithRevealedOptions = nil
        self.removingPackIds = Set()
    }
    
    init(editing: Bool, packIdWithRevealedOptions: ItemCollectionId?, removingPackIds: Set<ItemCollectionId>) {
        self.editing = editing
        self.packIdWithRevealedOptions = packIdWithRevealedOptions
        self.removingPackIds = removingPackIds
    }
    
    static func ==(lhs: ArchivedStickerPacksControllerState, rhs: ArchivedStickerPacksControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.packIdWithRevealedOptions != rhs.packIdWithRevealedOptions {
            return false
        }
        if lhs.removingPackIds != rhs.removingPackIds {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: editing, packIdWithRevealedOptions: self.packIdWithRevealedOptions, removingPackIds: self.removingPackIds)
    }
    
    func withUpdatedPackIdWithRevealedOptions(_ packIdWithRevealedOptions: ItemCollectionId?) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: self.editing, packIdWithRevealedOptions: packIdWithRevealedOptions, removingPackIds: self.removingPackIds)
    }
    
    func withUpdatedRemovingPackIds(_ removingPackIds: Set<ItemCollectionId>) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: editing, packIdWithRevealedOptions: self.self.packIdWithRevealedOptions, removingPackIds: removingPackIds)
    }
}

private func archivedStickerPacksControllerEntries(presentationData: PresentationData, state: ArchivedStickerPacksControllerState, packs: [ArchivedStickerPackItem]?, installedView: CombinedView, stickerSettings: StickerSettings) -> [ArchivedStickerPacksEntry] {
    var entries: [ArchivedStickerPacksEntry] = []
    
    if let packs = packs {
        entries.append(.info(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedPacks_Info + "\n\n"))
        
        var installedIds = Set<ItemCollectionId>()
        if let view = installedView.views[.itemCollectionIds(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionIdsView, let ids = view.idsByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            installedIds = ids
        }
        
        var index: Int32 = 0
        for item in packs {
            if !installedIds.contains(item.info.id) {
                let countTitle: String
                if item.info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                    countTitle = presentationData.strings.StickerPack_EmojiCount(item.info.count)
                } else if item.info.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
                    countTitle = presentationData.strings.StickerPack_MaskCount(item.info.count)
                } else {
                    countTitle = presentationData.strings.StickerPack_StickerCount(item.info.count)
                }
                
                entries.append(.pack(index, presentationData.theme, presentationData.strings, item.info, item.topItems.first, countTitle, stickerSettings.loopAnimatedStickers, !state.removingPackIds.contains(item.info.id), ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == item.info.id, reorderable: false, selectable: true)))
                index += 1
            }
        }
    }
    
    return entries
}

public func archivedStickerPacksController(context: AccountContext, mode: ArchivedStickerPacksControllerMode, archived: [ArchivedStickerPackItem]?, updatedPacks: @escaping ([ArchivedStickerPackItem]?) -> Void) -> ViewController {
    let statePromise = ValuePromise(ArchivedStickerPacksControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ArchivedStickerPacksControllerState())
    let updateState: ((ArchivedStickerPacksControllerState) -> ArchivedStickerPacksControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var navigationControllerImpl: (() -> NavigationController?)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    let removePackDisposables = DisposableDict<ItemCollectionId>()
    actionsDisposable.add(removePackDisposables)
    
    let namespace: ArchivedStickerPacksNamespace
    switch mode {
        case .stickers:
            namespace = .stickers
        case .emoji:
            namespace = .emoji
        case .masks:
            namespace = .masks
    }
    let stickerPacks = Promise<[ArchivedStickerPackItem]?>()
    stickerPacks.set(.single(archived) |> then(context.engine.stickers.archivedStickerPacks(namespace: namespace) |> map(Optional.init)))
    
    actionsDisposable.add(stickerPacks.get().start(next: { packs in
        updatedPacks(packs)
    }))
    
    let installedStickerPacks = Promise<CombinedView>()
    installedStickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionIds(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]))
    
    var presentStickerPackController: ((StickerPackCollectionInfo) -> Void)?
    
    let arguments = ArchivedStickerPacksControllerArguments(account: context.account, openStickerPack: { info in
        presentStickerPackController?(info)
    }, setPackIdWithRevealedOptions: { packId, fromPackId in
        updateState { state in
            if (packId == nil && fromPackId == state.packIdWithRevealedOptions) || (packId != nil && fromPackId == nil) {
                return state.withUpdatedPackIdWithRevealedOptions(packId)
            } else {
                return state
            }
        }
    }, addPack: { info in
        var add = false
        updateState { state in
            var removingPackIds = state.removingPackIds
            if !removingPackIds.contains(info.id) {
                removingPackIds.insert(info.id)
                add = true
            }
            return state.withUpdatedRemovingPackIds(removingPackIds)
        }
        if !add {
            return
        }
        let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
        |> mapToSignal { result -> Signal<(StickerPackCollectionInfo, [StickerPackItem]), NoError> in
            switch result {
            case let .result(info, items, installed):
                if installed {
                    return .complete()
                } else {
                    return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
                        |> ignoreValues
                        |> mapToSignal { _ -> Signal<(StickerPackCollectionInfo, [StickerPackItem]), NoError> in
                        }
                        |> then(.single((info, items)))
                }
            case .fetching:
                break
            case .none:
                break
            }
            return .complete()
        }
        |> deliverOnMainQueue).start(next: { info, items in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var animateInAsReplacement = false
            if let navigationController = navigationControllerImpl?() {
                for controller in navigationController.overlayControllers {
                    if let controller = controller as? UndoOverlayController {
                        controller.dismissWithCommitActionAndReplacementAnimation()
                        animateInAsReplacement = true
                    }
                }
            }
            
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in
                return true
            }), nil)
            
            let applyPacks: Signal<Void, NoError> = stickerPacks.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { packs -> Signal<Void, NoError> in
                if let packs = packs {
                    var updatedPacks = packs
                    for i in 0 ..< updatedPacks.count {
                        if updatedPacks[i].info.id == info.id {
                            updatedPacks.remove(at: i)
                            break
                        }
                    }
                    stickerPacks.set(.single(updatedPacks))
                }
                
                return .complete()
            }
            
            let _ = applyPacks.start()
        })
    }, removePack: { info in
        var remove = false
        updateState { state in
            var removingPackIds = state.removingPackIds
            if !removingPackIds.contains(info.id) {
                removingPackIds.insert(info.id)
                remove = true
            }
            return state.withUpdatedRemovingPackIds(removingPackIds)
        }
        if remove {
            let applyPacks: Signal<Void, NoError> = stickerPacks.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { packs -> Signal<Void, NoError> in
                    if let packs = packs {
                        var updatedPacks = packs
                        for i in 0 ..< updatedPacks.count {
                            if updatedPacks[i].info.id == info.id {
                                updatedPacks.remove(at: i)
                                break
                            }
                        }
                        stickerPacks.set(.single(updatedPacks))
                    }
                    
                    return .complete()
            }
            removePackDisposables.set((context.engine.stickers.removeArchivedStickerPack(info: info) |> then(applyPacks) |> deliverOnMainQueue).start(completed: {
                updateState { state in
                    var removingPackIds = state.removingPackIds
                    removingPackIds.remove(info.id)
                    return state.withUpdatedRemovingPackIds(removingPackIds)
                }
            }), forKey: info.id)
        }
    })
    
    var previousPackCount: Int?
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, installedStickerPacks.get() |> deliverOnMainQueue, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]) |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, packs, installedView, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
                stickerSettings = value
            }
            
            var rightNavigationButton: ItemListNavigationButton?
            if let packs = packs, packs.count != 0 {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(false)
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            let previous = previousPackCount
            previousPackCount = packs?.count
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if packs == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.StickerPacksSettings_ArchivedPacks), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
            
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: archivedStickerPacksControllerEntries(presentationData: presentationData, state: state, packs: packs, installedView: installedView, stickerSettings: stickerSettings), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && packs != nil && (previous! != 0 && previous! >= packs!.count - 10))
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    navigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    presentStickerPackController = { [weak controller] info in
        let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
        presentControllerImpl?(StickerPackScreen(context: context, mode: .settings, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controller?.navigationController as? NavigationController), nil)
    }
    
    return controller
}
