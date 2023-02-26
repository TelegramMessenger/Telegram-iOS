import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import TelegramCore
import Postbox
import SegmentedControlNode

private func generateMaskPath(size: CGSize, leftRadius: CGFloat, rightRadius: CGFloat) -> UIBezierPath {
    let path = UIBezierPath()
    path.addArc(withCenter: CGPoint(x: leftRadius, y: size.height / 2.0), radius: leftRadius, startAngle: .pi * 0.5, endAngle: -.pi * 0.5, clockwise: true)
    path.addArc(withCenter: CGPoint(x: size.width - rightRadius, y: size.height / 2.0), radius: rightRadius, startAngle: -.pi * 0.5, endAngle: .pi * 0.5, clockwise: true)
    path.close()
    return path
}

private func generateKnobImage() -> UIImage? {
    let side: CGFloat = 28.0
    let margin: CGFloat = 10.0
    
    let image = generateImage(CGSize(width: side + margin * 2.0, height: side + margin * 2.0), opaque: false, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
                
        context.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: 9.0, color: UIColor(rgb: 0x000000, alpha: 0.3).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: margin, y: margin), size: CGSize(width: side, height: side)))
    })
    return image?.stretchableImage(withLeftCapWidth: Int(margin + side * 0.5), topCapHeight: Int(margin + side * 0.5))
}

final class ModeAndSizeComponent: Component {
    let values: [String]
    let sizeValue: CGFloat
    let isEditing: Bool
    let isEnabled: Bool
    let rightInset: CGFloat
    let tag: AnyObject?
    let selectedIndex: Int
    let selectionChanged: (Int) -> Void
    let sizeUpdated: (CGFloat) -> Void
    let sizeReleased: () -> Void
    
    init(values: [String], sizeValue: CGFloat, isEditing: Bool, isEnabled: Bool, rightInset: CGFloat, tag: AnyObject?, selectedIndex: Int, selectionChanged: @escaping (Int) -> Void, sizeUpdated: @escaping (CGFloat) -> Void, sizeReleased: @escaping () -> Void) {
        self.values = values
        self.sizeValue = sizeValue
        self.isEditing = isEditing
        self.isEnabled = isEnabled
        self.rightInset = rightInset
        self.tag = tag
        self.selectedIndex = selectedIndex
        self.selectionChanged = selectionChanged
        self.sizeUpdated = sizeUpdated
        self.sizeReleased = sizeReleased
    }
    
