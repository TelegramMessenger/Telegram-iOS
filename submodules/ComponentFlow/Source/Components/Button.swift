import Foundation
import UIKit

public final class Button: Component {
    public let content: AnyComponent<Empty>
    public let minSize: CGSize?
    public let tag: AnyObject?
    public let automaticHighlight: Bool
    public let action: () -> Void
    public let holdAction: (() -> Void)?

    convenience public init(
        content: AnyComponent<Empty>,
        action: @escaping () -> Void
    ) {
        self.init(
            content: content,
            minSize: nil,
            tag: nil,
            automaticHighlight: true,
            action: action,
            holdAction: nil
        )
    }
    
    private init(
        content: AnyComponent<Empty>,
        minSize: CGSize? = nil,
        tag: AnyObject? = nil,
        automaticHighlight: Bool = true,
        action: @escaping () -> Void,
        holdAction: (() -> Void)?
    ) {
        self.content = content
        self.minSize = minSize
        self.tag = tag
        self.automaticHighlight = automaticHighlight
        self.action = action
        self.holdAction = holdAction
    }
    
    public func minSize(_ minSize: CGSize?) -> Button {
        return Button(
            content: self.content,
            minSize: minSize,
            tag: self.tag,
            automaticHighlight: self.automaticHighlight,
            action: self.action,
            holdAction: self.holdAction
        )
    }
    
    public func withHoldAction(_ holdAction: (() -> Void)?) -> Button {
        return Button(
            content: self.content,
            minSize: self.minSize,
            tag: self.tag,
            automaticHighlight: self.automaticHighlight,
            action: self.action,
            holdAction: holdAction
        )
    }
    
    public func tagged(_ tag: AnyObject) -> Button {
        return Button(
            content: self.content,
            minSize: self.minSize,
            tag: tag,
            automaticHighlight: self.automaticHighlight,
            action: self.action,
            holdAction: self.holdAction
        )
    }
    
    public static func ==(lhs: Button, rhs: Button) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.minSize != rhs.minSize {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        if lhs.automaticHighlight != rhs.automaticHighlight {
            return false
        }
        return true
    }
    
    public final class View: UIButton, ComponentTaggedView {
        private let contentView: ComponentHostView<Empty>
        
        private var component: Button?
        private var currentIsHighlighted: Bool = false {
            didSet {
                guard let component = self.component, component.automaticHighlight else {
                    return
                }
                if self.currentIsHighlighted != oldValue {
                    self.contentView.alpha = self.currentIsHighlighted ? 0.6 : 1.0
                }
            }
        }
        
        private var holdActionTriggerred: Bool = false
        private var holdActionTimer: Timer?
        
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
        
        deinit {
            self.holdActionTimer?.invalidate()
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
        
        @objc private func pressed() {
            if self.holdActionTriggerred {
                self.holdActionTriggerred = false
            } else {
                self.component?.action()
            }
        }
        
        override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.currentIsHighlighted = true
            
            self.holdActionTriggerred = false
            
            if self.component?.holdAction != nil {
                self.holdActionTriggerred = true
                self.component?.action()
                
                self.holdActionTimer?.invalidate()
                if #available(iOS 10.0, *) {
                    let holdActionTimer = Timer(timeInterval: 0.5, repeats: false, block: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.holdActionTimer?.invalidate()
                        strongSelf.component?.holdAction?()
                        strongSelf.beginExecuteHoldActionTimer()
                    })
                    self.holdActionTimer = holdActionTimer
                    RunLoop.main.add(holdActionTimer, forMode: .common)
                }
            }
            
            return super.beginTracking(touch, with: event)
        }
        
        private func beginExecuteHoldActionTimer() {
            self.holdActionTimer?.invalidate()
            if #available(iOS 10.0, *) {
                let holdActionTimer = Timer(timeInterval: 0.1, repeats: true, block: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.component?.holdAction?()
                })
                self.holdActionTimer = holdActionTimer
                RunLoop.main.add(holdActionTimer, forMode: .common)
            }
        }
        
        override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            self.holdActionTimer?.invalidate()
            self.holdActionTimer = nil
            
            super.endTracking(touch, with: event)
        }
        
        override public func cancelTracking(with event: UIEvent?) {
            self.currentIsHighlighted = false
            
            self.holdActionTimer?.invalidate()
            self.holdActionTimer = nil
            
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
