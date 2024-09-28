import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import ViewControllerComponent
import EntityKeyboard
import PagerComponent
import FeaturedStickersScreen
import TelegramNotices
import ChatEntityKeyboardInputNode
import ContextUI
import ChatPresentationInterfaceState
import MediaEditor
import EntityKeyboardGifContent
import CameraButtonComponent
import BundleIconComponent
import LottieComponent
import LottieComponentResourceContent
import UndoUI
import GalleryUI
import TextLoadingEffect
import TelegramStringFormatting

private final class StickerSelectionComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let deviceMetrics: DeviceMetrics
    let topInset: CGFloat
    let bottomInset: CGFloat
    let content: StickerPickerInputData
    let backgroundColor: UIColor
    let separatorColor: UIColor
    let getController: () -> StickerPickerScreen?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        deviceMetrics: DeviceMetrics,
        topInset: CGFloat,
        bottomInset: CGFloat,
        content: StickerPickerInputData,
        backgroundColor: UIColor,
        separatorColor: UIColor,
        getController: @escaping () -> StickerPickerScreen?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.deviceMetrics = deviceMetrics
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.content = content
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.getController = getController
    }
    
    public static func ==(lhs: StickerSelectionComponent, rhs: StickerSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.topInset != rhs.topInset {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        return true
    }
    
    final class KeyboardClippingView: UIView {
        var hitEdgeInsets: UIEdgeInsets = .zero
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let bounds = self.bounds.inset(by: self.hitEdgeInsets)
            return bounds.contains(point)
        }
    }
    
    public final class View: UIView {
        fileprivate let keyboardView: ComponentView<Empty>
        private let keyboardClippingView: KeyboardClippingView
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelBackgroundView: BlurredBackgroundView
        private let panelSeparatorView: UIView
        
        private var component: StickerSelectionComponent?
        private weak var state: EmptyComponentState?
        
        private var interaction: ChatEntityKeyboardInputNode.Interaction?
        private var inputNodeInteraction: ChatMediaInputNodeInteraction?
        
        private var searchVisible = false
        private var forceUpdate = false
        
        private var ignoreNextZeroScrollingOffset = false
        private var topPanelScrollingOffset: CGFloat = 0.0
        private var keyboardContentId: AnyHashable?
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.keyboardClippingView = KeyboardClippingView()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.panelBackgroundView.isUserInteractionEnabled = false
            self.panelSeparatorView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.keyboardClippingView)
            self.addSubview(self.panelBackgroundView)
            self.addSubview(self.panelSeparatorView)
            self.addSubview(self.panelHostView)
            
            self.interaction = ChatEntityKeyboardInputNode.Interaction(
                sendSticker: { [weak self] file, silent, schedule, query, clearInput, sourceView, sourceRect, sourceLayer, _ in
                    if let self, let controller = self.component?.getController() {
                        controller.forEachController { c in
                            if let c = c as? (ViewController & StickerPackScreen) {
                                c.dismiss(animated: true)
                            }
                            return true
                        }
                        controller.window?.forEachController({ c in
                            if let c = c as? (ViewController & StickerPackScreen) {
                                c.dismiss(animated: true)
                            }
                        })
                        if controller.completion(.file(file, .sticker)) {
                            controller.dismiss(animated: true)
                        }
                    }
                    return false
                },
                sendEmoji: { _, _, _ in
                },
                sendGif: { [weak self] file, _, _, _, _ in
                    if let self, let controller = self.component?.getController() {
                        if controller.completion(.video(file.media)) {
                            controller.dismiss(animated: true)
                        }
                    }
                    return false
                },
                sendBotContextResultAsGif: { [weak self] collection, result, _, _, _, _ in
                    if let self, let controller = self.component?.getController() {
                        if case let .internalReference(reference) = result {
                            if let file = reference.file {
                                if controller.completion(.video(file)) {
                                    controller.dismiss(animated: true)
                                }
                            }
                        }
                    }
                    return false
                },
                updateChoosingSticker: { _ in },
                switchToTextInput: {},
                dismissTextInput: {},
                insertText: { _ in
                },
                backwardsDeleteText: {},
                openStickerEditor: {},
                presentController: { [weak self] c, a in
                    if let self, let controller = self.component?.getController() {
                        controller.present(c, in: .window(.root), with: a)
                    }
                },
                presentGlobalOverlayController: { [weak self] c, a in
                    if let self, let controller = self.component?.getController() {
                        controller.presentInGlobalOverlay(c, with: a)
                    }
                },
                getNavigationController: {
                    return nil
                },
                requestLayout: { transition in
                    let _ = transition
                }
            )
            
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
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func scrolledToItemGroup() {
            self.topPanelScrollingOffset = 30.0
            self.ignoreNextZeroScrollingOffset = true
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func update(component: StickerSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.backgroundColor = component.backgroundColor
            let panelBackgroundColor = component.backgroundColor.withMultipliedAlpha(0.85)
            self.panelBackgroundView.updateColor(color: panelBackgroundColor, transition: .immediate)
            self.panelSeparatorView.backgroundColor = component.separatorColor
            
            self.component = component
            self.state = state
            
            let topPanelHeight: CGFloat = 42.0
            let topInset = component.topInset
            
            let controller = component.getController()
            let defaultToEmoji = controller?.defaultToEmoji ?? false
            
            let context = component.context
            let stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                context: context,
                forceTheme: controller?.forceDark == true ? defaultDarkColorPresentationTheme : nil,
                interaction: nil,
                chatPeerId: nil,
                present: { c, a in
                }
            )
            
            let isFullscreen = controller?.isFullscreen == true
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isContentInFocus: true,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0 + topInset, left: 0.0, bottom: component.bottomInset, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.content.emoji,
                    stickerContent: component.content.stickers,
                    maskContent: nil,
                    gifContent: component.content.gifs,
                    hasRecentGifs: !isFullscreen,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: defaultToEmoji,
                    externalTopPanelContainer: self.panelHostView,
                    externalBottomPanelContainer: nil,
                    displayTopPanelBackground: .blur,
                    topPanelExtensionUpdated: { _, _ in
                    },
                    topPanelScrollingOffset: { [weak self] offset, transition in
                        if let self {
                            if self.ignoreNextZeroScrollingOffset && offset == 0.0 {
                            } else {
                                self.ignoreNextZeroScrollingOffset = false
                                self.topPanelScrollingOffset = offset
                            }
                        }
                    },
                    hideInputUpdated: { [weak self] _, searchVisible, transition in
                        guard let self else {
                            return
                        }
                        self.forceUpdate = true
                        self.searchVisible = searchVisible
                        self.state?.updated(transition: transition)
                    },
                    hideTopPanelUpdated: { _, _ in
                    },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { [weak self] content in
                        guard let self, let interaction = self.interaction, let inputNodeInteraction = self.inputNodeInteraction, let component = self.component, let controller = component.getController() else {
                            return nil
                        }

                        let mappedMode: ChatMediaInputSearchMode
                        switch content {
                        case .stickers:
                            mappedMode = .sticker
                        case .gifs:
                            mappedMode = .gif
                        }
                        
                        var presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if controller.forceDark == true {
                            presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                        }
                        let searchContainerNode = PaneSearchContainerNode(
                            context: context,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            interaction: interaction,
                            inputNodeInteraction: inputNodeInteraction,
                            mode: mappedMode,
                            stickerActionTitle: presentationData.strings.StickerPack_AddSticker,
                            trendingGifsPromise: self.component?.getController()?.node.trendingGifsPromise ?? Promise(nil),
                            cancel: {
                            },
                            peekBehavior: stickerPeekBehavior
                        )
                        searchContainerNode.openGifContextMenu = { [weak self] item, sourceNode, sourceRect, gesture, isSaved in
                            guard let self, let node = self.component?.getController()?.node else {
                                return
                            }
                            node.openGifContextMenu(file: item.file, contextResult: item.contextResult, sourceView: sourceNode.view, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
                        }
                        return searchContainerNode
                    },
                    contentIdUpdated: { [weak self] id in
                        guard let self else {
                            return
                        }
                        self.keyboardContentId = id
                    },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    inputHeight: 0.0,
                    displayBottomPanel: !isFullscreen,
                    isExpanded: true,
                    clipContentToTopPanel: false,
                    useExternalSearchContainer: false
                )),
                environment: {},
                forceUpdate: self.forceUpdate,
                containerSize: availableSize
            )
            self.forceUpdate = false
            if let keyboardComponentView = self.keyboardView.view {
                if keyboardComponentView.superview == nil {
                    self.keyboardClippingView.addSubview(keyboardComponentView)
                }
                
                if panelBackgroundColor.alpha < 0.01 {
                    self.keyboardClippingView.clipsToBounds = true
                } else {
                    self.keyboardClippingView.clipsToBounds = false
                }
                
                transition.setFrame(view: self.keyboardClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + topInset), size: CGSize(width: availableSize.width, height: availableSize.height - topPanelHeight - topInset)))
                self.keyboardClippingView.hitEdgeInsets = UIEdgeInsets(top: -topPanelHeight - topInset, left: 0.0, bottom: 0.0, right: 0.0)
                
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelHeight - topInset), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + topInset - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                
                transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: keyboardSize.width, height: topPanelHeight + topInset)))
                self.panelBackgroundView.update(size: self.panelBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                
                let topPanelAlpha: CGFloat
                if self.searchVisible || self.keyboardContentId == AnyHashable("gifs") {
                    topPanelAlpha = 0.0
                    if isFullscreen, let navigationBar = controller?.navigationBar, navigationBar.alpha > 0.0 {
                        transition.setAlpha(view: navigationBar.view, alpha: 0.0)
                    }
                } else if isFullscreen {
                    topPanelAlpha = 1.0
                    if let navigationBar = controller?.navigationBar, navigationBar.alpha < 1.0 {
                        transition.setAlpha(view: navigationBar.view, alpha: 1.0)
                    }
                } else {
                    topPanelAlpha = max(0.0, min(1.0, (self.topPanelScrollingOffset / 20.0)))
                }
            
                transition.setAlpha(view: self.panelBackgroundView, alpha: topPanelAlpha)
                transition.setAlpha(view: self.panelSeparatorView, alpha: topPanelAlpha)
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + topInset - UIScreenPixel), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
            }
            
            return availableSize
        }
        
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            
            if self.searchVisible, let keyboardView = self.keyboardView.view, let keyboardResult = keyboardView.hitTest(self.convert(point, to: keyboardView), with: event) {
                return keyboardResult
            }
            
            return result
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StickerPickerScreen: ViewController {
    final class Node: ViewControllerTracingNode, ASScrollViewDelegate, ASGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: StickerPickerScreen?
        private let theme: PresentationTheme
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let hostView: ComponentHostView<Empty>
        
        fileprivate var content: StickerPickerInputData?
        private let contentDisposable = MetaDisposable()
        private var hasRecentGifsDisposable: Disposable?
        fileprivate let trendingGifsPromise = Promise<ChatMediaInputGifPaneTrendingState?>(nil)
        private var scheduledEmojiContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        fileprivate var temporaryDismiss = false
        
        private var gifMode: GifPagerContentComponent.Subject? {
            didSet {
                if let gifMode = self.gifMode, gifMode != oldValue {
                    self.reloadGifContext()
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
        private let gifComponent = Promise<EntityKeyboardGifContent>()
        private var gifInputInteraction: GifPagerContentComponent.InputInteraction?
        
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
        
        private var storyStickersContentView: StoryStickersContentView?
                
        init(context: AccountContext, controller: StickerPickerScreen, theme: PresentationTheme) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.controller = controller
            self.theme = theme
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = SparseContainerView()
            self.containerView = SparseContainerView()
            self.hostView = ComponentHostView()
            
            super.init()
                        
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = .clear
            
            if !controller.isFullscreen {
                self.addSubnode(self.dim)
            }
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.hostView)
            
            if controller.hasInteractiveStickers {
                self.storyStickersContentView = StoryStickersContentView(
                    context: context,
                    weather: controller.weather
                )
                self.storyStickersContentView?.locationAction = { [weak self] in
                    self?.controller?.presentLocationPicker()
                }
                self.storyStickersContentView?.audioAction = { [weak self] in
                    self?.controller?.presentAudioPicker()
                }
                self.storyStickersContentView?.reactionAction = { [weak self] in
                    self?.controller?.addReaction()
                }
                self.storyStickersContentView?.linkAction = { [weak self] in
                    guard let self, let controller = self.controller else {
                        return
                    }
                    if controller.context.isPremium {
                        controller.addLink()
                    } else {
                        self.presentLinkPremiumSuggestion()
                    }
                }
                self.storyStickersContentView?.weatherAction = { [weak self] in
                    self?.controller?.addWeather()
                }
            }
            
            let gifItems: Signal<EntityKeyboardGifContent?, NoError>
            if controller.hasGifs {
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
                }).strict()
                
                self.trendingGifsPromise.set(.single(nil))
                self.trendingGifsPromise.set(paneGifSearchForQuery(context: context, query: "", offset: nil, incompleteResults: true, delayRequest: false, updateActivity: nil)
                |> map { items -> ChatMediaInputGifPaneTrendingState? in
                    if let items = items {
                        return ChatMediaInputGifPaneTrendingState(files: items.files, nextOffset: items.nextOffset)
                    } else {
                        return nil
                    }
                })
                
                let gifInputInteraction = GifPagerContentComponent.InputInteraction(
                    performItemAction: { [weak self] item, view, rect in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        if controller.completion(.video(item.file.media)) {
                            controller.dismiss(animated: true)
                        }
                    },
                    openGifContextMenu: { [weak self] item, sourceView, sourceRect, gesture, isSaved in
                        guard let self else {
                            return
                        }
                        self.openGifContextMenu(file: item.file, contextResult: item.contextResult, sourceView: sourceView, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
                    },
                    loadMore: { [weak self] token in
                        guard let strongSelf = self, let gifContext = strongSelf.gifContext else {
                            return
                        }
                        gifContext.loadMore(token: token)
                    },
                    openSearch: { [weak self] in
                        if let self, let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
                            if let pagerView = componentView.keyboardView.view as? EntityKeyboardComponent.View {
                                pagerView.openSearch()
                            }
                            self.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
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
                    hideBackground: true,
                    hasSearch: true
                )
                self.gifInputInteraction = gifInputInteraction
                
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
                        hideBackground: true
                    )
                ))
            } else {
                gifItems = .single(nil)
            }
            
            let data = combineLatest(
                queue: Queue.mainQueue(),
                controller.inputData,
                gifItems |> then(self.gifComponent.get() |> map(Optional.init)),
                self.stickerSearchState.get(),
                self.emojiSearchState.get()
            )
                        
            self.contentDisposable.set(data.start(next: { [weak self] inputData, gifData, stickerSearchState, emojiSearchState in
                if let strongSelf = self {
                    guard var inputData = inputData as? StickerPickerInputData else {
                        return
                    }
                                        
                    let presentationData = strongSelf.presentationData
                    inputData.gifs = gifData?.component
                    
                    if let emoji = inputData.emoji {
                        if let emojiSearchResult = emojiSearchState.result {
                            var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                            if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                                emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                                    text: presentationData.strings.EmojiSearch_SearchEmojiEmptyResult,
                                    iconFile: nil
                                )
                            }
                            
                            let defaultSearchState: EmojiPagerContentComponent.SearchState = emojiSearchResult.isPreset ? .active : .empty(hasResults: true)
                            inputData.emoji = emoji.withUpdatedItemGroups(panelItemGroups: emoji.panelItemGroups, contentItemGroups: emojiSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: emojiSearchResult.id, version: emojiSearchResult.version), emptySearchResults: emptySearchResults, searchState: emojiSearchState.isSearching ? .searching : defaultSearchState)
                        } else if emojiSearchState.isSearching {
                            inputData.emoji = emoji.withUpdatedItemGroups(panelItemGroups: emoji.panelItemGroups, contentItemGroups: emoji.contentItemGroups, itemContentUniqueId: emoji.itemContentUniqueId, emptySearchResults: emoji.emptySearchResults, searchState: .searching)
                        }
                    }
                    
                    if let stickers = inputData.stickers {
                        if let stickerSearchResult = stickerSearchState.result {
                            var stickerSearchResults: EmojiPagerContentComponent.EmptySearchResults?
                            if !stickerSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                                stickerSearchResults = EmojiPagerContentComponent.EmptySearchResults(
                                    text: presentationData.strings.EmojiSearch_SearchStickersEmptyResult,
                                    iconFile: nil
                                )
                            }
                            
                            let defaultSearchState: EmojiPagerContentComponent.SearchState = stickerSearchResult.isPreset ? .active : .empty(hasResults: true)
                            inputData.stickers = stickers.withUpdatedItemGroups(panelItemGroups: stickers.panelItemGroups, contentItemGroups: stickerSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: stickerSearchResult.id, version: stickerSearchResult.version), emptySearchResults: stickerSearchResults, searchState: stickerSearchState.isSearching ? .searching : defaultSearchState)
                        } else if stickerSearchState.isSearching {
                            inputData.stickers = stickers.withUpdatedItemGroups(panelItemGroups: stickers.panelItemGroups, contentItemGroups: stickers.contentItemGroups, itemContentUniqueId: stickers.itemContentUniqueId, emptySearchResults: stickers.emptySearchResults, searchState: .searching)
                        }
                    }
                    
                    strongSelf.updateContent(inputData)
                }
            }))
        }
        
        deinit {
            self.contentDisposable.dispose()
            self.emojiSearchDisposable.dispose()
            self.stickerSearchDisposable.dispose()
            self.hasRecentGifsDisposable?.dispose()
        }
        
        private func reloadGifContext() {
            if let gifInputInteraction = self.gifInputInteraction, let gifMode = self.gifMode, let context = self.controller?.context {
                self.gifContext = GifContext(context: context, subject: gifMode, gifInputInteraction: gifInputInteraction, trendingGifs: self.trendingGifsPromise.get())
            }
        }
        
        fileprivate func openGifContextMenu(file: FileMediaReference, contextResult: (ChatContextResultCollection, ChatContextResult)?, sourceView: UIView, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
            guard let controller = self.controller else {
                return
            }
            let context = controller.context
            
            let canSaveGif: Bool
            if file.media.fileId.namespace == Namespaces.Media.CloudFile {
                canSaveGif = true
            } else {
                canSaveGif = false
            }
            
            let _ = (context.engine.stickers.isGifSaved(id: file.media.fileId)
            |> deliverOnMainQueue).start(next: { [weak self] isGifSaved in
                var isGifSaved = isGifSaved
                if !canSaveGif {
                    isGifSaved = false
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                
                let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file.media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                
                let gallery = GalleryController(context: context, source: .standaloneMessage(message, nil), streamSingleVideo: true, replaceRootController: { _, _ in
                }, baseNavigationController: nil)
                gallery.setHintWillBePresentedInPreviewingContext(true)
                
                var items: [ContextMenuItem] = []
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaEditor_AddGif, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    if let self, let controller = self.controller {
                        if isSaved {
                            if controller.completion(.video(file.media)) {
                                self.controller?.dismiss(animated: true)
                            }
                        } else if let (_, result) = contextResult {
                            if case let .internalReference(reference) = result {
                                if let file = reference.file {
                                    if controller.completion(.video(file)) {
                                        self.controller?.dismiss(animated: true)
                                    }
                                }
                            }
                        }
                    }
                })))
                
                if isSaved || isGifSaved {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        
                        let _ = removeSavedGif(postbox: context.account.postbox, mediaId: file.media.fileId).start()
                    })))
                } else if canSaveGif && !isGifSaved {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Preview_SaveGif, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        
                        guard let self else {
                            return
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let _ = (toggleGifSaved(account: context.account, fileReference: file, saved: true)
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let controller = self?.controller else {
                                return
                            }
                            switch result {
                            case .generic:
                                controller.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                            case let .limitExceeded(limit, premiumLimit):
                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                let text: String
                                if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                    text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                } else {
                                    text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                }
                                controller.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { [weak controller] action in
                                    if case .info = action, let controller {
                                        let premiumController = context.sharedContext.makePremiumIntroController(context: context, source: .savedGifs, forceDark: controller.forceDark, dismissed: nil)
                                        controller.pushController(premiumController)
                                        return true
                                    }
                                    return false
                                }), in: .window(.root))
                            }
                        })
                    })))
                }
                
                let contextController = ContextController(presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceView: sourceView, sourceRect: sourceRect)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                controller.presentInGlobalOverlay(contextController)
            })
        }
        
        func updateContent(_ content: StickerPickerInputData) {
            self.content = content
            
            guard let controller = self.controller else {
                return
            }
                        
            content.emoji?.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] groupId, item, _, _, _, _ in
                    guard let strongSelf = self, let controller = strongSelf.controller else {
                        return
                    }
                    let context = controller.context
                    if groupId == AnyHashable("featuredTop"), let file = item.itemFile {
                        let _ = (
                        combineLatest(
                            ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: controller.context.account.peerId, premiumIfSavedMessages: true),
                            ChatEntityKeyboardInputNode.hasPremium(context: context, chatPeerId: controller.context.account.peerId, premiumIfSavedMessages: false)
                        )
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] hasPremium, hasGlobalPremium in
                            guard let self else {
                                return
                            }
                            
                            let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                            let _ = (combineLatest(
                                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                                context.account.postbox.combinedView(keys: [viewKey])
                            )
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] emojiPacksView, views in
                                guard let view = views.views[viewKey] as? OrderedItemListView else {
                                    return
                                }
                                guard let self else {
                                    return
                                }
                                                                
                                var installedCollectionIds = Set<ItemCollectionId>()
                                for (id, _, _) in emojiPacksView.collectionInfos {
                                    installedCollectionIds.insert(id)
                                }
                                
                                let stickerPacks = view.items.map({ $0.contents.get(FeaturedStickerPackItem.self)! }).filter({
                                    !installedCollectionIds.contains($0.info.id)
                                })
                                
                                for featuredStickerPack in stickerPacks {
                                    if featuredStickerPack.topItems.contains(where: { $0.file.fileId == file.fileId }) {
                                        if let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
                                            if let pagerView = componentView.keyboardView.view as? EntityKeyboardComponent.View, let emojiInputInteraction = self.content?.emoji?.inputInteractionHolder.inputInteraction, let controller = self.controller {
                                                pagerView.openCustomSearch(content: EmojiSearchContent(
                                                    context: context,
                                                    forceTheme: controller.forceDark ? defaultDarkPresentationTheme : nil,
                                                    items: stickerPacks,
                                                    initialFocusId: featuredStickerPack.info.id,
                                                    hasPremiumForUse: hasPremium,
                                                    hasPremiumForInstallation: hasGlobalPremium,
                                                    parentInputInteraction: emojiInputInteraction
                                                ))
                                            }
                                        }
                                        break
                                    }
                                }
                            })
                        })
                    } else if let file = item.itemFile {
                        if controller.completion(.file(.standalone(media: file), .sticker)) {
                            controller.dismiss(animated: true)
                        }
                    } else if case let .staticEmoji(emoji) = item.content {
                        if let image = generateImage(CGSize(width: 256.0, height: 256.0), scale: 1.0, rotatedContext: { size, context in
                            context.clear(CGRect(origin: .zero, size: size))

                            let attributedString = NSAttributedString(string: emoji, attributes: [NSAttributedString.Key.font: Font.regular(200), NSAttributedString.Key.foregroundColor: UIColor.white])
                            
                            let line = CTLineCreateWithAttributedString(attributedString)
                            let lineBounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
                            
                            let lineOffset = CGPoint(x: 1.0 - UIScreenPixel, y: 0.0)
                            let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0) + lineOffset.y)
                            
                            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                            
                            context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
                            CTLineDraw(line, context)
                            context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
                        }) {
                            if controller.completion(.image(image, .sticker)) {
                                controller.dismiss(animated: true)
                            }
                        } else {
                            controller.dismiss(animated: true)
                        }
                    }
                },
                deleteBackwards: nil,
                openStickerSettings: nil,
                openFeatured: nil,
                openSearch: {
                },
                addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                    guard let strongSelf = self, let controller = strongSelf.controller, let collectionId = groupId.base as? ItemCollectionId else {
                        return
                    }
                    let context = controller.context
                    let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
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
                                            return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
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
                clearGroup: { [weak self] groupId in
                    guard let strongSelf = self, let controller = strongSelf.controller else {
                        return
                    }
                    var presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
                    if controller.forceDark {
                        presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                    }
                    let context = controller.context
                    if groupId == AnyHashable("recent") {
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
                        context.sharedContext.mainWindow?.presentInGlobalOverlay(actionSheet)
                    } else if groupId == AnyHashable("popular") {
                        let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: presentationData.strings.Chat_ClearReactionsAlertText, parseMarkdown: true))
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Chat_ClearReactionsAlertAction, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupRemoved(id: "popular"))
                            let _ = context.engine.stickers.clearRecentlyUsedReactions().start()
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        context.sharedContext.mainWindow?.presentInGlobalOverlay(actionSheet)
                    }
                },
                editAction: { _ in },
                pushController: { c in
                },
                presentController: { c in
                },
                presentGlobalOverlayController: { c in
                },
                navigationController: { [weak self] in
                    return self?.controller?.navigationController as? NavigationController
                },
                requestUpdate: { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if !transition.animation.isImmediate, let (layout, navigationHeight) = strongSelf.currentLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
                    }
                },
                updateSearchQuery: { [weak self] query in
                    guard let self, let controller = self.controller else {
                        return
                    }
                    let context = controller.context
                    
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
                        
                            let hasPremium: Signal<Bool, NoError> = .single(true)
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
                                if hasPremium {
                                    remoteSignal = context.engine.stickers.searchEmoji(emojiString: Array(allEmoticons.keys))
                                } else {
                                    remoteSignal = .single(([], true))
                                }
                                return remoteSignal
                                |> mapToSignal { foundEmoji -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
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
                                        let animationData = EntityKeyboardAnimationData(file: itemFile)
                                        let item = EmojiPagerContentComponent.Item(
                                            animationData: animationData,
                                            content: .animation(animationData),
                                            itemFile: itemFile,
                                            subgroupId: nil,
                                            icon: .none,
                                            tintMode: animationData.isTemplate ? .primary : .none
                                        )
                                        items.append(item)
                                    }
                                    
                                    if hasPremium {
                                        appendUnicodeEmoji()
                                    }
                                
                                    return .single([EmojiPagerContentComponent.ItemGroup(
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
                                    )])
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
                        let resultSignal = context.engine.stickers.searchEmoji(category: value)
                        |> mapToSignal { files, isFinalResult -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                            var items: [EmojiPagerContentComponent.Item] = []
                            
                            var existingIds = Set<MediaId>()
                            for itemFile in files {
                                if existingIds.contains(itemFile.fileId) {
                                    continue
                                }
                                existingIds.insert(itemFile.fileId)
                                let animationData = EntityKeyboardAnimationData(file: itemFile)
                                let item = EmojiPagerContentComponent.Item(
                                    animationData: animationData,
                                    content: .animation(animationData),
                                    itemFile: itemFile, subgroupId: nil,
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
                updateScrollingToItemGroup: { [weak self] in
                    if let self, let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
                        componentView.scrolledToItemGroup()
                    }
                    self?.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                },
                onScroll: {},
                chatPeerId: nil,
                peekBehavior: nil,
                customLayout: nil,
                externalBackground: nil,
                externalExpansionView: nil,
                customContentView: nil,
                useOpaqueTheme: false,
                hideBackground: true,
                stateContext: nil,
                addImage: controller.hasGifs ? { [weak self] in
                    if let self, let controller = self.controller {
                        let _ = controller.completion(nil)
                        controller.dismiss(animated: true)
                        controller.presentGallery()
                    }
                } : nil
            )
            
            var stickerPeekBehavior: EmojiContentPeekBehaviorImpl?
            if let controller = self.controller {
                stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                    context: controller.context,
                    forceTheme: controller.forceDark ? defaultDarkColorPresentationTheme : nil,
                    interaction: nil,
                    chatPeerId: nil,
                    present: { [weak controller] c, a in
                        controller?.presentInGlobalOverlay(c, with: a)
                    }
                )
            }
            
            content.stickers?.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                performItemAction: { [weak self] groupId, item, _, _, _, _ in
                    guard let self, let controller = self.controller, let file = item.itemFile else {
                        return
                    }
                    let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
                    if groupId == AnyHashable("featuredTop") {
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
                        let _ = (controller.context.account.postbox.combinedView(keys: [viewKey])
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] views in
                            guard let self, let controller = self.controller, let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            for featuredStickerPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                                if featuredStickerPack.topItems.contains(where: { $0.file.fileId == file.fileId }) {
                                    controller.pushController(FeaturedStickersScreen(
                                        context: controller.context,
                                        highlightedPackId: featuredStickerPack.info.id,
                                        forceTheme: defaultDarkColorPresentationTheme,
                                        stickerActionTitle: presentationData.strings.StickerPack_AddSticker,
                                        sendSticker: { [weak self] fileReference, _, _ in
                                            guard let self, let controller = self.controller else {
                                                return false
                                            }
                                            if controller.completion(.file(fileReference, .sticker)) {
                                                controller.dismiss(animated: true)
                                            }
                                            return true
                                        }
                                    ))
                                    
                                    break
                                }
                            }
                        })
                    } else {
                        let reference: FileMediaReference
                        if groupId == AnyHashable("saved") {
                            reference = .savedSticker(media: file)
                        } else if groupId == AnyHashable("recent") {
                            reference = .recentSticker(media: file)
                        } else {
                            reference = .standalone(media: file)
                        }
                        let _ = controller.completion(.file(reference, .sticker))
                        controller.dismiss(animated: true)
                    }
                },
                deleteBackwards: nil,
                openStickerSettings: nil,
                openFeatured: nil,
                openSearch: { [weak self] in
                    if let self, let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
                        if let pagerView = componentView.keyboardView.view as? EntityKeyboardComponent.View {
                            pagerView.openSearch()
                        }
                        self.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                },
                addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                    guard let strongSelf = self, let controller = strongSelf.controller, let collectionId = groupId.base as? ItemCollectionId else {
                        return
                    }
                    let context = controller.context
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
                                            return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
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
                clearGroup: { [weak self] groupId in
                    guard let strongSelf = self, let controller = strongSelf.controller else {
                        return
                    }
                    let context = controller.context
                    if groupId == AnyHashable("recent") {
                        var presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        if controller.forceDark {
                            presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
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
                        context.sharedContext.mainWindow?.presentInGlobalOverlay(actionSheet)
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
                editAction: { _ in },
                pushController: { c in
                },
                presentController: { c in
                },
                presentGlobalOverlayController: { c in
                },
                navigationController: { [weak self] in
                    return self?.controller?.navigationController as? NavigationController
                },
                requestUpdate: { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if !transition.animation.isImmediate, let (layout, navigationHeight) = strongSelf.currentLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
                    }
                },
                updateSearchQuery: { [weak self] query in
                    guard let strongSelf = self, let controller = strongSelf.controller else {
                        return
                    }
                    let context = controller.context
                    
                    switch query {
                    case .none:
                        strongSelf.stickerSearchDisposable.set(nil)
                        strongSelf.stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false)
                    case .text:
                        strongSelf.stickerSearchDisposable.set(nil)
                        strongSelf.stickerSearchStateValue = EmojiSearchState(result: nil, isSearching: false)
                    case let .category(value):
                        let resultSignal = context.engine.stickers.searchStickers(category: value, scope: [.installed, .remote])
                        |> mapToSignal { files -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                            var items: [EmojiPagerContentComponent.Item] = []
                            
                            var existingIds = Set<MediaId>()
                            for item in files.items {
                                let itemFile = item.file
                                if existingIds.contains(itemFile.fileId) {
                                    continue
                                }
                                existingIds.insert(itemFile.fileId)
                                let animationData = EntityKeyboardAnimationData(file: itemFile)
                                let item = EmojiPagerContentComponent.Item(
                                    animationData: animationData,
                                    content: .animation(animationData),
                                    itemFile: itemFile, subgroupId: nil,
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
                            )], files.isFinalResult))
                        }
                            
                        var version = 0
                        strongSelf.stickerSearchDisposable.set((resultSignal
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let strongSelf = self else {
                                return
                            }
                            guard let group = result.items.first else {
                                return
                            }
                            if group.items.isEmpty && !result.isFinalResult {
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
                updateScrollingToItemGroup: { [weak self] in
                    if let self, let componentView = self.hostView.componentView as? StickerSelectionComponent.View {
                        componentView.scrolledToItemGroup()
                    }
                    self?.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                },
                onScroll: {},
                chatPeerId: nil,
                peekBehavior: stickerPeekBehavior,
                customLayout: nil,
                externalBackground: nil,
                externalExpansionView: nil,
                customContentView: self.storyStickersContentView,
                useOpaqueTheme: false,
                hideBackground: true,
                stateContext: nil,
                addImage: controller.hasGifs ? { [weak self] in
                    if let self, let controller = self.controller {
                        let _ = controller.completion(nil)
                        controller.dismiss(animated: true)
                        controller.presentGallery()
                    }
                } : nil
            )
            
            if let (layout, navigationHeight) = self.currentLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            if let controller = self.controller {
                controller.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
            }
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                let _ = self.controller?.completion(nil)
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let controller = self.controller, !controller.isFullscreen else {
                return false
            }
            if let (layout, _) = self.currentLayout {
                if layout.metrics.isTablet {
                    return false
                }
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                if otherGestureRecognizer is PagerPanGestureRecognizer {
                    return false
                } else if otherGestureRecognizer is UIPanGestureRecognizer, let scrollView = otherGestureRecognizer.view, scrollView.frame.width > scrollView.frame.height {
                    return false
                } else if otherGestureRecognizer is PeekControllerGestureRecognizer {
                    return false
                }
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            guard let controller = self.controller, !controller.isFullscreen else {
                return
            }
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            if !self.temporaryDismiss {
                self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
            }
        }
        
        func presentLinkPremiumSuggestion() {
            guard let controller = self.controller else {
                return
            }
            let tooltipController = UndoOverlayController(
                presentationData: self.presentationData,
                content: .linkCopied(
                    text: self.presentationData.strings.Story_Editor_TooltipLinkPremium
                ),
                elevatedLayout: true,
                position: .top,
                animateInAsReplacement: false, action: { [weak controller] action in
                    if case .info = action, let controller {
                        let _ = controller.completion(nil)
                        controller.dismiss(animated: true)
                        
                        let premiumController = controller.context.sharedContext.makePremiumIntroController(context: controller.context, source: .storiesLinks, forceDark: controller.forceDark, dismissed: nil)
                        controller.pushController(premiumController)
                        return true
                    }
                    return false
                }
            )
            controller.present(tooltipController, in: .window(.root))
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ComponentTransition) {
            guard let controller = self.controller else {
                return
            }
            self.currentLayout = (layout, navigationHeight)
                        
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            let effectiveExpanded = self.isExpanded || layout.metrics.isTablet
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            var bottomInset = layout.intrinsicInsets.bottom
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            var modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            if self.isDismissing {
                modalProgress = 0.0
            }
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            if self.isDismissing {
                return
            }
            
            let clipFrame: CGRect
            let contentFrame: CGRect
            if controller.isFullscreen {
                clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                contentFrame = clipFrame
            } else if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                    contentFrame = clipFrame
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    var containerTopInset: CGFloat = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                    contentFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height - topInset)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
                
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: floorToScreenPixels(min(layout.size.width - 20.0, floor(maxSide / 2.0)) * 0.66), height: floorToScreenPixels((min(layout.size.height, minSide) - verticalInset * 2.0) * 0.66))
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
                contentFrame = clipFrame
                
                bottomInset = 0.0
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
                        
            if let content = self.content {
                var stickersTransition: ComponentTransition = transition
                if let scheduledEmojiContentAnimationHint = self.scheduledEmojiContentAnimationHint {
                    self.scheduledEmojiContentAnimationHint = nil
                    let contentAnimation = scheduledEmojiContentAnimationHint
                    stickersTransition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(contentAnimation)
                }
                
                var contentSize = self.hostView.update(
                    transition: stickersTransition,
                    component: AnyComponent(
                        StickerSelectionComponent(
                            context: controller.context,
                            theme: self.theme,
                            strings: self.presentationData.strings,
                            deviceMetrics: layout.deviceMetrics,
                            topInset: controller.isFullscreen ? navigationHeight : 0.0,
                            bottomInset: bottomInset,
                            content: content,
                            backgroundColor: self.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.85),
                            separatorColor: self.theme.rootController.navigationBar.separatorColor,
                            getController: { [weak self] in
                                if let self {
                                    return self.controller
                                } else {
                                    return nil
                                }
                            }
                        )
                    ),
                    environment: {},
                    forceUpdate: true,
                    containerSize: CGSize(width: contentFrame.size.width, height: contentFrame.height)
                )
                contentSize.height = max(layout.size.height - navigationHeight, contentSize.height)
                transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            }
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let (layout, _) = self.currentLayout else {
                return 210.0
            }
            
            if let controller = self.controller, controller.isFullscreen {
                return 0.0
            }
            
            if case .compact = layout.metrics.widthClass {
                var factor: CGFloat = 0.2488
                if layout.size.width <= 320.0 {
                    factor = 0.15
                }
                return floor(max(layout.size.width, layout.size.height) * factor)
            } else {
                return 210.0
            }
        }
        
        private func findScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? PagerExpandableScrollView {
                    return (view, nil)
                }
                if let view = view as? GridNodeScrollerView {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            
            guard let controller = self.controller, !controller.isFullscreen else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
                        scrollViewAndListNode = nil
                    }
                    let scrollView = scrollViewAndListNode?.0
                    let listNode = scrollViewAndListNode?.1
                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
                case .changed:
                    guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if case let .known(value) = visibleContentOffset, value <= epsilon {
                        if let scrollView = scrollView {
                            scrollView.bounces = false
                            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if case let .known(value) = visibleContentOffset, value > 0.1 {
                            velocity = CGPoint()
                        } else if case .unknown = visibleContentOffset {
                            velocity = CGPoint()
                        } else if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        let _ = self.controller?.completion(nil)
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.isExpanded = isExpanded
            
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    public enum Weather {
        public struct LoadedWeather {
            public let emoji: String
            public let emojiFile: TelegramMediaFile
            public let temperature: Double
            
            public init(emoji: String, emojiFile: TelegramMediaFile, temperature: Double) {
                self.emoji = emoji
                self.emojiFile = emojiFile
                self.temperature = temperature
            }
        }
        
        case none
        case notDetermined
        case notAllowed
        case notPreloaded
        case fetching
        case loaded(StickerPickerScreen.Weather.LoadedWeather)
    }
    
    private let context: AccountContext
    private let theme: PresentationTheme
    let forceDark: Bool
    private let inputData: Signal<StickerPickerInput, NoError>
    let defaultToEmoji: Bool
    let isFullscreen: Bool
    let hasEmoji: Bool
    let hasGifs: Bool
    let hasInteractiveStickers: Bool
    let weather: Signal<StickerPickerScreen.Weather, NoError>
    
    private var currentLayout: ContainerViewLayout?
    
    public var pushController: (ViewController) -> Void = { _ in }
    public var presentController: (ViewController) -> Void = { _ in }
    
    public var completion: (DrawingStickerEntity.Content?) -> Bool = { _ in return true }
    
    public var presentGallery: () -> Void = { }
    public var presentLocationPicker: () -> Void = { }
    public var presentAudioPicker: () -> Void = { }
    public var addReaction: () -> Void = { }
    public var addLink: () -> Void = { }
    public var addWeather: () -> Void = { }
    
    public init(context: AccountContext, inputData: Signal<StickerPickerInput, NoError>, forceDark: Bool = false, expanded: Bool = false, defaultToEmoji: Bool = false, hasEmoji: Bool = true, hasGifs: Bool = false, hasInteractiveStickers: Bool = true, weather: Signal<StickerPickerScreen.Weather, NoError> = .single(.none)) {
        self.context = context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.theme = forceDark ? defaultDarkColorPresentationTheme : presentationData.theme
        self.forceDark = forceDark
        self.inputData = inputData
        self.isFullscreen = expanded
        self.defaultToEmoji = defaultToEmoji
        self.hasEmoji = hasEmoji
        self.hasGifs = hasGifs
        self.hasInteractiveStickers = hasInteractiveStickers
        self.weather = weather
        
        super.init(navigationBarPresentationData: expanded ? NavigationBarPresentationData(presentationData: presentationData) : nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        if expanded {
            self.title = presentationData.strings.Stickers_ChooseSticker_Title
            self.navigationPresentation = .modal
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, theme: self.theme)
        self.displayNodeDidLoad()
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if self.isFullscreen {
            super.dismiss(animated: flag, completion: completion)
        } else {
            if flag {
                self.node.animateOut(completion: {
                    super.dismiss(animated: false, completion: {})
                    completion?()
                })
            } else {
                super.dismiss(animated: false, completion: {})
                completion?()
            }
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
        
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat = 56.0
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
    }
}

private final class InteractiveStickerButtonContent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let title: String?
    let iconName: String?
    let iconFile: TelegramMediaFile?
    let useOpaqueTheme: Bool
    weak var tintContainerView: UIView?

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        title: String?,
        iconName: String?,
        iconFile: TelegramMediaFile? = nil,
        useOpaqueTheme: Bool,
        tintContainerView: UIView
    ) {
        self.context = context
        self.theme = theme
        self.title = title
        self.iconName = iconName
        self.iconFile = iconFile
        self.useOpaqueTheme = useOpaqueTheme
        self.tintContainerView = tintContainerView
    }
    
    public static func ==(lhs: InteractiveStickerButtonContent, rhs: InteractiveStickerButtonContent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.useOpaqueTheme != rhs.useOpaqueTheme {
            return false
        }
        return true
    }
    
    final class View: UIView {
        override public static var layerClass: AnyClass {
            return PassthroughLayer.self
        }
                
        private let backgroundLayer = SimpleLayer()
        let tintBackgroundLayer = SimpleLayer()
        
        private var loadingView: TextLoadingEffectView?
        private var icon: ComponentView<Empty>
        private var title: ComponentView<Empty>
        
        private var component: InteractiveStickerButtonContent?
    
        override init(frame: CGRect) {
            self.icon = ComponentView<Empty>()
            self.title = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.isExclusiveTouch = true
            
            self.layer.addSublayer(self.backgroundLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: InteractiveStickerButtonContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.backgroundLayer.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.11).cgColor
              
            let iconSize: CGSize
            let buttonSize: CGSize
            if let title = component.title {
                if let iconFile = component.iconFile {
                    iconSize = self.icon.update(
                        transition: .immediate,
                        component: AnyComponent(
                            LottieComponent(
                                content: LottieComponent.ResourceContent(context: component.context, file: iconFile, attemptSynchronously: true, providesPlaceholder: true),
                                color: nil,
                                placeholderColor: UIColor(rgb: 0xffffff, alpha: 0.4),
                                loop: !["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"].contains(component.iconName ?? "")
                            )
                        ),
                        environment: {},
                        containerSize: CGSize(width: 20.0, height: 20.0)
                    )
                } else {
                    iconSize = self.icon.update(
                        transition: .immediate,
                        component: AnyComponent(BundleIconComponent(
                            name: component.iconName ?? "",
                            tintColor: .white,
                            maxSize: CGSize(width: 20.0, height: 20.0)
                        )),
                        environment: {},
                        containerSize: availableSize
                    )
                }
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(Text(
                        text: title.uppercased(),
                        font: Font.with(size: 23.0, design: .camera),
                        color: .white
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                
                let padding: CGFloat = 7.0
                let spacing: CGFloat = 4.0
                buttonSize = CGSize(width: padding + iconSize.width + spacing + titleSize.width + padding, height: 34.0)
                
                if let view = self.icon.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: padding, y: floorToScreenPixels((buttonSize.height - iconSize.height) / 2.0)), size: iconSize))
                }
                if let view = self.title.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: padding + iconSize.width + spacing, y: floorToScreenPixels((buttonSize.height - titleSize.height) / 2.0)), size: titleSize))
                }
                
                if let loadingView = self.loadingView {
                    self.loadingView = nil
                    loadingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        loadingView.removeFromSuperview()
                    })
                }
            } else {
                buttonSize = CGSize(width: 87.0, height: 34.0)
                
                let loadingView: TextLoadingEffectView
                if let current = self.loadingView {
                    loadingView = current
                } else {
                    loadingView = TextLoadingEffectView()
                    self.addSubview(loadingView)
                    self.loadingView = loadingView
                }
            }
            
            self.backgroundLayer.cornerRadius = 6.0
            self.tintBackgroundLayer.cornerRadius = 6.0
            
            var transition = transition
            if self.backgroundLayer.frame.width.isZero {
                transition = .immediate
            }
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: buttonSize))
            
            if self.tintBackgroundLayer.superlayer == nil, let tintContainerView = component.tintContainerView {
                Queue.mainQueue().justDispatch {
                    let mappedFrame = self.convert(self.bounds, to: tintContainerView)
                    transition.setFrame(layer: self.tintBackgroundLayer, frame: mappedFrame)
                }
            }
            
            if let loadingView = self.loadingView {
                let loadingSize = CGSize(width: buttonSize.width - 18.0, height: 16.0)
                loadingView.update(color: UIColor.white, rect: CGRect(origin: .zero, size: loadingSize))
                loadingView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((buttonSize.width - loadingSize.width) / 2.0), y: floorToScreenPixels((buttonSize.width - loadingSize.width) / 2.0)), size: loadingSize)
            }
            
            return buttonSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class InteractiveReactionButtonContent: Component {
    let theme: PresentationTheme

    public init(
        theme: PresentationTheme
    ) {
        self.theme = theme
    }
    
    public static func ==(lhs: InteractiveReactionButtonContent, rhs: InteractiveReactionButtonContent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    final class View: UIView {
        override public static var layerClass: AnyClass {
            return PassthroughLayer.self
        }
                
        private var icon: ComponentView<Empty>
        
        private var component: InteractiveReactionButtonContent?
    
        override init(frame: CGRect) {
            self.icon = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.isExclusiveTouch = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: InteractiveReactionButtonContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let bounds = CGRect(origin: .zero, size: CGSize(width: 54.0, height: 54.0))
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Media Editor/Reaction",
                    tintColor: nil,
                    maxSize: CGSize(width: 52.0, height: 52.0)
                )),
                environment: {},
                containerSize: availableSize
            )
            
            if let view = self.icon.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 2.0, y: 0.0), size: iconSize))
            }
 
            return bounds.size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class RoundVideoButtonContent: Component {
    let theme: PresentationTheme

    public init(
        theme: PresentationTheme
    ) {
        self.theme = theme
    }
    
    public static func ==(lhs: RoundVideoButtonContent, rhs: RoundVideoButtonContent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    final class View: UIView {
        override public static var layerClass: AnyClass {
            return PassthroughLayer.self
        }
                
        private let backgroundLayer = SimpleLayer()
        private var icon: ComponentView<Empty>
        
        private var component: InteractiveReactionButtonContent?
    
        override init(frame: CGRect) {
            self.icon = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.isExclusiveTouch = true
            
            self.layer.addSublayer(self.backgroundLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: RoundVideoButtonContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.backgroundLayer.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.11).cgColor
            
            let bounds = CGRect(origin: .zero, size: CGSize(width: 54.0, height: 54.0))
            let backgroundSize = CGSize(width: 50.0, height: 50.0)
            self.backgroundLayer.frame = backgroundSize.centered(in: bounds)
            self.backgroundLayer.cornerRadius = backgroundSize.width / 2.0
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat List/Tabs/IconCamera",
                    tintColor: nil,
                    maxSize: CGSize(width: 30.0, height: 30.0)
                )),
                environment: {},
                containerSize: availableSize
            )
            
            if let view = self.icon.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: iconSize.centered(in: bounds))
            }
 
            return bounds.size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ItemStack<ChildEnvironment: Equatable>: CombinedComponent {
    typealias EnvironmentType = ChildEnvironment

    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let padding: CGFloat
    private let minSpacing: CGFloat
    private let verticalSpacing: CGFloat
    private let maxHorizontalItems: Int

    init(_ items: [AnyComponentWithIdentity<ChildEnvironment>], padding: CGFloat, minSpacing: CGFloat, verticalSpacing: CGFloat, maxHorizontalItems: Int) {
        self.items = items
        self.padding = padding
        self.minSpacing = minSpacing
        self.verticalSpacing = verticalSpacing
        self.maxHorizontalItems = maxHorizontalItems
    }

    static func ==(lhs: ItemStack<ChildEnvironment>, rhs: ItemStack<ChildEnvironment>) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.padding != rhs.padding {
            return false
        }
        if lhs.minSpacing != rhs.minSpacing {
            return false
        }
        if lhs.verticalSpacing != rhs.verticalSpacing {
            return false
        }
        if lhs.maxHorizontalItems != rhs.maxHorizontalItems {
            return false
        }
        return true
    }

    static var body: Body {
        let children = ChildMap(environment: ChildEnvironment.self, keyedBy: AnyHashable.self)

        return { context in
            let updatedChildren = context.component.items.map { item in
                return children[item.id].update(
                    component: item.component, environment: {
                        context.environment[ChildEnvironment.self]
                    },
                    availableSize: context.availableSize,
                    transition: context.transition
                )
            }

            var groups: [[Int]] = []
            var currentGroup: [Int] = []
            for i in 0 ..< updatedChildren.count {
                var itemsWidth: CGFloat = 0.0
                for j in currentGroup {
                    itemsWidth += updatedChildren[j].size.width
                }
                itemsWidth += updatedChildren[i].size.width
                let rowItemsCount = currentGroup.count + 1
                
                let remainingWidth = context.availableSize.width - itemsWidth - context.component.padding * 2.0
                let spacing = remainingWidth / CGFloat(rowItemsCount - 1)
                if spacing < context.component.minSpacing || currentGroup.count == context.component.maxHorizontalItems {
                    groups.append(currentGroup)
                    currentGroup = []
                }
                currentGroup.append(i)
            }
            if !currentGroup.isEmpty {
                groups.append(currentGroup)
            }
            
            var size = CGSize(width: context.availableSize.width, height: 0.0)
            for group in groups {
                var groupHeight: CGFloat = 0.0
                var spacing = context.component.minSpacing
                var itemsWidth = 0.0
                for i in group {
                    let childSize = updatedChildren[i].size
                    groupHeight = max(groupHeight, childSize.height)
                    itemsWidth += childSize.width
                }
                let remainingWidth = context.availableSize.width - itemsWidth - context.component.padding * 2.0
                spacing = remainingWidth / CGFloat(group.count - 1)
                
                var useCenteredLayout = false
                if spacing > 30.0 || group.count == 1 {
                    spacing = 30.0
                    useCenteredLayout = true
                }
                
                var nextX: CGFloat
                if useCenteredLayout {
                    let totalWidth = itemsWidth + spacing * CGFloat(group.count - 1)
                    nextX = floorToScreenPixels((size.width - totalWidth) / 2.0)
                } else {
                    nextX = context.component.padding
                }
                for i in group {
                    let child = updatedChildren[i]
                    let frame = CGRect(origin: CGPoint(x: nextX, y: size.height + floorToScreenPixels((groupHeight - child.size.height) / 2.0)), size: child.size)
                    
                    context.add(child
                        .position(child.size.centered(in: frame).center)
                    )
                    nextX += child.size.width + spacing
                }
                size.height += groupHeight + context.component.verticalSpacing
            }

            return size
        }
    }
}

