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
import StickerPackPreviewUI

public struct StickerPickerInputData: Equatable {
    var emoji: EmojiPagerContentComponent
    var stickers: EmojiPagerContentComponent?
    var masks: EmojiPagerContentComponent?
    
    public init(
        emoji: EmojiPagerContentComponent,
        stickers: EmojiPagerContentComponent?,
        masks: EmojiPagerContentComponent?
    ) {
        self.emoji = emoji
        self.stickers = stickers
        self.masks = masks
    }
}

private final class StickerSelectionComponent: Component {
    typealias EnvironmentType = Empty
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let deviceMetrics: DeviceMetrics
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
    
    public final class View: UIView {
        fileprivate let keyboardView: ComponentView<Empty>
        private let keyboardClippingView: UIView
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelBackgroundView: BlurredBackgroundView
        private let panelSeparatorView: UIView
        
        private var component: StickerSelectionComponent?
        private weak var state: EmptyComponentState?
        
        private var interaction: ChatEntityKeyboardInputNode.Interaction?
        private var inputNodeInteraction: ChatMediaInputNodeInteraction?
        private let trendingGifsPromise = Promise<ChatMediaInputGifPaneTrendingState?>(nil)
        
        private var searchVisible = false
        private var forceUpdate = false
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.keyboardClippingView = UIView()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.panelSeparatorView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.keyboardClippingView)
            self.addSubview(self.panelBackgroundView)
            self.addSubview(self.panelSeparatorView)
            self.addSubview(self.panelHostView)
            
            self.interaction = ChatEntityKeyboardInputNode.Interaction(
                sendSticker: { [weak self] file, silent, schedule, query, clearInput, sourceView, sourceRect, sourceLayer, _ in
                    if let self, let controller = self.component?.getController() {
                        controller.completion(.file(file.media))
                        controller.forEachController { c in
                            if let c = c as? StickerPackScreenImpl {
                                c.dismiss(animated: true)
                            }
                            return true
                        }
                        controller.window?.forEachController({ c in
                            if let c = c as? StickerPackScreenImpl {
                                c.dismiss(animated: true)
                            }
                        })
                        controller.dismiss(animated: true)
                    }
                    return false
                },
                sendEmoji: { _, _, _ in
                },
                sendGif: { _, _, _, _, _ in
                    return false
                },
                sendBotContextResultAsGif: { _, _, _, _, _, _ in
                    return false
                },
                updateChoosingSticker: { _ in },
                switchToTextInput: {},
                dismissTextInput: {},
                insertText: { _ in
                },
                backwardsDeleteText: {},
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
        
        func update(component: StickerSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.backgroundColor = component.backgroundColor
            let panelBackgroundColor = component.backgroundColor.withMultipliedAlpha(0.85)
            self.panelBackgroundView.updateColor(color: panelBackgroundColor, transition: .immediate)
            self.panelSeparatorView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.1)
            
            self.component = component
            self.state = state
            
            let topPanelHeight: CGFloat = 42.0
            
            let defaultToEmoji = component.getController()?.defaultToEmoji ?? false
            
            let context = component.context
            let stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                context: context,
                forceTheme: defaultDarkColorPresentationTheme,
                interaction: nil,
                chatPeerId: nil,
                present: { c, a in
                    let _ = c
                    let _ = a
//                    controller?.presentInGlobalOverlay(c, with: a)
                }
            )
            
