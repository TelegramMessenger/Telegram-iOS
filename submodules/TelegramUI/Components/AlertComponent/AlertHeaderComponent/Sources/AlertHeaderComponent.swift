import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AlertComponent

public final class AlertHeaderComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let component: AnyComponentWithIdentity<Empty>
    
    public init(
        component: AnyComponentWithIdentity<Empty>
    ) {
        self.component = component
    }
    
    public static func ==(lhs: AlertHeaderComponent, rhs: AlertHeaderComponent) -> Bool {
        if lhs.component != rhs.component {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let componentView = ComponentView<Empty>()
        
        private var component: AlertHeaderComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size: CGSize = CGSize(width: 80.0, height: 80.0)
            
            let componentSize = self.componentView.update(
                transition: transition,
                component: component.component.component,
                environment: {},
                containerSize: size
            )
            let frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - componentSize.width) / 2.0), y: 0.0), size: componentSize)
            if let componentView = self.componentView.view {
                if componentView.superview == nil {
                    self.addSubview(componentView)
                }
                transition.setFrame(view: componentView, frame: frame)
            }
            
            return CGSize(width: availableSize.width, height: size.height + 11.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
