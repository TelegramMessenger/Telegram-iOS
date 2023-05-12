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
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let state: StoryListContext.State?
    public let peerAction: (EnginePeer) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        state: StoryListContext.State?,
        peerAction: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.state = state
        self.peerAction = peerAction
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
        if lhs.state != rhs.state {
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
        private let scrollView: ScrollView
        
        private var ignoreScrolling: Bool = false
        private var itemLayout: ItemLayout?
        
        private var sortedItemSets: [StoryListContext.PeerItemSet] = []
        private var visibleItems: [EnginePeer.Id: VisibleItem] = [:]
        
        private var component: StoryPeerListComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
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
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func transitionViewForItem(peerId: EnginePeer.Id) -> UIView? {
            if let visibleItem = self.visibleItems[peerId], let itemView = visibleItem.view.view as? StoryPeerListItemComponent.View {
                return itemView.transitionView()
            }
            return nil
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
            
            var validIds: [EnginePeer.Id] = []
            for i in 0 ..< self.sortedItemSets.count {
                let itemSet = self.sortedItemSets[i]
                guard let peer = itemSet.peer else {
                    continue
                }
                validIds.append(itemSet.peerId)
                
                let visibleItem: VisibleItem
                var itemTransition = transition
                if let current = self.visibleItems[itemSet.peerId] {
                    visibleItem = current
                } else {
                    itemTransition = .immediate
                    visibleItem = VisibleItem()
                    self.visibleItems[itemSet.peerId] = visibleItem
                }
                
                var hasUnseen = false
                if peer.id != component.context.account.peerId {
                    for item in itemSet.items {
                        if !item.isSeen {
                            hasUnseen = true
                        }
                    }
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: AnyComponent(StoryPeerListItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        peer: peer,
                        hasUnseen: hasUnseen,
                        action: component.peerAction
                    )),
                    environment: {},
                    containerSize: itemLayout.itemSize
                )
                
                let itemFrame = itemLayout.frame(at: i)
                
                if let itemView = visibleItem.view.view {
                    if itemView.superview == nil {
                        self.scrollView.addSubview(itemView)
                    }
                    itemTransition.setFrame(view: itemView, frame: itemFrame)
                }
            }
            
            var removedIds: [EnginePeer.Id] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    if let itemView = visibleItem.view.view {
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removedIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        func update(component: StoryPeerListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            self.sortedItemSets.removeAll(keepingCapacity: true)
            if let state = component.state {
                if let myIndex = state.itemSets.firstIndex(where: { $0.peerId == component.context.account.peerId }) {
                    self.sortedItemSets.append(state.itemSets[myIndex])
                }
                for itemSet in state.itemSets {
                    if itemSet.peerId == component.context.account.peerId {
                        continue
                    }
                    self.sortedItemSets.append(itemSet)
                }
            }
            
            let itemLayout = ItemLayout(
                containerSize: availableSize,
                containerInsets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 10.0),
                itemSize: CGSize(width: 60.0, height: 77.0),
                itemSpacing: 24.0,
                itemCount: self.sortedItemSets.count
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
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
