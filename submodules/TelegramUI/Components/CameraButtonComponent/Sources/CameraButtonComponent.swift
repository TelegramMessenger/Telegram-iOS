import Foundation
import UIKit
import ComponentFlow

public final class CameraButton: Component {
    let content: AnyComponentWithIdentity<Empty>
    let minSize: CGSize?
    let tag: AnyObject?
    let isEnabled: Bool
    let isExclusive: Bool
    let action: () -> Void
    let longTapAction: (() -> Void)?

    public init(
        content: AnyComponentWithIdentity<Empty>,
        minSize: CGSize? = nil,
        tag: AnyObject? = nil,
        isEnabled: Bool = true,
        isExclusive: Bool = true,
        action: @escaping () -> Void,
        longTapAction: (() -> Void)? = nil
    ) {
        self.content = content
        self.minSize = minSize
        self.tag = tag
        self.isEnabled = isEnabled
        self.isExclusive = isExclusive
        self.action = action
        self.longTapAction = longTapAction
    }
    
    public func tagged(_ tag: AnyObject) -> CameraButton {
        return CameraButton(
            content: self.content,
            minSize: self.minSize,
            tag: tag,
            isEnabled: self.isEnabled,
            isExclusive: self.isExclusive,
            action: self.action,
            longTapAction: self.longTapAction
        )
    }
    
    public static func ==(lhs: CameraButton, rhs: CameraButton) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.minSize != rhs.minSize {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.isExclusive != rhs.isExclusive {
            return false
        }
        return true
    }
    
    public final class View: UIButton, ComponentTaggedView {
        private let containerView = UIView()
        public var contentView: ComponentHostView<Empty>
        
        private var component: CameraButton?
        private var currentIsHighlighted: Bool = false {
            didSet {
                if self.currentIsHighlighted != oldValue {
                    self.updateScale(transition: .easeInOut(duration: 0.3))
                }
            }
        }
        
        private func updateScale(transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            let scale: CGFloat
            if component.isEnabled {
                scale = self.currentIsHighlighted ? 0.8 : 1.0
            } else {
                scale = 1.0
            }
            transition.setScale(view: self.containerView, scale: scale)
        }
        
        private var longTapGestureRecognizer: UILongPressGestureRecognizer?
    
        public override init(frame: CGRect) {
            self.containerView.isUserInteractionEnabled = false
            
            self.contentView = ComponentHostView<Empty>()
            self.contentView.isUserInteractionEnabled = false
            self.contentView.layer.allowsGroupOpacity = true
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.contentView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            let longTapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress))
            self.longTapGestureRecognizer = longTapGestureRecognizer
            self.addGestureRecognizer(longTapGestureRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        @objc private func handleLongPress() {
            self.component?.longTapAction?()
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.currentIsHighlighted = true
            
            return super.beginTracking(touch, with: event)
        }
    
        public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            super.endTracking(touch, with: event)
        }
        
        public override func cancelTracking(with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            super.cancelTracking(with: event)
        }
        
        func update(component: CameraButton, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if let currentId = self.component?.content.id, currentId != component.content.id {
                let previousContentView = self.contentView
                
                self.contentView = ComponentHostView<Empty>()
                self.contentView.isUserInteractionEnabled = false
                self.contentView.layer.allowsGroupOpacity = true
                self.containerView.addSubview(self.contentView)
                
                if transition.animation.isImmediate {
                    previousContentView.removeFromSuperview()
                } else {
                    self.containerView.addSubview(previousContentView)
                    previousContentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousContentView] _ in
                        previousContentView?.removeFromSuperview()
                    })
                }
            }
            let contentSize = self.contentView.update(
                transition: .immediate,
                component: component.content.component,
                environment: {},
                containerSize: availableSize
            )
            
            var size = contentSize
            if let minSize = component.minSize {
                size.width = max(size.width, minSize.width)
                size.height = max(size.height, minSize.height)
            }
            
            self.component = component
            
            self.isExclusiveTouch = component.isExclusive
            
            self.updateScale(transition: transition)
            self.isEnabled = component.isEnabled
            self.longTapGestureRecognizer?.isEnabled = component.longTapAction != nil
            
            self.contentView.bounds = CGRect(origin: .zero, size: contentSize)
            self.contentView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            
            self.containerView.bounds = CGRect(origin: .zero, size: size)
            self.containerView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
