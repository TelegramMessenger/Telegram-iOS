import Foundation
import UIKit
import ComponentFlow
import Display
import ComponentDisplayAdapters

public final class BlurredBackgroundComponent: Component {
    public let color: UIColor
    public let tintContainerView: UIView?
    public let cornerRadius: CGFloat

    public init(
        color: UIColor,
        tintContainerView: UIView? = nil,
        cornerRadius: CGFloat = 0.0
    ) {
        self.color = color
        self.tintContainerView = tintContainerView
        self.cornerRadius = cornerRadius
    }
    
    public static func ==(lhs: BlurredBackgroundComponent, rhs: BlurredBackgroundComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.tintContainerView !== rhs.tintContainerView {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        return true
    }
    
    public final class View: BlurredBackgroundView {
        private var tintContainerView: UIView?
        private var vibrancyEffectView: UIVisualEffectView?
        
        public func update(component: BlurredBackgroundComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.updateColor(color: component.color, transition: transition.containedViewLayoutTransition)
            
            self.update(size: availableSize, cornerRadius: component.cornerRadius, transition: transition.containedViewLayoutTransition)
            
            if let tintContainerView = self.tintContainerView {
                transition.setFrame(view: tintContainerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            if let vibrancyEffectView = self.vibrancyEffectView {
                transition.setFrame(view: vibrancyEffectView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }

            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(color: nil, enableBlur: true)
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
