import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import StickerPackPreviewUI
import ItemListStickerPackItem

private final class FeaturedStickerPacksControllerArguments {
    let context: AccountContext
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let addPack: (StickerPackCollectionInfo) -> Void
    
    init(context: AccountContext, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, addPack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.context = context
        self.openStickerPack = openStickerPack
        self.addPack = addPack
    }
}

private enum FeaturedStickerPacksSection: Int32 {
    case stickers
}

private enum FeaturedStickerPacksEntryId: Hashable {
    case pack(EngineItemCollectionId)
}

private enum FeaturedStickerPacksEntry: ItemListNodeEntry {
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo.Accessor, Bool, StickerPackItem?, String, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .pack:
                return FeaturedStickerPacksSection.stickers.rawValue
        }
    }
    
    var stableId: FeaturedStickerPacksEntryId {
        switch self {
            case let .pack(_, _, _, info, _, _, _, _, _):
                return .pack(info.id)
        }
    }
    
    static func ==(lhs: FeaturedStickerPacksEntry, rhs: FeaturedStickerPacksEntry) -> Bool {
        switch lhs {
            case let .pack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsUnread, lhsTopItem, lhsCount, lhsPlayAnimatedStickers, lhsInstalled):
                if case let .pack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsUnread, rhsTopItem, rhsCount, rhsPlayAnimatedStickers, rhsInstalled) = rhs {
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
                    if lhsUnread != rhsUnread {
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
                    if lhsInstalled != rhsInstalled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: FeaturedStickerPacksEntry, rhs: FeaturedStickerPacksEntry) -> Bool {
        switch lhs {
            case let .pack(lhsIndex, _, _, _, _, _, _,  _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FeaturedStickerPacksControllerArguments
        switch self {
            case let .pack(_, _, _, info, unread, topItem, count, playAnimatedStickers, installed):
                return ItemListStickerPackItem(presentationData: presentationData, context: arguments.context, packInfo: info, itemCount: count, topItem: topItem, unread: unread, control: .installation(installed: installed), editing: ItemListStickerPackItemEditing(editable: false, editing: false, revealed: false, reorderable: false, selectable: false), enabled: true, playAnimatedStickers: playAnimatedStickers, sectionId: self.section, action: {
                    arguments.openStickerPack(info._parse())
                }, setPackIdWithRevealedOptions: { _, _ in
                }, addPack: {
                    arguments.addPack(info._parse())
                }, removePack: {
                }, toggleSelected: {
                })
        }
    }
}

private struct FeaturedStickerPacksControllerState: Equatable {
    init() {
    }
    
    static func ==(lhs: FeaturedStickerPacksControllerState, rhs: FeaturedStickerPacksControllerState) -> Bool {
        return true
    }
}

private func featuredStickerPacksControllerEntries(context: AccountContext, presentationData: PresentationData, state: FeaturedStickerPacksControllerState, view: [EngineRawItemCollectionInfoEntry], featured: [FeaturedStickerPackItem], unreadPacks: [EngineItemCollectionId: Bool], stickerSettings: StickerSettings)  -> [FeaturedStickerPacksEntry] {
    var entries: [FeaturedStickerPacksEntry] = []

    if !featured.isEmpty {
        var installedPacks = Set<EngineItemCollectionId>()
        for entry in view {
            installedPacks.insert(entry.id)
        }
        var index: Int32 = 0
        for item in featured {
            var unread = false
            if let value = unreadPacks[item.info.id] {
                unread = value
            }

            let countTitle: String
            if item.info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                countTitle = presentationData.strings.StickerPack_EmojiCount(item.info.count)
            } else if item.info.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
                countTitle = presentationData.strings.StickerPack_MaskCount(item.info.count)
            } else {
                countTitle = presentationData.strings.StickerPack_StickerCount(item.info.count)
            }

            entries.append(.pack(index, presentationData.theme, presentationData.strings, item.info, unread, item.topItems.first, countTitle, context.sharedContext.energyUsageSettings.loopStickers, installedPacks.contains(item.info.id)))
            index += 1
        }
    }

    return entries
}

public func featuredStickerPacksController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(FeaturedStickerPacksControllerState(), ignoreRepeated: true)
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    var presentStickerPackController: ((StickerPackCollectionInfo) -> Void)?
    
    let arguments = FeaturedStickerPacksControllerArguments(context: context, openStickerPack: { info in
        presentStickerPackController?(info)
    }, addPack: { info in
        let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
        |> mapToSignal { result -> Signal<AddStickerPackResult, NoError> in
            switch result {
                case let .result(info, items, installed):
                    if installed {
                        return .complete()
                    } else {
                        return context.engine.stickers.addStickerPackInteractively(info: info._parse(), items: items)
                    }
                case .fetching:
                    break
                case .none:
                    break
            }
            return .complete()
        } |> deliverOnMainQueue).startStandalone()
    })
    
    actionsDisposable.add((context.account.stateManager.installedStickerPacksArchivedEvents
    |> deliverOnMainQueue).startStandalone(next: { count in
       if count == 0 {
           return
       }
        let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
        presentControllerImpl?(textAlertController(context: context, updatedPresentationData: nil, title: nil, text: presentationData.strings.ArchivedPacksAlert_Title, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
    }))
    
    let stickerPacks = Promise<[EngineRawItemCollectionInfoEntry]>()
    stickerPacks.set(context.engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCollections.InstalledPackInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks)))
    
    let featured = Promise<[FeaturedStickerPackItem]>()
    featured.set(context.account.viewTracker.featuredStickerPacks())

    var initialUnreadPacks: [EngineItemCollectionId: Bool] = [:]
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, featured.get() |> deliverOnMainQueue, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]) |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, view, featured, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
                stickerSettings = value
            }
            
            for item in featured {
                if initialUnreadPacks[item.info.id] == nil {
                    initialUnreadPacks[item.info.id] = item.unread
                }
            }
            
            let rightNavigationButton: ItemListNavigationButton? = nil
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.FeaturedStickerPacks_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
            
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: featuredStickerPacksControllerEntries(context: context, presentationData: presentationData, state: state, view: view, featured: featured, unreadPacks: initialUnreadPacks, stickerSettings: stickerSettings), style: .blocks, animateChanges: false)
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    var alreadyReadIds = Set<EngineItemCollectionId>()
    
    controller.visibleEntriesUpdated = { entries in
        var unreadIds: [EngineItemCollectionId] = []
        for entry in entries {
            if let entry = entry as? FeaturedStickerPacksEntry {
                switch entry {
                    case let .pack(_, _, _, info, unread, _, _, _, _):
                        if unread && !alreadyReadIds.contains(info.id) {
                            unreadIds.append(info.id)
                        }
                }
            }
        }
        if !unreadIds.isEmpty {
            alreadyReadIds.formUnion(Set(unreadIds))
            
            let _ = context.engine.stickers.markFeaturedStickerPacksAsSeenInteractively(ids: unreadIds).start()
        }
    }
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    presentStickerPackController = { [weak controller] info in
        let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
        presentControllerImpl?(StickerPackScreen(context: context, mode: .settings, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controller?.navigationController as? NavigationController), nil)
    }
    
    return controller
}
