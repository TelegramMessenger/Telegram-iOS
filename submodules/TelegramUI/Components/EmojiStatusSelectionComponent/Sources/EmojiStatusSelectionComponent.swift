import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AnimationCache
import MultiAnimationRenderer
import EntityKeyboard
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import PagerComponent
import Postbox
import TelegramCore
import Lottie
import EmojiTextAttachmentView
import TextFormat
import AppBundle
import GZip
import EmojiStatusComponent

private func randomGenericReactionEffect(context: AccountContext) -> Signal<String?, NoError> {
    return context.engine.stickers.loadedStickerPack(reference: .emojiGenericAnimations, forceActualized: false)
    |> map { result -> [TelegramMediaFile]? in
        switch result {
        case let .result(_, items, _):
            return items.map(\.file)
        default:
            return nil
        }
    }
    |> take(1)
    |> mapToSignal { items -> Signal<String?, NoError> in
        guard let items = items else {
            return .single(nil)
        }
        guard let file = items.randomElement() else {
            return .single(nil)
        }
        return Signal { subscriber in
            let fetchDisposable = freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file)).start()
            let dataDisposable = (context.account.postbox.mediaBox.resourceData(file.resource)
            |> filter(\.complete)
            |> take(1)).start(next: { data in
                subscriber.putNext(data.path)
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                fetchDisposable.dispose()
                dataDisposable.dispose()
            }
        }
    }
}

