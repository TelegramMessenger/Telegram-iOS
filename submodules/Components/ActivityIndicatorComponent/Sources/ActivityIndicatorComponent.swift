import Foundation
import UIKit
import ComponentFlow

public final class ActivityIndicatorComponent: Component {
    public let color: UIColor
    
    public init(
        color: UIColor
    ) {
        self.color = color
    }

    public static func ==(lhs: ActivityIndicatorComponent, rhs: ActivityIndicatorComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: UIActivityIndicatorView {
        public init() {
            super.init(style: .whiteLarge)
        }
        
        required public init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ActivityIndicatorComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if component.color != self.color {
                self.color = component.color
            }
            
            if !self.isAnimating {
                self.startAnimating()
            }
            
            return CGSize(width: 22.0, height: 22.0)
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
