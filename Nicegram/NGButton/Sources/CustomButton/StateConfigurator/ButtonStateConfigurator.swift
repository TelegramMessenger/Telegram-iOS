import UIKit

public struct ButtonStateConfigurator {
    public let configure: (CustomButton, UIControl.State) -> Void
    
    public init(configure: @escaping (CustomButton, UIControl.State) -> Void) {
        self.configure = configure
    }
}

public extension ButtonStateConfigurator {
    static func foregroundTint() -> ButtonStateConfigurator {
        return ButtonStateConfigurator { button, state in
            guard let foregroundColor = button.foregroundColor else { return }
            
            let newForegroundColor: UIColor
            switch state {
            case .highlighted, .selected:
                newForegroundColor = foregroundColor.withMultipliedAlphaComponent(0.5)
            default:
                newForegroundColor = foregroundColor
            }
            
            button.configureTitleLabel { l in
                l.textColor = newForegroundColor
            }
            button.configureImageContainer { i in
                i.tintColor = newForegroundColor
            }
        }
    }
}

public extension UIColor {
    func withMultipliedAlphaComponent(_ multiplier: CGFloat) -> UIColor {
        guard let components = getComponents() else { return self }
        return withAlphaComponent(components.a * multiplier)
    }
}

public extension UIColor {
    func getComponents() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        let c = cgColor.components ?? []
        if c.count == 2 {
            return (r: c[0], g: c[0], b: c[0], a: c[1])
        } else if c.count == 4 {
            return (r: c[0], g: c[1], b: c[2], a: c[3])
        } else {
            return nil
        }
    }
}
