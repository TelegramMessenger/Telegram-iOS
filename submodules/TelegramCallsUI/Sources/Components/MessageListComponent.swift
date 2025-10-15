import Foundation
import Display
import UIKit
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import ReactionSelectionNode

final class MessageListComponent: Component {
    struct Item: Equatable {
        let id: AnyHashable
        let icon: MessageItemComponent.Icon
        let isNotification: Bool
        let text: String
        let entities: [MessageTextEntity]
    }
    
    class SendActionTransition {
        public let randomId: Int64
        public let textSnapshotView: UIView
        public let globalFrame: CGRect
        public let cornerRadius: CGFloat
        
        init(randomId: Int64, textSnapshotView: UIView, globalFrame: CGRect, cornerRadius: CGFloat) {
            self.randomId = randomId
            self.textSnapshotView = textSnapshotView
            self.globalFrame = globalFrame
            self.cornerRadius = cornerRadius
        }
    }
    
    private let context: AccountContext
    private let items: [Item]
    private let availableReactions: [ReactionItem]?
    private let sendActionTransition: SendActionTransition?
    private let openPeer: (EnginePeer) -> Void
    
    init(
        context: AccountContext,
        items: [Item],
        availableReactions: [ReactionItem]?,
        sendActionTransition: SendActionTransition?,
        openPeer: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.items = items
        self.availableReactions = availableReactions
        self.sendActionTransition = sendActionTransition
        self.openPeer = openPeer
    }
    
    static func == (lhs: MessageListComponent, rhs: MessageListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if (lhs.availableReactions ?? []).isEmpty != (rhs.availableReactions ?? []).isEmpty {
            return false
        }
        if lhs.sendActionTransition !== rhs.sendActionTransition {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private var component: MessageListComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating = false
        
        private var nextSendActionTransition: MessageListComponent.SendActionTransition?
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private let topInset: CGFloat = 8.0
        private let bottomInset: CGFloat = 8.0
        private let itemSpacing: CGFloat = 6.0
        
        private var ignoreScrolling: Bool = false
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = false
            self.scrollView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            
        }
        
        private func isAtBottom(tolerance: CGFloat = 1.0) -> Bool {
            let bottomY = -self.scrollView.adjustedContentInset.top
            return self.scrollView.contentOffset.y <= bottomY + tolerance
        }

        private func scrollToBottom(animated: Bool) {
            let targetY = -self.scrollView.adjustedContentInset.top
            if animated {
                self.scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
            } else {
                self.scrollView.contentOffset = CGPoint(x: 0, y: targetY)
            }
        }
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            for (_, itemView) in self.itemViews {
                if let view = itemView.view, view.point(inside: self.convert(point, to: view), with: event) {
                    return true
                }
            }
            return false
        }
        
        func update(component: MessageListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            if let _ = component.sendActionTransition {
                self.nextSendActionTransition = component.sendActionTransition
            }
            
            let originalTransition = transition
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: availableSize))
            
            let previousContentHeight = self.scrollView.contentSize.height
            let wasAtBottom = self.isAtBottom(tolerance: 1.0)
            
            let maxWidth: CGFloat = min(availableSize.width - 16.0, 330.0)
            
            var measured: [(id: AnyHashable, size: CGSize, item: MessageListComponent.Item, itemTransition: ComponentTransition)] = []
            measured.reserveCapacity(component.items.count)
            
            for item in component.items {
                var itemTransition = transition
                let key = item.id
                let container = self.itemViews[key] ?? {
                    itemTransition = .immediate
                    let v = ComponentView<Empty>()
                    self.itemViews[key] = v
                    return v
                }()
                
                let size = container.update(
                    transition: transition,
                    component: AnyComponent(MessageItemComponent(
                        context: component.context,
                        icon: item.icon,
                        isNotification: item.isNotification,
                        text: item.text,
                        entities: item.entities,
                        availableReactions: component.availableReactions,
                        openPeer: component.openPeer
                    )),
                    environment: {},
                    containerSize: CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
                )
                measured.append((id: key, size: size, item: item, itemTransition: itemTransition))
            }
            
            let itemsHeight: CGFloat = measured.reduce(0) { $0 + $1.size.height } +
                CGFloat(max(0, measured.count - 1)) * self.itemSpacing
            let contentHeight = self.topInset + itemsHeight + self.bottomInset

            var y = self.bottomInset

            var validKeys = Set<AnyHashable>()
            for (index, entry) in measured.enumerated() {
                validKeys.insert(entry.id)
                if let itemView = self.itemViews[entry.id]?.view {
                    var customAnimation = false
                    if let nextSendActionTransition = self.nextSendActionTransition, entry.id == AnyHashable(nextSendActionTransition.randomId) {
                        customAnimation = true
                    }
                    let itemFrame = CGRect(
                        origin: CGPoint(x: floor((availableSize.width - entry.size.width) / 2.0), y: y),
                        size: entry.size
                    )
                    
                    if itemView.superview == nil {
                        if !originalTransition.animation.isImmediate && !customAnimation {
                            originalTransition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                            originalTransition.animateScale(view: itemView, from: 0.01, to: 1.0)
                        }
                        if customAnimation, let nextSendActionTransition = self.nextSendActionTransition {
                            self.nextSendActionTransition = nil
                            itemView.frame = itemFrame
                            if let itemView = itemView as? MessageItemComponent.View {
                                itemView.isHidden = true
                                Queue.mainQueue().justDispatch {
                                    itemView.animateFrom(globalFrame: nextSendActionTransition.globalFrame, cornerRadius: nextSendActionTransition.cornerRadius, textSnapshotView: nextSendActionTransition.textSnapshotView, transition: originalTransition)
                                    itemView.isHidden = false
                                }
                            }
                        }
                        self.scrollView.addSubview(itemView)
                    }
                    entry.itemTransition.setFrame(view: itemView, frame: itemFrame)
                }
                y += entry.size.height
                if index != measured.count - 1 { y += self.itemSpacing }
            }

            let finalContentHeight = max(availableSize.height, contentHeight)
            self.scrollView.contentSize = CGSize(width: availableSize.width, height: finalContentHeight)
            
            let delta = self.scrollView.contentSize.height - previousContentHeight
            if !wasAtBottom && abs(delta) > .ulpOfOne {
                self.scrollView.contentOffset.y += delta
            } else if wasAtBottom {
                self.scrollToBottom(animated: false)
            }
            
            if self.itemViews.count > validKeys.count {
                let toRemove = self.itemViews.keys.filter { !validKeys.contains($0) }
                for key in toRemove {
                    if let itemView = self.itemViews[key]?.view {
                        if transition.animation.isImmediate {
                            itemView.removeFromSuperview()
                        } else {
                            transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                            transition.setScale(view: itemView, scale: 0.01)
                        }
                    }
                    self.itemViews.removeValue(forKey: key)
                }
            }
            
            if wasAtBottom {
                self.scrollToBottom(animated: false)
            }
            
            return availableSize
        }
    }
    
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
