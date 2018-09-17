import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private func p2pAllowed(settings: (VoiceCallSettings, VoipConfiguration)?, isContact: Bool) -> Bool {
    var mode: VoiceCallP2PMode? = settings?.0.p2pMode
    if mode == nil {
        mode = settings?.1.defaultP2PMode
    }
    switch (mode ?? .contacts, isContact) {
        case (.always, _), (.contacts, true):
            return true
        default:
            return false
    }
}

private func callKitIntegrationIfEnabled(_ integration: CallKitIntegration?, settings: VoiceCallSettings?) -> CallKitIntegration?  {
    let enabled = settings?.enableSystemIntegration ?? true
    return enabled ? integration : nil
}

private enum CurrentCall {
    case none
    case incomingRinging(CallSessionRingingState)
    case ongoing(CallSession, OngoingCallContext)
    
    var internalId: CallSessionInternalId? {
        switch self {
            case .none:
                return nil
            case let .incomingRinging(ringingState):
                return ringingState.id
            case let .ongoing(session, _):
                return session.id
        }
    }
}

public enum RequestCallResult {
    case requested
    case alreadyInProgress(PeerId)
}

public final class PresentationCallManager {
    private let postbox: Postbox
    private let getDeviceAccessData: () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void)
    private let networkType: Signal<NetworkType, NoError>
    private let audioSession: ManagedAudioSession
    private let callSessionManager: CallSessionManager
    private let callKitIntegration: CallKitIntegration?
    
    private var currentCall: PresentationCall?
    private let removeCurrentCallDisposable = MetaDisposable()
    
    private var ringingStatesDisposable: Disposable?
    
    private let hasActiveCallsPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var hasActiveCalls: Signal<Bool, NoError> {
        return self.hasActiveCallsPromise.get()
    }
    
    private let currentCallPromise = Promise<PresentationCall?>(nil)
    public var currentCallSignal: Signal<PresentationCall?, NoError> {
        return self.currentCallPromise.get()
    }
    
    private let startCallDisposable = MetaDisposable()
    
    private var proxyServer: ProxyServerSettings?
    private var proxyServerDisposable: Disposable?
    
    private var callSettings: (VoiceCallSettings, VoipConfiguration)?
    private var callSettingsDisposable: Disposable?
    
    public init(postbox: Postbox, getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void), networkType: Signal<NetworkType, NoError>, audioSession: ManagedAudioSession, callSessionManager: CallSessionManager) {
        self.postbox = postbox
        self.getDeviceAccessData = getDeviceAccessData
        self.networkType = networkType
        self.audioSession = audioSession
        self.callSessionManager = callSessionManager
        
        var startCallImpl: ((UUID, String) -> Signal<Bool, NoError>)?
        var answerCallImpl: ((UUID) -> Void)?
        var endCallImpl: ((UUID) -> Signal<Bool, NoError>)?
        var audioSessionActivationChangedImpl: ((Bool) -> Void)?
        
        self.callKitIntegration = CallKitIntegration(startCall: { uuid, handle in
            if let startCallImpl = startCallImpl {
                return startCallImpl(uuid, handle)
            } else {
                return .single(false)
            }
        }, answerCall: { uuid in
            answerCallImpl?(uuid)
        }, endCall: { uuid in
            if let endCallImpl = endCallImpl {
                return endCallImpl(uuid)
            } else {
                return .single(false)
            }
        }, audioSessionActivationChanged: { value in
            audioSessionActivationChangedImpl?(value)
        })
        
        let enableCallKit = postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.voiceCallSettings])
        |> map { preferences -> Bool in
            let settings = preferences.values[ApplicationSpecificPreferencesKeys.voiceCallSettings] as? VoiceCallSettings ?? .defaultSettings
            return settings.enableSystemIntegration
        }
        |> distinctUntilChanged
        
        let enabledMicrophoneAccess = Signal<Bool, NoError> { subscriber in
            subscriber.putNext(DeviceAccess.isMicrophoneAccessAuthorized() == true)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        self.ringingStatesDisposable = (combineLatest(callSessionManager.ringingStates(), enableCallKit, enabledMicrophoneAccess)
        |> mapToSignal { ringingStates, enableCallKit, enabledMicrophoneAccess -> Signal<([(Peer, CallSessionRingingState, Bool)], Bool), NoError> in
            if ringingStates.isEmpty {
                return .single(([], enableCallKit && enabledMicrophoneAccess))
            } else {
                return postbox.transaction { transaction -> ([(Peer, CallSessionRingingState, Bool)], Bool) in
                    var result: [(Peer, CallSessionRingingState, Bool)] = []
                    for state in ringingStates {
                        if let peer = transaction.getPeer(state.peerId) {
                            result.append((peer, state, transaction.isPeerContact(peerId: state.peerId)))
                        }
                    }
                    return (result, enableCallKit && enabledMicrophoneAccess)
                }
            }
        }
        |> mapToSignal { states, enableCallKit -> Signal<([(Peer, CallSessionRingingState, Bool)], NetworkType, Bool), NoError> in
            return networkType
            |> take(1)
            |> map { currentNetworkType -> ([(Peer, CallSessionRingingState, Bool)], NetworkType, Bool) in
                return (states, currentNetworkType, enableCallKit)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] ringingStates, currentNetworkType, enableCallKit in
            self?.ringingStatesUpdated(ringingStates, currentNetworkType: currentNetworkType, enableCallKit: enableCallKit)
        })
        
        startCallImpl = { [weak self] uuid, handle in
            if let strongSelf = self, let userId = Int32(handle) {
                return strongSelf.startCall(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), internalId: uuid)
                |> take(1)
                |> map { result -> Bool in
                    return result
                }
            } else {
                return .single(false)
            }
        }
        
        answerCallImpl = { [weak self] uuid in
            if let strongSelf = self {
                strongSelf.currentCall?.answer()
            }
        }
        
        endCallImpl = { [weak self] uuid in
            if let strongSelf = self, let currentCall = strongSelf.currentCall {
                return currentCall.hangUp()
            } else {
                return .single(false)
            }
        }
        
        audioSessionActivationChangedImpl = { [weak self] value in
            if value {
                self?.audioSession.callKitActivatedAudioSession()
            } else {
                self?.audioSession.callKitDeactivatedAudioSession()
            }
        }
        
        self.proxyServerDisposable = (postbox.preferencesView(keys: [PreferencesKeys.proxySettings])
        |> deliverOnMainQueue).start(next: { [weak self] preferences in
            if let strongSelf = self, let settings = preferences.values[PreferencesKeys.proxySettings] as? ProxySettings {
                if settings.enabled && settings.useForCalls {
                    strongSelf.proxyServer = settings.activeServer
                } else {
                    strongSelf.proxyServer = nil
                }
            }
        })
        
        self.callSettingsDisposable = (postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.voiceCallSettings, PreferencesKeys.voipConfiguration])
        |> deliverOnMainQueue).start(next: { [weak self] preferences in
            let callSettings = preferences.values[ApplicationSpecificPreferencesKeys.voiceCallSettings] as? VoiceCallSettings ?? .defaultSettings
            let configuration = preferences.values[PreferencesKeys.voipConfiguration] as? VoipConfiguration ?? .defaultValue
            if let strongSelf = self {
                strongSelf.callSettings = (callSettings, configuration)
            }
        })
    }
    
    deinit {
        self.ringingStatesDisposable?.dispose()
        self.removeCurrentCallDisposable.dispose()
        self.startCallDisposable.dispose()
        self.proxyServerDisposable?.dispose()
        self.callSettingsDisposable?.dispose()
    }
    
    private func ringingStatesUpdated(_ ringingStates: [(Peer, CallSessionRingingState, Bool)], currentNetworkType: NetworkType, enableCallKit: Bool) {
        if let firstState = ringingStates.first {
            if self.currentCall == nil {
                let call = PresentationCall(audioSession: self.audioSession, callSessionManager: self.callSessionManager, callKitIntegration: enableCallKit ? self.callKitIntegration : nil, getDeviceAccessData: self.getDeviceAccessData, internalId: firstState.1.id, peerId: firstState.1.peerId, isOutgoing: false, peer: firstState.0, allowP2P: p2pAllowed(settings: self.callSettings, isContact: firstState.2), proxyServer: self.proxyServer, currentNetworkType: currentNetworkType, updatedNetworkType: self.networkType)
                self.currentCall = call
                self.currentCallPromise.set(.single(call))
                self.hasActiveCallsPromise.set(true)
                self.removeCurrentCallDisposable.set((call.canBeRemoved
                |> deliverOnMainQueue).start(next: { [weak self, weak call] value in
                    if value, let strongSelf = self, let call = call {
                        if strongSelf.currentCall === call {
                            strongSelf.currentCall = nil
                            strongSelf.currentCallPromise.set(.single(nil))
                            strongSelf.hasActiveCallsPromise.set(false)
                        }
                    }
                }))
            }
        }
    }
    
    public func requestCall(peerId: PeerId, endCurrentIfAny: Bool) -> RequestCallResult {
        if let call = self.currentCall, !endCurrentIfAny {
            return .alreadyInProgress(call.peerId)
        }
        if let _ = self.callKitIntegration {
            let (presentationData, present, openSettings) = self.getDeviceAccessData()
            
            let accessEnabledSignal: Signal<Bool, NoError> = Signal { subscriber in
                DeviceAccess.authorizeAccess(to: .microphone(.voiceCall), presentationData: presentationData, present: { c, a in
                    present(c, a)
                }, openSettings: {
                    openSettings()
                }, { value in
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                })
                return EmptyDisposable
            }
            |> runOn(Queue.mainQueue())
            let postbox = self.postbox
            self.startCallDisposable.set((accessEnabledSignal
            |> mapToSignal { accessEnabled -> Signal<Peer?, NoError> in
                if !accessEnabled {
                    return .single(nil)
                }
                return postbox.loadedPeerWithId(peerId)
                |> take(1)
                |> map(Optional.init)
            }
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let strongSelf = self, let peer = peer else {
                    return
                }
                strongSelf.callKitIntegration?.startCall(peerId: peerId, displayTitle: peer.displayTitle)
            }))
        } else {
            let _ = self.startCall(peerId: peerId).start()
        }
        return .requested
    }
    
    private func startCall(peerId: PeerId, internalId: CallSessionInternalId = CallSessionInternalId()) -> Signal<Bool, NoError> {
        let (presentationData, present, openSettings) = self.getDeviceAccessData()
        
        let accessEnabledSignal: Signal<Bool, NoError> = Signal { subscriber in
            DeviceAccess.authorizeAccess(to: .microphone(.voiceCall), presentationData: presentationData, present: { c, a in
                present(c, a)
            }, openSettings: {
                openSettings()
            }, { value in
                subscriber.putNext(value)
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        let postbox = self.postbox
        let callSessionManager = self.callSessionManager
        let networkType = self.networkType
        return accessEnabledSignal
        |> mapToSignal { [weak self] accessEnabled -> Signal<Bool, NoError> in
            if !accessEnabled {
                return .single(false)
            }
            return (combineLatest(callSessionManager.request(peerId: peerId, internalId: internalId), networkType |> take(1), postbox.peerView(id: peerId) |> take(1) |> map({ peerView -> Bool in
                return peerView.peerIsContact
            }) |> take(1))
            |> deliverOnMainQueue
            |> beforeNext { internalId, currentNetworkType, isContact in
                if let strongSelf = self, accessEnabled {
                    if let currentCall = strongSelf.currentCall {
                        currentCall.rejectBusy()
                    }
                 
                    let call = PresentationCall(audioSession: strongSelf.audioSession, callSessionManager: strongSelf.callSessionManager, callKitIntegration: callKitIntegrationIfEnabled(strongSelf.callKitIntegration, settings: strongSelf.callSettings?.0), getDeviceAccessData: strongSelf.getDeviceAccessData, internalId: internalId, peerId: peerId, isOutgoing: true, peer: nil, allowP2P: p2pAllowed(settings: strongSelf.callSettings, isContact: isContact), proxyServer: strongSelf.proxyServer, currentNetworkType: currentNetworkType, updatedNetworkType: strongSelf.networkType)
                    strongSelf.currentCall = call
                    strongSelf.currentCallPromise.set(.single(call))
                    strongSelf.hasActiveCallsPromise.set(true)
                    strongSelf.removeCurrentCallDisposable.set((call.canBeRemoved
                    |> deliverOnMainQueue).start(next: { [weak call] value in
                        if value, let strongSelf = self, let call = call {
                            if strongSelf.currentCall === call {
                                strongSelf.currentCall = nil
                                strongSelf.currentCallPromise.set(.single(nil))
                                strongSelf.hasActiveCallsPromise.set(false)
                            }
                        }
                    }))
                }
            })
            |> mapToSignal { value -> Signal<Bool, NoError> in
                return .single(true)
            }
        }
    }
}
