import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ListSectionComponent
import SwitchNode

public final class ListActionItemComponent: Component {
    public enum Accessory: Equatable {
        case arrow
        case toggle(Bool)
    }
    
    public let theme: PresentationTheme
    public let title: AnyComponent<Empty>
    public let leftIcon: AnyComponentWithIdentity<Empty>?
    public let icon: AnyComponentWithIdentity<Empty>?
    public let accessory: Accessory?
    public let action: ((UIView) -> Void)?
    
    public init(
        theme: PresentationTheme,
        title: AnyComponent<Empty>,
        leftIcon: AnyComponentWithIdentity<Empty>? = nil,
        icon: AnyComponentWithIdentity<Empty>? = nil,
        accessory: Accessory? = .arrow,
        action: ((UIView) -> Void)?
    ) {
        self.theme = theme
        self.title = title
        self.leftIcon = leftIcon
        self.icon = icon
        self.accessory = accessory
        self.action = action
    }
    
    public static func ==(lhs: ListActionItemComponent, rhs: ListActionItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.leftIcon != rhs.leftIcon {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.accessory != rhs.accessory {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton, ListSectionComponent.ChildView {
        private let title = ComponentView<Empty>()
        private var leftIcon: ComponentView<Empty>?
        private var icon: ComponentView<Empty>?
        
        private var arrowView: UIImageView?
        private var switchNode: IconSwitchNode?
        
        private var component: ListActionItemComponent?
        
        public var iconView: UIView? {
            return self.icon?.view
        }
        
        public var leftIconView: UIView? {
            return self.leftIcon?.view
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var separatorInset: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
            
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
            
            let themeUpdated = component.theme !== previousComponent?.theme
            
            let verticalInset: CGFloat = 12.0
            
            var contentLeftInset: CGFloat = 16.0
            let contentRightInset: CGFloat
            switch component.accessory {
            case .none:
                contentRightInset = 16.0
            case .arrow:
                contentRightInset = 30.0
            case .toggle:
                contentRightInset = 42.0
            }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += verticalInset
            
            if component.leftIcon != nil {
                contentLeftInset += 46.0
            }

            let titleSize = self.title.update(
                transition: transition,
                component: component.title,
                environment: {},
                containerSize: CGSize(width: availableSize.width - contentLeftInset - contentRightInset, height: availableSize.height)
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
            
            if let leftIconValue = component.leftIcon {
                if previousComponent?.leftIcon?.id != leftIconValue.id, let leftIcon = self.leftIcon {
                    self.leftIcon = nil
                    if let iconView = leftIcon.view {
                        transition.setAlpha(view: iconView, alpha: 0.0, completion: { [weak iconView] _ in
                            iconView?.removeFromSuperview()
                        })
                    }
                }
                
                var leftIconTransition = transition
                let leftIcon: ComponentView<Empty>
                if let current = self.leftIcon {
                    leftIcon = current
                } else {
                    leftIconTransition = leftIconTransition.withAnimation(.none)
                    leftIcon = ComponentView()
                    self.leftIcon = leftIcon
                }
                
                let leftIconSize = leftIcon.update(
                    transition: leftIconTransition,
                    component: leftIconValue.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let leftIconFrame = CGRect(origin: CGPoint(x: floor((contentLeftInset - leftIconSize.width) * 0.5), y: floor((min(60.0, contentHeight) - leftIconSize.height) * 0.5)), size: leftIconSize)
                if let leftIconView = leftIcon.view {
                    if leftIconView.superview == nil {
                        leftIconView.isUserInteractionEnabled = false
                        self.addSubview(leftIconView)
                        transition.animateAlpha(view: leftIconView, from: 0.0, to: 1.0)
                    }
                    leftIconTransition.setFrame(view: leftIconView, frame: leftIconFrame)
                }
            } else {
                if let leftIcon = self.leftIcon {
                    self.leftIcon = nil
                    if let leftIconView = leftIcon.view {
                        transition.setAlpha(view: leftIconView, alpha: 0.0, completion: { [weak leftIconView] _ in
                            leftIconView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if case .arrow = component.accessory {
                let arrowView: UIImageView
                var arrowTransition = transition
                if let current = self.arrowView {
                    arrowView = current
                } else {
                    arrowTransition = arrowTransition.withAnimation(.none)
                    arrowView = UIImageView(image: PresentationResourcesItemList.disclosureArrowImage(component.theme)?.withRenderingMode(.alwaysTemplate))
                    self.arrowView = arrowView
                    self.addSubview(arrowView)
                }
                
                arrowView.tintColor = component.theme.list.disclosureArrowColor
                
                if let image = arrowView.image {
                    let arrowFrame = CGRect(origin: CGPoint(x: availableSize.width - 7.0 - image.size.width, y: floor((contentHeight - image.size.height) * 0.5)), size: image.size)
                    arrowTransition.setFrame(view: arrowView, frame: arrowFrame)
                }
            } else {
                if let arrowView = self.arrowView {
                    self.arrowView = nil
                    arrowView.removeFromSuperview()
                }
            }
            
            if case let .toggle(isOn) = component.accessory {
                let switchNode: IconSwitchNode
                var switchTransition = transition
                var updateSwitchTheme = themeUpdated
                if let current = self.switchNode {
                    switchNode = current
                    switchNode.setOn(isOn, animated: !transition.animation.isImmediate)
                } else {
                    switchTransition = switchTransition.withAnimation(.none)
                    updateSwitchTheme = true
                    switchNode = IconSwitchNode()
                    switchNode.setOn(isOn, animated: false)
                    self.addSubview(switchNode.view)
                }
                
                if updateSwitchTheme {
                    switchNode.frameColor = component.theme.list.itemSwitchColors.frameColor
                    switchNode.contentColor = component.theme.list.itemSwitchColors.contentColor
                    switchNode.handleColor = component.theme.list.itemSwitchColors.handleColor
                    switchNode.positiveContentColor = component.theme.list.itemSwitchColors.positiveColor
                    switchNode.negativeContentColor = component.theme.list.itemSwitchColors.negativeColor
                }
                
                let switchSize = CGSize(width: 51.0, height: 31.0)
                let switchFrame = CGRect(origin: CGPoint(x: availableSize.width - 16.0 - switchSize.width, y: floor((min(60.0, contentHeight) - switchSize.height) * 0.5)), size: switchSize)
                switchTransition.setFrame(view: switchNode.view, frame: switchFrame)
            } else {
                if let switchNode = self.switchNode {
                    self.switchNode = nil
                    switchNode.view.removeFromSuperview()
                }
            }
            
            self.separatorInset = contentLeftInset
            
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
