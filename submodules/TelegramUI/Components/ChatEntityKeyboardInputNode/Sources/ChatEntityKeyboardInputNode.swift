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
import TextFormat
import PagerComponent
import AppBundle
import PremiumUI
import AudioToolbox
import UndoUI
import ContextUI
import TelegramPresentationData
import TelegramNotices
import StickerPeekUI
import ChatInputNode
import TelegramUIPreferences
import MultiplexedVideoNode
import ChatControllerInteraction
import FeaturedStickersScreen
import Pasteboard
import EntityKeyboardGifContent
import LegacyMessageInputPanelInputView
import AttachmentTextInputPanelNode

public final class EmptyInputView: UIView, UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool {
        return true
    }
}

public struct ChatMediaInputPaneScrollState {
    let absoluteOffset: CGFloat?
    let relativeChange: CGFloat
}

public final class ChatEntityKeyboardInputNode: ChatInputNode {
    public final class Interaction {
        let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool
        let sendEmoji: (String, ChatTextInputTextCustomEmojiAttribute, Bool) -> Void
        let sendGif: (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool
        let sendBotContextResultAsGif: (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool, Bool) -> Bool
        let updateChoosingSticker: (Bool) -> Void
        let switchToTextInput: () -> Void
        let dismissTextInput: () -> Void
        let insertText: (NSAttributedString) -> Void
        let backwardsDeleteText: () -> Void
        let openStickerEditor: () -> Void
        let presentController: (ViewController, Any?) -> Void
        let presentGlobalOverlayController: (ViewController, Any?) -> Void
        let getNavigationController: () -> NavigationController?
        let requestLayout: (ContainedViewLayoutTransition) -> Void
        public var forceTheme: PresentationTheme?
        
        public init(
            sendSticker: @escaping (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool,
            sendEmoji: @escaping (String, ChatTextInputTextCustomEmojiAttribute, Bool) -> Void,
            sendGif: @escaping (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool,
            sendBotContextResultAsGif: @escaping (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool, Bool) -> Bool,
            updateChoosingSticker: @escaping (Bool) -> Void,
            switchToTextInput: @escaping () -> Void,
            dismissTextInput: @escaping () -> Void,
            insertText: @escaping (NSAttributedString) -> Void,
            backwardsDeleteText: @escaping () -> Void,
            openStickerEditor: @escaping () -> Void,
            presentController: @escaping (ViewController, Any?) -> Void,
            presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void,
            getNavigationController: @escaping () -> NavigationController?,
            requestLayout: @escaping (ContainedViewLayoutTransition) -> Void
        ) {
            self.sendSticker = sendSticker
            self.sendEmoji = sendEmoji
            self.sendGif = sendGif
            self.sendBotContextResultAsGif = sendBotContextResultAsGif
            self.updateChoosingSticker = updateChoosingSticker
            self.switchToTextInput = switchToTextInput
            self.dismissTextInput = dismissTextInput
            self.insertText = insertText
            self.backwardsDeleteText = backwardsDeleteText
            self.openStickerEditor = openStickerEditor
            self.presentController = presentController
            self.presentGlobalOverlayController = presentGlobalOverlayController
            self.getNavigationController = getNavigationController
            self.requestLayout = requestLayout
        }
        
        public init(chatControllerInteraction: ChatControllerInteraction, panelInteraction: ChatPanelInterfaceInteraction) {
            self.sendSticker = chatControllerInteraction.sendSticker
            self.sendEmoji = chatControllerInteraction.sendEmoji
            self.sendGif = chatControllerInteraction.sendGif
            self.sendBotContextResultAsGif = chatControllerInteraction.sendBotContextResultAsGif
            self.updateChoosingSticker = chatControllerInteraction.updateChoosingSticker
            self.switchToTextInput = { [weak chatControllerInteraction] in
                chatControllerInteraction?.updateInputMode { _ in
                    return .text
                }
            }
            self.dismissTextInput = chatControllerInteraction.dismissTextInput
            self.insertText = panelInteraction.insertText
            self.backwardsDeleteText = panelInteraction.backwardsDeleteText
            self.openStickerEditor = chatControllerInteraction.openStickerEditor
            self.presentController = chatControllerInteraction.presentController
            self.presentGlobalOverlayController = chatControllerInteraction.presentGlobalOverlayController
            self.getNavigationController = chatControllerInteraction.navigationController
            self.requestLayout = panelInteraction.requestLayout
        }
    }
    
    public struct InputData: Equatable {
        public var emoji: EmojiPagerContentComponent?
        public var stickers: EmojiPagerContentComponent?
        public var gifs: EntityKeyboardGifContent?
        public var availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji]
        
        public init(
            emoji: EmojiPagerContentComponent?,
            stickers: EmojiPagerContentComponent?,
            gifs: EntityKeyboardGifContent?,
            availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji]
        ) {
            self.emoji = emoji
            self.stickers = stickers
            self.gifs = gifs
            self.availableGifSearchEmojies = availableGifSearchEmojies
        }
    }
    
    public final class StateContext {
        let emojiState = EmojiPagerContentComponent.StateContext()
        
        public init() {
        }
    }
    
    public static func hasPremium(context: AccountContext, chatPeerId: EnginePeer.Id?, premiumIfSavedMessages: Bool) -> Signal<Bool, NoError> {
        let hasPremium: Signal<Bool, NoError>
        if premiumIfSavedMessages, let chatPeerId = chatPeerId, chatPeerId == context.account.peerId {
            hasPremium = .single(true)
        } else {
            hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            |> distinctUntilChanged
        }
        return hasPremium
    }
    
    public static func inputData(
        context: AccountContext,
        chatPeerId: PeerId?,
        areCustomEmojiEnabled: Bool,
        hasEdit: Bool = false,
        hasTrending: Bool = true,
        hasSearch: Bool = true,
        hasStickers: Bool = true,
        hasGifs: Bool = true,
        hideBackground: Bool = false,
        forceHasPremium: Bool = false,
        sendGif: ((FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool)?
    ) -> Signal<InputData, NoError> {
        let animationCache = context.animationCache
        let animationRenderer = context.animationRenderer
        
        let emojiItems = EmojiPagerContentComponent.emojiInputData(
            context: context,
            animationCache: animationCache,
            animationRenderer: animationRenderer,
            isStandalone: false,
            subject: .emoji,
            hasTrending: hasTrending,
            topReactionItems: [],
            areUnicodeEmojiEnabled: true,
            areCustomEmojiEnabled: areCustomEmojiEnabled,
            chatPeerId: chatPeerId,
            hasSearch: hasSearch,
            forceHasPremium: forceHasPremium,
            hideBackground: hideBackground
        )
        
        let stickerNamespaces: [ItemCollectionId.Namespace] = [Namespaces.ItemCollection.CloudStickerPacks]
        let stickerOrderedItemListCollectionIds: [Int32] = [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers]
                
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        
        let stickerItems: Signal<EmojiPagerContentComponent?, NoError>
        if hasStickers {
            stickerItems = EmojiPagerContentComponent.stickerInputData(
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                stickerNamespaces: stickerNamespaces,
                stickerOrderedItemListCollectionIds: stickerOrderedItemListCollectionIds,
                chatPeerId: chatPeerId,
                hasSearch: hasSearch,
                hasTrending: hasTrending,
                forceHasPremium: false,
                hasEdit: hasEdit,
                hasAdd: hasEdit,
                subject: .chatStickers,
                hideBackground: hideBackground
            )
            |> map(Optional.init)
        } else {
            stickerItems = .single(nil)
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
        
        let animatedEmojiStickers: Signal<[String: [StickerPackItem]], NoError>
        
        if hasGifs {
            animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
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
        } else {
            animatedEmojiStickers = .single([:])
        }
        
        let gifInputInteraction = GifPagerContentComponent.InputInteraction(
            performItemAction: { item, view, rect in
                if let sendGif {
                    let _ = sendGif(item.file, view, rect, false, false)
                }
            },
            openGifContextMenu: { _, _, _, _, _ in
            },
            loadMore: { _ in
            },
            openSearch: {
            },
            updateSearchQuery: { _ in
            },
            hideBackground: hideBackground,
            hasSearch: hasSearch
        )
        
        // We are going to subscribe to the actual data when the view is loaded
        let gifItems: Signal<EntityKeyboardGifContent?, NoError>
        if hasGifs {
            gifItems = .single(EntityKeyboardGifContent(
                hasRecentGifs: true,
                component: GifPagerContentComponent(
                    context: context,
                    inputInteraction: gifInputInteraction,
                    subject: .recent,
                    items: [],
                    isLoading: false,
                    loadMoreToken: nil,
                    displaySearchWithPlaceholder: nil,
                    searchCategories: nil,
                    searchInitiallyHidden: true,
                    searchState: .empty(hasResults: false),
                    hideBackground: hideBackground
                )
            ))
        } else {
            gifItems = .single(nil)
        }
        
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
                    var title: String?
                    switch reaction {
                        case "😡":
                            title = strings.Gif_Emotion_Angry
                        case "😮":
                            title = strings.Gif_Emotion_Surprised
                        case "😂":
                            title = strings.Gif_Emotion_Joy
                        case "😘":
                            title = strings.Gif_Emotion_Kiss
                        case "😍":
                            title = strings.Gif_Emotion_Hearts
                        case "👍":
                            title = strings.Gif_Emotion_ThumbsUp
                        case "👎":
                            title = strings.Gif_Emotion_ThumbsDown
                        case "🙄":
                            title = strings.Gif_Emotion_RollEyes
                        case "😎":
                            title = strings.Gif_Emotion_Cool
                        case "🥳":
                            title = strings.Gif_Emotion_Party
                        default:
                            break
                    }
                    
                    guard let title = title else {
                        continue
                    }
                    
                    availableGifSearchEmojies.append(EntityKeyboardComponent.GifSearchEmoji(emoji: reaction, file: file._parse(), title: title))
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
    private let stateContext: StateContext?
    private let entityKeyboardView: ComponentHostView<Empty>
    
    private let defaultToEmojiTab: Bool
    private var stableReorderableGroupOrder: [EntityKeyboardComponent.ReorderCategory: [ItemCollectionId]] = [:]
    private var currentInputData: InputData
    private var inputDataDisposable: Disposable?
    private var hasRecentGifsDisposable: Disposable?
    private let opaqueTopPanelBackground: Bool
    private let useOpaqueTheme: Bool
    
    private struct EmojiSearchResult {
        var groups: [EmojiPagerContentComponent.ItemGroup]
        var id: AnyHashable
        var version: Int
        var isPreset: Bool
    }
    
    private struct EmojiSearchState {
        var result: EmojiSearchResult?
        var isSearching: Bool
        
        init(result: EmojiSearchResult?, isSearching: Bool) {
            self.result = result
            self.isSearching = isSearching
        }
    }
    
    private let emojiSearchDisposable = MetaDisposable()
    private let emojiSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
    private var emojiSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
        didSet {
            self.emojiSearchState.set(.single(self.emojiSearchStateValue))
        }
    }
    
    private let stickerSearchDisposable = MetaDisposable()
    private let stickerSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
    private var stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
        didSet {
            self.stickerSearchState.set(.single(self.stickerSearchStateValue))
        }
    }
    
    private let interaction: ChatEntityKeyboardInputNode.Interaction?
    private var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    private let trendingGifsPromise = Promise<ChatMediaInputGifPaneTrendingState?>(nil)
    
    private var isMarkInputCollapsed: Bool = false
    
    private var isEmojiSearchActive: Bool = false {
        didSet {
            self.followsDefaultHeight = !self.isEmojiSearchActive
        }
    }
    
    fileprivate var clipContentToTopPanel: Bool = false
    
    public var externalTopPanelContainerImpl: PagerExternalTopPanelContainer?
    public override var externalTopPanelContainer: UIView? {
        return self.externalTopPanelContainerImpl
    }
    
    public var switchToTextInput: (() -> Void)?
    
    private var currentState: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool)?
    
