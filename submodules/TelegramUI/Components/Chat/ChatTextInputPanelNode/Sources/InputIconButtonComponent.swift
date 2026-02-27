import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import AppBundle

final class InputIconButtonComponent: Component {
    let theme: PresentationTheme
    let name: String
    let action: (UIView) -> Void
    
    init(
        theme: PresentationTheme,
        name: String,
        action: @escaping (UIView) -> Void
    ) {
        self.theme = theme
        self.name = name
        self.action = action
    }
    
    static func ==(lhs: InputIconButtonComponent, rhs: InputIconButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private let button: HighlightTrackingButton
        private let iconView: GlassBackgroundView.ContentImageView
        
        private var component: InputIconButtonComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            self.button = HighlightTrackingButton()
            self.iconView = GlassBackgroundView.ContentImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.iconView)
            self.backgroundView.contentView.addSubview(self.button)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if #available(iOS 26.0, *) {
                } else {
                    self.iconView.alpha = highlighted ? 1.0 : 0.7
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
            self.component?.action(self)
        }
        
        func update(component: InputIconButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component?.name != component.name {
                self.iconView.image = UIImage(bundleImageName: component.name)?.withRenderingMode(.alwaysTemplate)
            }
            
            self.iconView.tintColor = component.theme.chat.inputPanel.panelControlColor
            
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)
            
            if let image = self.iconView.image {
                self.iconView.frame = image.size.centered(in: CGRect(origin: CGPoint(), size: size))
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            
            self.button.frame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
