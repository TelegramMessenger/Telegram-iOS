import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum PresentationCallState: Equatable {
    case waiting
    case ringing
    case requesting(Bool)
    case connecting
    case active(Double, Data)
    case terminating
    case terminated
    
    public static func ==(lhs: PresentationCallState, rhs: PresentationCallState) -> Bool {
        switch lhs {
            case .waiting:
                if case .waiting = rhs {
                    return true
                } else {
                    return false
                }
            case .ringing:
                if case .ringing = rhs {
                    return true
                } else {
                    return false
                }
            case let .requesting(ringing):
                if case .requesting(ringing) = rhs {
                    return true
                } else {
                    return false
                }
            case .connecting:
                if case .connecting = rhs {
                    return true
                } else {
                    return false
                }
            case let .active(timestamp, keyVisualHash):
                if case .active(timestamp, keyVisualHash) = rhs {
                    return true
                } else {
                    return false
                }
            case .terminating:
                if case .terminating = rhs {
                    return true
                } else {
                    return false
                }
            case .terminated:
                if case .terminated = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class PresentationCall {
    private let audioSession: ManagedAudioSession
    private let callSessionManager: CallSessionManager
    private let callKitIntegration: CallKitIntegration?
    
    let internalId: CallSessionInternalId
    let peerId: PeerId
    let isOutgoing: Bool
    let peer: Peer?
    
    private var sessionState: CallSession?
    private var ongoingGontext: OngoingCallContext
    
    private var sessionStateDisposable: Disposable?
    
    private let statePromise = ValuePromise<PresentationCallState>(.waiting, ignoreRepeated: true)
    public var state: Signal<PresentationCallState, NoError> {
        return self.statePromise.get()
    }
    
    private let isMutedPromise = ValuePromise<Bool>(false)
    private var isMutedValue = false
    public var isMuted: Signal<Bool, NoError> {
        return self.isMutedPromise.get()
    }
    
    private let speakerModePromise = ValuePromise<Bool>(false)
    private var speakerModeValue = false
    public var speakerMode: Signal<Bool, NoError> {
        return self.speakerModePromise.get()
    }
    
    private let canBeRemovedPromise = Promise<Bool>(false)
    private var didSetCanBeRemoved = false
    var canBeRemoved: Signal<Bool, NoError> {
        return self.canBeRemovedPromise.get()
    }
    
    private let hungUpPromise = ValuePromise<Bool>()
    
    private var activeTimestamp: Double?
    
    private var audioSessionControl: ManagedAudioSessionControl?
    private var audioSessionDisposable: Disposable?
    
    init(audioSession: ManagedAudioSession, callSessionManager: CallSessionManager, callKitIntegration: CallKitIntegration?, internalId: CallSessionInternalId, peerId: PeerId, isOutgoing: Bool, peer: Peer?) {
        self.audioSession = audioSession
        self.callSessionManager = callSessionManager
        self.callKitIntegration = callKitIntegration
        
        self.internalId = internalId
        self.peerId = peerId
        self.isOutgoing = isOutgoing
        self.peer = peer
        
        self.ongoingGontext = OngoingCallContext(callSessionManager: self.callSessionManager, internalId: self.internalId)
        
        self.sessionStateDisposable = (callSessionManager.callState(internalId: internalId)
            |> deliverOnMainQueue).start(next: { [weak self] sessionState in
                if let strongSelf = self {
                    strongSelf.updateSessionState(sessionState: sessionState, audioSessionControl: strongSelf.audioSessionControl)
                }
            })
        
        self.audioSessionDisposable = audioSession.push(audioSessionType: .voiceCall, manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    if let sessionState = strongSelf.sessionState {
                        strongSelf.updateSessionState(sessionState: sessionState, audioSessionControl: control)
                    } else {
                        strongSelf.audioSessionControl = control
                    }
                }
            }
        }, deactivate: { [weak self] in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        if let sessionState = strongSelf.sessionState {
                            strongSelf.updateSessionState(sessionState: sessionState, audioSessionControl: nil)
                        } else {
                            strongSelf.audioSessionControl = nil
                        }
                    }
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        })
    }
    
    deinit {
        self.sessionStateDisposable?.dispose()
        self.audioSessionDisposable?.dispose()
    }
    
    private func updateSessionState(sessionState: CallSession, audioSessionControl: ManagedAudioSessionControl?) {
        let previous = self.sessionState
        let previousControl = self.audioSessionControl
        self.sessionState = sessionState
        self.audioSessionControl = audioSessionControl
        
        let presentationState: PresentationCallState
        
        var wasActive = false
        var wasTerminated = false
        if let previous = previous {
            switch previous.state {
                case .active:
                    wasActive = true
                case .terminated:
                    wasTerminated = true
                default:
                    break
            }
        }
        
        if let audioSessionControl = audioSessionControl, previous == nil || previousControl == nil {
            audioSessionControl.setOutputMode(self.speakerModeValue ? .custom(.speaker) : .system)
            audioSessionControl.setup(synchronous: true)
        }
        
        switch sessionState.state {
            case .ringing:
                presentationState = .ringing
                if let _ = audioSessionControl, previous == nil || previousControl == nil {
                    self.callKitIntegration?.reportIncomingCall(uuid: self.internalId, handle: "\(self.peerId.id)", displayTitle: self.peer?.displayTitle ?? "Unknown", completion: { [weak self] error in
                        if error != nil {
                            Queue.mainQueue().async {
                                if let strongSelf = self {
                                    strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .hangUp)
                                }
                            }
                        }
                    })
                }
            case .accepting:
                presentationState = .connecting
            case .dropping:
                presentationState = .terminating
            case .terminated:
                presentationState = .terminated
            case let .requesting(ringing):
                presentationState = .requesting(ringing)
            case let .active(_, keyVisualHash, _):
                let timestamp: Double
                if let activeTimestamp = self.activeTimestamp {
                    timestamp = activeTimestamp
                } else {
                    timestamp = CFAbsoluteTimeGetCurrent()
                    self.activeTimestamp = timestamp
                }
                presentationState = .active(timestamp, keyVisualHash)
        }
        
        switch sessionState.state {
            case let .active(key, _, connections):
                if let audioSessionControl = audioSessionControl, !wasActive || previousControl == nil {
                    let audioSessionActive: Signal<Bool, NoError>
                    if let callKitIntegration = self.callKitIntegration {
                        audioSessionActive = callKitIntegration.audioSessionActive |> filter { $0 } |> timeout(2.0, queue: Queue.mainQueue(), alternate: Signal { [weak self] subscriber in
                            if let strongSelf = self, let audioSessionControl = strongSelf.audioSessionControl {
                                audioSessionControl.activate({ _ in })
                            }
                            subscriber.putNext(true)
                            subscriber.putCompletion()
                            return EmptyDisposable
                        })
                    } else {
                        audioSessionControl.activate({ _ in })
                        audioSessionActive = .single(true)
                    }
                    
                    self.ongoingGontext.start(key: key, isOutgoing: sessionState.isOutgoing, connections: connections, audioSessionActive: audioSessionActive)
                    if sessionState.isOutgoing {
                        self.callKitIntegration?.reportOutgoingCallConnected(uuid: sessionState.id, at: Date())
                    }
                }
            default:
                if wasActive {
                    self.ongoingGontext.stop()
                }
        }
        if case .terminated = sessionState.state, !wasTerminated {
            if !self.didSetCanBeRemoved {
                self.didSetCanBeRemoved = true
                self.canBeRemovedPromise.set(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
            }
            self.hungUpPromise.set(true)
            self.callKitIntegration?.dropCall(uuid: self.internalId)
        }
        self.statePromise.set(presentationState)
    }
    
    func answer() {
        self.callSessionManager.accept(internalId: self.internalId)
        self.callKitIntegration?.answerCall(uuid: self.internalId)
    }
    
    func hangUp() -> Signal<Bool, NoError> {
        self.callSessionManager.drop(internalId: self.internalId, reason: .hangUp)
        self.ongoingGontext.stop()
        
        return self.hungUpPromise.get()
    }
    
    func rejectBusy() {
        self.callSessionManager.drop(internalId: self.internalId, reason: .busy)
        self.ongoingGontext.stop()
    }
    
    func toggleIsMuted() {
        self.isMutedValue = !self.isMutedValue
        self.isMutedPromise.set(self.isMutedValue)
        self.ongoingGontext.setIsMuted(self.isMutedValue)
    }
    
    func toggleSpeaker() {
        self.speakerModeValue = !self.speakerModeValue
        self.speakerModePromise.set(self.speakerModeValue)
        if let audioSessionControl = self.audioSessionControl {
            audioSessionControl.setOutputMode(self.speakerModeValue ? .speakerIfNoHeadphones : .system)
        }
    }
}
