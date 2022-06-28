import Foundation
import UIKit
import ComponentFlow
import Display
import SolidRoundedButtonNode
import AppBundle

public final class SolidRoundedButtonComponent: Component {
    public typealias Theme = SolidRoundedButtonTheme
    
    public let title: String?
    public let icon: UIImage?
    public let theme: SolidRoundedButtonTheme
    public let font: SolidRoundedButtonFont
    public let fontSize: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat
    public let gloss: Bool
    public let iconName: String?
    public let animationName: String?
    public let iconPosition: SolidRoundedButtonIconPosition
    public let iconSpacing: CGFloat
    public let isLoading: Bool
    public let action: () -> Void
    
    public init(
        title: String? = nil,
        icon: UIImage? = nil,
        theme: SolidRoundedButtonTheme,
        font: SolidRoundedButtonFont = .bold,
        fontSize: CGFloat = 17.0,
        height: CGFloat = 48.0,
        cornerRadius: CGFloat = 24.0,
        gloss: Bool = false,
        iconName: String? = nil,
        animationName: String? = nil,
        iconPosition: SolidRoundedButtonIconPosition = .left,
        iconSpacing: CGFloat = 8.0,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.theme = theme
        self.font = font
        self.fontSize = fontSize
        self.height = height
        self.cornerRadius = cornerRadius
        self.gloss = gloss
        self.iconName = iconName
        self.animationName = animationName
        self.iconPosition = iconPosition
        self.iconSpacing = iconSpacing
        self.isLoading = isLoading
        self.action = action
    }
    
    public static func ==(lhs: SolidRoundedButtonComponent, rhs: SolidRoundedButtonComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.icon !== rhs.icon {
            return false
        }
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.height != rhs.height {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.gloss != rhs.gloss {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.animationName != rhs.animationName {
            return false
        }
        if lhs.iconPosition != rhs.iconPosition {
            return false
        }
        if lhs.iconSpacing != rhs.iconSpacing {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: SolidRoundedButtonComponent?
        private var button: SolidRoundedButtonView?
        
        private var currentIsLoading = false
        
        public func update(component: SolidRoundedButtonComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.button == nil {
                let button = SolidRoundedButtonView(
                    title: component.title,
                    icon: component.icon,
                    theme: component.theme,
                    font: component.font,
                    fontSize: component.fontSize,
                    height: component.height,
                    cornerRadius: component.cornerRadius,
                    gloss: component.gloss
                )
                button.progressType = .embedded
                self.button = button
                self.addSubview(button)
                
                button.pressed = { [weak self] in
                    self?.component?.action()
                }
            }
            
            if let button = self.button {
                button.title = component.title
                button.iconPosition = component.iconPosition
                button.iconSpacing = component.iconSpacing
                button.icon = component.iconName.flatMap { UIImage(bundleImageName: $0) }
                button.animation = component.animationName
                button.gloss = component.gloss
                
                button.updateTheme(component.theme)
                let height = button.updateLayout(width: availableSize.width, transition: .immediate)
                transition.setFrame(view: button, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height)), completion: nil)
                
                if self.currentIsLoading != component.isLoading {
                    self.currentIsLoading = component.isLoading
                    if component.isLoading {
                        button.transitionToProgress()
                    } else {
                        button.transitionFromProgress()
                    }
                }
            }
            
            self.component = component
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
