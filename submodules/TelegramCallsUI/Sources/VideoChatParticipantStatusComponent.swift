import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore
import LottieComponent

final class VideoChatParticipantStatusComponent: Component {
    let muteState: GroupCallParticipantsContext.Participant.MuteState?
    let hasRaiseHand: Bool
    let isSpeaking: Bool
    let theme: PresentationTheme

    init(
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        hasRaiseHand: Bool,
        isSpeaking: Bool,
        theme: PresentationTheme
    ) {
        self.muteState = muteState
        self.hasRaiseHand = hasRaiseHand
        self.isSpeaking = isSpeaking
        self.theme = theme
    }

    static func ==(lhs: VideoChatParticipantStatusComponent, rhs: VideoChatParticipantStatusComponent) -> Bool {
        if lhs.muteState != rhs.muteState {
            return false
        }
        if lhs.hasRaiseHand != rhs.hasRaiseHand {
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
        private var muteStatus: ComponentView<Empty>?
        private var raiseHandStatus: ComponentView<Empty>?
        
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
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.2)
            } else {
                alphaTransition = .immediate
            }
            
            let size = CGSize(width: 44.0, height: 44.0)
            
            let isRaiseHand: Bool
            if let muteState = component.muteState {
                if muteState.canUnmute {
                    isRaiseHand = false
                } else {
                    isRaiseHand = component.hasRaiseHand
                }
            } else {
                isRaiseHand = false
            }
            
            if !isRaiseHand {
                let muteStatus: ComponentView<Empty>
                var muteStatusTransition = transition
                if let current = self.muteStatus {
                    muteStatus = current
                } else {
                    muteStatusTransition = muteStatusTransition.withAnimation(.none)
                    muteStatus = ComponentView()
                    self.muteStatus = muteStatus
                }
                
                let muteStatusSize = muteStatus.update(
                    transition: muteStatusTransition,
                    component: AnyComponent(VideoChatMuteIconComponent(
                        color: .white,
                        content: .mute(isFilled: false, isMuted: component.muteState != nil && !component.isSpeaking)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 36.0, height: 36.0)
                )
                let muteStatusFrame = CGRect(origin: CGPoint(x: floor((size.width - muteStatusSize.width) * 0.5), y: floor((size.height - muteStatusSize.height) * 0.5)), size: muteStatusSize)
                if let muteStatusView = muteStatus.view as? VideoChatMuteIconComponent.View {
                    var animateIn = false
                    if muteStatusView.superview == nil {
                        animateIn = true
                        self.addSubview(muteStatusView)
                    }
                    muteStatusTransition.setFrame(view: muteStatusView, frame: muteStatusFrame)
                    
                    let tintTransition: ComponentTransition
                    if !muteStatusTransition.animation.isImmediate {
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
                    
                    if animateIn, !transition.animation.isImmediate {
                        transition.animateScale(view: muteStatusView, from: 0.001, to: 1.0)
                        alphaTransition.animateAlpha(view: muteStatusView, from: 0.0, to: 1.0)
                    }
                }
            } else if let muteStatus = self.muteStatus {
                self.muteStatus = nil
                
                if let muteStatusView = muteStatus.view {
                    if !transition.animation.isImmediate {
                        transition.setScale(view: muteStatusView, scale: 0.001)
                        alphaTransition.setAlpha(view: muteStatusView, alpha: 0.0, completion: { [weak muteStatusView] _ in
                            muteStatusView?.removeFromSuperview()
                        })
                    } else {
                        muteStatusView.removeFromSuperview()
                    }
                }
            }
            
            if isRaiseHand {
                let raiseHandStatus: ComponentView<Empty>
                var raiseHandStatusTransition = transition
                if let current = self.raiseHandStatus {
                    raiseHandStatus = current
                } else {
                    raiseHandStatusTransition = raiseHandStatusTransition.withAnimation(.none)
                    raiseHandStatus = ComponentView()
                    self.raiseHandStatus = raiseHandStatus
                }
                
                let raiseHandStatusSize = raiseHandStatus.update(
                    transition: raiseHandStatusTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "anim_hand1"
                        ),
                        color: component.theme.list.itemAccentColor,
                        size: CGSize(width: 48.0, height: 48.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 48.0, height: 48.0)
                )
                let raiseHandStatusFrame = CGRect(origin: CGPoint(x: floor((size.width - raiseHandStatusSize.width) * 0.5) - 2.0, y: floor((size.height - raiseHandStatusSize.height) * 0.5)), size: raiseHandStatusSize)
                if let raiseHandStatusView = raiseHandStatus.view {
                    var animateIn = false
                    if raiseHandStatusView.superview == nil {
                        animateIn = true
                        self.addSubview(raiseHandStatusView)
                    }
                    raiseHandStatusTransition.setFrame(view: raiseHandStatusView, frame: raiseHandStatusFrame)
                    
                    if animateIn, !transition.animation.isImmediate {
                        transition.animateScale(view: raiseHandStatusView, from: 0.001, to: 1.0)
                        alphaTransition.animateAlpha(view: raiseHandStatusView, from: 0.0, to: 1.0)
                    }
                }
            } else if let raiseHandStatus = self.raiseHandStatus {
                self.raiseHandStatus = nil
                
                if let raiseHandStatusView = raiseHandStatus.view {
                    if !transition.animation.isImmediate {
                        transition.setScale(view: raiseHandStatusView, scale: 0.001)
                        alphaTransition.setAlpha(view: raiseHandStatusView, alpha: 0.0, completion: { [weak raiseHandStatusView] _ in
                            raiseHandStatusView?.removeFromSuperview()
                        })
                    } else {
                        raiseHandStatusView.removeFromSuperview()
                    }
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
