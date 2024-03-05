import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ListSectionComponent
import SwitchNode

public final class ListActionItemComponent: Component {
    public enum ToggleStyle {
        case regular
        case icons
    }
    
    public struct Toggle: Equatable {
        public var style: ToggleStyle
        public var isOn: Bool
        public var isInteractive: Bool
        public var action: ((Bool) -> Void)?
        
        public init(style: ToggleStyle, isOn: Bool, isInteractive: Bool = true, action: ((Bool) -> Void)? = nil) {
            self.style = style
            self.isOn = isOn
            self.isInteractive = isInteractive
            self.action = action
        }
        
        public static func ==(lhs: Toggle, rhs: Toggle) -> Bool {
            if lhs.style != rhs.style {
                return false
            }
            if lhs.isOn != rhs.isOn {
                return false
            }
            if lhs.isInteractive != rhs.isInteractive {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            return true
        }
    }
    
    public enum Accessory: Equatable {
        case arrow
        case toggle(Toggle)
        case activity
    }
    
    public enum IconInsets: Equatable {
        case `default`
        case custom(UIEdgeInsets)
    }
    
    public struct Icon: Equatable {
        public var component: AnyComponentWithIdentity<Empty>
        public var insets: IconInsets
        public var allowUserInteraction: Bool
        
        public init(component: AnyComponentWithIdentity<Empty>, insets: IconInsets = .default, allowUserInteraction: Bool = false) {
            self.component = component
            self.insets = insets
            self.allowUserInteraction = allowUserInteraction
        }
    }
    
    public let theme: PresentationTheme
    public let title: AnyComponent<Empty>
    public let contentInsets: UIEdgeInsets
    public let leftIcon: AnyComponentWithIdentity<Empty>?
    public let icon: Icon?
    public let accessory: Accessory?
    public let action: ((UIView) -> Void)?
    
