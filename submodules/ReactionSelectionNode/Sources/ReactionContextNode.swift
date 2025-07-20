import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramCore
import Postbox
import TelegramPresentationData
import AccountContext
import TelegramAnimatedStickerNode
import ReactionButtonListComponent
import SwiftSignalKit
import Lottie
import AppBundle
import AvatarNode
import ComponentFlow
import PagerComponent
import EmojiStatusSelectionComponent
import EntityKeyboard
import ComponentDisplayAdapters
import AnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import TextFormat
import GZip
import BalancedTextComponent
import Markdown
import PremiumStarComponent

public final class ReactionItem {
    public struct Reaction: Equatable {
        public var rawValue: MessageReaction.Reaction
        
        public init(rawValue: MessageReaction.Reaction) {
            self.rawValue = rawValue
        }
    }
    
    public let reaction: ReactionItem.Reaction
    public let appearAnimation: TelegramMediaFile.Accessor
    public let stillAnimation: TelegramMediaFile.Accessor
    public let listAnimation: TelegramMediaFile.Accessor
    public let largeListAnimation: TelegramMediaFile.Accessor
    public let applicationAnimation: TelegramMediaFile.Accessor?
    public let largeApplicationAnimation: TelegramMediaFile.Accessor?
    public let isCustom: Bool
    
    public init(
        reaction: ReactionItem.Reaction,
        appearAnimation: TelegramMediaFile.Accessor,
        stillAnimation: TelegramMediaFile.Accessor,
        listAnimation: TelegramMediaFile.Accessor,
        largeListAnimation: TelegramMediaFile.Accessor,
        applicationAnimation: TelegramMediaFile.Accessor?,
        largeApplicationAnimation: TelegramMediaFile.Accessor?,
        isCustom: Bool
    ) {
        self.reaction = reaction
        self.appearAnimation = appearAnimation
        self.stillAnimation = stillAnimation
        self.listAnimation = listAnimation
        self.largeListAnimation = largeListAnimation
        self.applicationAnimation = applicationAnimation
        self.largeApplicationAnimation = largeApplicationAnimation
        self.isCustom = isCustom
    }
    
    var updateMessageReaction: UpdateMessageReaction {
        switch self.reaction.rawValue {
        case let .builtin(value):
            return .builtin(value)
        case let .custom(fileId):
            return .custom(fileId: fileId, file: self.listAnimation._parse())
        case .stars:
            return .stars
        }
    }
}

public enum ReactionContextItem: Equatable {
    public static func == (lhs: ReactionContextItem, rhs: ReactionContextItem) -> Bool {
        switch lhs {
        case let .staticEmoji(emoji):
            if case .staticEmoji(emoji) = rhs {
                return true
            } else {
                return false
            }
        case let .reaction(lhsReaction, lhsIcon):
            if case let .reaction(rhsReaction, rhsIcon) = rhs {
                return lhsReaction.reaction == rhsReaction.reaction && lhsIcon == rhsIcon
            } else {
                return false
            }
        case .premium:
            if case .premium = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    case staticEmoji(String)
    case reaction(item: ReactionItem, icon: EmojiPagerContentComponent.Item.Icon)
    case premium
    
    public var reaction: ReactionItem.Reaction? {
        if case let .reaction(item, _) = self {
            return item.reaction
        } else {
            return nil
        }
    }
    
    public var emoji: String? {
        if case let .staticEmoji(emoji) = self {
            return emoji
        } else {
            return nil
        }
    }
}

private let largeCircleSize: CGFloat = 16.0
private let smallCircleSize: CGFloat = 8.0

private final class ExpandItemView: UIView {
    private let arrowView: UIImageView
    let tintView: UIView
    
    override init(frame: CGRect) {
        self.tintView = UIView()
        self.tintView.backgroundColor = .black
        
        self.arrowView = UIImageView()
        self.arrowView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReactionExpandArrow"), color: .white)
        
        super.init(frame: frame)
        
        self.addSubview(self.arrowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = theme.chat.inputMediaPanel.panelContentControlVibrantOverlayColor.mixedWith(theme.contextMenu.backgroundColor.withMultipliedAlpha(0.4), alpha: 0.5)
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateCornerRadius(layer: self.layer, cornerRadius: size.width / 2.0)
        transition.updateCornerRadius(layer: self.tintView.layer, cornerRadius: size.width / 2.0)
        
        if let image = self.arrowView.image {
            transition.updateFrame(view: self.arrowView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) / 2.0), y: floorToScreenPixels(size.height - size.width + (size.width - image.size.height) / 2.0 + 1.0)), size: image.size))
        }
    }
}

private final class TitleLabelView: UIView {
    let contentView = ComponentView<Empty>()
    let tintContentView = ComponentView<Empty>()
    
    var action: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(width: CGFloat, text: String, theme: PresentationTheme, transition: ContainedViewLayoutTransition) -> CGFloat {
        let foregroundColor: UIColor
        if theme.overallDarkAppearance {
            foregroundColor = UIColor(white: 1.0, alpha: 0.5)
        } else {
            foregroundColor = UIColor(white: 0.5, alpha: 0.9)
        }
        
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: foregroundColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: foregroundColor)
        let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor, additionalAttributes: ["URL": true as NSNumber])
        let attributes = MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { _ in
            return nil
        })
        
        let tintBody = MarkdownAttributeSet(font: Font.regular(13.0), textColor: .black)
        let tintBold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: .black)
        let tintLink = MarkdownAttributeSet(font: Font.regular(13.0), textColor: .black, additionalAttributes: [TelegramTextAttributes.URL: true as NSNumber])
        let tintAttributes = MarkdownAttributes(body: tintBody, bold: tintBold, link: tintLink, linkAttribute: { _ in
            return (TelegramTextAttributes.URL, "")
        })
        
        let contentSize = self.contentView.update(
            transition: .immediate,
            component: AnyComponent(BalancedTextComponent(
                text: .markdown(text: text, attributes: attributes),
                balanced: true,
                horizontalAlignment: .center,
                maximumNumberOfLines: 0,
                highlightColor: theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                highlightAction: { attributes in
                    if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                        return NSAttributedString.Key(rawValue: "URL")
                    } else {
                        return nil
                    }
                }, tapAction: { [weak self] attributes, _ in
                    guard let self else {
                        return
                    }
                    if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                        self.action?()
                    }
                }
            )),
            environment: {},
            containerSize: CGSize(width: width - 8.0 * 2.0, height: 10000.0)
        )
        let _ = self.tintContentView.update(
            transition: .immediate,
            component: AnyComponent(BalancedTextComponent(
                text: .markdown(text: text, attributes: tintAttributes),
                balanced: true,
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: width - 8.0 * 2.0, height: 10000.0)
        )
        
        if let contentView = self.contentView.view {
            if contentView.superview == nil {
                contentView.layer.rasterizationScale = UIScreenScale
                self.addSubview(contentView)
            }
            transition.updateFrame(view: contentView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - contentSize.width) / 2.0), y: 6.0), size: contentSize))
        }
        
        return 6.0 + contentSize.height
    }
}

public final class ReactionContextNode: ASDisplayNode, ASScrollViewDelegate {
    private struct ItemLayout {
        var itemSize: CGFloat
        var visibleItemCount: Int
        
        init(
            itemSize: CGFloat,
            visibleItemCount: Int
        ) {
            self.itemSize = itemSize
            self.visibleItemCount = visibleItemCount
        }
    }
    
    private final class ContentScrollView: UIScrollView {
        override static var layerClass: AnyClass {
            return EmojiPagerContentComponent.View.ContentScrollLayer.self
        }
        
        init(mirrorView: UIView) {
            super.init(frame: CGRect())
            
            (self.layer as? EmojiPagerContentComponent.View.ContentScrollLayer)?.mirrorLayer = mirrorView.layer
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
    }
    
    private final class ContentScrollNode: ASDisplayNode {
        override var view: ContentScrollView {
            return super.view as! ContentScrollView
        }
        
        init(mirrorView: UIView) {
            super.init()
            
            self.setViewBlock({
                return ContentScrollView(mirrorView: mirrorView)
            })
        }
    }
    
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
    
    private let context: AccountContext
    private let presentationData: PresentationData
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    public var items: [ReactionContextItem] {
        didSet {
            var updated = false
            if oldValue != self.items {
                for (_, itemNode) in self.visibleItemNodes {
                    itemNode.selectionView?.removeFromSuperview()
                    itemNode.selectionTintView?.removeFromSuperview()
                    itemNode.removeFromSupernode()
                }
                self.visibleItemNodes.removeAll()
                updated = true
            }
            self.skipApperanceAnimation = true
            self.updateScrolling(transition: updated ? .immediate : .animated(duration: 0.25, curve: .easeInOut))
            self.skipApperanceAnimation = false
        }
    }
    private var skipApperanceAnimation = false
    
    public var selectedItems: Set<AnyHashable>
    private let getEmojiContent: ((AnimationCache, MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError>)?
    private let isExpandedUpdated: (ContainedViewLayoutTransition) -> Void
    private let requestLayout: (ContainedViewLayoutTransition) -> Void
    private let requestUpdateOverlayWantsToBeBelowKeyboard: (ContainedViewLayoutTransition) -> Void
    
    private let backgroundNode: ReactionContextBackgroundNode
    
    private let contentTintContainer: ASDisplayNode
    private let contentContainer: ASDisplayNode
    private let contentContainerMask: UIImageView
    private let leftBackgroundMaskNode: ASDisplayNode
    private let rightBackgroundMaskNode: ASDisplayNode
    private let backgroundMaskNode: ASDisplayNode
    private let mirrorContentScrollView: UIView
    private let scrollNode: ContentScrollNode
    private let previewingItemContainer: ASDisplayNode
    private var visibleItemNodes: [Int: ReactionItemNode] = [:]
    private var disappearingVisibleItemNodes: [Int: ReactionItemNode] = [:]
    private var visibleItemMaskNodes: [Int: ASDisplayNode] = [:]
    private let expandItemView: ExpandItemView?
    
    private let title: String?
    private let reactionsLocked: Bool
    private var titleLabelView: TitleLabelView?
    private var titleLabelHeight: CGFloat?
    
    private var reactionSelectionComponentHost: ComponentView<Empty>?
    
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var highlightedReaction: ReactionItem.Reaction?
    private var highlightedByHover = false
    private var didTriggerExpandedReaction: Bool = false
    private var continuousHaptic: Any?
    private var validLayout: (CGSize, UIEdgeInsets, CGRect, Bool, Bool)?
    private var isLeftAligned: Bool = true
    private var itemLayout: ItemLayout?
    
    public var centerAligned: Bool {
        return self.validLayout?.4 ?? false
    }
    
    private var customReactionSource: (view: UIView, rect: CGRect, layer: CALayer, item: ReactionItem)?
    
    public var emojiSelected: ((String) -> Void)?
    public var reactionSelected: ((UpdateMessageReaction, Bool) -> Void)?
    public var premiumReactionsSelected: ((TelegramMediaFile?) -> Void)?
    
    private var hapticFeedback: HapticFeedback?
    private var standaloneReactionAnimation: StandaloneReactionAnimation?
    
    private weak var animationTargetView: UIView?
    private var animationHideNode: Bool = false
    
    public var displayTail: Bool = true
    public var forceTailToRight: Bool = false
    public var forceDark: Bool = false
    public var hideBackground: Bool = false
    
    public var isMessageEffects: Bool = false
    
    private var didAnimateIn: Bool = false
    public private(set) var isAnimatingOut: Bool = false
    public private(set) var isAnimatingOutToReaction: Bool = false
    
    private var contentTopInset: CGFloat = 0.0
    public var contentHeight: CGFloat {
        return self.contentTopInset + self.currentContentHeight
    }
    
    private var currentContentHeight: CGFloat = 46.0
    public private(set) var isExpanded: Bool = false
    public private(set) var canBeExpanded: Bool = false
    private var isCollapsing: Bool = false
    
    private var animateFromExtensionDistance: CGFloat = 0.0
    private var extensionDistance: CGFloat = 0.0
    public private(set) var visibleExtensionDistance: CGFloat = 0.0
    
    private var emojiContentHeight: CGFloat = 300.0
    private var didInitializeEmojiContentHeight: Bool = false
    private var emojiContentLayout: EmojiPagerContentComponent.CustomLayout?
    private var emojiContent: EmojiPagerContentComponent?
    private var scheduledEmojiContentAnimationHint: EmojiPagerContentComponent.ContentAnimation?
    private var emojiContentDisposable: Disposable?
    
    private let emojiSearchDisposable = MetaDisposable()
    private let emojiSearchState = Promise<EmojiSearchState>(EmojiSearchState(result: nil, isSearching: false))
    private var emojiSearchStateValue = EmojiSearchState(result: nil, isSearching: false) {
        didSet {
            self.emojiSearchState.set(.single(self.emojiSearchStateValue))
        }
    }
    
    private var emptyResultEmojis: [TelegramMediaFile] = []
    private var stableEmptyResultEmoji: TelegramMediaFile?
    private let stableEmptyResultEmojiDisposable = MetaDisposable()
    
    private var horizontalExpandRecognizer: UIPanGestureRecognizer?
    private var horizontalExpandStartLocation: CGPoint?
    private var horizontalExpandDistance: CGFloat = 0.0
    
    private var animateInInfo: (centerX: CGFloat, width: CGFloat)?
    
    private var availableReactions: AvailableReactions?
    private var availableReactionsDisposable: Disposable?
    
    public let alwaysAllowPremiumReactions: Bool
    private var hideExpandedTopPanel: Bool = false
    private var hasPremium: Bool?
    private var hasPremiumDisposable: Disposable?
    
    private var allPresetReactionsAreAvailable: Bool
    
    private var genericReactionEffectDisposable: Disposable?
    private var genericReactionEffect: String?
    
    public var isReactionSearchActive: Bool = false
    
    public var reduceMotion: Bool = false
    
    public var isEmojiOnly: Bool = false
    
    public static func randomGenericReactionEffect(context: AccountContext) -> Signal<String?, NoError> {
        return context.engine.stickers.loadedStickerPack(reference: .emojiGenericAnimations, forceActualized: false)
        |> map { result -> TelegramMediaFile? in
            switch result {
            case let .result(_, items, _):
                return items.randomElement()?.file._parse()
            default:
                return nil
            }
        }
        |> filter { $0 != nil }
        |> take(1)
        |> mapToSignal { file -> Signal<String?, NoError> in
            guard let file else {
                return .single(nil)
            }
            return Signal { subscriber in
                let fetchDisposable = freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file)).start()
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
    
    public init(context: AccountContext, animationCache: AnimationCache, presentationData: PresentationData, items: [ReactionContextItem], selectedItems: Set<AnyHashable>, title: String? = nil, reactionsLocked: Bool, alwaysAllowPremiumReactions: Bool, allPresetReactionsAreAvailable: Bool, getEmojiContent: ((AnimationCache, MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError>)?, isExpandedUpdated: @escaping (ContainedViewLayoutTransition) -> Void, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void, requestUpdateOverlayWantsToBeBelowKeyboard: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.items = items
        self.selectedItems = selectedItems
        self.getEmojiContent = getEmojiContent
        self.isExpandedUpdated = isExpandedUpdated
        self.requestLayout = requestLayout
        self.requestUpdateOverlayWantsToBeBelowKeyboard = requestUpdateOverlayWantsToBeBelowKeyboard
        self.reactionsLocked = reactionsLocked
        
        self.animationCache = animationCache
        self.animationRenderer = MultiAnimationRendererImpl()
        (self.animationRenderer as? MultiAnimationRendererImpl)?.useYuvA = context.sharedContext.immediateExperimentalUISettings.compressedEmojiCache
        
        self.backgroundMaskNode = ASDisplayNode()
        self.backgroundNode = ReactionContextBackgroundNode(largeCircleSize: largeCircleSize, smallCircleSize: smallCircleSize, maskNode: self.backgroundMaskNode)
        self.leftBackgroundMaskNode = ASDisplayNode()
        self.leftBackgroundMaskNode.backgroundColor = .black
        self.rightBackgroundMaskNode = ASDisplayNode()
        self.rightBackgroundMaskNode.backgroundColor = .black
        self.backgroundMaskNode.addSubnode(self.leftBackgroundMaskNode)
        self.backgroundMaskNode.addSubnode(self.rightBackgroundMaskNode)
        
        self.mirrorContentScrollView = UIView()
        self.mirrorContentScrollView.isUserInteractionEnabled = false
        
        self.scrollNode = ContentScrollNode(mirrorView: self.mirrorContentScrollView)
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.clipsToBounds = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.previewingItemContainer = ASDisplayNode()
        self.previewingItemContainer.isUserInteractionEnabled = false
        
        self.contentContainer = ASDisplayNode()
        self.contentContainer.clipsToBounds = true
        self.contentContainer.addSubnode(self.scrollNode)
        
        self.contentTintContainer = ASDisplayNode()
        self.contentTintContainer.clipsToBounds = true
        self.contentTintContainer.isUserInteractionEnabled = false
        
        self.contentTintContainer.view.addSubview(self.mirrorContentScrollView)
        
        self.contentContainerMask = UIImageView()
        self.contentContainerMask.image = generateImage(CGSize(width: 46.0, height: 46.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: 1.1)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            let shadowColor = UIColor.black

            let stepCount = 10
            var colors: [CGColor] = []
            var locations: [CGFloat] = []

            for i in 0 ... stepCount {
                let t = CGFloat(i) / CGFloat(stepCount)
                colors.append(shadowColor.withAlphaComponent(t).cgColor)
                locations.append(t)
            }

            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
            
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let gradientWidth = 6.0
            context.drawRadialGradient(gradient, startCenter: center, startRadius: size.width / 2.0, endCenter: center, endRadius: size.width / 2.0 - gradientWidth, options: [])
            
            context.setFillColor(shadowColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: gradientWidth - 1.0, dy: gradientWidth - 1.0))
        })?.stretchableImage(withLeftCapWidth: Int(46.0 / 2.0), topCapHeight: Int(46.0 / 2.0))
        if self.getEmojiContent == nil || self.reactionsLocked {
            self.contentContainer.view.mask = self.contentContainerMask
        }
        
        if getEmojiContent != nil && !self.reactionsLocked {
            let expandItemView = ExpandItemView()
            self.expandItemView = expandItemView
            
            self.contentContainer.view.addSubview(expandItemView)
            self.contentTintContainer.view.addSubview(expandItemView.tintView)
        } else {
            self.expandItemView = nil
        }
        
        self.title = title
        if self.title != nil {
            let titleLabelView = TitleLabelView(frame: CGRect())
            self.titleLabelView = titleLabelView
            self.contentContainer.view.addSubview(titleLabelView)
        }
        
        self.alwaysAllowPremiumReactions = alwaysAllowPremiumReactions
        self.allPresetReactionsAreAvailable = allPresetReactionsAreAvailable
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        
        self.addSubnode(self.contentContainer)
        self.addSubnode(self.previewingItemContainer)
        
        if let titleLabelView = self.titleLabelView {
            titleLabelView.action = { [weak self] in
                guard let self else {
                    return
                }
                self.premiumReactionsSelected?(nil)
            }
        }
        
        self.availableReactionsDisposable = (context.engine.stickers.availableReactions()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] availableReactions in
            guard let strongSelf = self else {
                return
            }
            strongSelf.availableReactions = availableReactions
        })
        
