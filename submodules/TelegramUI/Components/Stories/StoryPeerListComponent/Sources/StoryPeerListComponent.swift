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

public func shouldDisplayStoriesInChatListHeader(storySubscriptions: EngineStorySubscriptions) -> Bool {
    if !storySubscriptions.items.isEmpty {
        return true
    }
    if let accountItem = storySubscriptions.accountItem, (accountItem.hasUnseen || accountItem.hasPending) {
        return true
    }
    return false
}

private func solveParabolicMotion(from sourcePoint: CGPoint, to targetPosition: CGPoint, progress: CGFloat) -> CGPoint {
    if sourcePoint.y == targetPosition.y {
        return sourcePoint.interpolate(to: targetPosition, amount: progress)
    }
    
    //(x - h)² + (y - k)² = r²
    //(x1 - h) * (x1 - h) + (y1 - k) * (y1 - k) = r * r
    //(x2 - h) * (x2 - h) + (y2 - k) * (y2 - k) = r * r
    
    let x1 = sourcePoint.y
    let y1 = sourcePoint.x
    let x2 = targetPosition.y
    let y2 = targetPosition.x
    
    let b = (x1 * x1 * y2 - x2 * x2 * y1) / (x1 * x1 - x2 * x2)
    let k = (y1 - y2) / (x1 * x1 - x2 * x2)
    
    let x = sourcePoint.y.interpolate(to: targetPosition.y, amount: progress)
    let y = k * x * x + b
    return CGPoint(x: y, y: x)
}

private let modelSpringAnimation: CABasicAnimation = {
    return makeSpringBounceAnimation("", 0.0, 88.0)
}()

public final class StoryPeerListComponent: Component {
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
    public let titleContentWidth: CGFloat
    public let maxTitleX: CGFloat
    public let useHiddenList: Bool
    public let storySubscriptions: EngineStorySubscriptions?
    public let collapseFraction: CGFloat
    public let unlocked: Bool
    public let uploadProgress: Float?
    public let peerAction: (EnginePeer?) -> Void
    public let contextPeerAction: (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void
    public let updateTitleContentOffset: (CGFloat, Transition) -> Void
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        sideInset: CGFloat,
        titleContentWidth: CGFloat,
        maxTitleX: CGFloat,
        useHiddenList: Bool,
        storySubscriptions: EngineStorySubscriptions?,
        collapseFraction: CGFloat,
        unlocked: Bool,
        uploadProgress: Float?,
        peerAction: @escaping (EnginePeer?) -> Void,
        contextPeerAction: @escaping (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void,
        updateTitleContentOffset: @escaping (CGFloat, Transition) -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sideInset = sideInset
        self.titleContentWidth = titleContentWidth
        self.maxTitleX = maxTitleX
        self.useHiddenList = useHiddenList
        self.storySubscriptions = storySubscriptions
        self.collapseFraction = collapseFraction
        self.unlocked = unlocked
        self.uploadProgress = uploadProgress
        self.peerAction = peerAction
        self.contextPeerAction = contextPeerAction
        self.updateTitleContentOffset = updateTitleContentOffset
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
        if lhs.titleContentWidth != rhs.titleContentWidth {
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
                return CGRect(origin: CGPoint(x: floor((self.containerSize.width - self.itemSize.width) * 0.5), y: self.containerInsets.top), size: self.itemSize)
            } else if self.contentSize.width < self.containerSize.width {
                let usableWidth = self.containerSize.width - self.containerInsets.left - self.containerInsets.right
                let usableSpacingWidth = usableWidth - self.itemSize.width * CGFloat(self.itemCount)
                
                var spacing = floor(usableSpacingWidth / CGFloat(self.itemCount + 1))
                spacing = min(120.0, spacing)
                return CGRect(origin: CGPoint(x: self.containerInsets.left + spacing + (self.itemSize.width + spacing) * CGFloat(index), y: self.containerInsets.top), size: self.itemSize)
            } else {
                return CGRect(origin: CGPoint(x: self.containerInsets.left + (self.itemSize.width + self.itemSpacing) * CGFloat(index), y: self.containerInsets.top), size: self.itemSize)
            }
        }
    }
    
