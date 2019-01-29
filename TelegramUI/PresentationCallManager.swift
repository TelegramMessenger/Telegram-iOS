import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

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
    private let tempAccount: Account
    private let getDeviceAccessData: () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void)
    private let networkType: Signal<NetworkType, NoError>
    private let audioSession: ManagedAudioSession
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
    
    private var callSettings: (VoiceCallSettings, VoipConfiguration, VoipDerivedState)?
    private var callSettingsDisposable: Disposable?
    
    public static var voipMaxLayer: Int32 {
        return OngoingCallContext.maxLayer
    }
    
    public init(accountManager: AccountManager, account: Account, getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void), networkType: Signal<NetworkType, NoError>, audioSession: ManagedAudioSession, activeAccounts: Signal<[Account], NoError>) {
        self.tempAccount = account
        self.getDeviceAccessData = getDeviceAccessData
        self.networkType = networkType
        self.audioSession = audioSession
        
        var startCallImpl: ((Account, UUID, String) -> Signal<Bool, NoError>)?
        var answerCallImpl: ((UUID) -> Void)?
        var endCallImpl: ((UUID) -> Signal<Bool, NoError>)?
        var setCallMutedImpl: ((UUID, Bool) -> Void)?
        var audioSessionActivationChangedImpl: ((Bool) -> Void)?
        
        self.callKitIntegration = CallKitIntegration(startCall: { account, uuid, handle in
            if let startCallImpl = startCallImpl {
                return startCallImpl(account, uuid, handle)
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
        }, setCallMuted: { uuid, isMuted in
            setCallMutedImpl?(uuid, isMuted)
        }, audioSessionActivationChanged: { value in
            audioSessionActivationChangedImpl?(value)
        })
        
        let postbox = self.tempAccount.postbox
        let enableCallKit = accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings])
        |> map { sharedData -> Bool in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings] as? VoiceCallSettings ?? .defaultSettings
            return settings.enableSystemIntegration
        }
        |> distinctUntilChanged
        
        let enabledMicrophoneAccess = Signal<Bool, NoError> { subscriber in
            subscriber.putNext(DeviceAccess.isMicrophoneAccessAuthorized() == true)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        let queue = Queue()
        let ringingStatesByAccount: Signal<[(Account, CallSessionRingingState)], NoError> = Signal { subscriber in
            let disposable = MetaDisposable()
            queue.async {
                var currentAccounts: [(Account, [CallSessionRingingState])] = []
                disposable.set((activeAccounts
                |> deliverOn(queue)).start(next: { accounts in
                    
                }))
            }
            return disposable
        }
        
        self.ringingStatesDisposable = (combineLatest(ringingStatesByAccount, enableCallKit, enabledMicrophoneAccess)
        |> mapToSignal { ringingStatesByAccount, enableCallKit, enabledMicrophoneAccess -> Signal<([(Account, Peer, CallSessionRingingState, Bool)], Bool), NoError> in
            if ringingStatesByAccount.isEmpty {
                return .single(([], enableCallKit && enabledMicrophoneAccess))
            } else {
                return postbox.transaction { transaction -> ([(Account, Peer, CallSessionRingingState, Bool)], Bool) in
                    var result: [(Account, Peer, CallSessionRingingState, Bool)] = []
                    for (account, state) in ringingStatesByAccount {
                        if let peer = transaction.getPeer(state.peerId) {
                            result.append((account, peer, state, transaction.isPeerContact(peerId: state.peerId)))
                        }
                    }
                    return (result, enableCallKit && enabledMicrophoneAccess)
                }
            }
        }
        |> mapToSignal { states, enableCallKit -> Signal<([(Account, Peer, CallSessionRingingState, Bool)], NetworkType, Bool), NoError> in
            return networkType
            |> take(1)
            |> map { currentNetworkType -> ([(Account, Peer, CallSessionRingingState, Bool)], NetworkType, Bool) in
                return (states, currentNetworkType, enableCallKit)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] ringingStates, currentNetworkType, enableCallKit in
            self?.ringingStatesUpdated(ringingStates, currentNetworkType: currentNetworkType, enableCallKit: enableCallKit)
        })
        
        startCallImpl = { [weak self] account, uuid, handle in
            if let strongSelf = self, let userId = Int32(handle) {
                return strongSelf.startCall(account: account, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), internalId: uuid)
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
        
        setCallMutedImpl = { [weak self] uuid, isMuted in
            if let strongSelf = self, let currentCall = strongSelf.currentCall {
                currentCall.setIsMuted(isMuted)
            }
        }
        
        audioSessionActivationChangedImpl = { [weak self] value in
            if value {
                self?.audioSession.callKitActivatedAudioSession()
            } else {
                self?.audioSession.callKitDeactivatedAudioSession()
            }
        }
        
        self.proxyServerDisposable = (accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self, let settings = sharedData.entries[SharedDataKeys.proxySettings] as? ProxySettings {
                if settings.enabled && settings.useForCalls {
                    strongSelf.proxyServer = settings.activeServer
                } else {
                    strongSelf.proxyServer = nil
                }
            }
        })
        
        self.callSettingsDisposable = (combineLatest(queue: .mainQueue(), accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings]), postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, ApplicationSpecificPreferencesKeys.voipDerivedState]))
        |> deliverOnMainQueue).start(next: { [weak self] sharedData, preferences in
            let callSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings] as? VoiceCallSettings ?? .defaultSettings
            let configuration = preferences.values[PreferencesKeys.voipConfiguration] as? VoipConfiguration ?? .defaultValue
            let derivedState = preferences.values[ApplicationSpecificPreferencesKeys.voipDerivedState] as? VoipDerivedState ?? .default
            if let strongSelf = self {
                strongSelf.callSettings = (callSettings, configuration, derivedState)
                
                if let legacyP2PMode = callSettings.legacyP2PMode {
                    _ = updateVoiceCallSettingsSettingsInteractively(accountManager: accountManager, { settings -> VoiceCallSettings in
                        var settings = settings
                        settings.legacyP2PMode = nil
                        return settings
                    }).start()
                    
                    let settings: SelectivePrivacySettings
                    switch legacyP2PMode {
                        case .always:
                            settings = .enableEveryone(disableFor: Set<PeerId>())
                        case .contacts:
                            settings = .enableContacts(enableFor: Set<PeerId>(), disableFor: Set<PeerId>())
                        case .never:
                            settings = .disableEveryone(enableFor: Set<PeerId>())
                    }
                    _ = updateSelectiveAccountPrivacySettings(account: strongSelf.tempAccount, type: .voiceCallsP2P, settings: settings).start()
                }
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
    
    private func ringingStatesUpdated(_ ringingStates: [(Account, Peer, CallSessionRingingState, Bool)], currentNetworkType: NetworkType, enableCallKit: Bool) {
        if let firstState = ringingStates.first {
            if self.currentCall == nil {
                let call = PresentationCall(account: firstState.0, audioSession: self.audioSession, callSessionManager: firstState.0.callSessionManager, callKitIntegration: enableCallKit ? callKitIntegrationIfEnabled(self.callKitIntegration, settings: self.callSettings?.0) : nil, serializedData: self.callSettings?.1.serializedData, dataSaving: self.callSettings?.0.dataSaving ?? .never, derivedState: self.callSettings?.2 ?? VoipDerivedState.default, getDeviceAccessData: self.getDeviceAccessData, internalId: firstState.2.id, peerId: firstState.2.peerId, isOutgoing: false, peer: firstState.1, proxyServer: self.proxyServer, currentNetworkType: currentNetworkType, updatedNetworkType: self.networkType)
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
            } else {
                for (account, _, state, _) in ringingStates {
                    if state.id != self.currentCall?.internalId {
                        account.callSessionManager.drop(internalId: state.id, reason: .missed)
                    }
                }
            }
        }
    }
    
    public func requestCall(account: Account, peerId: PeerId, endCurrentIfAny: Bool) -> RequestCallResult {
        if let call = self.currentCall, !endCurrentIfAny {
            return .alreadyInProgress(call.peerId)
        }
        if let _ = callKitIntegrationIfEnabled(self.callKitIntegration, settings: self.callSettings?.0) {
            let begin: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let (presentationData, present, openSettings) = strongSelf.getDeviceAccessData()
                
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
                let postbox = account.postbox
                strongSelf.startCallDisposable.set((accessEnabledSignal
                |> mapToSignal { accessEnabled -> Signal<Peer?, NoError> in
                    if !accessEnabled {
                        return .single(nil)
                    }
                    return postbox.loadedPeerWithId(peerId)
                    |> take(1)
                    |> map(Optional.init)
                }
                |> deliverOnMainQueue).start(next: { peer in
                    guard let strongSelf = self, let peer = peer else {
                        return
                    }
                    strongSelf.callKitIntegration?.startCall(account: account, peerId: peerId, displayTitle: peer.displayTitle)
                }))
            }
            if let currentCall = self.currentCall {
                self.callKitIntegration?.dropCall(uuid: currentCall.internalId)
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else {
                begin()
            }
        } else {
            let begin: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.startCall(account: account, peerId: peerId).start()
            }
            if let currentCall = self.currentCall {
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else {
                begin()
            }
        }
        return .requested
    }
    
    private func startCall(account: Account, peerId: PeerId, internalId: CallSessionInternalId = CallSessionInternalId()) -> Signal<Bool, NoError> {
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
        
        let networkType = self.networkType
        return accessEnabledSignal
        |> mapToSignal { [weak self] accessEnabled -> Signal<Bool, NoError> in
            if !accessEnabled {
                return .single(false)
            }
            return (combineLatest(queue: .mainQueue(), account.callSessionManager.request(peerId: peerId, internalId: internalId), networkType |> take(1), account.postbox.peerView(id: peerId) |> take(1) |> map({ peerView -> Bool in
                return peerView.peerIsContact
            }) |> take(1))
            |> deliverOnMainQueue
            |> beforeNext { internalId, currentNetworkType, isContact in
                if let strongSelf = self, accessEnabled {
                    if let currentCall = strongSelf.currentCall {
                        currentCall.rejectBusy()
                    }
                    
                    let call = PresentationCall(account: account, audioSession: strongSelf.audioSession, callSessionManager: account.callSessionManager, callKitIntegration: callKitIntegrationIfEnabled(strongSelf.callKitIntegration, settings: strongSelf.callSettings?.0), serializedData: strongSelf.callSettings?.1.serializedData, dataSaving: strongSelf.callSettings?.0.dataSaving ?? .never, derivedState: strongSelf.callSettings?.2 ?? VoipDerivedState.default, getDeviceAccessData: strongSelf.getDeviceAccessData, internalId: internalId, peerId: peerId, isOutgoing: true, peer: nil, proxyServer: strongSelf.proxyServer, currentNetworkType: currentNetworkType, updatedNetworkType: strongSelf.networkType)
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
