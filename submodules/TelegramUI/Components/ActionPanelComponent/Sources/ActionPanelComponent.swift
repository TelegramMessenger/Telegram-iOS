import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import GlassBackgroundComponent

public final class ActionPanelComponent: Component {
    public enum Color {
        case accent
        case destructive
    }
    
    public let theme: PresentationTheme
    public let title: String
    public let color: Color
    /// Insets the glass capsule keeps from the panel's sides, beyond its own margin (the safe insets, so that it lines up
    /// with the navigation bar's header panels; iPhone Duo's side strip).
    public let sideInsets: UIEdgeInsets
    public let action: () -> Void
    public let dismissAction: () -> Void
    
    public init(
        theme: PresentationTheme,
        title: String,
        color: Color,
        sideInsets: UIEdgeInsets = UIEdgeInsets(),
        action: @escaping () -> Void,
        dismissAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.color = color
        self.sideInsets = sideInsets
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
        if lhs.sideInsets != rhs.sideInsets {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private let backgroundContainer: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        private var capsuleFrame: CGRect = CGRect()
        
        private let contentView: UIView
        private let title = ComponentView<Empty>()
        
        private let dismissButton: HighlightTrackingButton
        private let dismissIconView: UIImageView
        
        private var component: ActionPanelComponent?
        
        public override init(frame: CGRect) {
            self.backgroundContainer = GlassBackgroundContainerView()
            self.backgroundContainer.isUserInteractionEnabled = false
            self.backgroundView = GlassBackgroundView()
            
            self.contentView = UIView()
            self.contentView.isUserInteractionEnabled = false
            
            self.dismissButton = HighlightTrackingButton()
            self.dismissIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.backgroundContainer.contentView.addSubview(self.backgroundView)
            self.addSubview(self.backgroundContainer)
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
        
        // Only the capsule takes touches: the margins around it show the list, and pass touches on to it.
        override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return self.capsuleFrame.contains(point)
        }
        
        func update(component: ActionPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            
            if themeUpdated {
                self.dismissIconView.image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/EncircledCloseButton")?.withRenderingMode(.alwaysTemplate)
                self.dismissIconView.tintColor = component.theme.rootController.navigationBar.accentTextColor
            }
            
            // A capsule of the folder tabs' glass, with their height and margins (`HeaderPanelContainerComponent`).
            let sideInset: CGFloat = 16.0
            let capsuleHeight: CGFloat = 40.0
            let capsuleFrame = CGRect(
                x: component.sideInsets.left + sideInset,
                y: availableSize.height - capsuleHeight,
                width: max(0.0, availableSize.width - component.sideInsets.left - component.sideInsets.right - sideInset * 2.0),
                height: capsuleHeight
            )
            self.capsuleFrame = capsuleFrame
            
            // The container outsets the glass so that its edge effects are not clipped.
            let containerOutset: CGFloat = 32.0
            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: availableSize).insetBy(dx: -containerOutset, dy: -containerOutset))
            self.backgroundContainer.update(size: CGSize(width: availableSize.width + containerOutset * 2.0, height: availableSize.height + containerOutset * 2.0), isDark: component.theme.overallDarkAppearance, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: capsuleFrame.offsetBy(dx: containerOutset, dy: containerOutset))
            self.backgroundView.update(size: capsuleFrame.size, cornerRadius: capsuleHeight * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)
            
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let buttonWidth: CGFloat = 44.0
            
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
                containerSize: CGSize(width: max(1.0, capsuleFrame.width - buttonWidth * 2.0), height: capsuleFrame.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.contentView.addSubview(titleView)
                }
                let titleFrame = CGRect(origin: CGPoint(x: capsuleFrame.minX + floor((capsuleFrame.width - titleSize.width) * 0.5), y: capsuleFrame.minY + floor((capsuleFrame.height - titleSize.height) * 0.5)), size: titleSize)
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            let dismissButtonFrame = CGRect(origin: CGPoint(x: capsuleFrame.maxX - buttonWidth, y: capsuleFrame.minY), size: CGSize(width: buttonWidth, height: capsuleFrame.height))
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