    private final class AnimationState {
        let duration: Double
        let fromIsUnlocked: Bool
        let fromFraction: CGFloat
        let startTime: Double
        let bounce: Bool
        
        init(
            duration: Double,
            fromIsUnlocked: Bool,
            fromFraction: CGFloat,
            startTime: Double,
            bounce: Bool
        ) {
            self.duration = duration
            self.fromIsUnlocked = fromIsUnlocked
            self.fromFraction = fromFraction
            self.startTime = startTime
            self.bounce = bounce
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
    
    public final class View: UIView, UIScrollViewDelegate {
        private let collapsedButton: HighlightableButton
        private let scrollView: ScrollView
        private let scrollContainerView: UIView
        
        private var ignoreScrolling: Bool = false
        private var itemLayout: ItemLayout?
        
        private var sortedItems: [EngineStorySubscriptions.Item] = []
        
        private var visibleItems: [EnginePeer.Id: VisibleItem] = [:]
        private var visibleCollapsableItems: [EnginePeer.Id: VisibleItem] = [:]
        
        private var component: StoryPeerListComponent?
        private weak var state: EmptyComponentState?
        
        private var requestedLoadMoreToken: String?
        private let loadMoreDisposable = MetaDisposable()
        
        private var previewedItemDisposable: Disposable?
        private var previewedItemId: EnginePeer.Id?
        
        private var animationState: AnimationState?
        private var animator: ConstantDisplayLinkAnimator?
        
        private var currentFraction: CGFloat = 0.0
        
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
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.scrollView.alpha = 0.0
            self.scrollContainerView.addGestureRecognizer(self.scrollView.panGestureRecognizer)
            self.addSubview(self.scrollView)
            self.addSubview(self.scrollContainerView)
            self.addSubview(self.collapsedButton)
            
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
        }
        
        @objc private func collapsedButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.peerAction(nil)
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
                            if !self.scrollView.bounds.intersects(itemView.frame.insetBy(dx: 20.0, dy: 0.0)) {
                                self.scrollView.scrollRectToVisible(itemView.frame.insetBy(dx: -40.0, dy: 0.0), animated: false)
                            }
                        }
                    }
                }
            })
        }
        
        public func anchorForTooltip() -> (UIView, CGRect)? {
            return (self.collapsedButton, self.collapsedButton.bounds)
        }
        
        public func transitionViewForItem(peerId: EnginePeer.Id) -> (UIView, StoryContainerScreen.TransitionView)? {
            if self.collapsedButton.isUserInteractionEnabled {
                return nil
            }
            if let visibleItem = self.visibleItems[peerId], let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                if !self.scrollView.bounds.intersects(itemView.frame) {
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
            
            var hasStories: Bool = false
            if let storySubscriptions = component.storySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions) {
                hasStories = true
            }
            let _ = hasStories
            
            let collapseStartIndex: Int
            if component.useHiddenList {
                collapseStartIndex = 0
            } else if let storySubscriptions = component.storySubscriptions {
                if let accountItem = storySubscriptions.accountItem, (accountItem.hasUnseen || accountItem.hasPending) {
                    collapseStartIndex = 0
                } else {
                    collapseStartIndex = 1
                }
            } else {
                collapseStartIndex = 1
            }
            
            let collapsedItemWidth: CGFloat = 24.0
            let collapsedItemDistance: CGFloat = 14.0
            let collapsedItemCount: CGFloat = CGFloat(min(self.sortedItems.count - collapseStartIndex, 3))
            var collapsedContentWidth: CGFloat = 0.0
            if collapsedItemCount > 0 {
                collapsedContentWidth = 1.0 * collapsedItemWidth + (collapsedItemDistance) * max(0.0, collapsedItemCount - 1.0)
            }
            
            let collapseEndIndex = collapseStartIndex + max(0, Int(collapsedItemCount) - 1)
            
            var collapsedContentOrigin: CGFloat
            let collapsedItemOffsetY: CGFloat
            
            let titleContentSpacing: CGFloat = 8.0
            var combinedTitleContentWidth = component.titleContentWidth
            if !combinedTitleContentWidth.isZero {
                combinedTitleContentWidth += titleContentSpacing
            }
            let centralContentWidth: CGFloat = collapsedContentWidth + combinedTitleContentWidth
            collapsedContentOrigin = floor((itemLayout.containerSize.width - centralContentWidth) * 0.5)
            collapsedContentOrigin = min(collapsedContentOrigin, component.maxTitleX - centralContentWidth - 4.0)
            var collapsedContentOriginOffset: CGFloat = 0.0
            if itemLayout.itemCount == 1 && collapsedContentWidth <= 0.1 {
                collapsedContentOriginOffset = 4.0
            }
            collapsedContentOrigin -= collapsedContentOriginOffset
            collapsedItemOffsetY = -59.0
            
            struct CollapseState {
                var globalFraction: CGFloat
                var scaleFraction: CGFloat
                var minFraction: CGFloat
                var maxFraction: CGFloat
                var sideAlphaFraction: CGFloat
            }
            
            let targetExpandedFraction = component.collapseFraction
            
            let targetFraction: CGFloat = component.collapseFraction
            
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
                
                let timestamp = CACurrentMediaTime()
                
                let animatedGlobalFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: animationState.fromFraction, toFraction: targetFraction)
                let animatedScaleFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromScaleFraction, toFraction: targetScaleFraction)
                let animatedMinFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromMinFraction, toFraction: targetMinFraction)
                let animatedMaxFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromMaxFraction, toFraction: targetMaxFraction)
                let animatedSideAlphaFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: effectiveFromSideAlphaFraction, toFraction: targetSideAlphaFraction)
                
                collapsedState = CollapseState(
                    globalFraction: animatedGlobalFraction,
                    scaleFraction: animatedScaleFraction,
                    minFraction: animatedMinFraction,
                    maxFraction: animatedMaxFraction,
                    sideAlphaFraction: animatedSideAlphaFraction
                )
                
                var rawProgress = CGFloat((timestamp - animationState.startTime) / animationState.duration)
                rawProgress = max(0.0, min(1.0, rawProgress))
                
                if !animationState.fromIsUnlocked && animationState.bounce && itemLayout.itemCount > 3 {
                    expandBoundsFraction = animationState.interpolatedFraction(at: timestamp, effectiveFromFraction: 1.0, toFraction: 0.0)
                } else {
                    expandBoundsFraction = 0.0
                }
            } else {
                collapsedState = CollapseState(
                    globalFraction: component.collapseFraction,
                    scaleFraction: targetScaleFraction,
                    minFraction: targetMinFraction,
                    maxFraction: targetMaxFraction,
                    sideAlphaFraction: targetSideAlphaFraction
                )
                expandBoundsFraction = 0.0
            }
            
            self.currentFraction = collapsedState.globalFraction
            
            component.externalState.collapsedWidth = collapsedContentWidth
            
            let effectiveVisibleBounds = self.scrollView.bounds
            let visibleBounds = effectiveVisibleBounds.insetBy(dx: -200.0, dy: 0.0)
            
            var effectiveFirstVisibleIndex = 0
            for i in 0 ..< self.sortedItems.count {
                let regularItemFrame = itemLayout.frame(at: i)
                let isReallyVisible = effectiveVisibleBounds.intersects(regularItemFrame)
                if isReallyVisible {
                    effectiveFirstVisibleIndex = i
                    break
                }
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
                } else if collapseIndex > collapseEndIndex {
                    collapsedItemX = collapsedContentOrigin + CGFloat(collapseEndIndex) * collapsedItemDistance - collapsedItemWidth * 0.5
                } else {
                    collapsedItemX = collapsedContentOrigin + CGFloat(collapseIndex - collapseStartIndex) * collapsedItemDistance
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
                
                let minimizedItemScale: CGFloat = 24.0 / 52.0
                let minimizedMaxItemScale: CGFloat = (24.0 + 4.0) / 52.0
                
                let maximizedItemScale: CGFloat = 1.0
                
                let minItemScale = minimizedItemScale.interpolate(to: minimizedMaxItemScale, amount: collapsedState.minFraction)
                let itemScale: CGFloat = minItemScale.interpolate(to: maximizedItemScale, amount: collapsedState.maxFraction)
                
                let itemFrame: CGRect
                if isReallyVisible {
                    var adjustedRegularFrame = regularItemFrame
                    if index < collapseStartIndex {
                        adjustedRegularFrame = adjustedRegularFrame.interpolate(to: itemLayout.frame(at: effectiveFirstVisibleIndex + collapseStartIndex), amount: 0.0)
                    } else if index > collapseEndIndex {
                        adjustedRegularFrame = adjustedRegularFrame.interpolate(to: itemLayout.frame(at: effectiveFirstVisibleIndex + collapseEndIndex), amount: 0.0)
                    }
                    adjustedRegularFrame.origin.x -= effectiveVisibleBounds.minX
                    
                    let collapsedItemPosition: CGPoint = collapsedItemFrame.center.interpolate(to: collapsedMaxItemFrame.center, amount: collapsedState.minFraction)
                    
                    var itemPosition = collapsedItemPosition.interpolate(to: adjustedRegularFrame.center, amount: collapsedState.maxFraction)
                    
                    var bounceOffsetFraction = (adjustedRegularFrame.midX - itemLayout.frame(at: collapseStartIndex).midX) / itemLayout.containerSize.width
                    bounceOffsetFraction = max(-1.0, min(1.0, bounceOffsetFraction))
                    itemPosition.x += min(10.0, expandBoundsFraction * collapsedState.maxFraction * 1200.0) * bounceOffsetFraction
                    
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
                
                var hasUnseen = false
                hasUnseen = itemSet.hasUnseen
                
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
                
                let measuredItem = calculateItem(i)
                
                var leftItemFrame: CGRect?
                var rightItemFrame: CGRect?
                
                var itemAlpha: CGFloat = 1.0
                var isCollapsable: Bool = false
                var itemScale = measuredItem.itemScale
                if itemLayout.itemCount == 1 {
                    let singleScaleFactor = min(1.0, collapsedState.minFraction + collapsedState.maxFraction)
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
                    
                    if effectiveFirstVisibleIndex == 0 {
                        itemAlpha = 1.0
                    } else {
                        itemAlpha = collapsedState.sideAlphaFraction
                    }
                } else {
                    if itemLayout.itemCount == 1 {
                        itemAlpha = min(1.0, (collapsedState.minFraction + collapsedState.maxFraction) * 4.0)
                    } else {
                        itemAlpha = collapsedState.sideAlphaFraction
                    }
                }
                
                var leftNeighborDistance: CGPoint?
                var rightNeighborDistance: CGPoint?
                
                if let leftItemFrame {
                    leftNeighborDistance = CGPoint(x: abs(leftItemFrame.midX - measuredItem.itemFrame.midX), y: leftItemFrame.minY - measuredItem.itemFrame.minY)
                }
                if let rightItemFrame {
                    rightNeighborDistance = CGPoint(x: abs(rightItemFrame.midX - measuredItem.itemFrame.midX), y: rightItemFrame.minY - measuredItem.itemFrame.minY)
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: AnyComponent(StoryPeerListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        peer: peer,
                        hasUnseen: hasUnseen,
                        hasUnseenCloseFriendsItems: hasUnseenCloseFriendsItems,
                        hasItems: hasItems,
                        ringAnimation: itemRingAnimation,
                        collapseFraction: isReallyVisible ? (1.0 - collapsedState.maxFraction) : 0.0,
                        scale: itemScale,
                        collapsedWidth: collapsedItemWidth,
                        expandedAlphaFraction: collapsedState.sideAlphaFraction,
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
                
                var hasUnseen = false
                hasUnseen = itemSet.hasUnseen
                
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
                var itemScale = measuredItem.itemScale
                if itemLayout.itemCount == 1 {
                    let singleScaleFactor = min(1.0, collapsedState.minFraction + collapsedState.maxFraction)
                    itemScale = 0.001 * (1.0 - singleScaleFactor) + itemScale * singleScaleFactor
                }
                
                if i >= collapseStartIndex && i <= collapseEndIndex {
                    isCollapsable = true
                    
                    if i != collapseStartIndex {
                        leftItemFrame = calculateItem(collapseIndex - 1).itemFrame
                    }
                    if i != collapseEndIndex {
                        rightItemFrame = calculateItem(collapseIndex + 1).itemFrame
                    }
                    
                    if effectiveFirstVisibleIndex == 0 {
                        itemAlpha = 0.0
                    } else {
                        itemAlpha = 1.0 - collapsedState.sideAlphaFraction
                    }
                } else {
                    if itemLayout.itemCount == 1 {
                        itemAlpha = min(1.0, (collapsedState.minFraction + collapsedState.maxFraction) * 4.0)
                    } else {
                        itemAlpha = collapsedState.sideAlphaFraction
                    }
                }
                
                var leftNeighborDistance: CGPoint?
                var rightNeighborDistance: CGPoint?
                
                if let leftItemFrame {
                    leftNeighborDistance = CGPoint(x: abs(leftItemFrame.midX - measuredItem.itemFrame.midX), y: leftItemFrame.minY - measuredItem.itemFrame.minY)
                }
                if let rightItemFrame {
                    rightNeighborDistance = CGPoint(x: abs(rightItemFrame.midX - measuredItem.itemFrame.midX), y: rightItemFrame.minY - measuredItem.itemFrame.minY)
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: AnyComponent(StoryPeerListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        peer: peer,
                        hasUnseen: hasUnseen,
                        hasUnseenCloseFriendsItems: hasUnseenCloseFriendsItems,
                        hasItems: hasItems,
                        ringAnimation: itemRingAnimation,
                        collapseFraction: 1.0 - collapsedState.maxFraction,
                        scale: itemScale,
                        collapsedWidth: collapsedItemWidth,
                        expandedAlphaFraction: collapsedState.sideAlphaFraction,
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
                    
                    itemView.updateIsPreviewing(isPreviewing: self.previewedItemId == itemSet.peer.id)
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
            
            transition.setFrame(view: self.collapsedButton, frame: CGRect(origin: CGPoint(x: collapsedContentOrigin - 4.0, y: 6.0 - 59.0), size: CGSize(width: collapsedContentWidth + 4.0, height: 44.0)))
            
            let defaultCollapsedTitleOffset = floor((itemLayout.containerSize.width - component.titleContentWidth) * 0.5)
            
            var targetCollapsedTitleOffset: CGFloat = collapsedContentOrigin + collapsedContentOriginOffset + collapsedContentWidth + titleContentSpacing
            if itemLayout.itemCount == 1 && collapsedContentWidth <= 0.1 {
                let singleScaleFactor = min(1.0, collapsedState.minFraction)
                targetCollapsedTitleOffset += singleScaleFactor * 4.0
            }
            
            let collapsedTitleOffset = targetCollapsedTitleOffset - defaultCollapsedTitleOffset
            
            let titleMinContentOffset: CGFloat = collapsedTitleOffset.interpolate(to: collapsedTitleOffset + 12.0, amount: collapsedState.minFraction)
            let titleContentOffset: CGFloat = titleMinContentOffset.interpolate(to: 0.0 as CGFloat, amount: collapsedState.maxFraction)
            
            component.updateTitleContentOffset(titleContentOffset, transition)
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.alpha.isZero {
                return nil
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
                    duration = 0.3
                } else {
                    duration = 0.25
                }
                self.animationState = AnimationState(duration: duration * UIView.animationDurationFactor(), fromIsUnlocked: previousComponent.unlocked, fromFraction: self.currentFraction, startTime: timestamp, bounce: animationHint?.bounce ?? true)
            }
            
            if let animationState = self.animationState {
                if animationState.isFinished(at: timestamp) {
                    self.animationState = nil
                }
            }
            
            if let _ = self.animationState {
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
                itemSpacing: 24.0,
                itemCount: self.sortedItems.count
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: CGSize(width: availableSize.width, height: availableSize.height + 4.0)))
            transition.setFrame(view: self.scrollContainerView, frame: CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: CGSize(width: availableSize.width, height: availableSize.height + 4.0)))
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
