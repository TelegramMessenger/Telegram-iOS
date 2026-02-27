import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import TelegramCore
import GlassBackgroundComponent

public final class ChatPanelsComponent: Component {    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
    }
    
    public static func ==(lhs: ChatPanelsComponent, rhs: ChatPanelsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if result === self {
                return nil
            }
            return result
        }
        
        func update(component: ChatPanelsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
