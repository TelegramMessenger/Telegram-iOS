import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ListSectionComponent

public final class ListActionItemComponent: Component {
    public let theme: PresentationTheme
    public let title: AnyComponent<Empty>
    public let icon: AnyComponentWithIdentity<Empty>?
    public let hasArrow: Bool
    public let action: ((UIView) -> Void)?
    
    public init(
        theme: PresentationTheme,
        title: AnyComponent<Empty>,
        icon: AnyComponentWithIdentity<Empty>?,
        hasArrow: Bool = true,
        action: ((UIView) -> Void)?
    ) {
        self.theme = theme
        self.title = title
        self.icon = icon
        self.hasArrow = hasArrow
        self.action = action
    }
    
    public static func ==(lhs: ListActionItemComponent, rhs: ListActionItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.hasArrow != rhs.hasArrow {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton, ListSectionComponent.ChildView {
        private let title = ComponentView<Empty>()
        private var icon: ComponentView<Empty>?
        
        private let arrowView: UIImageView
        
        private var component: ListActionItemComponent?
        
        public var iconView: UIView? {
            return self.icon?.view
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        
        public override init(frame: CGRect) {
            self.arrowView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.arrowView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.internalHighligthedChanged = { [weak self] isHighlighted in
                guard let self else {
                    return
                }
                if let customUpdateIsHighlighted = self.customUpdateIsHighlighted {
                    customUpdateIsHighlighted(isHighlighted)
                }
            }
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.component?.action?(self)
        }
        
        func update(component: ListActionItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            self.isEnabled = component.action != nil
            
            let verticalInset: CGFloat = 11.0
            
            let contentLeftInset: CGFloat = 16.0
            let contentRightInset: CGFloat = component.hasArrow ? 30.0 : 16.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += verticalInset

            let titleSize = self.title.update(
                transition: transition,
                component: component.title,
                environment: {},
                containerSize: CGSize(width: availableSize.width - contentLeftInset, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: contentLeftInset, y: verticalInset), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            contentHeight += titleSize.height
            
            contentHeight += verticalInset
            
            if let iconValue = component.icon {
                if previousComponent?.icon?.id != iconValue.id, let icon = self.icon {
                    self.icon = nil
                    if let iconView = icon.view {
                        transition.setAlpha(view: iconView, alpha: 0.0, completion: { [weak iconView] _ in
                            iconView?.removeFromSuperview()
                        })
                    }
                }
                
                var iconTransition = transition
                let icon: ComponentView<Empty>
                if let current = self.icon {
                    icon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    icon = ComponentView()
                    self.icon = icon
                }
                
                let iconSize = icon.update(
                    transition: iconTransition,
                    component: iconValue.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let iconFrame = CGRect(origin: CGPoint(x: availableSize.width - contentRightInset - iconSize.width, y: floor((contentHeight - iconSize.height) * 0.5)), size: iconSize)
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        iconView.isUserInteractionEnabled = false
                        self.addSubview(iconView)
                        transition.animateAlpha(view: iconView, from: 0.0, to: 1.0)
                    }
                    iconTransition.setFrame(view: iconView, frame: iconFrame)
                }
            } else {
                if let icon = self.icon {
                    self.icon = nil
                    if let iconView = icon.view {
                        transition.setAlpha(view: iconView, alpha: 0.0, completion: { [weak iconView] _ in
                            iconView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)?.withRenderingMode(.alwaysTemplate)
            }
            self.arrowView.tintColor = component.theme.list.disclosureArrowColor
            if let image = self.arrowView.image {
                let arrowFrame = CGRect(origin: CGPoint(x: availableSize.width - 7.0 - image.size.width, y: floor((contentHeight - image.size.height) * 0.5)), size: image.size)
                transition.setFrame(view: self.arrowView, frame: arrowFrame)
            }
            transition.setAlpha(view: self.arrowView, alpha: component.hasArrow ? 1.0 : 0.0)
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