        if alwaysAllowPremiumReactions {
            self.hasPremium = true
        } else {
            self.hasPremiumDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                         |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.hasPremium = peer?.isPremium ?? false
            })
        }
        
        if let getEmojiContent = getEmojiContent, !self.reactionsLocked {
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
                        if let alt = item.file.customEmojiAlt {
                            if filterList.contains(alt) {
                                filteredFiles.append(item.file._parse())
                            }
                        }
                    }
                }
                strongSelf.emptyResultEmojis = filteredFiles
            }))
            
            self.emojiContentDisposable = combineLatest(queue: .mainQueue(),
                getEmojiContent(self.animationCache, self.animationRenderer),
                self.emojiSearchState.get()
            ).start(next: { [weak self] emojiContent, emojiSearchState in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.hideExpandedTopPanel = emojiContent.panelItemGroups.isEmpty
                if emojiContent.panelItemGroups.count == 1 && emojiContent.panelItemGroups[0].groupId == AnyHashable("recent") {
                    strongSelf.hideExpandedTopPanel = true
                }
                
                var emojiContent = emojiContent
                if let emojiSearchResult = emojiSearchState.result {
                    var emptySearchResults: EmojiPagerContentComponent.EmptySearchResults?
                    if !emojiSearchResult.groups.contains(where: { !$0.items.isEmpty || $0.fillWithLoadingPlaceholders }) {
                        if strongSelf.stableEmptyResultEmoji == nil {
                            strongSelf.stableEmptyResultEmoji = strongSelf.emptyResultEmojis.randomElement()
                        }
                        emptySearchResults = EmojiPagerContentComponent.EmptySearchResults(
                            text: strongSelf.presentationData.strings.EmojiSearch_SearchReactionsEmptyResult,
                            iconFile: strongSelf.stableEmptyResultEmoji
                        )
                    } else {
                        strongSelf.stableEmptyResultEmoji = nil
                    }
                    emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiSearchResult.groups, itemContentUniqueId: EmojiPagerContentComponent.ContentId(id: emojiSearchResult.id, version: emojiSearchResult.version), emptySearchResults: emptySearchResults, searchState: emojiSearchState.isSearching ? .searching : .active)
                } else {
                    strongSelf.stableEmptyResultEmoji = nil
                    
                    if emojiSearchState.isSearching {
                        emojiContent = emojiContent.withUpdatedItemGroups(panelItemGroups: emojiContent.panelItemGroups, contentItemGroups: emojiContent.contentItemGroups, itemContentUniqueId: emojiContent.itemContentUniqueId, emptySearchResults: emojiContent.emptySearchResults, searchState: .searching)
                    }
                }
                
                strongSelf.emojiContent = emojiContent
                if !strongSelf.canBeExpanded {
                    strongSelf.canBeExpanded = true
                    
                    if !strongSelf.isEmojiOnly {
                        let horizontalExpandRecognizer = UIPanGestureRecognizer(target: strongSelf, action: #selector(strongSelf.horizontalExpandGesture(_:)))
                        strongSelf.view.addGestureRecognizer(horizontalExpandRecognizer)
                        strongSelf.horizontalExpandRecognizer = horizontalExpandRecognizer
                    }
                }
                strongSelf.updateEmojiContent(emojiContent)
                
                if let reactionSelectionComponentHost = strongSelf.reactionSelectionComponentHost, let componentView = reactionSelectionComponentHost.view {
                    var emojiTransition: ComponentTransition = .immediate
                    if let scheduledEmojiContentAnimationHint = strongSelf.scheduledEmojiContentAnimationHint {
                        strongSelf.scheduledEmojiContentAnimationHint = nil
                        let contentAnimation = scheduledEmojiContentAnimationHint
                        emojiTransition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(contentAnimation)
                    }
                    
                    var hideTopPanel = false
                    if strongSelf.isReactionSearchActive {
                        hideTopPanel = true
                    } else if strongSelf.alwaysAllowPremiumReactions || strongSelf.hideExpandedTopPanel {
                        hideTopPanel = true
                    }
                    
                    let _ = reactionSelectionComponentHost.update(
                        transition: emojiTransition,
                        component: AnyComponent(EmojiStatusSelectionComponent(
                            theme: strongSelf.presentationData.theme,
                            strings: strongSelf.presentationData.strings,
                            deviceMetrics: DeviceMetrics.iPhone13,
                            emojiContent: emojiContent,
                            color: nil,
                            backgroundColor: .clear,
                            separatorColor: strongSelf.presentationData.theme.list.itemPlainSeparatorColor.withMultipliedAlpha(0.5),
                            hideTopPanel: hideTopPanel,
                            disableTopPanel: strongSelf.alwaysAllowPremiumReactions || strongSelf.hideExpandedTopPanel,
                            hideTopPanelUpdated: { hideTopPanel, transition in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.isReactionSearchActive = hideTopPanel
                                strongSelf.requestLayout(transition.containedViewLayoutTransition)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: componentView.bounds.width, height: strongSelf.emojiContentHeight)
                    )
                }
            })
        }
        
        self.genericReactionEffectDisposable = (ReactionContextNode.randomGenericReactionEffect(context: context)
        |> deliverOnMainQueue).start(next: { [weak self] path in
            self?.genericReactionEffect = path
        })
    }
    
    deinit {
        self.emojiContentDisposable?.dispose()
        self.availableReactionsDisposable?.dispose()
        self.hasPremiumDisposable?.dispose()
        self.genericReactionEffectDisposable?.dispose()
        self.emojiSearchDisposable.dispose()
        self.stableEmptyResultEmojiDisposable.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
        longPressRecognizer.minimumPressDuration = 0.2
        self.longPressRecognizer = longPressRecognizer
        self.view.addGestureRecognizer(longPressRecognizer)
        
        if self.allPresetReactionsAreAvailable {
            longPressRecognizer.isEnabled = false
        }
    }
    
    @objc private func horizontalExpandGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.horizontalExpandStartLocation = recognizer.location(in: self.view)
        case .changed:
            if let horizontalExpandStartLocation = self.horizontalExpandStartLocation {
                let currentLocation = recognizer.location(in: self.view)
                
                let distance = -min(0.0, currentLocation.x - horizontalExpandStartLocation.x)
                self.horizontalExpandDistance = distance
                
                let maxCompressionDistance: CGFloat = 100.0
                var compressionFactor: CGFloat = max(0.0, min(1.0, self.horizontalExpandDistance / maxCompressionDistance))
                compressionFactor = compressionFactor * compressionFactor
                
                if compressionFactor >= 0.95 {
                    self.horizontalExpandStartLocation = nil
                    self.expand()
                } else {
                    self.extensionDistance = 20.0 * compressionFactor
                    self.visibleExtensionDistance = self.extensionDistance
                    
                    self.requestLayout(.immediate)
                }
            }
        case .cancelled, .ended:
            if let _ = self.horizontalExpandStartLocation, self.horizontalExpandDistance != 0.0 {
                if self.horizontalExpandDistance >= 90.0 {
                    self.expand()
                } else {
                    self.horizontalExpandDistance = 0.0
                    self.extensionDistance = 0.0
                    self.visibleExtensionDistance = 0.0
                    
                    self.requestLayout(.animated(duration: 0.4, curve: .spring))
                }
            }
        default:
            break
        }
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, centerAligned: Bool = false, isCoveredByInput: Bool, isAnimatingOut: Bool, forceUpdate: Bool = false, transition: ContainedViewLayoutTransition) {
        self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: isAnimatingOut, forceUpdate: forceUpdate, transition: transition, animateInFromAnchorRect: nil, animateOutToAnchorRect: nil)
    }
    
    public func updateIsIntersectingContent(isIntersectingContent: Bool, transition: ContainedViewLayoutTransition) {
        self.backgroundNode.updateIsIntersectingContent(isIntersectingContent: isIntersectingContent, transition: transition)
    }
    
    public func updateExtension(distance: CGFloat) {
        if self.extensionDistance != distance {
            self.extensionDistance = distance
            
            if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
                self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .immediate, animateInFromAnchorRect: nil, animateOutToAnchorRect: nil)
            }
        }
    }
    
    public func wantsDisplayBelowKeyboard() -> Bool {
        if let emojiView = self.reactionSelectionComponentHost?.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View {
            return emojiView.wantsDisplayBelowKeyboard()
        } else if let stickersView = self.reactionSelectionComponentHost?.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("stickers"))) as? EmojiPagerContentComponent.View {
            return stickersView.wantsDisplayBelowKeyboard()
        } else {
            return false
        }
    }
    
    private func calculateBackgroundFrame(containerSize: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, contentSize: CGSize, centerAligned: Bool) -> (backgroundFrame: CGRect, visualBackgroundFrame: CGRect, isLeftAligned: Bool, cloudSourcePoint: CGFloat) {
        var contentSize = contentSize
        contentSize.width = max(46.0, contentSize.width)
        contentSize.height = self.contentTopInset + self.currentContentHeight
        
        let sideInset: CGFloat
        if self.forceTailToRight {
            sideInset = insets.left
        } else {
            sideInset = 11.0 + insets.left
        }
        let backgroundOffset: CGPoint = CGPoint(x: 22.0, y: -7.0)
        
        var rect: CGRect
        let isLeftAligned: Bool
        if self.forceTailToRight {
            rect = CGRect(origin: CGPoint(x: anchorRect.minX - backgroundOffset.x - 4.0, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = false
        } else if anchorRect.minX < containerSize.width - anchorRect.maxX {
            rect = CGRect(origin: CGPoint(x: anchorRect.maxX - contentSize.width + backgroundOffset.x, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = true
        } else {
            rect = CGRect(origin: CGPoint(x: anchorRect.minX - backgroundOffset.x - 4.0, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = false
        }
        rect.origin.x = max(sideInset, rect.origin.x)
        rect.origin.y = max(insets.top + sideInset, rect.origin.y)
        rect.origin.x = min(containerSize.width - contentSize.width - sideInset, rect.origin.x)
        
        let rightEdge = containerSize.width - sideInset
        if rect.maxX > rightEdge {
            rect.origin.x = containerSize.width - sideInset - rect.width
        }
        if rect.minX < sideInset {
            rect.origin.x = sideInset
        }
        
        if centerAligned {
            rect.origin.x = floor((containerSize.width - rect.width) / 2.0)
        }
        
        let cloudSourcePoint: CGFloat
        if self.forceTailToRight {
            cloudSourcePoint = min(rect.maxX - 46.0 / 2.0, anchorRect.maxX - 4.0)
        } else if isLeftAligned {
            cloudSourcePoint = min(rect.maxX - 46.0 / 2.0, anchorRect.maxX - 4.0)
        } else {
            cloudSourcePoint = max(rect.minX + 46.0 / 2.0, anchorRect.minX)
        }
        
        var visualRect = rect
        visualRect.size.height += self.extensionDistance
        
        return (rect, visualRect, isLeftAligned, cloudSourcePoint)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(transition: .immediate)
    }
    
    private func updateScrolling(transition: ContainedViewLayoutTransition) {
        guard let itemLayout = self.itemLayout else {
            return
        }
        
        let sideInset: CGFloat = 6.0
        let itemSpacing: CGFloat = 8.0
        let itemSize: CGFloat = itemLayout.itemSize
        
        let containerHeight: CGFloat = 46.0
        var contentHeight: CGFloat = containerHeight
        if self.highlightedReaction != nil {
            contentHeight = floor(contentHeight * 0.9)
        }
        
        let totalVisibleCount: CGFloat = CGFloat(min(7, self.items.count))
        let totalVisibleWidth: CGFloat = totalVisibleCount * itemSize + (totalVisibleCount - 1.0) * itemSpacing
        
        let selectedItemSize = floor(itemSize * 1.5)
        let remainingVisibleWidth = totalVisibleWidth - selectedItemSize
        let remainingVisibleCount = totalVisibleCount - 1.0
        let remainingItemSize = floor((remainingVisibleWidth - (remainingVisibleCount - 1.0) * itemSpacing) / remainingVisibleCount)
        
        var visibleBounds = self.scrollNode.view.bounds
        self.previewingItemContainer.bounds = visibleBounds
        if self.highlightedReaction != nil {
            visibleBounds = visibleBounds.insetBy(dx: remainingItemSize - selectedItemSize, dy: 0.0)
        }
        let appearBounds = visibleBounds.insetBy(dx: 16.0, dy: 0.0)
        
        let highlightedReactionIndex: Int?
        if let highlightedReaction = self.highlightedReaction {
            highlightedReactionIndex = self.items.firstIndex(where: { $0.reaction == highlightedReaction })
        } else {
            highlightedReactionIndex = nil
        }
        
        var currentMaskFrame: CGRect?
        var maskTransition: ContainedViewLayoutTransition?
        
        let maxCompressionDistance: CGFloat = 100.0
        let compressionFactor: CGFloat = max(0.0, min(1.0, self.horizontalExpandDistance / maxCompressionDistance))
        let minItemSpacing: CGFloat = 2.0
        let effectiveItemSpacing: CGFloat = minItemSpacing + (1.0 - compressionFactor) * (itemSpacing - minItemSpacing)
        
        var topVisibleItems: Int
        if !self.reactionsLocked && self.getEmojiContent != nil {
            topVisibleItems = min(self.items.count, itemLayout.visibleItemCount)
        } else {
            topVisibleItems = self.items.count
        }
        
        var loopIdle = false
        for i in 0 ..< min(self.items.count, itemLayout.visibleItemCount) {
            if let reaction = self.items[i].reaction {
                switch reaction.rawValue {
                case .builtin:
                    break
                case .custom:
                    loopIdle = true
                case .stars:
                    break
                }
            }
        }
        
        if !self.context.sharedContext.energyUsageSettings.loopEmoji {
            loopIdle = false
        }
        
        var validIndices = Set<Int>()
        var nextX: CGFloat = sideInset
        for i in 0 ..< self.items.count {
            var currentItemSize = itemSize
            if let highlightedReactionIndex = highlightedReactionIndex {
                if highlightedReactionIndex == i {
                    currentItemSize = selectedItemSize
                } else {
                    currentItemSize = remainingItemSize
                }
            }
            
            var baseItemFrame = CGRect(origin: CGPoint(x: nextX, y: containerHeight - contentHeight + floor((contentHeight - currentItemSize) / 2.0)), size: CGSize(width: currentItemSize, height: currentItemSize))
            if highlightedReactionIndex == i {
                let updatedSize = floor(itemSize * 2.0)
                baseItemFrame = baseItemFrame.insetBy(dx: (baseItemFrame.width - updatedSize) / 2.0, dy: (baseItemFrame.height - updatedSize) / 2.0)
                
                baseItemFrame.origin.y = containerHeight - contentHeight + floor((contentHeight - itemSize) / 2.0) + itemSize + 4.0 - updatedSize
            }
            nextX += currentItemSize + effectiveItemSpacing
            
            if i >= topVisibleItems {
                if let itemNode = self.visibleItemNodes[i] {
                    self.visibleItemNodes.removeValue(forKey: i)
                    
                    if self.disappearingVisibleItemNodes[i] == nil {
                        self.disappearingVisibleItemNodes[i] = itemNode
                        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak self, weak itemNode] _ in
                            guard let strongSelf = self, let itemNode = itemNode else {
                                return
                            }
                            itemNode.removeFromSupernode()
                            if strongSelf.disappearingVisibleItemNodes[i] === itemNode {
                                strongSelf.disappearingVisibleItemNodes.removeValue(forKey: i)
                            }
                        })
                        itemNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.1, removeOnCompletion: false)
                    }
                }
            }
            
            if i >= topVisibleItems {
                if let itemNode = self.disappearingVisibleItemNodes[i] {
                    transition.updatePosition(node: itemNode, position: baseItemFrame.center, beginWithCurrentState: true)
                }
                
                break
            }
            
            if appearBounds.intersects(baseItemFrame) || (self.visibleItemNodes[i] != nil && visibleBounds.intersects(baseItemFrame)) {
                validIndices.insert(i)
                
                var itemFrame = baseItemFrame
                var selectionItemFrame = itemFrame
                let normalItemScale: CGFloat = 1.0
                
                var isPreviewing = false
                if let highlightedReaction = self.highlightedReaction, highlightedReaction == self.items[i].reaction {
                    isPreviewing = true
                }
                
                var isSelected = false
                if let reaction = self.items[i].reaction, self.selectedItems.contains(reaction.rawValue) {
                    isSelected = true
                } else if let emoji = self.items[i].emoji, self.selectedItems.contains(emoji) {
                    isSelected = true
                }
                
                if isSelected && !isPreviewing {
                    itemFrame = itemFrame.insetBy(dx: (itemFrame.width - 0.8 * itemFrame.width) * 0.5, dy: (itemFrame.height - 0.8 * itemFrame.height) * 0.5)
                }
                
                var animateIn = false
                
                let maskNode: ASDisplayNode?
                let itemNode: ReactionItemNode
                var itemTransition = transition
                if let current = self.visibleItemNodes[i] {
                    itemNode = current
                    maskNode = self.visibleItemMaskNodes[i]
                } else {
                    animateIn = self.didAnimateIn
                    itemTransition = .immediate
                    
                    switch self.items[i] {
                    case let .reaction(item, icon):
                        var isLocked = self.reactionsLocked
                        switch icon {
                        case .locked:
                            isLocked = true
                        default:
                            break
                        }
                        
                        itemNode = ReactionNode(context: self.context, theme: self.presentationData.theme, item: item, icon: icon, animationCache: self.animationCache, animationRenderer: self.animationRenderer, loopIdle: loopIdle, isLocked: isLocked)
                        maskNode = nil
                    case let .staticEmoji(emoji):
                        itemNode = EmojiItemNode(theme: self.presentationData.theme, emoji: emoji)
                        maskNode = nil
                    case .premium:
                        itemNode = PremiumReactionsNode(theme: self.presentationData.theme)
                        maskNode = itemNode.maskNode
                    }
                    self.visibleItemNodes[i] = itemNode
                    
                    self.scrollNode.addSubnode(itemNode)
                                        
                    if let maskNode = maskNode {
                        self.visibleItemMaskNodes[i] = maskNode
                        self.backgroundMaskNode.addSubnode(maskNode)
                    }
                }
                maskTransition = itemTransition
                
                if let selectionView = itemNode.selectionView, let selectionTintView = itemNode.selectionTintView {
                    if isSelected {
                        if selectionView.superview == nil {
                            self.mirrorContentScrollView.addSubview(selectionTintView)
                            self.scrollNode.view.addSubview(selectionView)
                            
                            selectionView.alpha = 1.0
                            selectionTintView.alpha = 1.0
                            if transition.isAnimated {
                                selectionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                selectionTintView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                transition.animateTransformScale(view: selectionView, from: 0.1)
                                transition.animateTransformScale(view: selectionTintView, from: 0.1)
                            }
                        }
                    } else {
                        if selectionView.superview != nil {
                            selectionView.alpha = 0.0
                            selectionTintView.alpha = 0.0
                            if transition.isAnimated {
                                selectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                    selectionTintView.removeFromSuperview()
                                    selectionView.removeFromSuperview()
                                })
                                selectionTintView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                            } else {
                                selectionTintView.removeFromSuperview()
                                selectionView.removeFromSuperview()
                            }
                        }
                    }
                }
                
                if let maskNode = maskNode {
                    let maskFrame = CGRect(origin: CGPoint(x: -self.scrollNode.view.contentOffset.x + itemFrame.minX, y: 0.0), size: CGSize(width: itemFrame.width, height: itemFrame.height + 12.0))
                    itemTransition.updateFrame(node: maskNode, frame: maskFrame)
                    currentMaskFrame = maskFrame
                }
                
                if let reaction = self.items[i].reaction, case .custom = reaction.rawValue, self.selectedItems.contains(reaction.rawValue) {
                    itemNode.layer.masksToBounds = true
                    itemNode.layer.cornerRadius = 12.0
                } else {
                    itemNode.layer.masksToBounds = false
                    itemNode.layer.cornerRadius = 0.0
                }
                
                if !itemNode.isExtracted {
                    if isPreviewing {
                        if itemNode.supernode !== self.previewingItemContainer {
                            self.previewingItemContainer.addSubnode(itemNode)
                        }
                    }
                    
                    if !self.reactionsLocked && self.getEmojiContent != nil && i == itemLayout.visibleItemCount - 1 {
                        itemFrame.origin.x -= (1.0 - compressionFactor) * selectionItemFrame.width * 0.5
                        selectionItemFrame.origin.x -= (1.0 - compressionFactor) * selectionItemFrame.width * 0.5
                        itemNode.isUserInteractionEnabled = false
                    } else {
                        itemNode.isUserInteractionEnabled = true
                    }
                    
                    itemTransition.updateFrameAsPositionAndBounds(node: itemNode, frame: itemFrame, beginWithCurrentState: true, completion: { [weak self, weak itemNode] completed in
                        guard let strongSelf = self, let itemNode = itemNode else {
                            return
                        }
                        if !completed {
                            return
                        }
                        if !isPreviewing {
                            if itemNode.supernode !== strongSelf.scrollNode {
                                strongSelf.scrollNode.addSubnode(itemNode)
                            }
                        }
                    })
                    itemNode.updateLayout(size: itemFrame.size, isExpanded: false, largeExpanded: false, isPreviewing: isPreviewing, transition: itemTransition)
                    
                    if let selectionView = itemNode.selectionView, let selectionTintView = itemNode.selectionTintView {
                        let cornerRadius = min(selectionItemFrame.width, selectionItemFrame.height) / 2.0
                        itemTransition.updatePosition(layer: selectionTintView.layer, position: selectionItemFrame.center)
                        itemTransition.updateBounds(layer: selectionTintView.layer, bounds: CGRect(origin: CGPoint(), size: selectionItemFrame.size))
                        itemTransition.updateCornerRadius(layer: selectionTintView.layer, cornerRadius: cornerRadius)
                        
                        itemTransition.updatePosition(layer: selectionView.layer, position: selectionItemFrame.center)
                        itemTransition.updateBounds(layer: selectionView.layer, bounds: CGRect(origin: CGPoint(), size: selectionItemFrame.size))
                        itemTransition.updateCornerRadius(layer: selectionView.layer, cornerRadius: cornerRadius)
                    }
                    
                    if animateIn && !self.skipApperanceAnimation {
                        itemNode.appear(animated: !self.context.sharedContext.currentPresentationData.with({ $0 }).reduceMotion && !self.reduceMotion)
                    }
                    
                    if !self.reactionsLocked, self.getEmojiContent != nil, i == itemLayout.visibleItemCount - 1, let itemNode = itemNode as? ReactionNode {
                        let itemScale: CGFloat = 0.001 * (1.0 - compressionFactor) + normalItemScale * compressionFactor
                        let alphaFraction = min(compressionFactor, 0.2) / 0.2
                        transition.updateSublayerTransformScale(node: itemNode, scale: itemScale)
                        transition.updateAlpha(node: itemNode, alpha: alphaFraction)
                        
                        if let selectionView = itemNode.selectionView, let selectionTintView = itemNode.selectionTintView {
                            transition.updateTransformScale(layer: selectionView.layer, scale: CGPoint(x: itemScale, y: itemScale))
                            transition.updateAlpha(layer: selectionView.layer, alpha: alphaFraction)
                            
                            transition.updateTransformScale(layer: selectionTintView.layer, scale: CGPoint(x: itemScale, y: itemScale))
                            transition.updateAlpha(layer: selectionTintView.layer, alpha: alphaFraction)
                        }
                    } else {
                        transition.updateSublayerTransformScale(node: itemNode, scale: normalItemScale)
                        if let selectionView = itemNode.selectionView, let selectionTintView = itemNode.selectionTintView {
                            transition.updateSublayerTransformScale(layer: selectionView.layer, scale: CGPoint(x: normalItemScale, y: normalItemScale))
                            transition.updateSublayerTransformScale(layer: selectionTintView.layer, scale: CGPoint(x: normalItemScale, y: normalItemScale))
                        }
                    }
                }
            }
        }
        
        if let expandItemView = self.expandItemView {
            let expandItemSize: CGFloat
            let expandTintOffset: CGFloat
            if self.highlightedReaction != nil {
                expandItemSize = floor(30.0 * 0.9)
                expandTintOffset = contentHeight - containerHeight
            } else {
                expandItemSize = 30.0
                expandTintOffset = 0.0
            }
            var baseNextFrame = CGRect(origin: CGPoint(x: self.scrollNode.view.bounds.width - expandItemSize - 9.0, y: self.contentTopInset + containerHeight - contentHeight + floor((contentHeight - expandItemSize) / 2.0)), size: CGSize(width: expandItemSize, height: expandItemSize + self.extensionDistance))
            if self.isExpanded {
                if self.alwaysAllowPremiumReactions || self.hideExpandedTopPanel {
                } else {
                    baseNextFrame.origin.y += 46.0 + 54.0 - 4.0
                }
            }
            
            transition.updateFrame(view: expandItemView, frame: baseNextFrame)
            transition.updateFrame(view: expandItemView.tintView, frame: baseNextFrame.offsetBy(dx: 0.0, dy: expandTintOffset))
            
            expandItemView.update(size: baseNextFrame.size, transition: transition)
        }
        
        if let currentMaskFrame = currentMaskFrame {
            let transition = maskTransition ?? transition
            transition.updateFrame(node: self.leftBackgroundMaskNode, frame: CGRect(x: -1000.0 + currentMaskFrame.minX, y: 0.0, width: 1000.0, height: self.contentTopInset + self.currentContentHeight + self.extensionDistance))
            transition.updateFrame(node: self.rightBackgroundMaskNode, frame: CGRect(x: currentMaskFrame.maxX, y: 0.0, width: 1000.0, height: self.currentContentHeight + self.extensionDistance))
        } else {
            transition.updateFrame(node: self.leftBackgroundMaskNode, frame: CGRect(x: 0.0, y: 0.0, width: 1000.0, height: self.contentTopInset + self.currentContentHeight + self.extensionDistance))
            self.rightBackgroundMaskNode.frame = CGRect(origin: .zero, size: .zero)
        }
        
        var removedIndices: [Int] = []
        for (index, itemNode) in self.visibleItemNodes {
            if !validIndices.contains(index) {
                removedIndices.append(index)
                itemNode.removeFromSupernode()
            }
        }
        for (index, maskNode) in self.visibleItemMaskNodes {
            if !validIndices.contains(index) {
                maskNode.removeFromSupernode()
            }
        }
        for index in removedIndices {
            self.visibleItemNodes.removeValue(forKey: index)
            self.visibleItemMaskNodes.removeValue(forKey: index)
        }
    }
    
    private func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, centerAligned: Bool, isCoveredByInput: Bool, isAnimatingOut: Bool, forceUpdate: Bool = false, transition: ContainedViewLayoutTransition, animateInFromAnchorRect: CGRect?, animateOutToAnchorRect: CGRect?, animateReactionHighlight: Bool = false) {
        if let expandItemView = self.expandItemView {
            expandItemView.updateTheme(theme: self.presentationData.theme)
        }
        
        self.validLayout = (size, insets, anchorRect, isCoveredByInput, centerAligned)
        
        let externalSideInset: CGFloat = 4.0
        let sideInset: CGFloat = 6.0
        let itemSpacing: CGFloat = 8.0
        var itemSize: CGFloat = 36.0
        let verticalInset: CGFloat = 13.0
        let rowHeight: CGFloat = 30.0
        
        var itemCount: Int
        var visibleContentWidth: CGFloat
        var completeContentWidth: CGFloat
        
        if !self.reactionsLocked && self.getEmojiContent != nil {
            let totalItemSlotCount = self.items.count + 1
            
            var maxRowItemCount = Int(floor((size.width - sideInset * 2.0 - externalSideInset * 2.0 - itemSpacing) / (itemSize + itemSpacing)))
            
            if maxRowItemCount < 8 {
                itemSize = floor((size.width - sideInset * 2.0 - externalSideInset * 2.0 - itemSpacing - 8 * itemSpacing) / 8.0)
                maxRowItemCount = Int(floor((size.width - sideInset * 2.0 - externalSideInset * 2.0 - itemSpacing) / (itemSize + itemSpacing)))
            }
            
            maxRowItemCount = min(maxRowItemCount, 8)
            itemCount = min(totalItemSlotCount, maxRowItemCount)
            if self.isExpanded {
                itemCount = maxRowItemCount
            }
            
            let minVisibleItemCount: CGFloat = CGFloat(itemCount)
            completeContentWidth = CGFloat(itemCount) * itemSize + (CGFloat(itemCount) - 1.0) * itemSpacing + sideInset * 2.0
            visibleContentWidth = floor(minVisibleItemCount * itemSize + (minVisibleItemCount - 1.0) * itemSpacing + sideInset * 2.0)
            if visibleContentWidth > size.width - sideInset * 2.0 {
                visibleContentWidth = size.width - sideInset * 2.0
            }
        } else {
            itemCount = self.items.count
            completeContentWidth = floor(CGFloat(itemCount) * itemSize + (CGFloat(itemCount) - 1.0) * itemSpacing + sideInset * 2.0)
            
            let minVisibleItemCount = min(CGFloat(self.items.count), 6.5)
            
            visibleContentWidth = floor(minVisibleItemCount * itemSize + (minVisibleItemCount - 1.0) * itemSpacing + sideInset * 2.0)
            if visibleContentWidth > size.width - sideInset * 2.0 {
                visibleContentWidth = size.width - sideInset * 2.0
            }
        }
        
        if let title = self.title, let titleLabelView = self.titleLabelView {
            let titleLabelHeight = titleLabelView.update(width: visibleContentWidth, text: title, theme: self.presentationData.theme, transition: transition)
            self.titleLabelHeight = titleLabelHeight
            
            let baseTitleFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: visibleContentWidth, height: titleLabelHeight))
            transition.updateFrame(view: titleLabelView, frame: baseTitleFrame)
            
            transition.updateAlpha(layer: titleLabelView.layer, alpha: self.isExpanded ? 0.0 : 1.0)
            if let titleView = titleLabelView.contentView.view, let tintContentView = titleLabelView.tintContentView.view {
                if tintContentView.superview == nil {
                    tintContentView.layer.rasterizationScale = UIScreenScale
                    self.contentTintContainer.view.addSubview(tintContentView)
                }
                transition.updateFrame(view: tintContentView, frame: titleView.frame.offsetBy(dx: baseTitleFrame.minX, dy: baseTitleFrame.minY))
                transition.updateAlpha(layer: tintContentView.layer, alpha: self.isExpanded ? 0.0 : 1.0)
            }
            
            if !self.isExpanded {
                self.contentTopInset = titleLabelHeight
            }
        }
        
        let contentHeight = verticalInset * 2.0 + rowHeight
        
        var backgroundInsets = insets
        backgroundInsets.left += sideInset
        backgroundInsets.right += sideInset
        
        let (actualBackgroundFrame, visualBackgroundFrame, isLeftAligned, cloudSourcePoint) = self.calculateBackgroundFrame(containerSize: CGSize(width: size.width, height: size.height), insets: backgroundInsets, anchorRect: anchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight), centerAligned: centerAligned)
        self.isLeftAligned = isLeftAligned
        
        self.itemLayout = ItemLayout(
            itemSize: itemSize,
            visibleItemCount: itemCount
        )
        
        var scrollFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: actualBackgroundFrame.size)
        if self.isExpanded {
            if self.alwaysAllowPremiumReactions || self.hideExpandedTopPanel {
                scrollFrame.origin.y += 0.0
            } else {
                scrollFrame.origin.y += 46.0 + 54.0 - 4.0
            }
        } else {
            scrollFrame.origin.y += self.contentTopInset
        }
        scrollFrame.origin.y += floorToScreenPixels(self.extensionDistance / 2.0)
        
        transition.updatePosition(node: self.contentContainer, position: visualBackgroundFrame.center, beginWithCurrentState: true)
        
        if !self.contentContainer.bounds.equalTo(CGRect(origin: CGPoint(), size: visualBackgroundFrame.size)) {
            transition.updateBounds(node: self.contentContainer, bounds: CGRect(origin: CGPoint(), size: visualBackgroundFrame.size), beginWithCurrentState: true)
        }
        
        transition.updateFrame(node: self.contentTintContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: visualBackgroundFrame.size), beginWithCurrentState: true)
        transition.updateFrame(view: self.contentContainerMask, frame: CGRect(origin: CGPoint(), size: visualBackgroundFrame.size), beginWithCurrentState: true)
        transition.updateFrame(node: self.scrollNode, frame: scrollFrame, beginWithCurrentState: true)
        transition.updateFrame(node: self.previewingItemContainer, frame: visualBackgroundFrame, beginWithCurrentState: true)
        self.scrollNode.view.contentSize = CGSize(width: completeContentWidth, height: scrollFrame.size.height)
        
        self.updateScrolling(transition: transition)
        
        self.emojiContentLayout = EmojiPagerContentComponent.CustomLayout(
            topPanelAlwaysHidden: self.alwaysAllowPremiumReactions || self.hideExpandedTopPanel,
            itemsPerRow: itemCount,
            itemSize: itemSize,
            sideInset: sideInset,
            itemSpacing: itemSpacing
        )
        
        if (self.isExpanded || (self.reactionSelectionComponentHost != nil && !self.isCollapsing)), let _ = self.getEmojiContent, !self.reactionsLocked {
            let reactionSelectionComponentHost: ComponentView<Empty>
            var componentTransition = ComponentTransition(transition)
            if let current = self.reactionSelectionComponentHost {
                reactionSelectionComponentHost = current
            } else {
                componentTransition = .immediate
                reactionSelectionComponentHost = ComponentView<Empty>()
                self.reactionSelectionComponentHost = reactionSelectionComponentHost
            }
            
            if let emojiContent = self.emojiContent {
                self.updateEmojiContent(emojiContent)
                
                if let scheduledEmojiContentAnimationHint = self.scheduledEmojiContentAnimationHint {
                    self.scheduledEmojiContentAnimationHint = nil
                    let contentAnimation = scheduledEmojiContentAnimationHint
                    componentTransition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(contentAnimation)
                }
                
                var hideTopPanel = false
                if self.isReactionSearchActive {
                    hideTopPanel = true
                } else if self.alwaysAllowPremiumReactions || self.hideExpandedTopPanel {
                    hideTopPanel = true
                }
                
                if forceUpdate {
                    componentTransition = componentTransition.withUserData(PagerComponentForceUpdate())
                }
                
                let _ = reactionSelectionComponentHost.update(
                    transition: componentTransition,
                    component: AnyComponent(EmojiStatusSelectionComponent(
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        deviceMetrics: DeviceMetrics.iPhone13,
                        emojiContent: emojiContent,
                        color: nil,
                        backgroundColor: .clear,
                        separatorColor: self.presentationData.theme.list.itemPlainSeparatorColor.withMultipliedAlpha(0.5),
                        hideTopPanel: hideTopPanel,
                        disableTopPanel: self.alwaysAllowPremiumReactions,
                        hideTopPanelUpdated: { [weak self] hideTopPanel, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.isReactionSearchActive = hideTopPanel
                            strongSelf.requestLayout(transition.containedViewLayoutTransition)
                        }
                    )),
                    environment: {},
                    forceUpdate: forceUpdate,
                    containerSize: CGSize(width: actualBackgroundFrame.width, height: self.emojiContentHeight)
                )
                if let componentView = reactionSelectionComponentHost.view {
                    var animateIn = false
                    if componentView.superview == nil {
                        componentView.layer.cornerRadius = 26.0
                        componentView.clipsToBounds = true
                        
                        self.contentContainer.view.insertSubview(componentView, belowSubview: self.scrollNode.view)
                        self.contentContainer.view.mask = nil
                        for (_, itemNode) in self.visibleItemNodes {
                            itemNode.isHidden = true
                            
                            if let selectionView = itemNode.selectionView, let selectionTintView = itemNode.selectionTintView {
                                selectionView.isHidden = true
                                selectionTintView.isHidden = true
                            }
                        }
                        if let emojiView = reactionSelectionComponentHost.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View {
                            var initialPositionAndFrame: [MediaId: (frame: CGRect, cornerRadius: CGFloat, frameIndex: Int, placeholder: UIImage)] = [:]
                            for (_, itemNode) in self.visibleItemNodes {
                                guard let itemNode = itemNode as? ReactionNode else {
                                    continue
                                }
                                guard let placeholder = itemNode.currentFrameImage else {
                                    continue
                                }
                                if itemNode.alpha.isZero {
                                    continue
                                }
                                initialPositionAndFrame[itemNode.item.stillAnimation.fileId] = (
                                    frame: itemNode.frame,
                                    cornerRadius: itemNode.layer.cornerRadius,
                                    frameIndex: itemNode.currentFrameIndex,
                                    placeholder: placeholder
                                )
                            }
                            
                            emojiView.animateInReactionSelection(sourceItems: initialPositionAndFrame)
                            
                            if let mirrorContentClippingView = emojiView.mirrorContentClippingView {
                                mirrorContentClippingView.clipsToBounds = false
                                
                                var animationOffsetY: CGFloat = 0.0
                                if self.isEmojiOnly {
                                    animationOffsetY += 54.0
                                } else if self.alwaysAllowPremiumReactions {
                                    animationOffsetY += -4.0
                                } else {
                                    animationOffsetY += 46.0 + 54.0 - 4.0
                                }
                                
                                ComponentTransition(transition).animateBoundsOrigin(view: mirrorContentClippingView, from: CGPoint(x: 0.0, y: animationOffsetY), to: CGPoint(), additive: true, completion: { [weak mirrorContentClippingView] _ in
                                    mirrorContentClippingView?.clipsToBounds = true
                                })
                            }
                        }
                        if let topPanelView = reactionSelectionComponentHost.findTaggedView(tag: EntityKeyboardTopPanelComponent.Tag(id: AnyHashable("emoji"))) as? EntityKeyboardTopPanelComponent.View {
                            topPanelView.animateIn()
                        }
                        
                        if let expandItemView = self.expandItemView {
                            expandItemView.alpha = 0.0
                            expandItemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.scrollNode.isHidden = true
                                strongSelf.mirrorContentScrollView.isHidden = true
                            })
                            expandItemView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                            expandItemView.tintView.alpha = 0.0
                            expandItemView.tintView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                            expandItemView.tintView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        }
                        animateIn = true
                    }
                    
                    let componentFrame = CGRect(origin: CGPoint(), size: actualBackgroundFrame.size)
                    
                    componentTransition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))
                    
                    if animateIn {
                        var animationOffsetY: CGFloat = 0.0
                        if self.isEmojiOnly {
                            animationOffsetY += 54.0
                        } else if self.alwaysAllowPremiumReactions {
                            animationOffsetY += 4.0
                        } else if self.isMessageEffects {
                            animationOffsetY += 54.0
                            transition.animatePositionAdditive(layer: self.backgroundNode.vibrantExpandedContentContainer.layer, offset: CGPoint(x: 0.0, y: -animationOffsetY + floorToScreenPixels(self.animateFromExtensionDistance / 2.0)))
                        } else {
                            animationOffsetY += 46.0 + 54.0 - 4.0
                        }
                        
                        transition.animatePositionAdditive(layer: componentView.layer, offset: CGPoint(x: 0.0, y: -animationOffsetY + floorToScreenPixels(self.animateFromExtensionDistance / 2.0)))
                    }
                }
            }
        } else if !self.isExpanded, let reactionSelectionComponentHost = self.reactionSelectionComponentHost {
            self.reactionSelectionComponentHost = nil
            if let componentView = reactionSelectionComponentHost.view {
                self.scrollNode.isHidden = false
                self.mirrorContentScrollView.isHidden = false
                
                if let expandItemView = self.expandItemView {
                    expandItemView.alpha = 1.0
                    expandItemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    expandItemView.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
                    expandItemView.tintView.alpha = 1.0
                    expandItemView.tintView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    expandItemView.tintView.layer.animateScale(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false)
                }
                
                for (_, itemNode) in self.visibleItemNodes {
                    itemNode.isHidden = false
                    itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    transition.animatePositionAdditive(layer: itemNode.layer, offset: CGPoint(x: 0.0, y: 54.0))
                    
                    if let selectionView = itemNode.selectionView, let selectionTintView = itemNode.selectionTintView {
                        transition.animatePositionAdditive(layer: selectionView.layer, offset: CGPoint(x: 0.0, y: 54.0))
                        transition.animatePositionAdditive(layer: selectionTintView.layer, offset: CGPoint(x: 0.0, y: 54.0))
                        
                        selectionView.isHidden = false
                        selectionTintView.isHidden = false
                    }
                }
                transition.updatePosition(layer: componentView.layer, position: componentView.layer.position.offsetBy(dx: 0.0, dy: -30.0))
                transition.updateAlpha(layer: componentView.layer, alpha: 0.0, completion: { _ in
                    componentView.removeFromSuperview()
                })
                if let emojiView = reactionSelectionComponentHost.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: AnyHashable("emoji"))) as? EmojiPagerContentComponent.View, let mirrorContentClippingView = emojiView.mirrorContentClippingView {
                    transition.updatePosition(layer: mirrorContentClippingView.layer, position: mirrorContentClippingView.layer.position.offsetBy(dx: 0.0, dy: -30.0))
                    transition.updateAlpha(layer: mirrorContentClippingView.layer, alpha: 0.0, completion: { _ in
                        mirrorContentClippingView.removeFromSuperview()
                    })
                }
            }
            if self.isCollapsing {
                Queue.mainQueue().justDispatch {
                    self.isCollapsing = false
                }
            }
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: visualBackgroundFrame, beginWithCurrentState: true)
        self.backgroundNode.update(
            theme: self.presentationData.theme,
            forceDark: self.forceDark,
            size: visualBackgroundFrame.size,
            cloudSourcePoint: cloudSourcePoint - visualBackgroundFrame.minX,
            isLeftAligned: isLeftAligned,
            isMinimized: self.highlightedReaction != nil && !self.highlightedByHover,
            isCoveredByInput: isCoveredByInput,
            displayTail: self.displayTail,
            forceTailToRight: self.forceTailToRight,
            transition: transition
        )
        
        if self.contentTintContainer.view.superview !== self.backgroundNode.backgroundTintMaskContainer {
            self.backgroundNode.backgroundTintMaskContainer.addSubview(self.contentTintContainer.view)
        }
        
        if let animateInFromAnchorRect = animateInFromAnchorRect, !self.reduceMotion {
            let springDuration: Double = 0.5
            let springDamping: CGFloat = 104.0
            let springScaleDelay: Double = 0.1
            let springDelay: Double = springScaleDelay + 0.01
            
            let sourceBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: backgroundInsets, anchorRect: animateInFromAnchorRect, contentSize: CGSize(width: visualBackgroundFrame.height, height: contentHeight), centerAligned: false).0
            
            self.backgroundNode.animateInFromAnchorRect(size: visualBackgroundFrame.size, sourceBackgroundFrame: sourceBackgroundFrame.offsetBy(dx: -visualBackgroundFrame.minX, dy: -visualBackgroundFrame.minY))
            
            let xOffset = sourceBackgroundFrame.midX - visualBackgroundFrame.midX
            self.animateInInfo = (sourceBackgroundFrame.minX - visualBackgroundFrame.minX, visualBackgroundFrame.width)
            self.contentContainer.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: xOffset, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            self.contentContainer.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(x: (sourceBackgroundFrame.minX - visualBackgroundFrame.minX), y: 0.0), size: sourceBackgroundFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: visualBackgroundFrame.size)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
            
            self.contentTintContainer.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: xOffset, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            self.contentTintContainer.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(x: (sourceBackgroundFrame.minX - visualBackgroundFrame.minX), y: 0.0), size: sourceBackgroundFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: visualBackgroundFrame.size)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        } else if let animateOutToAnchorRect = animateOutToAnchorRect {
            let targetBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: backgroundInsets, anchorRect: animateOutToAnchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight), centerAligned: false).0
            
            let offset = CGPoint(x: -(targetBackgroundFrame.minX - visualBackgroundFrame.minX), y: -(targetBackgroundFrame.minY - visualBackgroundFrame.minY))
            self.position = CGPoint(x: self.position.x - offset.x, y: self.position.y - offset.y)
            self.layer.animatePosition(from: offset, to: CGPoint(), duration: 0.2, removeOnCompletion: true, additive: true)
        }
    }
    
    private func updateEmojiContent(_ emojiContent: EmojiPagerContentComponent) {
        guard let emojiContentLayout = self.emojiContentLayout else {
            return
        }
        
        if !self.didInitializeEmojiContentHeight {
            self.didInitializeEmojiContentHeight = true
            
            if emojiContent.contentItemGroups.count == 1 && emojiContent.contentItemGroups[0].title == nil {
                let itemCount = emojiContent.contentItemGroups[0].items.count
                let numRows = (itemCount + (emojiContentLayout.itemsPerRow - 1)) / emojiContentLayout.itemsPerRow
                let proposedHeight: CGFloat = CGFloat(numRows) * emojiContentLayout.itemSize + CGFloat(numRows - 1) * emojiContentLayout.itemSpacing + emojiContentLayout.itemSpacing * 2.0 + 5.0
                self.emojiContentHeight = min(300.0, proposedHeight)
            }
        }
        
        emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak self] groupId, item, sourceView, sourceRect, sourceLayer, isLongPress in
                guard let strongSelf = self, let availableReactions = strongSelf.availableReactions else {
                    return
                }
                
                if case let .staticEmoji(emoji) = item.content {
                    strongSelf.emojiSelected?(emoji)
                    return
                }
                
                guard let itemFile = item.itemFile else {
                    return
                }
                
                strongSelf.didTriggerExpandedReaction = isLongPress
                
                var found = false
                for reaction in availableReactions.reactions {
                    guard let centerAnimation = reaction.centerAnimation, let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if reaction.selectAnimation.fileId == itemFile.fileId {
                        found = true
                        
                        let updateReaction: UpdateMessageReaction
                        switch reaction.value {
                        case let .builtin(value):
                            updateReaction = .builtin(value)
                        case let .custom(fileId):
                            updateReaction = .custom(fileId: fileId, file: nil)
                        case .stars:
                            updateReaction = .stars
                        }
                        
                        let reactionItem = ReactionItem(
                            reaction: ReactionItem.Reaction(rawValue: reaction.value),
                            appearAnimation: reaction.appearAnimation,
                            stillAnimation: reaction.selectAnimation,
                            listAnimation: centerAnimation,
                            largeListAnimation: reaction.activateAnimation,
                            applicationAnimation: aroundAnimation,
                            largeApplicationAnimation: reaction.effectAnimation,
                            isCustom: false
                        )
                        
                        if case .locked = item.icon {
                            strongSelf.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                        } else if strongSelf.reactionsLocked {
                            strongSelf.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                        } else {
                            strongSelf.customReactionSource = (sourceView, sourceRect, sourceLayer, reactionItem)
                            strongSelf.reactionSelected?(updateReaction, isLongPress)
                        }
                        
                        break
                    }
                }
                if !found {
                    let reactionItem = ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: .custom(itemFile.fileId.id)),
                        appearAnimation: itemFile,
                        stillAnimation: itemFile,
                        listAnimation: itemFile,
                        largeListAnimation: itemFile,
                        applicationAnimation: nil,
                        largeApplicationAnimation: nil,
                        isCustom: true
                    )
                    strongSelf.customReactionSource = (sourceView, sourceRect, sourceLayer, reactionItem)
                    if case .locked = item.icon {
                        strongSelf.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                    } else if strongSelf.reactionsLocked {
                        strongSelf.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                    } else {
                        strongSelf.reactionSelected?(reactionItem.updateMessageReaction, isLongPress)
                    }
                }
            },
            deleteBackwards: {
            },
            openStickerSettings: {
            },
            openFeatured: {
            },
            openSearch: {
            },
            addGroupAction: { [weak self] groupId, isPremiumLocked, _ in
                guard let strongSelf = self, let collectionId = groupId.base as? ItemCollectionId else {
                    return
                }
                
                if isPremiumLocked {
                    strongSelf.premiumReactionsSelected?(nil)
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
                                strongSelf.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupInstalled(id: collectionId, scrollToGroup: true))
                            }
                            let _ = strongSelf.context.engine.stickers.addStickerPackInteractively(info: featuredEmojiPack.info._parse(), items: featuredEmojiPack.topItems).start()
                            
                            break
                        }
                    }
                })
            },
            clearGroup: { [weak self] groupId in
                guard let strongSelf = self else {
                    return
                }
                if groupId == AnyHashable("popular") {
                    let presentationData = strongSelf.presentationData
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    let context = strongSelf.context
                    items.append(ActionSheetTextItem(title: presentationData.strings.Chat_ClearReactionsAlertText, parseMarkdown: true))
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Chat_ClearReactionsAlertAction, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.scheduledEmojiContentAnimationHint = EmojiPagerContentComponent.ContentAnimation(type: .groupRemoved(id: "popular"))
                        let _ = strongSelf.context.engine.stickers.clearRecentlyUsedReactions().start()
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
            pushController: { _ in
            },
            presentController: { _ in
            },
            presentGlobalOverlayController: { _ in
            },
            navigationController: {
                return nil
            },
            requestUpdate: { [weak self] transition in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdateOverlayWantsToBeBelowKeyboard(transition.containedViewLayoutTransition)
            },
            updateSearchQuery: { [weak self] query in
                guard let self else {
                    return
                }
                
                let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
                let strings = presentationData.strings
                
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
                        let isEmojiOnly = self.isEmojiOnly
                        
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
                        
                        let resultSignal: Signal<[EmojiPagerContentComponent.ItemGroup], NoError>
                        if self.isMessageEffects {
                            resultSignal = signal
                            |> mapToSignal { keywords -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                var allEmoticons: [String: String] = [:]
                                for keyword in keywords {
                                    for emoticon in keyword.emoticons {
                                        allEmoticons[emoticon] = keyword.keyword
                                    }
                                }
                                
                                return combineLatest(
                                    context.availableMessageEffects |> take(1),
                                    hasPremium |> take(1)
                                )
                                |> mapToSignal { availableMessageEffects, hasPremium -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                    guard let availableMessageEffects else {
                                        return .single([])
                                    }
                                    
                                    var filteredEffects: [AvailableMessageEffects.MessageEffect] = []
                                    for messageEffect in availableMessageEffects.messageEffects {
                                        if allEmoticons[messageEffect.emoticon] != nil {
                                            filteredEffects.append(messageEffect)
                                        }
                                    }
                                    
                                    var reactionEffects: [AvailableMessageEffects.MessageEffect] = []
                                    var stickerEffects: [AvailableMessageEffects.MessageEffect] = []
                                    for messageEffect in filteredEffects {
                                        if messageEffect.effectAnimation != nil {
                                            reactionEffects.append(messageEffect)
                                        } else {
                                            stickerEffects.append(messageEffect)
                                        }
                                    }
                                    
                                    struct ItemGroup {
                                        var supergroupId: AnyHashable
                                        var id: AnyHashable
                                        var title: String?
                                        var subtitle: String?
                                        var actionButtonTitle: String?
                                        var isPremiumLocked: Bool
                                        var isFeatured: Bool
                                        var displayPremiumBadges: Bool
                                        var hasEdit: Bool
                                        var headerItem: EntityKeyboardAnimationData?
                                        var items: [EmojiPagerContentComponent.Item]
                                    }
                                    
                                    var resultGroups: [ItemGroup] = []
                                    var resultGroupIndexById: [AnyHashable: Int] = [:]
                                    
                                    for i in 0 ..< 2 {
                                        let groupId = i == 0 ? "reactions" : "stickers"
                                        for item in i == 0 ? reactionEffects : stickerEffects {
                                            let itemFile = item.effectSticker
                                            
                                            var tintMode: EmojiPagerContentComponent.Item.TintMode = .none
                                            if itemFile.isCustomTemplateEmoji {
                                                tintMode = .primary
                                            }
                                            
                                            let icon: EmojiPagerContentComponent.Item.Icon
                                            if i == 0 {
                                                if !hasPremium && item.isPremium {
                                                    icon = .locked
                                                } else {
                                                    icon = .none
                                                }
                                            } else {
                                                if !hasPremium && item.isPremium {
                                                    icon = .locked
                                                } else if let staticIcon = item.staticIcon {
                                                    icon = .customFile(staticIcon)
                                                } else {
                                                    icon = .text(item.emoticon)
                                                }
                                            }
                                            
                                            let animationData = EntityKeyboardAnimationData(file: itemFile, partialReference: .none)
                                            let resultItem = EmojiPagerContentComponent.Item(
                                                animationData: animationData,
                                                content: .animation(animationData),
                                                itemFile: itemFile,
                                                subgroupId: nil,
                                                icon: icon,
                                                tintMode: tintMode
                                            )
                                            
                                            if let groupIndex = resultGroupIndexById[groupId] {
                                                resultGroups[groupIndex].items.append(resultItem)
                                            } else {
                                                resultGroupIndexById[groupId] = resultGroups.count
                                                resultGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: i == 0 ? nil : strings.Chat_MessageEffectMenu_SectionMessageEffects, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, hasEdit: false, headerItem: nil, items: [resultItem]))
                                            }
                                        }
                                    }
                                    
                                    let allItemGroups = resultGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                                        let hasClear = false
                                        let isEmbedded = false
                                        
                                        return EmojiPagerContentComponent.ItemGroup(
                                            supergroupId: group.supergroupId,
                                            groupId: group.id,
                                            title: group.title,
                                            subtitle: group.subtitle,
                                            badge: nil,
                                            actionButtonTitle: group.actionButtonTitle,
                                            isFeatured: group.isFeatured,
                                            isPremiumLocked: group.isPremiumLocked,
                                            isEmbedded: isEmbedded,
                                            hasClear: hasClear,
                                            hasEdit: group.hasEdit,
                                            collapsedLineCount: nil,
                                            displayPremiumBadges: group.displayPremiumBadges,
                                            headerItem: group.headerItem,
                                            fillWithLoadingPlaceholders: false,
                                            items: group.items
                                        )
                                    }
                                    
                                    return .single(allItemGroups)
                                }
                            }
                        } else {
                            let remotePacksSignal: Signal<(sets: FoundStickerSets, isFinalResult: Bool), NoError> = .single((FoundStickerSets(), false))
                            |> then(
                                context.engine.stickers.searchEmojiSetsRemotely(query: query) |> map {
                                    ($0, true)
                                }
                            )
                            let localPacksSignal: Signal<FoundStickerSets, NoError> = context.engine.stickers.searchEmojiSets(query: query)
                            
                            resultSignal = signal
                            |> mapToSignal { keywords -> Signal<[EmojiPagerContentComponent.ItemGroup], NoError> in
                                var allEmoticons: [String: String] = [:]
                                for keyword in keywords {
                                    for emoticon in keyword.emoticons {
                                        allEmoticons[emoticon] = keyword.keyword
                                    }
                                }
                                if isEmojiOnly {
                                    var items: [EmojiPagerContentComponent.Item] = []
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
                                    return .single(resultGroups)
                                } else {
                                    let remoteSignal = context.engine.stickers.searchEmoji(query: query, emoticon: Array(allEmoticons.keys), inputLanguageCode: languageCode)
                                    
                                    return combineLatest(
                                        context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000) |> take(1),
                                        context.engine.stickers.availableReactions() |> take(1),
                                        hasPremium |> take(1),
                                        remotePacksSignal,
                                        remoteSignal,
                                        localPacksSignal
                                    )
                                    |> map { view, availableReactions, hasPremium, foundPacks, foundEmoji, foundLocalPacks -> [EmojiPagerContentComponent.ItemGroup] in
                                        var result: [(String, TelegramMediaFile.Accessor?, String)] = []
                                        
                                        var allEmoticons: [String: String] = [:]
                                        for keyword in keywords {
                                            for emoticon in keyword.emoticons {
                                                allEmoticons[emoticon] = keyword.keyword
                                            }
                                        }
                                        
                                        for itemFile in foundEmoji.items {
                                            for attribute in itemFile.attributes {
                                                switch attribute {
                                                case let .CustomEmoji(_, _, alt, _):
                                                    if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                                        result.append((alt, TelegramMediaFile.Accessor(itemFile), keyword))
                                                    } else if alt == query {
                                                        result.append((alt, TelegramMediaFile.Accessor(itemFile), alt))
                                                    }
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                        
                                        for entry in view.entries {
                                            guard let item = entry.item as? StickerPackItem else {
                                                continue
                                            }
                                            if !item.file.isPremiumEmoji {
                                                if let alt = item.file.customEmojiAlt {
                                                    if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                                        result.append((alt, item.file, keyword))
                                                    } else if alt == query {
                                                        result.append((alt, item.file, alt))
                                                    }
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
                                                    icon: (!hasPremium && itemFile.isPremiumEmoji) ? .locked : .none,
                                                    tintMode: animationData.isTemplate ? .primary : .none
                                                )
                                                items.append(item)
                                            }
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
                                        
                                        var combinedSets: FoundStickerSets
                                        combinedSets = foundLocalPacks
                                        combinedSets = combinedSets.merge(with: foundPacks.sets)
                                        
                                        var existingCollectionIds = Set<ItemCollectionId>()
                                        for (collectionId, info, _, _) in combinedSets.infos {
                                            if !existingCollectionIds.contains(collectionId) {
                                                existingCollectionIds.insert(collectionId)
                                            } else {
                                                continue
                                            }
                                            
                                            if let info = info as? StickerPackCollectionInfo {
                                                var topItems: [StickerPackItem] = []
                                                for e in combinedSets.entries {
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
                                                        icon: (!hasPremium && item.file.isPremiumEmoji) ? .locked : .none,
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
                                        return resultGroups
                                    }
                                }
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
                    let context = self.context
                    let resultSignal: Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError>
                    if self.isMessageEffects {
                        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> map { peer -> Bool in
                            guard case let .user(user) = peer else {
                                return false
                            }
                            return user.isPremium
                        }
                        |> distinctUntilChanged
                        
                        let keywords: Signal<[String], NoError> = .single(value.identifiers)
                        resultSignal = keywords
                        |> mapToSignal { keywords -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                            var allEmoticons: [String: String] = [:]
                            for keyword in keywords {
                                allEmoticons[keyword] = keyword
                            }
                            
                            return combineLatest(
                                context.availableMessageEffects |> take(1),
                                hasPremium |> take(1)
                            )
                            |> mapToSignal { availableMessageEffects, hasPremium -> Signal<(items: [EmojiPagerContentComponent.ItemGroup], isFinalResult: Bool), NoError> in
                                guard let availableMessageEffects else {
                                    return .single(([], true))
                                }
                                
                                var filteredEffects: [AvailableMessageEffects.MessageEffect] = []
                                for messageEffect in availableMessageEffects.messageEffects {
                                    if allEmoticons[messageEffect.emoticon] != nil {
                                        filteredEffects.append(messageEffect)
                                    }
                                }
                                
                                var reactionEffects: [AvailableMessageEffects.MessageEffect] = []
                                var stickerEffects: [AvailableMessageEffects.MessageEffect] = []
                                for messageEffect in filteredEffects {
                                    if messageEffect.effectAnimation != nil {
                                        reactionEffects.append(messageEffect)
                                    } else {
                                        stickerEffects.append(messageEffect)
                                    }
                                }
                                
                                struct ItemGroup {
                                    var supergroupId: AnyHashable
                                    var id: AnyHashable
                                    var title: String?
                                    var subtitle: String?
                                    var actionButtonTitle: String?
                                    var isPremiumLocked: Bool
                                    var isFeatured: Bool
                                    var displayPremiumBadges: Bool
                                    var hasEdit: Bool
                                    var headerItem: EntityKeyboardAnimationData?
                                    var items: [EmojiPagerContentComponent.Item]
                                }
                                
                                var resultGroups: [ItemGroup] = []
                                var resultGroupIndexById: [AnyHashable: Int] = [:]
                                
                                for i in 0 ..< 2 {
                                    let groupId = i == 0 ? "reactions" : "stickers"
                                    for item in i == 0 ? reactionEffects : stickerEffects {
                                        let itemFile = item.effectSticker
                                        
                                        var tintMode: EmojiPagerContentComponent.Item.TintMode = .none
                                        if itemFile.isCustomTemplateEmoji {
                                            tintMode = .primary
                                        }
                                        
                                        let icon: EmojiPagerContentComponent.Item.Icon
                                        if i == 0 {
                                            if !hasPremium && item.isPremium {
                                                icon = .locked
                                            } else {
                                                icon = .none
                                            }
                                        } else {
                                            if !hasPremium && item.isPremium {
                                                icon = .locked
                                            } else if let staticIcon = item.staticIcon {
                                                icon = .customFile(staticIcon)
                                            } else {
                                                icon = .text(item.emoticon)
                                            }
                                        }
                                        
                                        let animationData = EntityKeyboardAnimationData(file: itemFile, partialReference: .none)
                                        let resultItem = EmojiPagerContentComponent.Item(
                                            animationData: animationData,
                                            content: .animation(animationData),
                                            itemFile: itemFile,
                                            subgroupId: nil,
                                            icon: icon,
                                            tintMode: tintMode
                                        )
                                        
                                        if let groupIndex = resultGroupIndexById[groupId] {
                                            resultGroups[groupIndex].items.append(resultItem)
                                        } else {
                                            resultGroupIndexById[groupId] = resultGroups.count
                                            resultGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: i == 0 ? nil : strings.Chat_MessageEffectMenu_SectionMessageEffects, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, hasEdit: false, headerItem: nil, items: [resultItem]))
                                        }
                                    }
                                }
                                
                                let allItemGroups = resultGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                                    let hasClear = false
                                    let isEmbedded = false
                                    
                                    return EmojiPagerContentComponent.ItemGroup(
                                        supergroupId: group.supergroupId,
                                        groupId: group.id,
                                        title: group.title,
                                        subtitle: group.subtitle,
                                        badge: nil,
                                        actionButtonTitle: group.actionButtonTitle,
                                        isFeatured: group.isFeatured,
                                        isPremiumLocked: group.isPremiumLocked,
                                        isEmbedded: isEmbedded,
                                        hasClear: hasClear,
                                        hasEdit: group.hasEdit,
                                        collapsedLineCount: nil,
                                        displayPremiumBadges: group.displayPremiumBadges,
                                        headerItem: group.headerItem,
                                        fillWithLoadingPlaceholders: false,
                                        items: group.items
                                    )
                                }
                                
                                return .single((allItemGroups, true))
                            }
                        }
                    } else {
                        resultSignal = self.context.engine.stickers.searchEmoji(category: value)
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
                            //self.emojiSearchStateValue.isSearching = true
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
            chatPeerId: nil,
            peekBehavior: nil,
            customLayout: emojiContentLayout,
            externalBackground: self.backgroundNode.backgroundTintMaskContainer.isHidden ? nil : EmojiPagerContentComponent.ExternalBackground(
                effectContainerView: self.backgroundNode.vibrantExpandedContentContainer
            ),
            externalExpansionView: self.view,
            customContentView: nil,
            useOpaqueTheme: false,
            hideBackground: self.hideBackground,
            stateContext: nil,
            addImage: nil
        )
    }
    
    public func animateIn(from sourceAnchorRect: CGRect) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        
        if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .immediate, animateInFromAnchorRect: sourceAnchorRect, animateOutToAnchorRect: nil)
        }
        
        let mainCircleDelay: Double = 0.01
        
        if !self.presentationData.reduceMotion && !self.reduceMotion {
            self.backgroundNode.animateIn()
        }
        
        self.didAnimateIn = true
        
        if !self.presentationData.reduceMotion && !self.reduceMotion {
            for i in 0 ..< self.items.count {
                guard let itemNode = self.visibleItemNodes[i] else {
                    continue
                }
                if let itemLayout = self.itemLayout, !self.reactionsLocked, self.getEmojiContent != nil, i == itemLayout.visibleItemCount - 1 {
                    itemNode.appear(animated: false)
                    continue
                }
                
                let itemDelay: Double
                if let animateInInfo = self.animateInInfo {
                    let distance = abs(itemNode.frame.center.x - animateInInfo.centerX)
                    let distanceNorm = distance / animateInInfo.width
                    let adjustedDistanceNorm = distanceNorm//listViewAnimationCurveSystem(distanceNorm)
                    itemDelay = mainCircleDelay + adjustedDistanceNorm * 0.3
                } else {
                    itemDelay = mainCircleDelay + Double(i) * 0.06
                }
                
                itemNode.willAppear(animated: true)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + itemDelay * UIView.animationDurationFactor(), execute: { [weak itemNode] in
                    guard let itemNode = itemNode else {
                        return
                    }
                    itemNode.appear(animated: true)
                })
            }
            
            if let expandItemView = self.expandItemView {
                let itemDelay: Double
                if let animateInInfo = self.animateInInfo {
                    let distance = abs(expandItemView.frame.center.x - animateInInfo.centerX)
                    let distanceNorm = distance / animateInInfo.width
                    let adjustedDistanceNorm = distanceNorm//listViewAnimationCurveSystem(distanceNorm)
                    itemDelay = mainCircleDelay + adjustedDistanceNorm * 0.3
                } else {
                    itemDelay = mainCircleDelay + Double(8) * 0.06
                }
                
                expandItemView.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, delay: itemDelay)
                expandItemView.tintView.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, delay: itemDelay)
            }
        } else {
            for i in 0 ..< self.items.count {
                guard let itemNode = self.visibleItemNodes[i] else {
                    continue
                }
                itemNode.appear(animated: false)
            }
        }
    }
    
    public func animateOut(to targetAnchorRect: CGRect?, animatingOutToReaction: Bool) {
        self.isAnimatingOut = true
        
        self.backgroundNode.animateOut()
        
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.isExtracted {
                continue
            }
            itemNode.layer.animateAlpha(from: itemNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            if let selectionView = itemNode.selectionView {
                selectionView.layer.animateAlpha(from: selectionView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            }
            if let selectionTintView = itemNode.selectionTintView {
                selectionTintView.layer.animateAlpha(from: selectionTintView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
            }
        }
        
        if let titleLabelView = self.titleLabelView {
            titleLabelView.layer.animateAlpha(from: titleLabelView.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        if let reactionComponentView = self.reactionSelectionComponentHost?.view {
            reactionComponentView.alpha = 0.0
            reactionComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        }
        if let expandItemView = self.expandItemView {
            expandItemView.alpha = 0.0
            expandItemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            expandItemView.tintView.alpha = 0.0
            expandItemView.tintView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        }
        
        if let targetAnchorRect = targetAnchorRect, let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .immediate, animateInFromAnchorRect: nil, animateOutToAnchorRect: targetAnchorRect)
        }
    }
    
    private func animateFromItemNodeToReaction(itemNode: ReactionNode, targetView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        guard let targetSnapshotView = targetView.snapshotContentTree(unhide: true) else {
            completion()
            return
        }
        
        //targetSnapshotView.layer.sublayers![0].backgroundColor = UIColor.green.cgColor
        
        let sourceFrame = itemNode.view.convert(itemNode.bounds, to: self.view)
        
        var selfTargetBounds = targetView.bounds
        if let targetView = targetView as? ReactionIconView, let iconFrame = targetView.iconFrame, !"".isEmpty {
            selfTargetBounds = iconFrame
        }
        /*if case .builtin = itemNode.item.reaction.rawValue {
            selfTargetBounds = selfTargetBounds.insetBy(dx: -selfTargetBounds.width * 0.5, dy: -selfTargetBounds.height * 0.5)
        }*/
        
        let targetFrame = self.view.convert(targetView.convert(selfTargetBounds, to: nil), from: nil)
        
        targetSnapshotView.frame = targetFrame
        //targetSnapshotView.backgroundColor = .blue
        self.view.insertSubview(targetSnapshotView, belowSubview: itemNode.view)
        
        var completedTarget = false
        var targetScaleCompleted = false
        let intermediateCompletion: () -> Void = {
            if completedTarget && targetScaleCompleted {
                completion()
            }
        }
        
        let targetPosition = targetFrame.center
        let duration: Double = 0.16
        
        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.9, removeOnCompletion: false)
        
        //itemNode.layer.isHidden = true
        /*targetView.alpha = 1.0
        targetView.isHidden = false
        if let targetView = targetView as? ReactionIconView {
            targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
        }*/
        
        itemNode.layer.animatePosition(from: itemNode.layer.position, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.alpha = 1.0
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animatePosition(from: sourceFrame.center, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 1.0, duration: duration, removeOnCompletion: false, completion: { [weak targetSnapshotView] _ in
            completedTarget = true
            intermediateCompletion()
            
            targetSnapshotView?.isHidden = true
            
            if hideNode {
                targetView.alpha = 1.0
                targetView.isHidden = false
                if let targetView = targetView as? ReactionIconView {
                    targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                }
                targetSnapshotView?.isHidden = true
                targetScaleCompleted = true
                intermediateCompletion()
            } else {
                targetScaleCompleted = true
                intermediateCompletion()
            }
        })
        
        itemNode.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 1.0) / itemNode.bounds.width, duration: duration, removeOnCompletion: false)
    }
    
    public func willAnimateOutToReaction(value: MessageReaction.Reaction) {
        for (_, itemNode) in self.visibleItemNodes {
            if let itemNode = itemNode as? ReactionNode, itemNode.item.reaction.rawValue == value {
                itemNode.isExtracted = true
            }
        }
    }
    
    public func animateOutToReaction(value: MessageReaction.Reaction, targetView: UIView, hideNode: Bool, forceSwitchToInlineImmediately: Bool = false, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, onHit: (() -> Void)?, completion: @escaping () -> Void) {
        self.isAnimatingOutToReaction = true
        
        var foundItemNode: ReactionNode?
        for (_, itemNode) in self.visibleItemNodes {
            if let itemNode = itemNode as? ReactionNode, itemNode.item.reaction.rawValue == value {
                foundItemNode = itemNode
                break
            }
        }
        
        foundItemNode?.animateHideEffects()
        
        if let customReactionSource = self.customReactionSource {
            let itemNode = ReactionNode(context: self.context, theme: self.presentationData.theme, item: customReactionSource.item, icon: .none, animationCache: self.animationCache, animationRenderer: self.animationRenderer, loopIdle: false, isLocked: false, useDirectRendering: false)
            if let contents = customReactionSource.layer.contents {
                itemNode.setCustomContents(contents: contents)
            }
            self.scrollNode.addSubnode(itemNode)
            itemNode.frame = customReactionSource.view.convert(customReactionSource.rect, to: self.scrollNode.view)
            itemNode.updateLayout(size: itemNode.frame.size, isExpanded: false, largeExpanded: false, isPreviewing: false, transition: .immediate)
            customReactionSource.layer.isHidden = true
            foundItemNode = itemNode
        }
        
        guard let itemNode = foundItemNode else {
            completion()
            return
        }
        
        let switchToInlineImmediately: Bool
        if itemNode.item.listAnimation.isVideoEmoji || itemNode.item.listAnimation.isVideoSticker || itemNode.item.listAnimation.isAnimatedSticker || itemNode.item.listAnimation.isStaticEmoji {
            switch itemNode.item.reaction.rawValue {
            case .builtin:
                switchToInlineImmediately = forceSwitchToInlineImmediately
            case .custom:
                switchToInlineImmediately = !self.didTriggerExpandedReaction
            case .stars:
                switchToInlineImmediately = forceSwitchToInlineImmediately
            }
        } else {
            switchToInlineImmediately = !self.didTriggerExpandedReaction
        }
        
        self.animationTargetView = targetView
        self.animationHideNode = hideNode
        
        if hideNode {
            if let animateTargetContainer = animateTargetContainer {
                animateTargetContainer.isHidden = true
                targetView.isHidden = true
            } else {
                targetView.alpha = 0.0
                targetView.layer.animateAlpha(from: targetView.alpha, to: 0.0, duration: 0.2)
            }
        }
        
        itemNode.isExtracted = true
        let selfSourceRect = itemNode.view.convert(itemNode.view.bounds, to: self.view)
        
        var selfTargetBounds = targetView.bounds
        if case .builtin = itemNode.item.reaction.rawValue {
            selfTargetBounds = selfTargetBounds.insetBy(dx: -selfTargetBounds.width * 0.5, dy: -selfTargetBounds.height * 0.5)
        } else if case .stars = itemNode.item.reaction.rawValue {
            selfTargetBounds = selfTargetBounds.insetBy(dx: -selfTargetBounds.width * 0.13, dy: -selfTargetBounds.height * 0.13).offsetBy(dx: -0.5, dy: -0.5)
        }
        
        let selfTargetRect = self.view.convert(selfTargetBounds, from: targetView)
        
        var expandedSize: CGSize = selfTargetRect.size
        if self.didTriggerExpandedReaction {
            if itemNode.item.listAnimation.isVideoEmoji || itemNode.item.listAnimation.isVideoSticker || itemNode.item.listAnimation.isStaticEmoji {
                expandedSize = CGSize(width: 80.0, height: 80.0)
            } else {
                expandedSize = CGSize(width: 120.0, height: 120.0)
            }
        }
        
        let expandedFrame = CGRect(origin: CGPoint(x: selfTargetRect.midX - expandedSize.width / 2.0, y: selfTargetRect.midY - expandedSize.height / 2.0), size: expandedSize)
        
        var effectFrame: CGRect
        let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
        if self.didTriggerExpandedReaction {
            let expandFactor: CGFloat = 0.5
            effectFrame = expandedFrame.insetBy(dx: -expandedFrame.width * expandFactor, dy: -expandedFrame.height * expandFactor).offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
        } else {
            effectFrame = expandedFrame.insetBy(dx: -expandedSize.width, dy: -expandedSize.height)
            if itemNode.item.isCustom {
                effectFrame = effectFrame.insetBy(dx: -expandedSize.width, dy: -expandedSize.height)
            }
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
        
        self.addSubnode(itemNode)
        itemNode.position = expandedFrame.center
        transition.updateBounds(node: itemNode, bounds: CGRect(origin: CGPoint(), size: expandedFrame.size))
        itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, largeExpanded: self.didTriggerExpandedReaction, isPreviewing: false, transition: transition)
        
        let additionalAnimationNode: DefaultAnimatedStickerNodeImpl?
        var genericAnimationView: AnimationView?
        
        var additionalAnimation: TelegramMediaFile.Accessor?
        if self.didTriggerExpandedReaction {
            additionalAnimation = itemNode.item.largeApplicationAnimation
        } else {
            additionalAnimation = itemNode.item.applicationAnimation
            
            if additionalAnimation == nil && itemNode.item.isCustom {
                if let alt = itemNode.item.stillAnimation.customEmojiAlt {
                    if let availableReactions = self.availableReactions {
                        for availableReaction in availableReactions.reactions {
                            if availableReaction.value == .builtin(alt) {
                                additionalAnimation = availableReaction.aroundAnimation
                            }
                        }
                    }
                }
            }
        }
        
        if let additionalAnimation = additionalAnimation {
            let additionalAnimationNodeValue = DefaultAnimatedStickerNodeImpl()
            additionalAnimationNode = additionalAnimationNodeValue
            if self.didTriggerExpandedReaction {
                if incomingMessage {
                    additionalAnimationNodeValue.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
            }
            
            let additionalAnimationFile = additionalAnimation._parse()
            additionalAnimationNodeValue.setup(source: AnimatedStickerResourceSource(account: itemNode.context.account, resource: additionalAnimationFile.resource), width: Int(effectFrame.width * 2.0), height: Int(effectFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(additionalAnimationFile.resource.id)))
            additionalAnimationNodeValue.frame = effectFrame
            additionalAnimationNodeValue.updateLayout(size: effectFrame.size)
            self.addSubnode(additionalAnimationNodeValue)
        } else if itemNode.item.isCustom {
            additionalAnimationNode = nil
            
            var effectData: Data?
            if self.didTriggerExpandedReaction {
                if let url = getAppBundle().url(forResource: "generic_reaction_effect", withExtension: "json") {
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
                
                if incomingMessage {
                    view.layer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
                
                genericAnimationView = view
                
                let animationCache = itemNode.context.animationCache
                let animationRenderer = itemNode.context.animationRenderer
                
                for i in 1 ... 32 {
                    let allLayers = view.allLayers(forKeypath: AnimationKeypath(keypath: "placeholder_\(i)"))
                    let itemNodeListAnimationFile = itemNode.item.listAnimation._parse()
                    for animationLayer in allLayers {
                        let baseItemLayer = InlineStickerItemLayer(
                            context: itemNode.context,
                            userLocation: .other,
                            attemptSynchronousLoad: false,
                            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: itemNode.item.listAnimation.fileId.id, file: itemNodeListAnimationFile),
                            file: itemNodeListAnimationFile,
                            cache: animationCache,
                            renderer: animationRenderer,
                            placeholderColor: UIColor(white: 0.0, alpha: 0.0),
                            pointSize: CGSize(width: self.didTriggerExpandedReaction ? 64.0 : 32.0, height: self.didTriggerExpandedReaction ? 64.0 : 32.0)
                        )
                        
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
                
                if self.didTriggerExpandedReaction {
                    view.frame = effectFrame.insetBy(dx: -10.0, dy: -10.0).offsetBy(dx: incomingMessage ? 22.0 : -22.0, dy: 0.0)
                } else {
                    view.frame = effectFrame.insetBy(dx: -20.0, dy: -20.0)
                }
                self.view.addSubview(view)
            }
        } else {
            additionalAnimationNode = nil
        }
        
        var mainAnimationCompleted = false
        var additionalAnimationCompleted = false
        let intermediateCompletion: () -> Void = {
            if mainAnimationCompleted && additionalAnimationCompleted {
                completion()
            }
        }
        
        if let additionalAnimationNode = additionalAnimationNode {
            additionalAnimationNode.completed = { _ in
                additionalAnimationCompleted = true
                intermediateCompletion()
            }
        } else if let genericAnimationView = genericAnimationView {
            genericAnimationView.play(completion: { _ in
                additionalAnimationCompleted = true
                intermediateCompletion()
            })
        } else {
            additionalAnimationCompleted = true
        }
        
        transition.animatePositionWithKeyframes(node: itemNode, keyframes: generateParabollicMotionKeyframes(from: selfSourceRect.center, to: expandedFrame.center, elevation: 30.0), completion: { [weak self, weak itemNode, weak targetView, weak animateTargetContainer] _ in
            let afterCompletion: () -> Void = {
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.didTriggerExpandedReaction {
                    return
                }
                guard let itemNode = itemNode else {
                    return
                }
                if let animateTargetContainer = animateTargetContainer {
                    animateTargetContainer.isHidden = false
                }
                
                if let targetView = targetView {
                    targetView.isHidden = false
                    targetView.alpha = 1.0
                    targetView.layer.removeAnimation(forKey: "opacity")
                }
                
                if strongSelf.hapticFeedback == nil {
                    strongSelf.hapticFeedback = HapticFeedback()
                }
                strongSelf.hapticFeedback?.tap()
                
                if let targetView = targetView as? ReactionIconView {
                    if switchToInlineImmediately {
                        targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                        itemNode.isHidden = true
                    } else {
                        targetView.updateIsAnimationHidden(isAnimationHidden: true, transition: .immediate)
                        targetView.addSubnode(itemNode)
                        itemNode.frame = selfTargetBounds
                    }
                } else if let targetView = targetView as? UIImageView {
                    itemNode.isHidden = true
                    targetView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    targetView.layer.animateScale(from: 0.2, to: 1.0, duration: 0.12)
                }
                
                if switchToInlineImmediately {
                    mainAnimationCompleted = true
                    intermediateCompletion()
                }
            }
            
            onHit?()
            
            if switchToInlineImmediately {
                afterCompletion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: afterCompletion)
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15 * UIView.animationDurationFactor(), execute: {
            additionalAnimationNode?.visibility = true
            if let animateTargetContainer = animateTargetContainer {
                animateTargetContainer.isHidden = false
                animateTargetContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                animateTargetContainer.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
        })
        
        if !switchToInlineImmediately {
            let maxDuration: Double
            if case .stars = value {
                maxDuration = 3.0
            } else {
                maxDuration = 2.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + min(5.0, maxDuration * UIView.animationDurationFactor()), execute: {
                if self.didTriggerExpandedReaction {
                    self.animateFromItemNodeToReaction(itemNode: itemNode, targetView: targetView, hideNode: hideNode, completion: { [weak self] in
                        if let strongSelf = self, strongSelf.didTriggerExpandedReaction, let addStandaloneReactionAnimation = addStandaloneReactionAnimation {
                            let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: strongSelf.genericReactionEffect)
                            
                            addStandaloneReactionAnimation(standaloneReactionAnimation)
                            
                            standaloneReactionAnimation.animateReactionSelection(
                                context: strongSelf.context,
                                theme: strongSelf.presentationData.theme,
                                animationCache: strongSelf.animationCache,
                                reaction: itemNode.item,
                                avatarPeers: [],
                                playHaptic: false,
                                isLarge: false,
                                targetView: targetView,
                                addStandaloneReactionAnimation: nil,
                                completion: { [weak standaloneReactionAnimation] in
                                    if let _ = standaloneReactionAnimation?.supernode {
                                        standaloneReactionAnimation?.removeFromSupernode()
                                    } else {
                                        standaloneReactionAnimation?.view.removeFromSuperview()
                                    }
                                }
                            )
                        }
                        
                        mainAnimationCompleted = true
                        intermediateCompletion()
                    })
                } else {
                    if hideNode {
                        targetView.alpha = 1.0
                        targetView.isHidden = false
                        if let targetView = targetView as? ReactionIconView {
                            targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                            if let _ = itemNode.supernode {
                                itemNode.removeFromSupernode()
                            } else {
                                itemNode.view.removeFromSuperview()
                            }
                        }
                    }
                    mainAnimationCompleted = true
                    intermediateCompletion()
                }
            })
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isExpanded, let titleLabelView = self.titleLabelView {
            if let result = titleLabelView.hitTest(self.view.convert(point, to: titleLabelView), with: event) {
                return result
            }
        }
        
        let contentPoint = self.contentContainer.view.convert(point, from: self.view)
        if self.contentContainer.bounds.contains(contentPoint) {
            return self.contentContainer.hitTest(contentPoint, with: event)
        }
        
        return nil
    }
    
    private let longPressDuration: Double = 0.5
    @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let point = recognizer.location(in: self.view)
            if let itemNode = self.reactionItemNode(at: point) as? ReactionNode {
                if self.selectedItems.contains(itemNode.item.reaction.rawValue) {
                    recognizer.state = .cancelled
                    return
                }
                if !itemNode.isAnimationLoaded {
                    recognizer.state = .cancelled
                    return
                }
                
                self.highlightedReaction = itemNode.item.reaction
                if #available(iOS 13.0, *) {
                    self.continuousHaptic = try? ContinuousHaptic(duration: longPressDuration)
                }
                
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                
                if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .animated(duration: longPressDuration, curve: .linear), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
                }
                
                self.longPressTimer?.invalidate()
                self.longPressTimer = SwiftSignalKit.Timer(timeout: longPressDuration, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.longPressRecognizer?.state = .ended
                }, queue: .mainQueue())
                self.longPressTimer?.start()
            }
        case .changed:
            let point = recognizer.location(in: self.view)
            var shouldCancel = false
            if let itemNode = self.reactionItemNode(at: point) as? ReactionNode {
                if self.highlightedReaction != itemNode.item.reaction {
                    shouldCancel = true
                }
            } else {
                shouldCancel = true
            }
            if shouldCancel {
                self.longPressRecognizer?.state = .cancelled
            }
        case .cancelled:
            self.longPressTimer?.invalidate()
            self.continuousHaptic = nil
            
            self.highlightedReaction = nil
            if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
                self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .animated(duration: 0.3, curve: .spring), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
            }
        case .ended:
            self.longPressTimer?.invalidate()
            self.continuousHaptic = nil
            self.didTriggerExpandedReaction = true
            self.highlightGestureFinished(performAction: true, isLarge: true)
        default:
            break
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            let point = recognizer.location(in: self.view)
            
            if self.isExpanded || self.isCollapsing {
                return
            }
            if let expandItemView = self.expandItemView, expandItemView.bounds.contains(self.view.convert(point, to: self.expandItemView)) {
                self.animateFromExtensionDistance = self.contentTopInset * 2.0 + self.extensionDistance
                self.contentTopInset = 0.0
                self.currentContentHeight = self.emojiContentHeight
                self.isExpanded = true
                self.longPressRecognizer?.isEnabled = false
                self.isExpandedUpdated(.animated(duration: 0.4, curve: .spring))
            } else if let reaction = self.reaction(at: point) {
                switch reaction {
                case let .reaction(reactionItem, icon):
                    if case .custom = reactionItem.updateMessageReaction, let hasPremium = self.hasPremium, !hasPremium, !self.allPresetReactionsAreAvailable {
                        self.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                    } else if self.reactionsLocked {
                        self.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                    } else if case .locked = icon {
                        self.premiumReactionsSelected?(reactionItem.stillAnimation._parse())
                    } else {
                        self.reactionSelected?(reactionItem.updateMessageReaction, false)
                    }
                case let .staticEmoji(emoji):
                    self.emojiSelected?(emoji)
                case .premium:
                    self.premiumReactionsSelected?(nil)
                }
            }
        default:
            break
        }
    }
    
    public func hasSpaceInTheBottom(insets: UIEdgeInsets, height: CGFloat) -> Bool {
        if self.backgroundNode.frame.maxY < self.bounds.height - insets.bottom - height {
            return true
        } else {
            return false
        }
    }
    
    public func expand() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.tap()
        
        self.longPressRecognizer?.isEnabled = false
        
        self.animateFromExtensionDistance = self.contentTopInset * 2.0 + self.extensionDistance
        self.extensionDistance = 0.0
        self.visibleExtensionDistance = 0.0
        self.contentTopInset = 0.0
        self.currentContentHeight = self.emojiContentHeight
        self.isExpanded = true
        self.isExpandedUpdated(.animated(duration: 0.4, curve: .spring))
    }
    
    public func collapse() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.tap()
        
        self.view.endEditing(true)
        self.longPressRecognizer?.isEnabled = false
        
        guard self.isExpanded else {
            return
        }
        
        self.animateFromExtensionDistance = 0.0
        self.extensionDistance = 0.0
        self.visibleExtensionDistance = 0.0
        self.contentTopInset = self.titleLabelHeight ?? 0.0
        self.currentContentHeight = 46.0
        self.isExpanded = false
        self.isCollapsing = true
        self.isExpandedUpdated(.animated(duration: 0.4, curve: .spring))
        
        self.emojiSearchDisposable.set(nil)
        self.emojiSearchState.set(.single(EmojiSearchState(result: nil, isSearching: false)))
    }
    
    public func highlightGestureMoved(location: CGPoint, hover: Bool) {
        if self.allPresetReactionsAreAvailable {
            return
        }
        
        let highlightedReaction = self.previewReaction(at: location)?.reaction
        if self.highlightedReaction != highlightedReaction {
            self.highlightedReaction = highlightedReaction
            self.highlightedByHover = hover && highlightedReaction != nil
            
            if !hover {
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                self.hapticFeedback?.tap()
            }
            
            if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
                self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
            }
        }
    }
    
    public func highlightGestureFinished(performAction: Bool) {
        if self.allPresetReactionsAreAvailable {
            return
        }
        
        self.highlightGestureFinished(performAction: performAction, isLarge: false)
    }
    
    private func highlightGestureFinished(performAction: Bool, isLarge: Bool) {
        if self.allPresetReactionsAreAvailable {
            return
        }
        
        if let highlightedReaction = self.highlightedReaction {
            self.highlightedReaction = nil
            if performAction {
                self.performReactionSelection(reaction: highlightedReaction, isLarge: isLarge)
            } else {
                if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
                }
            }
        }
    }
    
    private func previewReaction(at point: CGPoint) -> ReactionItem? {
        let scrollPoint = self.view.convert(point, to: self.scrollNode.view)
        if !self.scrollNode.bounds.contains(scrollPoint) {
            return nil
        }
        
        let itemSize: CGFloat = 40.0
        
        var closestItem: (index: Int, distance: CGFloat)?
        
        for (index, itemNode) in self.visibleItemNodes {
            let intersectionItemFrame = CGRect(origin: CGPoint(x: itemNode.position.x - itemSize / 2.0, y: itemNode.position.y - 1.0), size: CGSize(width: itemSize, height: 2.0))
            
            if !self.scrollNode.bounds.contains(intersectionItemFrame) {
                continue
            }
            
            let distance = abs(scrollPoint.x - intersectionItemFrame.midX)
            if let (_, currentDistance) = closestItem {
                if currentDistance > distance {
                    closestItem = (index, distance)
                }
            } else {
                closestItem = (index, distance)
            }
        }
        if let closestItem = closestItem, let closestItemNode = self.visibleItemNodes[closestItem.index] as? ReactionNode {
            if let expandItemView = self.expandItemView, expandItemView.frame.insetBy(dx: -20.0, dy: -20.0).contains(scrollPoint) {
                return nil
            }
            return closestItemNode.item
        }
        return nil
    }
    
    private func reactionItemNode(at point: CGPoint) -> ReactionItemNode? {
        for i in 0 ..< 2 {
            let touchInset: CGFloat = i == 0 ? 0.0 : 8.0
            for (_, itemNode) in self.visibleItemNodes {
                if itemNode.supernode === self.scrollNode && !self.scrollNode.bounds.intersects(itemNode.frame) {
                    continue
                }
                if !itemNode.isUserInteractionEnabled {
                    continue
                }
                let itemPoint = self.view.convert(point, to: itemNode.view)
                if itemNode.bounds.insetBy(dx: -touchInset, dy: -touchInset).contains(itemPoint) {
                    return itemNode
                }
            }
        }
        return nil
    }
    
    public func reaction(at point: CGPoint) -> ReactionContextItem? {
        let itemNode = self.reactionItemNode(at: point)
        if let itemNode = itemNode as? ReactionNode {
            if !itemNode.isAnimationLoaded {
                return nil
            }
            return .reaction(item: itemNode.item, icon: itemNode.icon)
        } else if let itemNode = itemNode as? EmojiItemNode {
            return .staticEmoji(itemNode.emoji)
        } else if let _ = itemNode as? PremiumReactionsNode {
            return .premium
        }
        return nil
    }
    
    public func performReactionSelection(reaction: ReactionItem.Reaction, isLarge: Bool) {
        for (_, itemNode) in self.visibleItemNodes {
            if let itemNode = itemNode as? ReactionNode, itemNode.item.reaction == reaction {
                if case .custom = itemNode.item.updateMessageReaction, let hasPremium = self.hasPremium, !hasPremium {
                    self.premiumReactionsSelected?(itemNode.item.stillAnimation._parse())
                } else if self.reactionsLocked {
                    self.premiumReactionsSelected?(itemNode.item.stillAnimation._parse())
                } else {
                    self.reactionSelected?(itemNode.item.updateMessageReaction, isLarge)
                }
                break
            }
        }
    }
    
    public func cancelReactionAnimation() {
        self.standaloneReactionAnimation?.cancel()
        
        if let animationTargetView = self.animationTargetView, self.animationHideNode {
            animationTargetView.alpha = 1.0
            animationTargetView.isHidden = false
        }
    }
    
    public func setHighlightedReaction(_ value: ReactionItem.Reaction?) {
        self.highlightedReaction = value
        if let (size, insets, anchorRect, isCoveredByInput, centerAligned) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, centerAligned: centerAligned, isCoveredByInput: isCoveredByInput, isAnimatingOut: false, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
        }
    }
}

