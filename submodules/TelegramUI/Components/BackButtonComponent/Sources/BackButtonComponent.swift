import Foundation
import UIKit
import ComponentFlow
import BundleIconComponent
import Display

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
        private let arrow = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        
        private var component: BackButtonComponent?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self {
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.alpha = 0.65
                    } else {
                        self.alpha = 1.0
                        self.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
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
            return super.hitTest(point, with: event)
        }
        
        func update(component: BackButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let sideInset: CGFloat = 4.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.title, font: Font.regular(17.0), color: component.color)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 4.0, height: availableSize.height)
            )

            let size = CGSize(width: sideInset * 2.0 + titleSize.width, height: availableSize.height)

            let titleFrame = titleSize.centered(in: CGRect(origin: CGPoint(), size: size))
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
