import Foundation
import UIKit

public final class Button: Component {
    public let content: AnyComponent<Empty>
    public let minSize: CGSize?
    public let action: () -> Void

    convenience public init(
        content: AnyComponent<Empty>,
        action: @escaping () -> Void
    ) {
        self.init(
            content: content,
            minSize: nil,
            action: action
        )
    }
    
    private init(
        content: AnyComponent<Empty>,
        minSize: CGSize?,
        action: @escaping () -> Void
    ) {
        self.content = content
        self.minSize = nil
        self.action = action
    }
    
    public func minSize(_ minSize: CGSize?) -> Button {
        return Button(
            content: self.content,
            minSize: minSize,
            action: self.action
        )
    }
    
    public static func ==(lhs: Button, rhs: Button) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.minSize != rhs.minSize {
            return false
        }
        return true
    }
    
    public final class View: UIButton {
        private let contentView: ComponentHostView<Empty>
        
        private var component: Button?
        private var currentIsHighlighted: Bool = false {
            didSet {
                if self.currentIsHighlighted != oldValue {
                    self.contentView.alpha = self.currentIsHighlighted ? 0.6 : 1.0
                }
            }
        }
        
        override init(frame: CGRect) {
            self.contentView = ComponentHostView<Empty>()
            self.contentView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.contentView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.currentIsHighlighted = true
            
            return super.beginTracking(touch, with: event)
        }
        
        override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            super.endTracking(touch, with: event)
        }
        
        override public func cancelTracking(with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            super.cancelTracking(with: event)
        }
        
        func update(component: Button, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            
            var size = contentSize
            if let minSize = component.minSize {
                size.width = max(size.width, minSize.width)
                size.height = max(size.height, minSize.height)
            }
            
            self.component = component
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) / 2.0), y: floor((size.height - contentSize.height) / 2.0)), size: contentSize), completion: nil)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