    private var scheduledContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
    private var scheduledInnerTransition: ComponentTransition?
    
    private var gifMode: GifPagerContentComponent.Subject? {
        didSet {
            if let gifMode = self.gifMode, gifMode != oldValue {
                self.reloadGifContext()
            }
        }
    }
    
    public var canSwitchToTextInputAutomatically: Bool {
        if let pagerView = self.entityKeyboardView.componentView as? EntityKeyboardComponent.View, let centralId = pagerView.centralId {
            if centralId == AnyHashable("emoji") {
                return false
            }
        }
        return true
    }
        
    public var useExternalSearchContainer: Bool = false
        
    private var gifContext: GifContext? {
        didSet {
            if let gifContext = self.gifContext {
                self.gifComponent.set(gifContext.component)
            }
        }
    }
    private let gifComponent = Promise<EntityKeyboardGifContent>()
    private var gifInputInteraction: GifPagerContentComponent.InputInteraction?
    
    fileprivate var emojiInputInteraction: EmojiPagerContentComponent.InputInteraction?
    private var stickerInputInteraction: EmojiPagerContentComponent.InputInteraction?
    
    private weak var currentUndoOverlayController: UndoOverlayController?
    
    private var choosingStickerDisposable: Disposable?
    private var scrollingStickersGridPromise = Promise<Bool>(false)
    private var previewingStickersPromise = ValuePromise<Bool>(false)
    private var choosingSticker: Signal<Bool, NoError> {
        return combineLatest(self.scrollingStickersGridPromise.get(), self.previewingStickersPromise.get())
        |> map { scrollingStickersGrid, previewingStickers -> Bool in
            return scrollingStickersGrid || previewingStickers
        }
        |> distinctUntilChanged
    }
    
