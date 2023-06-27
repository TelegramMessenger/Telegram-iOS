import Foundation
import UIKit
import Display
import ComponentFlow
import ActivityIndicator

public final class TitleActivityIndicatorComponent: Component {
    let color: UIColor
    
    public init(
        color: UIColor
    ) {
        self.color = color
    }
    
    public static func ==(lhs: TitleActivityIndicatorComponent, rhs: TitleActivityIndicatorComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var activityIndicator: ActivityIndicator?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
        }
        
        func update(component: TitleActivityIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let activityIndicator: ActivityIndicator
            if let current = self.activityIndicator {
                activityIndicator = current
            } else {
                activityIndicator = ActivityIndicator(type: .custom(component.color, availableSize.width, 2.0, true))
                self.activityIndicator = activityIndicator
                self.addSubview(activityIndicator.view)
            }
            
            activityIndicator.frame = CGRect(origin: CGPoint(), size: availableSize)
            activityIndicator.isHidden = false
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
