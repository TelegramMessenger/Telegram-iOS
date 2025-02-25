import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import GiftItemComponent
import PlainButtonComponent
import TelegramPresentationData
import AccountContext

final class GiftListItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let gifts: [StarGift.UniqueGift]
    let selectedId: Int64?
    let selectionUpdated: (StarGift.UniqueGift) -> Void
    let tag: AnyObject?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        gifts: [StarGift.UniqueGift],
        selectedId: Int64?,
        selectionUpdated: @escaping (StarGift.UniqueGift) -> Void,
        tag: AnyObject?
    ) {
        self.context = context
        self.theme = theme
        self.gifts = gifts
        self.selectedId = selectedId
        self.selectionUpdated = selectionUpdated
        self.tag = tag
    }
    
    static func ==(lhs: GiftListItemComponent, rhs: GiftListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.gifts != rhs.gifts {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }
    
    final class View: UIView, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private var giftItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var component: GiftListItemComponent?
        private var state: EmptyComponentState?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var visibleBounds: CGRect?
        func updateVisibleBounds(_ bounds: CGRect) {
            self.visibleBounds = bounds
            self.state?.updated()
        }
                
        func update(component: GiftListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                  
            let sideInset: CGFloat = 16.0
            let topInset: CGFloat = 13.0
            let spacing: CGFloat = 10.0
            let itemsInRow = 3
            let rowsCount = Int(ceil(CGFloat(component.gifts.count) / CGFloat(itemsInRow)))
            
            let itemWidth = floorToScreenPixels((availableSize.width - sideInset * 2.0 - spacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow))
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: itemWidth, height: itemWidth))

            let contentHeight = topInset * 2.0 + itemWidth * CGFloat(rowsCount) + spacing * CGFloat(rowsCount - 1)
            
            var index: Int32 = 0
            for gift in component.gifts {
                var isVisible = false
                if let visibleBounds = self.visibleBounds, visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                if isVisible {
                    let id = gift.id
                    let itemId = AnyHashable(id)
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.giftItems[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        self.giftItems[itemId] = visibleItem
                        itemTransition = .immediate
                    }
                                        
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: component.theme,
                                        strings: component.context.sharedContext.currentPresentationData.with { $0 }.strings,
                                        peer: nil,
                                        subject: .uniqueGift(gift: gift),
                                        ribbon: nil,
                                        isHidden: false,
                                        isSelected: gift.id == component.selectedId,
                                        mode: .grid
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.selectionUpdated(gift)
                                },
                                animateAlpha: false
                            )
                        ),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.addSubview(itemView)
                            
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                itemFrame.origin.x += itemFrame.width + spacing
                if itemFrame.maxX > availableSize.width {
                    itemFrame.origin.x = sideInset
                    itemFrame.origin.y += itemFrame.height + spacing
                }
                index += 1
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.giftItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeIds {
                self.giftItems.removeValue(forKey: id)
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
