import Foundation
import UIKit
import ComponentFlow

public final class UndoPanelComponent: Component {
    public let icon: AnyComponent<Empty>?
    public let content: AnyComponent<Empty>
    public let action: AnyComponent<Empty>?

    public init(
        icon: AnyComponent<Empty>?,
        content: AnyComponent<Empty>,
        action: AnyComponent<Empty>?
    ) {
        self.icon = icon
        self.content = content
        self.action = action
    }

    public static func ==(lhs: UndoPanelComponent, rhs: UndoPanelComponent) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.content !== rhs.content {
            return false
        }
        if lhs.action != rhs.action {
            return false
        }
        
        return true
    }
    
    public final class View: UIVisualEffectView {
        private var iconView: ComponentHostView<Empty>?
        private let centralContentView: ComponentHostView<Empty>
        private var actionView: ComponentHostView<Empty>?
        
        init() {
            self.centralContentView = ComponentHostView()
            
            super.init(effect: nil)
            
            self.addSubview(self.contentView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: UndoPanelComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.effect = UIBlurEffect(style: .dark)
            
            self.layer.cornerRadius = 10.0
            
            return CGSize(width: availableSize.width, height: 50.0)
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