    public init(context: AccountContext, currentInputData: InputData, updatedInputData: Signal<InputData, NoError>, defaultToEmojiTab: Bool, opaqueTopPanelBackground: Bool = false, useOpaqueTheme: Bool = false, interaction: ChatEntityKeyboardInputNode.Interaction?, chatPeerId: PeerId?, stateContext: StateContext?, forceHasPremium: Bool = false) {
        self.context = context
        self.currentInputData = currentInputData
        self.defaultToEmojiTab = defaultToEmojiTab
        self.opaqueTopPanelBackground = opaqueTopPanelBackground
        self.useOpaqueTheme = useOpaqueTheme
        self.stateContext = stateContext
        
        self.interaction = interaction
        
        self.entityKeyboardView = ComponentHostView<Empty>()
        
        super.init()
        
        self.currentInputData = self.processInputData(inputData: self.currentInputData)
        
        self.topBackgroundExtension = 34.0
        self.followsDefaultHeight = true
        
        self.view.addSubview(self.entityKeyboardView)
        
        self.externalTopPanelContainerImpl = PagerExternalTopPanelContainer()
        
        var stickerPeekBehavior: EmojiContentPeekBehaviorImpl?
        if let interaction {
            let context = self.context
            
            stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                context: self.context,
                interaction: EmojiContentPeekBehaviorImpl.Interaction(
                    sendSticker: interaction.sendSticker,
                    sendEmoji: { file in
                        var text = "."
                        var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, displayText, stickerPackReference):
                                text = displayText
                                
                                var packId: ItemCollectionId?
                                if case let .id(id, _) = stickerPackReference {
                                    packId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id)
                                }
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: packId, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                        
                        if let emojiAttribute {
                            interaction.sendEmoji(text, emojiAttribute, true)
                        }
                    },
                    setStatus: { [weak self] file in
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf.context.engine.accountData.setEmojiStatus(file: file, expirationDate: nil).start()
                        
                        var animateInAsReplacement = false
                        if let currentUndoOverlayController = strongSelf.currentUndoOverlayController {
                            currentUndoOverlayController.dismissWithCommitActionAndReplacementAnimation()
                            strongSelf.currentUndoOverlayController = nil
                            animateInAsReplacement = true
                        }
                                                    
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        
                        let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.EmojiStatus_AppliedText, undoText: nil, customAction: nil), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in return false })
                        strongSelf.currentUndoOverlayController = controller
                        interaction.presentController(controller, nil)
                    },
                    copyEmoji: { [weak self] file in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        var text = "."
                        var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, displayText, _):
                                text = displayText
                                
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                        
                        if let _ = emojiAttribute {
                            storeMessageTextInPasteboard(text, entities: [MessageTextEntity(range: 0 ..< (text as NSString).length, type: .CustomEmoji(stickerPack: nil, fileId: file.fileId.id))])
                            
                            var animateInAsReplacement = false
                            if let currentUndoOverlayController = strongSelf.currentUndoOverlayController {
                                currentUndoOverlayController.dismissWithCommitActionAndReplacementAnimation()
                                strongSelf.currentUndoOverlayController = nil
                                animateInAsReplacement = true
                            }
                                                        
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            
                            let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.Conversation_EmojiCopied, undoText: nil, customAction: nil), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in return false })
                            strongSelf.currentUndoOverlayController = controller
                            interaction.presentController(controller, nil)
                        }
                    },
                    presentController: interaction.presentController,
                    presentGlobalOverlayController: interaction.presentGlobalOverlayController,
                    navigationController: interaction.getNavigationController,
                    updateIsPreviewing: { [weak self] value in
                        self?.previewingStickersPromise.set(value)
                    }
                ),
                chatPeerId: chatPeerId,
                present: { c, a in
                    interaction.presentGlobalOverlayController(c, a)
                }
            )
        }
        
        var premiumToastCounter = 0
        self.emojiInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak self, weak interaction] groupId, item, _, _, _, _ in
                let _ = (
                combineLatest(
                    ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: chatPeerId, premiumIfSavedMessages: true),
                    ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: chatPeerId, premiumIfSavedMessages: false)
                )
                |> take(1)
                |> deliverOnMainQueue).start(next: { hasPremium, hasGlobalPremium in
                    guard let strongSelf = self, let interaction else {
                        return
                    }
                    
                    if groupId == AnyHashable("featuredTop"), let file = item.itemFile {
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                        let _ = (combineLatest(
                            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                            context.account.postbox.combinedView(keys: [viewKey])
                        )
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak interaction] emojiPacksView, views in
                            guard let interaction else {
                                return
                            }
                            guard let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            guard let self else {
                                return
                            }
                            
                            let _ = interaction
                            
                            var installedCollectionIds = Set<ItemCollectionId>()
                            for (id, _, _) in emojiPacksView.collectionInfos {
                                installedCollectionIds.insert(id)
                            }
                            
                            let stickerPacks = view.items.map({ $0.contents.get(FeaturedStickerPackItem.self)! }).filter({
                                !installedCollectionIds.contains($0.info.id)
                            })
                            
                            for featuredStickerPack in stickerPacks {
                                if featuredStickerPack.topItems.contains(where: { $0.file.fileId == file.fileId }) {
                                    if let pagerView = self.entityKeyboardView.componentView as? EntityKeyboardComponent.View, let emojiInputInteraction = self.emojiInputInteraction {
                                        pagerView.openCustomSearch(content: EmojiSearchContent(
                                            context: self.context,
                                            forceTheme: self.interaction?.forceTheme,
                                            items: stickerPacks,
                                            initialFocusId: featuredStickerPack.info.id,
                                            hasPremiumForUse: hasPremium,
                                            hasPremiumForInstallation: hasGlobalPremium,
                                            parentInputInteraction: emojiInputInteraction
                                        ))
                                    }
                                    break
                                }
                            }
                        })
                    } else if let file = item.itemFile?._parse() {
                        var text = "."
                        var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, displayText, _):
                                text = displayText
                                
                                var packId: ItemCollectionId?
                                if let id = groupId.base as? ItemCollectionId {
                                    packId = id
                                }
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: packId, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                        
                        if file.isPremiumEmoji && !hasPremium && groupId != AnyHashable("peerSpecific") && !forceHasPremium {
                            var animateInAsReplacement = false
                            if let currentUndoOverlayController = strongSelf.currentUndoOverlayController {
                                currentUndoOverlayController.dismissWithCommitActionAndReplacementAnimation()
                                strongSelf.currentUndoOverlayController = nil
                                animateInAsReplacement = true
                            }
                                                        
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            
                            premiumToastCounter += 1
                            var suggestSavedMessages = premiumToastCounter % 2 == 0
                            if chatPeerId == nil {
                                suggestSavedMessages = false
                            }
                            let text: String
                            let actionTitle: String
                            if suggestSavedMessages {
                                text = presentationData.strings.EmojiInput_PremiumEmojiToast_TryText
                                actionTitle = presentationData.strings.EmojiInput_PremiumEmojiToast_TryAction
                            } else {
                                text = presentationData.strings.EmojiInput_PremiumEmojiToast_Text
                                actionTitle = presentationData.strings.EmojiInput_PremiumEmojiToast_Action
                            }
                            
                            let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: text, undoText: actionTitle, customAction: { [weak interaction] in
                                guard let interaction else {
                                    return
                                }
                                
                                if suggestSavedMessages {
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                    |> deliverOnMainQueue).start(next: { peer in
                                        guard let peer = peer, let navigationController = interaction.getNavigationController() else {
                                            return
                                        }
                                        
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                            navigationController: navigationController,
                                            chatController: nil,
                                            context: context,
                                            chatLocation: .peer(peer),
                                            subject: nil,
                                            updateTextInputState: nil,
                                            activateInput: .entityInput,
                                            keepStack: .always,
                                            completion: { _ in
                                            })
                                        )
                                    })
                                } else {
                                    var replaceImpl: ((ViewController) -> Void)?
                                    let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                                        let controller = PremiumIntroScreen(context: context, source: .animatedEmoji)
                                        replaceImpl?(controller)
                                    })
                                    replaceImpl = { [weak controller] c in
                                        controller?.replace(with: c)
                                    }
                                    interaction.getNavigationController()?.pushViewController(controller)
                                }
                            }), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in return false })
                            strongSelf.currentUndoOverlayController = controller
                            interaction.presentController(controller, nil)
                            return
                        }
                        
                        if let emojiAttribute = emojiAttribute {
                            AudioServicesPlaySystemSound(0x450)
                            interaction.insertText(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute]))
                        }
                    } else if case let .staticEmoji(staticEmoji) = item.content {
                        AudioServicesPlaySystemSound(0x450)
                        interaction.insertText(NSAttributedString(string: staticEmoji, attributes: [:]))
                    }
                })
            },
            deleteBackwards: { [weak interaction] in
                if let interaction {
                    interaction.backwardsDeleteText()
                }
            },
            openStickerSettings: {
            },
            openFeatured: {
            },
            openSearch: {
            },
            addGroupAction: { [weak self, weak interaction] groupId, isPremiumLocked, scrollToGroup in
                guard let interaction, let collectionId = groupId.base as? ItemCollectionId else {
                    return
                }
                
                if isPremiumLocked {
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                        let controller = PremiumIntroScreen(context: context, source: .animatedEmoji)
                        replaceImpl?(controller)
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    interaction.getNavigationController()?.pushViewController(controller)
                    
                    return
                }
                
                let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                let _ = (context.account.postbox.combinedView(keys: [viewKey])
                |> take(1)
                |> deliverOnMainQueue).start(next: { views in
                    guard let view = views.views[viewKey] as? OrderedItemListView else {
                        return
                    }
                    for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                        if featuredEmojiPack.info.id == collectionId {
                            if let strongSelf = self {
                                strongSelf.scheduledContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupInstalled(id: collectionId, scrollToGroup: scrollToGroup))
                            }
                            let _ = context.engine.stickers.addStickerPackInteractively(info: featuredEmojiPack.info._parse(), items: featuredEmojiPack.topItems).start()
                            
                            break
                        }
                    }
                })
            },
            clearGroup: { [weak interaction] groupId in
                guard let interaction else {
                    return
                }
                if groupId == AnyHashable("recent") {
                    interaction.dismissTextInput()
                    var presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    if let forceTheme = interaction.forceTheme {
                        presentationData = presentationData.withUpdated(theme: forceTheme)
                    }
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Emoji_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = context.engine.stickers.clearRecentlyUsedEmoji().start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    interaction.presentController(actionSheet, nil)
                } else if groupId == AnyHashable("featuredTop") {
                    let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                    let _ = (context.account.postbox.combinedView(keys: [viewKey])
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { views in
                        guard let view = views.views[viewKey] as? OrderedItemListView else {
                            return
                        }
                        var emojiPackIds: [Int64] = []
                        for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                            emojiPackIds.append(featuredEmojiPack.info.id.id)
                        }
                        let _ = ApplicationSpecificNotice.setDismissedTrendingEmojiPacks(accountManager: context.sharedContext.accountManager, values: emojiPackIds).start()
                    })
                }
            },
            editAction: { _ in },
            pushController: { [weak interaction] controller in
                guard let interaction else {
                    return
                }
                interaction.getNavigationController()?.pushViewController(controller)
            },
            presentController: { [weak interaction] controller in
                guard let interaction else {
                    return
                }
                interaction.presentController(controller, nil)
            },
            presentGlobalOverlayController: { [weak interaction] controller in
                guard let interaction else {
                    return
                }
                interaction.presentGlobalOverlayController(controller, nil)
            },
            navigationController: { [weak interaction] in
                return interaction?.getNavigationController()
            },
            requestUpdate: { [weak self] transition in
                guard let strongSelf = self else {
                    return
                }
                if !transition.animation.isImmediate {
                    strongSelf.interaction?.requestLayout(transition.containedViewLayoutTransition)
                }
            },
            updateSearchQuery: { [weak self] query in
                guard let self = self else {
                    return
                }
                
                switch query {
                case .none:
                    self.emojiSearchDisposable.set(nil)
                    self.emojiSearchState.set(.single(EmojiSearchState(result: nil, isSearching: false)))
                case let .text(rawQuery, languageCode):
                    let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if query.isEmpty {
                        self.emojiSearchDisposable.set(nil)
                        self.emojiSearchState.set(.single(EmojiSearchState(result: nil, isSearching: false)))
                    } else {
                        let context = self.context
                        
                        var signal = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query, completeMatch: false)
                        if !languageCode.lowercased().hasPrefix("en") {
                            signal = signal
                            |> mapToSignal { keywords in
                                return .single(keywords)
                                |> then(
                                    context.engine.stickers.searchEmojiKeywords(inputLanguageCode: "en-US", query: query, completeMatch: query.count < 3)
                                    |> map { englishKeywords in
                                        return keywords + englishKeywords
                                    }
                                )
                            }
                        }
                    
                        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> map { peer -> Bool in
                            guard case let .user(user) = peer else {
                                return false
                            }
                            return user.isPremium
                        }
                        |> distinctUntilChanged
                        
                        let resultSignal = combineLatest(
                            signal,
                            hasPremium
                        )
                        |> mapToSignal { keywords, hasPremium -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                            var allEmoticons: [String: String] = [:]
                            for keyword in keywords {
                                for emoticon in keyword.emoticons {
                                    allEmoticons[emoticon] = keyword.keyword
                                }
                            }
                            let remoteSignal: Signal<(items: [TelegramMediaFile], isFinalResult: Bool), NoError>
                            let remotePacksSignal: Signal<(sets: FoundStickerSets, isFinalResult: Bool), NoError>
                            if hasPremium {
                                remoteSignal = context.engine.stickers.searchEmoji(query: query, emoticon: Array(allEmoticons.keys), inputLanguageCode: languageCode)
                                remotePacksSignal = context.engine.stickers.searchEmojiSets(query: query)
                                |> mapToSignal { localResult in
                                    return .single((localResult, false))
                                    |> then(
                                        context.engine.stickers.searchEmojiSetsRemotely(query: query)
                                        |> map { remoteResult in
                                            return (localResult.merge(with: remoteResult), true)
                                        }
                                    )
                                }
                            } else {
                                remoteSignal = .single(([], true))
                                remotePacksSignal = .single((FoundStickerSets(), true))
                            }
                            return combineLatest(remoteSignal, remotePacksSignal)
                            |> mapToSignal { foundEmoji, foundPacks -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                if foundEmoji.items.isEmpty && !foundEmoji.isFinalResult {
                                    return .complete()
                                }
                                var items: [EmojiPagerContentComponent.Item] = []
                                
                                let appendUnicodeEmoji = {
                                    for (_, list) in EmojiPagerContentComponent.staticEmojiMapping {
                                        for emojiString in list {
                                            if allEmoticons[emojiString] != nil {
                                                let item = EmojiPagerContentComponent.Item(
                                                    animationData: nil,
                                                    content: .staticEmoji(emojiString),
                                                    itemFile: nil,
                                                    subgroupId: nil,
                                                    icon: .none,
                                                    tintMode: .none
                                                )
                                                items.append(item)
                                            }
                                        }
                                    }
                                }
                                
                                if !hasPremium {
                                    appendUnicodeEmoji()
                                }
                                
                                var existingIds = Set<MediaId>()
                                for itemFile in foundEmoji.items {
                                    if existingIds.contains(itemFile.fileId) {
                                        continue
                                    }
                                    existingIds.insert(itemFile.fileId)
                                    if itemFile.isPremiumEmoji && !hasPremium {
                                        continue
                                    }
                                    let animationData = EntityKeyboardAnimationData(file: TelegramMediaFile.Accessor(itemFile))
                                    let item = EmojiPagerContentComponent.Item(
                                        animationData: animationData,
                                        content: .animation(animationData),
                                        itemFile: TelegramMediaFile.Accessor(itemFile),
                                        subgroupId: nil,
                                        icon: .none,
                                        tintMode: animationData.isTemplate ? .primary : .none
                                    )
                                    items.append(item)
                                }
                                
                                if hasPremium {
                                    appendUnicodeEmoji()
                                }
                                
                                var resultGroups: [EmojiPagerContentComponent.ItemGroup] = []
                                resultGroups.append(EmojiPagerContentComponent.ItemGroup(
                                    supergroupId: "search",
                                    groupId: "search",
                                    title: nil,
                                    subtitle: nil,
                                    badge: nil,
                                    actionButtonTitle: nil,
                                    isFeatured: false,
                                    isPremiumLocked: false,
                                    isEmbedded: false,
                                    hasClear: false,
                                    hasEdit: false,
                                    collapsedLineCount: nil,
                                    displayPremiumBadges: false,
                                    headerItem: nil,
                                    fillWithLoadingPlaceholders: false,
                                    items: items
                                ))
                                
                                for (collectionId, info, _, _) in foundPacks.sets.infos {
                                    if let info = info as? StickerPackCollectionInfo {
                                        var topItems: [StickerPackItem] = []
                                        for e in foundPacks.sets.entries {
                                            if let item = e.item as? StickerPackItem {
                                                if e.index.collectionId == collectionId {
                                                    topItems.append(item)
                                                }
                                            }
                                        }
                                        
                                        var groupItems: [EmojiPagerContentComponent.Item] = []
                                        for item in topItems {
                                            var tintMode: EmojiPagerContentComponent.Item.TintMode = .none
                                            if item.file.isCustomTemplateEmoji {
                                                tintMode = .primary
                                            }
                                            
                                            let animationData = EntityKeyboardAnimationData(file: item.file)
                                            let resultItem = EmojiPagerContentComponent.Item(
                                                animationData: animationData,
                                                content: .animation(animationData),
                                                itemFile: item.file,
                                                subgroupId: nil,
                                                icon: .none,
                                                tintMode: tintMode
                                            )
                                            
                                            groupItems.append(resultItem)
                                        }
                                        
                                        resultGroups.append(EmojiPagerContentComponent.ItemGroup(
                                            supergroupId: AnyHashable(info.id),
                                            groupId: AnyHashable(info.id),
                                            title: info.title,
                                            subtitle: nil,
                                            badge: nil,
                                            actionButtonTitle: nil,
                                            isFeatured: false,
                                            isPremiumLocked: false,
                                            isEmbedded: false,
                                            hasClear: false,
                                            hasEdit: false,
                                            collapsedLineCount: 3,
                                            displayPremiumBadges: false,
                                            headerItem: nil,
                                            fillWithLoadingPlaceholders: false,
                                            items: groupItems
                                        ))
                                    }
                                }
                            
                                return .single(resultGroups)
                            }
                        }
                        
                        var version = 0
                        self.emojiSearchStateValue.isSearching = true
                        self.emojiSearchDisposable.set((resultSignal
                        |> delay(0.15, queue: .mainQueue())
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let self else {
                                return
                            }
                            
                            self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result, id: AnyHashable(query), version: version, isPreset: false), isSearching: false)
                            version += 1
                        }))
                    }
                case let .category(value):
                    let resultSignal = self.context.engine.stickers.searchEmoji(category: value)
                    |> mapToSignal { files, isFinalResult -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                        var items: [EmojiPagerContentComponent.Item] = []
                        
                        var existingIds = Set<MediaId>()
                        for itemFile in files {
                            if existingIds.contains(itemFile.fileId) {
                                continue
                            }
                            existingIds.insert(itemFile.fileId)
                            let animationData = EntityKeyboardAnimationData(file: TelegramMediaFile.Accessor(itemFile))
                            let item = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: TelegramMediaFile.Accessor(itemFile),
                                subgroupId: nil,
                                icon: .none,
                                tintMode: animationData.isTemplate ? .primary : .none
                            )
                            items.append(item)
                        }
                        
                        return .single(([EmojiPagerContentComponent.ItemGroup(
                            supergroupId: "search",
                            groupId: "search",
                            title: nil,
                            subtitle: nil,
                            badge: nil,
                            actionButtonTitle: nil,
                            isFeatured: false,
                            isPremiumLocked: false,
                            isEmbedded: false,
                            hasClear: false,
                            hasEdit: false,
                            collapsedLineCount: nil,
                            displayPremiumBadges: false,
                            headerItem: nil,
                            fillWithLoadingPlaceholders: false,
                            items: items
                        )], isFinalResult))
                    }
                        
                    var version = 0
                    self.emojiSearchDisposable.set((resultSignal
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let self else {
                            return
                        }
                        
                        guard let group = result.items.first else {
                            return
                        }
                        if group.items.isEmpty && !result.isFinalResult {
                            self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: [
                                EmojiPagerContentComponent.ItemGroup(
                                    supergroupId: "search",
                                    groupId: "search",
                                    title: nil,
                                    subtitle: nil,
                                    badge: nil,
                                    actionButtonTitle: nil,
                                    isFeatured: false,
                                    isPremiumLocked: false,
                                    isEmbedded: false,
                                    hasClear: false,
                                    hasEdit: false,
                                    collapsedLineCount: nil,
                                    displayPremiumBadges: false,
                                    headerItem: nil,
                                    fillWithLoadingPlaceholders: true,
                                    items: []
                                )
                            ], id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                            return
                        }
                        self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                        version += 1
                    }))
                }
            },
            updateScrollingToItemGroup: {
            },
            onScroll: {},
            chatPeerId: chatPeerId,
            peekBehavior: stickerPeekBehavior,
            customLayout: nil,
            externalBackground: nil,
            externalExpansionView: nil,
            customContentView: nil,
            useOpaqueTheme: self.useOpaqueTheme,
            hideBackground: false,
            stateContext: self.stateContext?.emojiState,
            addImage: nil
        )
        
        self.stickerInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interaction] groupId, item, view, rect, layer, _ in
                let _ = (ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: chatPeerId, premiumIfSavedMessages: false) |> take(1) |> deliverOnMainQueue).start(next: { hasPremium in
                    guard let interaction else {
                        return
                    }
                    guard let file = item.itemFile?._parse() else {
                        if case .icon(.add) = item.content {
                            interaction.openStickerEditor()
                        }
                        return
                    }
                    
                    if groupId == AnyHashable("featuredTop") {
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                        let _ = (context.account.postbox.combinedView(keys: [viewKey])
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak interaction] views in
                            guard let interaction else {
                                return
                            }
                            guard let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                                if featuredStickerPack.topItems.contains(where: { $0.file.fileId == file.fileId }) {
                                    interaction.getNavigationController()?.pushViewController(FeaturedStickersScreen(
                                        context: context,
                                        highlightedPackId: featuredStickerPack.info.id,
                                        forceTheme: interaction.forceTheme,
                                        sendSticker: { [weak interaction] fileReference, sourceNode, sourceRect in
                                            guard let interaction else {
                                                return false
                                            }
                                            return interaction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect, nil, [])
                                        }
                                    ))
                                    
                                    break
                                }
                            }
                        })
                    } else {
                        if file.isPremiumSticker && !hasPremium {
                            let controller = PremiumIntroScreen(context: context, source: .stickers)
                            interaction.getNavigationController()?.pushViewController(controller)
                            
                            return
                        }
                        var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
                        if let id = groupId.base as? ItemCollectionId, context.sharedContext.currentStickerSettings.with({ $0 }).dynamicPackOrder {
                            bubbleUpEmojiOrStickersets.append(id)
                        }
                        
                        let reference: FileMediaReference
                        if groupId == AnyHashable("saved") {
                            reference = .savedSticker(media: file)
                        } else if groupId == AnyHashable("recent") {
                            reference = .recentSticker(media: file)
                        } else {
                            reference = .standalone(media: file)
                        }
                        let _ = interaction.sendSticker(reference, false, false, nil, false, view, rect, layer, bubbleUpEmojiOrStickersets)
                    }
                })
            },
            deleteBackwards: { [weak interaction] in
                if let interaction {
                    interaction.backwardsDeleteText()
                }
            },
            openStickerSettings: { [weak interaction] in
                guard let interaction else {
                    return
                }
                let controller = context.sharedContext.makeInstalledStickerPacksController(context: context, mode: .modal, forceTheme: interaction.forceTheme)
                controller.navigationPresentation = .modal
                interaction.getNavigationController()?.pushViewController(controller)
            },
            openFeatured: { [weak interaction] in
                guard let interaction else {
                    return
                }

                interaction.getNavigationController()?.pushViewController(FeaturedStickersScreen(
                    context: context,
                    highlightedPackId: nil,
                    forceTheme: interaction.forceTheme,
                    sendSticker: { [weak interaction] fileReference, sourceNode, sourceRect in
                        guard let interaction else {
                            return false
                        }
                        return interaction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect, nil, [])
                    }
                ))
            },
            openSearch: { [weak self] in
                if let strongSelf = self, let pagerView = strongSelf.entityKeyboardView.componentView as? EntityKeyboardComponent.View {
                    pagerView.openSearch()
                }
            },
            addGroupAction: { [weak interaction] groupId, isPremiumLocked, _ in
                guard let interaction, let collectionId = groupId.base as? ItemCollectionId else {
                    return
                }
                
                if isPremiumLocked {
                    let controller = PremiumIntroScreen(context: context, source: .stickers)
                    interaction.getNavigationController()?.pushViewController(controller)
                    
                    return
                }
                
                let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                let _ = (context.account.postbox.combinedView(keys: [viewKey])
                |> take(1)
                |> deliverOnMainQueue).start(next: { views in
                    guard let view = views.views[viewKey] as? OrderedItemListView else {
                        return
                    }
                    for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                        if featuredStickerPack.info.id == collectionId {
                            let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: featuredStickerPack.info.id.id, accessHash: featuredStickerPack.info.accessHash), forceActualized: false)
                            |> mapToSignal { result -> Signal<Void, NoError> in
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
                            }
                            |> deliverOnMainQueue).start(completed: {
                            })
                            
                            break
                        }
                    }
                })
            },
            clearGroup: { [weak interaction] groupId in
                guard let interaction else {
                    return
                }
                if groupId == AnyHashable("recent") {
                    interaction.dismissTextInput()
                    var presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    if let forceTheme = interaction.forceTheme {
                        presentationData = presentationData.withUpdated(theme: forceTheme)
                    }
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = context.engine.stickers.clearRecentlyUsedStickers().start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    interaction.presentController(actionSheet, nil)
                } else if groupId == AnyHashable("featuredTop") {
                    let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                    let _ = (context.account.postbox.combinedView(keys: [viewKey])
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { views in
                        guard let view = views.views[viewKey] as? OrderedItemListView else {
                            return
                        }
                        var stickerPackIds: [Int64] = []
                        for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                            stickerPackIds.append(featuredStickerPack.info.id.id)
                        }
                        let _ = ApplicationSpecificNotice.setDismissedTrendingStickerPacks(accountManager: context.sharedContext.accountManager, values: stickerPackIds).start()
                    })
                } else if groupId == AnyHashable("peerSpecific") {
                }
            },
            editAction: { [weak interaction] groupId in
                guard let collectionId = groupId.base as? ItemCollectionId else {
                    return
                }
                let viewKey = PostboxViewKey.itemCollectionInfo(id: collectionId)
                let _ = (context.account.postbox.combinedView(keys: [viewKey])
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak interaction] views in
                    guard let interaction, let view = views.views[viewKey] as? ItemCollectionInfoView, let info = view.info as? StickerPackCollectionInfo else {
                        return
                    }
                    let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                    let controller = context.sharedContext.makeStickerPackScreen(
                        context: context,
                        updatedPresentationData: nil,
                        mainStickerPack: packReference,
                        stickerPacks: [packReference],
                        loadedStickerPacks: [],
                        actionTitle: nil,
                        isEditing: true,
                        expandIfNeeded: true,
                        parentNavigationController: interaction.getNavigationController(),
                        sendSticker: { [weak interaction] fileReference, sourceView, sourceRect in
                            return interaction?.sendSticker(fileReference, false, false, nil, false, sourceView, sourceRect, nil, []) ?? false
                        },
                        actionPerformed: nil
                    )
                    interaction.presentController(controller, nil)
                })
            },
            pushController: { [weak interaction] controller in
                guard let interaction else {
                    return
                }
                interaction.getNavigationController()?.pushViewController(controller)
            },
            presentController: { [weak interaction] controller in
                guard let interaction else {
                    return
                }
                interaction.presentController(controller, nil)
            },
            presentGlobalOverlayController: { [weak interaction] controller in
                guard let interaction else {
                    return
                }
                interaction.presentGlobalOverlayController(controller, nil)
            },
            navigationController: { [weak interaction] in
                return interaction?.getNavigationController()
            },
            requestUpdate: { _ in
            },
            updateSearchQuery: { [weak self] query in
                guard let strongSelf = self else {
                    return
                }
                
                switch query {
                case .none:
                    strongSelf.stickerSearchDisposable.set(nil)
                    strongSelf.stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false)
                case .text:
                    strongSelf.stickerSearchDisposable.set(nil)
                    strongSelf.stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false)
                case let .category(value):
                    let resultSignal = strongSelf.context.engine.stickers.searchStickers(category: value, scope: [.installed, .remote])
                    |> mapToSignal { files -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                        var items: [EmojiPagerContentComponent.Item] = []
                        
                        var existingIds = Set<MediaId>()
                        for item in files.items {
                            let itemFile = item.file
                            if existingIds.contains(itemFile.fileId) {
                                continue
                            }
                            existingIds.insert(itemFile.fileId)
                            let animationData = EntityKeyboardAnimationData(file: TelegramMediaFile.Accessor(itemFile))
                            let item = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: TelegramMediaFile.Accessor(itemFile),
                                subgroupId: nil,
                                icon: itemFile.isPremiumSticker ? .premium : .none,
                                tintMode: animationData.isTemplate ? .primary : .none
                            )
                            items.append(item)
                        }
                        
                        return .single(([EmojiPagerContentComponent.ItemGroup(
                            supergroupId: "search",
                            groupId: "search",
                            title: nil,
                            subtitle: nil,
                            badge: nil,
                            actionButtonTitle: nil,
                            isFeatured: false,
                            isPremiumLocked: false,
                            isEmbedded: false,
                            hasClear: false,
                            hasEdit: false,
                            collapsedLineCount: nil,
                            displayPremiumBadges: false,
                            headerItem: nil,
                            fillWithLoadingPlaceholders: false,
                            items: items
                        )], files.isFinalResult))
                    }
                        
                    var version = 0
                    strongSelf.stickerSearchDisposable.set((resultSignal
                    |> deliverOnMainQueue).start(next: { result in
                        guard let strongSelf = self else {
                            return
                        }
                        guard let group = result.items.first else {
                            return
                        }
                        if group.items.isEmpty && !result.isFinalResult {
                            //strongSelf.stickerSearchStateValue.isSearching = true
                            strongSelf.stickerSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: [
                                EmojiPagerContentComponent.ItemGroup(
                                    supergroupId: "search",
                                    groupId: "search",
                                    title: nil,
                                    subtitle: nil,
                                    badge: nil,
                                    actionButtonTitle: nil,
                                    isFeatured: false,
                                    isPremiumLocked: false,
                                    isEmbedded: false,
                                    hasClear: false,
                                    hasEdit: false,
                                    collapsedLineCount: nil,
                                    displayPremiumBadges: false,
                                    headerItem: nil,
                                    fillWithLoadingPlaceholders: true,
                                    items: []
                                )
                            ], id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                            return
                        }
                        strongSelf.stickerSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value.id), version: version, isPreset: true), isSearching: false)
                        version += 1
                    }))
                }
            },
            updateScrollingToItemGroup: {
            },
            onScroll: {},
            chatPeerId: chatPeerId,
            peekBehavior: stickerPeekBehavior,
            customLayout: nil,
            externalBackground: nil,
            externalExpansionView: nil,
            customContentView: nil,
            useOpaqueTheme: self.useOpaqueTheme,
            hideBackground: false,
            stateContext: nil,
            addImage: nil
        )
                
        self.inputDataDisposable = (combineLatest(queue: .mainQueue(),
            updatedInputData,
            .single(self.currentInputData.gifs) |> then(self.gifComponent.get() |> map(Optional.init)),
            self.emojiSearchState.get(),
            self.stickerSearchState.get()
        )
        |> deliverOnMainQueue).start(next: { [weak self] inputData, gifs, emojiSearchState, stickerSearchState in
            guard let strongSelf = self else {
                return
            }
            var inputData = inputData
            inputData.gifs = gifs
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            if let emojiSearchResult = emojiSearchState.result {
                var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                    emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                        text: presentationData.strings.EmojiSearch_SearchEmojiEmptyResult,
                        iconFile: nil
                    )
                }
                if let emoji = inputData.emoji {
                    let defaultSearchState: EmojiPagerContentComponent.SearchState = emojiSearchResult.isPreset ? .active : .empty(hasResults: true)
                    inputData.emoji = emoji.withUpdatedItemGroups(panelItemGroups: emoji.panelItemGroups, contentItemGroups: emojiSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: emojiSearchResult.id, version: emojiSearchResult.version), emptySearchResults: emptySearchResults, searchState: emojiSearchState.isSearching ? .searching : defaultSearchState)
                }
            } else if emojiSearchState.isSearching {
                if let emoji = inputData.emoji {
                    inputData.emoji = emoji.withUpdatedItemGroups(panelItemGroups: emoji.panelItemGroups, contentItemGroups: emoji.contentItemGroups, itemContentUniqueId: emoji.itemContentUniqueId, emptySearchResults: emoji.emptySearchResults, searchState: .searching)
                }
            }
            
            if let stickerSearchResult = stickerSearchState.result {
                var stickerSearchResults: EmojiPagerContentComponent.EmptySearchResults?
                if !stickerSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                    stickerSearchResults = EmojiPagerContentComponent.EmptySearchResults(
                        text: presentationData.strings.EmojiSearch_SearchStickersEmptyResult,
                        iconFile: nil
                    )
                }
                if let stickers = inputData.stickers {
                    let defaultSearchState: EmojiPagerContentComponent.SearchState = stickerSearchResult.isPreset ? .active : .empty(hasResults: true)
                    inputData.stickers = stickers.withUpdatedItemGroups(panelItemGroups: stickers.panelItemGroups, contentItemGroups: stickerSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: stickerSearchResult.id, version: stickerSearchResult.version), emptySearchResults: stickerSearchResults, searchState: stickerSearchState.isSearching ? .searching : defaultSearchState)
                }
            } else if stickerSearchState.isSearching {
                if let stickers = inputData.stickers {
                    inputData.stickers = stickers.withUpdatedItemGroups(panelItemGroups: stickers.panelItemGroups, contentItemGroups: stickers.contentItemGroups, itemContentUniqueId: stickers.itemContentUniqueId, emptySearchResults: stickers.emptySearchResults, searchState: .searching)
                }
            }
            
            var transition: ComponentTransition = .immediate
            var useAnimation = false
            
            if let pagerView = strongSelf.entityKeyboardView.componentView as? EntityKeyboardComponent.View, let centralId = pagerView.centralId {
                if centralId == AnyHashable("emoji") {
                    useAnimation = strongSelf.currentInputData.emoji != inputData.emoji
                } else if centralId == AnyHashable("stickers"),  strongSelf.currentInputData.stickers != nil, inputData.stickers != nil {
                    useAnimation = strongSelf.currentInputData.stickers != inputData.stickers
                }
            }
            
            if useAnimation {
                let contentAnimation: EmojiPagerContentComponent.ContentAnimation
                if let scheduledContentAnimationHint = strongSelf.scheduledContentAnimationHint {
                    strongSelf.scheduledContentAnimationHint = nil
                    contentAnimation = scheduledContentAnimationHint
                } else {
                    contentAnimation = EmojiPagerContentComponent.ContentAnimation(type: .generic)
                }
                transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(contentAnimation)
            }
            strongSelf.currentInputData = strongSelf.processInputData(inputData: inputData)
            strongSelf.performLayout(transition: transition)
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
            performItemAction: { [weak interaction] item, view, rect in
                guard let interaction else {
                    return
                }
                
                if let (collection, result) = item.contextResult {
                    let _ = interaction.sendBotContextResultAsGif(collection, result, view, rect, false, false)
                } else {
                    let _ = interaction.sendGif(item.file, view, rect, false, false)
                }
            },
            openGifContextMenu: { [weak self] item, sourceView, sourceRect, gesture, isSaved in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.openGifContextMenu(file: item.file, contextResult: item.contextResult, sourceView: sourceView, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
            },
            loadMore: { [weak self] token in
                guard let strongSelf = self, let gifContext = strongSelf.gifContext else {
                    return
                }
                gifContext.loadMore(token: token)
            },
            openSearch: { [weak self] in
                if let strongSelf = self, let pagerView = strongSelf.entityKeyboardView.componentView as? EntityKeyboardComponent.View {
                    pagerView.openSearch()
                }
            },
            updateSearchQuery: { [weak self] query in
                guard let self else {
                    return
                }
                if let query {
                    self.gifMode = .emojiSearch(query)
                } else {
                    self.gifMode = .recent
                }
            },
            hideBackground: currentInputData.gifs?.component.hideBackground ?? false,
            hasSearch: currentInputData.gifs?.component.inputInteraction.hasSearch ?? false
        )
        
        self.switchToTextInput = { [weak self] in
            if let self {
                self.interaction?.switchToTextInput()
            }
        }
        
        if self.currentInputData.gifs != nil {
            let hasRecentGifs = context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
            |> map { savedGifs -> Bool in
                return !savedGifs.isEmpty
            }
            
            self.hasRecentGifsDisposable = (hasRecentGifs
            |> deliverOnMainQueue).start(next: { [weak self] hasRecentGifs in
                guard let strongSelf = self else {
                    return
                }
                
                if let gifMode = strongSelf.gifMode {
                    if !hasRecentGifs, case .recent = gifMode {
                        strongSelf.gifMode = .trending
                    }
                } else {
                    strongSelf.gifMode = hasRecentGifs ? .recent : .trending
                }
            })
        }
        
        self.choosingStickerDisposable = (self.choosingSticker
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let self {
                self.interaction?.updateChoosingSticker(value)
            }
        })
    }
    
    deinit {
        self.inputDataDisposable?.dispose()
        self.hasRecentGifsDisposable?.dispose()
        self.emojiSearchDisposable.dispose()
        self.stickerSearchDisposable.dispose()
        self.choosingStickerDisposable?.dispose()
    }
    
    private func reloadGifContext() {
        if let gifInputInteraction = self.gifInputInteraction, let gifMode = self.gifMode {
            self.gifContext = GifContext(context: self.context, subject: gifMode, gifInputInteraction: gifInputInteraction, trendingGifs: self.trendingGifsPromise.get())
        }
    }
    
    public func markInputCollapsed() {
        self.isMarkInputCollapsed = true
    }
    
    private func performLayout(transition: ComponentTransition) {
        guard let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, layoutMetrics, deviceMetrics, isVisible, isExpanded) = self.currentState else {
            return
        }
        self.scheduledInnerTransition = transition
        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, layoutMetrics: layoutMetrics, deviceMetrics: deviceMetrics, isVisible: isVisible, isExpanded: isExpanded)
    }
    
    public func simulateUpdateLayout(isVisible: Bool) {
        guard let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, layoutMetrics, deviceMetrics, _, isExpanded) = self.currentState else {
            return
        }
        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, layoutMetrics: layoutMetrics, deviceMetrics: deviceMetrics, isVisible: isVisible, isExpanded: isExpanded)
    }
    
    public override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        self.currentState = (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, layoutMetrics, deviceMetrics, isVisible, isExpanded)
        
        let innerTransition: ComponentTransition
        if let scheduledInnerTransition = self.scheduledInnerTransition {
            self.scheduledInnerTransition = nil
            innerTransition = scheduledInnerTransition
        } else {
            innerTransition = ComponentTransition(transition)
        }
        
        let wasMarkedInputCollapsed = self.isMarkInputCollapsed
        self.isMarkInputCollapsed = false
        
        var expandedHeight = standardInputHeight
        if self.isEmojiSearchActive && !isExpanded {
            expandedHeight += 118.0
        }
        
        var hiddenInputHeight: CGFloat = 0.0
        if self.hideInput && !self.adjustLayoutForHiddenInput {
            hiddenInputHeight = inputPanelHeight
        }
        
        let context = self.context
        let interaction = self.interaction
        let inputNodeInteraction = self.inputNodeInteraction!
        let trendingGifsPromise = self.trendingGifsPromise
        
        var mappedTransition = innerTransition
        
        if wasMarkedInputCollapsed || !isExpanded {
            mappedTransition = mappedTransition.withUserData(EntityKeyboardComponent.MarkInputCollapsed())
        }
        
        var emojiContent: EmojiPagerContentComponent? = self.currentInputData.emoji
        var stickerContent: EmojiPagerContentComponent? = self.currentInputData.stickers
        var gifContent: EntityKeyboardGifContent? = self.currentInputData.gifs
        
        var stickersEnabled = true
        var emojiEnabled = true
        if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel {
            if let boostsToUnrestrict = interfaceState.boostsToUnrestrict, boostsToUnrestrict > 0 {
                
            } else {
                if peer.hasBannedPermission(.banSendStickers) != nil {
                    stickersEnabled = false
                }
                if peer.hasBannedPermission(.banSendText) != nil {
                    emojiEnabled = false
                }
            }
        } else if let peer = interfaceState.renderedPeer?.peer as? TelegramGroup {
            if peer.hasBannedPermission(.banSendStickers) {
                stickersEnabled = false
            }
            if peer.hasBannedPermission(.banSendText) {
                emojiEnabled = false
            }
        }
        
        if !stickersEnabled || interfaceState.interfaceState.editMessage != nil {
            stickerContent = nil
            gifContent = nil
        }
        if !emojiEnabled && interfaceState.interfaceState.editMessage == nil {
            emojiContent = nil
        }
        if case let .customChatContents(customChatContents) = interfaceState.subject {
            switch customChatContents.kind {
            case .quickReplyMessageInput:
                break
            case .hashTagSearch:
                break
            case .businessLinkSetup:
                stickerContent = nil
                gifContent = nil
            }
        }
        
        stickerContent?.inputInteractionHolder.inputInteraction = self.stickerInputInteraction
        self.currentInputData.emoji?.inputInteractionHolder.inputInteraction = self.emojiInputInteraction
        
        if let stickerInputInteraction = self.stickerInputInteraction {
            self.scrollingStickersGridPromise.set(stickerInputInteraction.scrollingStickersGridPromise.get())
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var keyboardBottomInset = bottomInset
        if case .regular = layoutMetrics.widthClass, inputHeight > 0.0 && inputHeight < 100.0 {
            keyboardBottomInset = inputHeight + 15.0
        }
        let entityKeyboardSize = self.entityKeyboardView.update(
            transition: mappedTransition,
            component: AnyComponent(EntityKeyboardComponent(
                theme: interfaceState.theme,
                strings: interfaceState.strings,
                isContentInFocus: isVisible,
                containerInsets: UIEdgeInsets(top: self.isEmojiSearchActive ? -34.0 : 0.0, left: leftInset, bottom: keyboardBottomInset, right: rightInset),
                topPanelInsets: UIEdgeInsets(),
                emojiContent: emojiContent,
                stickerContent: stickerContent,
                maskContent: nil,
                gifContent: gifContent?.component,
                hasRecentGifs: gifContent?.hasRecentGifs ?? false,
                availableGifSearchEmojies: self.currentInputData.availableGifSearchEmojies,
                defaultToEmojiTab: self.defaultToEmojiTab,
                externalTopPanelContainer: self.externalTopPanelContainerImpl,
                externalBottomPanelContainer: nil,
                displayTopPanelBackground: self.opaqueTopPanelBackground ? .opaque : .none,
                topPanelExtensionUpdated: { [weak self] topPanelExtension, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.topBackgroundExtension != topPanelExtension {
                        strongSelf.topBackgroundExtension = topPanelExtension
                        strongSelf.topBackgroundExtensionUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                topPanelScrollingOffset: { _, _ in },
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
                hideTopPanelUpdated: { [weak self] hideTopPanel, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.isEmojiSearchActive = hideTopPanel
                    strongSelf.performLayout(transition: transition)
                },
                switchToTextInput: { [weak self] in
                    self?.switchToTextInput?()
                },
                switchToGifSubject: { [weak self] subject in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.gifMode = subject
                },
                reorderItems: { [weak self] category, items in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.reorderItems(category: category, items: items)
                },
                makeSearchContainerNode: { [weak self, weak interaction] content in
                    guard let self, let interaction else {
                        return nil
                    }

                    let mappedMode: ChatMediaInputSearchMode
                    switch content {
                    case .stickers:
                        mappedMode = .sticker
                    case .gifs:
                        mappedMode = .gif
                    }
                    
                    let searchContainerNode = PaneSearchContainerNode(
                        context: context,
                        theme: interfaceState.theme,
                        strings: interfaceState.strings,
                        interaction: interaction,
                        inputNodeInteraction: inputNodeInteraction,
                        mode: mappedMode,
                        batchVideoRenderingContext: nil,
                        trendingGifsPromise: trendingGifsPromise,
                        cancel: {
                        },
                        peekBehavior: self.emojiInputInteraction?.peekBehavior
                    )
                    searchContainerNode.openGifContextMenu = { [weak self] item, sourceNode, sourceRect, gesture, isSaved in
                        guard let self else {
                            return
                        }
                        self.openGifContextMenu(file: item.file, contextResult: item.contextResult, sourceView: sourceNode.view, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
                    }
                    
                    return searchContainerNode
                },
                contentIdUpdated: { _ in },
                deviceMetrics: deviceMetrics,
                hiddenInputHeight: hiddenInputHeight,
                inputHeight: inputHeight,
                displayBottomPanel: true,
                isExpanded: isExpanded && !self.isEmojiSearchActive,
                clipContentToTopPanel: self.clipContentToTopPanel,
                useExternalSearchContainer: self.useExternalSearchContainer
            )),
            environment: {},
            containerSize: CGSize(width: width, height: expandedHeight)
        )
        transition.updateFrame(view: self.entityKeyboardView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: entityKeyboardSize))
        
        let layoutTime = CFAbsoluteTimeGetCurrent() - startTime
        if layoutTime > 0.1 {
            #if DEBUG
            print("EntityKeyboard layout in \(layoutTime * 1000.0) ms")
            #endif
        }
        
        return (expandedHeight, 0.0)
    }
    
    private func processStableItemGroupList(category: EntityKeyboardComponent.ReorderCategory, itemGroups: [EmojiPagerContentComponent.ItemGroup]) -> [EmojiPagerContentComponent.ItemGroup] {
        let nextIds: [ItemCollectionId] = itemGroups.compactMap { group -> ItemCollectionId? in
            if group.isEmbedded {
                return nil
            }
            if group.isFeatured {
                return nil
            }
            if let collectionId = group.groupId.base as? ItemCollectionId {
                return collectionId
            } else {
                return nil
            }
        }
        
        let stableOrder = self.stableReorderableGroupOrder[category] ?? nextIds
        
        var updatedGroups: [EmojiPagerContentComponent.ItemGroup] = []
        
        var staticIsFirst = false
        let topStaticGroups: [String] = [
            "static",
            "recent",
            "featuredTop"
        ]
        for group in itemGroups {
            var found = false
            for topStaticGroup in topStaticGroups {
                if group.groupId == AnyHashable(topStaticGroup) {
                    if group.groupId == AnyHashable("static") {
                        staticIsFirst = true
                    }
                    found = true
                    break
                }
            }
            if !found {
                break
            }
        }
        
        for group in itemGroups {
            if !(group.groupId.base is ItemCollectionId) {
                if group.groupId != AnyHashable("static") || staticIsFirst {
                    updatedGroups.append(group)
                }
            } else {
                if group.isEmbedded {
                    continue
                }
                if group.isFeatured {
                    continue
                }
                if !stableOrder.contains(where: { AnyHashable($0) == group.groupId }) {
                    updatedGroups.append(group)
                }
            }
        }
        for id in stableOrder {
            if let group = itemGroups.first(where: { $0.groupId == AnyHashable(id) }) {
                updatedGroups.append(group)
            }
        }
        for group in itemGroups {
            if !updatedGroups.contains(where: { $0.groupId == group.groupId }) {
                updatedGroups.append(group)
            }
        }
        
        let updatedIds = updatedGroups.compactMap { group -> ItemCollectionId? in
            if group.isEmbedded {
                return nil
            }
            if group.isFeatured {
                return nil
            }
            if let collectionId = group.groupId.base as? ItemCollectionId {
                return collectionId
            } else {
                return nil
            }
        }

        self.stableReorderableGroupOrder[category] = updatedIds
        
        return updatedGroups
    }
    
    private func processInputData(inputData: InputData) -> InputData {
        return InputData(
            emoji: inputData.emoji.flatMap { emoji in
                return emoji.withUpdatedItemGroups(panelItemGroups: self.processStableItemGroupList(category: .emoji, itemGroups: emoji.panelItemGroups), contentItemGroups: self.processStableItemGroupList(category: .emoji, itemGroups: emoji.contentItemGroups), itemContentUniqueId: emoji.itemContentUniqueId, emptySearchResults: emoji.emptySearchResults, searchState: emoji.searchState)
            },
            stickers: inputData.stickers.flatMap { stickers in
                return stickers.withUpdatedItemGroups(panelItemGroups: self.processStableItemGroupList(category: .stickers, itemGroups: stickers.panelItemGroups), contentItemGroups: self.processStableItemGroupList(category: .stickers, itemGroups: stickers.contentItemGroups), itemContentUniqueId: stickers.itemContentUniqueId, emptySearchResults: nil, searchState: stickers.searchState)
            },
            gifs: inputData.gifs,
            availableGifSearchEmojies: inputData.availableGifSearchEmojies
        )
    }
    
    private func reorderItems(category: EntityKeyboardComponent.ReorderCategory, items: [EntityKeyboardTopPanelComponent.Item]) {
        var currentIds: [ItemCollectionId] = []
        for item in items {
            guard let id = item.id.base as? ItemCollectionId else {
                continue
            }
            currentIds.append(id)
        }
        let namespace: ItemCollectionId.Namespace
        switch category {
        case .stickers:
            namespace = Namespaces.ItemCollection.CloudStickerPacks
        case .emoji:
            namespace = Namespaces.ItemCollection.CloudEmojiPacks
        case .masks:
            namespace = Namespaces.ItemCollection.CloudMaskPacks
        }
        
        self.stableReorderableGroupOrder.removeValue(forKey: category)
        
        let _ = (self.context.engine.stickers.reorderStickerPacks(namespace: namespace, itemIds: currentIds)
        |> deliverOnMainQueue).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.performLayout(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
        })
        
        if self.context.sharedContext.currentStickerSettings.with({ $0 }).dynamicPackOrder {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.interaction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_reorder", scale: 0.05, colors: [:], title: presentationData.strings.StickerPacksSettings_DynamicOrderOff, text: presentationData.strings.StickerPacksSettings_DynamicOrderOffInfo, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                    return false
            }), nil)
                
            let _ = updateStickerSettingsInteractively(accountManager: self.context.sharedContext.accountManager, {
                return $0.withUpdatedDynamicPackOrder(false)
            }).start()
        }
    }
    
    private func openGifContextMenu(file: FileMediaReference, contextResult: (ChatContextResultCollection, ChatContextResult)?, sourceView: UIView, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
        let canSaveGif: Bool
        if file.media.fileId.namespace == Namespaces.Media.CloudFile {
            canSaveGif = true
        } else {
            canSaveGif = false
        }
        
        let _ = (self.context.engine.stickers.isGifSaved(id: file.media.fileId)
        |> deliverOnMainQueue).start(next: { [weak self] isGifSaved in
            guard let strongSelf = self else {
                return
            }
            var isGifSaved = isGifSaved
            if !canSaveGif {
                isGifSaved = false
            }
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file.media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            let gallery = strongSelf.context.sharedContext.makeGalleryController(context: strongSelf.context, source: .standaloneMessage(message, nil), streamSingleVideo: true, isPreview: true)
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Send, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] _, f in
                f(.default)
                if let self {
                    if isSaved {
                        let _ = self.interaction?.sendGif(file, sourceView, sourceRect, false, false)
                    } else if let (collection, result) = contextResult {
                        let _ = self.interaction?.sendBotContextResultAsGif(collection, result, sourceView, sourceRect, false, false)
                    }
                }
            })))
            
            if let currentState = strongSelf.currentState {
                let interfaceState = currentState.interfaceState
                
                var isScheduledMessages = false
                if case .scheduledMessages = interfaceState.subject {
                    isScheduledMessages = true
                }
                if !isScheduledMessages {
                    if case let .peer(peerId) = interfaceState.chatLocation {
                        if peerId != self?.context.account.peerId && peerId.namespace != Namespaces.Peer.SecretChat  {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                f(.default)
                                if let self {
                                    if isSaved {
                                        let _ = self.interaction?.sendGif(file, sourceView, sourceRect, true, false)
                                    } else if let (collection, result) = contextResult {
                                        let _ = self.interaction?.sendBotContextResultAsGif(collection, result, sourceView, sourceRect, true, false)
                                    }
                                }
                            })))
                        }
                    
                        if isSaved && interfaceState.sendPaidMessageStars == nil {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                f(.default)
                                if let self {
                                    let _ = self.interaction?.sendGif(file, sourceView, sourceRect, false, true)
                                }
                            })))
                        }
                    }
                }
            }
            
            if isSaved || isGifSaved {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    if let self {
                        let _ = removeSavedGif(postbox: self.context.account.postbox, mediaId: file.media.fileId).start()
                    }
                })))
            } else if canSaveGif && !isGifSaved {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Preview_SaveGif, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let context = strongSelf.context
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let _ = (toggleGifSaved(account: context.account, fileReference: file, saved: true)
                    |> deliverOnMainQueue).start(next: { [weak self]  result in
                        guard let strongSelf = self else {
                            return
                        }
                        switch result {
                            case .generic:
                                strongSelf.interaction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                            case let .limitExceeded(limit, premiumLimit):
                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                let text: String
                                if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                    text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                } else {
                                    text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                }
                                strongSelf.interaction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                                    guard let strongSelf = self else {
                                        return false
                                    }
                                    
                                    if case .info = action {
                                        let controller = PremiumIntroScreen(context: context, source: .savedGifs)
                                        strongSelf.interaction?.getNavigationController()?.pushViewController(controller)
                                        return true
                                    }
                                    return false
                                }), nil)
                        }
                    })
                })))
            }
            
            let contextController = ContextController(presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceView: sourceView, sourceRect: sourceRect)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.interaction?.presentGlobalOverlayController(contextController, nil)
        })
    }
    
    public func scrollToGroupEmoji() {
        if let pagerView = self.entityKeyboardView.componentView as? EntityKeyboardComponent.View {
            pagerView.scrollToItemGroup(contentId: "emoji", groupId: "peerSpecific", subgroupId: nil)
        }
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
        if let controller = self.controller as? GalleryControllerProtocol {
            controller.viewDidAppear(false)
        }
    }
}

