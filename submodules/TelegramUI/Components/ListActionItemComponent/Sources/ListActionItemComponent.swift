import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ListSectionComponent
import SwitchNode
import CheckNode

public final class ListActionItemComponent: Component {
    public enum ToggleStyle {
        case regular
        case icons
        case lock
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
    
    public struct CustomAccessory: Equatable {
        public var component: AnyComponentWithIdentity<Empty>
        public var insets: UIEdgeInsets
        public var isInteractive: Bool
        
        public init(component: AnyComponentWithIdentity<Empty>, insets: UIEdgeInsets = UIEdgeInsets(), isInteractive: Bool = false) {
            self.component = component
            self.insets = insets
            self.isInteractive = isInteractive
        }
    }
    
    public enum Accessory: Equatable {
        case arrow
        case toggle(Toggle)
        case activity
        case custom(CustomAccessory)
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
    
    public enum LeftIcon: Equatable {
        public final class Check: Equatable {
            public let isSelected: Bool
            public let toggle: (() -> Void)?
            
            public init(isSelected: Bool, toggle: (() -> Void)?) {
                self.isSelected = isSelected
                self.toggle = toggle
            }
            
            public static func ==(lhs: Check, rhs: Check) -> Bool {
                if lhs === rhs {
                    return true
                }
                if lhs.isSelected != rhs.isSelected {
                    return false
                }
                if (lhs.toggle == nil) != (rhs.toggle == nil) {
                    return false
                }
                return true
            }
        }
        
        case check(Check)
        case custom(AnyComponentWithIdentity<Empty>, Bool)
    }
    
    public enum Highlighting {
        case `default`
        case disabled
    }
    
    public enum Alignment {
        case `default`
        case center
    }
    
    public let theme: PresentationTheme
    public let background: AnyComponent<Empty>?
    public let title: AnyComponent<Empty>
    public let titleAlignment: Alignment
    public let contentInsets: UIEdgeInsets
    public let leftIcon: LeftIcon?
    public let icon: Icon?
    public let accessory: Accessory?
    public let action: ((UIView) -> Void)?
    public let highlighting: Highlighting
    public let updateIsHighlighted: ((UIView, Bool) -> Void)?
    
    public init(
        theme: PresentationTheme,
        background: AnyComponent<Empty>? = nil,
        title: AnyComponent<Empty>,
        titleAlignment: Alignment = .default,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0),
        leftIcon: LeftIcon? = nil,
        icon: Icon? = nil,
        accessory: Accessory? = .arrow,
        action: ((UIView) -> Void)?,
        highlighting: Highlighting = .default,
        updateIsHighlighted: ((UIView, Bool) -> Void)? = nil
    ) {
        self.theme = theme
        self.background = background
        self.title = title
        self.titleAlignment = titleAlignment
        self.contentInsets = contentInsets
        self.leftIcon = leftIcon
        self.icon = icon
        self.accessory = accessory
        self.action = action
        self.highlighting = highlighting
        self.updateIsHighlighted = updateIsHighlighted
    }
    
