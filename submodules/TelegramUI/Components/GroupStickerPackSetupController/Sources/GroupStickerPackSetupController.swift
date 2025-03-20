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
import AccountContext
import StickerPackPreviewUI
import ItemListStickerPackItem
import UndoUI

private final class GroupStickerPackSetupControllerArguments {
    let context: AccountContext
    
    let selectStickerPack: (StickerPackCollectionInfo) -> Void
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let updateSearchText: (String) -> Void
    let openStickersBot: () -> Void
    
    init(context: AccountContext, selectStickerPack: @escaping (StickerPackCollectionInfo) -> Void, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, updateSearchText: @escaping (String) -> Void, openStickersBot: @escaping () -> Void) {
        self.context = context
        self.selectStickerPack = selectStickerPack
        self.openStickerPack = openStickerPack
        self.updateSearchText = updateSearchText
        self.openStickersBot = openStickersBot
    }
}

private enum GroupStickerPackSection: Int32 {
    case search
    case stickers
}

private enum GroupStickerPackEntryId: Hashable {
    case index(Int32)
    case pack(ItemCollectionId)
    
    static func ==(lhs: GroupStickerPackEntryId, rhs: GroupStickerPackEntryId) -> Bool {
        switch lhs {
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
            case let .pack(id):
                if case .pack(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum GroupStickerPackEntry: ItemListNodeEntry {
    case search(PresentationTheme, PresentationStrings, String, String, String)
    case currentPack(Int32, PresentationTheme, PresentationStrings, GroupStickerPackCurrentItemContent)
    case searchInfo(PresentationTheme, String)
    case packsTitle(PresentationTheme, String)
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .search, .currentPack, .searchInfo:
                return GroupStickerPackSection.search.rawValue
            case .packsTitle, .pack:
                return GroupStickerPackSection.stickers.rawValue
        }
    }
    
    var stableId: GroupStickerPackEntryId {
        switch self {
            case .search:
                return .index(0)
            case .currentPack:
                return .index(1)
            case .searchInfo:
                return .index(2)
            case .packsTitle:
                return .index(3)
            case let .pack(_, _, _, info, _, _, _, _):
                return .pack(info.id)
        }
    }
    
    static func ==(lhs: GroupStickerPackEntry, rhs: GroupStickerPackEntry) -> Bool {
        switch lhs {
        case let .search(lhsTheme, lhsStrings, lhsPrefix, lhsPlaceholder, lhsValue):
            if case let .search(rhsTheme, rhsStrings, rhsPrefix, rhsPlaceholder, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPrefix == rhsPrefix, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .searchInfo(lhsTheme, lhsText):
            if case let .searchInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .packsTitle(lhsTheme, lhsText):
            if case let .packsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .currentPack(lhsIndex, lhsTheme, lhsStrings, lhsContent):
            if case let .currentPack(rhsIndex, rhsTheme, rhsStrings, rhsContent) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsTheme !== rhsTheme {
                    return false
                }
                if lhsStrings !== rhsStrings {
                    return false
                }
                if lhsContent != rhsContent {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .pack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsTopItem, lhsCount, lhsPlayAnimatedStickers, lhsSelected):
            if case let .pack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsTopItem, rhsCount, rhsPlayAnimatedStickers, rhsSelected) = rhs {
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
                if lhsSelected != rhsSelected {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: GroupStickerPackEntry, rhs: GroupStickerPackEntry) -> Bool {
        switch lhs {
            case .search:
                switch rhs {
                    case .search:
                        return false
                    default:
                        return true
                }
            case .currentPack:
                switch rhs {
                    case .search, .currentPack:
                        return false
                    default:
                        return true
                }
            case .searchInfo:
                switch rhs {
                    case .search, .currentPack, .searchInfo:
                        return false
                    default:
                        return true
                }
            case .packsTitle:
                switch rhs {
                    case .search, .currentPack, .searchInfo, .packsTitle:
                        return false
                    default:
                        return true
                }
            case let .pack(lhsIndex, _, _, _, _, _, _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return false
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GroupStickerPackSetupControllerArguments
        switch self {
            case let .search(theme, _, prefix, placeholder, value):
                let isEmoji = prefix.contains("addemoji")
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: prefix, textColor: theme.list.itemPrimaryTextColor), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .none, tag: nil, sectionId: self.section, textUpdated: { value in
                    arguments.updateSearchText(value)
                }, processPaste: { text in
                    if let url = (URL(string: text) ?? URL(string: "http://" + text)), url.host == "t.me" || url.host == "telegram.me" {
                        let prefix = isEmoji ? "/addemoji/" : "/addstickers/"
                        if url.path.hasPrefix(prefix) {
                            return String(url.path[url.path.index(url.path.startIndex, offsetBy: prefix.count)...])
                        }
                    }
                    return text
                }, action: {})
            case let .searchInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, linkAction: nil)
            case let .packsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .pack(_, _, _, info, topItem, count, playAnimatedStickers, selected):
                return ItemListStickerPackItem(presentationData: presentationData, context: arguments.context, packInfo: StickerPackCollectionInfo.Accessor(info), itemCount: count, topItem: topItem, unread: false, control: selected ? .selection : .none, editing: ItemListStickerPackItemEditing(editable: false, editing: false, revealed: false, reorderable: false, selectable: false), enabled: true, playAnimatedStickers: playAnimatedStickers, sectionId: self.section, action: {
                    if selected {
                        arguments.openStickerPack(info)
                    } else {
                        arguments.selectStickerPack(info)
                    }
                }, setPackIdWithRevealedOptions: { _, _ in
                }, addPack: {
                }, removePack: {
                }, toggleSelected: {
                })
            case let .currentPack(_, theme, strings, content):
                return GroupStickerPackCurrentItem(theme: theme, strings: strings, account: arguments.context.account, content: content, sectionId: self.section, action: {
                    if case let .found(packInfo, _, _) = content {
                        arguments.openStickerPack(packInfo)
                    }
                }, remove: {
                    arguments.updateSearchText("")
                })
        }
    }
}

private struct StickerPackData: Equatable {
    let info: StickerPackCollectionInfo
    let item: StickerPackItem?
}

private enum InitialStickerPackData {
    case noData
    case data(StickerPackData)
}

private enum GroupStickerPackSearchState: Equatable {
    case none
    case found(StickerPackData)
    case notFound
    case searching
}

private struct GroupStickerPackSetupControllerState: Equatable {
    var isSaving: Bool
    var searchingPacks: Bool
}

private func groupStickerPackSetupControllerEntries(context: AccountContext, presentationData: PresentationData, searchText: String, view: CombinedView, initialData: InitialStickerPackData?, searchState: GroupStickerPackSearchState, stickerSettings: StickerSettings, isEmoji: Bool) -> [GroupStickerPackEntry] {
    if initialData == nil {
        return []
    }
    var entries: [GroupStickerPackEntry] = []
    
    entries.append(.search(presentationData.theme, presentationData.strings, isEmoji ? "t.me/addemoji/" : "t.me/addstickers/", isEmoji ? "emojiset" : presentationData.strings.Channel_Stickers_Placeholder, searchText))
    switch searchState {
        case .none:
            break
        case .notFound:
            entries.append(.currentPack(0, presentationData.theme, presentationData.strings, .notFound(isEmoji: isEmoji)))
        case .searching:
            entries.append(.currentPack(0, presentationData.theme, presentationData.strings, .searching))
        case let .found(data):
            entries.append(.currentPack(0, presentationData.theme, presentationData.strings, .found(packInfo: data.info, topItem: data.item, subtitle: isEmoji ? presentationData.strings.StickerPack_EmojiCount(data.info.count) : presentationData.strings.StickerPack_StickerCount(data.info.count))))
    }
    entries.append(.searchInfo(presentationData.theme, isEmoji ? presentationData.strings.Group_Emoji_Info : presentationData.strings.Channel_Stickers_CreateYourOwn))
    
    let namespace = isEmoji ? Namespaces.ItemCollection.CloudEmojiPacks : Namespaces.ItemCollection.CloudStickerPacks
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespace])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[namespace] {
            if !packsEntries.isEmpty {
                entries.append(.packsTitle(presentationData.theme, isEmoji ? presentationData.strings.Group_Emoji_YourEmoji : presentationData.strings.Channel_Stickers_YourStickers))
            }
            
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    var selected = false
                    if case let .found(found) = searchState {
                        selected = found.info.id == info.id
                    }
                    let count = info.count == 0 ? entry.count : info.count
                    
                    let thumbnail: StickerPackItem?
                    if let thumbnailRep = info.thumbnail {
                        thumbnail = StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: 0), file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: thumbnailRep.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: info.immediateThumbnailData, mimeType: "", size: nil, attributes: [], alternativeRepresentations: []), indexKeys: [])
                    } else {
                        thumbnail = entry.firstItem as? StickerPackItem
                    }
                    entries.append(.pack(index, presentationData.theme, presentationData.strings, info, thumbnail, isEmoji ? presentationData.strings.StickerPack_EmojiCount(count) : presentationData.strings.StickerPack_StickerCount(count), context.sharedContext.energyUsageSettings.loopStickers, selected))
                    index += 1
                }
            }
        }
    }
    
    return entries
}

