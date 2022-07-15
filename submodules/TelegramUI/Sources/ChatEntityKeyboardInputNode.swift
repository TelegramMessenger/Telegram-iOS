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
import PagerComponent
import AppBundle
import PremiumUI
import AudioToolbox
import UndoUI
import ContextUI
import GalleryUI

private let staticEmojiMapping: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = {
    guard let path = getAppBundle().path(forResource: "emoji1016", ofType: "txt") else {
        return []
    }
    guard let string = try? String(contentsOf: URL(fileURLWithPath: path)) else {
        return []
    }
    
    var result: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = []
    
    let orderedSegments = EmojiPagerContentComponent.StaticEmojiSegment.allCases
    
    let segments = string.components(separatedBy: "\n\n")
    for i in 0 ..< min(segments.count, orderedSegments.count) {
        let list = segments[i].components(separatedBy: " ")
        result.append((orderedSegments[i], list))
    }
    
    return result
}()

final class ChatEntityKeyboardInputNode: ChatInputNode {
    struct InputData: Equatable {
        var emoji: EmojiPagerContentComponent
        var stickers: EmojiPagerContentComponent
        var gifs: GifPagerContentComponent
        var availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji]
        
        init(
            emoji: EmojiPagerContentComponent,
            stickers: EmojiPagerContentComponent,
            gifs: GifPagerContentComponent,
            availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji]
        ) {
            self.emoji = emoji
            self.stickers = stickers
            self.gifs = gifs
            self.availableGifSearchEmojies = availableGifSearchEmojies
        }
    }
    
    static func inputData(context: AccountContext, interfaceInteraction: ChatPanelInterfaceInteraction, controllerInteraction: ChatControllerInteraction, chatPeerId: PeerId?) -> Signal<InputData, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> Bool in
            guard case let .user(user) = peer else {
                return false
            }
            return user.isPremium
        }
        |> distinctUntilChanged
        
        let emojiInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction, weak controllerInteraction] item, _, _, _ in
                let _ = (hasPremium |> take(1) |> deliverOnMainQueue).start(next: { hasPremium in
                    guard let controllerInteraction = controllerInteraction, let interfaceInteraction = interfaceInteraction else {
                        return
                    }
                    
                    if let file = item.file {
                        var text = "."
                        var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, displayText, packReference):
                                text = displayText
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(stickerPack: packReference, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                        
                        if file.isPremiumEmoji && !hasPremium {
                            //TODO:localize
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            controllerInteraction.presentController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, title: nil, text: "Subscribe to Telegram Premium to unlock this emoji.", undoText: "More", customAction: { [weak controllerInteraction] in
                                guard let controllerInteraction = controllerInteraction else {
                                    return
                                }
                                
                                var replaceImpl: ((ViewController) -> Void)?
                                let controller = PremiumDemoScreen(context: context, subject: .premiumStickers, action: {
                                    let controller = PremiumIntroScreen(context: context, source: .stickers)
                                    replaceImpl?(controller)
                                })
                                replaceImpl = { [weak controller] c in
                                    controller?.replace(with: c)
                                }
                                controllerInteraction.navigationController()?.pushViewController(controller)
                                
                                /*let controller = PremiumIntroScreen(context: context, source: .stickers)
                                controllerInteraction.navigationController()?.pushViewController(controller)*/
                            }), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                            return
                        }
                        
                        if let emojiAttribute = emojiAttribute {
                            AudioServicesPlaySystemSound(0x450)
                            interfaceInteraction.insertText(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute]))
                        }
                    } else if let staticEmoji = item.staticEmoji {
                        AudioServicesPlaySystemSound(0x450)
                        interfaceInteraction.insertText(NSAttributedString(string: staticEmoji, attributes: [:]))
                    }
                })
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            },
            openStickerSettings: {
            },
            openPremiumSection: { [weak controllerInteraction] in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let controller = PremiumIntroScreen(context: context, source: .stickers)
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
        let stickerInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction] item, view, rect, layer in
                let _ = (hasPremium |> take(1) |> deliverOnMainQueue).start(next: { hasPremium in
                    guard let interfaceInteraction = interfaceInteraction else {
                        return
                    }
                    if let file = item.file {
                        if file.isPremiumSticker && !hasPremium {
                            let controller = PremiumIntroScreen(context: context, source: .stickers)
                            controllerInteraction.navigationController()?.pushViewController(controller)
                            
                            return
                        }
                        let _ = interfaceInteraction.sendSticker(.standalone(media: file), false, view, rect, layer)
                    }
                })
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
            openPremiumSection: {
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
        
        let animationCache = AnimationCacheImpl(basePath: context.account.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        })
        let animationRenderer: MultiAnimationRenderer
        /*if #available(iOS 13.0, *) {
            animationRenderer = MultiAnimationMetalRendererImpl()
        } else {*/
            animationRenderer = MultiAnimationRendererImpl()
        //}
        
        let orderedItemListCollectionIds: [Int32] = [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.PremiumStickers, Namespaces.OrderedItemList.CloudPremiumStickers]
        let namespaces: [ItemCollectionId.Namespace] = [Namespaces.ItemCollection.CloudStickerPacks]
        
        let emojiItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
            hasPremium
        )
        |> map { view, hasPremium -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var isPremium: Bool
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            for (subgroupId, list) in staticEmojiMapping {
                let groupId: AnyHashable = "static"
                for emojiString in list {
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: nil,
                        staticEmoji: emojiString,
                        subgroupId: subgroupId.rawValue
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, isPremium: false, items: [resultItem]))
                    }
                }
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                let resultItem = EmojiPagerContentComponent.Item(
                    file: item.file,
                    staticEmoji: nil,
                    subgroupId: nil
                )
                
                let supergroupId = entry.index.collectionId
                let groupId: AnyHashable = supergroupId
                let isPremium: Bool = item.file.isPremiumEmoji && !hasPremium
                if isPremium && isPremiumDisabled {
                    continue
                }
                /*if isPremium {
                    groupId = "\(supergroupId)-p"
                } else {
                    groupId = supergroupId
                }*/
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, isPremium: isPremium, items: [resultItem]))
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
                        title = "Recently Used"
                    } else {
                        for (id, info, _) in view.collectionInfos {
                            if AnyHashable(id) == group.id, let info = info as? StickerPackCollectionInfo {
                                title = info.title
                                break
                            }
                        }
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(supergroupId: group.supergroupId, groupId: group.id, title: title, isPremium: group.isPremium, displayPremiumBadges: false, items: group.items)
                },
                itemLayoutType: .compact
            )
        }
        
        let stickerItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: namespaces, aroundIndex: nil, count: 10000000),
            hasPremium
        )
        |> map { view, hasPremium -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var displayPremiumBadges: Bool
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
                        file: item.file,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let groupId = "saved"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, displayPremiumBadges: false, items: [resultItem]))
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
                        file: item.media,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, displayPremiumBadges: false, items: [resultItem]))
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
                        file: item.media,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let groupId = "premium"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, displayPremiumBadges: false, items: [resultItem]))
                    }
                }
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                let resultItem = EmojiPagerContentComponent.Item(
                    file: item.file,
                    staticEmoji: nil,
                    subgroupId: nil
                )
                let groupId = entry.index.collectionId
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, displayPremiumBadges: true, items: [resultItem]))
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
                        title = "Saved"
                    } else if group.id == AnyHashable("recent") {
                        //TODO:localize
                        title = "Recently Used"
                    } else if group.id == AnyHashable("premium") {
                        //TODO:localize
                        title = "Premium"
                    } else {
                        for (id, info, _) in view.collectionInfos {
                            if AnyHashable(id) == group.id, let info = info as? StickerPackCollectionInfo {
                                title = info.title
                                break
                            }
                        }
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(supergroupId: group.supergroupId, groupId: group.id, title: title, isPremium: false, displayPremiumBadges: group.displayPremiumBadges, items: group.items)
                },
                itemLayoutType: .detailed
            )
        }
        
        let reactions: Signal<[String], NoError> = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.App())
        |> map { appConfiguration -> [String] in
            let defaultReactions: [String] = ["👍", "👎", "😍", "😂", "😯", "😕", "😢", "😡", "💪", "👏", "🙈", "😒"]
            
            guard let data = appConfiguration.data, let emojis = data["gif_search_emojies"] as? [String] else {
                return defaultReactions
            }
            return emojis
        }
        |> distinctUntilChanged
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let gifInputInteraction = GifPagerContentComponent.InputInteraction(
            performItemAction: { [weak controllerInteraction] item, view, rect in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendGif(.savedGif(media: item.file), view, rect, false, false)
            },
            openGifContextMenu: { _, _, _, _, _ in
            },
            loadMore: { _ in
            }
        )
        
        // We are going to subscribe to the actual data when the view is loaded
        let gifItems: Signal<GifPagerContentComponent, NoError> = .single(GifPagerContentComponent(
            context: context,
            inputInteraction: gifInputInteraction,
            subject: .recent,
            items: [],
            isLoading: false,
            loadMoreToken: nil
        ))
        
        return combineLatest(queue: .mainQueue(),
            emojiItems,
            stickerItems,
            gifItems,
            reactions,
            animatedEmojiStickers
        )
        |> map { emoji, stickers, gifs, reactions, animatedEmojiStickers -> InputData in
            var availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji] = []
            for reaction in reactions {
                if let file = animatedEmojiStickers[reaction]?.first?.file {
                    availableGifSearchEmojies.append(EntityKeyboardComponent.GifSearchEmoji(emoji: reaction, file: file, title: reaction))
                }
            }
            
            return InputData(
                emoji: emoji,
                stickers: stickers,
                gifs: gifs,
                availableGifSearchEmojies: availableGifSearchEmojies
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
    
    var externalTopPanelContainerImpl: PagerExternalTopPanelContainer?
    override var externalTopPanelContainer: UIView? {
        return self.externalTopPanelContainerImpl
    }
    
    private var currentState: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool)?
    
    private var gifMode: GifPagerContentComponent.Subject = .recent {
        didSet {
            if self.gifMode != oldValue {
                self.reloadGifContext()
            }
        }
    }
    
    private final class GifContext {
        private var componentValue: GifPagerContentComponent? {
            didSet {
                if let componentValue = self.componentValue {
                    self.componentResult.set(.single(componentValue))
                }
            }
        }
        private let componentPromise = Promise<GifPagerContentComponent>()
        
        private let componentResult = Promise<GifPagerContentComponent>()
        var component: Signal<GifPagerContentComponent, NoError> {
            return self.componentResult.get()
        }
        private var componentDisposable: Disposable?
        
        private let context: AccountContext
        private let subject: GifPagerContentComponent.Subject
        private let gifInputInteraction: GifPagerContentComponent.InputInteraction
        
        private var loadingMoreToken: String?
        
        init(context: AccountContext, subject: GifPagerContentComponent.Subject, gifInputInteraction: GifPagerContentComponent.InputInteraction, trendingGifs: Signal<ChatMediaInputGifPaneTrendingState?, NoError>) {
            self.context = context
            self.subject = subject
            self.gifInputInteraction = gifInputInteraction
            
            let gifItems: Signal<GifPagerContentComponent, NoError>
            switch subject {
            case .recent:
                gifItems = context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
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
                        subject: subject,
                        items: items,
                        isLoading: false,
                        loadMoreToken: nil
                    )
                }
            case .trending:
                gifItems = trendingGifs
                |> map { trendingGifs -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    
                    var isLoading = false
                    if let trendingGifs = trendingGifs {
                        for file in trendingGifs.files {
                            items.append(GifPagerContentComponent.Item(
                                file: file.file.media
                            ))
                        }
                    } else {
                        isLoading = true
                    }
                    
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: nil
                    )
                }
            case let .emojiSearch(query):
                gifItems = paneGifSearchForQuery(context: context, query: query, offset: nil, incompleteResults: true, staleCachedResults: true, delayRequest: false, updateActivity: nil)
                |> map { result -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    
                    var loadMoreToken: String?
                    var isLoading = false
                    if let result = result {
                        for file in result.files {
                            items.append(GifPagerContentComponent.Item(
                                file: file.file.media
                            ))
                        }
                        loadMoreToken = result.nextOffset
                    } else {
                        isLoading = true
                    }
                    
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: loadMoreToken
                    )
                }
            }
            
            self.componentPromise.set(gifItems)
            self.componentDisposable = (self.componentPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.componentValue = result
            })
        }
        
        deinit {
            self.componentDisposable?.dispose()
        }
        
        func loadMore(token: String) {
            if self.loadingMoreToken == token {
                return
            }
            self.loadingMoreToken = token
            
            guard let componentValue = self.componentValue else {
                return
            }
            
            let context = self.context
            let subject = self.subject
            let gifInputInteraction = self.gifInputInteraction
            
            switch self.subject {
            case let .emojiSearch(query):
                let gifItems: Signal<GifPagerContentComponent, NoError>
                gifItems = paneGifSearchForQuery(context: context, query: query, offset: token, incompleteResults: true, staleCachedResults: true, delayRequest: false, updateActivity: nil)
                |> map { result -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    var existingIds = Set<MediaId>()
                    for item in componentValue.items {
                        items.append(item)
                        existingIds.insert(item.file.fileId)
                    }
                    
                    var loadMoreToken: String?
                    var isLoading = false
                    if let result = result {
                        for file in result.files {
                            if existingIds.contains(file.file.media.fileId) {
                                continue
                            }
                            existingIds.insert(file.file.media.fileId)
                            items.append(GifPagerContentComponent.Item(file: file.file.media))
                        }
                        if !result.isComplete {
                            loadMoreToken = result.nextOffset
                        }
                    } else {
                        isLoading = true
                    }
                    
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: loadMoreToken
                    )
                }
                
                self.componentPromise.set(gifItems)
            default:
                break
            }
        }
    }
    private var gifContext: GifContext? {
        didSet {
            if let gifContext = self.gifContext {
                self.gifComponent.set(gifContext.component)
            }
        }
    }
    private let gifComponent = Promise<GifPagerContentComponent>()
    private var gifInputInteraction: GifPagerContentComponent.InputInteraction?
    
    init(context: AccountContext, currentInputData: InputData, updatedInputData: Signal<InputData, NoError>, defaultToEmojiTab: Bool, controllerInteraction: ChatControllerInteraction) {
        self.context = context
        self.currentInputData = currentInputData
        self.defaultToEmojiTab = defaultToEmojiTab
        
        self.controllerInteraction = controllerInteraction
        
        self.entityKeyboardView = ComponentHostView<Empty>()
        
        super.init()
        
        self.topBackgroundExtension = 41.0
        self.followsDefaultHeight = true
        
        self.view.addSubview(self.entityKeyboardView)
        
        self.externalTopPanelContainerImpl = PagerExternalTopPanelContainer()
        
        self.inputDataDisposable = (combineLatest(queue: .mainQueue(),
            updatedInputData,
            self.gifComponent.get()
        )
        |> deliverOnMainQueue).start(next: { [weak self] inputData, gifs in
            guard let strongSelf = self else {
                return
            }
            var inputData = inputData
            inputData.gifs = gifs
            
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
        
        self.trendingGifsPromise.set(.single(nil))
        self.trendingGifsPromise.set(paneGifSearchForQuery(context: context, query: "", offset: nil, incompleteResults: true, delayRequest: false, updateActivity: nil)
        |> map { items -> ChatMediaInputGifPaneTrendingState? in
            if let items = items {
                return ChatMediaInputGifPaneTrendingState(files: items.files, nextOffset: items.nextOffset)
            } else {
                return nil
            }
        })
        
        self.gifInputInteraction = GifPagerContentComponent.InputInteraction(
            performItemAction: { [weak controllerInteraction] item, view, rect in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendGif(.savedGif(media: item.file), view, rect, false, false)
            },
            openGifContextMenu: { [weak self] file, sourceView, sourceRect, gesture, isSaved in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.openGifContextMenu(file: file, sourceView: sourceView, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
            },
            loadMore: { [weak self] token in
                guard let strongSelf = self, let gifContext = strongSelf.gifContext else {
                    return
                }
                gifContext.loadMore(token: token)
            }
        )
        
        self.reloadGifContext()
    }
    
    deinit {
        self.inputDataDisposable?.dispose()
    }
    
    private func reloadGifContext() {
        if let gifInputInteraction = self.gifInputInteraction {
            self.gifContext = GifContext(context: self.context, subject: self.gifMode, gifInputInteraction: gifInputInteraction, trendingGifs: self.trendingGifsPromise.get())
        }
    }
    
    func markInputCollapsed() {
        self.isMarkInputCollapsed = true
    }
    
    private func performLayout() {
        guard let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible, isExpanded) = self.currentState else {
            return
        }
        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible, isExpanded: isExpanded)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        self.currentState = (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible, isExpanded)
        
        let wasMarkedInputCollapsed = self.isMarkInputCollapsed
        self.isMarkInputCollapsed = false
        
        let expandedHeight = standardInputHeight
        
        var hiddenInputHeight: CGFloat = 0.0
        if self.hideInput && !self.adjustLayoutForHiddenInput {
            hiddenInputHeight = inputPanelHeight
        }
        
        let context = self.context
        let controllerInteraction = self.controllerInteraction
        let inputNodeInteraction = self.inputNodeInteraction!
        let trendingGifsPromise = self.trendingGifsPromise
        
        var mappedTransition = Transition(transition)
        
        if wasMarkedInputCollapsed || !isExpanded {
            mappedTransition = mappedTransition.withUserData(EntityKeyboardComponent.MarkInputCollapsed())
        }
        
        var stickerContent: EmojiPagerContentComponent? = self.currentInputData.stickers
        var gifContent: GifPagerContentComponent? = self.currentInputData.gifs
        
        var stickersEnabled = true
        if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel {
            if peer.hasBannedPermission(.banSendStickers) != nil {
                stickersEnabled = false
            }
        } else if let peer = interfaceState.renderedPeer?.peer as? TelegramGroup {
            if peer.hasBannedPermission(.banSendStickers) {
                stickersEnabled = false
            }
        }
        
        if !stickersEnabled || interfaceState.interfaceState.editMessage != nil {
            stickerContent = nil
            gifContent = nil
        }
        
        let entityKeyboardSize = self.entityKeyboardView.update(
            transition: mappedTransition,
            component: AnyComponent(EntityKeyboardComponent(
                theme: interfaceState.theme,
                bottomInset: bottomInset,
                emojiContent: self.currentInputData.emoji,
                stickerContent: stickerContent,
                gifContent: gifContent,
                availableGifSearchEmojies: self.currentInputData.availableGifSearchEmojies,
                defaultToEmojiTab: self.defaultToEmojiTab,
                externalTopPanelContainer: self.externalTopPanelContainerImpl,
                topPanelExtensionUpdated: { [weak self] topPanelExtension, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.topBackgroundExtension != topPanelExtension {
                        strongSelf.topBackgroundExtension = topPanelExtension
                        strongSelf.topBackgroundExtensionUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                hideInputUpdated: { [weak self] hideInput, adjustLayout, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.hideInput != hideInput || strongSelf.adjustLayoutForHiddenInput != adjustLayout {
                        strongSelf.hideInput = hideInput
                        strongSelf.adjustLayoutForHiddenInput = adjustLayout
                        strongSelf.hideInputUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                switchToTextInput: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.controllerInteraction.updateInputMode { _ in
                        return .text
                    }
                },
                switchToGifSubject: { [weak self] subject in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.gifMode = subject
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
                deviceMetrics: deviceMetrics,
                hiddenInputHeight: hiddenInputHeight,
                isExpanded: isExpanded
            )),
            environment: {},
            containerSize: CGSize(width: width, height: expandedHeight)
        )
        transition.updateFrame(view: self.entityKeyboardView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: entityKeyboardSize))
        
        return (expandedHeight, 0.0)
    }
    
    private func openGifContextMenu(file: TelegramMediaFile, sourceView: UIView, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
        let canSaveGif: Bool
        if file.fileId.namespace == Namespaces.Media.CloudFile {
            canSaveGif = true
        } else {
            canSaveGif = false
        }
        
        let _ = (self.context.engine.stickers.isGifSaved(id: file.fileId)
        |> deliverOnMainQueue).start(next: { [weak self] isGifSaved in
            guard let strongSelf = self else {
                return
            }
            var isGifSaved = isGifSaved
            if !canSaveGif {
                isGifSaved = false
            }
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:])
            
            let gallery = GalleryController(context: strongSelf.context, source: .standaloneMessage(message), streamSingleVideo: true, replaceRootController: { _, _ in
            }, baseNavigationController: nil)
            gallery.setHintWillBePresentedInPreviewingContext(true)
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Send, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                f(.default)
                if isSaved {
                    let _ = self?.controllerInteraction.sendGif(FileMediaReference.savedGif(media: file), sourceView, sourceRect, false, false)
                }/* else if let (collection, result) = file.contextResult {
                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect, false)
                }*/
            })))
            
            /*if let (_, _, _, _, _, _, _, _, interfaceState, _, _, _) = strongSelf.validLayout {
                var isScheduledMessages = false
                if case .scheduledMessages = interfaceState.subject {
                    isScheduledMessages = true
                }
                if !isScheduledMessages {
                    if case let .peer(peerId) = interfaceState.chatLocation {
                        if peerId != self?.context.account.peerId && peerId.namespace != Namespaces.Peer.SecretChat  {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                if isSaved {
                                    let _ = self?.controllerInteraction.sendGif(file.file, sourceNode.view, sourceRect, true, false)
                                } else if let (collection, result) = file.contextResult {
                                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect, true)
                                }
                            })))
                        }
                    
                        if isSaved {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                
                                let _ = self?.controllerInteraction.sendGif(file.file, sourceNode.view, sourceRect, false, true)
                            })))
                        }
                    }
                }
            }*/
            
            if isSaved || isGifSaved {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = removeSavedGif(postbox: strongSelf.context.account.postbox, mediaId: file.fileId).start()
                })))
            } else if canSaveGif && !isGifSaved {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Preview_SaveGif, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let context = strongSelf.context
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controllerInteraction = strongSelf.controllerInteraction
                    let _ = (toggleGifSaved(account: context.account, fileReference: FileMediaReference.savedGif(media: file), saved: true)
                    |> deliverOnMainQueue).start(next: { result in
                        switch result {
                            case .generic:
                                controllerInteraction.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                            case let .limitExceeded(limit, premiumLimit):
                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                let text: String
                                if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                    text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                } else {
                                    text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                }
                                controllerInteraction.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                                    if case .info = action {
                                        let controller = PremiumIntroScreen(context: context, source: .savedGifs)
                                        controllerInteraction.navigationController()?.pushViewController(controller)
                                        return true
                                    }
                                    return false
                                }), nil)
                        }
                    })
                })))
            }
            
            let contextController = ContextController(account: strongSelf.context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceView: sourceView, sourceRect: sourceRect)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.controllerInteraction.presentGlobalOverlayController(contextController, nil)
        })
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceView: UIView?
    let sourceRect: CGRect
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceView: UIView?, sourceRect: CGRect) {
        self.controller = controller
        self.sourceView = sourceView
        self.sourceRect = sourceRect
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceView = self.sourceView
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceView] in
            if let sourceView = sourceView {
                return (sourceView, sourceRect)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        if let controller = self.controller as? GalleryController {
            controller.viewDidAppear(false)
        }
    }
}
