import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import BundleIconComponent

private final class TranslateButtonContentComponent: CombinedComponent {
    let theme: PresentationTheme
    let title: String
    let icon: String
    
    init(
        theme: PresentationTheme,
        title: String,
        icon: String
    ) {
        self.theme = theme
        self.title = title
        self.icon = icon
    }

    static func ==(lhs: TranslateButtonContentComponent, rhs: TranslateButtonContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(Text.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
           
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.icon,
                    tintColor: component.theme.list.itemPrimaryTextColor
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )

            let title = title.update(
                component: Text(
                    text: component.title,
                    font: Font.regular(17.0),
                    color: component.theme.list.itemPrimaryTextColor
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let sideInset: CGFloat = 16.0
                        
            context.add(title
                .position(CGPoint(x: sideInset + title.size.width / 2.0, y: context.availableSize.height / 2.0))
            )

            context.add(icon
                .position(CGPoint(x: context.availableSize.width - sideInset - icon.size.width / 2.0, y: context.availableSize.height / 2.0))
            )
                        
            return context.availableSize
        }
    }
}

final class TranslateButtonComponent: Component {
    private let content: TranslateButtonContentComponent
    private let theme: PresentationTheme
    private let isEnabled: Bool
    private let action: () -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) {
        self.content = TranslateButtonContentComponent(theme: theme, title: title, icon: icon)
        self.isEnabled = isEnabled
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: TranslateButtonComponent, rhs: TranslateButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.content !== rhs.content {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        return true
    }
    
    final class View: HighlightTrackingButton {
        private let backgroundView: UIView
        private let centralContentView: ComponentHostView<Empty>
        
        private var component: TranslateButtonComponent?
        
        override init(frame: CGRect) {
            self.backgroundView = UIView()
            self.backgroundView.isUserInteractionEnabled = false
            
            self.centralContentView = ComponentHostView()
            self.centralContentView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.centralContentView)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self, let component = strongSelf.component {
                    if highlighted {
                        strongSelf.backgroundView.backgroundColor = component.theme.list.itemHighlightedBackgroundColor
                    } else {
                        UIView.animate(withDuration: 0.3, animations: {
                            strongSelf.backgroundView.backgroundColor = component.theme.list.itemBlocksBackgroundColor
                        })
                    }
                }
            }
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func pressed() {
            if let component = self.component {
                component.action()
            }
        }
        
        public func update(component: TranslateButtonComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            self.backgroundView.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            self.backgroundView.layer.cornerRadius = 10.0
            
            let _ = self.centralContentView.update(
                transition: transition,
                component: AnyComponent(component.content),
                environment: {},
                containerSize: availableSize
            )
            transition.setFrame(view: self.centralContentView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize), completion: nil)
            
            self.centralContentView.alpha = component.isEnabled ? 1.0 : 0.4
            self.isUserInteractionEnabled = component.isEnabled
                        
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
