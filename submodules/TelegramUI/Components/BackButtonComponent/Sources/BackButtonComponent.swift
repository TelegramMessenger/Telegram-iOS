import Foundation
import UIKit
import ComponentFlow
import Display
import MultilineTextComponent

public final class BackButtonComponent: Component {
    public let title: String
    public let color: UIColor
    public let action: () -> Void
    
    public init(
        title: String,
        color: UIColor,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.color = color
        self.action = action
    }
    
    public static func ==(lhs: BackButtonComponent, rhs: BackButtonComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private let arrowView: UIImageView
        private let title = ComponentView<Empty>()
        
        private var component: BackButtonComponent?
        
        public override init(frame: CGRect) {
            self.arrowView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.arrowView)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self {
                    let transition: ComponentTransition = highlighted ? .immediate : .easeInOut(duration: 0.2)
                    if highlighted {
                        transition.setAlpha(view: self.arrowView, alpha: 0.65)
                        if let titleView = self.title.view {
                            transition.setAlpha(view: titleView, alpha: 0.65)
                        }
                    } else {
                        transition.setAlpha(view: self.arrowView, alpha: 1.0)
                        if let titleView = self.title.view {
                            transition.setAlpha(view: titleView, alpha: 1.0)
                        }
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.isHidden || self.alpha.isZero || self.isUserInteractionEnabled == false {
                return nil
            }
            
            if self.bounds.insetBy(dx: -8.0, dy: -8.0).contains(point) {
                return self
            }
            
            return nil
        }
        
        func update(component: BackButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            if self.arrowView.image == nil {
                self.arrowView.image = NavigationBar.backArrowImage(color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.arrowView.tintColor = component.color
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(17.0), textColor: component.color))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 4.0, height: availableSize.height)
            )
            
            let arrowInset: CGFloat = 15.0

            let size = CGSize(width: arrowInset + titleSize.width, height: titleSize.height)
            
            if let arrowImage = self.arrowView.image {
                let arrowFrame = CGRect(origin: CGPoint(x: -4.0, y: floor((size.height - arrowImage.size.height) * 0.5)), size: arrowImage.size)
                transition.setFrame(view: self.arrowView, frame: arrowFrame)
            }

            let titleFrame = CGRect(origin: CGPoint(x: arrowInset, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
