import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AlertComponent
import BundleIconComponent

public final class AlertTransferHeaderComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public enum IconType {
        case transfer
        case take
    }
    
    let fromComponent: AnyComponentWithIdentity<Empty>
    let toComponent: AnyComponentWithIdentity<Empty>
    let type: IconType
    
    public init(
        fromComponent: AnyComponentWithIdentity<Empty>,
        toComponent: AnyComponentWithIdentity<Empty>,
        type: IconType
    ) {
        self.fromComponent = fromComponent
        self.toComponent = toComponent
        self.type = type
    }
    
    public static func ==(lhs: AlertTransferHeaderComponent, rhs: AlertTransferHeaderComponent) -> Bool {
        if lhs.fromComponent != rhs.fromComponent {
            return false
        }
        if lhs.toComponent != rhs.toComponent {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let from = ComponentView<Empty>()
        private let to = ComponentView<Empty>()
        private let arrow = ComponentView<Empty>()
        
        private var component: AlertTransferHeaderComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertTransferHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let size: CGSize
            let iconName: String
            switch component.type {
            case .transfer:
                iconName = "Peer Info/AlertArrow"
                size = CGSize(width: 148.0, height: 60.0)
            case .take:
                iconName = "Media Editor/CutoutUndo"
                size = CGSize(width: 154.0, height: 60.0)
            }
            let sideInset = floorToScreenPixels((availableSize.width - size.width) / 2.0)
            
            let fromSize = self.from.update(
                transition: transition,
                component: component.fromComponent.component,
                environment: {},
                containerSize: CGSize(width: 60.0, height: 60.0)
            )
            let fromFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: fromSize)
            if let fromView = self.from.view {
                if fromView.superview == nil {
                    self.addSubview(fromView)
                }
                transition.setFrame(view: fromView, frame: fromFrame)
            }
            
            let arrowSize = self.arrow.update(
                transition: transition,
                component: AnyComponent(
                    BundleIconComponent(name: iconName, tintColor: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.2))
                ),
                environment: {},
                containerSize: availableSize
            )
            let arrowFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - arrowSize.width) / 2.0), y: floorToScreenPixels((size.height - arrowSize.height) / 2.0)), size: arrowSize)
            if let arrowView = self.arrow.view {
                if arrowView.superview == nil {
                    self.addSubview(arrowView)
                }
                transition.setFrame(view: arrowView, frame: arrowFrame)
            }
            
            let toSize = self.to.update(
                transition: transition,
                component: component.toComponent.component,
                environment: {},
                containerSize: CGSize(width: 60.0, height: 60.0)
            )
            let toFrame = CGRect(origin: CGPoint(x: availableSize.width - toSize.width - sideInset, y: 0.0), size: toSize)
            if let toView = self.to.view {
                if toView.superview == nil {
                    self.addSubview(toView)
                }
                transition.setFrame(view: toView, frame: toFrame)
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
