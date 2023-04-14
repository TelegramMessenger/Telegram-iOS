import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle

public final class ActionPanelComponent: Component {
    public enum Color {
        case accent
        case destructive
    }
    
    public let theme: PresentationTheme
    public let title: String
    public let color: Color
    public let action: () -> Void
    public let dismissAction: () -> Void
    
    public init(
        theme: PresentationTheme,
        title: String,
        color: Color,
        action: @escaping () -> Void,
        dismissAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.color = color
        self.action = action
        self.dismissAction = dismissAction
    }
    
    public static func ==(lhs: ActionPanelComponent, rhs: ActionPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private let backgroundView: BlurredBackgroundView
        private let separatorLayer: SimpleLayer
        
        private let contentView: UIView
        private let title = ComponentView<Empty>()
        
        private let dismissButton: HighlightTrackingButton
        private let dismissIconView: UIImageView
        
        private var component: ActionPanelComponent?
        
        public override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.backgroundView.isUserInteractionEnabled = false
            
            self.separatorLayer = SimpleLayer()
            self.contentView = UIView()
            self.contentView.isUserInteractionEnabled = false
            
            self.dismissButton = HighlightTrackingButton()
            self.dismissIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.contentView)
            
            self.dismissButton.addSubview(self.dismissIconView)
            self.addSubview(self.dismissButton)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self {
                    if highlighted {
                        self.contentView.layer.removeAnimation(forKey: "opacity")
                        self.contentView.alpha = 0.65
                    } else {
                        self.contentView.alpha = 1.0
                        self.contentView.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
                    }
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.dismissButton.highligthedChanged = { [weak self] highlighted in
                if let self {
                    if highlighted {
                        self.dismissButton.layer.removeAnimation(forKey: "opacity")
                        self.dismissButton.alpha = 0.65
                    } else {
                        self.dismissButton.alpha = 1.0
                        self.dismissButton.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
                    }
                }
            }
            self.dismissButton.addTarget(self, action: #selector(self.dismissPressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        @objc private func dismissPressed() {
            guard let component = self.component else {
                return
            }
            component.dismissAction()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        func update(component: ActionPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            if themeUpdated {
                self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
                
                self.dismissIconView.image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/EncircledCloseButton")?.withRenderingMode(.alwaysTemplate)
                self.dismissIconView.tintColor = component.theme.rootController.navigationBar.accentTextColor
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.backgroundView.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let rightInset: CGFloat = 44.0
            
            let resolvedColor: UIColor
            switch component.color {
            case .accent:
                resolvedColor = component.theme.rootController.navigationBar.accentTextColor
            case .destructive:
                resolvedColor = component.theme.list.itemDestructiveColor
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.title, font: Font.regular(17.0), color: resolvedColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - rightInset, height: availableSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.contentView.addSubview(titleView)
                }
                let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((availableSize.height - titleSize.height) * 0.5)), size: titleSize)
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let dismissButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - rightInset, y: 0.0), size: CGSize(width: rightInset, height: availableSize.height))
            transition.setFrame(view: self.dismissButton, frame: dismissButtonFrame)
            if let iconImage = self.dismissIconView.image {
                transition.setFrame(view: self.dismissIconView, frame: CGRect(origin: CGPoint(x: floor((dismissButtonFrame.width - iconImage.size.width) * 0.5), y: floor((dismissButtonFrame.height - iconImage.size.height) * 0.5)), size: iconImage.size))
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