    static func ==(lhs: ModeAndSizeComponent, rhs: ModeAndSizeComponent) -> Bool {
        if lhs.values != rhs.values {
            return false
        }
        if lhs.sizeValue != rhs.sizeValue {
            return false
        }
        if lhs.isEditing != rhs.isEditing {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.rightInset != rhs.rightInset {
            return false
        }
        if lhs.selectedIndex != rhs.selectedIndex {
            return false
        }
        return true
    }

    final class View: UIView, UIGestureRecognizerDelegate, ComponentTaggedView {
        private let backgroundNode: NavigationBackgroundNode
        private let node: SegmentedControlNode
        
        private var knob: UIImageView
        
        private let maskLayer = SimpleShapeLayer()
        
        private var isEditing: Bool?
        private var isControlEnabled: Bool?
        private var sliderWidth: CGFloat = 0.0
        
        fileprivate var updated: (CGFloat) -> Void = { _ in }
        fileprivate var released: () -> Void = { }
        
        private var component: ModeAndSizeComponent?
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        init() {
            self.backgroundNode = NavigationBackgroundNode(color: UIColor(rgb: 0x888888, alpha: 0.3))
            self.node = SegmentedControlNode(theme: SegmentedControlTheme(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shadowColor: .black, textColor: UIColor(rgb: 0xffffff), dividerColor: UIColor(rgb: 0x505155, alpha: 0.6)), items: [], selectedIndex: 0, cornerRadius: 16.0)

            self.knob = UIImageView(image: generateKnobImage())
            
            super.init(frame: CGRect())
            
            self.layer.allowsGroupOpacity = true

            self.addSubview(self.backgroundNode.view)
            self.addSubview(self.node.view)
            self.addSubview(self.knob)
            
            self.backgroundNode.layer.mask = self.maskLayer
            
            let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
            pressGestureRecognizer.minimumPressDuration = 0.01
            pressGestureRecognizer.delegate = self
            self.addGestureRecognizer(pressGestureRecognizer)
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            panGestureRecognizer.delegate = self
            self.addGestureRecognizer(panGestureRecognizer)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            let location = gestureRecognizer.location(in: self).offsetBy(dx: -12.0, dy: 0.0)
            guard self.frame.width > 0.0, case .began = gestureRecognizer.state else {
                return
            }
            let value = max(0.0, min(1.0, location.x / (self.frame.width - 24.0)))
            self.updated(value)
        }
        
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            switch gestureRecognizer.state {
            case .changed:
                let location = gestureRecognizer.location(in: self).offsetBy(dx: -12.0, dy: 0.0)
                guard self.frame.width > 0.0 else {
                    return
                }
                let value = max(0.0, min(1.0, location.x / (self.frame.width - 24.0)))
                self.updated(value)
            case .ended, .cancelled:
                self.released()
            default:
                break
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let isEditing = self.isEditing, let isControlEnabled = self.isControlEnabled {
                return isEditing && isControlEnabled
            } else {
                return false
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func animateIn() {
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        func animateOut() {
            self.node.alpha = 0.0
            self.node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            
            self.backgroundNode.alpha = 0.0
            self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
        }

        func update(component: ModeAndSizeComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
        
            self.updated = component.sizeUpdated
            self.released = component.sizeReleased
            
            let previousIsEditing = self.isEditing
            self.isEditing = component.isEditing
            self.isControlEnabled = component.isEnabled
            
            if component.isEditing {
                self.sliderWidth = availableSize.width
            }
            
            self.node.items = component.values.map { SegmentedControlItem(title: $0) }
            self.node.setSelectedIndex(component.selectedIndex, animated: !transition.animation.isImmediate)
            let selectionChanged = component.selectionChanged
            self.node.selectedIndexChanged = { [weak self] index in
                self?.window?.endEditing(true)
                selectionChanged(index)
            }
            
            let nodeSize = self.node.updateLayout(.stretchToFill(width: availableSize.width + component.rightInset), transition: transition.containedViewLayoutTransition)
            let size = CGSize(width: availableSize.width, height: nodeSize.height)
            transition.setFrame(view: self.node.view, frame: CGRect(origin: CGPoint(), size: nodeSize))
            
            var isDismissingEditing = false
            if component.isEditing != previousIsEditing && !component.isEditing {
                isDismissingEditing = true
            }
            
            self.knob.alpha = component.isEditing ? 1.0 : 0.0
            if !isDismissingEditing {
                self.knob.frame = CGRect(origin: CGPoint(x: -12.0 + floorToScreenPixels((self.sliderWidth + 24.0 - self.knob.frame.size.width) * component.sizeValue), y: floorToScreenPixels((size.height - self.knob.frame.size.height) / 2.0)), size: self.knob.frame.size)
            }
                
            if component.isEditing != previousIsEditing {
                let containedTransition = transition.containedViewLayoutTransition
                let maskPath: UIBezierPath
                if component.isEditing {
                    maskPath = generateMaskPath(size: size, leftRadius: 2.0, rightRadius: 11.5)
                    let selectionFrame = self.node.animateSelection(to: self.knob.center, transition: containedTransition)
                    containedTransition.animateFrame(layer: self.knob.layer, from: selectionFrame.insetBy(dx: -9.0, dy: -9.0))
                    
                    self.knob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                } else {
                    maskPath = generateMaskPath(size: size, leftRadius: 16.0, rightRadius: 16.0)
                    if previousIsEditing != nil {
                        let selectionFrame = self.node.animateSelection(from: self.knob.center, transition: containedTransition)
                        containedTransition.animateFrame(layer: self.knob.layer, from: self.knob.frame, to: selectionFrame.insetBy(dx: -9.0, dy: -9.0))
                        self.knob.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
                transition.setShapeLayerPath(layer: self.maskLayer, path: maskPath.cgPath)
            }
                        
            transition.setFrame(layer: self.maskLayer, frame: CGRect(origin: .zero, size: nodeSize))
            
            transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundNode.update(size: size, transition: transition.containedViewLayoutTransition)
            
            if let screenTransition = transition.userData(DrawingScreenTransition.self) {
                switch screenTransition {
                case .animateIn:
                    self.animateIn()
                case .animateOut:
                    self.animateOut()
                }
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