public final class EmojiStatusSelectionComponent: Component {
    public typealias EnvironmentType = Empty
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let deviceMetrics: DeviceMetrics
    public let emojiContent: EmojiPagerContentComponent
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let hideTopPanel: Bool
    public let hideTopPanelUpdated: (Bool, Transition) -> Void
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        deviceMetrics: DeviceMetrics,
        emojiContent: EmojiPagerContentComponent,
        backgroundColor: UIColor,
        separatorColor: UIColor,
        hideTopPanel: Bool,
        hideTopPanelUpdated: @escaping (Bool, Transition) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.deviceMetrics = deviceMetrics
        self.emojiContent = emojiContent
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.hideTopPanel = hideTopPanel
        self.hideTopPanelUpdated = hideTopPanelUpdated
    }
    
    public static func ==(lhs: EmojiStatusSelectionComponent, rhs: EmojiStatusSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.emojiContent != rhs.emojiContent {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        if lhs.hideTopPanel != rhs.hideTopPanel {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let keyboardView: ComponentView<Empty>
        private let keyboardClippingView: UIView
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelBackgroundView: BlurredBackgroundView
        private let panelSeparatorView: UIView
        
        private var component: EmojiStatusSelectionComponent?
        private weak var state: EmptyComponentState?
        
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
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: EmojiStatusSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.backgroundColor = component.backgroundColor
            let panelBackgroundColor = component.backgroundColor.withMultipliedAlpha(0.85)
            self.panelBackgroundView.updateColor(color: panelBackgroundColor, transition: .immediate)
            self.panelSeparatorView.backgroundColor = component.separatorColor
            
            self.component = component
            self.state = state
            
            let topPanelHeight: CGFloat = component.hideTopPanel ? 0.0 : 42.0
            
            let keyboardSize = self.keyboardView.update(
                transition: transition.withUserData(EmojiPagerContentComponent.SynchronousLoadBehavior(isDisabled: true)),
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    isContentInFocus: true,
                    containerInsets: UIEdgeInsets(top: topPanelHeight - 34.0, left: 0.0, bottom: 0.0, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.emojiContent,
                    stickerContent: nil,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: true,
                    externalTopPanelContainer: self.panelHostView,
                    topPanelExtensionUpdated: { _, _ in },
                    hideInputUpdated: { _, _, _ in },
                    hideTopPanelUpdated: { [weak self] hideTopPanel, transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.component?.hideTopPanelUpdated(hideTopPanel, transition)
                    },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    reorderItems: { _, _ in },
                    makeSearchContainerNode: { _ in return nil },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    displayBottomPanel: false,
                    isExpanded: false
                )),
                environment: {},
                containerSize: availableSize
            )
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
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: component.hideTopPanel ? -UIScreenPixel : topPanelHeight), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
                transition.setAlpha(view: self.panelSeparatorView, alpha: component.hideTopPanel ? 0.0 : 1.0)
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class EmojiStatusSelectionController: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: EmojiStatusSelectionController?
        private let context: AccountContext
        private weak var sourceView: UIView?
        private var globalSourceRect: CGRect?
        
        private let componentHost: ComponentView<Empty>
        private let componentShadowLayer: SimpleLayer
        
        private let cloudLayer0: SimpleLayer
        private let cloudShadowLayer0: SimpleLayer
        private let cloudLayer1: SimpleLayer
        private let cloudShadowLayer1: SimpleLayer
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        private let currentSelection: Int64?
        
        private var emojiContentDisposable: Disposable?
        private var emojiContent: EmojiPagerContentComponent?
        private var freezeUpdates: Bool = false
        private var scheduledEmojiContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
        
        private let emojiSearchDisposable = MetaDisposable()
        private let emojiSearchResult = Promise<(groups: [EmojiPagerContentComponent.ItemGroup], id: AnyHashable)?>(nil)
        private var emptyResultEmojis: [TelegramMediaFile] = []
        private var stableEmptyResultEmoji: TelegramMediaFile?
        private let stableEmptyResultEmojiDisposable = MetaDisposable()
        
        private var previewItem: (groupId: AnyHashable, item: EmojiPagerContentComponent.Item)?
        private var dismissedPreviewItem: (groupId: AnyHashable, item: EmojiPagerContentComponent.Item)?
        private var previewScreenView: ComponentView<Empty>?
        
        private var availableReactions: AvailableReactions?
        private var availableReactionsDisposable: Disposable?
        
        private var genericReactionEffectDisposable: Disposable?
        private var genericReactionEffect: String?
        
        private var hapticFeedback: HapticFeedback?
        
        private var isAnimatingOut: Bool = false
        private var isDismissed: Bool = false
        
        private var isReactionSearchActive: Bool = false
        
        init(controller: EmojiStatusSelectionController, context: AccountContext, sourceView: UIView?, emojiContent: Signal<EmojiPagerContentComponent, NoError>, currentSelection: Int64?) {
            self.controller = controller
            self.context = context
            self.currentSelection = currentSelection
            
            if let sourceView = sourceView {
                self.globalSourceRect = sourceView.convert(sourceView.bounds, to: nil)
            }
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.componentHost = ComponentView<Empty>()
            self.componentShadowLayer = SimpleLayer()
            self.componentShadowLayer.shadowOpacity = 0.12
            self.componentShadowLayer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.componentShadowLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.componentShadowLayer.shadowRadius = 16.0
            
            self.cloudLayer0 = SimpleLayer()
            self.cloudShadowLayer0 = SimpleLayer()
            self.cloudShadowLayer0.shadowOpacity = 0.12
            self.cloudShadowLayer0.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.cloudShadowLayer0.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.cloudShadowLayer0.shadowRadius = 16.0
            
            self.cloudLayer1 = SimpleLayer()
            self.cloudShadowLayer1 = SimpleLayer()
            self.cloudShadowLayer1.shadowOpacity = 0.12
            self.cloudShadowLayer1.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.cloudShadowLayer1.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.cloudShadowLayer1.shadowRadius = 16.0
            
            super.init()
            
            self.layer.addSublayer(self.componentShadowLayer)
            self.layer.addSublayer(self.cloudShadowLayer0)
            self.layer.addSublayer(self.cloudShadowLayer1)
            
            self.layer.addSublayer(self.cloudLayer0)
            self.layer.addSublayer(self.cloudLayer1)
            
            let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
            self.stableEmptyResultEmojiDisposable.set((self.context.account.postbox.combinedView(keys: [viewKey])
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] views in
                guard let strongSelf = self, let view = views.views[viewKey] as? OrderedItemListView else {
                    return
                }
                var filteredFiles: [TelegramMediaFile] = []
                let filterList: [String] = ["😖", "😫", "🫠", "😨", "❓"]
                for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                    for item in featuredEmojiPack.topItems {
                        for attribute in item.file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, alt, _):
                                if filterList.contains(alt) {
                                    filteredFiles.append(item.file)
                                }
                            default:
                                break
                            }
                        }
                    }
                }
                strongSelf.emptyResultEmojis = filteredFiles
            }))
            
            self.emojiContentDisposable = (combineLatest(queue: .mainQueue(),
                emojiContent,
                self.emojiSearchResult.get()
            )
            |> deliverOnMainQueue).start(next: { [weak self] emojiContent, emojiSearchResult in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controller?._ready.set(.single(true))
                
                var emojiContent = emojiContent
                if let emojiSearchResult = emojiSearchResult {
                    var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                    if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty }) {
                        if strongSelf.stableEmptyResultEmoji == nil {
                            strongSelf.stableEmptyResultEmoji = strongSelf.emptyResultEmojis.randomElement()
                        }
                        emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                            text: strongSelf.presentationData.strings.EmojiSearch_SearchStatusesEmptyResult,
                            iconFile: strongSelf.stableEmptyResultEmoji
                        )
                    } else {
                        strongSelf.stableEmptyResultEmoji = nil
                    }
                    emojiContent = emojiContent.withUpdatedItemGroups(itemGroups: emojiSearchResult.groups, itemContentUniqueId: emojiSearchResult.id, emptySearchResults: emptySearchResults)
                } else {
                    strongSelf.stableEmptyResultEmoji = nil
                }
                
                if strongSelf.emojiContent == nil || !strongSelf.freezeUpdates {
                    strongSelf.emojiContent = emojiContent
                }
                
                emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                    performItemAction: { groupId, item, _, _, _, isPreview in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.applyItem(groupId: groupId, item: item, isPreview: isPreview)
                    },
                    deleteBackwards: {
                    },
                    openStickerSettings: {
                    },
                    openFeatured: {
                    },
                    addGroupAction: { groupId, isPremiumLocked in
                        guard let strongSelf = self, let collectionId = groupId.base as? ItemCollectionId else {
                            return
                        }
                        
                        let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                        let _ = (strongSelf.context.account.postbox.combinedView(keys: [viewKey])
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { views in
                            guard let strongSelf = self, let view = views.views[viewKey] as? OrderedItemListView else {
                                return
                            }
                            for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                                if featuredEmojiPack.info.id == collectionId {
                                    if let strongSelf = self {
                                        strongSelf.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupInstalled(id: collectionId))
                                    }
                                    let _ = strongSelf.context.engine.stickers.addStickerPackInteractively(info: featuredEmojiPack.info, items: featuredEmojiPack.topItems).start()
                                    
                                    break
                                }
                            }
                        })
                    },
                    clearGroup: { groupId in
                    },
                    pushController: { c in
                    },
                    presentController: { c in
                    },
                    presentGlobalOverlayController: { c in
                    },
                    navigationController: {
                        return nil
                    },
                    requestUpdate: { _ in
                    },
                    updateSearchQuery: { rawQuery, languageCode in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if query.isEmpty {
                            strongSelf.emojiSearchDisposable.set(nil)
                            strongSelf.emojiSearchResult.set(.single(nil))
                        } else {
                            let context = strongSelf.context
                            
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
                            
                            let resultSignal = signal
                            |> mapToSignal { keywords -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                return combineLatest(
                                    context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                                    context.engine.stickers.availableReactions(),
                                    hasPremium
                                )
                                |> take(1)
                                |> map { view, availableReactions, hasPremium -> [EmojiPagerContentComponent.ItemGroup] in
                                    var result: [(String, TelegramMediaFile?, String)] = []
                                    
                                    var allEmoticons: [String: String] = [:]
                                    for keyword in keywords {
                                        for emoticon in keyword.emoticons {
                                            allEmoticons[emoticon] = keyword.keyword
                                        }
                                    }
                                    
                                    for entry in view.entries {
                                        guard let item = entry.item as? StickerPackItem else {
                                            continue
                                        }
                                        for attribute in item.file.attributes {
                                            switch attribute {
                                            case let .CustomEmoji(_, alt, _):
                                                if !item.file.isPremiumEmoji || hasPremium {
                                                    if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                                        result.append((alt, item.file, keyword))
                                                    } else if alt == query {
                                                        result.append((alt, item.file, alt))
                                                    }
                                                }
                                            default:
                                                break
                                            }
                                        }
                                    }
                                    
                                    var items: [EmojiPagerContentComponent.Item] = []
                                    
                                    var existingIds = Set<MediaId>()
                                    for item in result {
                                        if let itemFile = item.1 {
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
                                                accentTint: false
                                            )
                                            items.append(item)
                                        }
                                    }
                                    
                                    return [EmojiPagerContentComponent.ItemGroup(
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
                                        items: items
                                    )]
                                }
                            }
                            
                            strongSelf.emojiSearchDisposable.set((resultSignal
                            |> delay(0.15, queue: .mainQueue())
                            |> deliverOnMainQueue).start(next: { result in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.emojiSearchResult.set(.single((result, AnyHashable(query))))
                            }))
                        }
                    },
                    chatPeerId: nil,
                    peekBehavior: nil,
                    customLayout: nil,
                    externalBackground: nil,
                    externalExpansionView: nil,
                    useOpaqueTheme: true
                )
                
                strongSelf.refreshLayout(transition: .immediate)
            })
            
            self.availableReactionsDisposable = (context.engine.stickers.availableReactions()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] availableReactions in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.availableReactions = availableReactions
            })
            
            self.genericReactionEffectDisposable = (randomGenericReactionEffect(context: context)
            |> deliverOnMainQueue).start(next: { [weak self] path in
                self?.genericReactionEffect = path
            })
        }
        
        deinit {
            self.emojiContentDisposable?.dispose()
            self.availableReactionsDisposable?.dispose()
            self.genericReactionEffectDisposable?.dispose()
            self.emojiSearchDisposable.dispose()
        }
        
        private func refreshLayout(transition: Transition) {
            guard let layout = self.validLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: transition)
        }
        
        func animateOut(completion: @escaping () -> Void, fromBackground: Bool) {
            if self.isAnimatingOut {
                return
            }
            self.isAnimatingOut = true
            
            let duration: Double = fromBackground ? 0.1 : 0.25
            
            self.componentShadowLayer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
            self.componentHost.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { _ in
                completion()
            })
            
            self.cloudLayer0.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
            self.cloudShadowLayer0.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
            self.cloudLayer1.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
            self.cloudShadowLayer1.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
        }
        
        func animateOutToStatus(item: EmojiPagerContentComponent.Item, sourceLayer: CALayer, customEffectFile: String?, destinationView: UIView, fromBackground: Bool) {
            self.isUserInteractionEnabled = false
            destinationView.isHidden = true
            
            let hapticFeedback: HapticFeedback
            if let current = self.hapticFeedback {
                hapticFeedback = current
            } else {
                hapticFeedback = HapticFeedback()
                self.hapticFeedback = hapticFeedback
            }
            
            hapticFeedback.prepareTap()
            
            var itemCompleted = false
            var contentCompleted = false
            var effectCompleted = false
            let completion: () -> Void = { [weak self] in
                guard let strongSelf = self, itemCompleted, contentCompleted, effectCompleted else {
                    return
                }
                strongSelf.controller?.dismissNow()
            }
            
            var effectView: AnimationView?
            
            if let customEffectFile = customEffectFile, let data = try? Data(contentsOf: URL(fileURLWithPath: customEffectFile)), let composition = try? Animation.from(data: TGGUnzipData(data, 2 * 1024 * 1024) ?? data) {
                let view = AnimationView(animation: composition, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
                view.animationSpeed = 1.0
                view.backgroundColor = nil
                view.isOpaque = false
                
                effectView = view
            } else if let itemFile = item.itemFile {
                var useCleanEffect = false
                for attribute in itemFile.attributes {
                    if case let .CustomEmoji(_, _, packReference) = attribute {
                        switch packReference {
                        case let .id(id, _):
                            if id == 773947703670341676 || id == 2964141614563343 {
                                useCleanEffect = true
                            }
                        default:
                            break
                        }
                    }
                }
                
                var effectData: Data?
                if useCleanEffect {
                    if let url = getAppBundle().url(forResource: "generic_reaction_avatar_effect", withExtension: "json") {
                        effectData = try? Data(contentsOf: url)
                    }
                } else if let genericReactionEffect = self.genericReactionEffect, let data = try? Data(contentsOf: URL(fileURLWithPath: genericReactionEffect)) {
                    effectData = TGGUnzipData(data, 5 * 1024 * 1024) ?? data
                } else {
                    if let url = getAppBundle().url(forResource: "generic_reaction_small_effect", withExtension: "json") {
                        effectData = try? Data(contentsOf: url)
                    }
                }
                
                if let effectData = effectData, let composition = try? Animation.from(data: effectData) {
                    let view = AnimationView(animation: composition, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
                    view.animationSpeed = 1.0
                    view.backgroundColor = nil
                    view.isOpaque = false
                    
                    let animationCache = self.context.animationCache
                    let animationRenderer = self.context.animationRenderer
                    
                    for i in 1 ... 7 {
                        let allLayers = view.allLayers(forKeypath: AnimationKeypath(keypath: "placeholder_\(i)"))
                        for animationLayer in allLayers {
                            let baseItemLayer = InlineStickerItemLayer(
                                context: self.context,
                                attemptSynchronousLoad: false,
                                emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: itemFile.fileId.id, file: itemFile),
                                file: item.itemFile,
                                cache: animationCache,
                                renderer: animationRenderer,
                                placeholderColor: UIColor(white: 0.0, alpha: 0.0),
                                pointSize: CGSize(width: 32.0, height: 32.0)
                            )
                            if item.accentTint {
                                baseItemLayer.contentTintColor = self.presentationData.theme.list.itemAccentColor
                            }
                            
                            if let sublayers = animationLayer.sublayers {
                                for sublayer in sublayers {
                                    sublayer.isHidden = true
                                }
                            }
                            
                            baseItemLayer.isVisibleForAnimations = true
                            baseItemLayer.frame = CGRect(origin: CGPoint(x: -0.0, y: -0.0), size: CGSize(width: 500.0, height: 500.0))
                            animationLayer.addSublayer(baseItemLayer)
                        }
                    }
                    
                    effectView = view
                }
            }
            
            if let sourceCopyLayer = sourceLayer.snapshotContentTree() {
                self.layer.addSublayer(sourceCopyLayer)
                sourceCopyLayer.frame = sourceLayer.convert(sourceLayer.bounds, to: self.layer)
                sourceLayer.isHidden = true
                
                let previousSourceCopyFrame = sourceCopyLayer.frame
                
                let localDestinationFrame = destinationView.convert(destinationView.bounds, to: self.view)
                let destinationSize = max(localDestinationFrame.width, localDestinationFrame.height)
                let effectFrame = localDestinationFrame.insetBy(dx: -destinationSize * 2.0, dy: -destinationSize * 2.0)
                let destinationNormalScale = localDestinationFrame.width / previousSourceCopyFrame.width
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
                sourceCopyLayer.position = localDestinationFrame.center
                
                var midPointY: CGFloat = localDestinationFrame.center.y - 30.0
                if let layout = self.validLayout {
                    if midPointY < layout.safeInsets.top + 8.0 {
                        midPointY = max(localDestinationFrame.center.y, layout.safeInsets.top + 20.0)
                    }
                }
                
                transition.animatePositionWithKeyframes(layer: sourceCopyLayer, keyframes: generateParabollicMotionKeyframes(from: previousSourceCopyFrame.center, to: localDestinationFrame.center, midPointY: midPointY), completion: { [weak self, weak sourceCopyLayer, weak destinationView] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    itemCompleted = true
                    sourceCopyLayer?.isHidden = true
                    if let destinationView = destinationView {
                        destinationView.isHidden = false
                        destinationView.layer.animateScale(from: 0.3, to: 1.0, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                    
                    hapticFeedback.tap()
                    
                    if let effectView = effectView {
                        effectView.frame = effectFrame
                        strongSelf.view.addSubview(effectView)
                        effectView.play(completion: { _ in
                            effectCompleted = true
                            completion()
                        })
                    } else {
                        effectCompleted = true
                    }
                    
                    completion()
                })
                let scaleKeyframes: [CGFloat] = [
                    1.0,
                    1.4,
                    1.0,
                    destinationNormalScale * 0.3
                ]
                sourceCopyLayer.transform = CATransform3DMakeScale(scaleKeyframes[scaleKeyframes.count - 1], scaleKeyframes[scaleKeyframes.count - 1], 1.0)
                sourceCopyLayer.animateKeyframes(values: scaleKeyframes.map({ $0 as NSNumber }), duration: 0.2, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.linear.rawValue)
            } else {
                itemCompleted = true
                destinationView.isHidden = false
            }
            
            if let previewScreenView = self.previewScreenView {
                self.previewItem = nil
                self.dismissedPreviewItem = nil
                self.previewScreenView = nil
                
                if let previewScreenComponentView = previewScreenView.view as? EmojiStatusPreviewScreenComponent.View {
                    previewScreenComponentView.animateOut(targetLayer: nil, completion: { [weak previewScreenComponentView] in
                        previewScreenComponentView?.removeFromSuperview()
                    })
                } else {
                    previewScreenView.view?.removeFromSuperview()
                }
            }
            
            self.animateOut(completion: {
                contentCompleted = true
                completion()
            }, fromBackground: fromBackground)
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, transition: Transition) {
            self.validLayout = layout
            
            var transition = transition
            
            guard let emojiContent = self.emojiContent else {
                return
            }
            
            let listBackgroundColor: UIColor
            let separatorColor: UIColor
            if self.presentationData.theme.overallDarkAppearance {
                listBackgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
                separatorColor = self.presentationData.theme.list.itemBlocksSeparatorColor
                self.componentShadowLayer.shadowOpacity = 0.32
                self.cloudShadowLayer0.shadowOpacity = 0.32
                self.cloudShadowLayer1.shadowOpacity = 0.32
            } else {
                listBackgroundColor = self.presentationData.theme.list.plainBackgroundColor
                separatorColor = self.presentationData.theme.list.itemPlainSeparatorColor.withMultipliedAlpha(0.5)
                self.componentShadowLayer.shadowOpacity = 0.12
                self.cloudShadowLayer0.shadowOpacity = 0.12
                self.cloudShadowLayer1.shadowOpacity = 0.12
            }
            
            self.cloudLayer0.backgroundColor = listBackgroundColor.cgColor
            self.cloudLayer1.backgroundColor = listBackgroundColor.cgColor
            
            let sideInset: CGFloat = 16.0
            
            if let scheduledEmojiContentAnimationHint = self.scheduledEmojiContentAnimationHint {
                self.scheduledEmojiContentAnimationHint = nil
                let contentAnimation = scheduledEmojiContentAnimationHint
                transition = Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(contentAnimation)
            }
            
            var componentWidth = layout.size.width - sideInset * 2.0
            let nativeItemSize: CGFloat = 40.0
            let minSpacing: CGFloat = 9.0
            let itemsPerRow = Int((componentWidth + minSpacing) / (nativeItemSize + minSpacing))
            if itemsPerRow > 8 {
                componentWidth = min(componentWidth, 480.0)
            }
            
            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(EmojiStatusSelectionComponent(
                    theme: self.presentationData.theme,
                    strings: self.presentationData.strings,
                    deviceMetrics: layout.deviceMetrics,
                    emojiContent: emojiContent,
                    backgroundColor: listBackgroundColor,
                    separatorColor: separatorColor,
                    hideTopPanel: self.isReactionSearchActive,
                    hideTopPanelUpdated: { [weak self] hideTopPanel, transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.isReactionSearchActive = hideTopPanel
                        strongSelf.refreshLayout(transition: transition)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: componentWidth, height: min(308.0, layout.size.height))
            )
            if let componentView = self.componentHost.view {
                var animateIn = false
                if componentView.superview == nil {
                    self.view.addSubview(componentView)
                    animateIn = true
                    
                    componentView.clipsToBounds = true
                    componentView.layer.cornerRadius = 24.0
                }
                
                var sourceOrigin: CGPoint
                if let sourceView = self.sourceView {
                    let sourceRect = sourceView.convert(sourceView.bounds, to: self.view)
                    sourceOrigin = CGPoint(x: sourceRect.midX, y: sourceRect.maxY)
                } else if let globalSourceRect = self.globalSourceRect {
                    let sourceRect = self.view.convert(globalSourceRect, from: nil)
                    sourceOrigin = CGPoint(x: sourceRect.midX, y: sourceRect.maxY)
                } else {
                    sourceOrigin = CGPoint(x: layout.size.width / 2.0, y: floor(layout.size.height / 2.0 - componentSize.height))
                }
                
                if sourceOrigin.y + 5.0 + componentSize.height > layout.size.height - layout.insets(options: []).bottom {
                    sourceOrigin.y = layout.size.height - layout.insets(options: []).bottom - componentSize.height - 5.0
                }
                
                let componentFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - componentSize.width) / 2.0), y: sourceOrigin.y + 5.0), size: componentSize)
                
                if self.componentShadowLayer.bounds.size != componentFrame.size {
                    let componentShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: componentFrame.size), cornerRadius: 24.0).cgPath
                    self.componentShadowLayer.shadowPath = componentShadowPath
                }
                transition.setFrame(layer: self.componentShadowLayer, frame: componentFrame)
                
                let cloudOffset0: CGFloat = 30.0
                let cloudSize0: CGFloat = 16.0
                var cloudFrame0 = CGRect(origin: CGPoint(x: floor(sourceOrigin.x + cloudOffset0 - cloudSize0 / 2.0), y: componentFrame.minY - cloudSize0 / 2.0), size: CGSize(width: cloudSize0, height: cloudSize0))
                var invertX = false
                if cloudFrame0.maxX >= layout.size.width - layout.safeInsets.right - 32.0 {
                    cloudFrame0.origin.x = floor(sourceOrigin.x - cloudSize0 - cloudOffset0 + cloudSize0 / 2.0)
                    invertX = true
                }
                
                transition.setFrame(layer: self.cloudLayer0, frame: cloudFrame0)
                if self.cloudShadowLayer0.bounds.size != cloudFrame0.size {
                    let cloudShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: cloudFrame0.size), cornerRadius: 24.0).cgPath
                    self.cloudShadowLayer0.shadowPath = cloudShadowPath
                }
                transition.setFrame(layer: self.cloudShadowLayer0, frame: cloudFrame0)
                transition.setCornerRadius(layer: self.cloudLayer0, cornerRadius: cloudFrame0.width / 2.0)
                
                let cloudOffset1 = CGPoint(x: -9.0, y: -14.0)
                let cloudSize1: CGFloat = 8.0
                var cloudFrame1 = CGRect(origin: CGPoint(x: floor(cloudFrame0.midX + cloudOffset1.x - cloudSize1 / 2.0), y: floor(cloudFrame0.midY + cloudOffset1.y - cloudSize1 / 2.0)), size: CGSize(width: cloudSize1, height: cloudSize1))
                if invertX {
                    cloudFrame1.origin.x = floor(cloudFrame0.midX - cloudSize1 - cloudOffset1.x + cloudSize1 / 2.0)
                }
                transition.setFrame(layer: self.cloudLayer1, frame: cloudFrame1)
                if self.cloudShadowLayer1.bounds.size != cloudFrame1.size {
                    let cloudShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: cloudFrame1.size), cornerRadius: 24.0).cgPath
                    self.cloudShadowLayer1.shadowPath = cloudShadowPath
                }
                transition.setFrame(layer: self.cloudShadowLayer1, frame: cloudFrame1)
                transition.setCornerRadius(layer: self.cloudLayer1, cornerRadius: cloudFrame1.width / 2.0)
                
                transition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))
                
                if animateIn {
                    self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { [weak self] _ in
                        self?.allowsGroupOpacity = false
                    })
                    
                    let contentDuration: Double = 0.3
                    let contentDelay: Double = 0.14
                    let initialContentFrame = CGRect(origin: CGPoint(x: cloudFrame0.midX - 24.0, y: componentFrame.minY), size: CGSize(width: 24.0 * 2.0, height: 24.0 * 2.0))
                    
                    if let emojiView = self.componentHost.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View {
                        emojiView.animateIn(fromLocation: self.view.convert(initialContentFrame.center, to: emojiView))
                    }
                    
                    componentView.layer.animatePosition(from: initialContentFrame.center, to: componentFrame.center, duration: contentDuration, delay: contentDelay, timingFunction: kCAMediaTimingFunctionSpring)
                    componentView.layer.animateBounds(from: CGRect(origin: CGPoint(x: -(componentFrame.minX - initialContentFrame.minX), y: -(componentFrame.minY - initialContentFrame.minY)), size: initialContentFrame.size), to: CGRect(origin: CGPoint(), size: componentFrame.size), duration: contentDuration, delay: contentDelay, timingFunction: kCAMediaTimingFunctionSpring)
                    self.componentShadowLayer.animateFrame(from: CGRect(origin: CGPoint(x: cloudFrame0.midX - 24.0, y: componentFrame.minY), size: CGSize(width: 24.0 * 2.0, height: 24.0 * 2.0)), to: componentView.frame, duration: contentDuration, delay: contentDelay, timingFunction: kCAMediaTimingFunctionSpring)
                    componentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.04, delay: contentDelay)
                    self.componentShadowLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.04, delay: contentDelay)
                    
                    let initialComponentShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: initialContentFrame.size), cornerRadius: 24.0).cgPath
                    self.componentShadowLayer.animate(from: initialComponentShadowPath, to: self.componentShadowLayer.shadowPath!, keyPath: "shadowPath", timingFunction: kCAMediaTimingFunctionSpring, duration: contentDuration, delay: contentDelay)
                    
                    self.cloudLayer0.animateScale(from: 0.01, to: 1.0, duration: 0.4, delay: 0.05, timingFunction: kCAMediaTimingFunctionSpring)
                    self.cloudShadowLayer0.animateScale(from: 0.01, to: 1.0, duration: 0.4, delay: 0.05, timingFunction: kCAMediaTimingFunctionSpring)
                    
                    self.cloudLayer1.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.cloudShadowLayer1.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
            
            if let previewItem = self.previewItem, let itemFile = previewItem.item.itemFile {
                let previewScreenView: ComponentView<Empty>
                var previewScreenTransition = transition
                if let current = self.previewScreenView {
                    previewScreenView = current
                } else {
                    previewScreenTransition = Transition(animation: .none)
                    if let emojiView = self.componentHost.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View, let sourceLayer = emojiView.layerForItem(groupId: previewItem.groupId, item: previewItem.item) {
                        previewScreenTransition = previewScreenTransition.withUserData(EmojiStatusPreviewScreenComponent.TransitionAnimation(
                            transitionType: .animateIn(sourceLayer: sourceLayer)
                        ))
                    }
                    previewScreenView = ComponentView<Empty>()
                    self.previewScreenView = previewScreenView
                }
                let _ = previewScreenView.update(
                    transition: previewScreenTransition,
                    component: AnyComponent(EmojiStatusPreviewScreenComponent(
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        bottomInset: layout.insets(options: []).bottom,
                        item: EmojiStatusComponent(
                            context: self.context,
                            animationCache: self.context.animationCache,
                            animationRenderer: self.context.animationRenderer,
                            content: .animation(
                                content: .file(file: itemFile),
                                size: CGSize(width: 128.0, height: 128.0),
                                placeholderColor: self.presentationData.theme.list.plainBackgroundColor.withMultipliedAlpha(0.1),
                                themeColor: self.presentationData.theme.list.itemAccentColor,
                                loopMode: .forever
                            ),
                            isVisibleForAnimations: true,
                            useSharedAnimation: false,
                            action: nil
                        ),
                        dismiss: { [weak self] result in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let result = result, let previewItem = strongSelf.previewItem {
                                var emojiString: String?
                                if let itemFile = previewItem.item.itemFile {
                                    attributeLoop: for attribute in itemFile.attributes {
                                        switch attribute {
                                        case let .CustomEmoji(_, alt, _):
                                            emojiString = alt
                                            break attributeLoop
                                        default:
                                            break
                                        }
                                    }
                                }
                                
                                let context = strongSelf.context
                                let _ = (context.engine.stickers.availableReactions()
                                |> take(1)
                                |> mapToSignal { availableReactions -> Signal<String?, NoError> in
                                    guard let emojiString = emojiString, let availableReactions = availableReactions else {
                                        return .single(nil)
                                    }
                                    for reaction in availableReactions.reactions {
                                        if case let .builtin(value) = reaction.value, value == emojiString {
                                            if let aroundAnimation = reaction.aroundAnimation {
                                                return context.account.postbox.mediaBox.resourceData(aroundAnimation.resource)
                                                |> take(1)
                                                |> map { data -> String? in
                                                    if data.complete {
                                                        return data.path
                                                    } else {
                                                        return nil
                                                    }
                                                }
                                            } else {
                                                return .single(nil)
                                            }
                                        }
                                    }
                                    return .single(nil)
                                }
                                |> deliverOnMainQueue).start(next: { filePath in
                                    guard let strongSelf = self, let previewItem = strongSelf.previewItem, let destinationView = strongSelf.controller?.destinationItemView() else {
                                        return
                                    }
                                    
                                    let expirationDate: Int32? = result.timestamp
                            
                                    let _ = (strongSelf.context.engine.accountData.setEmojiStatus(file: previewItem.item.itemFile, expirationDate: expirationDate)
                                    |> deliverOnMainQueue).start()
                                    
                                    strongSelf.animateOutToStatus(item: previewItem.item, sourceLayer: result.sourceView.layer, customEffectFile: filePath, destinationView: destinationView, fromBackground: true)
                                })
                            } else {
                                strongSelf.dismissedPreviewItem = strongSelf.previewItem
                                strongSelf.previewItem = nil
                                strongSelf.refreshLayout(transition: .immediate)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: layout.size
                )
                if let view = previewScreenView.view {
                    if view.superview == nil {
                        self.view.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: layout.size))
                }
            } else if let previewScreenView = self.previewScreenView {
                self.previewScreenView = nil
                
                if let previewScreenComponentView = previewScreenView.view as? EmojiStatusPreviewScreenComponent.View {
                    var targetLayer: CALayer?
                    if let previewItem = self.dismissedPreviewItem, let emojiView = self.componentHost.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View, let sourceLayer = emojiView.layerForItem(groupId: previewItem.groupId, item: previewItem.item) {
                        targetLayer = sourceLayer
                    }
                    
                    previewScreenComponentView.animateOut(targetLayer: targetLayer, completion: { [weak previewScreenComponentView] in
                        previewScreenComponentView?.removeFromSuperview()
                    })
                } else {
                    previewScreenView.view?.removeFromSuperview()
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let result = super.hitTest(point, with: event) {
                if self.isDismissed {
                    return self.view
                }
                
                if result === self.view {
                    self.isDismissed = true
                    self.controller?.dismiss()
                }
                
                return result
            }
            return nil
        }
        
        private func applyItem(groupId: AnyHashable, item: EmojiPagerContentComponent.Item?, isPreview: Bool) {
            guard let controller = self.controller else {
                return
            }
            
            if isPreview {
                guard let item = item else {
                    return
                }
                self.previewItem = (groupId, item)
                self.view.endEditing(true)
                self.refreshLayout(transition: .immediate)
            } else {
                self.freezeUpdates = true
                
                if case .statusSelection = controller.mode, let item = item, let currentSelection = self.currentSelection, item.itemFile?.fileId.id == currentSelection {
                    let _ = (self.context.engine.accountData.setEmojiStatus(file: nil, expirationDate: nil)
                    |> deliverOnMainQueue).start()
                    controller.dismiss()
                    return
                }
                
                if let _ = item, let destinationView = controller.destinationItemView() {
                    if let snapshotView = destinationView.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = destinationView.frame
                        destinationView.superview?.insertSubview(snapshotView, belowSubview: destinationView)
                        snapshotView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                    destinationView.isHidden = true
                }
                
                switch controller.mode {
                case .statusSelection:
                    let _ = (self.context.engine.accountData.setEmojiStatus(file: item?.itemFile, expirationDate: nil)
                    |> deliverOnMainQueue).start()
                case let .quickReactionSelection(completion):
                    if let item = item, let itemFile = item.itemFile {
                        var selectedReaction: MessageReaction.Reaction?
                        
                        if let availableReactions = self.availableReactions {
                            for reaction in availableReactions.reactions {
                                if reaction.selectAnimation.fileId == itemFile.fileId {
                                    selectedReaction = reaction.value
                                    break
                                }
                            }
                        }
                        
                        if selectedReaction == nil {
                            selectedReaction = .custom(itemFile.fileId.id)
                        }
                        
                        if let selectedReaction = selectedReaction {
                            let _ = context.engine.stickers.updateQuickReaction(reaction: selectedReaction).start()
                        }
                    }
                    
                    completion()
                }
                
                if let item = item, let destinationView = controller.destinationItemView() {
                    var emojiString: String?
                    if let itemFile = item.itemFile {
                        attributeLoop: for attribute in itemFile.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, alt, _):
                                emojiString = alt
                                break attributeLoop
                            default:
                                break
                            }
                        }
                    }
                    
                    let context = self.context
                    let _ = (context.engine.stickers.availableReactions()
                    |> take(1)
                    |> mapToSignal { availableReactions -> Signal<String?, NoError> in
                        guard let emojiString = emojiString, let availableReactions = availableReactions else {
                            return .single(nil)
                        }
                        for reaction in availableReactions.reactions {
                            if case let .builtin(value) = reaction.value, value == emojiString {
                                if let aroundAnimation = reaction.aroundAnimation {
                                    return context.account.postbox.mediaBox.resourceData(aroundAnimation.resource)
                                    |> take(1)
                                    |> map { data -> String? in
                                        if data.complete {
                                            return data.path
                                        } else {
                                            return nil
                                        }
                                    }
                                } else {
                                    return .single(nil)
                                }
                            }
                        }
                        return .single(nil)
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] filePath in
                        guard let strongSelf = self else {
                            return
                        }
                        guard let emojiView = strongSelf.componentHost.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View, let sourceLayer = emojiView.layerForItem( groupId: groupId, item: item) else {
                            strongSelf.controller?.dismiss()
                            return
                        }
                        
                        strongSelf.animateOutToStatus(item: item, sourceLayer: sourceLayer, customEffectFile: filePath, destinationView: destinationView, fromBackground: false)
                    })
                } else {
                    controller.dismiss()
                }
            }
        }
    }
    
    public enum Mode {
        case statusSelection
        case quickReactionSelection(completion: () -> Void)
    }
    
    private let context: AccountContext
    private weak var sourceView: UIView?
    private let emojiContent: Signal<EmojiPagerContentComponent, NoError>
    private let currentSelection: Int64?
    private let mode: Mode
    private let destinationItemView: () -> UIView?
    
    fileprivate let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    override public var overlayWantsToBeBelowKeyboard: Bool {
        return true
    }
    
    public init(context: AccountContext, mode: Mode, sourceView: UIView, emojiContent: Signal<EmojiPagerContentComponent, NoError>, currentSelection: Int64?, destinationItemView: @escaping () -> UIView?) {
        self.context = context
        self.mode = mode
        self.sourceView = sourceView
        self.emojiContent = emojiContent
        self.currentSelection = currentSelection
        self.destinationItemView = destinationItemView
        
        super.init(navigationBarPresentationData: nil)
        
        self.lockOrientation = true
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func dismissNow() {
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        (self.displayNode as! Node).animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        }, fromBackground: false)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, sourceView: self.sourceView, emojiContent: self.emojiContent, currentSelection: self.currentSelection)

        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}

private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, midPointY: CGFloat) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: midPointY)
    
    let x1 = sourcePoint.x
    let y1 = sourcePoint.y
    let x2 = midPoint.x
    let y2 = midPoint.y
    let x3 = targetPosition.x
    let y3 = targetPosition.y
    
    var keyframes: [CGPoint] = []
    if abs(y1 - y3) < 5.0 && abs(x1 - x3) < 5.0 {
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
            keyframes.append(CGPoint(x: x, y: y))
        }
    } else {
        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = a * x * x + b * x + c
            keyframes.append(CGPoint(x: x, y: y))
        }
    }
    
    return keyframes
}