public final class StandaloneReactionAnimation: ASDisplayNode {
    private let genericReactionEffect: String?
    private let useDirectRendering: Bool
    private var itemNode: ReactionNode? = nil
    private var itemNodeIsEmbedded: Bool = false
    private let hapticFeedback = HapticFeedback()
    private var isCancelled: Bool = false
    
    private weak var targetView: UIView?
    
    public init(genericReactionEffect: String?, useDirectRendering: Bool = false) {
        self.genericReactionEffect = genericReactionEffect
        self.useDirectRendering = useDirectRendering
        
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    public func animateReactionSelection(context: AccountContext, theme: PresentationTheme, animationCache: AnimationCache, reaction: ReactionItem, customEffectResource: MediaResource? = nil, avatarPeers: [EnginePeer], playHaptic: Bool, isLarge: Bool, playCenterReaction: Bool = true, forceSmallEffectAnimation: Bool = false, hideCenterAnimation: Bool = false, targetView: UIView, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, onHit: (() -> Void)? = nil, completion: @escaping () -> Void) {
        self.animateReactionSelection(context: context, theme: theme, animationCache: animationCache, reaction: reaction, customEffectResource: customEffectResource, avatarPeers: avatarPeers, playHaptic: playHaptic, isLarge: isLarge, playCenterReaction: playCenterReaction, forceSmallEffectAnimation: forceSmallEffectAnimation, hideCenterAnimation: hideCenterAnimation, targetView: targetView, addStandaloneReactionAnimation: addStandaloneReactionAnimation, currentItemNode: nil, onHit: onHit, completion: completion)
    }
        
    public var currentDismissAnimation: (() -> Void)?
    
    public func animateReactionSelection(context: AccountContext, theme: PresentationTheme, animationCache: AnimationCache, reaction: ReactionItem, customEffectResource: MediaResource? = nil, avatarPeers: [EnginePeer], playHaptic: Bool, isLarge: Bool, playCenterReaction: Bool = true, forceSmallEffectAnimation: Bool = false, hideCenterAnimation: Bool = false, targetView: UIView, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, currentItemNode: ReactionNode?, onHit: (() -> Void)? = nil, completion: @escaping () -> Void) {
        guard let sourceSnapshotView = targetView.snapshotContentTree() else {
            completion()
            return
        }
        
        if playHaptic {
            self.hapticFeedback.tap()
        }
        onHit?()
        
        self.targetView = targetView
        
        let itemNode: ReactionNode?
        if playCenterReaction {
            if let currentItemNode = currentItemNode {
                itemNode = currentItemNode
            } else {
                let animationRenderer = MultiAnimationRendererImpl()
                itemNode = ReactionNode(context: context, theme: theme, item: reaction, icon: .none, animationCache: animationCache, animationRenderer: animationRenderer, loopIdle: false, isLocked: false)
            }
            self.itemNode = itemNode
        } else {
            itemNode = nil
        }
        
        let switchToInlineImmediately: Bool
        var playAnimationInline = false
        if let itemNode {
            if itemNode.item.listAnimation.isVideoEmoji || itemNode.item.listAnimation.isVideoSticker || itemNode.item.listAnimation.isAnimatedSticker || itemNode.item.listAnimation.isStaticEmoji {
                switch itemNode.item.reaction.rawValue {
                case .builtin:
                    switchToInlineImmediately = false
                case .custom:
                    switchToInlineImmediately = true
                case .stars:
                    switchToInlineImmediately = true
                    playAnimationInline = true
                }
            } else {
                switchToInlineImmediately = false
            }
        } else {
            switchToInlineImmediately = false
        }
        let _ = playAnimationInline
        
        if let itemNode, !forceSmallEffectAnimation, !switchToInlineImmediately, !hideCenterAnimation {
            if let targetView = targetView as? ReactionIconView, !isLarge {
                self.itemNodeIsEmbedded = true
                targetView.addSubnode(itemNode)
            } else {
                self.addSubnode(itemNode)
            }
        }
        
        if let itemNode {
            itemNode.expandedAnimationDidBegin = { [weak self, weak targetView] in
                guard let strongSelf = self, let targetView = targetView else {
                    return
                }
                if let targetView = targetView as? ReactionIconView, !isLarge {
                    strongSelf.itemNodeIsEmbedded = true
                    
                    targetView.updateIsAnimationHidden(isAnimationHidden: true, transition: .immediate)
                } else {
                    targetView.isHidden = true
                }
            }
            
            itemNode.isExtracted = true
        }
        
        var selfTargetBounds = targetView.bounds
        if let targetView = targetView as? ReactionIconView, let iconFrame = targetView.iconFrame {
            selfTargetBounds = iconFrame
        }
        
        let selfTargetRect = self.view.convert(selfTargetBounds, from: targetView)
        
        var expandedSize: CGSize = selfTargetRect.size
        if isLarge {
            expandedSize = CGSize(width: 120.0, height: 120.0)
        } else if case .stars = reaction.reaction.rawValue {
            expandedSize = CGSize(width: 120.0, height: 120.0)
        }
        
        let expandedFrame = CGRect(origin: CGPoint(x: selfTargetRect.midX - expandedSize.width / 2.0, y: selfTargetRect.midY - expandedSize.height / 2.0), size: expandedSize)
        
        let effectFrame: CGRect
        let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
        if isLarge && !forceSmallEffectAnimation {
            effectFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5).offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
        } else if case .stars = reaction.reaction.rawValue {
            effectFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5)
        } else {
            effectFrame = expandedFrame.insetBy(dx: -expandedSize.width, dy: -expandedSize.height)
        }
        
