import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import TelegramPresentationData

public final class SwitchComponent: Component {
    public typealias EnvironmentType = Empty
    
    let tintColor: UIColor?
    let value: Bool
    let valueUpdated: (Bool) -> Void
    
    public init(
        tintColor: UIColor? = nil,
        value: Bool,
        valueUpdated: @escaping (Bool) -> Void
    ) {
        self.tintColor = tintColor
        self.value = value
        self.valueUpdated = valueUpdated
    }
    
    public static func ==(lhs: SwitchComponent, rhs: SwitchComponent) -> Bool {
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let switchView: UISwitch
    
        private var component: SwitchComponent?
        
        override init(frame: CGRect) {
            self.switchView = UISwitch()
            
            super.init(frame: frame)
            
            self.addSubview(self.switchView)
            
            self.switchView.addTarget(self, action: #selector(self.valueChanged(_:)), for: .valueChanged)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func valueChanged(_ sender: Any) {
            self.component?.valueUpdated(self.switchView.isOn)
        }
        
        func update(component: SwitchComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
          
            self.switchView.tintColor = component.tintColor
            self.switchView.setOn(component.value, animated: !transition.animation.isImmediate)
            
            self.switchView.sizeToFit()
            self.switchView.frame = CGRect(origin: .zero, size: self.switchView.frame.size)
                        
            return self.switchView.frame.size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