public func groupStickerPackSetupController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, isEmoji: Bool = false, currentPackInfo: StickerPackCollectionInfo?, completion: ((StickerPackCollectionInfo?) -> Void)? = nil) -> ViewController {
    let initialState = GroupStickerPackSetupControllerState(isSaving: false, searchingPacks: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((GroupStickerPackSetupControllerState) -> GroupStickerPackSetupControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let searchText = ValuePromise<String>(currentPackInfo?.shortName ?? "", ignoreRepeated: true)
    
    let initialData = Promise<InitialStickerPackData?>()
    if let currentPackInfo = currentPackInfo {
        initialData.set(context.engine.stickers.cachedStickerPack(reference: .id(id: currentPackInfo.id.id, accessHash: currentPackInfo.accessHash), forceRemote: false)
        |> map { result -> InitialStickerPackData? in
            switch result {
                case .none:
                    return .noData
                case .fetching:
                    return nil
                case let .result(info, items, _):
                    return InitialStickerPackData.data(StickerPackData(info: info._parse(), item: items.first))
            }
        })
    } else {
        initialData.set(.single(.noData))
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    var completionImpl: ((StickerPackCollectionInfo?) -> Void)?
    if let completion {
        completionImpl = { value in
            completion(value)
        }
    }
    
    let stickerPacks = Promise<CombinedView>()
    stickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [isEmoji ? Namespaces.ItemCollection.CloudEmojiPacks : Namespaces.ItemCollection.CloudStickerPacks])]))
    
    let searchState = Promise<(String, GroupStickerPackSearchState)>()
    searchState.set(combineLatest(searchText.get(), initialData.get(), stickerPacks.get())
    |> mapToSignal { searchText, initialData, view -> Signal<(String, GroupStickerPackSearchState), NoError> in
        if let initialData = initialData {
            if searchText.isEmpty {
                return .single((searchText, .none))
            } else if case let .data(data) = initialData, searchText.lowercased() == data.info.shortName {
                Queue.mainQueue().async {
                    completionImpl?(data.info)
                }
                return .single((searchText, .found(StickerPackData(info: data.info, item: data.item))))
            } else {
                let namespace = isEmoji ? Namespaces.ItemCollection.CloudEmojiPacks : Namespaces.ItemCollection.CloudStickerPacks
                if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespace])] as? ItemCollectionInfosView {
                    if let packsEntries = stickerPacksView.entriesByNamespace[namespace] {
                        for entry in packsEntries {
                            if let info = entry.info as? StickerPackCollectionInfo {
                                if info.shortName.lowercased() == searchText.lowercased() {
                                    return .single((searchText, .found(StickerPackData(info: info, item: entry.firstItem as? StickerPackItem))))
                                }
                            }
                        }
                    }
                }
                return .single((searchText, .searching))
                |> then((context.engine.stickers.loadedStickerPack(reference: .name(searchText.lowercased()), forceActualized: false) |> delay(0.3, queue: Queue.concurrentDefaultQueue()))
                |> mapToSignal { value -> Signal<(String, GroupStickerPackSearchState), NoError> in
                    switch value {
                        case .fetching:
                            return .complete()
                        case .none:
                            return .single((searchText, .notFound))
                        case let .result(info, items, _):
                            return .single((searchText, .found(StickerPackData(info: info._parse(), item: items.first))))
                    }
                }
                |> afterNext { value in
                    if case let .found(data) = value.1 {
                        Queue.mainQueue().async {
                            completionImpl?(data.info)
                        }
                    }
                })
            }
        } else {
            return .single((searchText, .none))
        }
    })
    
    var navigateToChatControllerImpl: ((PeerId) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    let saveDisposable = MetaDisposable()
    actionsDisposable.add(saveDisposable)
    
    var presentStickerPackController: ((StickerPackCollectionInfo) -> Void)?
    
    let arguments = GroupStickerPackSetupControllerArguments(context: context, selectStickerPack: { info in
        searchText.set(info.shortName)
        completionImpl?(info)
    }, openStickerPack: { info in
        presentStickerPackController?(info)
    }, updateSearchText: { text in
        searchText.set(text)
        if text == "" {
            completionImpl?(nil)
        }
    }, openStickersBot: {
        resolveDisposable.set((context.engine.peers.resolvePeerByName(name: "stickers", referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> deliverOnMainQueue).start(next: { peer in
            if let peer = peer {
                dismissImpl?()
                navigateToChatControllerImpl?(peer.id)
            }
        }))
    })
    
    let previousHadData = Atomic<Bool>(value: false)
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(presentationData, statePromise.get() |> deliverOnMainQueue, initialData.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, searchState.get() |> deliverOnMainQueue, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]) |> deliverOnMainQueue)
    |> map { presentationData, state, initialData, view, searchState, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var stickerSettings = StickerSettings.defaultSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
            stickerSettings = value
        }
        
        let leftNavigationButton: ItemListNavigationButton?
        if isEmoji {
            leftNavigationButton = nil
        } else {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        if let _ = completion {
            rightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                updateState { state in
                    var updatedState = state
                    updatedState.searchingPacks = true
                    return updatedState
                }
            })
        } else {
            if initialData != nil {
                if state.isSaving {
                    rightNavigationButton = ItemListNavigationButton(content: .text(""), style: .activity, enabled: true, action: {})
                } else {
                    let enabled: Bool
                    var info: StickerPackCollectionInfo?
                    switch searchState.1 {
                    case .searching, .notFound:
                        enabled = false
                    case .none:
                        enabled = true
                    case let .found(data):
                        enabled = true
                        info = data.info
                    }
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: enabled, action: {
                        if info?.id == currentPackInfo?.id {
                            dismissImpl?()
                        } else {
                            updateState { state in
                                var state = state
                                state.isSaving = true
                                return state
                            }
                            saveDisposable.set((context.engine.peers.updateGroupSpecificStickerset(peerId: peerId, info: info)
                            |> deliverOnMainQueue).start(error: { _ in
                                updateState { state in
                                    var state = state
                                    state.isSaving = false
                                    return state
                                }
                            }, completed: {
                                dismissImpl?()
                            }))
                        }
                    })
                }
            }
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searchingPacks {
            searchItem = GroupStickerSearchItem(context: context, cancel: {
                updateState { state in
                    var updatedState = state
                    updatedState.searchingPacks = false
                    return updatedState
                }
            }, select: { pack in
                arguments.selectStickerPack(pack)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(isEmoji ? presentationData.strings.Group_Emoji_Title : presentationData.strings.Channel_Info_Stickers), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        
        let hasData = initialData != nil
        let hadData = previousHadData.swap(hasData)
        
        var emptyStateItem: ItemListLoadingIndicatorEmptyStateItem?
        if !hasData {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: groupStickerPackSetupControllerEntries(context: context, presentationData: presentationData, searchText: searchState.0, view: view, initialData: initialData, searchState: searchState.1, stickerSettings: stickerSettings, isEmoji: isEmoji), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: hasData && hadData)
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            if c is UndoOverlayController {
                controller.window?.forEachController { c in
                    if let controller = c as? UndoOverlayController {
                        controller.dismiss()
                    }
                }
            }
            
            controller.present(c, in: .window(.root), with: p)
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    presentStickerPackController = { [weak controller] info in
        dismissInputImpl?()
        let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
        presentControllerImpl?(StickerPackScreen(context: context, updatedPresentationData: updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controller?.navigationController as? NavigationController), nil)
    }
    navigateToChatControllerImpl = { [weak controller] peerId in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            
            if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
            }
        })
    }
    dismissImpl = { [weak controller] in
        dismissInputImpl?()
        controller?.dismiss()
    }
    
    return controller
}

