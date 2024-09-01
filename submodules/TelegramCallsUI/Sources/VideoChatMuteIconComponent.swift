import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import LottieComponent

final class VideoChatMuteIconComponent: Component {
    let color: UIColor
    let isMuted: Bool

    init(
        color: UIColor,
        isMuted: Bool
    ) {
        self.color = color
        self.isMuted = isMuted
    }

    static func ==(lhs: VideoChatMuteIconComponent, rhs: VideoChatMuteIconComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.isMuted != rhs.isMuted {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let icon: VoiceChatMicrophoneNode

        private var component: VideoChatMuteIconComponent?
        private var isUpdating: Bool = false
        
        private var contentImage: UIImage?
        
        override init(frame: CGRect) {
            self.icon = VoiceChatMicrophoneNode()
            
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
            
            let animationSize = availableSize
            
            let animationFrame = animationSize.centered(in: CGRect(origin: CGPoint(), size: availableSize))
            if self.icon.view.superview == nil {
                self.addSubview(self.icon.view)
            }
            transition.setFrame(view: self.icon.view, frame: animationFrame)
            self.icon.update(state: VoiceChatMicrophoneNode.State(muted: component.isMuted, filled: true, color: component.color), animated: !transition.animation.isImmediate)
            
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
