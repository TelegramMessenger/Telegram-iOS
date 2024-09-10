import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

final class VideoChatParticipantStatusComponent: Component {
    let isMuted: Bool
    let isSpeaking: Bool
    let theme: PresentationTheme

    init(
        isMuted: Bool,
        isSpeaking: Bool,
        theme: PresentationTheme
    ) {
        self.isMuted = isMuted
        self.isSpeaking = isSpeaking
        self.theme = theme
    }

    static func ==(lhs: VideoChatParticipantStatusComponent, rhs: VideoChatParticipantStatusComponent) -> Bool {
        if lhs.isMuted != rhs.isMuted {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private let muteStatus = ComponentView<Empty>()
        
        private var component: VideoChatParticipantStatusComponent?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: VideoChatParticipantStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let size = CGSize(width: 44.0, height: 44.0)
            
            let muteStatusSize = self.muteStatus.update(
                transition: transition,
                component: AnyComponent(VideoChatMuteIconComponent(
                    color: .white,
                    content: .mute(isFilled: false, isMuted: component.isMuted && !component.isSpeaking)
                )),
                environment: {},
                containerSize: CGSize(width: 36.0, height: 36.0)
            )
            let muteStatusFrame = CGRect(origin: CGPoint(x: floor((size.width - muteStatusSize.width) * 0.5), y: floor((size.height - muteStatusSize.height) * 0.5)), size: muteStatusSize)
            if let muteStatusView = self.muteStatus.view as? VideoChatMuteIconComponent.View {
                if muteStatusView.superview == nil {
                    self.addSubview(muteStatusView)
                }
                transition.setFrame(view: muteStatusView, frame: muteStatusFrame)
                
                let tintTransition: ComponentTransition
                if !transition.animation.isImmediate {
                    tintTransition = .easeInOut(duration: 0.2)
                } else {
                    tintTransition = .immediate
                }
                if let iconView = muteStatusView.iconView {
                    tintTransition.setTintColor(layer: iconView.layer, color: component.isSpeaking ? UIColor(rgb: 0x33C758) : UIColor(white: 1.0, alpha: 0.4))
                }
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
