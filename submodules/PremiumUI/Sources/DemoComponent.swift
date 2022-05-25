import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ComponentFlow
import AccountContext

final class DemoComponent: Component {
    public typealias EnvironmentType = DemoPageEnvironment
    
    let context: AccountContext
    
    public init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    public static func ==(lhs: DemoComponent, rhs: DemoComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: DemoComponent?
                
        public func update(component: DemoComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
                        
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
