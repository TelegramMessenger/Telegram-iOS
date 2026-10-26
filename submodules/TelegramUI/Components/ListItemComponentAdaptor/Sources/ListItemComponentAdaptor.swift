import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import ListSectionComponent

public protocol _ListItemComponentAdaptorItemGenerator: AnyObject, Equatable {
    func item() -> ListViewItem
}

private final class HighlightTrackingTapGestureRecognizer: UITapGestureRecognizer {
    var highlightChanged: ((CGPoint?, Bool) -> Void)?

    private var highlightedPoint: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            let point = touch.location(in: self.view)
            self.highlightedPoint = point
            self.highlightChanged?(point, true)
        }

        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        self.clearHighlight()

        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        self.clearHighlight()

        super.touchesCancelled(touches, with: event)
    }

    override func reset() {
        self.clearHighlight()

        super.reset()
    }

    func cancelHighlight() {
        self.clearHighlight()
    }

    private func clearHighlight() {
        if let highlightedPoint = self.highlightedPoint {
            self.highlightedPoint = nil
            self.highlightChanged?(highlightedPoint, false)
        }
    }
}

public final class ListItemComponentAdaptor: Component {
    public typealias ItemGenerator = _ListItemComponentAdaptorItemGenerator

    public enum ActionMode {
        case button
        case gesture
    }
    
    private let itemGenerator: AnyObject
    private let isEqualImpl: (AnyObject) -> Bool
    private let itemImpl: () -> ListViewItem
    private let params: ListViewItemLayoutParams
    private let separatorInset: CGFloat
    private let separatorAlpha: CGFloat
    private let action: (() -> Void)?
    private let actionMode: ActionMode
    private let tag: AnyObject?

    public init<ItemGeneratorType: ItemGenerator>(
        itemGenerator: ItemGeneratorType,
        params: ListViewItemLayoutParams,
        separatorInset: CGFloat = 0.0,
        separatorAlpha: CGFloat = 1.0,
        action: (() -> Void)? = nil,
        actionMode: ActionMode = .button,
        tag: AnyObject? = nil
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
        self.separatorInset = separatorInset
        self.separatorAlpha = separatorAlpha
        self.action = action
        self.actionMode = actionMode
        self.tag = tag
    }
    
    public static func ==(lhs: ListItemComponentAdaptor, rhs: ListItemComponentAdaptor) -> Bool {
        if !lhs.isEqualImpl(rhs.itemGenerator) {
            return false
        }
        if lhs.params != rhs.params {
            return false
        }
        if lhs.separatorInset != rhs.separatorInset {
            return false
        }
        if lhs.separatorAlpha != rhs.separatorAlpha {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        if lhs.actionMode != rhs.actionMode {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }
    
    public final class View: UIView, ComponentTaggedView, ListSectionComponent.ChildView {
        private var button: HighlightTrackingButton?
        private var tapGestureRecognizer: HighlightTrackingTapGestureRecognizer?
        public var itemNode: ListViewItemNode?
        
        private var component: ListItemComponentAdaptor?

        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var enumerateSiblings: (((UIView) -> Void) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        public private(set) var separatorAlpha: CGFloat = 1.0
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action?()
        }

        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard case .ended = recognizer.state, let component = self.component else {
                return
            }
            component.action?()
        }

        private func updateActionControls(component: ListItemComponentAdaptor, itemNode: ListViewItemNode, size: CGSize, transition: ComponentTransition) {
            itemNode.isUserInteractionEnabled = component.action == nil || component.actionMode == .gesture
            if component.action != nil && component.actionMode == .button {
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

                transition.setFrame(view: button, frame: CGRect(origin: CGPoint(), size: size))
            } else if let button = self.button {
                self.button = nil
                button.removeFromSuperview()
            }

            if component.action != nil && component.actionMode == .gesture {
                if self.tapGestureRecognizer == nil {
                    let tapGestureRecognizer = HighlightTrackingTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
                    tapGestureRecognizer.cancelsTouchesInView = false
                    tapGestureRecognizer.highlightChanged = { [weak self] point, isHighlighted in
                        guard let self, let itemNode = self.itemNode else {
                            return
                        }
                        let itemPoint: CGPoint
                        if let point {
                            itemPoint = self.convert(point, to: itemNode.view)
                        } else {
                            itemPoint = itemNode.bounds.center
                        }
                        itemNode.setHighlighted(isHighlighted, at: itemPoint, animated: !isHighlighted)
                    }
                    self.tapGestureRecognizer = tapGestureRecognizer
                    self.addGestureRecognizer(tapGestureRecognizer)
                }
            } else if let tapGestureRecognizer = self.tapGestureRecognizer {
                self.tapGestureRecognizer = nil
                tapGestureRecognizer.cancelHighlight()
                self.removeGestureRecognizer(tapGestureRecognizer)
            }
        }
        
        func update(component: ListItemComponentAdaptor, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.separatorInset = component.separatorInset
            self.separatorAlpha = component.separatorAlpha
            
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
                    neighbors: .none,
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
                        
                        apply(ListViewItemApply())
                    }
                )
                
                if let resultSize {
                    self.updateActionControls(component: component, itemNode: itemNode, size: resultSize, transition: transition)
                    
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
                    neighbors: .none,
                    completion: { result, apply in
                        itemNode = result
                        apply().1(ListViewItemApply())
                    }
                )
                if let itemNode {
                    self.updateActionControls(component: component, itemNode: itemNode, size: itemNode.bounds.size, transition: transition)
                    
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