    public static func ==(lhs: ListActionItemComponent, rhs: ListActionItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleAlignment != rhs.titleAlignment {
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
        if lhs.highlighting != rhs.highlighting {
            return false
        }
        return true
    }
    
    private final class CheckView: HighlightTrackingButton {
        private var checkLayer: CheckLayer?
        private var theme: PresentationTheme?
        
        var action: (() -> Void)?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let animateScale = true
                    
                    let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "transform.scale")
                        
                        if animateScale {
                            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                            transition.setScale(layer: self.layer, scale: topScale)
                        }
                    } else {
                        if animateScale {
                            let transition = ComponentTransition(animation: .none)
                            transition.setScale(layer: self.layer, scale: 1.0)
                            
                            self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                            })
                        }
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.action?()
        }
        
        func update(size: CGSize, theme: PresentationTheme, isSelected: Bool, transition: ComponentTransition) {
            let checkLayer: CheckLayer
            if let current = self.checkLayer {
                checkLayer = current
            } else {
                checkLayer = CheckLayer(theme: CheckNodeTheme(theme: theme, style: .plain), content: .check)
                self.checkLayer = checkLayer
                self.layer.addSublayer(checkLayer)
            }
            
            if self.theme !== theme {
                self.theme = theme
                
                checkLayer.theme = CheckNodeTheme(theme: theme, style: .plain)
            }
            
            checkLayer.frame = CGRect(origin: CGPoint(), size: size)
            checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
        }
    }
    
    public final class View: HighlightTrackingButton, ListSectionComponent.ChildView {
        private var background: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        private var leftIcon: ComponentView<Empty>?
        private var leftCheckView: CheckView?
        private var icon: ComponentView<Empty>?
        
        private var arrowView: UIImageView?
        private var switchNode: SwitchNode?
        private var iconSwitchNode: IconSwitchNode?
        private var activityIndicatorView: UIActivityIndicatorView?
        private var customAccessoryView: ComponentView<Empty>?
        
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
                component.updateIsHighlighted?(self, isHighlighted)
                if isHighlighted, component.highlighting == .disabled {
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
        
        func update(component: ListActionItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let themeUpdated = component.theme !== previousComponent?.theme
            
            var customAccessorySize: CGSize?
            var customAccessoryTransition: ComponentTransition = transition
            
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
            case let .custom(customAccessory):
                if case let .custom(previousCustomAccessory) = previousComponent?.accessory, previousCustomAccessory.component.id != customAccessory.component.id {
                    self.customAccessoryView?.view?.removeFromSuperview()
                    self.customAccessoryView = nil
                }
                
                let customAccessoryView: ComponentView<Empty>
                if let current = self.customAccessoryView {
                    customAccessoryView = current
                } else {
                    customAccessoryTransition = customAccessoryTransition.withAnimation(.none)
                    customAccessoryView = ComponentView()
                    self.customAccessoryView = customAccessoryView
                }
                
                let customAccessorySizeValue = customAccessoryView.update(
                    transition: customAccessoryTransition,
                    component: customAccessory.component.component,
                    environment: {},
                    containerSize: availableSize
                )
                customAccessorySize = customAccessorySizeValue
                contentRightInset = customAccessorySizeValue.width + customAccessory.insets.left + customAccessory.insets.right
            }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += component.contentInsets.top
            
            if let leftIcon = component.leftIcon {
                switch leftIcon {
                case .check:
                    contentLeftInset += 46.0
                case .custom:
                    contentLeftInset += 46.0
                }
            }

            let titleSize = self.title.update(
                transition: transition,
                component: component.title,
                environment: {},
                containerSize: CGSize(width: availableSize.width - contentLeftInset - contentRightInset, height: availableSize.height)
            )
            
            if case .center = component.titleAlignment {
                contentLeftInset = floor((availableSize.width - titleSize.width) / 2.0)
            }
            
           
            let titleY = contentHeight
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
                switch leftIconValue {
                case let .check(check):
                    if let leftIcon = self.leftIcon {
                        self.leftIcon = nil
                        if let iconView = leftIcon.view {
                            transition.setAlpha(view: iconView, alpha: 0.0, completion: { [weak iconView] _ in
                                iconView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    let leftCheckView: CheckView
                    var animateIn = false
                    if let current = self.leftCheckView {
                        leftCheckView = current
                    } else {
                        animateIn = true
                        leftCheckView = CheckView()
                        self.leftCheckView = leftCheckView
                        self.addSubview(leftCheckView)
                        
                        leftCheckView.action = { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            if case let .check(check) = component.leftIcon {
                                check.toggle?()
                            }
                        }
                    }
                    
                    leftCheckView.isUserInteractionEnabled = check.toggle != nil
                    
                    let checkSize = CGSize(width: 22.0, height: 22.0)
                    let checkFrame = CGRect(origin: CGPoint(x: floor((contentLeftInset - checkSize.width) * 0.5), y: floor((contentHeight - checkSize.height) * 0.5)), size: checkSize)
                    
                    if animateIn {
                        leftCheckView.frame = CGRect(origin: CGPoint(x: -checkSize.width, y: self.bounds.height == 0.0 ? checkFrame.minY : floor((self.bounds.height - checkSize.height) * 0.5)), size: checkFrame.size)
                        transition.setPosition(view: leftCheckView, position: checkFrame.center)
                        transition.setBounds(view: leftCheckView, bounds: CGRect(origin: CGPoint(), size: checkFrame.size))
                        leftCheckView.update(size: checkFrame.size, theme: component.theme, isSelected: check.isSelected, transition: .immediate)
                    } else {
                        transition.setPosition(view: leftCheckView, position: checkFrame.center)
                        transition.setBounds(view: leftCheckView, bounds: CGRect(origin: CGPoint(), size: checkFrame.size))
                        leftCheckView.update(size: checkFrame.size, theme: component.theme, isSelected: check.isSelected, transition: transition)
                    }
                case let .custom(customLeftIcon, adjustLeftInset):
                    var resetLeftIcon = false
                    if case let .custom(previousCustomLeftIcon, _) = previousComponent?.leftIcon {
                        if previousCustomLeftIcon.id != customLeftIcon.id {
                            resetLeftIcon = true
                        }
                    } else {
                        resetLeftIcon = true
                    }
                    if resetLeftIcon {
                        if let leftIcon = self.leftIcon {
                            self.leftIcon = nil
                            if let iconView = leftIcon.view {
                                transition.setAlpha(view: iconView, alpha: 0.0, completion: { [weak iconView] _ in
                                    iconView?.removeFromSuperview()
                                })
                            }
                        }
                    }
                    if let leftCheckView = self.leftCheckView {
                        self.leftCheckView = nil
                        transition.setAlpha(view: leftCheckView, alpha: 0.0, completion: { [weak leftCheckView] _ in
                            leftCheckView?.removeFromSuperview()
                        })
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
                        component: customLeftIcon.component,
                        environment: {},
                        containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                    )
                    let leftIconX: CGFloat
                    if adjustLeftInset {
                        leftIconX = 15.0
                    } else {
                        leftIconX = floor((contentLeftInset - leftIconSize.width) * 0.5)
                    }
                    let leftIconFrame = CGRect(origin: CGPoint(x: leftIconX, y: floor((min(60.0, contentHeight) - leftIconSize.height) * 0.5)), size: leftIconSize)
                    if let leftIconView = leftIcon.view {
                        if leftIconView.superview == nil {
                            leftIconView.isUserInteractionEnabled = false
                            self.addSubview(leftIconView)
                            transition.animateAlpha(view: leftIconView, from: 0.0, to: 1.0)
                        }
                        leftIconTransition.setFrame(view: leftIconView, frame: leftIconFrame)
                    }
                    if adjustLeftInset {
                        contentLeftInset = 22.0 + leftIconSize.width
                    }
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
                if let leftCheckView = self.leftCheckView {
                    self.leftCheckView = nil
                    transition.setAlpha(view: leftCheckView, alpha: 0.0, completion: { [weak leftCheckView] _ in
                        leftCheckView?.removeFromSuperview()
                    })
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
                case .icons, .lock:
                    let switchNode: IconSwitchNode
                    var switchTransition = transition
                    var updateSwitchTheme = themeUpdated
                    if let current = self.iconSwitchNode {
                        switchNode = current
                        switchNode.updateIsLocked(toggle.style == .lock)
                        if switchNode.isOn != toggle.isOn {
                            switchNode.setOn(toggle.isOn, animated: !transition.animation.isImmediate)
                        }
                    } else {
                        switchTransition = switchTransition.withAnimation(.none)
                        updateSwitchTheme = true
                        switchNode = IconSwitchNode()
                        switchNode.updateIsLocked(toggle.style == .lock)
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
            
            if case let .custom(customAccessory) = component.accessory, let customAccessoryView = self.customAccessoryView, let customAccessorySize {
                let activityAccessoryFrame = CGRect(origin: CGPoint(x: availableSize.width - customAccessory.insets.right - customAccessorySize.width, y: floor((contentHeight - customAccessorySize.height) * 0.5)), size: customAccessorySize)
                if let customAccessoryComponentView = customAccessoryView.view {
                    if customAccessoryComponentView.superview == nil {
                        customAccessoryComponentView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                        self.addSubview(customAccessoryComponentView)
                    }
                    customAccessoryComponentView.isUserInteractionEnabled = customAccessory.isInteractive
                    customAccessoryTransition.setPosition(view: customAccessoryComponentView, position: CGPoint(x: activityAccessoryFrame.maxX, y: activityAccessoryFrame.minY))
                    customAccessoryTransition.setBounds(view: customAccessoryComponentView, bounds: CGRect(origin: CGPoint(), size: activityAccessoryFrame.size))
                }
            } else {
                if let customAccessoryView = self.customAccessoryView {
                    self.customAccessoryView = nil
                    customAccessoryView.view?.removeFromSuperview()
                }
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: contentLeftInset, y: titleY), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            self.separatorInset = contentLeftInset
            
            if let backgroundComponent = component.background {
                var backgroundTransition = transition
                let background: ComponentView<Empty>
                if let current = self.background {
                    background = current
                } else {
                    backgroundTransition = backgroundTransition.withAnimation(.none)
                    background = ComponentView()
                    self.background = background
                }
                
                let backgroundSize = background.update(
                    transition: backgroundTransition,
                    component: backgroundComponent,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: contentHeight)
                )
                let backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
                if let backgroundView = background.view {
                    if backgroundView.superview == nil {
                        backgroundView.isUserInteractionEnabled = false
                        self.addSubview(backgroundView)
                        transition.animateAlpha(view: backgroundView, from: 0.0, to: 1.0)
                    }
                    backgroundTransition.setFrame(view: backgroundView, frame: backgroundFrame)
                }
            } else {
                if let background = self.background {
                    self.background = nil
                    if let backgroundView = background.view {
                        transition.setAlpha(view: backgroundView, alpha: 0.0, completion: { [weak backgroundView] _ in
                            backgroundView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