    public init(
        theme: PresentationTheme,
        title: AnyComponent<Empty>,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0),
        leftIcon: AnyComponentWithIdentity<Empty>? = nil,
        icon: Icon? = nil,
        accessory: Accessory? = .arrow,
        action: ((UIView) -> Void)?
    ) {
        self.theme = theme
        self.title = title
        self.contentInsets = contentInsets
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
        if lhs.contentInsets != rhs.contentInsets {
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
        private var switchNode: SwitchNode?
        private var iconSwitchNode: IconSwitchNode?
        private var activityIndicatorView: UIActivityIndicatorView?
        
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
                guard let self, let component = self.component, component.action != nil else {
                    return
                }
                if case .toggle = component.accessory, component.action == nil {
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
            guard let component, let action = component.action else {
                return
            }
            action(self)
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            return result
        }
        
        func update(component: ListActionItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let themeUpdated = component.theme !== previousComponent?.theme
            
            var contentLeftInset: CGFloat = 16.0
            let contentRightInset: CGFloat
            switch component.accessory {
            case .none:
                if let _ = component.icon {
                    contentRightInset = 42.0
                } else {
                    contentRightInset = 16.0
                }
            case .arrow:
                contentRightInset = 30.0
            case .toggle:
                contentRightInset = 76.0
            case .activity:
                contentRightInset = 76.0
            }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += component.contentInsets.top
            
            if component.leftIcon != nil {
                contentLeftInset += 46.0
            }

            let titleSize = self.title.update(
                transition: transition,
                component: component.title,
                environment: {},
                containerSize: CGSize(width: availableSize.width - contentLeftInset - contentRightInset, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: contentLeftInset, y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            contentHeight += titleSize.height
            
            contentHeight += component.contentInsets.bottom
            
            if let iconValue = component.icon {
                if previousComponent?.icon?.component.id != iconValue.component.id, let icon = self.icon {
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
                    component: iconValue.component.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                
                var iconOffset: CGFloat = 0.0
                if case .none = component.accessory {
                    iconOffset = 26.0
                }
                
                let iconFrame = CGRect(origin: CGPoint(x: availableSize.width - contentRightInset - iconSize.width + iconOffset, y: floor((contentHeight - iconSize.height) * 0.5)), size: iconSize)
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                        transition.animateAlpha(view: iconView, from: 0.0, to: 1.0)
                    }
                    iconView.isUserInteractionEnabled = iconValue.allowUserInteraction
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
                    if themeUpdated {
                        arrowView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
                    }
                } else {
                    arrowTransition = arrowTransition.withAnimation(.none)
                    arrowView = UIImageView(image: PresentationResourcesItemList.disclosureArrowImage(component.theme))
                    self.arrowView = arrowView
                    self.addSubview(arrowView)
                }
                                
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
            
            if case let .toggle(toggle) = component.accessory {
                switch toggle.style {
                case .regular:
                    let switchNode: SwitchNode
                    var switchTransition = transition
                    var updateSwitchTheme = themeUpdated
                    if let current = self.switchNode {
                        switchNode = current
                        switchNode.setOn(toggle.isOn, animated: !transition.animation.isImmediate)
                    } else {
                        switchTransition = switchTransition.withAnimation(.none)
                        updateSwitchTheme = true
                        switchNode = SwitchNode()
                        switchNode.setOn(toggle.isOn, animated: false)
                        self.switchNode = switchNode
                        self.addSubview(switchNode.view)
                        
                        switchNode.valueUpdated = { [weak self] value in
                            guard let self, let component = self.component else {
                                return
                            }
                            if case let .toggle(toggle) = component.accessory, let action = toggle.action {
                                action(value)
                            } else {
                                component.action?(self)
                            }
                        }
                    }
                    switchNode.isUserInteractionEnabled = toggle.isInteractive
                    
                    if updateSwitchTheme {
                        switchNode.frameColor = component.theme.list.itemSwitchColors.frameColor
                        switchNode.contentColor = component.theme.list.itemSwitchColors.contentColor
                        switchNode.handleColor = component.theme.list.itemSwitchColors.handleColor
                    }
                    
                    let switchSize = CGSize(width: 51.0, height: 31.0)
                    let switchFrame = CGRect(origin: CGPoint(x: availableSize.width - 16.0 - switchSize.width, y: floor((min(60.0, contentHeight) - switchSize.height) * 0.5)), size: switchSize)
                    switchTransition.setFrame(view: switchNode.view, frame: switchFrame)
                case .icons:
                    let switchNode: IconSwitchNode
                    var switchTransition = transition
                    var updateSwitchTheme = themeUpdated
                    if let current = self.iconSwitchNode {
                        switchNode = current
                        switchNode.setOn(toggle.isOn, animated: !transition.animation.isImmediate)
                    } else {
                        switchTransition = switchTransition.withAnimation(.none)
                        updateSwitchTheme = true
                        switchNode = IconSwitchNode()
                        switchNode.setOn(toggle.isOn, animated: false)
                        self.iconSwitchNode = switchNode
                        self.addSubview(switchNode.view)
                        
                        switchNode.valueUpdated = { [weak self] value in
                            guard let self, let component = self.component else {
                                return
                            }
                            if case let .toggle(toggle) = component.accessory, let action = toggle.action {
                                action(value)
                            } else {
                                component.action?(self)
                            }
                        }
                    }
                    switchNode.isUserInteractionEnabled = toggle.isInteractive
                    
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
                }
            } else {
                if let switchNode = self.switchNode {
                    self.switchNode = nil
                    switchNode.view.removeFromSuperview()
                }
            }
            
            if case .activity = component.accessory {
                let activityIndicatorView: UIActivityIndicatorView
                var activityIndicatorTransition = transition
                if let current = self.activityIndicatorView {
                    activityIndicatorView = current
                } else {
                    activityIndicatorTransition = activityIndicatorTransition.withAnimation(.none)
                    if #available(iOS 13.0, *) {
                        activityIndicatorView = UIActivityIndicatorView(style: .medium)
                    } else {
                        activityIndicatorView = UIActivityIndicatorView(style: .gray)
                    }
                    self.activityIndicatorView = activityIndicatorView
                    self.addSubview(activityIndicatorView)
                    activityIndicatorView.sizeToFit()
                }
                
                let activityIndicatorSize = activityIndicatorView.bounds.size
                let activityIndicatorFrame = CGRect(origin: CGPoint(x: availableSize.width - 16.0 - activityIndicatorSize.width, y: floor((min(60.0, contentHeight) - activityIndicatorSize.height) * 0.5)), size: activityIndicatorSize)
                
                activityIndicatorView.tintColor = component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.5)
                
                activityIndicatorTransition.setFrame(view: activityIndicatorView, frame: activityIndicatorFrame)
                
                if !activityIndicatorView.isAnimating {
                    activityIndicatorView.startAnimating()
                }
            } else {
                if let activityIndicatorView = self.activityIndicatorView {
                    self.activityIndicatorView = nil
                    activityIndicatorView.removeFromSuperview()
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
