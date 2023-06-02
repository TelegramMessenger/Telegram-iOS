import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData

public final class StoryPeerListComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var collapsedWidth: CGFloat = 0.0
        
        public init() {
        }
    }
    
    public let externalState: ExternalState
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let storySubscriptions: EngineStorySubscriptions?
    public let collapseFraction: CGFloat
    public let peerAction: (EnginePeer?) -> Void
    public let contextPeerAction: (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        storySubscriptions: EngineStorySubscriptions?,
        collapseFraction: CGFloat,
        peerAction: @escaping (EnginePeer?) -> Void,
        contextPeerAction: @escaping (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.storySubscriptions = storySubscriptions
        self.collapseFraction = collapseFraction
        self.peerAction = peerAction
        self.contextPeerAction = contextPeerAction
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
        if lhs.storySubscriptions != rhs.storySubscriptions {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
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
            return CGRect(origin: CGPoint(x: self.containerInsets.left + (self.itemSize.width + self.itemSpacing) * CGFloat(index), y: self.containerInsets.top), size: self.itemSize)
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate {
        private let collapsedButton: HighlightableButton
        private let scrollView: ScrollView
        
        private var ignoreScrolling: Bool = false
        private var itemLayout: ItemLayout?
        
        private var sortedItems: [EngineStorySubscriptions.Item] = []
        private var visibleItems: [EnginePeer.Id: VisibleItem] = [:]
        
        private var component: StoryPeerListComponent?
        private weak var state: EmptyComponentState?
        
        private var requestedLoadMoreToken: String?
        private let loadMoreDisposable = MetaDisposable()
        
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
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
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
        }
        
        @objc private func collapsedButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.peerAction(nil)
        }
        
        public func transitionViewForItem(peerId: EnginePeer.Id) -> UIView? {
            if self.collapsedButton.isUserInteractionEnabled {
                return nil
            }
            if let visibleItem = self.visibleItems[peerId], let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                return itemView.transitionView()
            }
            return nil
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate, keepVisibleUntilCompletion: false)
            }
        }
        
        private func updateScrolling(transition: Transition, keepVisibleUntilCompletion: Bool) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var hasStories: Bool = false
            if let storySubscriptions = component.storySubscriptions, !storySubscriptions.items.isEmpty {
                hasStories = true
            }
            let _ = hasStories
            
            let collapseStartIndex = 1
            
            let collapsedItemWidth: CGFloat = 24.0
            let collapsedItemDistance: CGFloat = 14.0
            let collapsedItemCount: CGFloat = CGFloat(min(self.sortedItems.count - collapseStartIndex, 3))
            var collapsedContentWidth: CGFloat = 0.0
            if collapsedItemCount > 0 {
                collapsedContentWidth = 1.0 * collapsedItemWidth + (collapsedItemDistance) * max(0.0, collapsedItemCount - 1.0)
            }
            
            let collapseEndIndex = collapseStartIndex + max(0, Int(collapsedItemCount) - 1)
            
            let collapsedContentOrigin: CGFloat
            let collapsedItemOffsetY: CGFloat
            let itemScale: CGFloat
            
            collapsedContentOrigin = floor((itemLayout.containerSize.width - collapsedContentWidth) * 0.5)
            itemScale = 1.0
            collapsedItemOffsetY = 0.0
            
            component.externalState.collapsedWidth = collapsedContentWidth
            
            let visibleBounds = self.scrollView.bounds
            
            var validIds: [EnginePeer.Id] = []
            for i in 0 ..< self.sortedItems.count {
                let itemSet = self.sortedItems[i]
                let peer = itemSet.peer
                
                let regularItemFrame = itemLayout.frame(at: i)
                if !visibleBounds.intersects(regularItemFrame) {
                    /*if keepVisibleUntilCompletion && self.visibleItems[itemSet.peerId] != nil {
                    } else {*/
                        continue
                    //}
                }
                
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
                
                var hasItems = true
                var itemProgress: CGFloat?
                if peer.id == component.context.account.peerId {
                    itemProgress = nil
                    if let storySubscriptions = component.storySubscriptions, let accountItem = storySubscriptions.accountItem {
                        hasItems = accountItem.storyCount != 0
                    } else {
                        hasItems = false
                    }
                    //itemProgress = component.state?.uploadProgress
                    //itemProgress = 0.0
                }
                
                let collapsedItemFrame = CGRect(origin: CGPoint(x: collapsedContentOrigin + CGFloat(i - collapseStartIndex) * collapsedItemDistance, y: regularItemFrame.minY + collapsedItemOffsetY), size: CGSize(width: collapsedItemWidth, height: regularItemFrame.height))
                
                let itemFrame = regularItemFrame.interpolate(to: collapsedItemFrame, amount: component.collapseFraction)
                
                var leftItemFrame: CGRect?
                var rightItemFrame: CGRect?
                
                var itemAlpha: CGFloat = 1.0
                
                if i >= collapseStartIndex && i <= collapseEndIndex {
                    if i != collapseStartIndex {
                        let regularLeftItemFrame = itemLayout.frame(at: i - 1)
                        let collapsedLeftItemFrame = CGRect(origin: CGPoint(x: collapsedContentOrigin + CGFloat(i - collapseStartIndex - 1) * collapsedItemDistance, y: regularLeftItemFrame.minY), size: CGSize(width: collapsedItemWidth, height: regularLeftItemFrame.height))
                        leftItemFrame = regularLeftItemFrame.interpolate(to: collapsedLeftItemFrame, amount: component.collapseFraction)
                    }
                    if i != collapseEndIndex {
                        let regularRightItemFrame = itemLayout.frame(at: i - 1)
                        let collapsedRightItemFrame = CGRect(origin: CGPoint(x: collapsedContentOrigin + CGFloat(i - collapseStartIndex - 1) * collapsedItemDistance, y: regularRightItemFrame.minY), size: CGSize(width: collapsedItemWidth, height: regularRightItemFrame.height))
                        rightItemFrame = regularRightItemFrame.interpolate(to: collapsedRightItemFrame, amount: component.collapseFraction)
                    }
                } else {
                    itemAlpha = pow(1.0 - component.collapseFraction, 1.5)
                }
                
                var leftNeighborDistance: CGFloat?
                var rightNeighborDistance: CGFloat?
                
                if let leftItemFrame {
                    leftNeighborDistance = abs(leftItemFrame.midX - itemFrame.midX)
                }
                if let rightItemFrame {
                    rightNeighborDistance = abs(rightItemFrame.midX - itemFrame.midX)
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: AnyComponent(StoryPeerListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        peer: peer,
                        hasUnseen: hasUnseen,
                        hasItems: hasItems,
                        progress: itemProgress,
                        collapseFraction: component.collapseFraction,
                        collapsedWidth: collapsedItemWidth,
                        leftNeighborDistance: leftNeighborDistance,
                        rightNeighborDistance: rightNeighborDistance,
                        action: component.peerAction,
                        contextGesture: component.contextPeerAction
                    )),
                    environment: {},
                    containerSize: itemLayout.itemSize
                )
                
                if let itemView = visibleItem.view.view {
                    if itemView.superview == nil {
                        self.scrollView.addSubview(itemView)
                    }
                    itemView.layer.zPosition = 1000.0 - CGFloat(i) * 0.01
                    itemTransition.setFrame(view: itemView, frame: itemFrame)
                    itemTransition.setAlpha(view: itemView, alpha: itemAlpha)
                    itemTransition.setScale(view: itemView, scale: itemScale)
                }
            }
            
            var removedIds: [EnginePeer.Id] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    if let itemView = visibleItem.view.view {
                        if keepVisibleUntilCompletion && !transition.animation.isImmediate {
                            transition.attachAnimation(view: itemView, id: "keep", completion: { [weak itemView] _ in
                                itemView?.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removedIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            transition.setFrame(view: self.collapsedButton, frame: CGRect(origin: CGPoint(x: collapsedContentOrigin, y: 6.0), size: CGSize(width: collapsedContentWidth, height: 44.0 - 4.0)))
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if self.collapsedButton.isUserInteractionEnabled {
                if result !== self.collapsedButton {
                    return nil
                }
            } else {
                if !result.isDescendant(of: self.scrollView) {
                    return nil
                }
            }
            return result
        }
        
        func update(component: StoryPeerListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if self.component != nil {
                if component.collapseFraction != 0.0 && self.scrollView.bounds.minX != 0.0 {
                    self.ignoreScrolling = true
                    
                    let scrollingDistance = self.scrollView.bounds.minX
                    self.scrollView.bounds = CGRect(origin: CGPoint(), size: self.scrollView.bounds.size)
                    let tempTransition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                    self.updateScrolling(transition: tempTransition, keepVisibleUntilCompletion: true)
                    tempTransition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: scrollingDistance, y: 0.0), to: CGPoint(), additive: true)
                    
                    self.ignoreScrolling = false
                }
            }
            
            self.component = component
            self.state = state
            
            if let storySubscriptions = component.storySubscriptions, let hasMoreToken = storySubscriptions.hasMoreToken {
                if self.requestedLoadMoreToken != hasMoreToken {
                    self.requestedLoadMoreToken = hasMoreToken
                    if let storySubscriptionsContext = component.context.account.storySubscriptionsContext {
                        storySubscriptionsContext.loadMore()
                    }
                }
            }
            
            self.collapsedButton.isUserInteractionEnabled = component.collapseFraction >= 1.0 - .ulpOfOne
            
            self.sortedItems.removeAll(keepingCapacity: true)
            if let storySubscriptions = component.storySubscriptions {
                if let accountItem = storySubscriptions.accountItem {
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
                containerInsets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 10.0),
                itemSize: CGSize(width: 60.0, height: 77.0),
                itemSpacing: 24.0,
                itemCount: self.sortedItems.count
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            if self.scrollView.contentSize != itemLayout.contentSize {
                self.scrollView.contentSize = itemLayout.contentSize
            }
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition, keepVisibleUntilCompletion: false)
            
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
