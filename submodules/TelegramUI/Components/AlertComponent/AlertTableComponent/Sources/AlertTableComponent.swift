import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AlertComponent
import TableComponent

public final class AlertTableComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let items: [TableComponent.Item]
    
    public init(
        items: [TableComponent.Item]
    ) {
        self.items = items
    }
    
    public static func ==(lhs: AlertTableComponent, rhs: AlertTableComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let table = ComponentView<Empty>()
        
        private var component: AlertTableComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertTableComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let tableSize = self.table.update(
                transition: transition,
                component: AnyComponent(
                    TableComponent(
                        theme: environment.theme,
                        items: component.items,
                        semiTransparent: true
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width + 20.0, height: availableSize.height)
            )
            let tableFrame = CGRect(origin: CGPoint(x: -10.0, y: 5.0), size: tableSize)
            if let tableView = self.table.view {
                if tableView.superview == nil {
                    self.addSubview(tableView)
                }
                transition.setFrame(view: tableView, frame: tableFrame)
            }
            return CGSize(width: availableSize.width, height: tableSize.height + 10.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
