import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import SwitchComponent

public final class ListSwitchItemComponent: Component {
    let theme: PresentationTheme
    let title: String
    let value: Bool
    let valueUpdated: (Bool) -> Void
    let accessibility: ComponentAccessibility?
    
    public init(
        theme: PresentationTheme,
        title: String,
        value: Bool,
        valueUpdated: @escaping (Bool) -> Void,
        accessibility: ComponentAccessibility? = nil
    ) {
        self.theme = theme
        self.title = title
        self.value = value
        self.valueUpdated = valueUpdated
        self.accessibility = accessibility
    }
    
    public static func ==(lhs: ListSwitchItemComponent, rhs: ListSwitchItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.accessibility != rhs.accessibility {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        private let switchView = ComponentView<Empty>()
        
        private var component: ListSwitchItemComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        override public func accessibilityActivate() -> Bool {
            guard let component = self.component else {
                return false
            }
            component.valueUpdated(!component.value)
            return true
        }
        
        func update(component: ListSwitchItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            self.layer.cornerRadius = 26.0
            
            let size = CGSize(width: availableSize.width, height: 52.0)
            let rightInset: CGFloat = 16.0
            let leftInset: CGFloat = 16.0
            let spacing: CGFloat = 8.0
            
            let switchSize = self.switchView.update(
                transition: transition,
                component: AnyComponent(SwitchComponent(
                    value: component.value,
                    valueUpdated: { [weak self] value in
                        guard let self else {
                            return
                        }
                        self.component?.valueUpdated(value)
                    }
                )),
                environment: {},
                containerSize: size
            )
            let switchFrame = CGRect(origin: CGPoint(x: size.width - rightInset - switchSize.width, y: floor((size.height - switchSize.height) * 0.5)), size: switchSize)
            if let switchComponentView = self.switchView.view {
                if switchComponentView.superview == nil {
                    self.addSubview(switchComponentView)
                }
                transition.setFrame(view: switchComponentView, frame: switchFrame)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.title, font: Font.regular(17.0), color: component.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: max(1.0, switchFrame.minX - spacing - leftInset), height: .greatestFiniteMagnitude)
            )
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            // The row is one element: the title and the switch are not reachable on their own. Activating it flips the
            // switch through the same callback.
            let toggleDefaults = ComponentAccessibility.toggleDefaults(isOn: component.value)
            var accessibility = component.accessibility ?? ComponentAccessibility()
            if !accessibility.isHidden {
                if accessibility.label == nil {
                    accessibility.label = component.title
                }
                if accessibility.value == nil {
                    accessibility.value = toggleDefaults.value
                }
            }
            self.apply(accessibility: accessibility, defaultTraits: toggleDefaults.traits)
            
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
