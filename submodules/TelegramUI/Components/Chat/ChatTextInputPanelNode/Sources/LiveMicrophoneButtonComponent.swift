import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import SwiftSignalKit
import VideoChatMicButtonComponent
import AccountContext

final class LiveMicrophoneButtonComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let call: AnyObject?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        call: AnyObject?
    ) {
        self.theme = theme
        self.strings = strings
        self.call = call
    }
    
    static func ==(lhs: LiveMicrophoneButtonComponent, rhs: LiveMicrophoneButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.call !== rhs.call {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let button = ComponentView<Empty>()
        
        private var component: LiveMicrophoneButtonComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var callStateDisposable: Disposable?
        private var muteStateDisposable: Disposable?
        private var callState: PresentationGroupCallState?
        private var isMuted: Bool = false
        private var isPushToTalkActive: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.muteStateDisposable?.dispose()
            self.callStateDisposable?.dispose()
        }
        
        func update(component: LiveMicrophoneButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.callStateDisposable == nil, let call = component.call as? PresentationGroupCall {
                self.callStateDisposable = (call.state
                |> deliverOnMainQueue).startStrict(next: { [weak self] callState in
                    guard let self else {
                        return
                    }
                    if self.callState != callState {
                        self.callState = callState
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                })
            }
            
            if self.muteStateDisposable == nil, let call = component.call as? PresentationGroupCall {
                self.muteStateDisposable = (call.isMuted
                |> deliverOnMainQueue).startStrict(next: { [weak self] isMuted in
                    guard let self else {
                        return
                    }
                    if self.isMuted != isMuted {
                        self.isMuted = isMuted
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                })
            }
            
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)
            
            let micButtonContent: VideoChatMicButtonComponent.Content
            if let callState = self.callState {
                switch callState.networkState {
                case .connecting:
                    micButtonContent = .connecting
                case .connected:
                    if let _ = callState.muteState {
                        if self.isPushToTalkActive {
                        micButtonContent = .unmuted(pushToTalk: self.isPushToTalkActive)
                    } else {
                        micButtonContent = .muted(forced: false)
                    }
                    } else {
                        micButtonContent = .unmuted(pushToTalk: false)
                    }
                }
            } else {
                micButtonContent = .connecting
            }
            
            let _ = self.button.update(
                transition: transition,
                component: AnyComponent(VideoChatMicButtonComponent(
                    call: component.call.flatMap { call -> VideoChatCall? in
                        if let call = call as? PresentationGroupCall {
                            return .group(call)
                        } else {
                            return nil
                        }
                    },
                    strings: component.strings,
                    content: micButtonContent,
                    isCollapsed: true,
                    isCompact: true,
                    customIconScale: 0.45,
                    updateUnmutedStateIsPushToTalk: { [weak self] unmutedStateIsPushToTalk in
                        guard let self, let component = self.component, let call = component.call as? PresentationGroupCall else {
                            return
                        }
                        if let unmutedStateIsPushToTalk {
                            if unmutedStateIsPushToTalk {
                                self.isPushToTalkActive = true
                                call.setIsMuted(action: .muted(isPushToTalkActive: true))
                            } else {
                                call.setIsMuted(action: .unmuted)
                                self.isPushToTalkActive = false
                            }
                            self.state?.updated(transition: .spring(duration: 0.4))
                        } else {
                            call.setIsMuted(action: .muted(isPushToTalkActive: false))
                            self.isPushToTalkActive = false
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    raiseHand: {},
                    scheduleAction: {}
                )),
                environment: {},
                containerSize: size
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                buttonView.frame = CGRect(origin: CGPoint(), size: size)
            }

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
