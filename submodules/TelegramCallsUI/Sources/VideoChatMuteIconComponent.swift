import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import LottieComponent
import BundleIconComponent

final class VideoChatMuteIconComponent: Component {
    enum Content: Equatable {
        case mute(isFilled: Bool, isMuted: Bool)
        case screenshare
    }
    
    let color: UIColor
    let content: Content

    init(
        color: UIColor,
        content: Content
    ) {
        self.color = color
        self.content = content
    }

    static func ==(lhs: VideoChatMuteIconComponent, rhs: VideoChatMuteIconComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private var icon: VoiceChatMicrophoneNode?
        private var scheenshareIcon: ComponentView<Empty>?

        private var component: VideoChatMuteIconComponent?
        private var isUpdating: Bool = false
        
        private var contentImage: UIImage?
        
        var iconView: UIView? {
            return self.icon?.view
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: VideoChatMuteIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            if case let .mute(isFilled, isMuted) = component.content {
                let icon: VoiceChatMicrophoneNode
                if let current = self.icon {
                    icon = current
                } else {
                    icon = VoiceChatMicrophoneNode()
                    self.icon = icon
                    self.addSubview(icon.view)
                }
                
                let animationSize = availableSize
                let animationFrame = animationSize.centered(in: CGRect(origin: CGPoint(), size: availableSize))
                transition.setFrame(view: icon.view, frame: animationFrame)
                icon.update(state: VoiceChatMicrophoneNode.State(muted: isMuted, filled: isFilled, color: component.color), animated: !transition.animation.isImmediate)
            } else {
                if let icon = self.icon {
                    self.icon = nil
                    icon.view.removeFromSuperview()
                }
            }
            
            if case .screenshare = component.content {
                let scheenshareIcon: ComponentView<Empty>
                if let current = self.scheenshareIcon {
                    scheenshareIcon = current
                } else {
                    scheenshareIcon = ComponentView()
                    self.scheenshareIcon = scheenshareIcon
                }
                let scheenshareIconSize = scheenshareIcon.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Call/StatusScreen",
                        tintColor: component.color
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let scheenshareIconFrame = scheenshareIconSize.centered(in: CGRect(origin: CGPoint(), size: availableSize))
                if let scheenshareIconView = scheenshareIcon.view {
                    if scheenshareIconView.superview == nil {
                        self.addSubview(scheenshareIconView)
                    }
                    transition.setPosition(view: scheenshareIconView, position: scheenshareIconFrame.center)
                    transition.setBounds(view: scheenshareIconView, bounds: CGRect(origin: CGPoint(), size: scheenshareIconFrame.size))
                    transition.setScale(view: scheenshareIconView, scale: 1.5)
                }
            } else {
                if let scheenshareIcon = self.scheenshareIcon {
                    self.scheenshareIcon = nil
                    scheenshareIcon.view?.removeFromSuperview()
                }
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
