import Foundation
import UIKit
import ComponentFlow
import Display
import ComponentDisplayAdapters

public final class BlurredBackgroundComponent: Component {
    public let color: UIColor
    public let tintContainerView: UIView?

    public init(
        color: UIColor,
        tintContainerView: UIView? = nil
    ) {
        self.color = color
        self.tintContainerView = tintContainerView
    }
    
    public static func ==(lhs: BlurredBackgroundComponent, rhs: BlurredBackgroundComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.tintContainerView !== rhs.tintContainerView {
            return false
        }
        return true
    }
    
    public final class View: BlurredBackgroundView {
        private var tintMaskView: UIView?
        
        public func update(component: BlurredBackgroundComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if let tintContainerView = component.tintContainerView {
                self.updateColor(color: .clear, forceKeepBlur: true, transition: transition.containedViewLayoutTransition)
                
                let tintMaskView: UIView
                if let current = self.tintMaskView {
                    tintMaskView = current
                } else {
                    tintMaskView = UIView()
                    self.tintMaskView = tintMaskView
                    self.addSubview(tintMaskView)
                }
                
                tintMaskView.backgroundColor = component.color
                transition.setFrame(view: tintMaskView, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if tintMaskView.mask !== tintContainerView {
                    tintMaskView.mask = tintContainerView
                }
            } else {
                self.updateColor(color: component.color, transition: transition.containedViewLayoutTransition)
                
                if let tintMaskView = self.tintMaskView {
                    self.tintMaskView = nil
                    tintMaskView.removeFromSuperview()
                }
            }
            self.update(size: availableSize, transition: transition.containedViewLayoutTransition)

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