public final class EntityInputView: UIInputView, AttachmentTextInputPanelInputView, LegacyMessageInputPanelInputView, UIInputViewAudioFeedback {
    private let context: AccountContext
    
    public var insertText: ((NSAttributedString) -> Void)?
    public var deleteBackwards: (() -> Void)?
    public var switchToKeyboard: (() -> Void)?
    public var presentController: ((ViewController) -> Void)?
    
    private var presentationData: PresentationData
    private var inputNode: ChatEntityKeyboardInputNode?
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    public init(
        context: AccountContext,
        isDark: Bool,
        areCustomEmojiEnabled: Bool,
        hideBackground: Bool = false,
        forceHasPremium: Bool = false
    ) {
        self.context = context
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        if isDark {
            self.presentationData = self.presentationData.withUpdated(theme: defaultDarkPresentationTheme)
        }
        
        super.init(frame: CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)), inputViewStyle: .default)
        
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.clipsToBounds = true
        
        let inputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak self] groupId, item, _, _, _, _ in
                let hasPremium: Signal<Bool, NoError>
                if forceHasPremium {
                    hasPremium = .single(true)
                } else {
                    hasPremium = ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: nil, premiumIfSavedMessages: false) |> take(1) |> deliverOnMainQueue
                }
                let _ = hasPremium.start(next: { hasPremium in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if groupId == AnyHashable("featuredTop") {
                    } else {
                        if let file = item.itemFile?._parse() {
                            var text = "."
                            var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                            loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, displayText, _):
                                text = displayText
                                var packId: ItemCollectionId?
                                if let id = groupId.base as? ItemCollectionId {
                                    packId = id
                                }
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: packId, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                            
                            if file.isPremiumEmoji && !hasPremium {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                strongSelf.presentController?(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.EmojiInput_PremiumEmojiToast_Text, undoText: presentationData.strings.EmojiInput_PremiumEmojiToast_Action, customAction: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    var replaceImpl: ((ViewController) -> Void)?
                                    let controller = PremiumDemoScreen(context: strongSelf.context, subject: .animatedEmoji, action: {
                                        let controller = PremiumIntroScreen(context: strongSelf.context, source: .animatedEmoji)
                                        replaceImpl?(controller)
                                    })
                                    replaceImpl = { [weak controller] c in
                                        guard let controller else {
                                            return
                                        }
                                        if controller.navigationController != nil {
                                            controller.replace(with: c)
                                        } else {
                                            controller.dismiss()
                                            
                                            if let self {
                                                self.presentController?(c)
                                            }
                                        }
                                    }
                                    strongSelf.presentController?(controller)
                                }), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
                                return
                            }
                            
                            if let emojiAttribute = emojiAttribute {
                                AudioServicesPlaySystemSound(0x450)
                                strongSelf.insertText?(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute]))
                            }
                        } else if case let .staticEmoji(staticEmoji) = item.content {
                            AudioServicesPlaySystemSound(0x450)
                            strongSelf.insertText?(NSAttributedString(string: staticEmoji, attributes: [:]))
                        }
                    }
                })
            },
            deleteBackwards: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.deleteBackwards?()
            },
            openStickerSettings: {
            },
            openFeatured: {
            },
            openSearch: {
            },
            addGroupAction: { _, _, _ in
            },
            clearGroup: { [weak self] groupId in
                guard let strongSelf = self else {
                    return
                }
                if groupId == AnyHashable("recent") {
                    strongSelf.window?.endEditing(true)
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Emoji_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = context.engine.stickers.clearRecentlyUsedEmoji().start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.presentController?(actionSheet)
                }
            },
            editAction: { _ in },
            pushController: { _ in
            },
            presentController: { _ in
            },
            presentGlobalOverlayController: { _ in
            },
            navigationController: {
                return nil
            },
            requestUpdate: { _ in
            },
            updateSearchQuery: { _ in
            },
            updateScrollingToItemGroup: {
            },
            onScroll: {},
            chatPeerId: nil,
            peekBehavior: nil,
            customLayout: nil,
            externalBackground: nil,
            externalExpansionView: nil,
            customContentView: nil,
            useOpaqueTheme: false,
            hideBackground: hideBackground,
            stateContext: nil,
            addImage: nil
        )
        
        let semaphore = DispatchSemaphore(value: 0)
        var emojiComponent: EmojiPagerContentComponent?
        let _ = EmojiPagerContentComponent.emojiInputData(
            context: context,
            animationCache: self.animationCache,
            animationRenderer: self.animationRenderer,
            isStandalone: true,
            subject: .generic,
            hasTrending: false, 
            topReactionItems: [],
            areUnicodeEmojiEnabled: true,
            areCustomEmojiEnabled: areCustomEmojiEnabled,
            chatPeerId: nil,
            forceHasPremium: forceHasPremium
        ).start(next: { value in
            emojiComponent = value
            semaphore.signal()
        })
        semaphore.wait()
        
        if let emojiComponent = emojiComponent {
            let inputNode = ChatEntityKeyboardInputNode(
                context: self.context,
                currentInputData: ChatEntityKeyboardInputNode.InputData(
                    emoji: emojiComponent,
                    stickers: nil,
                    gifs: nil,
                    availableGifSearchEmojies: []
                ),
                updatedInputData: EmojiPagerContentComponent.emojiInputData(
                    context: context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    isStandalone: true,
                    subject: .generic,
                    hasTrending: false,
                    topReactionItems: [], 
                    areUnicodeEmojiEnabled: true,
                    areCustomEmojiEnabled: areCustomEmojiEnabled,
                    chatPeerId: nil,
                    forceHasPremium: forceHasPremium,
                    hideBackground: hideBackground
                ) |> map { emojiComponent -> ChatEntityKeyboardInputNode.InputData in
                    return ChatEntityKeyboardInputNode.InputData(
                        emoji: emojiComponent,
                        stickers: nil,
                        gifs: nil,
                        availableGifSearchEmojies: []
                    )
                },
                defaultToEmojiTab: true,
                opaqueTopPanelBackground: !hideBackground,
                interaction: nil,
                chatPeerId: nil,
                stateContext: nil
            )
            self.inputNode = inputNode
            inputNode.clipContentToTopPanel = true
            inputNode.emojiInputInteraction = inputInteraction
            inputNode.externalTopPanelContainerImpl = nil
            inputNode.switchToTextInput = { [weak self] in
                self?.switchToKeyboard?()
            }
            if !hideBackground {
                inputNode.backgroundColor = self.presentationData.theme.chat.inputMediaPanel.backgroundColor
            }
            self.addSubnode(inputNode)
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let inputNode = self.inputNode else {
            return
        }
        
        for view in self.subviews {
            if view !== inputNode.view {
                view.isHidden = true
            }
        }
        
        let bottomInset: CGFloat
        if #available(iOS 11.0, *) {
            bottomInset = max(0.0, UIScreen.main.bounds.height - (self.window?.safeAreaLayoutGuide.layoutFrame.maxY ?? 10000.0))
        } else {
            bottomInset = 0.0
        }
            
        let presentationInterfaceState = ChatPresentationInterfaceState(
            chatWallpaper: .builtin(WallpaperSettings()),
            theme: self.presentationData.theme,
            strings: self.presentationData.strings,
            dateTimeFormat: self.presentationData.dateTimeFormat,
            nameDisplayOrder: self.presentationData.nameDisplayOrder,
            limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 },
            fontSize: self.presentationData.chatFontSize,
            bubbleCorners: self.presentationData.chatBubbleCorners,
            accountPeerId: self.context.account.peerId,
            mode: .standard(.default),
            chatLocation: .peer(id: self.context.account.peerId),
            subject: nil,
            peerNearbyData: nil,
            greetingData: nil,
            pendingUnpinnedAllMessages: false,
            activeGroupCallInfo: nil,
            hasActiveGroupCall: false,
            importState: nil,
            threadData: nil,
            isGeneralThreadClosed: nil,
            replyMessage: nil,
            accountPeerColor: nil,
            businessIntro: nil
        )

        let _ = inputNode.updateLayout(
            width: self.bounds.width,
            leftInset: 0.0,
            rightInset: 0.0,
            bottomInset: bottomInset,
            standardInputHeight: self.bounds.height,
            inputHeight: self.bounds.height,
            maximumHeight: self.bounds.height,
            inputPanelHeight: 0.0,
            transition: .immediate,
            interfaceState: presentationInterfaceState,
            layoutMetrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil),
            deviceMetrics: DeviceMetrics.iPhone12,
            isVisible: true,
            isExpanded: false
        )
        inputNode.frame = self.bounds
    }
}

