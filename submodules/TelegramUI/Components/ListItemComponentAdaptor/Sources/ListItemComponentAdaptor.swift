import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

public protocol _ListItemComponentAdaptorItemGenerator: AnyObject, Equatable {
    func item() -> ListViewItem
}

public final class ListItemComponentAdaptor: Component {
    public typealias ItemGenerator = _ListItemComponentAdaptorItemGenerator
    
    private let itemGenerator: AnyObject
    private let isEqualImpl: (AnyObject) -> Bool
    private let itemImpl: () -> ListViewItem
    private let params: ListViewItemLayoutParams
    private let action: (() -> Void)?

    public init<ItemGeneratorType: ItemGenerator>(
        itemGenerator: ItemGeneratorType,
        params: ListViewItemLayoutParams,
        action: (() -> Void)? = nil
    ) {
        self.itemGenerator = itemGenerator
        self.isEqualImpl = { other in
            if let other = other as? ItemGeneratorType, itemGenerator == other {
                return true
            } else {
                return false
            }
        }
        self.itemImpl = {
            return itemGenerator.item()
        }
        self.params = params
        self.action = action
    }
    
    public static func ==(lhs: ListItemComponentAdaptor, rhs: ListItemComponentAdaptor) -> Bool {
        if !lhs.isEqualImpl(rhs.itemGenerator) {
            return false
        }
        if lhs.params != rhs.params {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var button: HighlightTrackingButton?
        public var itemNode: ListViewItemNode?
        
        private var component: ListItemComponentAdaptor?
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action?()
        }
        
        func update(component: ListItemComponentAdaptor, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let item = component.itemImpl()
            
            if let itemNode = self.itemNode {
                let mappedAnimation: ListViewItemUpdateAnimation
                switch transition.animation {
                case .none:
                    mappedAnimation = .None
                case let .curve(duration, curve):
                    mappedAnimation = .System(duration: duration, transition: ControlledTransition(duration: duration, curve: curve.containedViewLayoutTransitionCurve, interactive: false))
                }
                
                var resultSize: CGSize?
                item.updateNode(
                    async: { f in f() },
                    node: { return itemNode },
                    params: component.params,
                    previousItem: nil,
                    nextItem: nil,
                    animation: mappedAnimation,
                    completion: { [weak itemNode] layout, apply in
                        resultSize = layout.size
                        
                        guard let itemNode else {
                            return
                        }
                        
                        let nodeFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height))
                        
                        itemNode.contentSize = layout.contentSize
                        itemNode.insets = layout.insets
                        itemNode.frame = nodeFrame
                        
                        apply(ListViewItemApply(isOnScreen: true))
                    }
                )
                
                if let resultSize {
                    itemNode.isUserInteractionEnabled = component.action == nil
                    if component.action != nil {
                        let button: HighlightTrackingButton
                        if let current = self.button {
                            button = current
                        } else {
                            button = HighlightTrackingButton()
                            self.button = button
                            self.addSubview(button)
                            button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
                            button.highligthedChanged = { [weak self] isHighlighted in
                                guard let self, let itemNode = self.itemNode else {
                                    return
                                }
                                itemNode.setHighlighted(isHighlighted, at: itemNode.bounds.center, animated: !isHighlighted)
                            }
                        }
                        
                        transition.setFrame(view: button, frame: CGRect(origin: CGPoint(), size: resultSize))
                    } else if let button = self.button {
                        self.button = nil
                        button.removeFromSuperview()
                    }
                    
                    transition.setFrame(view: itemNode.view, frame: CGRect(origin: CGPoint(), size: resultSize))
                    return resultSize
                } else {
                    #if DEBUG
                    assertionFailure()
                    #endif
                    return self.bounds.size
                }
            } else {
                var itemNode: ListViewItemNode?
                item.nodeConfiguredForParams(
                    async: { f in f() },
                    params: component.params,
                    synchronousLoads: true,
                    previousItem: nil,
                    nextItem: nil,
                    completion: { result, apply in
                        itemNode = result
                        apply().1(ListViewItemApply(isOnScreen: true))
                    }
                )
                if let itemNode {
                    itemNode.isUserInteractionEnabled = component.action == nil
                    if component.action != nil {
                        let button: HighlightTrackingButton
                        if let current = self.button {
                            button = current
                        } else {
                            button = HighlightTrackingButton()
                            self.button = button
                            self.addSubview(button)
                            button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
                            button.highligthedChanged = { [weak self] isHighlighted in
                                guard let self, let itemNode = self.itemNode else {
                                    return
                                }
                                itemNode.setHighlighted(isHighlighted, at: itemNode.bounds.center, animated: !isHighlighted)
                            }
                        }
                        transition.setFrame(view: button, frame: CGRect(origin: CGPoint(), size: itemNode.bounds.size))
                    } else if let button = self.button {
                        self.button = nil
                        button.removeFromSuperview()
                    }
                    
                    self.itemNode = itemNode
                    self.addSubnode(itemNode)
                    
                    return itemNode.bounds.size
                } else {
                    #if DEBUG
                    assertionFailure()
                    #endif
                    return self.bounds.size
                }
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