            let trendingGifsPromise = self.trendingGifsPromise
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isContentInFocus: true,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0, left: 0.0, bottom: component.bottomInset, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.content.emoji,
                    stickerContent: component.content.stickers,
                    maskContent: component.content.masks,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: defaultToEmoji,
                    externalTopPanelContainer: self.panelHostView,
                    externalBottomPanelContainer: nil,
                    displayTopPanelBackground: .blur,
                    topPanelExtensionUpdated: { _, _ in },
                    hideInputUpdated: { [weak self] _, searchVisible, transition in
                        guard let self else {
                            return
                        }
                        self.forceUpdate = true
                        self.searchVisible = searchVisible
                        self.state?.updated(transition: transition)
                    },
                    hideTopPanelUpdated: { _, _ in
                        print()
                    },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { [weak self] content in
                        guard let self, let interaction = self.interaction, let inputNodeInteraction = self.inputNodeInteraction else {
                            return nil
                        }

                        let mappedMode: ChatMediaInputSearchMode
                        switch content {
                        case .stickers:
                            mappedMode = .sticker
                        case .gifs:
                            mappedMode = .gif
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
                        let searchContainerNode = PaneSearchContainerNode(
                            context: context,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            interaction: interaction,
                            inputNodeInteraction: inputNodeInteraction,
                            mode: mappedMode,
                            stickerActionTitle: presentationData.strings.StickerPack_AddSticker,
                            trendingGifsPromise: trendingGifsPromise,
                            cancel: {
                            },
                            peekBehavior: stickerPeekBehavior
                        )
                        return searchContainerNode
                    },
                    contentIdUpdated: { _ in },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    inputHeight: 0.0,
                    displayBottomPanel: true,
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
                
                transition.setFrame(view: self.keyboardClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: availableSize.width, height: availableSize.height - topPanelHeight)))
                
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelHeight), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                
                transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: keyboardSize.width, height: topPanelHeight)))
                self.panelBackgroundView.update(size: self.panelBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                
                transition.setAlpha(view: self.panelBackgroundView, alpha: self.searchVisible ? 0.0 : 1.0)
                transition.setAlpha(view: self.panelSeparatorView, alpha: self.searchVisible ? 0.0 : 1.0)
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StickerPickerScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: StickerPickerScreen?
        private let theme: PresentationTheme
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let hostView: ComponentHostView<Empty>
        
        private var content: StickerPickerInputData?
        private let contentDisposable = MetaDisposable()
        private var scheduledEmojiContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        fileprivate var temporaryDismiss = false
        
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
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.hostView)
            
            let signal = combineLatest(
                queue: Queue.mainQueue(),
                controller.inputData,
                self.stickerSearchState.get(),
                self.emojiSearchState.get()
            )
            
            
            self.contentDisposable.set(signal.start(next: { [weak self] inputData, stickerSearchState, emojiSearchState in
                if let strongSelf = self {
                    let presentationData = strongSelf.presentationData
                    var inputData = inputData
                    
                    let emoji = inputData.emoji
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
                    
                    strongSelf.updateContent(inputData)
                }
            }))
        }
        
        deinit {
            self.contentDisposable.dispose()
            self.emojiSearchDisposable.dispose()
            self.stickerSearchDisposable.dispose()
        }
        
        func updateContent(_ content: StickerPickerInputData) {
            self.content = content
            
            content.emoji.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
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
                                            if let pagerView = componentView.keyboardView.view as? EntityKeyboardComponent.View, let emojiInputInteraction = self.content?.emoji.inputInteractionHolder.inputInteraction {
                                                pagerView.openCustomSearch(content: EmojiSearchContent(
                                                    context: context,
                                                    forceTheme: defaultDarkPresentationTheme,
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
                        strongSelf.controller?.completion(.file(file))
                        strongSelf.controller?.dismiss(animated: true)
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
                            strongSelf.controller?.completion(.image(image, .sticker))
                        }
                        strongSelf.controller?.dismiss(animated: true)
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
                    let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
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
                                        actionButtonTitle: nil,
                                        isFeatured: false,
                                        isPremiumLocked: false,
                                        isEmbedded: false,
                                        hasClear: false,
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
                        let resultSignal = context.engine.stickers.searchEmoji(emojiString: value)
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
                                actionButtonTitle: nil,
                                isFeatured: false,
                                isPremiumLocked: false,
                                isEmbedded: false,
                                hasClear: false,
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
                                        actionButtonTitle: nil,
                                        isFeatured: false,
                                        isPremiumLocked: false,
                                        isEmbedded: false,
                                        hasClear: false,
                                        collapsedLineCount: nil,
                                        displayPremiumBadges: false,
                                        headerItem: nil,
                                        fillWithLoadingPlaceholders: true,
                                        items: []
                                    )
                                ], id: AnyHashable(value), version: version, isPreset: true), isSearching: false)
                                return
                            }
                            self.emojiSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value), version: version, isPreset: true), isSearching: false)
                            version += 1
                        }))
                    }
                },
                updateScrollingToItemGroup: { [weak self] in
                    self?.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                },
                onScroll: {},
                chatPeerId: nil,
                peekBehavior: nil,
                customLayout: nil,
                externalBackground: nil,
                externalExpansionView: nil,
                useOpaqueTheme: false,
                hideBackground: true,
                stateContext: nil,
                addImage: { [weak self] in
                    if let self {
                        self.controller?.completion(nil)
                        self.controller?.dismiss(animated: true)
                        self.controller?.presentGallery()
                    }
                }
            )
            
            var stickerPeekBehavior: EmojiContentPeekBehaviorImpl?
            if let controller = self.controller {
                stickerPeekBehavior = EmojiContentPeekBehaviorImpl(
                    context: controller.context,
                    forceTheme: defaultDarkColorPresentationTheme,
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
                                    controller.push(FeaturedStickersScreen(
                                        context: controller.context,
                                        highlightedPackId: featuredStickerPack.info.id,
                                        forceTheme: defaultDarkPresentationTheme,
                                        sendSticker: { [weak self] fileReference, _, _ in
                                            guard let self else {
                                                return false
                                            }
                                            self.controller?.completion(.file(fileReference.media))
                                            self.controller?.dismiss(animated: true)
                                            return true
                                        }
                                    ))
                                    
                                    break
                                }
                            }
                        })
                    } else {
                        self.controller?.completion(.file(file))
                        self.controller?.dismiss(animated: true)
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
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
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
                        let resultSignal = context.engine.stickers.searchStickers(query: value, scope: [.installed, .remote])
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
                                actionButtonTitle: nil,
                                isFeatured: false,
                                isPremiumLocked: false,
                                isEmbedded: false,
                                hasClear: false,
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
                                //strongSelf.stickerSearchStateValue.isSearching = true
                                strongSelf.stickerSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: [
                                    EmojiPagerContentComponent.ItemGroup(
                                        supergroupId: "search",
                                        groupId: "search",
                                        title: nil,
                                        subtitle: nil,
                                        actionButtonTitle: nil,
                                        isFeatured: false,
                                        isPremiumLocked: false,
                                        isEmbedded: false,
                                        hasClear: false,
                                        collapsedLineCount: nil,
                                        displayPremiumBadges: false,
                                        headerItem: nil,
                                        fillWithLoadingPlaceholders: true,
                                        items: []
                                    )
                                ], id: AnyHashable(value), version: version, isPreset: true), isSearching: false)
                                return
                            }
                            strongSelf.stickerSearchStateValue = EmojiSearchState(result: EmojiSearchResult(groups: result.items, id: AnyHashable(value), version: version, isPreset: true), isSearching: false)
                            version += 1
                        }))
                    }
                },
                updateScrollingToItemGroup: { [weak self] in
                    self?.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
                },
                onScroll: {},
                chatPeerId: nil,
                peekBehavior: stickerPeekBehavior,
                customLayout: nil,
                externalBackground: nil,
                externalExpansionView: nil,
                useOpaqueTheme: false,
                hideBackground: true,
                stateContext: nil,
                addImage: { [weak self] in
                    if let self {
                        self.controller?.completion(nil)
                        self.controller?.dismiss(animated: true)
                        self.controller?.presentGallery()
                    }
                }
            )
            
            if let (layout, navigationHeight) = self.currentLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.completion(nil)
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let (layout, _) = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
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
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            guard let controller = self.controller else {
                return
            }
            self.currentLayout = (layout, navigationHeight)
                        
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
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
                        
            let clipFrame: CGRect
            let contentFrame: CGRect
            if layout.metrics.widthClass == .compact {
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
                var stickersTransition: Transition = transition
                if let scheduledEmojiContentAnimationHint = self.scheduledEmojiContentAnimationHint {
                    self.scheduledEmojiContentAnimationHint = nil
                    let contentAnimation = scheduledEmojiContentAnimationHint
                    stickersTransition = Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(contentAnimation)
                }
                
                var contentSize = self.hostView.update(
                    transition: stickersTransition,
                    component: AnyComponent(
                        StickerSelectionComponent(
                            context: controller.context,
                            theme: self.theme,
                            strings: self.presentationData.strings,
                            deviceMetrics: layout.deviceMetrics,
                            bottomInset: bottomInset,
                            content: content,
                            backgroundColor: self.theme.list.itemBlocksBackgroundColor,
                            separatorColor: self.theme.list.blocksBackgroundColor,
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
            guard let (layout, _) = self.currentLayout else{
                return 210.0
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
                        self.controller?.completion(nil)
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

                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
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
                    
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
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
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let theme: PresentationTheme
    private let inputData: Signal<StickerPickerInputData, NoError>
    fileprivate let defaultToEmoji: Bool
    
    private var currentLayout: ContainerViewLayout?
    
    public var pushController: (ViewController) -> Void = { _ in }
    public var presentController: (ViewController) -> Void = { _ in }
    
    public var completion: (DrawingStickerEntity.Content?) -> Void = { _ in }
    
    public var presentGallery: () -> Void = { }
    
    public init(context: AccountContext, inputData: Signal<StickerPickerInputData, NoError>, defaultToEmoji: Bool = false) {
        self.context = context
        self.theme = defaultDarkColorPresentationTheme
        self.inputData = inputData
        self.defaultToEmoji = defaultToEmoji
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
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
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
    }
}