public final class EmojiContentPeekBehaviorImpl: EmojiContentPeekBehavior {
    public class Interaction {
        public let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool
        public let sendEmoji: (TelegramMediaFile) -> Void
        public let setStatus: (TelegramMediaFile) -> Void
        public let copyEmoji: (TelegramMediaFile) -> Void
        public let presentController: (ViewController, Any?) -> Void
        public let presentGlobalOverlayController: (ViewController, Any?) -> Void
        public let navigationController: () -> NavigationController?
        public let updateIsPreviewing: (Bool) -> Void
        
        public init(sendSticker: @escaping (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool, sendEmoji: @escaping (TelegramMediaFile) -> Void, setStatus: @escaping (TelegramMediaFile) -> Void, copyEmoji: @escaping (TelegramMediaFile) -> Void, presentController: @escaping (ViewController, Any?) -> Void, presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void, navigationController: @escaping () -> NavigationController?, updateIsPreviewing: @escaping (Bool) -> Void) {
            self.sendSticker = sendSticker
            self.sendEmoji = sendEmoji
            self.setStatus = setStatus
            self.copyEmoji = copyEmoji
            self.presentController = presentController
            self.presentGlobalOverlayController = presentGlobalOverlayController
            self.navigationController = navigationController
            self.updateIsPreviewing = updateIsPreviewing
        }
    }
    
