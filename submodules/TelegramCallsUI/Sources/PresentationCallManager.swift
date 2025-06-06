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
import PhoneNumberFormat

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
    private var callToConferenceDisposable: Disposable?
    private var isConferenceReadyDisposable: Disposable?
    private var currentUpgradedToConferenceCallId: CallSessionInternalId?
    
    private var currentGroupCallValue: VideoChatCall?
    private var currentGroupCall: VideoChatCall? {
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
    
    public var hasActiveGroupCall: Bool {
        return self.currentGroupCall != nil
    }
    
    private let currentCallPromise = Promise<PresentationCall?>(nil)
    public var currentCallSignal: Signal<PresentationCall?, NoError> {
        return self.currentCallPromise.get()
    }
    
    private let currentGroupCallPromise = Promise<VideoChatCall?>(nil)
    public var currentGroupCallSignal: Signal<VideoChatCall?, NoError> {
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
        
        var startCallImpl: ((AccountContext, UUID, EnginePeer.Id?, String, Bool) -> Signal<Bool, NoError>)?
        var answerCallImpl: ((UUID) -> Void)?
        var endCallImpl: ((UUID) -> Signal<Bool, NoError>)?
        var setCallMutedImpl: ((UUID, Bool) -> Void)?
        var audioSessionActivationChangedImpl: ((Bool) -> Void)?
        
        self.callKitIntegration = CallKitIntegration.shared
        self.callKitIntegration?.setup(startCall: { context, uuid, maybePeerId, handle, isVideo in
            if let startCallImpl = startCallImpl {
                return startCallImpl(context, uuid, maybePeerId, handle, isVideo)
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
                    return context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: state.peerId),
                        TelegramEngine.EngineData.Item.Peer.IsContact(id: state.peerId)
                    )
                    |> map { peer, isContact -> (AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)? in
                        if let peer = peer {
                            return (context, peer._asPeer(), state, isContact, networkType)
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
        
        startCallImpl = { [weak self] context, uuid, maybePeerId, handle, isVideo in
            guard let strongSelf = self else {
                return .single(false)
            }
            
            var peerId: PeerId?
            if let maybePeerId = maybePeerId {
                peerId = maybePeerId
            } else if let userId = Int64(handle) {
                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            }
            guard let peerId = peerId else {
                return .single(false)
            }
            
            return strongSelf.startCall(context: context, peerId: peerId, isVideo: isVideo, internalId: uuid)
            |> take(1)
            |> map { result -> Bool in
                return result
            }
        }
        
        answerCallImpl = { [weak self] uuid in
            if let strongSelf = self {
                strongSelf.currentCall?.answer(fromCallKitAction: true)
            }
        }
        
        endCallImpl = { [weak self] uuid in
            guard let self else {
                return .single(false)
            }
            
            if let currentGroupCall = self.currentGroupCall {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    return conferenceSource.hangUp()
                case let .group(groupCall):
                    return groupCall.leave(terminateIfPossible: false)
                }
            }
            if let currentCall = self.currentCall {
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
        self.callToConferenceDisposable?.dispose()
        self.isConferenceReadyDisposable?.dispose()
    }
    
    private func ringingStatesUpdated(_ ringingStates: [(AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)], enableCallKit: Bool) {
        if let firstState = ringingStates.first {
            if self.currentCall == nil && self.currentGroupCall == nil {
                self.currentCallDisposable.set((combineLatest(
                    firstState.0.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, PreferencesKeys.appConfiguration]) |> take(1),
                    accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings]) |> take(1)
                )
                |> deliverOnMainQueue).start(next: { [weak self] preferences, sharedData in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.currentUpgradedToConferenceCallId == firstState.2.id {
                        return
                    }
                    
                    let configuration = preferences.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
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
                        getDeviceAccessData: strongSelf.getDeviceAccessData,
                        initialState: nil,
                        internalId: firstState.2.id,
                        peerId: firstState.2.peerId,
                        isOutgoing: false,
                        incomingConferenceSource: firstState.2.conferenceSource,
                        peer: EnginePeer(firstState.1),
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
                }))
            } else if let currentCall = self.currentCall, currentCall.peerId == firstState.1.id, currentCall.peerId.id._internalGetInt64Value() < firstState.0.account.peerId.id._internalGetInt64Value() {
                let _ = currentCall.hangUp().startStandalone()
                
                self.currentCallDisposable.set((combineLatest(
                    firstState.0.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, PreferencesKeys.appConfiguration]) |> take(1),
                    accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings]) |> take(1)
                )
                |> deliverOnMainQueue).start(next: { [weak self] preferences, sharedData in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.currentUpgradedToConferenceCallId == firstState.2.id {
                        return
                    }
                    
                    let configuration = preferences.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
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
                        getDeviceAccessData: strongSelf.getDeviceAccessData,
                        initialState: nil,
                        internalId: firstState.2.id,
                        peerId: firstState.2.peerId,
                        isOutgoing: false,
                        incomingConferenceSource: firstState.2.conferenceSource,
                        peer: EnginePeer(firstState.1),
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
                    
                    call.answer()
                }))
            } else {
                for (context, _, state, _, _) in ringingStates {
                    if state.id != self.currentCall?.internalId {
                        self.callKitIntegration?.dropCall(uuid: state.id)
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
            switch currentGroupCall {
            case let .conferenceSource(conferenceSource):
                alreadyInCallWithPeerId = conferenceSource.peerId
            case let .group(groupCall):
                alreadyInCallWithPeerId = groupCall.peerId
            }
        } else {
            if CXCallObserver().calls.contains(where: { $0.hasEnded == false }) {
                alreadyInCall = true
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
                |> mapToSignal { accessEnabled -> Signal<(Peer?, String?), NoError> in
                    if !accessEnabled {
                        return .single((nil, nil))
                    }
                    return postbox.transaction { transaction -> (Peer?, String?) in
                        var foundLocalId: String?
                        transaction.enumerateDeviceContactImportInfoItems({ _, value in
                            if let value = value as? TelegramDeviceContactImportedData {
                                switch value {
                                case let .imported(data, _, importedPeerId):
                                    if importedPeerId == peerId {
                                        foundLocalId = data.localIdentifiers.first
                                        return false
                                    }
                                default:
                                    break
                                }
                            }
                            return true
                        })
                        
                        return (transaction.getPeer(peerId), foundLocalId)
                    }
                }
                |> deliverOnMainQueue).start(next: { peer, localContactId in
                    guard let strongSelf = self, let peer = peer else {
                        return
                    }
                    var phoneNumber: String?
                    if let peer = peer as? TelegramUser, let phone = peer.phone {
                        phoneNumber = formatPhoneNumber(context: context, number: phone)
                    }
                    strongSelf.callKitIntegration?.startCall(context: context, peerId: peerId, phoneNumber: phoneNumber, localContactId: localContactId, isVideo: isVideo, displayTitle: peer.debugDisplayTitle)
                }))
            }
            if let currentCall = self.currentCall {
                self.callKitIntegration?.dropCall(uuid: currentCall.internalId)
                self.startCallDisposable.set((currentCall.hangUp()
                |> deliverOnMainQueue).start(next: { _ in
                    begin()
                }))
            } else if let currentGroupCall = self.currentGroupCallValue {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    self.startCallDisposable.set((conferenceSource.hangUp()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                case let .group(groupCall):
                    self.startCallDisposable.set((groupCall.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                }
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
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    self.startCallDisposable.set((conferenceSource.hangUp()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                case let .group(groupCall):
                    self.startCallDisposable.set((groupCall.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                }
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
            
            let areVideoCallsAvailable = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.AreVideoCallsAvailable(id: peerId))
            
            let request = areVideoCallsAvailable
            |> mapToSignal { areVideoCallsAvailable -> Signal<CallSessionInternalId, NoError> in
                let isVideoPossible: Bool = areVideoCallsAvailable
                
                return context.account.callSessionManager.request(peerId: peerId, isVideo: isVideo, enableVideo: isVideoPossible, internalId: internalId)
            }
            
            return (combineLatest(queue: .mainQueue(),
                request,
                networkType |> take(1),
                context.account.postbox.peerView(id: peerId)
                |> map { peerView -> Bool in
                    return peerView.peerIsContact
                }
                |> take(1),
                context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration, PreferencesKeys.appConfiguration]) |> take(1),
                accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings]) |> take(1),
                areVideoCallsAvailable
            )
            |> deliverOnMainQueue
            |> beforeNext { internalId, currentNetworkType, isContact, preferences, sharedData, areVideoCallsAvailable in
                if let strongSelf = self, accessEnabled {
                    if let currentCall = strongSelf.currentCall {
                        currentCall.rejectBusy()
                    }
                    
                    let configuration = preferences.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
                    let autodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) ?? .defaultSettings
                    let appConfiguration = preferences.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                    
                    let isVideoPossible: Bool = areVideoCallsAvailable
                    
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
                        getDeviceAccessData: strongSelf.getDeviceAccessData,
                        initialState: nil,
                        internalId: internalId,
                        peerId: peerId,
                        isOutgoing: true,
                        incomingConferenceSource: nil,
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
        
        if self.currentCallValue !== value {
            self.currentCallValue = value
            
            self.callToConferenceDisposable?.dispose()
            self.callToConferenceDisposable = nil
            self.currentUpgradedToConferenceCallId = nil
            
            if let currentCallValue = self.currentCallValue {
                self.callToConferenceDisposable = (currentCallValue.conferenceState
                |> filter { conferenceState in
                    return conferenceState != nil
                }
                |> take(1)
                |> deliverOnMainQueue).startStrict(next: { [weak self, weak currentCallValue] _ in
                    guard let self, let currentCallValue, self.currentCallValue === currentCallValue else {
                        return
                    }
                    
                    self.currentUpgradedToConferenceCallId = currentCallValue.internalId
                    self.removeCurrentCallDisposable.set(nil)
                    
                    self.updateCurrentGroupCall(.conferenceSource(currentCallValue))
                    self.updateCurrentCall(nil)
                })
                
                self.currentCallPromise.set(.single(currentCallValue))
                self.hasActivePersonalCallsPromise.set(true)
                self.removeCurrentCallDisposable.set((currentCallValue.canBeRemoved
                |> deliverOnMainQueue).start(next: { [weak self, weak currentCallValue] value in
                    if value, let self, let currentCallValue {
                        if self.currentCall === currentCallValue {
                            self.updateCurrentCall(nil)
                            self.currentCallPromise.set(.single(nil))
                            self.hasActivePersonalCallsPromise.set(false)
                        }
                    }
                }))
            } else {
                self.currentCallPromise.set(.single(nil))
                self.hasActivePersonalCallsPromise.set(false)
            }
        }
        
        if !wasEmpty && isEmpty && self.resumeMedia {
            self.resumeMedia = false
            self.resumeMediaPlayback()
        }
    }
    
    private func updateCurrentGroupCall(_ value: VideoChatCall?) {
        let wasEmpty = self.currentGroupCallValue == nil
        let isEmpty = value == nil
        if wasEmpty && !isEmpty {
            self.resumeMedia = self.isMediaPlaying()
        }
        
        if self.currentGroupCallValue != value {
            if case let .group(groupCall) = self.currentGroupCallValue, let conferenceSourceId = groupCall.conferenceSource {
                groupCall.accountContext.account.callSessionManager.drop(internalId: conferenceSourceId, reason: .hangUp, debugLog: .single(nil))
                (groupCall as! PresentationGroupCallImpl).callKitIntegration?.dropCall(uuid: conferenceSourceId)
            }
            
            self.currentGroupCallValue = value
            
            self.isConferenceReadyDisposable?.dispose()
            self.isConferenceReadyDisposable = nil
            
            if let value {
                switch value {
                case let .conferenceSource(conferenceSource):
                    self.isConferenceReadyDisposable?.dispose()
                    self.isConferenceReadyDisposable = (conferenceSource.conferenceState
                    |> filter { value in
                        if let value, case .ready = value {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> take(1)
                    |> deliverOnMainQueue).startStrict(next: { [weak self, weak conferenceSource] _ in
                        guard let self, let conferenceSource, self.currentGroupCallValue == .conferenceSource(conferenceSource) else {
                            return
                        }
                        guard let groupCall = conferenceSource.conferenceCall else {
                            return
                        }
                        (groupCall as! PresentationGroupCallImpl).moveConferenceCall(source: conferenceSource)
                        self.updateCurrentGroupCall(.group(groupCall))
                    })
                    
                    self.currentGroupCallPromise.set(.single(.conferenceSource(conferenceSource)))
                    self.hasActiveGroupCallsPromise.set(true)
                    self.removeCurrentGroupCallDisposable.set((conferenceSource.canBeRemoved
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self, weak conferenceSource] value in
                        guard let self, let conferenceSource else {
                            return
                        }
                        if value {
                            if self.currentGroupCall == .conferenceSource(conferenceSource) {
                                self.updateCurrentGroupCall(nil)
                            }
                        }
                    }))
                case let .group(groupCall):
                    self.currentGroupCallPromise.set(.single(.group(groupCall)))
                    self.hasActiveGroupCallsPromise.set(true)
                    self.removeCurrentGroupCallDisposable.set((groupCall.canBeRemoved
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self, weak groupCall] value in
                        guard let self, let groupCall else {
                            return
                        }
                        if value {
                            if self.currentGroupCall == .group(groupCall) {
                                self.updateCurrentGroupCall(nil)
                            }
                        }
                    }))
                }
            } else {
                self.currentGroupCallPromise.set(.single(nil))
                self.hasActiveGroupCallsPromise.set(false)
            }
        }
        
        if !wasEmpty && isEmpty && self.resumeMedia {
            self.resumeMedia = false
            self.resumeMediaPlayback()
        }
    }
    
    private func requestScheduleGroupCall(accountContext: AccountContext, peerId: PeerId, internalId: CallSessionInternalId = CallSessionInternalId(), parentController: ViewController) -> Signal<Bool, NoError> {
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
        |> mapToSignal { [weak self, weak parentController] accessEnabled, peer -> Signal<Bool, NoError> in
            guard let self else {
                return .single(false)
            }
            
            if !accessEnabled {
                return .single(false)
            }

            var isChannel = false
            if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                isChannel = true
            }
            
            if let parentController {
                parentController.push(ScheduleVideoChatSheetScreen(
                    context: accountContext,
                    scheduleAction: { [weak self] timestamp in
                        guard let self else {
                            return
                        }
                        
                        let call = PresentationGroupCallImpl(
                            accountContext: accountContext,
                            audioSession: self.audioSession,
                            callKitIntegration: nil,
                            getDeviceAccessData: self.getDeviceAccessData,
                            initialCall: nil,
                            internalId: internalId,
                            peerId: peerId,
                            isChannel: isChannel,
                            invite: nil,
                            joinAsPeerId: nil,
                            isStream: false,
                            keyPair: nil,
                            conferenceSourceId: nil,
                            isConference: false,
                            beginWithVideo: false,
                            sharedAudioContext: nil
                        )
                        call.schedule(timestamp: timestamp)
                        
                        self.updateCurrentGroupCall(.group(call))
                    }
                ))
            }
        
            return .single(true)
        }
    }
    
    public func scheduleGroupCall(context: AccountContext, peerId: PeerId, endCurrentIfAny: Bool, parentController: ViewController) -> RequestScheduleGroupCallResult {
        let begin: () -> Void = { [weak self, weak parentController] in
            guard let parentController else {
                return
            }
            let _ = self?.requestScheduleGroupCall(accountContext: context, peerId: peerId, parentController: parentController).start()
        }
        
        if let currentGroupCall = self.currentGroupCallValue {
            if endCurrentIfAny {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    self.startCallDisposable.set((conferenceSource.hangUp()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                case let .group(groupCall):
                    self.startCallDisposable.set((groupCall.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                }
            } else {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    return .alreadyInProgress(conferenceSource.peerId)
                case let .group(groupCall):
                    return .alreadyInProgress(groupCall.peerId)
                }
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
            if let requestJoinAsPeerId = requestJoinAsPeerId, (initialCall.isStream == nil || initialCall.isStream == false) {
                requestJoinAsPeerId({ joinAsPeerId in
                    guard let self else {
                        return
                    }
                    self.startCallDisposable.set(self.startGroupCall(accountContext: context, peerId: peerId, invite: invite, joinAsPeerId: joinAsPeerId, initialCall: initialCall).startStrict())
                })
            } else {
                guard let self else {
                    return
                }
                self.startCallDisposable.set(self.startGroupCall(accountContext: context, peerId: peerId, invite: invite, joinAsPeerId: nil, initialCall: initialCall).startStrict())
            }
        }
        
        if let currentGroupCall = self.currentGroupCallValue {
            if endCurrentIfAny {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    self.startCallDisposable.set((conferenceSource.hangUp()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                case let .group(groupCall):
                    self.startCallDisposable.set((groupCall.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                }
            } else {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    return .alreadyInProgress(conferenceSource.peerId)
                case let .group(groupCall):
                    return .alreadyInProgress(groupCall.peerId)
                }
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
                subscriber.putCompletion()
                
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

            strongSelf.createGroupCall(
                accountContext: accountContext,
                peerId: peerId,
                peer: peer,
                initialCall: initialCall,
                internalId: internalId,
                invite: invite,
                joinAsPeerId: joinAsPeerId
            )
        
            return .single(true)
        }
    }
    
    private func createGroupCall(
        accountContext: AccountContext,
        peerId: EnginePeer.Id,
        peer: EnginePeer?,
        initialCall: EngineGroupCallDescription,
        internalId: CallSessionInternalId,
        invite: String?,
        joinAsPeerId: EnginePeer.Id?
    ) {
        var isChannel = false
        if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
            isChannel = true
        }
                
        let call = PresentationGroupCallImpl(
            accountContext: accountContext,
            audioSession: self.audioSession,
            callKitIntegration: nil,
            getDeviceAccessData: self.getDeviceAccessData,
            initialCall: (initialCall, .id(id: initialCall.id, accessHash: initialCall.accessHash)),
            internalId: internalId,
            peerId: peerId,
            isChannel: isChannel,
            invite: invite,
            joinAsPeerId: joinAsPeerId,
            isStream: initialCall.isStream ?? false,
            keyPair: nil,
            conferenceSourceId: nil,
            isConference: false,
            beginWithVideo: false,
            sharedAudioContext: nil
        )
        self.updateCurrentGroupCall(.group(call))
    }
    
    public func joinConferenceCall(
        accountContext: AccountContext,
        initialCall: EngineGroupCallDescription,
        reference: InternalGroupCallReference,
        beginWithVideo: Bool,
        invitePeerIds: [EnginePeer.Id],
        endCurrentIfAny: Bool,
        unmuteByDefault: Bool
    ) -> JoinGroupCallManagerResult {
        let begin: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            
            let keyPair: TelegramKeyPair
            guard let keyPairValue = TelegramE2EEncryptionProviderImpl.shared.generateKeyPair() else {
                return
            }
            keyPair = keyPairValue
            
            let call = PresentationGroupCallImpl(
                accountContext: accountContext,
                audioSession: self.audioSession,
                callKitIntegration: nil,
                getDeviceAccessData: self.getDeviceAccessData,
                initialCall: (initialCall, reference),
                internalId: CallSessionInternalId(),
                peerId: nil,
                isChannel: false,
                invite: nil,
                joinAsPeerId: nil,
                isStream: false,
                keyPair: keyPair,
                conferenceSourceId: nil,
                isConference: true,
                beginWithVideo: beginWithVideo,
                sharedAudioContext: nil,
                unmuteByDefault: unmuteByDefault
            )
            for peerId in invitePeerIds {
                let _ = call.invitePeer(peerId, isVideo: beginWithVideo)
            }
            self.updateCurrentGroupCall(.group(call))
        }
        
        if let currentGroupCall = self.currentGroupCallValue {
            if endCurrentIfAny {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    self.startCallDisposable.set((conferenceSource.hangUp()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                case let .group(groupCall):
                    self.startCallDisposable.set((groupCall.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        begin()
                    }))
                }
            } else {
                switch currentGroupCall {
                case let .conferenceSource(conferenceSource):
                    return .alreadyInProgress(conferenceSource.peerId)
                case let .group(groupCall):
                    return .alreadyInProgress(groupCall.peerId)
                }
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
}