        if !self.itemNodeIsEmbedded {
            sourceSnapshotView.frame = selfTargetRect
            self.view.addSubview(sourceSnapshotView)
            sourceSnapshotView.alpha = 0.0
            sourceSnapshotView.layer.animateSpring(from: 1.0 as NSNumber, to: (expandedFrame.width / selfTargetRect.width) as NSNumber, keyPath: "transform.scale", duration: 0.7)
            sourceSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.01, completion: { [weak sourceSnapshotView] _ in
                sourceSnapshotView?.removeFromSuperview()
            })
        }
        
        if let itemNode {
            if self.itemNodeIsEmbedded {
                itemNode.frame = selfTargetBounds
            } else {
                itemNode.frame = expandedFrame
                
                itemNode.layer.animateSpring(from: (selfTargetRect.width / expandedFrame.width) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.7)
            }
            
            itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, largeExpanded: isLarge, isPreviewing: false, transition: .immediate)
        }
        
        var additionalAnimationResource: MediaResource?
        if isLarge && !forceSmallEffectAnimation {
            additionalAnimationResource = reaction.largeApplicationAnimation?._parse().resource
        } else if case .stars = reaction.reaction.rawValue {
            additionalAnimationResource = reaction.largeApplicationAnimation?._parse().resource ?? reaction.applicationAnimation?._parse().resource
        } else {
            additionalAnimationResource = reaction.applicationAnimation?._parse().resource
        }
        if additionalAnimationResource == nil, let customEffectResource {
            additionalAnimationResource = customEffectResource
        }
        
        let additionalAnimationNode: AnimatedStickerNode?
        var genericAnimationView: AnimationView?
        
        if let additionalAnimationResource {
            let additionalAnimationNodeValue: AnimatedStickerNode
            if self.useDirectRendering {
                additionalAnimationNodeValue = DirectAnimatedStickerNode()
            } else {
                additionalAnimationNodeValue = DefaultAnimatedStickerNodeImpl()
            }
            additionalAnimationNode = additionalAnimationNodeValue
            
            if isLarge && !forceSmallEffectAnimation {
                if incomingMessage {
                    additionalAnimationNodeValue.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
            }
            
            let additionalCachePathPrefix: String? = nil
            
            additionalAnimationNodeValue.setup(source: AnimatedStickerResourceSource(account: context.account, resource: additionalAnimationResource), width: Int(effectFrame.width * 1.33), height: Int(effectFrame.height * 1.33), playbackMode: .once, mode: .direct(cachePathPrefix: additionalCachePathPrefix))
            additionalAnimationNodeValue.frame = effectFrame
            additionalAnimationNodeValue.updateLayout(size: effectFrame.size)
            self.addSubnode(additionalAnimationNodeValue)
        } else if reaction.isCustom {
            var effectURL: URL?
            if let genericReactionEffect = self.genericReactionEffect {
                effectURL = URL(fileURLWithPath: genericReactionEffect)
            } else {
                if let url = getAppBundle().url(forResource: "generic_reaction_small_effect", withExtension: "json") {
                    effectURL = url
                }
            }
            
            if let effectURL {
                let additionalAnimationNodeValue: AnimatedStickerNode
                if self.useDirectRendering {
                    additionalAnimationNodeValue = DirectAnimatedStickerNode()
                } else {
                    additionalAnimationNodeValue = DefaultAnimatedStickerNodeImpl()
                }
                additionalAnimationNode = additionalAnimationNodeValue
                
                if isLarge && !forceSmallEffectAnimation {
                    if incomingMessage {
                        additionalAnimationNodeValue.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    }
                }
                
                additionalAnimationNodeValue.setup(source: AnimatedStickerNodeLocalFileSource(name: effectURL.path), width: Int(effectFrame.width * 1.33), height: Int(effectFrame.height * 1.33), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                additionalAnimationNodeValue.frame = effectFrame
                additionalAnimationNodeValue.updateLayout(size: effectFrame.size)
                self.addSubnode(additionalAnimationNodeValue)
            } else {
                additionalAnimationNode = nil
            }
                
            var patternEffectData: Data?
            if let url = getAppBundle().url(forResource: "generic_reaction_inline_pattern", withExtension: "json") {
                patternEffectData = try? Data(contentsOf: url)
            }
            
            if let patternEffectData, let composition = try? Animation.from(data: patternEffectData) {
                let view = AnimationView(animation: composition, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
                view.animationSpeed = 1.0
                view.backgroundColor = nil
                view.isOpaque = false
                
                if incomingMessage {
                    view.layer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
                
                genericAnimationView = view
                
                let animationCache = context.animationCache
                let animationRenderer = context.animationRenderer
                
                for i in 1 ... 7 {
                    let allLayers = view.allLayers(forKeypath: AnimationKeypath(keypath: "placeholder_\(i)"))
                    for animationLayer in allLayers {
                        let itemListAnimationFile = reaction.listAnimation._parse()
                        let baseItemLayer = InlineStickerItemLayer(
                            context: context,
                            userLocation: .other,
                            attemptSynchronousLoad: false,
                            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: reaction.listAnimation.fileId.id, file: itemListAnimationFile),
                            file: itemListAnimationFile,
                            cache: animationCache,
                            renderer: animationRenderer,
                            placeholderColor: UIColor(white: 0.0, alpha: 0.0),
                            pointSize: CGSize(width: 32.0, height: 32.0)
                        )
                        
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
                
                view.frame = effectFrame.insetBy(dx: -20.0, dy: -20.0)//.offsetBy(dx: incomingMessage ? 22.0 : -22.0, dy: 0.0)
                self.view.addSubview(view)
            }
        } else {
            additionalAnimationNode = nil
        }
        
        if let additionalAnimationNode = additionalAnimationNode, !isLarge, !avatarPeers.isEmpty, let url = getAppBundle().url(forResource: "effectavatar", withExtension: "json"), let composition = Animation.filepath(url.path) {
            let view = AnimationView(animation: composition, configuration: LottieConfiguration(renderingEngine: .mainThread, decodingStrategy: .codable))
            view.animationSpeed = 1.0
            view.backgroundColor = nil
            view.isOpaque = false
            
            var avatarIndex = 0
            
            let keypathIndices: [Int] = Array((1 ... 3).map({ $0 }).shuffled())
            for i in keypathIndices {
                var peer: EnginePeer?
                if avatarIndex < avatarPeers.count {
                    peer = avatarPeers[avatarIndex]
                }
                avatarIndex += 1
                
                if let peer = peer {
                    let avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
                    
                    let avatarContainer = UIView(frame: CGRect(origin: CGPoint(x: -100.0, y: -100.0), size: CGSize(width: 200.0, height: 200.0)))
                    
                    avatarNode.frame = CGRect(origin: CGPoint(x: floor((200.0 - 40.0) / 2.0), y: floor((200.0 - 40.0) / 2.0)), size: CGSize(width: 40.0, height: 40.0))
                    avatarNode.setPeer(context: context, theme: context.sharedContext.currentPresentationData.with({ $0 }).theme, peer: peer)
                    avatarNode.transform = CATransform3DMakeScale(200.0 / 40.0, 200.0 / 40.0, 1.0)
                    avatarContainer.addSubnode(avatarNode)
                    
                    let animationSubview = AnimationSubview()
                    animationSubview.addSubview(avatarContainer)
                    
                    view.addSubview(animationSubview, forLayerAt: AnimationKeypath(keypath: "Avatar \(i).Ellipse 1"))
                }
                
                view.setValueProvider(ColorValueProvider(UIColor.clear.lottieColorValue), keypath: AnimationKeypath(keypath: "Avatar \(i).Ellipse 1.Fill 1.Color"))
                /*let colorCallback = LOTColorValueCallback(color: UIColor.clear.cgColor)
                self.colorCallbacks.append(colorCallback)
                view.setValueDelegate(colorCallback, for: LOTKeypath(string: "Avatar \(i).Ellipse 1.Fill 1.Color"))*/
            }
            
            view.frame = additionalAnimationNode.bounds
            additionalAnimationNode.view.addSubview(view)
            view.play()
        }
        
        var mainAnimationCompleted = false
        var additionalAnimationCompleted = false
        let intermediateCompletion: () -> Void = {
            if mainAnimationCompleted && additionalAnimationCompleted {
                completion()
            }
        }
                
        var didBeginDismissAnimation = false
        let beginDismissAnimation: () -> Void = { [weak self, weak additionalAnimationNode] in
            if !didBeginDismissAnimation {
                didBeginDismissAnimation = true
            
                guard let strongSelf = self else {
                    mainAnimationCompleted = true
                    intermediateCompletion()
                    return
                }
                
                if forceSmallEffectAnimation {
                    if let additionalAnimationNode = additionalAnimationNode {
                        additionalAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak additionalAnimationNode] _ in
                            additionalAnimationNode?.removeFromSupernode()
                        })
                    }
                    
                    mainAnimationCompleted = true
                    intermediateCompletion()
                } else {
                    if isLarge, let itemNode {
                        let genericReactionEffect = strongSelf.genericReactionEffect
                        strongSelf.animateFromItemNodeToReaction(itemNode: itemNode, targetView: targetView, hideNode: true, completion: {
                            if let addStandaloneReactionAnimation = addStandaloneReactionAnimation {
                                let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: genericReactionEffect)
                                
                                addStandaloneReactionAnimation(standaloneReactionAnimation)
                                
                                standaloneReactionAnimation.animateReactionSelection(
                                    context: context,
                                    theme: context.sharedContext.currentPresentationData.with({ $0 }).theme,
                                    animationCache: animationCache,
                                    reaction: reaction,
                                    avatarPeers: avatarPeers,
                                    playHaptic: false,
                                    isLarge: false,
                                    targetView: targetView,
                                    addStandaloneReactionAnimation: nil,
                                    completion: { [weak standaloneReactionAnimation] in
                                        standaloneReactionAnimation?.removeFromSupernode()
                                    }
                                )
                            }
                            
                            mainAnimationCompleted = true
                            intermediateCompletion()
                        })
                    } else {
                        if let targetView = strongSelf.targetView {
                            if let targetView = targetView as? ReactionIconView, !isLarge {
                                targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                            } else {
                                targetView.alpha = 1.0
                                targetView.isHidden = false
                            }
                        }
                        
                        if strongSelf.itemNodeIsEmbedded {
                            strongSelf.itemNode?.removeFromSupernode()
                        }
                        
                        mainAnimationCompleted = true
                        intermediateCompletion()
                    }
                }
            }
        }
        self.currentDismissAnimation = beginDismissAnimation
        
        let maybeBeginDismissAnimation: () -> Void = {
            if mainAnimationCompleted && additionalAnimationCompleted {
                beginDismissAnimation()
            }
        }
        
        if forceSmallEffectAnimation {
            mainAnimationCompleted = true
            maybeBeginDismissAnimation()
        }
                
        if let additionalAnimationNode = additionalAnimationNode {
            additionalAnimationNode.completed = { [weak additionalAnimationNode] _ in
                additionalAnimationNode?.alpha = 0.0
                additionalAnimationNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                additionalAnimationCompleted = true
                intermediateCompletion()
                if forceSmallEffectAnimation {
                    maybeBeginDismissAnimation()
                } else {
                    beginDismissAnimation()
                }
            }
            
            if let genericAnimationView = genericAnimationView {
                genericAnimationView.play(completion: { [weak genericAnimationView] _ in
                    genericAnimationView?.alpha = 0.0
                    genericAnimationView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                })
            }
            
            additionalAnimationNode.visibility = true
        } else if let genericAnimationView = genericAnimationView {
            genericAnimationView.play(completion: { _ in
                additionalAnimationNode?.alpha = 0.0
                additionalAnimationNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                additionalAnimationCompleted = true
                intermediateCompletion()
                if forceSmallEffectAnimation {
                    maybeBeginDismissAnimation()
                } else {
                    beginDismissAnimation()
                }
            })
        } else {
            additionalAnimationCompleted = true
        }
        
        if !forceSmallEffectAnimation {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: {
                beginDismissAnimation()
            })
        }
    }
    
    private func animateFromItemNodeToReaction(itemNode: ReactionNode, targetView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        guard let targetSnapshotView = targetView.snapshotContentTree(unhide: true) else {
            completion()
            return
        }
        
        let sourceFrame = itemNode.view.convert(itemNode.bounds, to: self.view)
        
        var selfTargetBounds = targetView.bounds
        if let itemNode = self.itemNode, case .builtin = itemNode.item.reaction.rawValue {
            selfTargetBounds = selfTargetBounds.insetBy(dx: -selfTargetBounds.width * 0.5, dy: -selfTargetBounds.height * 0.5)
        } else if let itemNode = self.itemNode, case .stars = itemNode.item.reaction.rawValue {
            selfTargetBounds = selfTargetBounds.insetBy(dx: -selfTargetBounds.width * 0.0, dy: -selfTargetBounds.height * 0.0)
        }
        
        var targetFrame = self.view.convert(targetView.convert(selfTargetBounds, to: nil), from: nil)
        
        if let itemNode = self.itemNode, case .builtin = itemNode.item.reaction.rawValue {
            targetFrame = targetFrame.insetBy(dx: -targetFrame.width * 0.5, dy: -targetFrame.height * 0.5)
        } else if let itemNode = self.itemNode, case .stars = itemNode.item.reaction.rawValue {
            targetFrame = targetFrame.insetBy(dx: -targetFrame.width * 0.0, dy: -targetFrame.height * 0.0)
        }
        
        targetSnapshotView.frame = targetFrame
        self.view.insertSubview(targetSnapshotView, belowSubview: itemNode.view)
        
        var completedTarget = false
        var targetScaleCompleted = false
        let intermediateCompletion: () -> Void = {
            if completedTarget && targetScaleCompleted {
                completion()
            }
        }
        
        let targetPosition = targetFrame.center
        let duration: Double = 0.16
        
        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.9, removeOnCompletion: false)
        itemNode.layer.animatePosition(from: itemNode.layer.position, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.alpha = 1.0
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animatePosition(from: sourceFrame.center, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 1.0, duration: duration, removeOnCompletion: false, completion: { [weak targetSnapshotView] _ in
            completedTarget = true
            intermediateCompletion()
            
            targetSnapshotView?.isHidden = true
            
            if hideNode {
                targetView.alpha = 1.0
                targetView.isHidden = false
                if let targetView = targetView as? ReactionIconView {
                    targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                }
                targetSnapshotView?.isHidden = true
                targetScaleCompleted = true
                intermediateCompletion()
            } else {
                targetScaleCompleted = true
                intermediateCompletion()
            }
        })
        
        itemNode.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 1.0) / itemNode.bounds.width, duration: duration, removeOnCompletion: false)
    }
    
    public func animateOutToReaction(context: AccountContext, theme: PresentationTheme, item: ReactionItem, value: MessageReaction.Reaction, sourceView: UIView, targetView: UIView, hideNode: Bool, forceSwitchToInlineImmediately: Bool = false, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, onHit: (() -> Void)?, completion: @escaping () -> Void) {
        let star = ComponentView<Empty>()
        let starSize = star.update(
            transition: .immediate,
            component: AnyComponent(StandalonePremiumStarComponent(
                theme: theme,
                colors: [
                    UIColor(rgb: 0xe57d02),
                    UIColor(rgb: 0xf09903),
                    UIColor(rgb: 0xf9b004),
                    UIColor(rgb: 0xfdd219)
                ]
            )),
            environment: {},
            containerSize: CGSize(width: 240.0, height: 240.0)
        )
        guard let starView = star.view else {
            return
        }
        
        guard let sourceCloneView = sourceView.snapshotContentTree() else {
            return
        }
        
        self.view.addSubview(sourceCloneView)
        self.view.addSubview(starView)
        
        sourceCloneView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, removeOnCompletion: false)
        starView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
        
        let didTriggerExpandedReaction = "".isEmpty
        
        let sourceFrame = sourceView.convert(sourceView.bounds, to: self.view)
        starView.bounds = CGRect(origin: CGPoint(), size: starSize)
        
        sourceView.layer.isHidden = true
        
        let switchToInlineImmediately: Bool = "".isEmpty
        
        if hideNode {
            if let animateTargetContainer = animateTargetContainer {
                animateTargetContainer.isHidden = true
                targetView.isHidden = true
            } else {
                targetView.alpha = 0.0
                targetView.layer.animateAlpha(from: targetView.alpha, to: 0.0, duration: 0.2)
            }
        }
        if let targetView = targetView as? ReactionIconView {
            targetView.updateIsAnimationHidden(isAnimationHidden: true, transition: .immediate)
        }
        
        let selfSourceRect = sourceFrame
        
        var selfTargetBounds = targetView.bounds
        selfTargetBounds = selfTargetBounds.insetBy(dx: -selfTargetBounds.width * 0.5, dy: -selfTargetBounds.height * 0.5)
        
        let selfTargetRect = self.view.convert(selfTargetBounds, from: targetView)
        
        var expandedSize: CGSize = selfTargetRect.size
        if didTriggerExpandedReaction {
            expandedSize = CGSize(width: 120.0, height: 120.0)
        }
        
        let expandedFrame = CGRect(origin: CGPoint(x: selfTargetRect.midX - expandedSize.width / 2.0, y: selfTargetRect.midY - expandedSize.height / 2.0), size: expandedSize)
        
        var effectFrame: CGRect
        let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
        if didTriggerExpandedReaction {
            let expandFactor: CGFloat = 0.5
            effectFrame = expandedFrame.insetBy(dx: -expandedFrame.width * expandFactor, dy: -expandedFrame.height * expandFactor)//.offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
        } else {
            effectFrame = expandedFrame.insetBy(dx: -expandedSize.width, dy: -expandedSize.height)
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .linear)
        
        starView.center = expandedFrame.center
        sourceCloneView.frame = sourceFrame
        
        let additionalAnimationNode: DefaultAnimatedStickerNodeImpl?
        var genericAnimationView: AnimationView?
        
        var additionalAnimation: TelegramMediaFile?
        if didTriggerExpandedReaction {
            additionalAnimation = item.largeApplicationAnimation?._parse()
        } else {
            additionalAnimation = item.applicationAnimation?._parse()
        }
        
        if let additionalAnimation = additionalAnimation {
            let additionalAnimationNodeValue = DefaultAnimatedStickerNodeImpl()
            additionalAnimationNode = additionalAnimationNodeValue
            if didTriggerExpandedReaction {
                if incomingMessage {
                    additionalAnimationNodeValue.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
            }
            
            additionalAnimationNodeValue.setup(source: AnimatedStickerResourceSource(account: context.account, resource: additionalAnimation.resource), width: Int(effectFrame.width * 2.0), height: Int(effectFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(additionalAnimation.resource.id)))
            additionalAnimationNodeValue.frame = effectFrame
            additionalAnimationNodeValue.updateLayout(size: effectFrame.size)
            self.addSubnode(additionalAnimationNodeValue)
        } else if item.isCustom {
            additionalAnimationNode = nil
            
            var effectData: Data?
            if didTriggerExpandedReaction {
                if let url = getAppBundle().url(forResource: "generic_reaction_effect", withExtension: "json") {
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
                
                if incomingMessage {
                    view.layer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                }
                
                genericAnimationView = view
                
                if didTriggerExpandedReaction {
                    view.frame = effectFrame.insetBy(dx: -10.0, dy: -10.0).offsetBy(dx: incomingMessage ? 22.0 : -22.0, dy: 0.0)
                } else {
                    view.frame = effectFrame.insetBy(dx: -20.0, dy: -20.0)
                }
                self.view.addSubview(view)
            }
        } else {
            additionalAnimationNode = nil
        }
        
        var mainAnimationCompleted = false
        var additionalAnimationCompleted = false
        let intermediateCompletion: () -> Void = {
            if mainAnimationCompleted && additionalAnimationCompleted {
                completion()
            }
        }
        
        if let additionalAnimationNode = additionalAnimationNode {
            additionalAnimationNode.completed = { _ in
                additionalAnimationCompleted = true
                intermediateCompletion()
            }
        } else if let genericAnimationView = genericAnimationView {
            genericAnimationView.play(completion: { _ in
                additionalAnimationCompleted = true
                intermediateCompletion()
            })
        } else {
            additionalAnimationCompleted = true
        }
        
        starView.center = selfTargetRect.center
        sourceCloneView.center = selfTargetRect.center
        
        let starSourceScale = sourceFrame.width / starSize.width
        let starDestinationScale = selfTargetRect.width / starSize.width
        
        let elevation: CGFloat = min(selfSourceRect.center.y, expandedFrame.center.y) - selfSourceRect.center.y - 40.0
        let keyframes = generateParabollicMotionKeyframes(from: selfSourceRect.center, to: expandedFrame.center, elevation: -elevation)
        let scaleKeyframes = generateScaleKeyframes(from: starSourceScale, center: 1.0, to: starDestinationScale)
        starView.layer.transform = CATransform3DMakeScale(starDestinationScale, starDestinationScale, 1.0)
        transition.animateScaleWithKeyframes(layer: starView.layer, keyframes: scaleKeyframes)
        transition.animatePositionWithKeyframes(layer: starView.layer, keyframes: keyframes, completion: { [weak starView, weak targetView, weak animateTargetContainer] _ in
            let afterCompletion: () -> Void = {
                guard let starView else {
                    return
                }
                if let animateTargetContainer = animateTargetContainer {
                    animateTargetContainer.isHidden = false
                }
                
                if let targetView = targetView {
                    targetView.isHidden = false
                    targetView.alpha = 1.0
                    targetView.layer.removeAnimation(forKey: "opacity")
                }
                
                HapticFeedback().tap()
                
                if let targetView = targetView as? ReactionIconView {
                    if switchToInlineImmediately {
                        targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                        starView.isHidden = true
                    } else {
                        targetView.updateIsAnimationHidden(isAnimationHidden: true, transition: .immediate)
                    }
                } else if let targetView = targetView as? UIImageView {
                    starView.isHidden = true
                    targetView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    targetView.layer.animateScale(from: 0.2, to: 1.0, duration: 0.12)
                }
                
                if switchToInlineImmediately {
                    mainAnimationCompleted = true
                    intermediateCompletion()
                }
            }
            
            onHit?()
            
            if switchToInlineImmediately {
                afterCompletion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: afterCompletion)
            }
        })
        transition.animatePositionWithKeyframes(layer: sourceCloneView.layer, keyframes: keyframes)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3 * UIView.animationDurationFactor(), execute: {
            additionalAnimationNode?.visibility = true
            if let animateTargetContainer = animateTargetContainer {
                animateTargetContainer.isHidden = false
                animateTargetContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                animateTargetContainer.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
        })
        
        if !switchToInlineImmediately {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + min(5.0, 2.0 * UIView.animationDurationFactor()), execute: {
                if hideNode {
                    targetView.alpha = 1.0
                    targetView.isHidden = false
                    if let targetView = targetView as? ReactionIconView {
                        targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
                    }
                }
                mainAnimationCompleted = true
                intermediateCompletion()
            })
        }
    }
    
    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: offset.y)
        transition.animateOffsetAdditive(node: self, offset: -offset.y)
    }
    
    public func cancel() {
        self.isCancelled = true
        
        if let targetView = self.targetView {
            if let targetView = targetView as? ReactionIconView, self.itemNodeIsEmbedded {
                targetView.updateIsAnimationHidden(isAnimationHidden: false, transition: .immediate)
            } else {
                targetView.alpha = 1.0
                targetView.isHidden = false
            }
        }
        
        if self.itemNodeIsEmbedded {
            self.itemNode?.removeFromSupernode()
        }
    }
}

