import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import DeviceAccess
import TelegramPresentationData
import TelegramAudio
import TelegramVoip
import TelegramUIPreferences
import AccountContext
import CallKit

private func callKitIntegrationIfEnabled(_ integration: CallKitIntegration?, settings: VoiceCallSettings?) -> CallKitIntegration?  {
    let enabled = settings?.enableSystemIntegration ?? true
    return enabled ? integration : nil
}

private func shouldEnableStunMarking(appConfiguration: AppConfiguration) -> Bool {
    guard let data = appConfiguration.data else {
        return true
    }
    guard let enableStunMarking = data["voip_enable_stun_marking"] as? Bool else {
        return true
    }
    return enableStunMarking
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

public final class PresentationCallManagerImpl: PresentationCallManager {
    private let getDeviceAccessData: () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void)
    private let isMediaPlaying: () -> Bool
    private let resumeMediaPlayback: () -> Void

    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let audioSession: ManagedAudioSession
    private let callKitIntegration: CallKitIntegration?
    
    private var currentCallValue: PresentationCallImpl?
    private var currentCall: PresentationCallImpl? {
        return self.currentCallValue
    }
    private var currentCallDisposable = MetaDisposable()
    private let removeCurrentCallDisposable = MetaDisposable()
    private let removeCurrentGroupCallDisposable = MetaDisposable()
    
    private var currentGroupCallValue: PresentationGroupCallImpl?
    private var currentGroupCall: PresentationGroupCallImpl? {
        return self.currentGroupCallValue
    }
    
    private var ringingStatesDisposable: Disposable?
    
    private let hasActivePersonalCallsPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let hasActiveGroupCallsPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var hasActiveCalls: Signal<Bool, NoError> {
        return combineLatest(queue: .mainQueue(),
            self.hasActivePersonalCallsPromise.get(),
            self.hasActiveGroupCallsPromise.get()
        )
        |> map { value1, value2 -> Bool in
            return value1 || value2
        }
        |> distinctUntilChanged
    }
    
    public var hasActiveCall: Bool {
        return self.currentCall != nil || self.currentGroupCall != nil
    }
    
    private let currentCallPromise = Promise<PresentationCall?>(nil)
    public var currentCallSignal: Signal<PresentationCall?, NoError> {
        return self.currentCallPromise.get()
    }
    
    private let currentGroupCallPromise = Promise<PresentationGroupCall?>(nil)
    public var currentGroupCallSignal: Signal<PresentationGroupCall?, NoError> {
        return self.currentGroupCallPromise.get()
    }
    
    private let startCallDisposable = MetaDisposable()
    
    private var proxyServer: ProxyServerSettings?
    private var proxyServerDisposable: Disposable?
    
    private var callSettings: VoiceCallSettings?
    private var callSettingsDisposable: Disposable?
    
    private var resumeMedia: Bool = false
    
    public static var voipMaxLayer: Int32 {
        return OngoingCallContext.maxLayer
    }
    
    public static func voipVersions(includeExperimental: Bool, includeReference: Bool) -> [(version: String, supportsVideo: Bool)] {
        return OngoingCallContext.versions(includeExperimental: includeExperimental, includeReference: includeReference)
    }
    
    public init(
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void),
        isMediaPlaying: @escaping () -> Bool,
        resumeMediaPlayback: @escaping () -> Void,
        audioSession: ManagedAudioSession,
        activeAccounts: Signal<[AccountContext], NoError>
    ) {
        self.getDeviceAccessData = getDeviceAccessData
        self.accountManager = accountManager
        self.audioSession = audioSession
        
        self.isMediaPlaying = isMediaPlaying
        self.resumeMediaPlayback = resumeMediaPlayback
        
        var startCallImpl: ((AccountContext, UUID, String, Bool) -> Signal<Bool, NoError>)?
        var answerCallImpl: ((UUID) -> Void)?
        var endCallImpl: ((UUID) -> Signal<Bool, NoError>)?
        var setCallMutedImpl: ((UUID, Bool) -> Void)?
        var audioSessionActivationChangedImpl: ((Bool) -> Void)?
        
        self.callKitIntegration = CallKitIntegration.shared
        self.callKitIntegration?.setup(startCall: { context, uuid, handle, isVideo in
            if let startCallImpl = startCallImpl {
                return startCallImpl(context, uuid, handle, isVideo)
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
        
        let enableCallKit = accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings])
        |> map { sharedData -> Bool in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
            return settings.enableSystemIntegration
        }
        |> distinctUntilChanged
        
        let enabledMicrophoneAccess = Signal<Bool, NoError> { subscriber in
            subscriber.putNext(DeviceAccess.isMicrophoneAccessAuthorized() == true)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        let ringingStatesByAccount: Signal<[(AccountContext, CallSessionRingingState, NetworkType)], NoError> = activeAccounts
        |> mapToSignal { accounts -> Signal<[(AccountContext, CallSessionRingingState, NetworkType)], NoError> in
            return combineLatest(accounts.map { context -> Signal<(AccountContext, [CallSessionRingingState], NetworkType), NoError> in
                return combineLatest(context.account.callSessionManager.ringingStates(), context.account.networkType)
                |> map { ringingStates, networkType -> (AccountContext, [CallSessionRingingState], NetworkType) in
                    return (context, ringingStates, networkType)
                }
            })
            |> map { ringingStatesByAccount -> [(AccountContext, CallSessionRingingState, NetworkType)] in
                var result: [(AccountContext, CallSessionRingingState, NetworkType)] = []
                for (context, states, networkType) in ringingStatesByAccount {
                    for state in states {
                        result.append((context, state, networkType))
                    }
                }
                return result
            }
        }
        
        self.ringingStatesDisposable = (combineLatest(ringingStatesByAccount, enableCallKit, enabledMicrophoneAccess)
        |> mapToSignal { ringingStatesByAccount, enableCallKit, enabledMicrophoneAccess -> Signal<([(AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)], Bool), NoError> in
            if ringingStatesByAccount.isEmpty {
                return .single(([], enableCallKit && enabledMicrophoneAccess))
            } else {
                return combineLatest(ringingStatesByAccount.map { context, state, networkType -> Signal<(AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)?, NoError> in
                    return context.account.postbox.transaction { transaction -> (AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)? in
                        if let peer = transaction.getPeer(state.peerId) {
                            return (context, peer, state, transaction.isPeerContact(peerId: state.peerId), networkType)
                        } else {
                            return nil
                        }
                    }
                })
                |> map { ringingStatesByAccount -> ([(AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)], Bool) in
                    return (ringingStatesByAccount.compactMap({ $0 }), enableCallKit && enabledMicrophoneAccess)
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] ringingStates, enableCallKit in
            self?.ringingStatesUpdated(ringingStates, enableCallKit: enableCallKit)
        })
        
        startCallImpl = { [weak self] context, uuid, handle, isVideo in
            if let strongSelf = self, let userId = Int64(handle) {
                return strongSelf.startCall(context: context, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), isVideo: isVideo, internalId: uuid)
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
            if let strongSelf = self, let settings = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                if settings.enabled && settings.useForCalls {
                    strongSelf.proxyServer = settings.activeServer
                } else {
                    strongSelf.proxyServer = nil
                }
            }
        })
        
        self.callSettingsDisposable = (accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                strongSelf.callSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
            }
        })
    }
    
    deinit {
        self.currentCallDisposable.dispose()
        self.ringingStatesDisposable?.dispose()
        self.removeCurrentCallDisposable.dispose()
        self.removeCurrentGroupCallDisposable.dispose()
        self.startCallDisposable.dispose()
        self.proxyServerDisposable?.dispose()
        self.callSettingsDisposable?.dispose()
    }
    
    private func ringingStatesUpdated(_ ringingStates: [(AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)], enableCallKit: Bool) {
        if let firstState = ringingStates.first {
            if self.currentCall == nil && self.currentGroupCall == nil {
                self.currentCallDisposable.set((combineLatest(firstState.0.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, ApplicationSpecificPreferencesKeys.voipDerivedState, PreferencesKeys.appConfiguration]) |> take(1), accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings]) |> take(1))
                |> deliverOnMainQueue).start(next: { [weak self] preferences, sharedData in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let configuration = preferences.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
                    let derivedState = preferences.values[ApplicationSpecificPreferencesKeys.voipDerivedState]?.get(VoipDerivedState.self) ?? .default
                    let autodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) ?? .defaultSettings
                    let experimentalSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? .defaultSettings
                    let appConfiguration = preferences.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                    
                    let call = PresentationCallImpl(
                        context: firstState.0,
                        audioSession: strongSelf.audioSession,
                        callSessionManager: firstState.0.account.callSessionManager,
                        callKitIntegration: enableCallKit ? callKitIntegrationIfEnabled(strongSelf.callKitIntegration, settings: strongSelf.callSettings) : nil,
                        serializedData: configuration.serializedData,
                        dataSaving: effectiveDataSaving(for: strongSelf.callSettings, autodownloadSettings: autodownloadSettings),
                        derivedState: derivedState,
                        getDeviceAccessData: strongSelf.getDeviceAccessData,
                        initialState: nil,
                        internalId: firstState.2.id,
                        peerId: firstState.2.peerId,
                        isOutgoing: false,
                        peer: firstState.1,
                        proxyServer: strongSelf.proxyServer,
                        auxiliaryServers: [],
                        currentNetworkType: firstState.4,
                        updatedNetworkType: firstState.0.account.networkType,
                        startWithVideo: firstState.2.isVideo,
                        isVideoPossible: firstState.2.isVideoPossible,
                        enableStunMarking: shouldEnableStunMarking(appConfiguration: appConfiguration),
                        enableTCP: experimentalSettings.enableVoipTcp,
                        preferredVideoCodec: experimentalSettings.preferredVideoCodec
                    )
                    strongSelf.updateCurrentCall(call)
                    strongSelf.currentCallPromise.set(.single(call))
                    strongSelf.hasActivePersonalCallsPromise.set(true)
                    strongSelf.removeCurrentCallDisposable.set((call.canBeRemoved
                    |> deliverOnMainQueue).start(next: { [weak self, weak call] value in
                        if value, let strongSelf = self, let call = call {
                            if strongSelf.currentCall === call {
                                strongSelf.updateCurrentCall(nil)
                                strongSelf.currentCallPromise.set(.single(nil))
                                strongSelf.hasActivePersonalCallsPromise.set(false)
                            }
                        }
                    }))
                }))
            } else {
                for (context, _, state, _, _) in ringingStates {
                    if state.id != self.currentCall?.internalId {
                        context.account.callSessionManager.drop(internalId: state.id, reason: .busy, debugLog: .single(nil))
                    }
                }
            }
        }
    }
    
    public func requestCall(context: AccountContext, peerId: PeerId, isVideo: Bool, endCurrentIfAny: Bool) -> RequestCallResult {
        var alreadyInCall: Bool = false
        var alreadyInCallWithPeerId: PeerId?
        
        if let call = self.currentCall {
            alreadyInCall = true
            alreadyInCallWithPeerId = call.peerId
        } else if let currentGroupCall = self.currentGroupCallValue {
            alreadyInCall = true
            alreadyInCallWithPeerId = currentGroupCall.peerId
        } else {
            if #available(iOS 10.0, *) {
                if CXCallObserver().calls.contains(where: { $0.hasEnded == false }) {
                    alreadyInCall = true
                }
            }
        }
        
        if alreadyInCall, !endCurrentIfAny {
            return .alreadyInProgress(alreadyInCallWithPeerId)
        }
        if let _ = callKitIntegrationIfEnabled(self.callKitIntegration, settings: self.callSettings) {
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
                        if isVideo && value {
                            DeviceAccess.authorizeAccess(to: .camera(.videoCall), presentationData: presentationData, present: { c, a in
                                present(c, a)
                            }, openSettings: {
                                openSettings()
                            }, { value in
                                subscriber.putNext(value)
                                subscriber.putCompletion()
                            })
                        } else {
                            subscriber.putNext(value)
                            subscriber.putCompletion()
                        }
                    })
                    return EmptyDisposable
                }
                |> runOn(Queue.mainQueue())
                let postbox = context.account.postbox
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
                    strongSelf.callKitIntegration?.startCall(context: context, peerId: peerId, isVideo: isVideo, displayTitle: peer.debugDisplayTitle)
                }))
            }
            if let currentCall = self.currentCall {
                self.callKitIntegration?.dropCall(uuid: currentCall.internalId)
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else if let currentGroupCall = self.currentGroupCallValue {
                self.startCallDisposable.set((currentGroupCall.leave(terminateIfPossible: false)
                |> filter { $0 }
                |> take(1)
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
                let _ = strongSelf.startCall(context: context, peerId: peerId, isVideo: isVideo).start()
            }
            if let currentCall = self.currentCall {
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else if let currentGroupCall = self.currentGroupCallValue {
                self.startCallDisposable.set((currentGroupCall.leave(terminateIfPossible: false)
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else {
                begin()
            }
        }
        return .requested
    }
    
    private func startCall(
        context: AccountContext,
        peerId: PeerId,
        isVideo: Bool,
        internalId: CallSessionInternalId = CallSessionInternalId()
    ) -> Signal<Bool, NoError> {
        let (presentationData, present, openSettings) = self.getDeviceAccessData()
        
        let accessEnabledSignal: Signal<Bool, NoError> = Signal { subscriber in
            DeviceAccess.authorizeAccess(to: .microphone(.voiceCall), presentationData: presentationData, present: { c, a in
                present(c, a)
            }, openSettings: {
                openSettings()
            }, { value in
                if isVideo && value {
                    DeviceAccess.authorizeAccess(to: .camera(.videoCall), presentationData: presentationData, present: { c, a in
                        present(c, a)
                    }, openSettings: {
                        openSettings()
                    }, { value in
                        subscriber.putNext(value)
                        subscriber.putCompletion()
                    })
                } else {
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                }
            })
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        let networkType = context.account.networkType
        let accountManager = self.accountManager
        return accessEnabledSignal
        |> mapToSignal { [weak self] accessEnabled -> Signal<Bool, NoError> in
            if !accessEnabled {
                return .single(false)
            }
            
            let request = context.account.postbox.transaction { transaction -> (VideoCallsConfiguration, CachedUserData?) in
                let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                return (VideoCallsConfiguration(appConfiguration: appConfiguration), transaction.getPeerCachedData(peerId: peerId) as? CachedUserData)
            }
            |> mapToSignal { callsConfiguration, cachedUserData -> Signal<CallSessionInternalId, NoError> in
                var isVideoPossible: Bool
                switch callsConfiguration.videoCallsSupport {
                case .disabled:
                    isVideoPossible = isVideo
                case .full:
                    isVideoPossible = true
                case .onlyVideo:
                    isVideoPossible = isVideo
                }
                if let cachedUserData = cachedUserData, cachedUserData.videoCallsAvailable {
                } else {
                    isVideoPossible = false
                }
                
                return context.account.callSessionManager.request(peerId: peerId, isVideo: isVideo, enableVideo: isVideoPossible, internalId: internalId)
            }
            
            let cachedUserData = context.account.postbox.transaction { transaction -> CachedUserData? in
                return transaction.getPeerCachedData(peerId: peerId) as? CachedUserData
            }
            
            return (combineLatest(queue: .mainQueue(), request, networkType |> take(1), context.account.postbox.peerView(id: peerId) |> map { peerView -> Bool in
                return peerView.peerIsContact
            } |> take(1), context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, ApplicationSpecificPreferencesKeys.voipDerivedState, PreferencesKeys.appConfiguration]) |> take(1), accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings]) |> take(1), cachedUserData)
            |> deliverOnMainQueue
            |> beforeNext { internalId, currentNetworkType, isContact, preferences, sharedData, cachedUserData in
                if let strongSelf = self, accessEnabled {
                    if let currentCall = strongSelf.currentCall {
                        currentCall.rejectBusy()
                    }
                    
                    let configuration = preferences.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
                    let derivedState = preferences.values[ApplicationSpecificPreferencesKeys.voipDerivedState]?.get(VoipDerivedState.self) ?? .default
                    let autodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) ?? .defaultSettings
                    let appConfiguration = preferences.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                    
                    let callsConfiguration = VideoCallsConfiguration(appConfiguration: appConfiguration)
                    var isVideoPossible: Bool
                    switch callsConfiguration.videoCallsSupport {
                    case .disabled:
                        isVideoPossible = isVideo
                    case .full:
                        isVideoPossible = true
                    case .onlyVideo:
                        isVideoPossible = isVideo
                    }
                    if let cachedUserData = cachedUserData, cachedUserData.videoCallsAvailable {
                    } else {
                        isVideoPossible = false
                    }
                    
                    let experimentalSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? .defaultSettings
                    
                    let call = PresentationCallImpl(
                        context: context,
                        audioSession: strongSelf.audioSession,
                        callSessionManager: context.account.callSessionManager,
                        callKitIntegration: callKitIntegrationIfEnabled(
                            strongSelf.callKitIntegration,
                            settings: strongSelf.callSettings
                        ),
                        serializedData: configuration.serializedData,
                        dataSaving: effectiveDataSaving(for: strongSelf.callSettings, autodownloadSettings: autodownloadSettings),
                        derivedState: derivedState,
                        getDeviceAccessData: strongSelf.getDeviceAccessData,
                        initialState: nil,
                        internalId: internalId,
                        peerId: peerId,
                        isOutgoing: true,
                        peer: nil,
                        proxyServer: strongSelf.proxyServer,
                        auxiliaryServers: [],
                        currentNetworkType: currentNetworkType,
                        updatedNetworkType: context.account.networkType,
                        startWithVideo: isVideo,
                        isVideoPossible: isVideoPossible,
                        enableStunMarking: shouldEnableStunMarking(appConfiguration: appConfiguration),
                        enableTCP: experimentalSettings.enableVoipTcp,
                        preferredVideoCodec: experimentalSettings.preferredVideoCodec
                    )
                    strongSelf.updateCurrentCall(call)
                    strongSelf.currentCallPromise.set(.single(call))
                    strongSelf.hasActivePersonalCallsPromise.set(true)
                    strongSelf.removeCurrentCallDisposable.set((call.canBeRemoved
                    |> deliverOnMainQueue).start(next: { [weak call] value in
                        if value, let strongSelf = self, let call = call {
                            if strongSelf.currentCall === call {
                                strongSelf.updateCurrentCall(nil)
                                strongSelf.currentCallPromise.set(.single(nil))
                                strongSelf.hasActivePersonalCallsPromise.set(false)
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
    
    private func updateCurrentCall(_ value: PresentationCallImpl?) {
        let wasEmpty = self.currentCallValue == nil
        let isEmpty = value == nil
        if wasEmpty && !isEmpty {
            self.resumeMedia = self.isMediaPlaying()
        }
        
        self.currentCallValue = value
        
        if !wasEmpty && isEmpty && self.resumeMedia {
            self.resumeMedia = false
            self.resumeMediaPlayback()
        }
    }
    
    private func updateCurrentGroupCall(_ value: PresentationGroupCallImpl?) {
        let wasEmpty = self.currentGroupCallValue == nil
        let isEmpty = value == nil
        if wasEmpty && !isEmpty {
            self.resumeMedia = self.isMediaPlaying()
        }
        
        self.currentGroupCallValue = value
        
        if !wasEmpty && isEmpty && self.resumeMedia {
            self.resumeMedia = false
            self.resumeMediaPlayback()
        }
    }
    
    private func requestScheduleGroupCall(accountContext: AccountContext, peerId: PeerId, internalId: CallSessionInternalId = CallSessionInternalId()) -> Signal<Bool, NoError> {
        let (presentationData, present, openSettings) = self.getDeviceAccessData()
        
        let isVideo = false
        
        let accessEnabledSignal: Signal<Bool, NoError> = Signal { subscriber in
            DeviceAccess.authorizeAccess(to: .microphone(.voiceCall), presentationData: presentationData, present: { c, a in
                present(c, a)
            }, openSettings: {
                openSettings()
            }, { value in
                if isVideo && value {
                    DeviceAccess.authorizeAccess(to: .camera(.videoCall), presentationData: presentationData, present: { c, a in
                        present(c, a)
                    }, openSettings: {
                        openSettings()
                    }, { value in
                        subscriber.putNext(value)
                        subscriber.putCompletion()
                    })
                } else {
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                }
            })
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        return combineLatest(queue: .mainQueue(),
            accessEnabledSignal,
            accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        )
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] accessEnabled, peer -> Signal<Bool, NoError> in
            guard let strongSelf = self else {
                return .single(false)
            }
            
            if !accessEnabled {
                return .single(false)
            }

            var isChannel = false
            if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                isChannel = true
            }
                    
            let call = PresentationGroupCallImpl(
                accountContext: accountContext,
                audioSession: strongSelf.audioSession,
                callKitIntegration: nil,
                getDeviceAccessData: strongSelf.getDeviceAccessData,
                initialCall: nil,
                internalId: internalId,
                peerId: peerId,
                isChannel: isChannel,
                invite: nil,
                joinAsPeerId: nil,
                isStream: false
            )
            strongSelf.updateCurrentGroupCall(call)
            strongSelf.currentGroupCallPromise.set(.single(call))
            strongSelf.hasActiveGroupCallsPromise.set(true)
            strongSelf.removeCurrentGroupCallDisposable.set((call.canBeRemoved
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak call] value in
                guard let strongSelf = self, let call = call else {
                    return
                }
                if value {
                    if strongSelf.currentGroupCall === call {
                        strongSelf.updateCurrentGroupCall(nil)
                        strongSelf.currentGroupCallPromise.set(.single(nil))
                        strongSelf.hasActiveGroupCallsPromise.set(false)
                    }
                }
            }))
        
            return .single(true)
        }
    }
    
    public func scheduleGroupCall(context: AccountContext, peerId: PeerId, endCurrentIfAny: Bool) -> RequestScheduleGroupCallResult {
        let begin: () -> Void = { [weak self] in
            let _ = self?.requestScheduleGroupCall(accountContext: context, peerId: peerId).start()
        }
        
        if let currentGroupCall = self.currentGroupCallValue {
            if endCurrentIfAny {
                let endSignal = currentGroupCall.leave(terminateIfPossible: false)
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue
                self.startCallDisposable.set(endSignal.start(next: { _ in
                    begin()
                }))
            } else {
                return .alreadyInProgress(currentGroupCall.peerId)
            }
        } else if let currentCall = self.currentCall {
            if endCurrentIfAny {
                self.callKitIntegration?.dropCall(uuid: currentCall.internalId)
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else {
                return .alreadyInProgress(currentCall.peerId)
            }
        } else {
            begin()
        }
        return .success
    }
    
    public func joinGroupCall(context: AccountContext, peerId: PeerId, invite: String?, requestJoinAsPeerId: ((@escaping (PeerId?) -> Void) -> Void)?, initialCall: EngineGroupCallDescription, endCurrentIfAny: Bool) -> JoinGroupCallManagerResult {
        let begin: () -> Void = { [weak self] in
            if let requestJoinAsPeerId = requestJoinAsPeerId {
                requestJoinAsPeerId({ joinAsPeerId in
                    let _ = self?.startGroupCall(accountContext: context, peerId: peerId, invite: invite, joinAsPeerId: joinAsPeerId, initialCall: initialCall).start()
                })
            } else {
                let _ = self?.startGroupCall(accountContext: context, peerId: peerId, invite: invite, joinAsPeerId: nil, initialCall: initialCall).start()
            }
        }
        
        if let currentGroupCall = self.currentGroupCallValue {
            if endCurrentIfAny {
                let endSignal = currentGroupCall.leave(terminateIfPossible: false)
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue
                self.startCallDisposable.set(endSignal.start(next: { _ in
                    begin()
                }))
            } else {
                return .alreadyInProgress(currentGroupCall.peerId)
            }
        } else if let currentCall = self.currentCall {
            if endCurrentIfAny {
                self.callKitIntegration?.dropCall(uuid: currentCall.internalId)
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else {
                return .alreadyInProgress(currentCall.peerId)
            }
        } else {
            begin()
        }
        return .joined
    }
    
    private func startGroupCall(
        accountContext: AccountContext,
        peerId: PeerId,
        invite: String?,
        joinAsPeerId: PeerId?,
        initialCall: EngineGroupCallDescription,
        internalId: CallSessionInternalId = CallSessionInternalId()
    ) -> Signal<Bool, NoError> {
        let (presentationData, present, openSettings) = self.getDeviceAccessData()
        
        let isVideo = false
        
        let accessEnabledSignal: Signal<Bool, NoError> = Signal { subscriber in
            if let isStream = initialCall.isStream, isStream {
                subscriber.putNext(true)
                return EmptyDisposable
            }
            
            DeviceAccess.authorizeAccess(to: .microphone(.voiceCall), presentationData: presentationData, present: { c, a in
                present(c, a)
            }, openSettings: {
                openSettings()
            }, { value in
                if isVideo && value {
                    DeviceAccess.authorizeAccess(to: .camera(.videoCall), presentationData: presentationData, present: { c, a in
                        present(c, a)
                    }, openSettings: {
                        openSettings()
                    }, { value in
                        subscriber.putNext(value)
                        subscriber.putCompletion()
                    })
                } else {
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                }
            })
            return EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
        
        return combineLatest(queue: .mainQueue(),
            accessEnabledSignal,
            accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        )
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] accessEnabled, peer -> Signal<Bool, NoError> in
            guard let strongSelf = self else {
                return .single(false)
            }
            
            if !accessEnabled {
                return .single(false)
            }

            var isChannel = false
            if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                isChannel = true
            }
                    
            let call = PresentationGroupCallImpl(
                accountContext: accountContext,
                audioSession: strongSelf.audioSession,
                callKitIntegration: nil,
                getDeviceAccessData: strongSelf.getDeviceAccessData,
                initialCall: initialCall,
                internalId: internalId,
                peerId: peerId,
                isChannel: isChannel,
                invite: invite,
                joinAsPeerId: joinAsPeerId,
                isStream: initialCall.isStream ?? false
            )
            strongSelf.updateCurrentGroupCall(call)
            strongSelf.currentGroupCallPromise.set(.single(call))
            strongSelf.hasActiveGroupCallsPromise.set(true)
            strongSelf.removeCurrentGroupCallDisposable.set((call.canBeRemoved
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak call] value in
                guard let strongSelf = self, let call = call else {
                    return
                }
                if value {
                    if strongSelf.currentGroupCall === call {
                        strongSelf.updateCurrentGroupCall(nil)
                        strongSelf.currentGroupCallPromise.set(.single(nil))
                        strongSelf.hasActiveGroupCallsPromise.set(false)
                    }
                }
            }))
        
            return .single(true)
        }
    }
}
