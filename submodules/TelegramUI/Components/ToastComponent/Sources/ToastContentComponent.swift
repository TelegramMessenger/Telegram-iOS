import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

public final class ToastContentComponent: Component {
    public let icon: AnyComponent<Empty>
    public let content: AnyComponent<Empty>
    public let insets: UIEdgeInsets
    public let iconSpacing: CGFloat

    public init(
        icon: AnyComponent<Empty>,
        content: AnyComponent<Empty>,
        insets: UIEdgeInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0),
        iconSpacing: CGFloat = 10.0
    ) {
        self.icon = icon
        self.content = content
        self.insets = insets
        self.iconSpacing = iconSpacing
    }

    public static func ==(lhs: ToastContentComponent, rhs: ToastContentComponent) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.iconSpacing != rhs.iconSpacing {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: ToastContentComponent?
        
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
        
        
        func update(component: ToastContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var contentHeight: CGFloat = 0.0
            
            self.component = component
            
            let leftInset: CGFloat = component.insets.left
            let rightInset: CGFloat = component.insets.right
            let topInset: CGFloat = component.insets.top
            let bottomInset: CGFloat = component.insets.bottom
            let spacing: CGFloat = component.iconSpacing
            
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
            
            contentHeight += topInset + bottomInset + max(iconSize.height, contentSize.height)
            
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
            self.backgroundView.update(size: size, cornerRadius: 14.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            
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