public final class StandaloneDismissReactionAnimation: ASDisplayNode {
    private let hapticFeedback = HapticFeedback()
    
    override public init() {
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    public func animateReactionDismiss(sourceView: UIView, hideNode: Bool, isIncoming: Bool, completion: @escaping () -> Void) {
        guard let sourceSnapshotView = sourceView.snapshotContentTree() else {
            completion()
            return
        }
        if hideNode {
            sourceView.isHidden = true
        }
        
        let sourceRect = self.view.convert(sourceView.bounds, from: sourceView)
        sourceSnapshotView.frame = sourceRect
        self.view.addSubview(sourceSnapshotView)
        
        var targetOffset: CGFloat = 120.0
        if !isIncoming {
            targetOffset = -targetOffset
        }
        let targetPoint = CGPoint(x: sourceRect.midX + targetOffset, y: sourceRect.midY)
        
        let hapticFeedback = self.hapticFeedback
        hapticFeedback.prepareImpact(.soft)
        
        let keyframes = generateParabollicMotionKeyframes(from: sourceRect.center, to: targetPoint, elevation: 25.0)
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .easeInOut)
        sourceSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.04, delay: 0.18 - 0.04, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak sourceSnapshotView, weak hapticFeedback] _ in
            sourceSnapshotView?.removeFromSuperview()
            hapticFeedback?.impact(.soft)
            completion()
        })
        transition.animatePositionWithKeyframes(layer: sourceSnapshotView.layer, keyframes: keyframes, removeOnCompletion: false)
    }
    
    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: offset.y)
        transition.animateOffsetAdditive(node: self, offset: -offset.y)
    }
}

private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
    
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

private func generateScaleKeyframes(from: CGFloat, center: CGFloat, to: CGFloat) -> [CGFloat] {
    var keyframes: [CGFloat] = []
    for i in 0 ..< 10 {
        var k = CGFloat(i) / CGFloat(10 - 1)
        let valueFrom: CGFloat
        let valueTo: CGFloat
        if k <= 0.5 {
            k /= 0.5
            valueFrom = from
            valueTo = center
        } else {
            k = (k - 0.5) / 0.5
            valueFrom = center
            valueTo = to
        }
        let value = valueFrom * (1.0 - k) + valueTo * k
        keyframes.append(value)
    }
    return keyframes
}
