import Foundation
import UIKit
import Display
import ComponentFlow
import CheckNode

public final class CheckComponent: Component {
    public struct Theme: Equatable {
        public let backgroundColor: UIColor
        public let strokeColor: UIColor
        public let borderColor: UIColor
        public let overlayBorder: Bool
        public let hasInset: Bool
        public let hasShadow: Bool
        public let filledBorder: Bool
        public let borderWidth: CGFloat?
        
        public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil) {
            self.backgroundColor = backgroundColor
            self.strokeColor = strokeColor
            self.borderColor = borderColor
            self.overlayBorder = overlayBorder
            self.hasInset = hasInset
            self.hasShadow = hasShadow
            self.filledBorder = filledBorder
            self.borderWidth = borderWidth
        }
        
        var checkNodeTheme: CheckNodeTheme {
            return CheckNodeTheme(
                backgroundColor: self.backgroundColor,
                strokeColor: self.strokeColor,
                borderColor: self.borderColor,
                overlayBorder: self.overlayBorder,
                hasInset: self.hasInset,
                hasShadow: self.hasShadow,
                filledBorder: self.filledBorder,
                borderWidth: self.borderWidth
            )
        }
    }
    
    let theme: Theme
    let size: CGSize
    let selected: Bool
    
    public init(
        theme: Theme,
        size: CGSize = CGSize(width: 22.0, height: 22.0),
        selected: Bool
    ) {
        self.theme = theme
        self.size = size
        self.selected = selected
    }
    
    public static func ==(lhs: CheckComponent, rhs: CheckComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.selected != rhs.selected {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var currentValue: CGFloat?
        private var animator: DisplayLinkAnimator?

        private var checkLayer: CheckLayer {
            return self.layer as! CheckLayer
        }
        
        public override class var layerClass: AnyClass {
            return CheckLayer.self
        }
        
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
    
        public func update(component: CheckComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.checkLayer.setSelected(component.selected, animated: true)
            self.checkLayer.theme = component.theme.checkNodeTheme
            
            return component.size
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