    private final class ViewRecord {
        weak var view: UIView?
        let peekRecognizer: PeekControllerGestureRecognizer
        
        init(view: UIView, peekRecognizer: PeekControllerGestureRecognizer) {
            self.view = view
            self.peekRecognizer = peekRecognizer
        }
    }
    
    private let context: AccountContext
    private let forceTheme: PresentationTheme?
    private let interaction: Interaction?
    private let chatPeerId: EnginePeer.Id?
    private let present: (ViewController, Any?) -> Void
    
    private var viewRecords: [ViewRecord] = []
    private weak var peekController: PeekController?
    
    public init(context: AccountContext, forceTheme: PresentationTheme? = nil, interaction: Interaction?, chatPeerId: EnginePeer.Id?, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.forceTheme = forceTheme
        self.interaction = interaction
        self.chatPeerId = chatPeerId
        self.present = present
    }
    
    public func setGestureRecognizerEnabled(view: UIView, isEnabled: Bool, itemAtPoint: @escaping (CGPoint) -> (AnyHashable, CALayer, TelegramMediaFile)?) {
        self.viewRecords = self.viewRecords.filter({ $0.view != nil })
        
        let viewRecord = self.viewRecords.first(where: { $0.view === view })
        
        if let viewRecord = viewRecord {
            viewRecord.peekRecognizer.isEnabled = isEnabled
        } else {
            let peekRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self, weak view] point in
                guard let strongSelf = self else {
                    return nil
                }
                guard let (groupId, itemLayer, file) = itemAtPoint(point) else {
                    return nil
                }
                
                let context = strongSelf.context
                
                var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
                if let id = groupId.base as? ItemCollectionId {
                    if file.isCustomEmoji || context.sharedContext.currentStickerSettings.with({ $0 }).dynamicPackOrder {
                        bubbleUpEmojiOrStickersets.append(id)
                    }
                }
                
                let accountPeerId = context.account.peerId
                let chatPeerId = strongSelf.chatPeerId
                
                if file.isCustomEmoji {
                    return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId)) |> map { peer -> Bool in
                        var hasPremium = false
                        if case let .user(user) = peer, user.isPremium {
                            hasPremium = true
                        }
                        return hasPremium
                    }
                    |> deliverOnMainQueue
                    |> map { [weak itemLayer] hasPremium -> (UIView, CGRect, PeekControllerContent)? in
                        guard let strongSelf = self, let itemLayer = itemLayer else {
                            return nil
                        }
                        
                        var menuItems: [ContextMenuItem] = []
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        var isLocked = false
                        if !hasPremium {
                            isLocked = file.isPremiumEmoji
                            if isLocked && chatPeerId == context.account.peerId {
                                isLocked = false
                            }
                        }
                        
                        if let interaction = strongSelf.interaction {
                            let sendEmoji: (TelegramMediaFile) -> Void = { file in
                                interaction.sendEmoji(file)
                            }
                            let setStatus: (TelegramMediaFile) -> Void = { file in
                                interaction.setStatus(file)
                            }
                            let copyEmoji: (TelegramMediaFile) -> Void = { file in
                                interaction.copyEmoji(file)
                            }
                            
                            if let _ = strongSelf.chatPeerId {
                                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_SendEmoji, icon: { theme in
                                    if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.actionSheet.primaryTextColor) {
                                        return generateImage(image.size, rotatedContext: { size, context in
                                            context.clear(CGRect(origin: CGPoint(), size: size))
                                            
                                            if let cgImage = image.cgImage {
                                                context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                                            }
                                        })
                                    } else {
                                        return nil
                                    }
                                }, action: { _, f in
                                    sendEmoji(file)
                                    f(.default)
                                })))
                                
                                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_SetAsStatus, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Smile"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    f(.default)
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    if hasPremium {
                                        setStatus(file)
                                    } else {
                                        var replaceImpl: ((ViewController) -> Void)?
                                        let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                                            let controller = PremiumIntroScreen(context: context, source: .animatedEmoji)
                                            replaceImpl?(controller)
                                        })
                                        replaceImpl = { [weak controller] c in
                                            controller?.replace(with: c)
                                        }
                                        strongSelf.interaction?.navigationController()?.pushViewController(controller)
                                    }
                                })))
                                
                                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_CopyEmoji, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    copyEmoji(file)
                                    f(.default)
                                })))
                            }
                        }
                        
                        if menuItems.isEmpty {
                            return nil
                        }
                        guard let view = view else {
                            return nil
                        }
                        
                        return (view, itemLayer.convert(itemLayer.bounds, to: view.layer), StickerPreviewPeekContent(context: context, theme: presentationData.theme, strings: presentationData.strings, item: .pack(file), isLocked: isLocked, menu: menuItems, openPremiumIntro: {
                            guard let strongSelf = self, let interaction = strongSelf.interaction else {
                                return
                            }
                            let controller = PremiumIntroScreen(context: context, source: .stickers)
                            interaction.navigationController()?.pushViewController(controller)
                        }))
                    }
                } else {
                    let sendPaidMessageStars: Signal<StarsAmount?, NoError>
                    if let chatPeerId = strongSelf.chatPeerId {
                        sendPaidMessageStars = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars(id: chatPeerId))
                    } else {
                        sendPaidMessageStars = .single(nil)
                    }
                    
                    return combineLatest(
                        context.engine.stickers.isStickerSaved(id: file.fileId),
                        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId)) |> map { peer -> Bool in
                            var hasPremium = false
                            if case let .user(user) = peer, user.isPremium {
                                hasPremium = true
                            }
                            return hasPremium
                        },
                        sendPaidMessageStars
                    )
                    |> deliverOnMainQueue
                    |> map { [weak itemLayer] isStarred, hasPremium, sendPaidMessageStars -> (UIView, CGRect, PeekControllerContent)? in
                        guard let strongSelf = self, let itemLayer = itemLayer else {
                            return nil
                        }
                        var menuItems: [ContextMenuItem] = []
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let isLocked = file.isPremiumSticker && !hasPremium
                        
                        if let interaction = strongSelf.interaction {
                            let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?) -> Void = { fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer in
                                let _ = interaction.sendSticker(fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer, bubbleUpEmojiOrStickersets)
                            }
                            
                            if let chatPeerId = strongSelf.chatPeerId, !isLocked {
                                if chatPeerId != strongSelf.context.account.peerId && chatPeerId.namespace != Namespaces.Peer.SecretChat  {
                                    menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                                    }, action: { _, f in
                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                sendSticker(.standalone(media: file), true, false, nil, false, animationNode.view, animationNode.bounds, nil)
                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                sendSticker(.standalone(media: file), true, false, nil, false, imageNode.view, imageNode.bounds, nil)
                                            }
                                        }
                                        f(.default)
                                    })))
                                }
                                
                                if sendPaidMessageStars == nil {
                                    menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                                    }, action: { _, f in
                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                let _ = sendSticker(.standalone(media: file), false, true, nil, false, animationNode.view, animationNode.bounds, nil)
                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                let _ = sendSticker(.standalone(media: file), false, true, nil, false, imageNode.view, imageNode.bounds, nil)
                                            }
                                        }
                                        f(.default)
                                    })))
                                }
                            }
                            
                            menuItems.append(
                                .action(ContextMenuActionItem(text: isStarred ? presentationData.strings.Stickers_RemoveFromFavorites : presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    f(.default)
                                    
                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                    let _ = (context.engine.stickers.toggleStickerSaved(file: file, saved: !isStarred)
                                    |> deliverOnMainQueue).start(next: { result in
                                        switch result {
                                        case .generic:
                                            interaction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: !isStarred ? presentationData.strings.Conversation_StickerAddedToFavorites : presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), nil)
                                        case let .limitExceeded(limit, premiumLimit):
                                            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                            let text: String
                                            if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                text = presentationData.strings.Premium_MaxFavedStickersFinalText
                                            } else {
                                                text = presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                            }
                                            interaction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil, customAction: nil), elevatedLayout: false, action: { action in
                                                if case .info = action {
                                                    let controller = PremiumIntroScreen(context: context, source: .savedStickers)
                                                    interaction.navigationController()?.pushViewController(controller)
                                                    return true
                                                }
                                                return false
                                            }), nil)
                                        }
                                    })
                                }))
                            )
                            
                            loop: for attribute in file.attributes {
                                switch attribute {
                                case let .CustomEmoji(_, _, _, packReference), let .Sticker(_, packReference, _):
                                    if let packReference = packReference {
                                        menuItems.append(
                                            .action(ContextMenuActionItem(text: presentationData.strings.StickerPack_ViewPack, icon: { theme in
                                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
                                            }, action: { _, f in
                                                f(.default)
                                                
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                
                                                let controller = strongSelf.context.sharedContext.makeStickerPackScreen(context: context, updatedPresentationData: nil, mainStickerPack: packReference, stickerPacks: [packReference], loadedStickerPacks: [], actionTitle: nil, isEditing: false, expandIfNeeded: false, parentNavigationController: interaction.navigationController(), sendSticker: { file, sourceView, sourceRect in
                                                    sendSticker(file, false, false, nil, false, sourceView, sourceRect, nil)
                                                    return true
                                                }, actionPerformed: nil)
                                                
                                                interaction.navigationController()?.view.window?.endEditing(true)
                                                interaction.presentController(controller, nil)
                                            }))
                                        )
                                    }
                                    break loop
                                default:
                                    break
                                }
                            }
                            
                            if groupId == AnyHashable("recent") {
                                menuItems.append(
                                    .action(ContextMenuActionItem(text: presentationData.strings.Stickers_RemoveFromRecent, textColor: .destructive, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                                    }, action: { _, f in
                                        f(.default)
                                        
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        interaction.presentGlobalOverlayController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.Conversation_StickerRemovedFromRecent, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), nil)
                                        
                                        strongSelf.context.engine.stickers.removeRecentlyUsedSticker(fileReference: .recentSticker(media: file))
                                    }))
                                )
                            }
                        }
                        
                        guard let view = view else {
                            return nil
                        }
                        
                        return (view, itemLayer.convert(itemLayer.bounds, to: view.layer), StickerPreviewPeekContent(context: context, theme: presentationData.theme, strings: presentationData.strings, item: .pack(file), isLocked: isLocked && !isStarred, menu: menuItems, openPremiumIntro: {
                            guard let strongSelf = self, let interaction = strongSelf.interaction else {
                                return
                            }
                            let controller = PremiumIntroScreen(context: context, source: .stickers)
                            interaction.navigationController()?.pushViewController(controller)
                        }))
                    }
                }
            }, present: { [weak self] content, sourceView, sourceRect in
                guard let strongSelf = self else {
                    return nil
                }
                
                var presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                if let forceTheme = strongSelf.forceTheme {
                    presentationData = presentationData.withUpdated(theme: forceTheme)
                }
                let controller = PeekController(presentationData: presentationData, content: content, sourceView: {
                    return (sourceView, sourceRect)
                })
                controller.visibilityUpdated = { [weak self] visible in
                    guard let strongSelf = self, let interaction = strongSelf.interaction else {
                        return
                    }
                    interaction.updateIsPreviewing(visible)
                }
                strongSelf.peekController = controller
                strongSelf.present(controller, nil)
                return controller
            }, updateContent: { [weak self] content in
                guard let strongSelf = self else {
                    return
                }
                
                let _ = strongSelf
            })
            self.viewRecords.append(ViewRecord(view: view, peekRecognizer: peekRecognizer))
            view.addGestureRecognizer(peekRecognizer)
            peekRecognizer.isEnabled = isEnabled
        }
    }
}
