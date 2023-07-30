import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import StoryContainerScreen
import EmojiStatusComponent
import ChatListTitleView

public final class StoryPeerListComponent: Component {
    public enum PeerStatus: Equatable {
        case premium
        case emoji(PeerEmojiStatus)
    }
    
    public final class ExternalState {
        public fileprivate(set) var collapsedWidth: CGFloat = 0.0
        
        public init() {
        }
    }
    
    public final class AnimationHint {
        let duration: Double?
        let allowAvatarsExpansionUpdated: Bool
        let bounce: Bool
        let disableAnimations: Bool
        
        public init(duration: Double?, allowAvatarsExpansionUpdated: Bool, bounce: Bool, disableAnimations: Bool) {
            self.duration = duration
            self.allowAvatarsExpansionUpdated = allowAvatarsExpansionUpdated
            self.bounce = bounce
            self.disableAnimations = disableAnimations
        }
    }
    
    public let externalState: ExternalState
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let sideInset: CGFloat
    public let title: String
    public let titleHasLock: Bool
    public let titleHasActivity: Bool
    public let titlePeerStatus: PeerStatus?
    public let minTitleX: CGFloat
    public let maxTitleX: CGFloat
    public let useHiddenList: Bool
    public let storySubscriptions: EngineStorySubscriptions?
    public let collapseFraction: CGFloat
    public let unlocked: Bool
    public let uploadProgress: Float?
    public let peerAction: (EnginePeer?) -> Void
    public let contextPeerAction: (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void
    public let openStatusSetup: (UIView) -> Void
    public let lockAction: () -> Void
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sideInset: CGFloat,
        title: String,
        titleHasLock: Bool,
        titleHasActivity: Bool,
        titlePeerStatus: PeerStatus?,
        minTitleX: CGFloat,
        maxTitleX: CGFloat,
        useHiddenList: Bool,
        storySubscriptions: EngineStorySubscriptions?,
        collapseFraction: CGFloat,
        unlocked: Bool,
        uploadProgress: Float?,
        peerAction: @escaping (EnginePeer?) -> Void,
        contextPeerAction: @escaping (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void,
        openStatusSetup: @escaping (UIView) -> Void,
        lockAction: @escaping () -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sideInset = sideInset
        self.title = title
        self.titleHasLock = titleHasLock
        self.titleHasActivity = titleHasActivity
        self.titlePeerStatus = titlePeerStatus
        self.minTitleX = minTitleX
        self.maxTitleX = maxTitleX
        self.useHiddenList = useHiddenList
        self.storySubscriptions = storySubscriptions
        self.collapseFraction = collapseFraction
        self.unlocked = unlocked
        self.uploadProgress = uploadProgress
        self.peerAction = peerAction
        self.contextPeerAction = contextPeerAction
        self.openStatusSetup = openStatusSetup
        self.lockAction = lockAction
    }
    
    public static func ==(lhs: StoryPeerListComponent, rhs: StoryPeerListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleHasLock != rhs.titleHasLock {
            return false
        }
        if lhs.titleHasActivity != rhs.titleHasActivity {
            return false
        }
        if lhs.titlePeerStatus != rhs.titlePeerStatus {
            return false
        }
        if lhs.minTitleX != rhs.minTitleX {
            return false
        }
        if lhs.maxTitleX != rhs.maxTitleX {
            return false
        }
        if lhs.useHiddenList != rhs.useHiddenList {
            return false
        }
        if lhs.storySubscriptions != rhs.storySubscriptions {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
            return false
        }
        if lhs.unlocked != rhs.unlocked {
            return false
        }
        if lhs.uploadProgress != rhs.uploadProgress {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private final class VisibleItem {
        let view = ComponentView<Empty>()
        var hasBlur: Bool = false
        
        init() {
        }
    }
    
    private struct ItemLayout {
        let containerSize: CGSize
        let containerInsets: UIEdgeInsets
        let itemSize: CGSize
        let itemSpacing: CGFloat
        let itemCount: Int
        
        let contentSize: CGSize
        
        init(
            containerSize: CGSize,
            containerInsets: UIEdgeInsets,
            itemSize: CGSize,
            itemSpacing: CGFloat,
            itemCount: Int
        ) {
            self.containerSize = containerSize
            self.containerInsets = containerInsets
            self.itemSize = itemSize
            self.itemSpacing = itemSpacing
            self.itemCount = itemCount
            
            self.contentSize = CGSize(width: containerInsets.left + containerInsets.right + CGFloat(itemCount) * itemSize.width + CGFloat(max(0, itemCount - 1)) * itemSpacing, height: containerSize.height)
        }
        
        func frame(at index: Int) -> CGRect {
            if self.itemCount <= 1 {
                return CGRect(origin: CGPoint(x: self.containerInsets.left + floor((self.containerSize.width - self.containerInsets.left - containerInsets.right - self.itemSize.width) * 0.5), y: self.containerInsets.top), size: self.itemSize)
            } else if self.contentSize.width < self.containerSize.width {
                let usableWidth = self.containerSize.width - self.containerInsets.left - self.containerInsets.right
                let usableSpacingWidth = usableWidth - self.itemSize.width * CGFloat(self.itemCount)
                
                var spacing = floor(usableSpacingWidth / CGFloat(self.itemCount + 1))
                spacing = min(100.0, spacing)
                
                let contentWidth = self.itemSize.width * CGFloat(self.itemCount) + spacing * CGFloat(max(0, self.itemCount - 1))
                
                return CGRect(origin: CGPoint(x: floor((self.containerSize.width - contentWidth) * 0.5) + (self.itemSize.width + spacing) * CGFloat(index), y: self.containerInsets.top), size: self.itemSize)
            } else {
                return CGRect(origin: CGPoint(x: self.containerInsets.left + (self.itemSize.width + self.itemSpacing) * CGFloat(index), y: self.containerInsets.top), size: self.itemSize)
            }
        }
    }
    
    private final class TitleAnimationState {
        let duration: Double
        let startTime: Double
        let fromFraction: CGFloat
        let toFraction: CGFloat
        let imageView: UIImageView
        
        init(
            duration: Double,
            startTime: Double,
            fromFraction: CGFloat,
            toFraction: CGFloat,
            imageView: UIImageView
        ) {
            self.duration = duration
            self.startTime = startTime
            self.fromFraction = fromFraction
            self.toFraction = toFraction
            self.imageView = imageView
        }
        
        func interpolatedFraction(at timestamp: Double, effectiveFromFraction: CGFloat, toFraction: CGFloat) -> CGFloat {
            var rawProgress = CGFloat((timestamp - self.startTime) / self.duration)
            rawProgress = max(0.0, min(1.0, rawProgress))
            let progress = listViewAnimationCurveSystem(rawProgress)
            
            return effectiveFromFraction * (1.0 - progress) + toFraction * progress
        }
        
        func isFinished(at timestamp: Double) -> Bool {
            if timestamp > self.startTime + self.duration {
                return true
            } else {
                return false
            }
        }
    }
    
    private final class AnimationState {
        let duration: Double
        let fromIsUnlocked: Bool
        let fromFraction: CGFloat
        let fromTitleWidth: CGFloat
        let fromActivityFraction: CGFloat
        let startTime: Double
        let bounce: Bool
        
        init(
            duration: Double,
            fromIsUnlocked: Bool,
            fromFraction: CGFloat,
            fromTitleWidth: CGFloat,
            fromActivityFraction: CGFloat,
            startTime: Double,
            bounce: Bool
        ) {
            self.duration = duration
            self.fromIsUnlocked = fromIsUnlocked
            self.fromFraction = fromFraction
            self.fromTitleWidth = fromTitleWidth
            self.fromActivityFraction = fromActivityFraction
            self.startTime = startTime
            self.bounce = bounce
        }
        
        func interpolatedFraction(at timestamp: Double, effectiveFromFraction: CGFloat, toFraction: CGFloat, linear: Bool = false) -> CGFloat {
            var rawProgress = CGFloat((timestamp - self.startTime) / self.duration)
            rawProgress = max(0.0, min(1.0, rawProgress))
            let progress: CGFloat
            if linear {
                progress = rawProgress
            } else {
                progress = listViewAnimationCurveSystem(rawProgress)
            }
            
            return effectiveFromFraction * (1.0 - progress) + toFraction * progress
        }
        
        func isFinished(at timestamp: Double) -> Bool {
            if timestamp > self.startTime + self.duration {
                return true
            } else {
                return false
            }
        }
    }
    
    private struct TitleState: Equatable {
        var text: String
        var color: UIColor
        
        init(text: String, color: UIColor) {
            self.text = text
            self.color = color
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate {
        private let collapsedButton: HighlightableButton
        private let scrollView: ScrollView
        private let scrollContainerView: UIView
        
        private var ignoreScrolling: Bool = false
        private var itemLayout: ItemLayout?
        
        private var sortedItems: [EngineStorySubscriptions.Item] = []
        
        private var visibleItems: [EnginePeer.Id: VisibleItem] = [:]
        private var visibleCollapsableItems: [EnginePeer.Id: VisibleItem] = [:]
        
        private var titleIndicatorView: ComponentView<Empty>?
        
        private var titleLockView: ChatListTitleLockView?
        private var titleLockButton: HighlightTrackingButton?
        private let titleView: UIImageView
        private var titleState: TitleState?
        private var titleViewAnimation: TitleAnimationState?
        
        private var disappearingTitleViews: [TitleAnimationState] = []
        
        private var titleIconView: ComponentView<Empty>?
        
        private var component: StoryPeerListComponent?
        private weak var state: EmptyComponentState?
        
        private var requestedLoadMoreToken: String?
        private let loadMoreDisposable = MetaDisposable()
        
        private var previewedItemDisposable: Disposable?
        private var previewedItemId: EnginePeer.Id?
        
        private var loadingItemDisposable: Disposable?
        private var loadingItemId: EnginePeer.Id?
        
        private var animationState: AnimationState?
        private var animator: ConstantDisplayLinkAnimator?
        
        private var currentFraction: CGFloat = 0.0
        private var currentTitleWidth: CGFloat = 0.0
        private var currentActivityFraction: CGFloat = 0.0
        
        public private(set) var overscrollSelectedId: EnginePeer.Id?
        public private(set) var overscrollHiddenChatItemsAllowed: Bool = false
        
        private var anchorForTooltipRect: CGRect?
        
        private var sharedBlurEffect: NSObject?
        
        public override init(frame: CGRect) {
            self.collapsedButton = HighlightableButton()
            
            self.scrollView = ScrollView()
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.alwaysBounceHorizontal = true
            self.scrollView.clipsToBounds = false
            
            self.scrollContainerView = UIView()
            self.scrollContainerView.clipsToBounds = true
            self.scrollContainerView.isExclusiveTouch = true
            
            self.titleView = UIImageView()
            self.titleView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.scrollView.alpha = 0.0
            self.scrollContainerView.addGestureRecognizer(self.scrollView.panGestureRecognizer)
            self.addSubview(self.scrollView)
            self.addSubview(self.scrollContainerView)
            self.addSubview(self.collapsedButton)
            self.addSubview(self.titleView)
            
            self.collapsedButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.layer.allowsGroupOpacity = true
                    self.alpha = 0.6
                } else {
                    self.alpha = 1.0
                    self.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.25, completion: { [weak self] finished in
                        guard let self, finished else {
                            return
                        }
                        self.layer.allowsGroupOpacity = false
                    })
                }
            }
            self.collapsedButton.addTarget(self, action: #selector(self.collapsedButtonPressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.loadMoreDisposable.dispose()
            self.previewedItemDisposable?.dispose()
            self.loadingItemDisposable?.dispose()
        }
        
        @objc private func collapsedButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.peerAction(nil)
        }
        
        @objc private func titleLockButtonPressed() {
            guard let component = self.component else {
                return
            }
            if component.titleHasLock {
                component.lockAction()
            }
        }
        
        public func setPreviewedItem(signal: Signal<StoryId?, NoError>) {
            self.previewedItemDisposable?.dispose()
            self.previewedItemDisposable = (signal |> map(\.?.peerId) |> distinctUntilChanged |> deliverOnMainQueue).start(next: { [weak self] itemId in
                guard let self, let component = self.component else {
                    return
                }
                self.previewedItemId = itemId
                
                for (peerId, visibleItem) in self.visibleItems {
                    if let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                        itemView.updateIsPreviewing(isPreviewing: peerId == itemId)
                        
                        if component.unlocked && peerId == itemId {
                            let itemFrame = itemView.frame.offsetBy(dx: self.scrollView.bounds.minX, dy: 0.0)
                            if !self.scrollView.bounds.intersects(itemFrame.insetBy(dx: 20.0, dy: 0.0)) {
                                self.scrollView.scrollRectToVisible(itemFrame.insetBy(dx: -40.0, dy: 0.0), animated: false)
                            }
                        }
                    }
                }
            })
        }
        
        public func setLoadingItem(peerId: EnginePeer.Id, signal: Signal<Never, NoError>) {
            var applyLoadingItem = true
            self.loadingItemDisposable?.dispose()
            self.loadingItemDisposable = (signal |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let self else {
                    return
                }
                self.loadingItemId = nil
                applyLoadingItem = false
                self.state?.updated(transition: .immediate)
            })
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { [weak self] in
                guard let self else {
                    return
                }
                if applyLoadingItem {
                    self.loadingItemId = peerId
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        public func anchorForTooltip() -> (UIView, CGRect)? {
            if let anchorForTooltipRect = self.anchorForTooltipRect {
                return (self, anchorForTooltipRect)
            } else {
                return nil
            }
        }
        
        public func titleFrame() -> CGRect {
            return self.titleView.frame
        }
        
        public func lockViewFrame() -> CGRect? {
            if let titleLockView = self.titleLockView {
                return titleLockView.frame
            } else {
                return nil
            }
        }
        
        public func transitionViewForItem(peerId: EnginePeer.Id) -> (UIView, StoryContainerScreen.TransitionView)? {
            if self.collapsedButton.isUserInteractionEnabled {
                return nil
            }
            if let visibleItem = self.visibleItems[peerId], let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                let effectiveVisibleBounds = self.bounds.insetBy(dx: 0.0, dy: -10000.0)
                if !effectiveVisibleBounds.intersects(itemView.frame) {
                    return nil
                }
                
                return itemView.transitionView().flatMap { transitionView in
                    return (transitionView, StoryContainerScreen.TransitionView(
                        makeView: { [weak itemView] in
                            return StoryPeerListItemComponent.TransitionView(itemView: itemView)
                        },
                        updateView: { view, state, transition in
                            (view as? StoryPeerListItemComponent.TransitionView)?.update(state: state, transition: transition)
                        },
                        insertCloneTransitionView: nil
                    ))
                }
            }
            return nil
        }
        
        public func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
                
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let titleIconSpacing: CGFloat = 4.0
            let titleIndicatorSpacing: CGFloat = 8.0
            
            var realTitleContentWidth: CGFloat = 0.0
            
            let titleSize = self.titleView.image?.size ?? CGSize()
            realTitleContentWidth += titleSize.width
            
            var titleLockOffset: CGFloat = 0.0
            if component.titleHasLock {
                titleLockOffset = 20.0
            }
            realTitleContentWidth += titleLockOffset
            
            var titleIconSize: CGSize?
            if let peerStatus = component.titlePeerStatus {
                let statusContent: EmojiStatusComponent.Content
                switch peerStatus {
                case .premium:
                    statusContent = .premium(color: component.theme.list.itemAccentColor)
                case let .emoji(emoji):
                    statusContent = .animation(content: .customEmoji(fileId: emoji.fileId), size: CGSize(width: 22.0, height: 22.0), placeholderColor: component.theme.list.mediaPlaceholderColor, themeColor: component.theme.list.itemAccentColor, loopMode: .count(2))
                }
                
                var animateStatusTransition = false
                
                let titleIconView: ComponentView<Empty>
                if let current = self.titleIconView {
                    animateStatusTransition = true
                    titleIconView = current
                } else {
                    titleIconView = ComponentView()
                    self.titleIconView = titleIconView
                }
                
                var titleIconTransition: Transition
                if animateStatusTransition {
                    titleIconTransition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                } else {
                    titleIconTransition = .immediate
                }
                
                let titleIconSizeValue = titleIconView.update(
                    transition: titleIconTransition,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: statusContent,
                        isVisibleForAnimations: true,
                        action: { [weak self] in
                            guard let self, let component = self.component, let titleIconView = self.titleIconView?.view else {
                                return
                            }
                            component.openStatusSetup(titleIconView)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 22.0, height: 22.0)
                )
                
                titleIconSize = titleIconSizeValue
                
                if !component.titleHasActivity {
                    realTitleContentWidth += titleIconSpacing + titleIconSizeValue.width
                }
            } else {
                if let titleIconView = self.titleIconView {
                    self.titleIconView = nil
                    titleIconView.view?.removeFromSuperview()
                }
            }
            
            let collapseStartIndex: Int
            if component.useHiddenList {
                collapseStartIndex = 0
            } else if let storySubscriptions = component.storySubscriptions {
                if self.sortedItems.count < 3, let accountItem = storySubscriptions.accountItem, accountItem.storyCount != 0 {
                    collapseStartIndex = 1
                } else if let accountItem = storySubscriptions.accountItem, (accountItem.hasUnseen || accountItem.hasPending) {
                    collapseStartIndex = 0
                } else {
                    collapseStartIndex = 1
                }
            } else {
                collapseStartIndex = 1
            }
            
            struct CollapseState {
                var globalFraction: CGFloat
                var scaleFraction: CGFloat
                var minFraction: CGFloat
                var maxFraction: CGFloat
                var sideAlphaFraction: CGFloat
                var expandEffectFraction: CGFloat
                var titleWidth: CGFloat
                var activityFraction: CGFloat
            }
            
            let mappedTargetFraction: CGFloat = component.collapseFraction
            
            let targetExpandedFraction: CGFloat = mappedTargetFraction
            let targetFraction: CGFloat = mappedTargetFraction
            
            let targetScaleFraction: CGFloat
            let targetMinFraction: CGFloat
            let targetMaxFraction: CGFloat
            let targetSideAlphaFraction: CGFloat
            
            if component.unlocked {
                targetScaleFraction = targetExpandedFraction
                targetMinFraction = 0.0
                targetMaxFraction = 1.0 - targetExpandedFraction
                targetSideAlphaFraction = 1.0
            } else {
                targetScaleFraction = 1.0
                targetMinFraction = 1.0 - targetExpandedFraction
                targetMaxFraction = 0.0
                targetSideAlphaFraction = 0.0
            }
            
            let collapsedItemWidth: CGFloat = 24.0
            let collapsedItemDistance: CGFloat = 14.0
            let collapsedItemOffsetY: CGFloat = -54.0
            let titleContentSpacing: CGFloat = 8.0
            
            let collapsedItemCount: CGFloat = CGFloat(min(self.sortedItems.count - collapseStartIndex, 3))
            
            let targetActivityFraction: CGFloat = component.titleHasActivity ? 1.0 : 0.0
            
            let timestamp = CACurrentMediaTime()
            
            let calculateOverscrollEffectFraction: (CGFloat, CGFloat) -> CGFloat = { maxFraction, bounceFraction in
                var expandEffectFraction: CGFloat = max(0.0, min(1.0, maxFraction))
                expandEffectFraction = pow(expandEffectFraction, 1.0)
                
                let overscrollEffectFraction = max(0.0, maxFraction - 1.0)
                expandEffectFraction += overscrollEffectFraction * 0.12
                
                let reverseBounceFraction = 1.0 - pow(1.0 - bounceFraction, 2.4)
                expandEffectFraction += reverseBounceFraction * 0.09 * maxFraction
                
                return expandEffectFraction
            }
            
            let collapsedState: CollapseState
            let expandBoundsFraction: CGFloat
            if let animationState = self.animationState {
                let effectiveFromScaleFraction: CGFloat
                if animationState.fromIsUnlocked {
                    effectiveFromScaleFraction = animationState.fromFraction
                } else {
                    effectiveFromScaleFraction = 1.0
                }
                
                let effectiveFromMinFraction: CGFloat
                let effectiveFromMaxFraction: CGFloat
                if animationState.fromIsUnlocked {
                    effectiveFromMinFraction = 0.0
                    effectiveFromMaxFraction = 1.0 - animationState.fromFraction
                } else {
                    effectiveFromMinFraction = 1.0 - animationState.fromFraction
                    effectiveFromMaxFraction = 0.0
                }
                
                let effectiveFromSideAlphaFraction: CGFloat
                if animationState.fromIsUnlocked {
                    effectiveFromSideAlphaFraction = 1.0
                } else {
                    effectiveFromSideAlphaFraction = 0.0
                }
                
                let animatedGlobalFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: animationState.fromFraction, toFraction: targetFraction)
                let animatedScaleFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromScaleFraction, toFraction: targetScaleFraction)
                let animatedMinFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromMinFraction, toFraction: targetMinFraction)
                let animatedMaxFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromMaxFraction, toFraction: targetMaxFraction)
                let animatedSideAlphaFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromSideAlphaFraction, toFraction: targetSideAlphaFraction)
                let animatedTitleWidth = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: animationState.fromTitleWidth, toFraction: realTitleContentWidth)
                let animatedActivityFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: animationState.fromActivityFraction, toFraction: targetActivityFraction)
                
                var rawProgress = CGFloat((timestamp - animationState.startTime) / animationState.duration)
                rawProgress = max(0.0, min(1.0, rawProgress))
                
                if !animationState.fromIsUnlocked && animationState.bounce {
                    let bounceStartFraction: CGFloat = 0.0
                    let bounceGlobalFraction: CGFloat = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: 0.0, toFraction: 1.0, linear: true)
                    let bounceFraction: CGFloat = 1.0 - max(0.0, min(1.0, bounceGlobalFraction - bounceStartFraction)) / (1.0 - bounceStartFraction)
                    expandBoundsFraction = bounceFraction * bounceFraction
                } else {
                    expandBoundsFraction = 0.0
                }
                
                collapsedState = CollapseState(
                    globalFraction: animatedGlobalFraction,
                    scaleFraction: animatedScaleFraction,
                    minFraction: animatedMinFraction,
                    maxFraction: animatedMaxFraction,
                    sideAlphaFraction: animatedSideAlphaFraction,
                    expandEffectFraction: calculateOverscrollEffectFraction(animatedMaxFraction, expandBoundsFraction),
                    titleWidth: animatedTitleWidth,
                    activityFraction: animatedActivityFraction
                )
            } else {
                collapsedState = CollapseState(
                    globalFraction: targetFraction,
                    scaleFraction: targetScaleFraction,
                    minFraction: targetMinFraction,
                    maxFraction: targetMaxFraction,
                    sideAlphaFraction: targetSideAlphaFraction,
                    expandEffectFraction: calculateOverscrollEffectFraction(targetMaxFraction, 0.0),
                    titleWidth: realTitleContentWidth,
                    activityFraction: targetActivityFraction
                )
                expandBoundsFraction = 0.0
            }
            
            /*let blurRadius: CGFloat = collapsedState.sideAlphaFraction * 0.0 + (1.0 - collapsedState.sideAlphaFraction) * 14.0
            if blurRadius == 0.0 {
                self.sharedBlurEffect = nil
            } else {
                if let current = self.sharedBlurEffect, (current.value(forKey: "inputRadius") as? NSNumber)?.doubleValue == blurRadius {
                } else {
                    if let sharedBlurEffect = CALayer.blur() {
                        sharedBlurEffect.setValue(blurRadius as NSNumber, forKey: "inputRadius")
                        self.sharedBlurEffect = sharedBlurEffect
                    } else {
                        self.sharedBlurEffect = nil
                    }
                }
            }*/
            
            var targetCollapsedContentWidth: CGFloat = 0.0
            if collapsedItemCount > 0 {
                targetCollapsedContentWidth = 1.0 * collapsedItemWidth + (collapsedItemDistance) * max(0.0, collapsedItemCount - 1.0)
            }
            let activityCollapsedContentWidth: CGFloat = 16.0 + titleIndicatorSpacing
            let collapsedContentWidth = activityCollapsedContentWidth * collapsedState.activityFraction + targetCollapsedContentWidth * (1.0 - collapsedState.activityFraction)
            
            let collapseEndIndex = collapseStartIndex + max(0, Int(collapsedItemCount) - 1)
            
            var collapsedContentOrigin: CGFloat
            
            let centralContentWidth: CGFloat = collapsedContentWidth + titleContentSpacing + collapsedState.titleWidth
            
            collapsedContentOrigin = (itemLayout.containerSize.width - centralContentWidth) * 0.5
            
            collapsedContentOrigin = min(collapsedContentOrigin, component.maxTitleX - centralContentWidth - 4.0)
            
            let collapsedContentOriginOffset: CGFloat = 0.0
            collapsedContentOrigin -= collapsedContentOriginOffset
            
            self.currentFraction = collapsedState.globalFraction
            self.currentTitleWidth = collapsedState.titleWidth
            self.currentActivityFraction = collapsedState.activityFraction
            
            let effectiveVisibleBounds = self.scrollView.bounds
            let visibleBounds = effectiveVisibleBounds.insetBy(dx: -200.0, dy: -10000.0)
            
            var effectiveFirstVisibleIndex = 0
            for i in 0 ..< self.sortedItems.count {
                let regularItemFrame = itemLayout.frame(at: i)
                let isReallyVisible = effectiveVisibleBounds.intersects(regularItemFrame)
                if isReallyVisible {
                    effectiveFirstVisibleIndex = i
                    break
                }
            }
            
            let expandedItemWidth: CGFloat = 60.0
            
            let totalOverscrollFraction: CGFloat = max(0.0, collapsedState.maxFraction - 1.0)
            let overscrollStage1 = min(0.5, totalOverscrollFraction)
            let overscrollStage2 = max(0.0, totalOverscrollFraction - 0.5)
            
            //let realTimeOverscrollFraction: CGFloat = max(0.0, (1.0 - component.collapseFraction) - 1.0)
            let realTimeOverscrollFraction = totalOverscrollFraction
            
            var overscrollFocusIndex: Int?
            for i in 0 ..< self.sortedItems.count {
                if self.sortedItems[i].peer.id == component.context.account.peerId {
                    continue
                }
                let itemFrame = itemLayout.frame(at: i)
                if effectiveVisibleBounds.contains(itemFrame) {
                    overscrollFocusIndex = i
                    break
                }
            }
            
            if overscrollStage1 >= 0.5 {
                self.overscrollHiddenChatItemsAllowed = true
            } else {
                self.overscrollHiddenChatItemsAllowed = false
            }
            
            //print("overscrollStage2: \(overscrollStage2)")
            if let overscrollFocusIndex, overscrollStage2 >= 1.19 {
                self.overscrollSelectedId = self.sortedItems[overscrollFocusIndex].peer.id
            } else {
                self.overscrollSelectedId = nil
            }
            
            struct MeasuredItem {
                var itemFrame: CGRect
                var itemScale: CGFloat
            }
            let calculateItem: (Int) -> MeasuredItem = { index in
                let frameIndex = index
                let regularItemFrame = itemLayout.frame(at: frameIndex)
                let isReallyVisible = effectiveVisibleBounds.intersects(regularItemFrame)
                
                let collapseIndex = index - effectiveFirstVisibleIndex
                
                let collapsedItemX: CGFloat
                if collapseIndex < collapseStartIndex {
                    collapsedItemX = collapsedContentOrigin
                } else {
                    collapsedItemX = collapsedContentOrigin + CGFloat(min(collapseIndex - collapseStartIndex, collapseEndIndex - collapseStartIndex)) * collapsedItemDistance * (1.0 - collapsedState.activityFraction) * (1.0 - collapsedState.maxFraction)
                }
                let collapsedItemFrame = CGRect(origin: CGPoint(x: collapsedItemX, y: regularItemFrame.minY + collapsedItemOffsetY), size: CGSize(width: collapsedItemWidth, height: regularItemFrame.height))
                
                var collapsedMaxItemFrame = collapsedItemFrame
                
                if itemLayout.itemCount > 1 {
                    var collapseDistance: CGFloat = CGFloat(collapseIndex - collapseStartIndex) / CGFloat(collapseEndIndex - collapseStartIndex)
                    collapseDistance = max(0.0, min(1.0, collapseDistance))
                    collapsedMaxItemFrame.origin.x -= collapsedState.minFraction * 4.0
                    collapsedMaxItemFrame.origin.x += collapseDistance * 20.0
                    collapsedMaxItemFrame.origin.y += collapseDistance * 20.0
                    collapsedMaxItemFrame.origin.y += collapsedState.minFraction * 10.0
                }
                
                let minimizedDefaultItemScale: CGFloat = 24.0 / 52.0
                let minimizedItemScale = minimizedDefaultItemScale
                
                let minimizedMaxItemScale: CGFloat = (24.0 + 4.0) / 52.0
                
                let overscrollScaleFactor: CGFloat
                if index == overscrollFocusIndex {
                    overscrollScaleFactor = 1.0
                } else {
                    overscrollScaleFactor = 0.0
                }
                var maximizedItemScale: CGFloat = 1.0 + overscrollStage1 * 0.1 + overscrollScaleFactor * overscrollStage2 * 0.5
                maximizedItemScale = min(1.6, maximizedItemScale)
                
                let minItemScale: CGFloat = minimizedItemScale.interpolate(to: minimizedMaxItemScale, amount: collapsedState.minFraction) * (1.0 - collapsedState.activityFraction) + 0.1 * collapsedState.activityFraction
                
                let itemScale: CGFloat = minItemScale.interpolate(to: maximizedItemScale, amount: min(1.0, collapsedState.maxFraction))
                
                let itemFrame: CGRect
                if isReallyVisible {
                    var adjustedRegularFrame = regularItemFrame
                    if index < collapseStartIndex {
                        adjustedRegularFrame = adjustedRegularFrame.interpolate(to: itemLayout.frame(at: effectiveFirstVisibleIndex + collapseStartIndex), amount: 0.0)
                    } else if index > collapseEndIndex {
                        adjustedRegularFrame = adjustedRegularFrame.interpolate(to: itemLayout.frame(at: effectiveFirstVisibleIndex + collapseEndIndex), amount: 0.0)
                    }
                    adjustedRegularFrame.origin.x -= effectiveVisibleBounds.minX
                    
                    if let overscrollFocusIndex {
                        let focusIndexOffset: CGFloat = max(-1.0, min(1.0, CGFloat(index - overscrollFocusIndex)))
                        adjustedRegularFrame.origin.x += focusIndexOffset * overscrollStage2 * 0.3 * adjustedRegularFrame.width * 0.5
                    }
                    
                    let collapsedItemPosition: CGPoint = collapsedItemFrame.center.interpolate(to: collapsedMaxItemFrame.center, amount: collapsedState.minFraction)
                    
                    var itemPosition = collapsedItemPosition.interpolate(to: adjustedRegularFrame.center, amount: min(1.0, collapsedState.maxFraction))
                    
                    itemPosition.y += realTimeOverscrollFraction * 83.0 * 0.5
                    
                    var bounceOffsetFraction = (adjustedRegularFrame.midX - itemLayout.frame(at: collapseStartIndex).midX) / itemLayout.containerSize.width
                    bounceOffsetFraction = max(-1.0, min(1.0, bounceOffsetFraction))
                    
                    let _ = bounceOffsetFraction
                    
                    let bounceFactor = expandBoundsFraction * (1.0 + realTimeOverscrollFraction * 6.0)
                    let verticalBounceFactor = expandBoundsFraction * (1.0 + realTimeOverscrollFraction * 12.0)
                    itemPosition.x += bounceFactor * (adjustedRegularFrame.midX - collapsedItemPosition.x) * 0.04
                    itemPosition.y += verticalBounceFactor * (adjustedRegularFrame.midY - collapsedItemPosition.y) * 0.05
                    
                    let itemSize = CGSize(width: adjustedRegularFrame.width * itemScale, height: adjustedRegularFrame.height)
                    
                    itemFrame = itemSize.centered(around: itemPosition)
                } else {
                    itemFrame = regularItemFrame.offsetBy(dx: -effectiveVisibleBounds.minX, dy: 0.0)
                }
                
                return MeasuredItem(
                    itemFrame: itemFrame,
                    itemScale: itemScale
                )
            }
            
            var validIds: [EnginePeer.Id] = []
            var validCollapsableIds: [EnginePeer.Id] = []
            
            for i in 0 ..< self.sortedItems.count {
                let itemSet = self.sortedItems[i]
                let peer = itemSet.peer
                
                let regularItemFrame = itemLayout.frame(at: i)
                
                var isItemVisible = true
                if !visibleBounds.intersects(regularItemFrame) {
                    isItemVisible = false
                }
                
                if !isItemVisible {
                    continue
                }
                
                let isReallyVisible = effectiveVisibleBounds.intersects(regularItemFrame)
                let _ = isReallyVisible
                
                validIds.append(itemSet.peer.id)
                
                let visibleItem: VisibleItem
                var itemTransition = transition
                if let current = self.visibleItems[itemSet.peer.id] {
                    visibleItem = current
                } else {
                    itemTransition = .immediate
                    visibleItem = VisibleItem()
                    self.visibleItems[itemSet.peer.id] = visibleItem
                }
                
                var hasUnseenCloseFriendsItems = itemSet.hasUnseenCloseFriends
                
                var hasItems = true
                var itemRingAnimation: StoryPeerListItemComponent.RingAnimation?
                if peer.id == component.context.account.peerId {
                    if let storySubscriptions = component.storySubscriptions, let accountItem = storySubscriptions.accountItem {
                        hasItems = accountItem.storyCount != 0
                    } else {
                        hasItems = false
                    }
                    if let uploadProgress = component.uploadProgress {
                        itemRingAnimation = .progress(uploadProgress)
                    }
                    
                    hasUnseenCloseFriendsItems = false
                } else if peer.id == self.loadingItemId {
                    itemRingAnimation = .loading
                }
                
                let measuredItem = calculateItem(i)
                
                var leftItemFrame: CGRect?
                var rightItemFrame: CGRect?
                
                var itemAlpha: CGFloat = 1.0
                var isCollapsable: Bool = false
                var itemScale = measuredItem.itemScale
                if itemLayout.itemCount == 1 {
                    let singleScaleFactor = min(1.0, collapsedState.minFraction + min(1.0, collapsedState.maxFraction))
                    itemScale = 0.001 * (1.0 - singleScaleFactor) + itemScale * singleScaleFactor
                }
                
                let collapseIndex = i - effectiveFirstVisibleIndex
                if collapseIndex >= collapseStartIndex && collapseIndex <= collapseEndIndex {
                    isCollapsable = true
                    
                    if collapseIndex != collapseStartIndex {
                        leftItemFrame = calculateItem(i - 1).itemFrame
                    }
                    if collapseIndex != collapseEndIndex {
                        rightItemFrame = calculateItem(i + 1).itemFrame
                    }
                    
                    itemAlpha = (collapsedState.sideAlphaFraction * 1.0 + (1.0 - collapsedState.sideAlphaFraction) * (1.0 - collapsedState.activityFraction)) * collapsedState.sideAlphaFraction
                } else {
                    if itemLayout.itemCount == 1 {
                        itemAlpha = min(1.0, (collapsedState.minFraction + min(1.0, collapsedState.maxFraction)) * 4.0)
                    } else {
                        itemAlpha = collapsedState.sideAlphaFraction
                    }
                }
                
                var leftNeighborDistance: CGPoint?
                var rightNeighborDistance: CGPoint?
                
                if collapsedState.maxFraction < 0.5 {
                    if let leftItemFrame {
                        leftNeighborDistance = CGPoint(x: abs(leftItemFrame.midX - measuredItem.itemFrame.midX), y: leftItemFrame.minY - measuredItem.itemFrame.minY)
                    }
                    if let rightItemFrame {
                        rightNeighborDistance = CGPoint(x: abs(rightItemFrame.midX - measuredItem.itemFrame.midX), y: rightItemFrame.minY - measuredItem.itemFrame.minY)
                    }
                }
                
                let totalCount: Int
                let unseenCount: Int
                totalCount = itemSet.storyCount
                unseenCount = itemSet.unseenCount
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: AnyComponent(StoryPeerListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        peer: peer,
                        totalCount: totalCount,
                        unseenCount: unseenCount,
                        hasUnseenCloseFriendsItems: hasUnseenCloseFriendsItems,
                        hasItems: hasItems,
                        ringAnimation: itemRingAnimation,
                        scale: itemScale,
                        fullWidth: expandedItemWidth,
                        expandedAlphaFraction: collapsedState.sideAlphaFraction,
                        expandEffectFraction: collapsedState.expandEffectFraction,
                        leftNeighborDistance: leftNeighborDistance,
                        rightNeighborDistance: rightNeighborDistance,
                        action: component.peerAction,
                        contextGesture: component.contextPeerAction
                    )),
                    environment: {},
                    containerSize: itemLayout.itemSize
                )
                
                if let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                    if itemView.superview == nil {
                        self.scrollContainerView.addSubview(itemView)
                        self.scrollContainerView.addSubview(itemView.backgroundContainer)
                    }
                    
                    if isCollapsable {
                        itemView.layer.zPosition = 1000.0 - CGFloat(i) * 0.01
                        itemView.backgroundContainer.layer.zPosition = 1.0
                    } else {
                        itemView.layer.zPosition = 0.5
                        itemView.backgroundContainer.layer.zPosition = 0.0
                    }
                    
                    itemTransition.setFrame(view: itemView, frame: measuredItem.itemFrame)
                    itemTransition.setAlpha(view: itemView, alpha: itemAlpha)
                    itemTransition.setScale(view: itemView, scale: 1.0)
                    
                    itemTransition.setFrame(view: itemView.backgroundContainer, frame: measuredItem.itemFrame)
                    itemTransition.setAlpha(view: itemView.backgroundContainer, alpha: itemAlpha)
                    itemTransition.setScale(view: itemView.backgroundContainer, scale: 1.0)
                    
                    itemView.updateIsPreviewing(isPreviewing: self.previewedItemId == itemSet.peer.id)
                    
                    if (i >= collapseStartIndex && i <= collapseEndIndex) || !isReallyVisible {
                        itemView.layer.filters = nil
                    } else {
                        if let sharedBlurEffect = self.sharedBlurEffect {
                            itemView.layer.filters = [sharedBlurEffect]
                        } else {
                            itemView.layer.filters = nil
                        }
                    }
                }
            }
            
            for i in 0 ..< self.sortedItems.count {
                let itemSet = self.sortedItems[i]
                let peer = itemSet.peer
                
                if i >= collapseStartIndex && i <= collapseEndIndex {
                } else {
                    continue
                }
                
                validCollapsableIds.append(itemSet.peer.id)
                
                let visibleItem: VisibleItem
                var itemTransition = transition
                if let current = self.visibleCollapsableItems[itemSet.peer.id] {
                    visibleItem = current
                } else {
                    itemTransition = .immediate
                    visibleItem = VisibleItem()
                    self.visibleCollapsableItems[itemSet.peer.id] = visibleItem
                }
                
                var hasUnseenCloseFriendsItems = itemSet.hasUnseenCloseFriends
                
                var hasItems = true
                var itemRingAnimation: StoryPeerListItemComponent.RingAnimation?
                if peer.id == component.context.account.peerId {
                    if let storySubscriptions = component.storySubscriptions, let accountItem = storySubscriptions.accountItem {
                        hasItems = accountItem.storyCount != 0
                    } else {
                        hasItems = false
                    }
                    if let uploadProgress = component.uploadProgress {
                        itemRingAnimation = .progress(uploadProgress)
                    }
                    
                    hasUnseenCloseFriendsItems = false
                }
                
                let collapseIndex = i + effectiveFirstVisibleIndex
                let measuredItem = calculateItem(collapseIndex)
                
                var leftItemFrame: CGRect?
                var rightItemFrame: CGRect?
                
                var itemAlpha: CGFloat = 1.0
                var isCollapsable: Bool = false
                let itemScale = measuredItem.itemScale
                
                if i >= collapseStartIndex && i <= collapseEndIndex {
                    isCollapsable = true
                    
                    if i != collapseStartIndex {
                        leftItemFrame = calculateItem(collapseIndex - 1).itemFrame
                    }
                    if i != collapseEndIndex {
                        rightItemFrame = calculateItem(collapseIndex + 1).itemFrame
                    }
                    
                    itemAlpha = (1.0 - collapsedState.sideAlphaFraction) * (1.0 - collapsedState.activityFraction)
                } else {
                    itemAlpha = collapsedState.sideAlphaFraction
                }
                
                var leftNeighborDistance: CGPoint?
                var rightNeighborDistance: CGPoint?
                
                if collapsedState.maxFraction < 0.5 {
                    if let leftItemFrame {
                        leftNeighborDistance = CGPoint(x: abs(leftItemFrame.midX - measuredItem.itemFrame.midX), y: leftItemFrame.minY - measuredItem.itemFrame.minY)
                    }
                    if let rightItemFrame {
                        rightNeighborDistance = CGPoint(x: abs(rightItemFrame.midX - measuredItem.itemFrame.midX), y: rightItemFrame.minY - measuredItem.itemFrame.minY)
                    }
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: AnyComponent(StoryPeerListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        peer: peer,
                        totalCount: 1,
                        unseenCount: itemSet.unseenCount != 0 ? 1 : 0,
                        hasUnseenCloseFriendsItems: hasUnseenCloseFriendsItems,
                        hasItems: hasItems,
                        ringAnimation: itemRingAnimation,
                        scale: itemScale,
                        fullWidth: expandedItemWidth,
                        expandedAlphaFraction: collapsedState.sideAlphaFraction,
                        expandEffectFraction: collapsedState.expandEffectFraction,
                        leftNeighborDistance: leftNeighborDistance,
                        rightNeighborDistance: rightNeighborDistance,
                        action: component.peerAction,
                        contextGesture: component.contextPeerAction
                    )),
                    environment: {},
                    containerSize: itemLayout.itemSize
                )
                
                if let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                    if itemView.superview == nil {
                        itemView.isUserInteractionEnabled = false
                        self.scrollContainerView.addSubview(itemView)
                        self.scrollContainerView.addSubview(itemView.backgroundContainer)
                    }
                    
                    if isCollapsable {
                        itemView.layer.zPosition = 1000.0 - CGFloat(i) * 0.01
                        itemView.backgroundContainer.layer.zPosition = 1.0
                    } else {
                        itemView.layer.zPosition = 0.5
                        itemView.backgroundContainer.layer.zPosition = 0.0
                    }
                    
                    itemTransition.setFrame(view: itemView, frame: measuredItem.itemFrame)
                    itemTransition.setAlpha(view: itemView, alpha: itemAlpha)
                    itemTransition.setScale(view: itemView, scale: 1.0)
                    
                    itemTransition.setFrame(view: itemView.backgroundContainer, frame: measuredItem.itemFrame)
                    itemTransition.setAlpha(view: itemView.backgroundContainer, alpha: itemAlpha)
                    itemTransition.setScale(view: itemView.backgroundContainer, scale: 1.0)
                }
            }
            
            var removedIds: [EnginePeer.Id] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    if let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                        itemView.backgroundContainer.removeFromSuperview()
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removedIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            var removedCollapsableIds: [EnginePeer.Id] = []
            for (id, visibleItem) in self.visibleCollapsableItems {
                if !validCollapsableIds.contains(id) {
                    removedCollapsableIds.append(id)
                    if let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                        itemView.backgroundContainer.removeFromSuperview()
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removedCollapsableIds {
                self.visibleCollapsableItems.removeValue(forKey: id)
            }
            
            transition.setFrame(view: self.collapsedButton, frame: CGRect(origin: CGPoint(x: component.minTitleX, y: 6.0 - 59.0), size: CGSize(width: max(0.0, component.maxTitleX - component.minTitleX), height: 44.0)))
            self.anchorForTooltipRect = CGRect(origin: CGPoint(x: collapsedContentOrigin, y: -59.0 + 6.0 + 2.0), size: CGSize(width: collapsedContentWidth, height: 44.0))
            
            let defaultCollapsedTitleOffset: CGFloat = 0.0
            
            let targetCollapsedTitleOffset: CGFloat = collapsedContentOrigin + collapsedContentOriginOffset + collapsedContentWidth + titleContentSpacing
            
            let collapsedTitleOffset = targetCollapsedTitleOffset - defaultCollapsedTitleOffset
            
            let titleMinContentOffset: CGFloat = collapsedTitleOffset.interpolate(to: collapsedTitleOffset + 12.0, amount: collapsedState.minFraction * (1.0 - collapsedState.activityFraction))
            
            var titleContentOffset: CGFloat
            if self.sortedItems.isEmpty {
                titleContentOffset = collapsedTitleOffset
            } else {
                titleContentOffset = titleMinContentOffset.interpolate(to: ((itemLayout.containerSize.width - collapsedState.titleWidth) * 0.5) as CGFloat, amount: min(1.0, collapsedState.maxFraction) * (1.0 - collapsedState.activityFraction))
            }
            
            titleContentOffset += -expandBoundsFraction * 4.0
            
            var titleIndicatorSize: CGSize?
            if collapsedState.activityFraction != 0.0 {
                let collapsedItemMinX = collapsedContentOrigin - collapsedItemWidth * 0.5
                let collapsedItemMaxX = collapsedContentOrigin + CGFloat(collapseEndIndex - collapseStartIndex) * collapsedItemDistance * (1.0 - collapsedState.activityFraction) * (1.0 - collapsedState.sideAlphaFraction) + collapsedItemWidth * 0.5
                let collapsedContentWidth = max(collapsedItemWidth, collapsedItemMaxX - collapsedItemMinX)
                
                let titleIndicatorView: ComponentView<Empty>
                if let current = self.titleIndicatorView {
                    titleIndicatorView = current
                } else {
                    titleIndicatorView = ComponentView()
                    self.titleIndicatorView = titleIndicatorView
                }
                let titleIndicatorSizeValue = titleIndicatorView.update(
                    transition: .immediate,
                    component: AnyComponent(TitleActivityIndicatorComponent(
                        color: component.theme.rootController.navigationBar.accentTextColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: collapsedContentWidth - 2.0, height: collapsedItemWidth - 2.0)
                )
                titleIndicatorSize = titleIndicatorSizeValue
            } else if let titleIndicatorView = self.titleIndicatorView {
                self.titleIndicatorView = nil
                titleIndicatorView.view?.removeFromSuperview()
            }
            
            if let titleIndicatorSize, let titleIndicatorView = self.titleIndicatorView?.view {
                let titleIndicatorFrame = CGRect(origin: CGPoint(x: titleContentOffset - titleIndicatorSize.width - 9.0, y: collapsedItemOffsetY + 2.0 + floor((56.0 - titleIndicatorSize.height) * 0.5)), size: titleIndicatorSize)
                if titleIndicatorView.superview == nil {
                    self.addSubview(titleIndicatorView)
                }
                titleIndicatorView.center = titleIndicatorFrame.center
                titleIndicatorView.bounds = CGRect(origin: CGPoint(), size: titleIndicatorFrame.size)
                
                var indicatorMinScale: CGFloat = collapsedState.sideAlphaFraction * 0.1 + (1.0 - collapsedState.sideAlphaFraction) * 1.0
                if collapsedItemCount == 0 {
                    indicatorMinScale = 0.1
                }
                
                let indicatorScale: CGFloat = collapsedState.activityFraction * 1.0 + (1.0 - collapsedState.activityFraction) * indicatorMinScale
                let indicatorAlpha: CGFloat = collapsedState.activityFraction
                titleIndicatorView.layer.transform = CATransform3DMakeScale(indicatorScale, indicatorScale, 1.0)
                titleIndicatorView.alpha = indicatorAlpha
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: titleContentOffset + titleLockOffset, y: collapsedItemOffsetY + 2.0 + floor((56.0 - titleSize.height) * 0.5)), size: titleSize)
            if let image = self.titleView.image {
                self.titleView.center = CGPoint(x: titleFrame.minX, y: titleFrame.midY)
                self.titleView.bounds = CGRect(origin: CGPoint(), size: image.size)
                
                let titleFraction: CGFloat
                if let titleViewAnimation = self.titleViewAnimation {
                    titleFraction = titleViewAnimation.interpolatedFraction(at: timestamp, effectiveFromFraction: titleViewAnimation.fromFraction, toFraction: titleViewAnimation.toFraction)
                } else {
                    titleFraction = 1.0
                }
                
                self.titleView.alpha = titleFraction
                
                let titleScale: CGFloat = titleFraction * 1.0 + (1.0 - titleFraction) * 0.3
                self.titleView.layer.transform = CATransform3DMakeScale(titleScale, titleScale, 1.0)
            }
            
            if component.titleHasLock {
                let titleLockView: ChatListTitleLockView
                if let current = self.titleLockView {
                    titleLockView = current
                } else {
                    titleLockView = ChatListTitleLockView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0)))
                    self.titleLockView = titleLockView
                    self.addSubview(titleLockView)
                }
                titleLockView.updateTheme(component.theme)
                
                let lockFrame = CGRect(x: titleFrame.minX - 6.0 - 12.0, y: titleFrame.minY + 3.0, width: 2.0, height: 2.0)
                titleLockView.frame = lockFrame
                
                let titleLockButton: HighlightTrackingButton
                if let current = self.titleLockButton {
                    titleLockButton = current
                } else {
                    titleLockButton = HighlightTrackingButton()
                    self.titleLockButton = titleLockButton
                    self.addSubview(titleLockButton)
                    titleLockButton.addTarget(self, action: #selector(self.titleLockButtonPressed), for: .touchUpInside)
                }
                titleLockButton.frame = CGRect(origin: CGPoint(x: lockFrame.minX - 4.0, y: titleFrame.minY - 4.0), size: CGSize(width: titleFrame.maxX - lockFrame.minX + 4.0, height: titleFrame.height + 8.0))
            } else if let titleLockView = self.titleLockView {
                self.titleLockView = nil
                titleLockView.removeFromSuperview()
                
                self.titleLockButton?.removeFromSuperview()
                self.titleLockButton = nil
            }
            
            for disappearingTitleView in self.disappearingTitleViews {
                if let image = disappearingTitleView.imageView.image {
                    disappearingTitleView.imageView.center = CGPoint(x: titleFrame.minX, y: titleFrame.midY)
                    disappearingTitleView.imageView.bounds = CGRect(origin: CGPoint(), size: image.size)
                    
                    let titleFraction = disappearingTitleView.interpolatedFraction(at: timestamp, effectiveFromFraction: disappearingTitleView.fromFraction, toFraction: disappearingTitleView.toFraction)
                    
                    disappearingTitleView.imageView.alpha = titleFraction
                    
                    let titleScale: CGFloat = titleFraction * 1.0 + (1.0 - titleFraction) * 0.3
                    disappearingTitleView.imageView.layer.transform = CATransform3DMakeScale(titleScale, titleScale, 1.0)
                }
            }
            
            if let titleIconSize, let titleIconView = self.titleIconView?.view {
                titleContentOffset += titleIconSpacing
                
                let titleIconFrame = CGRect(origin: CGPoint(x: titleContentOffset - 3.0 + titleIconSpacing + (collapsedState.titleWidth - (titleIconSpacing + titleIconSize.width)) * (1.0 - collapsedState.activityFraction), y: collapsedItemOffsetY + 2.0 + floor((56.0 - titleIconSize.height) * 0.5)), size: titleIconSize)
                
                if titleIconView.superview == nil {
                    self.addSubview(titleIconView)
                }
                titleIconView.center = titleIconFrame.center
                titleIconView.bounds = CGRect(origin: CGPoint(), size: titleIconFrame.size)
                
                let titleIconFraction = 1.0 - collapsedState.activityFraction
                let titleIconAlpha: CGFloat = titleIconFraction
                let titleIconScale: CGFloat = titleIconFraction * 1.0 + (1.0 - titleIconFraction) * 0.1
                titleIconView.alpha = titleIconAlpha
                titleIconView.layer.transform = CATransform3DMakeScale(titleIconScale, titleIconScale, 1.0)
            }
            
            titleContentOffset += collapsedState.titleWidth
            
            self.scrollContainerView.isUserInteractionEnabled = collapsedState.maxFraction >= 1.0 - 0.001
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.alpha.isZero {
                return nil
            }
            
            if let titleIconView = self.titleIconView?.view {
                if let result = titleIconView.hitTest(self.convert(point, to: titleIconView), with: event) {
                    return result
                }
            }
            
            if let titleLockButton = self.titleLockButton {
                if let result = titleLockButton.hitTest(self.convert(point, to: titleLockButton), with: event) {
                    return result
                }
            }
            
            var result: UIView?
            for view in self.subviews.reversed() {
                if let resultValue = view.hitTest(self.convert(point, to: view), with: event), resultValue.isUserInteractionEnabled {
                    result = resultValue
                }
            }
            
            guard let result else {
                return nil
            }

            if self.collapsedButton.isUserInteractionEnabled {
                if result !== self.collapsedButton {
                    return nil
                }
            } else {
                if !self.scrollView.frame.contains(point) {
                    return nil
                }
                
                if !result.isDescendant(of: self.scrollContainerView) {
                    return nil
                }
            }
            return result
        }
        
        func update(component: StoryPeerListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            var transition = transition
            transition.animation = .none
            
            let animationHint = transition.userData(AnimationHint.self)
            var useAnimation = false
            if let previousComponent = self.component, component.unlocked != previousComponent.unlocked {
                useAnimation = true
            } else if let animationHint, animationHint.allowAvatarsExpansionUpdated {
                useAnimation = true
            } else if let previousComponent = self.component, (component.title != previousComponent.title || component.titleHasActivity != previousComponent.titleHasActivity) {
                useAnimation = true
            }
            
            if let animationHint, animationHint.disableAnimations {
                useAnimation = false
                self.animationState = nil
            }
            
            let timestamp = CACurrentMediaTime()
            if let previousComponent = self.component, useAnimation {
                let duration: Double
                if let durationValue = animationHint?.duration {
                    duration = durationValue
                } else if component.unlocked {
                    duration = 0.35
                } else {
                    duration = 0.25
                }
                
                if useAnimation, let previousComponent = self.component, component.title != previousComponent.title, self.titleView.image != nil {
                    var fromFraction: CGFloat = 1.0
                    if let titleViewAnimation = self.titleViewAnimation {
                        fromFraction = titleViewAnimation.interpolatedFraction(
                            at: timestamp,
                            effectiveFromFraction: titleViewAnimation.fromFraction,
                            toFraction: titleViewAnimation.toFraction
                        )
                    }
                    
                    if let previousImage = self.titleView.image {
                        let previousImageView = UIImageView(image: previousImage)
                        previousImageView.layer.anchorPoint = self.titleView.layer.anchorPoint
                        self.disappearingTitleViews.append(TitleAnimationState(
                            duration: duration,
                            startTime: timestamp,
                            fromFraction: fromFraction,
                            toFraction: 0.0,
                            imageView: previousImageView
                        ))
                        self.insertSubview(previousImageView, belowSubview: self.titleView)
                    }
                    
                    self.titleViewAnimation = TitleAnimationState(
                        duration: duration * UIView.animationDurationFactor(),
                        startTime: timestamp,
                        fromFraction: 0.0,
                        toFraction: 1.0,
                        imageView: self.titleView
                    )
                }
                
                var allowBounce = !previousComponent.unlocked && component.unlocked
                if let animationHint, !animationHint.bounce {
                    allowBounce = false
                }
                
                self.animationState = AnimationState(
                    duration: duration * UIView.animationDurationFactor(),
                    fromIsUnlocked: previousComponent.unlocked,
                    fromFraction: self.currentFraction,
                    fromTitleWidth: self.currentTitleWidth,
                    fromActivityFraction: self.currentActivityFraction,
                    startTime: timestamp,
                    bounce: allowBounce
                )
            }
            
            if let animationState = self.animationState {
                if animationState.isFinished(at: timestamp) {
                    self.animationState = nil
                }
            }
            
            if let titleViewAnimation = self.titleViewAnimation {
                if titleViewAnimation.isFinished(at: timestamp) {
                    self.titleViewAnimation = nil
                }
            }
            
            for i in (0 ..< self.disappearingTitleViews.count).reversed() {
                if self.disappearingTitleViews[i].isFinished(at: timestamp) {
                    self.disappearingTitleViews[i].imageView.removeFromSuperview()
                    self.disappearingTitleViews.remove(at: i)
                }
            }
            
            if self.animationState != nil || self.titleViewAnimation != nil || !self.disappearingTitleViews.isEmpty {
                if self.animator == nil {
                    let animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.state?.updated(transition: .immediate)
                    })
                    self.animator = animator
                    animator.isPaused = false
                }
            } else if let animator = self.animator {
                self.animator = nil
                animator.invalidate()
            }
            
            self.component = component
            self.state = state
            
            let updatedTitleState = TitleState(text: component.title, color: component.theme.rootController.navigationBar.primaryTextColor)
            if self.titleState != updatedTitleState {
                self.titleState = updatedTitleState
                
                let attributedText = NSAttributedString(string: updatedTitleState.text, attributes: [
                    NSAttributedString.Key.font: Font.semibold(17.0),
                    NSAttributedString.Key.foregroundColor: component.theme.rootController.navigationBar.primaryTextColor
                ])
                var boundingRect = attributedText.boundingRect(with: CGSize(width: max(0.0, component.maxTitleX - component.minTitleX - 30.0), height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                boundingRect.size.width = ceil(boundingRect.size.width)
                boundingRect.size.height = ceil(boundingRect.size.height)

                let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: boundingRect.size))
                let image = renderer.image { context in
                    UIGraphicsPushContext(context.cgContext)
                    attributedText.draw(at: CGPoint())
                    UIGraphicsPopContext()
                }
                self.titleView.image = image
            }
            
            if let storySubscriptions = component.storySubscriptions, let hasMoreToken = storySubscriptions.hasMoreToken {
                if self.requestedLoadMoreToken != hasMoreToken {
                    self.requestedLoadMoreToken = hasMoreToken
                    
                    if component.useHiddenList {
                        if let storySubscriptionsContext = component.context.account.hiddenStorySubscriptionsContext {
                            storySubscriptionsContext.loadMore()
                        }
                    } else {
                        if let storySubscriptionsContext = component.context.account.filteredStorySubscriptionsContext {
                            storySubscriptionsContext.loadMore()
                        }
                    }
                }
            }
            
            self.collapsedButton.isUserInteractionEnabled = !component.unlocked
            
            self.sortedItems.removeAll(keepingCapacity: true)
            if let storySubscriptions = component.storySubscriptions {
                if !component.useHiddenList, let accountItem = storySubscriptions.accountItem {
                    self.sortedItems.append(accountItem)
                }
                
                for itemSet in storySubscriptions.items {
                    if itemSet.peer.id == component.context.account.peerId {
                        continue
                    }
                    self.sortedItems.append(itemSet)
                }
            }
            
            let itemLayout = ItemLayout(
                containerSize: availableSize,
                containerInsets: UIEdgeInsets(top: 4.0, left: component.sideInset - 4.0, bottom: 0.0, right: component.sideInset - 4.0),
                itemSize: CGSize(width: 60.0, height: 77.0),
                itemSpacing: 14.0,
                itemCount: self.sortedItems.count
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: CGSize(width: availableSize.width, height: availableSize.height + 4.0)))
            
            let scrollContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: CGSize(width: availableSize.width, height: availableSize.height + 4.0))
            let scrollContainerExpandedFrame = scrollContainerFrame.insetBy(dx: 0.0, dy: -500.0)
            transition.setPosition(view: self.scrollContainerView, position: scrollContainerExpandedFrame.center)
            transition.setBounds(view: self.scrollContainerView, bounds: CGRect(origin: CGPoint(x: 0.0, y: scrollContainerExpandedFrame.minY - scrollContainerFrame.minY), size: scrollContainerExpandedFrame.size))
            
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
