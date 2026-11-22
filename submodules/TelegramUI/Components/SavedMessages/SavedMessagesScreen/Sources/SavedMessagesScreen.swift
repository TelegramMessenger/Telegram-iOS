import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import TelegramCore
import AccountContext
import SwiftSignalKit
import ViewControllerComponent

private final class SavedMessagesScreenComponent: Component {
    public let context: AccountContext
    
    public init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    public static func ==(lhs: SavedMessagesScreenComponent, rhs: SavedMessagesScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    public final class View: UIView {        
        private var component: SavedMessagesScreenComponent?
        private var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
        }
        
        required public init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: SavedMessagesScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            let themeUpdated = self.environment?.theme !== environment.theme
            
            self.environment = environment
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class SavedMessagesScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init(context: context, component: SavedMessagesScreenComponent(context: context), navigationBarAppearance: .none)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
}
