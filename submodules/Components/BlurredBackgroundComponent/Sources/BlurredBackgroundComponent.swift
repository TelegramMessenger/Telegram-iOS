import Foundation
import UIKit
import ComponentFlow
import Display
import ComponentDisplayAdapters

public final class BlurredBackgroundComponent: Component {
    public let color: UIColor

    public init(
        color: UIColor
    ) {
        self.color = color
    }
    
    public static func ==(lhs: BlurredBackgroundComponent, rhs: BlurredBackgroundComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: BlurredBackgroundView {
        public func update(component: BlurredBackgroundComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.updateColor(color: component.color, transition: transition.containedViewLayoutTransition)
            self.update(size: availableSize, transition: transition.containedViewLayoutTransition)

            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(color: .clear, enableBlur: true)
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
