import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import ChatPresentationInterfaceState
import ComponentFlow
import EntityKeyboard
import AnimationCache
import MultiAnimationRenderer
import Postbox
import TelegramCore
import ComponentDisplayAdapters
import SettingsUI
import TextFormat

final class ChatEntityKeyboardInputNode: ChatInputNode {
    struct InputData: Equatable {
        let emoji: EmojiPagerContentComponent
        let stickers: EmojiPagerContentComponent
        let gifs: GifPagerContentComponent
        
        init(
            emoji: EmojiPagerContentComponent,
            stickers: EmojiPagerContentComponent,
            gifs: GifPagerContentComponent
        ) {
            self.emoji = emoji
            self.stickers = stickers
            self.gifs = gifs
        }
    }
    
    static func inputData(context: AccountContext, interfaceInteraction: ChatPanelInterfaceInteraction, controllerInteraction: ChatControllerInteraction, chatPeerId: PeerId?) -> Signal<InputData, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let emojiInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction] item, _, _, _ in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                var text = "."
                var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                loop: for attribute in item.file.attributes {
                    switch attribute {
                    case let .Sticker(displayText, packReference, _):
                        text = displayText
                        if let packReference = packReference {
                            emojiAttribute = ChatTextInputTextCustomEmojiAttribute(stickerPack: packReference, fileId: item.file.fileId.id)
                            break loop
                        }
                    default:
                        break
                    }
                }
                
                if let emojiAttribute = emojiAttribute {
                    interfaceInteraction.insertText(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute]))
                }
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            },
            openStickerSettings: {
            },
            pushController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.navigationController()?.pushViewController(controller)
            },
            presentController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentController(controller, nil)
            },
            presentGlobalOverlayController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentGlobalOverlayController(controller, nil)
            },
            navigationController: { [weak controllerInteraction] in
                return controllerInteraction?.navigationController()
            },
            sendSticker: { [weak controllerInteraction] fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendSticker(fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer)
            },
            chatPeerId: chatPeerId
        )
        let stickerInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction] item, view, rect, layer in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                let _ = interfaceInteraction.sendSticker(.standalone(media: item.file), false, view, rect, layer)
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            },
            openStickerSettings: { [weak controllerInteraction] in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let controller = installedStickerPacksController(context: context, mode: .modal)
                controller.navigationPresentation = .modal
                controllerInteraction.navigationController()?.pushViewController(controller)
            },
            pushController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.navigationController()?.pushViewController(controller)
            },
            presentController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentController(controller, nil)
            },
            presentGlobalOverlayController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentGlobalOverlayController(controller, nil)
            },
            navigationController: { [weak controllerInteraction] in
                return controllerInteraction?.navigationController()
            },
            sendSticker: { [weak controllerInteraction] fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendSticker(fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer)
            },
            chatPeerId: chatPeerId
        )
        let gifInputInteraction = GifPagerContentComponent.InputInteraction(
            performItemAction: { [weak controllerInteraction] item, view, rect in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendGif(.savedGif(media: item.file), view, rect, false, false)
            }
        )
        
        let animationCache = AnimationCacheImpl(basePath: context.account.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        })
        let animationRenderer = MultiAnimationRendererImpl()
        
        let orderedItemListCollectionIds: [Int32] = [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.PremiumStickers, Namespaces.OrderedItemList.CloudPremiumStickers]
        let namespaces: [ItemCollectionId.Namespace] = [Namespaces.ItemCollection.CloudStickerPacks]
        
        let emojiItems: Signal<EmojiPagerContentComponent, NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: namespaces, aroundIndex: nil, count: 10000000)
        |> map { view -> EmojiPagerContentComponent in
            struct ItemGroup {
                var id: AnyHashable
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            var emojiCollectionIds = Set<ItemCollectionId>()
            for (id, info, _) in view.collectionInfos {
                if let info = info as? StickerPackCollectionInfo {
                    if info.shortName.lowercased().contains("emoji") {
                        emojiCollectionIds.insert(id)
                    }
                }
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                if item.file.isAnimatedSticker || item.file.isVideoSticker {
                    if emojiCollectionIds.contains(entry.index.collectionId) {
                        let resultItem = EmojiPagerContentComponent.Item(
                            emoji: "",
                            file: item.file,
                            stickerPackItem: nil
                        )
                        
                        let groupId = entry.index.collectionId
                        if let groupIndex = itemGroupIndexById[groupId] {
                            itemGroups[groupIndex].items.append(resultItem)
                        } else {
                            itemGroupIndexById[groupId] = itemGroups.count
                            itemGroups.append(ItemGroup(id: groupId, items: [resultItem]))
                        }
                    }
                }
            }
            
            return EmojiPagerContentComponent(
                id: "emoji",
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteraction: emojiInputInteraction,
                itemGroups: itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                    var title: String?
                    if group.id == AnyHashable("recent") {
                        //TODO:localize
                        title = "Recently Used".uppercased()
                    } else {
                        for (id, info, _) in view.collectionInfos {
                            if AnyHashable(id) == group.id, let info = info as? StickerPackCollectionInfo {
                                title = info.title.uppercased()
                                break
                            }
                        }
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(id: group.id, title: title, items: group.items)
                },
                itemLayoutType: .compact
            )
        }
        
        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> Bool in
            guard case let .user(user) = peer else {
                return false
            }
            return user.isPremium
        }
        |> distinctUntilChanged
        
        let stickerItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: namespaces, aroundIndex: nil, count: 10000000),
            hasPremium
        )
        |> map { view, hasPremium -> EmojiPagerContentComponent in
            struct ItemGroup {
                var id: AnyHashable
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            var savedStickers: OrderedItemListView?
            var recentStickers: OrderedItemListView?
            var premiumStickers: OrderedItemListView?
            var cloudPremiumStickers: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStickers {
                    recentStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudSavedStickers {
                    savedStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.PremiumStickers {
                    premiumStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudPremiumStickers {
                    cloudPremiumStickers = orderedView
                }
            }
            
            if let savedStickers = savedStickers {
                for item in savedStickers.items {
                    guard let item = item.contents.get(SavedStickerItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.file.isPremiumSticker {
                        continue
                    }
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        emoji: "",
                        file: item.file,
                        stickerPackItem: nil
                    )
                    
                    let groupId = "saved"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(id: groupId, items: [resultItem]))
                    }
                }
            }
            
            if let recentStickers = recentStickers {
                var count = 0
                for item in recentStickers.items {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.media.isPremiumSticker {
                        continue
                    }
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        emoji: "",
                        file: item.media,
                        stickerPackItem: nil
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(id: groupId, items: [resultItem]))
                    }
                    
                    count += 1
                    if count >= 5 {
                        break
                    }
                }
            }
            
            var hasPremiumStickers = false
            if hasPremium {
                if let premiumStickers = premiumStickers, !premiumStickers.items.isEmpty {
                    hasPremiumStickers = true
                } else if let cloudPremiumStickers = cloudPremiumStickers, !cloudPremiumStickers.items.isEmpty {
                    hasPremiumStickers = true
                }
            }
            
            if hasPremiumStickers {
                var premiumStickers = premiumStickers?.items ?? []
                if let cloudPremiumStickers = cloudPremiumStickers {
                    premiumStickers.append(contentsOf: cloudPremiumStickers.items)
                }
                
                var processedIds = Set<MediaId>()
                for item in premiumStickers {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.media.isPremiumSticker {
                        continue
                    }
                    if processedIds.contains(item.media.fileId) {
                        continue
                    }
                    processedIds.insert(item.media.fileId)
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        emoji: "",
                        file: item.media,
                        stickerPackItem: nil
                    )
                    
                    let groupId = "premium"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(id: groupId, items: [resultItem]))
                    }
                }
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                let resultItem = EmojiPagerContentComponent.Item(
                    emoji: "",
                    file: item.file,
                    stickerPackItem: item
                )
                let groupId = entry.index.collectionId
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(id: groupId, items: [resultItem]))
                }
            }
            
            return EmojiPagerContentComponent(
                id: "stickers",
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteraction: stickerInputInteraction,
                itemGroups: itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                    var title: String?
                    if group.id == AnyHashable("saved") {
                        //TODO:localize
                        title = "Saved".uppercased()
                    } else if group.id == AnyHashable("recent") {
                        //TODO:localize
                        title = "Recently Used".uppercased()
                    } else if group.id == AnyHashable("premium") {
                        //TODO:localize
                        title = "Premium".uppercased()
                    } else {
                        for (id, info, _) in view.collectionInfos {
                            if AnyHashable(id) == group.id, let info = info as? StickerPackCollectionInfo {
                                title = info.title.uppercased()
                                break
                            }
                        }
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(id: group.id, title: title, items: group.items)
                },
                itemLayoutType: .detailed
            )
        }
        
        let gifItems: Signal<GifPagerContentComponent, NoError> = context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
        |> map { savedGifs -> GifPagerContentComponent in
            var items: [GifPagerContentComponent.Item] = []
            for gifItem in savedGifs {
                items.append(GifPagerContentComponent.Item(
                    file: gifItem.contents.get(RecentMediaItem.self)!.media
                ))
            }
            return GifPagerContentComponent(
                context: context,
                inputInteraction: gifInputInteraction,
                items: items
            )
        }
        
        return combineLatest(queue: .mainQueue(),
            emojiItems,
            stickerItems,
            gifItems
        )
        |> map { emoji, stickers, gifs -> InputData in
            return InputData(
                emoji: emoji,
                stickers: stickers,
                gifs: gifs
            )
        }
    }
    
    private let context: AccountContext
    private let entityKeyboardView: ComponentHostView<Empty>
    
    private let defaultToEmojiTab: Bool
    private var currentInputData: InputData
    private var inputDataDisposable: Disposable?
    
    private let controllerInteraction: ChatControllerInteraction
    
    private var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    private let trendingGifsPromise = Promise<ChatMediaInputGifPaneTrendingState?>(nil)
    
    private var isMarkInputCollapsed: Bool = false
    
    private var currentState: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool)?
    
    init(context: AccountContext, currentInputData: InputData, updatedInputData: Signal<InputData, NoError>, defaultToEmojiTab: Bool, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.currentInputData = currentInputData
        self.defaultToEmojiTab = defaultToEmojiTab
        
        self.controllerInteraction = controllerInteraction
        
        self.entityKeyboardView = ComponentHostView<Empty>()
        
        super.init()
        
        self.view.addSubview(self.entityKeyboardView)
        
        self.externalTopPanelContainer = SparseContainerView()
        
        self.inputDataDisposable = (updatedInputData
        |> deliverOnMainQueue).start(next: { [weak self] inputData in
            guard let strongSelf = self else {
                return
            }
            strongSelf.currentInputData = inputData
            strongSelf.performLayout()
        })
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(
            navigateToCollectionId: { _ in
            },
            navigateBackToStickers: {
            },
            setGifMode: { _ in
            },
            openSettings: {
            },
            openTrending: { _ in
            },
            dismissTrendingPacks: { _ in
            },
            toggleSearch: { _, _, _ in
            },
            openPeerSpecificSettings: {
            },
            dismissPeerSpecificSettings: {
            },
            clearRecentlyUsedStickers: {
            }
        )
        
        self.trendingGifsPromise.set(paneGifSearchForQuery(context: context, query: "", offset: nil, incompleteResults: true, delayRequest: false, updateActivity: nil)
        |> map { items -> ChatMediaInputGifPaneTrendingState? in
            if let items = items {
                return ChatMediaInputGifPaneTrendingState(files: items.files, nextOffset: items.nextOffset)
            } else {
                return nil
            }
        })
    }
    
    deinit {
        self.inputDataDisposable?.dispose()
    }
    
    func markInputCollapsed() {
        self.isMarkInputCollapsed = true
    }
    
    private func performLayout() {
        guard let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.currentState else {
            return
        }
        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        self.currentState = (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible)
        
        let wasMarkedInputCollapsed = self.isMarkInputCollapsed
        self.isMarkInputCollapsed = false
        
        let expandedHeight = standardInputHeight + self.expansionFraction * (maximumHeight - standardInputHeight)
        
        let context = self.context
        let controllerInteraction = self.controllerInteraction
        let inputNodeInteraction = self.inputNodeInteraction!
        let trendingGifsPromise = self.trendingGifsPromise
        
        var mappedTransition = Transition(transition)
        
        if wasMarkedInputCollapsed {
            mappedTransition = mappedTransition.withUserData(EntityKeyboardComponent.MarkInputCollapsed())
        }
        
        let entityKeyboardSize = self.entityKeyboardView.update(
            transition: mappedTransition,
            component: AnyComponent(EntityKeyboardComponent(
                theme: interfaceState.theme,
                bottomInset: bottomInset,
                emojiContent: self.currentInputData.emoji,
                stickerContent: self.currentInputData.stickers,
                gifContent: self.currentInputData.gifs,
                defaultToEmojiTab: self.defaultToEmojiTab,
                externalTopPanelContainer: self.externalTopPanelContainer,
                topPanelExtensionUpdated: { [weak self] topPanelExtension, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.topBackgroundExtension != topPanelExtension {
                        strongSelf.topBackgroundExtension = topPanelExtension
                        strongSelf.topBackgroundExtensionUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                hideInputUpdated: { [weak self] hideInput, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.hideInput != hideInput {
                        strongSelf.hideInput = hideInput
                        strongSelf.hideInputUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                makeSearchContainerNode: { content in
                    let mappedMode: ChatMediaInputSearchMode
                    switch content {
                    case .stickers:
                        mappedMode = .sticker
                    case .gifs:
                        mappedMode = .gif
                    }
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    return PaneSearchContainerNode(
                        context: context,
                        theme: presentationData.theme,
                        strings: presentationData.strings,
                        controllerInteraction: controllerInteraction,
                        inputNodeInteraction: inputNodeInteraction,
                        mode: mappedMode,
                        trendingGifsPromise: trendingGifsPromise,
                        cancel: {
                        }
                    )
                },
                deviceMetrics: deviceMetrics
            )),
            environment: {},
            containerSize: CGSize(width: width, height: expandedHeight)
        )
        transition.updateFrame(view: self.entityKeyboardView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: entityKeyboardSize))
        
        return (expandedHeight, 0.0)
    }
}
