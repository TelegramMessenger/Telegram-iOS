import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore

final class VideoChatParticipantStatusComponent: Component {
    let muteState: GroupCallParticipantsContext.Participant.MuteState?
    let isSpeaking: Bool
    let theme: PresentationTheme

    init(
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        isSpeaking: Bool,
        theme: PresentationTheme
    ) {
        self.muteState = muteState
        self.isSpeaking = isSpeaking
        self.theme = theme
    }

    static func ==(lhs: VideoChatParticipantStatusComponent, rhs: VideoChatParticipantStatusComponent) -> Bool {
        if lhs.muteState != rhs.muteState {
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
                    content: .mute(isFilled: false, isMuted: component.muteState != nil && !component.isSpeaking)
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
                    let iconTintColor: UIColor
                    if component.isSpeaking {
                        iconTintColor = UIColor(rgb: 0x33C758)
                    } else {
                        if let muteState = component.muteState {
                            if muteState.canUnmute {
                                iconTintColor = UIColor(white: 1.0, alpha: 0.4)
                            } else {
                                iconTintColor = UIColor(rgb: 0xFF3B30)
                            }
                        } else {
                            iconTintColor = UIColor(white: 1.0, alpha: 0.4)
                        }
                    }
                    
                    tintTransition.setTintColor(layer: iconView.layer, color: iconTintColor)
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
