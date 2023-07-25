import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

public final class ToastContentComponent: Component {
    public let icon: AnyComponent<Empty>
    public let content: AnyComponent<Empty>

    public init(
        icon: AnyComponent<Empty>,
        content: AnyComponent<Empty>
    ) {
        self.icon = icon
        self.content = content
    }

    public static func ==(lhs: ToastContentComponent, rhs: ToastContentComponent) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView: BlurredBackgroundView
        private let icon = ComponentView<Empty>()
        private let content = ComponentView<Empty>()
        
        public var iconView: UIView? {
            return self.icon.view
        }
        
        public var contentView: UIView? {
            return self.content.view
        }
        
        override public init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ToastContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            var contentHeight: CGFloat = 0.0
            
            let leftInset: CGFloat = 9.0
            let rightInset: CGFloat = 6.0
            let verticalInset: CGFloat = 10.0
            let spacing: CGFloat = 9.0
            
            let iconSize = self.icon.update(
                transition: transition,
                component: component.icon,
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - spacing, height: availableSize.height)
            )
            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - spacing - iconSize.width, height: availableSize.height)
            )
            
            contentHeight += verticalInset * 2.0 + max(iconSize.height, contentSize.height)
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: leftInset, y: floor((contentHeight - iconSize.height) * 0.5)), size: iconSize))
            }
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: leftInset + iconSize.height + spacing, y: floor((contentHeight - contentSize.height) * 0.5)), size: contentSize))
            }
            
            let size = CGSize(width: availableSize.width, height: contentHeight)
            self.backgroundView.updateColor(color: UIColor(white: 0.0, alpha: 0.7), transition: .immediate)
            self.backgroundView.update(size: size, cornerRadius: 10.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