final class StoryStickersContentView: UIView, EmojiCustomContentView {
    private let context: AccountContext
    
    let tintContainerView = UIView()
    private let container = ComponentView<Empty>()
        
    private var weatherDisposable: Disposable?
    private var weather: StickerPickerScreen.Weather = .none
    
    var locationAction: () -> Void = {}
    var audioAction: () -> Void = {}
    var reactionAction: () -> Void = {}
    var linkAction: () -> Void = {}
    var weatherAction: () -> Void = {}
        
    private var params: (theme: PresentationTheme, strings: PresentationStrings, useOpaqueTheme: Bool, availableSize: CGSize)?
    
    init(context: AccountContext, weather: Signal<StickerPickerScreen.Weather, NoError>) {
        self.context = context
        
        super.init(frame: .zero)
                
        self.weatherDisposable = (weather
        |> deliverOnMainQueue).start(next: { [weak self] weather in
            guard let self else {
                return
            }
            self.weather = weather
            if let (theme, strings, useOpaqueTheme, availableSize) = self.params {
                let _ = self.update(theme: theme, strings: strings, useOpaqueTheme: useOpaqueTheme, availableSize: availableSize, transition: .easeInOut(duration: 0.25))
            }
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.weatherDisposable?.dispose()
    }
    
    func update(theme: PresentationTheme, strings: PresentationStrings, useOpaqueTheme: Bool, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
        self.params = (theme, strings, useOpaqueTheme, availableSize)
        
        let padding: CGFloat = 22.0
        var maxHorizontalItems = 2
        var items: [AnyComponentWithIdentity<Empty>] = []
        items.append(
            AnyComponentWithIdentity(
                id: "link",
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "content",
                            component: AnyComponent(
                                InteractiveStickerButtonContent(
                                    context: self.context,
                                    theme: theme,
                                    title: strings.MediaEditor_AddLink,
                                    iconName: self.context.isPremium ? "Media Editor/Link" : "Media Editor/LinkLocked",
                                    useOpaqueTheme: useOpaqueTheme,
                                    tintContainerView: self.tintContainerView
                                )
                            )
                        ),
                        action: { [weak self] in
                            if let self {
                                self.linkAction()
                            }
                        })
                )
            )
        )
        items.append(
            AnyComponentWithIdentity(
                id: "location",
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "content",
                            component: AnyComponent(
                                InteractiveStickerButtonContent(
                                    context: self.context,
                                    theme: theme,
                                    title: strings.MediaEditor_AddLocationShort,
                                    iconName: "Chat/Attach Menu/Location",
                                    useOpaqueTheme: useOpaqueTheme,
                                    tintContainerView: self.tintContainerView
                                )
                            )
                        ),
                        action: { [weak self] in
                            if let self {
                                self.locationAction()
                            }
                        })
                )
            )
        )
        
        if case .none = self.weather {
            
        } else {
            maxHorizontalItems = 3
            
            let weatherButtonContent: AnyComponent<Empty>
            switch self.weather {
            case .notAllowed, .notDetermined, .notPreloaded:
                weatherButtonContent = AnyComponent(
                    InteractiveStickerButtonContent(
                        context: self.context,
                        theme: theme,
                        title: stringForTemperature(24),
                        iconName: "☀️",
                        iconFile: self.context.animatedEmojiStickersValue["☀️"]?.first?.file,
                        useOpaqueTheme: useOpaqueTheme,
                        tintContainerView: self.tintContainerView
                    )
                )
            case let .loaded(weather):
                weatherButtonContent = AnyComponent(
                    InteractiveStickerButtonContent(
                        context: self.context,
                        theme: theme,
                        title: stringForTemperature(weather.temperature),
                        iconName: weather.emoji,
                        iconFile: weather.emojiFile,
                        useOpaqueTheme: useOpaqueTheme,
                        tintContainerView: self.tintContainerView
                    )
                )
            case .fetching:
                weatherButtonContent = AnyComponent(
                    InteractiveStickerButtonContent(
                        context: self.context,
                        theme: theme,
                        title: nil,
                        iconName: nil,
                        useOpaqueTheme: useOpaqueTheme,
                        tintContainerView: self.tintContainerView
                    )
                )
            default:
                fatalError()
            }
            items.append(
                AnyComponentWithIdentity(
                    id: "weather",
                    component: AnyComponent(
                        CameraButton(
                            content: AnyComponentWithIdentity(
                                id: "weather",
                                component: weatherButtonContent
                            ),
                            action: { [weak self] in
                                if let self {
                                    self.weatherAction()
                                }
                            })
                    )
                )
            )
        }
        
        items.append(
            AnyComponentWithIdentity(
                id: "audio",
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "audio",
                            component: AnyComponent(
                                InteractiveStickerButtonContent(
                                    context: self.context,
                                    theme: theme,
                                    title: strings.MediaEditor_AddAudio,
                                    iconName: "Media Editor/Audio",
                                    useOpaqueTheme: useOpaqueTheme,
                                    tintContainerView: self.tintContainerView
                                )
                            )
                        ),
                        action: { [weak self] in
                            if let self {
                                self.audioAction()
                            }
                        })
                )
            )
        )
        
        items.append(
            AnyComponentWithIdentity(
                id: "reaction",
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "reaction",
                            component: AnyComponent(
                                InteractiveReactionButtonContent(theme: theme)
                            )
                        ),
                        action: { [weak self] in
                            if let self {
                                self.reactionAction()
                            }
                        })
                )
            )
        )
        
        let size = self.container.update(
            transition: transition,
            component: AnyComponent(
                ItemStack(
                    items,
                    padding: 18.0,
                    minSpacing: 8.0,
                    verticalSpacing: 12.0,
                    maxHorizontalItems: maxHorizontalItems
                )
            ),
            environment: {},
            containerSize: availableSize
        )
        if let view = self.container.view {
            if view.superview == nil {
                self.addSubview(view)
            }
            view.frame = CGRect(origin: CGPoint(x: 0.0, y: padding), size: size)
        }
        
        return CGSize(width: size.width, height: size.height + padding * 2.0 - 12.0)
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
