import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import LottieComponent

final class VideoChatMicButtonComponent: Component {
    enum Content {
        case connecting
        case muted
        case unmuted
    }
    
    let content: Content
    let isCollapsed: Bool

    init(
        content: Content,
        isCollapsed: Bool
    ) {
        self.content = content
        self.isCollapsed = isCollapsed
    }

    static func ==(lhs: VideoChatMicButtonComponent, rhs: VideoChatMicButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.isCollapsed != rhs.isCollapsed {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let background = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()

        private var component: VideoChatMicButtonComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: VideoChatMicButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let titleText: String
            let backgroundColor: UIColor
            switch component.content {
            case .connecting:
                titleText = "Connecting..."
                backgroundColor = UIColor(white: 1.0, alpha: 0.1)
            case .muted:
                titleText = "Unmute"
                backgroundColor = UIColor(rgb: 0x0086FF)
            case .unmuted:
                titleText = "Mute"
                backgroundColor = UIColor(rgb: 0x34C659)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(15.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: availableSize.height)
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: backgroundColor,
                    cornerRadius: size.width * 0.5,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: size.height + 16.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                alphaTransition.setAlpha(view: titleView, alpha: component.isCollapsed ? 0.0 : 1.0)
            }
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(
                        name: "VoiceUnmute"
                    ),
                    color: .white
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                transition.setBounds(view: iconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                transition.setScale(view: iconView, scale: component.isCollapsed ? ((iconSize.width - 24.0) / iconSize.width) : 1.0)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
