import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import AVFoundation
import TelegramVoip
import TelegramAudio
import TelegramUIPreferences
import TelegramPresentationData
import DeviceAccess
import UniversalMediaPlayer
import AccountContext
import DeviceProximity
import UndoUI
import TemporaryCachedPeerDataManager
import CallsEmoji
import TdBinding

private extension PresentationGroupCallState {
    static func initialValue(myPeerId: PeerId, title: String?, scheduleTimestamp: Int32?, subscribedToScheduled: Bool) -> PresentationGroupCallState {
        return PresentationGroupCallState(
            myPeerId: myPeerId,
            networkState: .connecting,
            canManageCall: false,
            adminIds: Set(),
            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
            defaultParticipantMuteState: nil,
            recordingStartTimestamp: nil,
            title: title,
            raisedHand: false,
            scheduleTimestamp: scheduleTimestamp,
            subscribedToScheduled: subscribedToScheduled,
            isVideoEnabled: false,
            isVideoWatchersLimitReached: false,
            isMyVideoActive: false
        )
    }
}

private enum CurrentImpl {
    case call(OngoingGroupCallContext)
    case mediaStream(WrappedMediaStreamingContext)
    case externalMediaStream(DirectMediaStreamingContext)
}

private extension CurrentImpl {
    var joinPayload: Signal<(String, UInt32), NoError> {
        switch self {
        case let .call(callContext):
            return callContext.joinPayload
        case .mediaStream, .externalMediaStream:
            let ssrcId = UInt32.random(in: 0 ..< UInt32(Int32.max - 1))
            let dict: [String: Any] = [
                "fingerprints": [] as [Any],
                "ufrag": "",
                "pwd": "",
                "ssrc": Int32(bitPattern: ssrcId),
                "ssrc-groups": [] as [Any]
            ]
            guard let jsonString = (try? JSONSerialization.data(withJSONObject: dict, options: [])).flatMap({ String(data: $0, encoding: .utf8) }) else {
                return .never()
            }
            return .single((jsonString, ssrcId))
        }
    }
    
    var networkState: Signal<OngoingGroupCallContext.NetworkState, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.networkState
        case .mediaStream, .externalMediaStream:
            return .single(OngoingGroupCallContext.NetworkState(isConnected: true, isTransitioningFromBroadcastToRtc: false))
        }
    }
    
    var audioLevels: Signal<[(OngoingGroupCallContext.AudioLevelKey, Float, Bool)], NoError> {
        switch self {
        case let .call(callContext):
            return callContext.audioLevels
        case .mediaStream, .externalMediaStream:
            return .single([])
        }
    }
    
    var isMuted: Signal<Bool, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.isMuted
        case .mediaStream, .externalMediaStream:
            return .single(true)
        }
    }

    var isNoiseSuppressionEnabled: Signal<Bool, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.isNoiseSuppressionEnabled
        case .mediaStream, .externalMediaStream:
            return .single(false)
        }
    }
    
    func stop(account: Account, reportCallId: CallId?, debugLog: Promise<String?>) {
        switch self {
        case let .call(callContext):
            callContext.stop(account: account, reportCallId: reportCallId, debugLog: debugLog)
        case .mediaStream, .externalMediaStream:
            debugLog.set(.single(nil))
        }
    }
    
    func setIsMuted(_ isMuted: Bool) {
        switch self {
        case let .call(callContext):
            callContext.setIsMuted(isMuted)
        case .mediaStream, .externalMediaStream:
            break
        }
    }

    func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool) {
        switch self {
        case let .call(callContext):
            callContext.setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled)
        case .mediaStream, .externalMediaStream:
            break
        }
    }
    
    func requestVideo(_ capturer: OngoingCallVideoCapturer?) {
        switch self {
        case let .call(callContext):
            callContext.requestVideo(capturer)
        case .mediaStream, .externalMediaStream:
            break
        }
    }
    
    func disableVideo() {
        switch self {
        case let .call(callContext):
            callContext.disableVideo()
        case .mediaStream, .externalMediaStream:
            break
        }
    }
    
    func setVolume(ssrc: UInt32, volume: Double) {
        switch self {
        case let .call(callContext):
            callContext.setVolume(ssrc: ssrc, volume: volume)
        case .mediaStream, .externalMediaStream:
            break
        }
    }

    func setRequestedVideoChannels(_ channels: [OngoingGroupCallContext.VideoChannel]) {
        switch self {
        case let .call(callContext):
            callContext.setRequestedVideoChannels(channels)
        case .mediaStream, .externalMediaStream:
            break
        }
    }

    func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.video(endpointId: endpointId)
        case let .mediaStream(mediaStreamContext):
            return mediaStreamContext.video()
        case .externalMediaStream:
            return .never()
        }
    }

    func addExternalAudioData(data: Data) {
        switch self {
        case let .call(callContext):
            callContext.addExternalAudioData(data: data)
        case .mediaStream, .externalMediaStream:
            break
        }
    }

    func getStats(completion: @escaping (OngoingGroupCallContext.Stats) -> Void) {
        switch self {
        case let .call(callContext):
            callContext.getStats(completion: completion)
        case .mediaStream, .externalMediaStream:
            break
        }
    }
    
    func setTone(tone: OngoingGroupCallContext.Tone?) {
        switch self {
        case let .call(callContext):
            callContext.setTone(tone: tone)
        case .mediaStream, .externalMediaStream:
            break
        }
    }
}

private final class PendingConferenceInvitationContext {
    enum State {
        case ringing
    }
    
    enum InvitationError {
        case generic
        case privacy(peer: EnginePeer?)
    }
    
    private let engine: TelegramEngine
    private var requestDisposable: Disposable?
    private var stateDisposable: Disposable?
    private(set) var messageId: EngineMessage.Id?
    
    private var hadMessage: Bool = false
    private var didNotifyEnded: Bool = false
    
    init(engine: TelegramEngine, reference: InternalGroupCallReference, peerId: PeerId, isVideo: Bool, onStateUpdated: @escaping (State) -> Void, onEnded: @escaping (Bool) -> Void, onError: @escaping (InvitationError) -> Void) {
        self.engine = engine
        self.requestDisposable = ((engine.calls.inviteConferenceCallParticipant(reference: reference, peerId: peerId, isVideo: isVideo) |> deliverOnMainQueue).startStrict(next: { [weak self] messageId in
            guard let self else {
                return
            }
            self.messageId = messageId
            
            onStateUpdated(.ringing)
            
            let timeout: Double = 30.0
            let timerSignal = Signal<Void, NoError>.single(Void()) |> then(
                Signal<Void, NoError>.single(Void())
                |> delay(1.0, queue: .mainQueue())
            ) |> restart
            
            let startTime = CFAbsoluteTimeGetCurrent()
            self.stateDisposable = (combineLatest(queue: .mainQueue(),
                engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
                ),
                timerSignal
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] message, _ in
                guard let self else {
                    return
                }
                if let message {
                    self.hadMessage = true
                    if message.timestamp + Int32(timeout) <= Int32(Date().timeIntervalSince1970) {
                        if !self.didNotifyEnded {
                            self.didNotifyEnded = true
                            onEnded(false)
                        }
                    } else {
                        var isActive = false
                        var isAccepted = false
                        var foundAction: TelegramMediaAction?
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                foundAction = action
                                break
                            }
                        }
                        
                        if let action = foundAction, case let .conferenceCall(conferenceCall) = action.action {
                            if conferenceCall.flags.contains(.isMissed) || conferenceCall.duration != nil {
                            } else {
                                if conferenceCall.flags.contains(.isActive) {
                                    isAccepted = true
                                } else {
                                    isActive = true
                                }
                            }
                        }
                        if !isActive {
                            if !self.didNotifyEnded {
                                self.didNotifyEnded = true
                                onEnded(isAccepted)
                            }
                        }
                    }
                } else {
                    if self.hadMessage || CFAbsoluteTimeGetCurrent() > startTime + 1.0 {
                        if !self.didNotifyEnded {
                            self.didNotifyEnded = true
                            onEnded(false)
                        }
                    }
                }
            })
        }, error: { [weak self] error in
            guard let self else {
                return
            }
            
            if !self.didNotifyEnded {
                self.didNotifyEnded = true
                onEnded(false)
            }
            
            let mappedError: InvitationError
            switch error {
            case .privacy(let peer):
                mappedError = .privacy(peer: peer)
            default:
                mappedError = .generic
            }
            onError(mappedError)
        }))
    }
    
    deinit {
        self.requestDisposable?.dispose()
        self.stateDisposable?.dispose()
    }
}

private final class ConferenceCallE2EContextStateImpl: ConferenceCallE2EContextState {
    private let call: TdCall

    init(call: TdCall) {
        self.call = call
    }

    func getEmojiState() -> Data? {
        return self.call.emojiState()
    }
    
    func getParticipants() -> [ConferenceCallE2EContext.BlockchainParticipant] {
        return self.call.participants().map { ConferenceCallE2EContext.BlockchainParticipant(userId: $0.userId, internalId: $0.internalId) }
    }
    
    func getParticipantLatencies() -> [Int64: Double] {
        let dict = self.call.participantLatencies()
        var result: [Int64: Double] = [:]
        for (k, v) in dict {
            result[k.int64Value] = v.doubleValue
        }
        return result
    }

    func getParticipantIds() -> [Int64] {
        return self.call.participants().map { $0.userId }
    }

    func applyBlock(block: Data) {
        self.call.applyBlock(block)
    }

    func applyBroadcastBlock(block: Data) {
        self.call.applyBroadcastBlock(block)
    }

    func generateRemoveParticipantsBlock(participantIds: [Int64]) -> Data? {
        return self.call.generateRemoveParticipantsBlock(participantIds.map { $0 as NSNumber })
    }

    func takeOutgoingBroadcastBlocks() -> [Data] {
        return self.call.takeOutgoingBroadcastBlocks()
    }

    func encrypt(message: Data, channelId: Int32, plaintextPrefixLength: Int) -> Data? {
        return self.call.encrypt(message, channelId: channelId, plaintextPrefixLength: plaintextPrefixLength)
    }

    func decrypt(message: Data, userId: Int64) -> Data? {
        return self.call.decrypt(message, userId: userId)
    }
}

class OngoingGroupCallEncryptionContextImpl: OngoingGroupCallEncryptionContext {
    private let e2eCall: Atomic<ConferenceCallE2EContext.ContextStateHolder>
    private let channelId: Int32
    
    init(e2eCall: Atomic<ConferenceCallE2EContext.ContextStateHolder>, channelId: Int32) {
        self.e2eCall = e2eCall
        self.channelId = channelId
    }
    
    func encrypt(message: Data, plaintextPrefixLength: Int) -> Data? {
        let channelId = self.channelId
        return self.e2eCall.with({ $0.state?.encrypt(message: message, channelId: channelId, plaintextPrefixLength: plaintextPrefixLength) })
    }
    
    func decrypt(message: Data, userId: Int64) -> Data? {
        return self.e2eCall.with({ $0.state?.decrypt(message: message, userId: userId) })
    }
}

public final class PresentationGroupCallImpl: PresentationGroupCall {
    private enum InternalState {
        case requesting
        case active(GroupCallInfo)
        case established(info: GroupCallInfo, connectionMode: JoinGroupCallResult.ConnectionMode, clientParams: String, localSsrc: UInt32, initialState: GroupCallParticipantsContext.State)
        
        var callInfo: GroupCallInfo? {
            switch self {
            case .requesting:
                return nil
            case let .active(info):
                return info
            case let .established(info, _, _, _, _):
                return info
            }
        }
    }
    
    private struct SummaryInfoState: Equatable {
        public var info: GroupCallInfo
        
        public init(
            info: GroupCallInfo
        ) {
            self.info = info
        }
    }
    
    private struct SummaryParticipantsState: Equatable {
        public var participantCount: Int
        public var topParticipants: [GroupCallParticipantsContext.Participant]
        public var activeSpeakers: Set<EnginePeer.Id>
    
        public init(
            participantCount: Int,
            topParticipants: [GroupCallParticipantsContext.Participant],
            activeSpeakers: Set<EnginePeer.Id>
        ) {
            self.participantCount = participantCount
            self.topParticipants = topParticipants
            self.activeSpeakers = activeSpeakers
        }
    }
    
    private class SpeakingParticipantsContext {
        private let speakingLevelThreshold: Float = 0.1
        private let cutoffTimeout: Int32 = 3
        private let silentTimeout: Int32 = 2
        
        struct Participant {
            let ssrc: UInt32
            let timestamp: Int32
            let level: Float
        }
        
        private var participants: [EnginePeer.Id: Participant] = [:]
        private let speakingParticipantsPromise = ValuePromise<[PeerId: UInt32]>()
        private var speakingParticipants = [EnginePeer.Id: UInt32]() {
            didSet {
                self.speakingParticipantsPromise.set(self.speakingParticipants)
            }
        }
        
        private let audioLevelsPromise = Promise<[(EnginePeer.Id, UInt32, Float, Bool)]>()
        
        init() {
        }
        
        func update(levels: [(EnginePeer.Id, UInt32, Float, Bool)]) {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            let currentParticipants: [PeerId: Participant] = self.participants
            
            var validSpeakers: [EnginePeer.Id: Participant] = [:]
            var silentParticipants = Set<EnginePeer.Id>()
            var speakingParticipants = [EnginePeer.Id: UInt32]()
            for (peerId, ssrc, level, hasVoice) in levels {
                if level > speakingLevelThreshold && hasVoice {
                    validSpeakers[peerId] = Participant(ssrc: ssrc, timestamp: timestamp, level: level)
                    speakingParticipants[peerId] = ssrc
                } else {
                    silentParticipants.insert(peerId)
                }
            }
            
            for (peerId, participant) in currentParticipants {
                if let _ = validSpeakers[peerId] {
                } else {
                    let delta = timestamp - participant.timestamp
                    if silentParticipants.contains(peerId) {
                        if delta < silentTimeout {
                            validSpeakers[peerId] = participant
                            speakingParticipants[peerId] = participant.ssrc
                        }
                    } else if delta < cutoffTimeout {
                        validSpeakers[peerId] = participant
                        speakingParticipants[peerId] = participant.ssrc
                    }
                }
            }
            
            var audioLevels: [(EnginePeer.Id, UInt32, Float, Bool)] = []
            for (peerId, source, level, hasVoice) in levels {
                if level > 0.001 {
                    audioLevels.append((peerId, source, level, hasVoice))
                }
            }
            
            self.participants = validSpeakers
            self.speakingParticipants = speakingParticipants
            self.audioLevelsPromise.set(.single(audioLevels))
        }
        
        func get() -> Signal<[EnginePeer.Id: UInt32], NoError> {
            return self.speakingParticipantsPromise.get()
        }
        
        func getAudioLevels() -> Signal<[(EnginePeer.Id, UInt32, Float, Bool)], NoError> {
            return self.audioLevelsPromise.get()
        }
    }
    
    public let account: Account
    public let accountContext: AccountContext
    private let audioSession: ManagedAudioSession
    public let callKitIntegration: CallKitIntegration?
    public var isIntegratedWithCallKit: Bool {
        return self.callKitIntegration != nil
    }
    
    private let getDeviceAccessData: () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void)
    
    private(set) var initialCall: (description: EngineGroupCallDescription, reference: InternalGroupCallReference)?
    public var currentReference: InternalGroupCallReference?
    public let internalId: CallSessionInternalId
    public let peerId: EnginePeer.Id?
    private let isChannel: Bool
    private var invite: String?
    private var joinAsPeerId: EnginePeer.Id
    private var ignorePreviousJoinAsPeerId: (PeerId, UInt32)?
    private var reconnectingAsPeer: EnginePeer?
    
    public private(set) var callId: Int64?
    
    public private(set) var hasVideo: Bool
    public private(set) var hasScreencast: Bool
    private let isVideoEnabled: Bool
    
    private let keyPair: TelegramKeyPair?
    
    private var temporaryJoinTimestamp: Int32
    private var temporaryActivityTimestamp: Double?
    private var temporaryActivityRank: Int?
    private var temporaryRaiseHandRating: Int64?
    private var temporaryHasRaiseHand: Bool = false
    private var temporaryJoinedVideo: Bool = true
    private var temporaryMuteState: GroupCallParticipantsContext.Participant.MuteState?
    
    private var internalState: InternalState = .requesting
    private let internalStatePromise = Promise<InternalState>(.requesting)
    private var currentLocalSsrc: UInt32?
    private var currentLocalEndpointId: String?
    
    private var genericCallContext: CurrentImpl?
    private var currentConnectionMode: OngoingGroupCallContext.ConnectionMode = .none
    private var didInitializeConnectionMode: Bool = false
    
    let externalMediaStream = Promise<DirectMediaStreamingContext>()

    private var screencastIPCContext: ScreencastIPCContext?

    private struct SsrcMapping {
        var peerId: EnginePeer.Id
        var isPresentation: Bool
    }
    private var ssrcMapping: [UInt32: SsrcMapping] = [:]
    
    private var requestedVideoChannels: [OngoingGroupCallContext.VideoChannel] = []
    private var suspendVideoChannelRequests: Bool = false
    private var pendingVideoSubscribers = Bag<(String, MetaDisposable, (OngoingGroupCallContext.VideoFrameData) -> Void)>()
    
    private var summaryInfoState = Promise<SummaryInfoState?>(nil)
    private var summaryParticipantsState = Promise<SummaryParticipantsState?>(nil)
    
    private let summaryStatePromise = Promise<PresentationGroupCallSummaryState?>(nil)
    public var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> {
        return self.summaryStatePromise.get()
    }
    private var summaryStateDisposable: Disposable?
    
    private var isMutedValue: PresentationGroupCallMuteAction = .muted(isPushToTalkActive: false) {
        didSet {
            if self.isMutedValue != oldValue {
                self.updateProximityMonitoring()
            }
        }
    }
    private let isMutedPromise = ValuePromise<PresentationGroupCallMuteAction>(.muted(isPushToTalkActive: false))
    public var isMuted: Signal<Bool, NoError> {
        return self.isMutedPromise.get()
        |> map { value -> Bool in
            switch value {
            case let .muted(isPushToTalkActive):
                return !isPushToTalkActive
            case .unmuted:
                return false
            }
        }
    }

    private let isNoiseSuppressionEnabledPromise = ValuePromise<Bool>(true)
    public var isNoiseSuppressionEnabled: Signal<Bool, NoError> {
        return self.isNoiseSuppressionEnabledPromise.get()
    }
    private let isNoiseSuppressionEnabledDisposable = MetaDisposable()
    
    public var e2eEncryptionKeyHash: Signal<Data?, NoError> {
        return self.e2eContext?.e2eEncryptionKeyHash ?? .single(nil)
    }

    private var isVideoMuted: Bool = false
    private let isVideoMutedDisposable = MetaDisposable()
    
    private let audioOutputStatePromise = Promise<([AudioSessionOutput], AudioSessionOutput?)>(([], nil))
    private var audioOutputStateDisposable: Disposable?
    private var actualAudioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
    private var audioOutputStateValue: ([AudioSessionOutput], AudioSessionOutput?) = ([], nil)
    private var currentSelectedAudioOutputValue: AudioSessionOutput = .builtin
    public var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> {
        if let sharedAudioContext = self.sharedAudioContext {
            return sharedAudioContext.audioOutputState
        }
        return self.audioOutputStatePromise.get()
    }
    
    private var audioLevelsDisposable = MetaDisposable()
    
    private let speakingParticipantsContext = SpeakingParticipantsContext()
    private var speakingParticipantsReportTimestamp: [EnginePeer.Id: Double] = [:]
    public var audioLevels: Signal<[(EnginePeer.Id, UInt32, Float, Bool)], NoError> {
        return self.speakingParticipantsContext.getAudioLevels()
    }
    
    private var participantsContextStateDisposable = MetaDisposable()
    private var temporaryParticipantsContext: GroupCallParticipantsContext?
    private var participantsContext: GroupCallParticipantsContext?
    
    private let myAudioLevelPipe = ValuePipe<Float>()
    public var myAudioLevel: Signal<Float, NoError> {
        return self.myAudioLevelPipe.signal()
    }
    private let myAudioLevelAndSpeakingPipe = ValuePipe<(Float, Bool)>()
    public var myAudioLevelAndSpeaking: Signal<(Float, Bool), NoError> {
        return self.myAudioLevelAndSpeakingPipe.signal()
    }
    private var myAudioLevelDisposable = MetaDisposable()
    
    private var hasActiveIncomingDataValue: Bool = false {
        didSet {
            if self.hasActiveIncomingDataValue != oldValue {
                self.hasActiveIncomingDataPromise.set(self.hasActiveIncomingDataValue)
            }
        }
    }
    private let hasActiveIncomingDataPromise = ValuePromise<Bool>(false)
    var hasActiveIncomingData: Signal<Bool, NoError> {
        return self.hasActiveIncomingDataPromise.get()
    }
    private var hasActiveIncomingDataDisposable: Disposable?
    private var hasActiveIncomingDataTimer: Foundation.Timer?
    
    private let isFailedPromise = ValuePromise<Bool>(false)
    var isFailed: Signal<Bool, NoError> {
        return self.isFailedPromise.get()
    }
    
    private let signalBarsPromise = Promise<Int32>(0)
    var signalBars: Signal<Int32, NoError> {
        return self.signalBarsPromise.get()
    }
    
    private var audioSessionControl: ManagedAudioSessionControl?
    private var audioSessionDisposable: Disposable?
    private let audioSessionShouldBeActive = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var audioSessionShouldBeActiveDisposable: Disposable?
    private let audioSessionActive = Promise<Bool>(false)
    private var audioSessionActiveDisposable: Disposable?
    private var isAudioSessionActive = false
    
    private let typingDisposable = MetaDisposable()
    
    private let _canBeRemoved = Promise<Bool>(false)
    public var canBeRemoved: Signal<Bool, NoError> {
        return self._canBeRemoved.get()
    }
    private var markedAsCanBeRemoved = false
    
    private let wasRemoved = Promise<Bool>(false)
    private var leaving = false
    
    private var stateValue: PresentationGroupCallState {
        didSet {
            if self.stateValue != oldValue {
                self.statePromise.set(self.stateValue)
            }
        }
    }
    private let statePromise: ValuePromise<PresentationGroupCallState>
    public var state: Signal<PresentationGroupCallState, NoError> {
        return self.statePromise.get()
    }

    private var stateVersionValue: Int = 0 {
        didSet {
            if self.stateVersionValue != oldValue {
                self.stateVersionPromise.set(self.stateVersionValue)
            }
        }
    }
    private let stateVersionPromise = ValuePromise<Int>(0)
    public var stateVersion: Signal<Int, NoError> {
        return self.stateVersionPromise.get()
    }
    
    private var membersValue: PresentationGroupCallMembers? {
        didSet {
            if self.membersValue != oldValue {
                self.membersPromise.set(self.membersValue)
            }
        }
    }
    private let membersPromise = ValuePromise<PresentationGroupCallMembers?>(nil)
    public var members: Signal<PresentationGroupCallMembers?, NoError> {
        return self.membersPromise.get()
    }
    
    private var invitedPeersValue: [PresentationGroupCallInvitedPeer] = [] {
        didSet {
            if self.invitedPeersValue != oldValue {
                self.inivitedPeersPromise.set(self.invitedPeersValue)
            }
        }
    }
    private let inivitedPeersPromise = ValuePromise<[PresentationGroupCallInvitedPeer]>([])
    public var invitedPeers: Signal<[PresentationGroupCallInvitedPeer], NoError> {
        return self.inivitedPeersPromise.get()
    }
    
    private let memberEventsPipe = ValuePipe<PresentationGroupCallMemberEvent>()
    public var memberEvents: Signal<PresentationGroupCallMemberEvent, NoError> {
        return self.memberEventsPipe.signal()
    }
    private let memberEventsPipeDisposable = MetaDisposable()

    private let reconnectedAsEventsPipe = ValuePipe<EnginePeer>()
    public var reconnectedAsEvents: Signal<EnginePeer, NoError> {
        return self.reconnectedAsEventsPipe.signal()
    }
    
    private let joinDisposable = MetaDisposable()
    private let screencastJoinDisposable = MetaDisposable()
    private let requestDisposable = MetaDisposable()
    private let startDisposable = MetaDisposable()
    private var groupCallParticipantUpdatesDisposable: Disposable?
    
    private let networkStateDisposable = MetaDisposable()
    private let isMutedDisposable = MetaDisposable()
    private let memberStatesDisposable = MetaDisposable()
    private let leaveDisposable = MetaDisposable()

    private var isReconnectingAsSpeaker = false {
        didSet {
            if self.isReconnectingAsSpeaker != oldValue {
                self.isReconnectingAsSpeakerPromise.set(self.isReconnectingAsSpeaker)
            }
        }
    }
    private let isReconnectingAsSpeakerPromise = ValuePromise<Bool>(false)
    
    private var checkCallDisposable: Disposable?
    private var isCurrentlyConnecting: Bool?

    private var myAudioLevelTimer: SwiftSignalKit.Timer?
    
    private var proximityManagerIndex: Int?
    
    private var removedChannelMembersDisposable: Disposable?
    
    private var didStartConnectingOnce: Bool = false
    private var didConnectOnce: Bool = false
    
    private var videoCapturer: OngoingCallVideoCapturer?
    private var useFrontCamera: Bool = true

    private var peerUpdatesSubscription: Disposable?
    
    public private(set) var schedulePending = false
    private var isScheduled = false
    private var isScheduledStarted = false

    private let isSpeakingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isSpeaking: Signal<Bool, NoError> {
        return self.isSpeakingPromise.get()
    }
    
    private var screencastStateDisposable: Disposable?
    
    public let isStream: Bool
    private let sharedAudioContext: SharedCallAudioContext?
    
    public let isConference: Bool
    private let beginWithVideo: Bool
    
    private let conferenceSourceId: CallSessionInternalId?
    public var conferenceSource: CallSessionInternalId? {
        return self.conferenceSourceId
    }
    
    public var onMutedSpeechActivityDetected: ((Bool) -> Void)?
    
    let debugLog = Promise<String?>()
    
    public weak var upgradedConferenceCall: PresentationCallImpl?
    public var pendingDisconnedUpgradedConferenceCall: PresentationCallImpl?
    private var pendingDisconnedUpgradedConferenceCallTimer: Foundation.Timer?
    private var conferenceInvitationContexts: [PeerId: PendingConferenceInvitationContext] = [:]

    private let e2eContext: ConferenceCallE2EContext?
    
    private var lastErrorAlertTimestamp: Double = 0.0
    
    init(
        accountContext: AccountContext,
        audioSession: ManagedAudioSession,
        callKitIntegration: CallKitIntegration?,
        getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void),
        initialCall: (description: EngineGroupCallDescription, reference: InternalGroupCallReference)?,
        internalId: CallSessionInternalId,
        peerId: EnginePeer.Id?,
        isChannel: Bool,
        invite: String?,
        joinAsPeerId: EnginePeer.Id?,
        isStream: Bool,
        keyPair: TelegramKeyPair?,
        conferenceSourceId: CallSessionInternalId?,
        isConference: Bool,
        beginWithVideo: Bool,
        sharedAudioContext: SharedCallAudioContext?,
        unmuteByDefault: Bool? = nil
    ) {
        self.account = accountContext.account
        self.accountContext = accountContext
        self.audioSession = audioSession
        self.callKitIntegration = callKitIntegration
        self.getDeviceAccessData = getDeviceAccessData
        
        self.initialCall = initialCall
        self.currentReference = initialCall?.reference
        self.callId = initialCall?.description.id
        
        self.internalId = internalId
        self.peerId = peerId
        self.isChannel = isChannel
        self.invite = invite
        self.joinAsPeerId = joinAsPeerId ?? accountContext.account.peerId
        self.schedulePending = initialCall == nil
        self.isScheduled = initialCall == nil || initialCall?.description.scheduleTimestamp != nil
        
        self.stateValue = PresentationGroupCallState.initialValue(myPeerId: self.joinAsPeerId, title: initialCall?.description.title, scheduleTimestamp: initialCall?.description.scheduleTimestamp, subscribedToScheduled: initialCall?.description.subscribedToScheduled ?? false)
        self.statePromise = ValuePromise(self.stateValue)
        
        self.temporaryJoinTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)

        self.isVideoEnabled = true
        self.hasVideo = false
        self.hasScreencast = false
        self.isStream = isStream
        self.conferenceSourceId = conferenceSourceId
        self.isConference = isConference
        self.beginWithVideo = beginWithVideo
        self.keyPair = keyPair
        
        if let unmuteByDefault {
            if unmuteByDefault {
                self.isMutedValue = .unmuted
                self.isMutedPromise.set(self.isMutedValue)
                self.stateValue.muteState = nil
            }
        } else {
            if self.isConference && conferenceSourceId == nil {
                self.isMutedValue = .unmuted
                self.isMutedPromise.set(self.isMutedValue)
                self.stateValue.muteState = nil
            }
        }

        if let keyPair, let initialCall {
            self.e2eContext = ConferenceCallE2EContext(
                engine: accountContext.engine,
                callId: initialCall.description.id,
                accessHash: initialCall.description.accessHash,
                userId: accountContext.account.peerId.id._internalGetInt64Value(),
                reference: initialCall.reference,
                keyPair: keyPair,
                initializeState: { keyPair, userId, block in
                    guard let keyPair = TdKeyPair(keyId: keyPair.id, publicKey: keyPair.publicKey.data) else {
                        return nil
                    }
                    guard let call = TdCall.make(with: keyPair, userId: userId, latestBlock: block) else {
                        return nil
                    }
                    return ConferenceCallE2EContextStateImpl(call: call)
                }
            )
        } else {
            self.e2eContext = nil
        }
        
        var sharedAudioContext = sharedAudioContext
        if sharedAudioContext == nil {
            var useSharedAudio = !isStream
            var canReuseCurrent = true
            if let data = self.accountContext.currentAppConfiguration.with({ $0 }).data {
                if data["ios_killswitch_group_shared_audio"] != nil {
                    useSharedAudio = false
                }
                if data["ios_killswitch_group_shared_audio_reuse"] != nil {
                    canReuseCurrent = false
                }
            }
            
            if useSharedAudio {
                let sharedAudioContextValue = SharedCallAudioContext.get(audioSession: audioSession, callKitIntegration: callKitIntegration, defaultToSpeaker: true, reuseCurrent: canReuseCurrent && callKitIntegration == nil)
                sharedAudioContext = sharedAudioContextValue
            }
        }
        
        self.sharedAudioContext = sharedAudioContext
        
        if self.sharedAudioContext == nil && !accountContext.sharedContext.immediateExperimentalUISettings.liveStreamV2 {
            var didReceiveAudioOutputs = false
            
            if !audioSession.getIsHeadsetPluggedIn() {
                self.currentSelectedAudioOutputValue = .speaker
                self.audioOutputStatePromise.set(.single(([], .speaker)))
            }
            
            self.audioSessionDisposable = audioSession.push(audioSessionType: self.isStream ? .play(mixWithOthers: false) : .voiceCall, activateImmediately: true, manualActivate: { [weak self] control in
                Queue.mainQueue().async {
                    if let self {
                        self.updateSessionState(internalState: self.internalState, audioSessionControl: control)
                    }
                }
            }, deactivate: { [weak self] _ in
                return Signal { subscriber in
                    Queue.mainQueue().async {
                        if let self {
                            self.updateIsAudioSessionActive(false)
                            self.updateSessionState(internalState: self.internalState, audioSessionControl: nil)
                            
                            if self.isStream {
                                let _ = self.leave(terminateIfPossible: false)
                            }
                        }
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            }, availableOutputsChanged: { [weak self] availableOutputs, currentOutput in
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    self.audioOutputStateValue = (availableOutputs, currentOutput)
                    
                    var signal: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> = .single((availableOutputs, currentOutput))
                    if !didReceiveAudioOutputs {
                        didReceiveAudioOutputs = true
                        if currentOutput == .speaker {
                            signal = .single((availableOutputs, .speaker))
                            |> then(
                                signal
                                |> delay(1.0, queue: Queue.mainQueue())
                            )
                        }
                    }
                    self.audioOutputStatePromise.set(signal)
                }
            })
            
            self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                if value {
                    if let audioSessionControl = self.audioSessionControl {
                        if !self.isStream, let callKitIntegration = self.callKitIntegration {
                            _ = callKitIntegration.audioSessionActive
                            |> filter { $0 }
                            |> timeout(2.0, queue: Queue.mainQueue(), alternate: Signal { subscriber in
                                subscriber.putNext(true)
                                subscriber.putCompletion()
                                return EmptyDisposable
                            })
                        } else {
                            audioSessionControl.activate({ [weak self] _ in
                                Queue.mainQueue().async {
                                    guard let self else {
                                        return
                                    }
                                    self.audioSessionActive.set(.single(true))
                                }
                            })
                        }
                    } else {
                        self.audioSessionActive.set(.single(false))
                    }
                } else {
                    self.audioSessionActive.set(.single(false))
                }
            })
            
            if self.sharedAudioContext == nil {
                self.audioSessionActiveDisposable = (self.audioSessionActive.get()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    if let self {
                        self.updateIsAudioSessionActive(value)
                    }
                })
                
                self.audioOutputStateDisposable = (self.audioOutputStatePromise.get()
                |> deliverOnMainQueue).start(next: { [weak self] availableOutputs, currentOutput in
                    guard let self else {
                        return
                    }
                    self.updateAudioOutputs(availableOutputs: availableOutputs, currentOutput: currentOutput)
                })
            }
        }
        
        self.groupCallParticipantUpdatesDisposable = (self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let self else {
                return
            }
            if case let .established(callInfo, _, _, _, _) = self.internalState {
                var removedSsrc: [UInt32] = []
                for (callId, update) in updates {
                    if callId == callInfo.id {
                        switch update {
                        case let .state(update):
                            for participantUpdate in update.participantUpdates {
                                if case .left = participantUpdate.participationStatusChange {
                                    if let ssrc = participantUpdate.ssrc {
                                        removedSsrc.append(ssrc)
                                    }
                                    
                                    if participantUpdate.peerId == self.joinAsPeerId {
                                        if case let .established(_, _, _, ssrc, _) = self.internalState, ssrc == participantUpdate.ssrc {
                                            self.markAsCanBeRemoved()
                                        }
                                    } else {
                                        self.e2eContext?.synchronizeRemovedParticipants()
                                    }
                                } else if participantUpdate.peerId == self.joinAsPeerId {
                                    if case let .established(_, connectionMode, _, ssrc, _) = self.internalState {
                                        if ssrc != participantUpdate.ssrc {
                                            self.markAsCanBeRemoved()
                                        } else if case .broadcast = connectionMode {
                                            let canUnmute: Bool
                                            if let muteState = participantUpdate.muteState {
                                                canUnmute = muteState.canUnmute
                                            } else {
                                                canUnmute = true
                                            }
                                            
                                            if canUnmute {
                                                self.requestCall(movingFromBroadcastToRtc: true)
                                            }
                                        }
                                    }
                                }
                            }
                        case let .call(isTerminated, _, _, _, _, _, _):
                            if isTerminated {
                                self.markAsCanBeRemoved()
                            }
                        case let .conferenceChainBlocks(subChainId, blocks, nextOffset):
                            if let e2eContext = self.e2eContext {
                                e2eContext.addChainBlocksUpdate(subChainId: subChainId, blocks: blocks, nextOffset: nextOffset)
                            }
                        }
                    }
                }
                if !removedSsrc.isEmpty {
                    if case let .call(callContext) = self.genericCallContext {
                        callContext.removeSsrcs(ssrcs: removedSsrc)
                    }
                }
            }
        })
        
        self.summaryStatePromise.set(combineLatest(queue: .mainQueue(),
            self.summaryInfoState.get(),
            self.summaryParticipantsState.get(),
            self.statePromise.get()
        )
        |> map { infoState, participantsState, callState -> PresentationGroupCallSummaryState? in
            guard let participantsState = participantsState else {
                return nil
            }
            return PresentationGroupCallSummaryState(
                info: infoState?.info,
                participantCount: participantsState.participantCount,
                callState: callState,
                topParticipants: participantsState.topParticipants,
                activeSpeakers: participantsState.activeSpeakers
            )
        })
        
        if let initialCall = initialCall, let peerId, let temporaryParticipantsContext = (self.accountContext.cachedGroupCallContexts as? AccountGroupCallContextCacheImpl)?.impl.syncWith({ impl in
            impl.get(account: accountContext.account, engine: accountContext.engine, peerId: peerId, isChannel: isChannel, call: EngineGroupCallDescription(id: initialCall.description.id, accessHash: initialCall.description.accessHash, title: initialCall.description.title, scheduleTimestamp: initialCall.description.scheduleTimestamp, subscribedToScheduled: initialCall.description.subscribedToScheduled, isStream: initialCall.description.isStream))
        }) {
            self.switchToTemporaryParticipantsContext(sourceContext: temporaryParticipantsContext.context.participantsContext, oldMyPeerId: self.joinAsPeerId)
        } else {
            self.switchToTemporaryParticipantsContext(sourceContext: nil, oldMyPeerId: self.joinAsPeerId)
        }
        
        self.removedChannelMembersDisposable = (accountContext.peerChannelMemberCategoriesContextsManager.removedChannelMembers
        |> deliverOnMainQueue).start(next: { [weak self] pairs in
            guard let self else {
                return
            }
            for (channelId, memberId) in pairs {
                if channelId == self.peerId {
                    self.removedPeer(memberId)
                }
            }
        })
        
        if let peerId {
            let _ = (self.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self else {
                    return
                }
                var canManageCall = false
                if let peer = peer as? TelegramGroup {
                    if case .creator = peer.role {
                        canManageCall = true
                    } else if case let .admin(rights, _) = peer.role, rights.rights.contains(.canManageCalls) {
                        canManageCall = true
                    }
                } else if let peer = peer as? TelegramChannel {
                    if peer.flags.contains(.isCreator) {
                        canManageCall = true
                    } else if (peer.adminRights?.rights.contains(.canManageCalls) == true) {
                        canManageCall = true
                    }
                    self.peerUpdatesSubscription = self.accountContext.account.viewTracker.polledChannel(peerId: peer.id).start()
                }
                var updatedValue = self.stateValue
                updatedValue.canManageCall = canManageCall
                self.stateValue = updatedValue
            })
        }
        
        if let _ = self.initialCall {
            self.requestCall(movingFromBroadcastToRtc: false)
        }

        var useIPCContext = false
        if let data = self.accountContext.currentAppConfiguration.with({ $0 }).data, let value = data["ios_use_inprocess_screencast"] as? Double {
            useIPCContext = value != 0.0
        }
        
        let embeddedBroadcastImplementationTypePath = self.accountContext.sharedContext.basePath + "/broadcast-coordination-type-v2"
        
        let screencastIPCContext: ScreencastIPCContext
        if useIPCContext {
            screencastIPCContext = ScreencastEmbeddedIPCContext(basePath: self.accountContext.sharedContext.basePath)
            let _ = try? "ipc".write(toFile: embeddedBroadcastImplementationTypePath, atomically: true, encoding: .utf8)
        } else {
            screencastIPCContext = ScreencastInProcessIPCContext(basePath: self.accountContext.sharedContext.basePath, isConference: self.isConference, e2eContext: self.e2eContext)
            let _ = try? "legacy".write(toFile: embeddedBroadcastImplementationTypePath, atomically: true, encoding: .utf8)
        }
        self.screencastIPCContext = screencastIPCContext
        
        self.screencastStateDisposable = (screencastIPCContext.isActive
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] isActive in
            guard let self else {
                return
            }
            if isActive {
                self.requestScreencast()
            } else {
                self.disableScreencast()
            }
        })

        /*Queue.mainQueue().after(2.0, { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.screencastBufferClientContext = IpcGroupCallBufferBroadcastContext(basePath: basePath)
        })*/
        
        if beginWithVideo {
            self.requestVideo()
        }
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())

        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.audioSessionActiveDisposable?.dispose()
        self.summaryStateDisposable?.dispose()
        self.audioSessionDisposable?.dispose()
        self.joinDisposable.dispose()
        self.screencastJoinDisposable.dispose()
        self.requestDisposable.dispose()
        self.startDisposable.dispose()
        self.groupCallParticipantUpdatesDisposable?.dispose()
        self.leaveDisposable.dispose()
        self.isMutedDisposable.dispose()
        self.isNoiseSuppressionEnabledDisposable.dispose()
        self.isVideoMutedDisposable.dispose()
        self.memberStatesDisposable.dispose()
        self.networkStateDisposable.dispose()
        self.checkCallDisposable?.dispose()
        self.audioLevelsDisposable.dispose()
        self.participantsContextStateDisposable.dispose()
        self.myAudioLevelDisposable.dispose()
        self.memberEventsPipeDisposable.dispose()
        self.hasActiveIncomingDataDisposable?.dispose()
        self.hasActiveIncomingDataTimer?.invalidate()
        
        self.myAudioLevelTimer?.invalidate()
        self.typingDisposable.dispose()
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
        
        self.audioOutputStateDisposable?.dispose()
        self.removedChannelMembersDisposable?.dispose()
        self.peerUpdatesSubscription?.dispose()
        self.screencastStateDisposable?.dispose()
        self.pendingDisconnedUpgradedConferenceCallTimer?.invalidate()
    }
    
    private func switchToTemporaryParticipantsContext(sourceContext: GroupCallParticipantsContext?, oldMyPeerId: PeerId) {
        let myPeerId = self.joinAsPeerId
        let accountContext = self.accountContext
        let myPeerData = self.accountContext.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: myPeerId),
            TelegramEngine.EngineData.Item.Peer.AboutText(id: myPeerId)
        )
        |> map { peer, aboutText -> (EnginePeer, String?)? in
            guard let peer = peer else {
                return nil
            }
            switch aboutText {
            case let .known(value):
                return (peer, value)
            case .unknown:
                let _ = accountContext.engine.peers.fetchAndUpdateCachedPeerData(peerId: myPeerId).start()
                
                return (peer, nil)
            }
        }
        
        if let sourceContext = sourceContext, let initialState = sourceContext.immediateState {
            let temporaryParticipantsContext = self.accountContext.engine.calls.groupCall(peerId: self.peerId, myPeerId: myPeerId, id: sourceContext.id, reference: sourceContext.reference, state: initialState, previousServiceState: sourceContext.serviceState, e2eContext: self.e2eContext)
            self.temporaryParticipantsContext = temporaryParticipantsContext
            self.participantsContextStateDisposable.set((combineLatest(queue: .mainQueue(),
                myPeerData,
                temporaryParticipantsContext.state,
                temporaryParticipantsContext.activeSpeakers
            )
            |> take(1)).start(next: { [weak self] myPeerData, state, activeSpeakers in
                guard let self else {
                    return
                }
                
                var topParticipants: [GroupCallParticipantsContext.Participant] = []

                var members = PresentationGroupCallMembers(
                    participants: [],
                    speakingParticipants: [],
                    totalCount: 0,
                    loadMoreToken: nil
                )

                var updatedInvitedPeers = self.invitedPeersValue
                var didUpdateInvitedPeers = false

                var participants = state.participants

                if oldMyPeerId != myPeerId {
                    for i in 0 ..< participants.count {
                        if participants[i].id == .peer(oldMyPeerId) {
                            participants.remove(at: i)
                            break
                        }
                    }
                }

                if !participants.contains(where: { $0.id == .peer(myPeerId) }) {
                    if let (myPeer, aboutText) = myPeerData {
                        let about: String?
                        if let aboutText = aboutText {
                            about = aboutText
                        } else {
                            about = " "
                        }
                        participants.append(GroupCallParticipantsContext.Participant(
                            id: .peer(myPeer.id),
                            peer: myPeer,
                            ssrc: nil,
                            videoDescription: nil,
                            presentationDescription: nil,
                            joinTimestamp: self.temporaryJoinTimestamp,
                            raiseHandRating: self.temporaryRaiseHandRating,
                            hasRaiseHand: self.temporaryHasRaiseHand,
                            activityTimestamp: self.temporaryActivityTimestamp,
                            activityRank: self.temporaryActivityRank,
                            muteState: self.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                            volume: nil,
                            about: about,
                            joinedVideo: self.temporaryJoinedVideo
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                    }
                }

                for participant in participants {
                    members.participants.append(participant)

                    if topParticipants.count < 3 {
                        topParticipants.append(participant)
                    }

                    if let index = updatedInvitedPeers.firstIndex(where: { participant.id == .peer($0.id) }) {
                        updatedInvitedPeers.remove(at: index)
                        didUpdateInvitedPeers = true
                    }
                }

                members.totalCount = state.totalCount
                members.loadMoreToken = state.nextParticipantsFetchOffset

                self.membersValue = members

                var stateValue = self.stateValue
                stateValue.myPeerId = self.joinAsPeerId
                stateValue.adminIds = state.adminIds

                self.stateValue = stateValue

                self.summaryParticipantsState.set(.single(SummaryParticipantsState(
                    participantCount: state.totalCount,
                    topParticipants: topParticipants,
                    activeSpeakers: activeSpeakers
                )))

                if didUpdateInvitedPeers {
                    self.invitedPeersValue = updatedInvitedPeers
                }
            }))
        } else {
            self.temporaryParticipantsContext = nil
            self.participantsContextStateDisposable.set((myPeerData
            |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] myPeerData in
                guard let self else {
                    return
                }

                var topParticipants: [GroupCallParticipantsContext.Participant] = []

                var members = PresentationGroupCallMembers(
                    participants: [],
                    speakingParticipants: [],
                    totalCount: 0,
                    loadMoreToken: nil
                )

                var participants: [GroupCallParticipantsContext.Participant] = []

                if let (myPeer, aboutText) = myPeerData {
                    let about: String?
                    if let aboutText = aboutText {
                        about = aboutText
                    } else {
                        about = " "
                    }
                    participants.append(GroupCallParticipantsContext.Participant(
                        id: .peer(myPeer.id),
                        peer: myPeer,
                        ssrc: nil,
                        videoDescription: nil,
                        presentationDescription: nil,
                        joinTimestamp: self.temporaryJoinTimestamp,
                        raiseHandRating: self.temporaryRaiseHandRating,
                        hasRaiseHand: self.temporaryHasRaiseHand,
                        activityTimestamp: self.temporaryActivityTimestamp,
                        activityRank: self.temporaryActivityRank,
                        muteState: self.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                        volume: nil,
                        about: about,
                        joinedVideo: self.temporaryJoinedVideo
                    ))
                }

                for participant in participants {
                    members.participants.append(participant)

                    if topParticipants.count < 3 {
                        topParticipants.append(participant)
                    }
                }

                self.membersValue = members

                var stateValue = self.stateValue
                stateValue.myPeerId = self.joinAsPeerId

                self.stateValue = stateValue
            }))
        }
    }
    
    private func switchToTemporaryScheduledParticipantsContext() {
        guard let callInfo = self.internalState.callInfo, callInfo.scheduleTimestamp != nil else {
            return
        }
        let accountContext = self.accountContext
        let peerId = self.peerId
        let rawAdminIds: Signal<Set<PeerId>, NoError>
        if let peerId {
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                rawAdminIds = Signal { subscriber in
                    let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(engine: accountContext.engine, postbox: accountContext.account.postbox, network: accountContext.account.network, accountPeerId: accountContext.account.peerId, peerId: peerId, updated: { list in
                        var peerIds = Set<PeerId>()
                        for item in list.list {
                            if let adminInfo = item.participant.adminInfo, adminInfo.rights.rights.contains(.canManageCalls) {
                                peerIds.insert(item.peer.id)
                            }
                        }
                        subscriber.putNext(peerIds)
                    })
                    return disposable
                }
                |> distinctUntilChanged
                |> runOn(.mainQueue())
            } else {
                rawAdminIds = accountContext.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.LegacyGroupParticipants(id: peerId)
                )
                |> map { participants -> Set<PeerId> in
                    guard case let .known(participants) = participants else {
                        return Set()
                    }
                    return Set(participants.compactMap { item -> PeerId? in
                        switch item {
                        case .creator, .admin:
                            return item.peerId
                        default:
                            return nil
                        }
                    })
                }
                |> distinctUntilChanged
            }
        } else {
            rawAdminIds = .single(Set())
        }
        
        let peer: Signal<EnginePeer?, NoError>
        if let peerId {
            peer = accountContext.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        } else {
            peer = .single(nil)
        }
        let adminIds = combineLatest(queue: .mainQueue(),
            rawAdminIds,
            peer
        )
        |> map { rawAdminIds, peer -> Set<PeerId> in
            var rawAdminIds = rawAdminIds
            if let peer, case let .channel(peer) = peer {
                if peer.hasPermission(.manageCalls) {
                    rawAdminIds.insert(accountContext.account.peerId)
                } else {
                    rawAdminIds.remove(accountContext.account.peerId)
                }
            }
            return rawAdminIds
        }
        |> distinctUntilChanged

        let participantsContext = self.accountContext.engine.calls.groupCall(
            peerId: self.peerId,
            myPeerId: self.joinAsPeerId,
            id: callInfo.id,
            reference: .id(id: callInfo.id, accessHash: callInfo.accessHash),
            state: GroupCallParticipantsContext.State(
                participants: [],
                nextParticipantsFetchOffset: nil,
                adminIds: Set(),
                isCreator: false,
                defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: self.stateValue.defaultParticipantMuteState == .muted, canChange: true),
                sortAscending: true,
                recordingStartTimestamp: nil,
                title: self.stateValue.title,
                scheduleTimestamp: self.stateValue.scheduleTimestamp,
                subscribedToScheduled: self.stateValue.subscribedToScheduled,
                totalCount: 0,
                isVideoEnabled: callInfo.isVideoEnabled,
                unmutedVideoLimit: callInfo.unmutedVideoLimit,
                isStream: callInfo.isStream,
                version: 0
            ),
            previousServiceState: nil,
            e2eContext: self.e2eContext
        )
        self.temporaryParticipantsContext = nil
        self.participantsContext = participantsContext
        
        let myPeerId = self.joinAsPeerId
        let myPeerData = self.accountContext.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: myPeerId),
            TelegramEngine.EngineData.Item.Peer.AboutText(id: myPeerId)
        )
        |> map { peer, aboutText -> (EnginePeer, String?)? in
            guard let peer = peer else {
                return nil
            }
            switch aboutText {
            case let .known(value):
                return (peer, value)
            case .unknown:
                let _ = accountContext.engine.peers.fetchAndUpdateCachedPeerData(peerId: myPeerId).start()
                
                return (peer, nil)
            }
        }
        
        let peerView: Signal<PeerView?, NoError>
        if let peerId {
            peerView = accountContext.account.postbox.peerView(id: peerId) |> map(Optional.init)
        } else {
            peerView = .single(nil)
        }
        self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
            participantsContext.state,
            adminIds,
            myPeerData,
            peerView
        ).start(next: { [weak self] state, adminIds, myPeerData, view in
            guard let self else {
                return
            }
            
            var members = PresentationGroupCallMembers(
                participants: [],
                speakingParticipants: Set(),
                totalCount: state.totalCount,
                loadMoreToken: state.nextParticipantsFetchOffset
            )
            
            self.stateValue.adminIds = adminIds
            let canManageCall = state.isCreator || self.stateValue.adminIds.contains(self.accountContext.account.peerId)
            
            var participants: [GroupCallParticipantsContext.Participant] = []
            var topParticipants: [GroupCallParticipantsContext.Participant] = []
            if let (myPeer, aboutText) = myPeerData {
                let about: String?
                if let aboutText = aboutText {
                    about = aboutText
                } else {
                    about = " "
                }
                participants.append(GroupCallParticipantsContext.Participant(
                    id: .peer(myPeer.id),
                    peer: myPeer,
                    ssrc: nil,
                    videoDescription: nil,
                    presentationDescription: nil,
                    joinTimestamp: self.temporaryJoinTimestamp,
                    raiseHandRating: self.temporaryRaiseHandRating,
                    hasRaiseHand: self.temporaryHasRaiseHand,
                    activityTimestamp: self.temporaryActivityTimestamp,
                    activityRank: self.temporaryActivityRank,
                    muteState: self.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: canManageCall || !state.defaultParticipantsAreMuted.isMuted, mutedByYou: false),
                    volume: nil,
                    about: about,
                    joinedVideo: self.temporaryJoinedVideo
                ))
            }

            for participant in participants {
                members.participants.append(participant)

                if topParticipants.count < 3 {
                    topParticipants.append(participant)
                }
            }
            
            self.membersValue = members
            self.stateValue.canManageCall = state.isCreator || adminIds.contains(self.accountContext.account.peerId)
            self.stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
            
            
            self.stateValue.recordingStartTimestamp = state.recordingStartTimestamp
            self.stateValue.title = state.title
            self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canManageCall || !state.defaultParticipantsAreMuted.isMuted, mutedByYou: false)
        
            self.stateValue.subscribedToScheduled = state.subscribedToScheduled
            self.stateValue.scheduleTimestamp = self.isScheduledStarted ? nil : state.scheduleTimestamp
            if state.scheduleTimestamp == nil && !self.isScheduledStarted {
                self.updateSessionState(internalState: .active(GroupCallInfo(
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    participantCount: state.totalCount,
                    streamDcId: callInfo.streamDcId,
                    title: state.title,
                    scheduleTimestamp: nil,
                    subscribedToScheduled: false,
                    recordingStartTimestamp: nil,
                    sortAscending: true,
                    defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? state.defaultParticipantsAreMuted,
                    isVideoEnabled: callInfo.isVideoEnabled,
                    unmutedVideoLimit: callInfo.unmutedVideoLimit,
                    isStream: callInfo.isStream,
                    isCreator: callInfo.isCreator
                )), audioSessionControl: self.audioSessionControl)
            } else {
                self.summaryInfoState.set(.single(SummaryInfoState(info: GroupCallInfo(
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    participantCount: state.totalCount,
                    streamDcId: nil,
                    title: state.title,
                    scheduleTimestamp: state.scheduleTimestamp,
                    subscribedToScheduled: false,
                    recordingStartTimestamp: state.recordingStartTimestamp,
                    sortAscending: state.sortAscending,
                    defaultParticipantsAreMuted: state.defaultParticipantsAreMuted,
                    isVideoEnabled: state.isVideoEnabled,
                    unmutedVideoLimit: state.unmutedVideoLimit,
                    isStream: callInfo.isStream,
                    isCreator: callInfo.isCreator
                ))))
                
                self.summaryParticipantsState.set(.single(SummaryParticipantsState(
                    participantCount: state.totalCount,
                    topParticipants: topParticipants,
                    activeSpeakers: Set()
                )))
            }
        }))
    }
    
    private func updateSessionState(internalState: InternalState, audioSessionControl: ManagedAudioSessionControl?) {
        let previousControl = self.audioSessionControl
        self.audioSessionControl = audioSessionControl
        
        let previousInternalState = self.internalState
        self.internalState = internalState
        self.internalStatePromise.set(.single(internalState))
        
        if self.sharedAudioContext == nil, !self.accountContext.sharedContext.immediateExperimentalUISettings.liveStreamV2, let audioSessionControl = audioSessionControl, previousControl == nil {
            if self.isStream {
                audioSessionControl.setOutputMode(.system)
            } else {
                switch self.currentSelectedAudioOutputValue {
                case .speaker:
                    audioSessionControl.setOutputMode(.custom(self.currentSelectedAudioOutputValue))
                default:
                    break
                }
            }
            audioSessionControl.setup(synchronous: false)
        }
        
        self.audioSessionShouldBeActive.set(true)
        
        switch previousInternalState {
        case .requesting:
            break
        default:
            if case .requesting = internalState {
                self.isCurrentlyConnecting = nil
            }
        }
        
        var shouldJoin = false
        let activeCallInfo: GroupCallInfo?
        switch previousInternalState {
            case let .active(previousCallInfo):
                if case let .active(callInfo) = internalState {
                    shouldJoin = previousCallInfo.scheduleTimestamp != nil && callInfo.scheduleTimestamp == nil
                    self.participantsContext = nil
                    activeCallInfo = callInfo
                } else {
                    activeCallInfo = nil
                }
            default:
                if case let .active(callInfo) = internalState {
                    shouldJoin = callInfo.scheduleTimestamp == nil
                    activeCallInfo = callInfo
                } else {
                    activeCallInfo = nil
                }
        }
        if self.leaving {
            shouldJoin = false
        }
        
        if shouldJoin, let callInfo = activeCallInfo {
            let genericCallContext: CurrentImpl
            if let current = self.genericCallContext {
                genericCallContext = current
            } else {
                if self.isStream, self.accountContext.sharedContext.immediateExperimentalUISettings.liveStreamV2 {
                    let externalMediaStream = DirectMediaStreamingContext(id: self.internalId, rejoinNeeded: { [weak self] in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            if self.leaving {
                                return
                            }
                            if case .established = self.internalState {
                                self.requestCall(movingFromBroadcastToRtc: false)
                            }
                        }
                    })
                    genericCallContext = .externalMediaStream(externalMediaStream)
                    self.externalMediaStream.set(.single(externalMediaStream))
                } else {
                    var outgoingAudioBitrateKbit: Int32?
                    let appConfiguration = self.accountContext.currentAppConfiguration.with({ $0 })
                    if let data = appConfiguration.data, let value = data["voice_chat_send_bitrate"] as? Double {
                        outgoingAudioBitrateKbit = Int32(value)
                    }
                    
                    let contextAudioSessionActive: Signal<Bool, NoError>
                    if self.sharedAudioContext != nil {
                        contextAudioSessionActive = .single(true)
                    } else {
                        contextAudioSessionActive = self.audioSessionActive.get()
                    }
                    
                    var audioIsActiveByDefault = true
                    if self.isConference && self.conferenceSourceId != nil {
                        audioIsActiveByDefault = false
                    }
                    
                    var encryptionContext: OngoingGroupCallEncryptionContext?
                    if let e2eContext = self.e2eContext {
                        encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: e2eContext.state, channelId: 0)
                    } else if self.isConference {
                        // Prevent non-encrypted conference calls
                        encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: Atomic(value: ConferenceCallE2EContext.ContextStateHolder()), channelId: 0)
                    }
                    
                    var prioritizeVP8 = false
                    #if DEBUG && false
                    prioritizeVP8 = "".isEmpty
                    #endif
                    if let data = self.accountContext.currentAppConfiguration.with({ $0 }).data, let value = data["ios_calls_prioritize_vp8"] as? Double {
                        prioritizeVP8 = value != 0.0
                    }

                    genericCallContext = .call(OngoingGroupCallContext(audioSessionActive: contextAudioSessionActive, video: self.videoCapturer, requestMediaChannelDescriptions: { [weak self] ssrcs, completion in
                        let disposable = MetaDisposable()
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            disposable.set(self.requestMediaChannelDescriptions(ssrcs: ssrcs, completion: completion))
                        }
                        return disposable
                    }, rejoinNeeded: { [weak self] in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            if case .established = self.internalState {
                                self.requestCall(movingFromBroadcastToRtc: false)
                            }
                        }
                    }, outgoingAudioBitrateKbit: outgoingAudioBitrateKbit, videoContentType: self.isVideoEnabled ? .generic : .none, enableNoiseSuppression: false, disableAudioInput: self.isStream, enableSystemMute: self.accountContext.sharedContext.immediateExperimentalUISettings.experimentalCallMute, prioritizeVP8: prioritizeVP8, logPath: allocateCallLogPath(account: self.account), onMutedSpeechActivityDetected: { [weak self] value in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            self.onMutedSpeechActivityDetected?(value)
                        }
                    }, isConference: self.isConference, audioIsActiveByDefault: audioIsActiveByDefault, isStream: self.isStream, sharedAudioDevice: self.sharedAudioContext?.audioDevice, encryptionContext: encryptionContext))
                    
                    let isEffectivelyMuted: Bool
                    switch self.isMutedValue {
                    case let .muted(isPushToTalkActive):
                        isEffectivelyMuted = !isPushToTalkActive
                    case .unmuted:
                        isEffectivelyMuted = false
                    }
                    genericCallContext.setIsMuted(isEffectivelyMuted)
                }

                self.genericCallContext = genericCallContext
                self.stateVersionValue += 1
                
                let isEffectivelyMuted: Bool
                switch self.isMutedValue {
                case let .muted(isPushToTalkActive):
                    isEffectivelyMuted = !isPushToTalkActive
                case .unmuted:
                    isEffectivelyMuted = false
                }
                genericCallContext.setIsMuted(isEffectivelyMuted)
                
                genericCallContext.setRequestedVideoChannels(self.suspendVideoChannelRequests ? [] : self.requestedVideoChannels)
                self.connectPendingVideoSubscribers()
                
                if let videoCapturer = self.videoCapturer {
                    genericCallContext.requestVideo(videoCapturer)
                }
                
                if case let .call(callContext) = genericCallContext {
                    var lastTimestamp: Double?
                    self.hasActiveIncomingDataDisposable?.dispose()
                    self.hasActiveIncomingDataDisposable = (callContext.ssrcActivities
                    |> filter { !$0.isEmpty }
                    |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        lastTimestamp = CFAbsoluteTimeGetCurrent()
                        self.hasActiveIncomingDataValue = true
                        
                        self.activateIncomingAudioIfNeeded()
                    })
                    
                    self.hasActiveIncomingDataTimer?.invalidate()
                    self.hasActiveIncomingDataTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        let timestamp = CFAbsoluteTimeGetCurrent()
                        if let lastTimestamp {
                            if lastTimestamp + 1.0 < timestamp {
                                self.hasActiveIncomingDataValue = false
                            }
                        }
                    })
                    
                    self.signalBarsPromise.set(callContext.signalBars)
                }
            }
            
            self.joinDisposable.set((genericCallContext.joinPayload
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                return true
            })
            |> deliverOnMainQueue).start(next: { [weak self] joinPayload, ssrc in
                guard let self else {
                    return
                }

                let peerAdminIds: Signal<[PeerId], NoError>
                let peerId = self.peerId
                if let peerId {
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        peerAdminIds = Signal { [weak self] subscriber in
                            guard let self else {
                                subscriber.putNext([])
                                subscriber.putCompletion()
                                return EmptyDisposable
                            }
                            
                            let (disposable, _) = self.accountContext.peerChannelMemberCategoriesContextsManager.admins(engine: self.accountContext.engine, postbox: self.accountContext.account.postbox, network: self.accountContext.account.network, accountPeerId: self.accountContext.account.peerId, peerId: peerId, updated: { list in
                                var peerIds = Set<PeerId>()
                                for item in list.list {
                                    if let adminInfo = item.participant.adminInfo, adminInfo.rights.rights.contains(.canManageCalls) {
                                        peerIds.insert(item.peer.id)
                                    }
                                }
                                subscriber.putNext(Array(peerIds))
                            })
                            return disposable
                        }
                        |> distinctUntilChanged
                        |> runOn(.mainQueue())
                    } else {
                        peerAdminIds = self.accountContext.engine.data.get(
                            TelegramEngine.EngineData.Item.Peer.LegacyGroupParticipants(id: peerId)
                        )
                        |> map { participants -> [EnginePeer.Id] in
                            guard case let .known(participants) = participants else {
                                return []
                            }
                            var result: [EnginePeer.Id] = []
                            for participant in participants {
                                if case .creator = participant {
                                    result.append(participant.peerId)
                                } else if case .admin = participant {
                                    result.append(participant.peerId)
                                }
                            }
                            return result
                        }
                    }
                } else {
                    peerAdminIds = .single([])
                }
                
                var generateE2EData: ((Data?) -> JoinGroupCallE2E?)?
                if let keyPair = self.keyPair {
                    if let mappedKeyPair = TdKeyPair(keyId: keyPair.id, publicKey: keyPair.publicKey.data) {
                        let userId = self.joinAsPeerId.id._internalGetInt64Value()
                        generateE2EData = { block -> JoinGroupCallE2E? in
                            if let block {
                                guard let resultBlock = tdGenerateSelfAddBlock(mappedKeyPair, userId, block) else {
                                    return nil
                                }
                                return JoinGroupCallE2E(
                                    publicKey: keyPair.publicKey,
                                    block: resultBlock
                                )
                            } else {
                                guard let resultBlock = tdGenerateZeroBlock(mappedKeyPair, userId) else {
                                    return nil
                                }
                                return JoinGroupCallE2E(
                                    publicKey: keyPair.publicKey,
                                    block: resultBlock
                                )
                            }
                        }
                    }
                }
                
                let reference: InternalGroupCallReference
                if let initialCall = self.initialCall {
                    reference = initialCall.reference
                } else {
                    reference = .id(id: callInfo.id, accessHash: callInfo.accessHash)
                }
                
                let isEffectivelyMuted: Bool
                switch self.isMutedValue {
                case let .muted(isPushToTalkActive):
                    isEffectivelyMuted = !isPushToTalkActive
                case .unmuted:
                    isEffectivelyMuted = false
                }

                self.currentLocalSsrc = ssrc
                self.requestDisposable.set((self.accountContext.engine.calls.joinGroupCall(
                    peerId: self.peerId,
                    joinAs: self.joinAsPeerId,
                    callId: callInfo.id,
                    reference: reference,
                    preferMuted: isEffectivelyMuted,
                    joinPayload: joinPayload,
                    peerAdminIds: peerAdminIds,
                    inviteHash: self.invite,
                    generateE2E: generateE2EData
                )
                |> deliverOnMainQueue).start(next: { [weak self] joinCallResult in
                    guard let self else {
                        return
                    }
                    
                    self.currentReference = .id(id: joinCallResult.callInfo.id, accessHash: joinCallResult.callInfo.accessHash)
                    
                    let clientParams = joinCallResult.jsonParams
                    if let data = clientParams.data(using: .utf8), let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
                        if let video = dict["video"] as? [String: Any] {
                            if let endpointId = video["endpoint"] as? String {
                                self.currentLocalEndpointId = endpointId
                            }
                        }
                    }

                    self.ssrcMapping.removeAll()
                    for participant in joinCallResult.state.participants {
                        if let ssrc = participant.ssrc, let participantPeer = participant.peer {
                            self.ssrcMapping[ssrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: false)
                        }
                        if let presentationSsrc = participant.presentationDescription?.audioSsrc, let participantPeer = participant.peer {
                            self.ssrcMapping[presentationSsrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: true)
                        }
                    }

                    if let genericCallContext = self.genericCallContext {
                        switch genericCallContext {
                        case let .call(callContext):
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                self.currentConnectionMode = .rtc
                                callContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
                                callContext.setJoinResponse(payload: clientParams)
                            case .broadcast:
                                self.currentConnectionMode = .broadcast
                                callContext.setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData(engine: self.accountContext.engine, callId: callInfo.id, accessHash: callInfo.accessHash, isExternalStream: callInfo.isStream))
                                callContext.setConnectionMode(.broadcast, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: callInfo.isStream)
                            }
                        case let .mediaStream(mediaStreamContext):
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                self.currentConnectionMode = .rtc
                            case .broadcast:
                                self.currentConnectionMode = .broadcast
                                mediaStreamContext.setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData(engine: self.accountContext.engine, callId: callInfo.id, accessHash: callInfo.accessHash, isExternalStream: callInfo.isStream))
                            }
                        case let .externalMediaStream(externalMediaStream):
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                self.currentConnectionMode = .rtc
                            case .broadcast:
                                self.currentConnectionMode = .broadcast
                                externalMediaStream.setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData(engine: self.accountContext.engine, callId: callInfo.id, accessHash: callInfo.accessHash, isExternalStream: callInfo.isStream))
                            }
                        }
                    }

                    self.updateSessionState(internalState: .established(info: joinCallResult.callInfo, connectionMode: joinCallResult.connectionMode, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state), audioSessionControl: self.audioSessionControl)
                    
                    if let e2eState = joinCallResult.e2eState {
                        self.e2eContext?.begin(initialState: e2eState)
                    } else {
                        self.e2eContext?.begin(initialState: nil)
                    }
                }, error: { [weak self] error in
                    guard let self else {
                        return
                    }
                    if case .anonymousNotAllowed = error {
                        let presentationData = self.accountContext.sharedContext.currentPresentationData.with { $0 }
                        self.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: self.isChannel ? presentationData.strings.LiveStream_AnonymousDisabledAlertText : presentationData.strings.VoiceChat_AnonymousDisabledAlertText, actions: [
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                        ]), on: .root, blockInteraction: false, completion: {})
                    } else if case .tooManyParticipants = error {
                        let presentationData = self.accountContext.sharedContext.currentPresentationData.with { $0 }
                        self.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: self.isChannel ? presentationData.strings.LiveStream_ChatFullAlertText : presentationData.strings.VoiceChat_ChatFullAlertText, actions: [
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                        ]), on: .root, blockInteraction: false, completion: {})
                    } else if case .invalidJoinAsPeer = error {
                        if let peerId = self.peerId {
                            let _ = self.accountContext.engine.calls.clearCachedGroupCallDisplayAsAvailablePeers(peerId: peerId).start()
                        }
                    }
                    self.markAsCanBeRemoved()
                }))
            }))
            
            self.networkStateDisposable.set((genericCallContext.networkState
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                let mappedState: PresentationGroupCallState.NetworkState
                if state.isConnected {
                    mappedState = .connected
                } else {
                    mappedState = .connecting
                }

                let wasConnecting = self.stateValue.networkState == .connecting
                if self.stateValue.networkState != mappedState {
                    self.stateValue.networkState = mappedState
                }
                let isConnecting = mappedState == .connecting
                
                if self.isCurrentlyConnecting != isConnecting {
                    self.isCurrentlyConnecting = isConnecting
                    if isConnecting {
                        self.startCheckingCallIfNeeded()
                    } else {
                        self.checkCallDisposable?.dispose()
                        self.checkCallDisposable = nil
                    }
                }

                self.isReconnectingAsSpeaker = state.isTransitioningFromBroadcastToRtc
                
                if (wasConnecting != isConnecting && self.didConnectOnce) {
                    if isConnecting {
                        self.beginTone(tone: .groupConnecting)
                    } else {
                        self.beginTone(tone: nil)
                    }
                }
                
                if isConnecting {
                    self.didStartConnectingOnce = true
                }
                
                if state.isConnected {
                    if !self.didConnectOnce {
                        self.didConnectOnce = true
                        
                        if !self.isScheduled {
                            self.beginTone(tone: .groupJoined)
                        }
                    }

                    if let peer = self.reconnectingAsPeer {
                        self.reconnectingAsPeer = nil
                        self.reconnectedAsEventsPipe.putNext(peer)
                    }
                }
            }))

            self.isNoiseSuppressionEnabledDisposable.set((genericCallContext.isNoiseSuppressionEnabled
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                self.isNoiseSuppressionEnabledPromise.set(value)
            }))
            
            self.audioLevelsDisposable.set((genericCallContext.audioLevels
            |> deliverOnMainQueue).start(next: { [weak self] levels in
                guard let self else {
                    return
                }
                var result: [(PeerId, UInt32, Float, Bool)] = []
                var myLevel: Float = 0.0
                var myLevelHasVoice: Bool = false
                var orignalMyLevelHasVoice: Bool = false
                var missingSsrcs = Set<UInt32>()
                for (ssrcKey, level, hasVoice) in levels {
                    var peerId: PeerId?
                    let ssrcValue: UInt32
                    switch ssrcKey {
                    case .local:
                        peerId = self.joinAsPeerId
                        ssrcValue = 0
                    case let .source(ssrc):
                        if let mapping = self.ssrcMapping[ssrc] {
                            if mapping.isPresentation {
                                peerId = nil
                                ssrcValue = 0
                            } else {
                                peerId = mapping.peerId
                                ssrcValue = ssrc
                            }
                        } else {
                            ssrcValue = ssrc
                        }
                    }
                    if let peerId = peerId {
                        if case .local = ssrcKey {
                            orignalMyLevelHasVoice = hasVoice
                            myLevel = level
                            myLevelHasVoice = hasVoice
                        }
                        result.append((peerId, ssrcValue, level, hasVoice))
                    } else if ssrcValue != 0 {
                        missingSsrcs.insert(ssrcValue)
                    }
                }
                
                self.speakingParticipantsContext.update(levels: result)
                
                let mappedLevel = myLevel * 1.5
                self.myAudioLevelPipe.putNext(mappedLevel)
                self.myAudioLevelAndSpeakingPipe.putNext((mappedLevel, myLevelHasVoice))
                self.processMyAudioLevel(level: mappedLevel, hasVoice: myLevelHasVoice)
                self.isSpeakingPromise.set(orignalMyLevelHasVoice)
                
                if !missingSsrcs.isEmpty && !self.isStream {
                    self.participantsContext?.ensureHaveParticipants(ssrcs: missingSsrcs)
                }
            }))
        }
        
        switch previousInternalState {
        case .established:
            break
        default:
            if case let .established(callInfo, _, _, _, initialState) = internalState {
                self.summaryInfoState.set(.single(SummaryInfoState(info: callInfo)))
                
                self.stateValue.canManageCall = initialState.isCreator || initialState.adminIds.contains(self.accountContext.account.peerId)
                if self.stateValue.canManageCall && initialState.defaultParticipantsAreMuted.canChange {
                    self.stateValue.defaultParticipantMuteState = initialState.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                }
                if self.stateValue.recordingStartTimestamp != initialState.recordingStartTimestamp {
                    self.stateValue.recordingStartTimestamp = initialState.recordingStartTimestamp
                }
                if self.stateValue.title != initialState.title {
                    self.stateValue.title = initialState.title
                }
                if self.stateValue.scheduleTimestamp != initialState.scheduleTimestamp {
                    self.stateValue.scheduleTimestamp = initialState.scheduleTimestamp
                }
                
                let accountContext = self.accountContext
                let peerId = self.peerId
                let rawAdminIds: Signal<Set<PeerId>, NoError>
                if let peerId {
                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                        rawAdminIds = Signal { subscriber in
                            let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(engine: accountContext.engine, postbox: accountContext.account.postbox, network: accountContext.account.network, accountPeerId: accountContext.account.peerId, peerId: peerId, updated: { list in
                                var peerIds = Set<PeerId>()
                                for item in list.list {
                                    if let adminInfo = item.participant.adminInfo, adminInfo.rights.rights.contains(.canManageCalls) {
                                        peerIds.insert(item.peer.id)
                                    }
                                }
                                subscriber.putNext(peerIds)
                            })
                            return disposable
                        }
                        |> distinctUntilChanged
                        |> runOn(.mainQueue())
                    } else {
                        rawAdminIds = accountContext.engine.data.subscribe(
                            TelegramEngine.EngineData.Item.Peer.LegacyGroupParticipants(id: peerId)
                        )
                        |> map { participants -> Set<PeerId> in
                            guard case let .known(participants) = participants else {
                                return Set()
                            }
                            return Set(participants.compactMap { item -> PeerId? in
                                switch item {
                                case .creator, .admin:
                                    return item.peerId
                                default:
                                    return nil
                                }
                            })
                        }
                        |> distinctUntilChanged
                    }
                } else {
                    rawAdminIds = .single(Set())
                }
                
                let peer: Signal<EnginePeer?, NoError>
                if let peerId {
                    peer = accountContext.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                } else {
                    peer = .single(nil)
                }
                
                let adminIds = combineLatest(queue: .mainQueue(),
                    rawAdminIds,
                    peer
                )
                |> map { rawAdminIds, peer -> Set<PeerId> in
                    var rawAdminIds = rawAdminIds
                    if let peer, case let .channel(peer) = peer {
                        if peer.hasPermission(.manageCalls) {
                            rawAdminIds.insert(accountContext.account.peerId)
                        } else {
                            rawAdminIds.remove(accountContext.account.peerId)
                        }
                    }
                    return rawAdminIds
                }
                |> distinctUntilChanged

                let myPeerId = self.joinAsPeerId
                
                var initialState = initialState
                var serviceState: GroupCallParticipantsContext.ServiceState?
                if let participantsContext = self.participantsContext, let immediateState = participantsContext.immediateState {
                    initialState.mergeActivity(from: immediateState, myPeerId: myPeerId, previousMyPeerId: self.ignorePreviousJoinAsPeerId?.0, mergeActivityTimestamps: true)
                    serviceState = participantsContext.serviceState
                }
                
                let reference: InternalGroupCallReference
                if let initialCall = self.initialCall {
                    reference = initialCall.reference
                } else {
                    reference = .id(id: callInfo.id, accessHash: callInfo.accessHash)
                }
                
                let participantsContext = self.accountContext.engine.calls.groupCall(
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    reference: reference,
                    state: initialState,
                    previousServiceState: serviceState,
                    e2eContext: self.e2eContext
                )
                self.temporaryParticipantsContext = nil
                self.participantsContext = participantsContext
                let myPeer = self.accountContext.account.postbox.peerView(id: myPeerId)
                |> map { view -> (Peer, CachedPeerData?)? in
                    if let peer = peerViewMainPeer(view) {
                        return (peer, view.cachedData)
                    } else {
                        return nil
                    }
                }
                |> beforeNext { view in
                    if let view = view, view.1 == nil {
                        let _ = accountContext.engine.peers.fetchAndUpdateCachedPeerData(peerId: myPeerId).start()
                    }
                }
                
                let chatPeer: Signal<Peer?, NoError>
                if let peerId = self.peerId {
                    chatPeer = self.accountContext.account.postbox.peerView(id: peerId)
                    |> map { view -> Peer? in
                        if let peer = peerViewMainPeer(view) {
                            return peer
                        } else {
                            return nil
                        }
                    }
                } else {
                    chatPeer = .single(nil)
                }
                
                let peerView: Signal<PeerView?, NoError>
                if let peerId {
                    peerView = accountContext.account.postbox.peerView(id: peerId) |> map(Optional.init)
                } else {
                    peerView = .single(nil)
                }
                
                self.updateLocalVideoState()
                
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    participantsContext.activeSpeakers,
                    self.speakingParticipantsContext.get(),
                    adminIds,
                    myPeer,
                    chatPeer,
                    peerView,
                    self.isReconnectingAsSpeakerPromise.get()
                ).start(next: { [weak self] state, activeSpeakers, speakingParticipants, adminIds, myPeerAndCachedData, chatPeer, view, isReconnectingAsSpeaker in
                    guard let self else {
                        return
                    }
                    let appConfiguration = self.accountContext.currentAppConfiguration.with({ $0 })
                    let configuration = VoiceChatConfiguration.with(appConfiguration: appConfiguration)
                    
                    self.participantsContext?.updateAdminIds(adminIds)
                    
                    var topParticipants: [GroupCallParticipantsContext.Participant] = []
                    
                    var reportSpeakingParticipants: [PeerId: UInt32] = [:]
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    for (peerId, ssrc) in speakingParticipants {
                        let shouldReport: Bool
                        if let previousTimestamp = self.speakingParticipantsReportTimestamp[peerId] {
                            shouldReport = previousTimestamp + 1.0 < timestamp
                        } else {
                            shouldReport = true
                        }
                        if shouldReport {
                            self.speakingParticipantsReportTimestamp[peerId] = timestamp
                            reportSpeakingParticipants[peerId] = ssrc
                        }
                    }
                    
                    if !reportSpeakingParticipants.isEmpty {
                        Queue.mainQueue().justDispatch { [weak self] in
                            guard let self else {
                                return
                            }
                            self.participantsContext?.reportSpeakingParticipants(ids: reportSpeakingParticipants)
                        }
                    }
                    
                    var members = PresentationGroupCallMembers(
                        participants: [],
                        speakingParticipants: Set(speakingParticipants.keys),
                        totalCount: 0,
                        loadMoreToken: nil
                    )
                    
                    var updatedInvitedPeers = self.invitedPeersValue
                    var didUpdateInvitedPeers = false

                    var participants = state.participants

                    if let (ignorePeerId, ignoreSsrc) = self.ignorePreviousJoinAsPeerId {
                        for i in 0 ..< participants.count {
                            if participants[i].id == .peer(ignorePeerId) && participants[i].ssrc == ignoreSsrc {
                                participants.remove(at: i)
                                break
                            }
                        }
                    }

                    if !participants.contains(where: { $0.id == .peer(myPeerId) }) && !self.leaving {
                        if let (myPeer, cachedData) = myPeerAndCachedData {
                            let about: String?
                            if let cachedData = cachedData as? CachedUserData {
                                about = cachedData.about
                            } else if let cachedData = cachedData as? CachedChannelData {
                                about = cachedData.about
                            } else {
                                about = " "
                            }

                            participants.append(GroupCallParticipantsContext.Participant(
                                id: .peer(myPeer.id),
                                peer: EnginePeer(myPeer),
                                ssrc: nil,
                                videoDescription: nil,
                                presentationDescription: nil,
                                joinTimestamp: self.temporaryJoinTimestamp,
                                raiseHandRating: self.temporaryRaiseHandRating,
                                hasRaiseHand: self.temporaryHasRaiseHand,
                                activityTimestamp: self.temporaryActivityTimestamp,
                                activityRank: self.temporaryActivityRank,
                                muteState: self.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                                volume: nil,
                                about: about,
                                joinedVideo: self.temporaryJoinedVideo
                            ))
                            participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                        }
                    }

                    var otherParticipantsWithVideo = 0
                    var videoWatchingParticipants = 0
                    
                    for participant in participants {
                        var participant = participant
                        
                        if topParticipants.count < 3 {
                            topParticipants.append(participant)
                        }
                        
                        if let ssrc = participant.ssrc {
                            if let participantPeer = participant.peer {
                                self.ssrcMapping[ssrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: false)
                            }
                        }
                        if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                            if let participantPeer = participant.peer {
                                self.ssrcMapping[presentationSsrc] = SsrcMapping(peerId: participantPeer.id, isPresentation: true)
                            }
                        }
                        
                        if participant.id == .peer(self.joinAsPeerId) {
                            if let (myPeer, cachedData) = myPeerAndCachedData {
                                let about: String?
                                if let cachedData = cachedData as? CachedUserData {
                                    about = cachedData.about
                                } else if let cachedData = cachedData as? CachedChannelData {
                                    about = cachedData.about
                                } else {
                                    about = " "
                                }
                                participant.peer = EnginePeer(myPeer)
                                participant.about = about
                            }
                        
                            var filteredMuteState = participant.muteState
                            if isReconnectingAsSpeaker || self.currentConnectionMode != .rtc {
                                filteredMuteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false)
                                participant.muteState = filteredMuteState
                            }

                            let previousRaisedHand = self.stateValue.raisedHand
                            if !(self.stateValue.muteState?.canUnmute ?? false) {
                                self.stateValue.raisedHand = participant.hasRaiseHand
                            }
                            
                            if let muteState = participant.muteState, muteState.canUnmute && previousRaisedHand { 
                                let _ = (self.accountContext.sharedContext.hasGroupCallOnScreen
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] hasGroupCallOnScreen in
                                    guard let self else {
                                        return
                                    }
                                    let presentationData = self.accountContext.sharedContext.currentPresentationData.with { $0 }
                                    if !hasGroupCallOnScreen {
                                        let title: String?
                                        if let voiceChatTitle = self.stateValue.title {
                                            title = voiceChatTitle
                                        } else if let view, let peer = peerViewMainPeer(view) {
                                            title = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        } else {
                                            title = nil
                                        }
                                        
                                        let text: String
                                        if let title = title {
                                            text = presentationData.strings.VoiceChat_YouCanNowSpeakIn(title).string
                                        } else {
                                            text = presentationData.strings.VoiceChat_YouCanNowSpeak
                                        }
                                        self.accountContext.sharedContext.mainWindow?.present(UndoOverlayController(presentationData: presentationData, content: .voiceChatCanSpeak(text: text), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return true }), on: .root, blockInteraction: false, completion: {})
                                        self.playTone(.unmuted)
                                    }
                                })
                            }

                            if let muteState = filteredMuteState {
                                if muteState.canUnmute {
                                    if let currentMuteState = self.stateValue.muteState, !currentMuteState.canUnmute {
                                        self.isMutedValue = .muted(isPushToTalkActive: false)
                                        self.isMutedPromise.set(self.isMutedValue)
                                        self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                                        self.genericCallContext?.setIsMuted(true)
                                    } else {
                                        switch self.isMutedValue {
                                        case .muted:
                                            break
                                        case .unmuted:
                                            let _ = self.updateMuteState(peerId: self.joinAsPeerId, isMuted: false)
                                        }
                                    }
                                } else {
                                    self.isMutedValue = .muted(isPushToTalkActive: false)
                                    self.isMutedPromise.set(self.isMutedValue)
                                    self.genericCallContext?.setIsMuted(true)
                                    self.stateValue.muteState = muteState
                                }
                            } else if let currentMuteState = self.stateValue.muteState, !currentMuteState.canUnmute {
                                self.isMutedValue = .muted(isPushToTalkActive: false)
                                self.isMutedPromise.set(self.isMutedValue)
                                self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                                self.genericCallContext?.setIsMuted(true)
                            }
                            
                            if participant.joinedVideo {
                                videoWatchingParticipants += 1
                            }
                        } else {
                            if let ssrc = participant.ssrc {
                                if let volume = participant.volume {
                                    self.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    self.genericCallContext?.setVolume(ssrc: ssrc, volume: 0.0)
                                }
                            }
                            if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                                if let volume = participant.volume {
                                    self.genericCallContext?.setVolume(ssrc: presentationSsrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    self.genericCallContext?.setVolume(ssrc: presentationSsrc, volume: 0.0)
                                }
                            }

                            if participant.videoDescription != nil || participant.presentationDescription != nil {
                                otherParticipantsWithVideo += 1
                            }
                            if participant.joinedVideo {
                                videoWatchingParticipants += 1
                            }
                        }
                        
                        if let index = updatedInvitedPeers.firstIndex(where: { participant.id == .peer($0.id) }) {
                            updatedInvitedPeers.remove(at: index)
                            didUpdateInvitedPeers = true
                        }

                        members.participants.append(participant)
                    }
                    
                    members.totalCount = state.totalCount
                    members.loadMoreToken = state.nextParticipantsFetchOffset
                    
                    self.membersValue = members
                    
                    self.stateValue.adminIds = adminIds
                    
                    self.stateValue.canManageCall = state.isCreator || adminIds.contains(self.accountContext.account.peerId)
                    if (state.isCreator || self.stateValue.adminIds.contains(self.accountContext.account.peerId)) && state.defaultParticipantsAreMuted.canChange {
                        self.stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                    }
                    self.stateValue.recordingStartTimestamp = state.recordingStartTimestamp
                    self.stateValue.title = state.title
                    self.stateValue.scheduleTimestamp = state.scheduleTimestamp
                    self.stateValue.isVideoEnabled = state.isVideoEnabled && otherParticipantsWithVideo < state.unmutedVideoLimit
                    self.stateValue.isVideoWatchersLimitReached = videoWatchingParticipants >= configuration.videoParticipantsMaxCount
                    
                    self.summaryInfoState.set(.single(SummaryInfoState(info: GroupCallInfo(
                        id: callInfo.id,
                        accessHash: callInfo.accessHash,
                        participantCount: state.totalCount,
                        streamDcId: nil,
                        title: state.title,
                        scheduleTimestamp: state.scheduleTimestamp,
                        subscribedToScheduled: false,
                        recordingStartTimestamp: state.recordingStartTimestamp,
                        sortAscending: state.sortAscending,
                        defaultParticipantsAreMuted: state.defaultParticipantsAreMuted,
                        isVideoEnabled: state.isVideoEnabled,
                        unmutedVideoLimit: state.unmutedVideoLimit,
                        isStream: callInfo.isStream,
                        isCreator: callInfo.isCreator
                    ))))
                    
                    self.summaryParticipantsState.set(.single(SummaryParticipantsState(
                        participantCount: state.totalCount,
                        topParticipants: topParticipants,
                        activeSpeakers: activeSpeakers
                    )))
                    
                    if didUpdateInvitedPeers {
                        self.invitedPeersValue = updatedInvitedPeers
                    }
                }))
                
                let engine = self.accountContext.engine
                self.memberEventsPipeDisposable.set((participantsContext.memberEvents
                |> mapToSignal { event -> Signal<PresentationGroupCallMemberEvent, NoError> in
                    return engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: event.peerId),
                        TelegramEngine.EngineData.Item.Peer.IsContact(id: event.peerId),
                        TelegramEngine.EngineData.Item.Messages.ChatListIndex(id: event.peerId)
                    )
                    |> mapToSignal { peer, isContact, chatListIndex -> Signal<PresentationGroupCallMemberEvent, NoError> in
                        if let peer = peer {
                            let isInChatList = chatListIndex != nil
                            return .single(PresentationGroupCallMemberEvent(peer: peer, isContact: isContact, isInChatList: isInChatList, canUnmute: event.canUnmute, joined: event.joined))
                        } else {
                            return .complete()
                        }
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] event in
                    guard let self, event.peer.id != self.stateValue.myPeerId else {
                        return
                    }
                    var skip = false
                    if let participantsCount = self.participantsContext?.immediateState?.totalCount, participantsCount >= 250 {
                        if event.peer.isVerified || event.isContact || event.isInChatList || (self.stateValue.defaultParticipantMuteState == .muted && event.canUnmute) {
                            skip = false
                        } else {
                            skip = true
                        }
                    }
                    if !skip {
                        self.memberEventsPipe.putNext(event)
                    }
                }))
                
                if let isCurrentlyConnecting = self.isCurrentlyConnecting, isCurrentlyConnecting {
                    self.startCheckingCallIfNeeded()
                }
            } else if case let .active(callInfo) = internalState, callInfo.scheduleTimestamp != nil {
                self.switchToTemporaryScheduledParticipantsContext()
            }
        }
    }
    
    private func activateIncomingAudioIfNeeded() {
        if let genericCallContext = self.genericCallContext, case let .call(groupCall) = genericCallContext {
            groupCall.activateIncomingAudio()
            if let pendingDisconnedUpgradedConferenceCall = self.pendingDisconnedUpgradedConferenceCall {
                pendingDisconnedUpgradedConferenceCall.deactivateIncomingAudio()
            }
        }
    }
    
    private func requestMediaChannelDescriptions(ssrcs: Set<UInt32>, completion: @escaping ([OngoingGroupCallContext.MediaChannelDescription]) -> Void) -> Disposable {
        func extractMediaChannelDescriptions(remainingSsrcs: inout Set<UInt32>, participants: [GroupCallParticipantsContext.Participant], into result: inout [OngoingGroupCallContext.MediaChannelDescription]) {
            for participant in participants {
                guard let audioSsrc = participant.ssrc else {
                    continue
                }

                if remainingSsrcs.contains(audioSsrc) {
                    remainingSsrcs.remove(audioSsrc)

                    if let participantPeer = participant.peer {
                        result.append(OngoingGroupCallContext.MediaChannelDescription(
                            kind: .audio,
                            peerId: participantPeer.id.id._internalGetInt64Value(),
                            audioSsrc: audioSsrc,
                            videoDescription: nil
                        ))
                    }
                }

                if let screencastSsrc = participant.presentationDescription?.audioSsrc {
                    if remainingSsrcs.contains(screencastSsrc) {
                        remainingSsrcs.remove(screencastSsrc)

                        if let participantPeer = participant.peer {
                            result.append(OngoingGroupCallContext.MediaChannelDescription(
                                kind: .audio,
                                peerId: participantPeer.id.id._internalGetInt64Value(),
                                audioSsrc: screencastSsrc,
                                videoDescription: nil
                            ))
                        }
                    }
                }
            }
        }

        var remainingSsrcs = ssrcs
        var result: [OngoingGroupCallContext.MediaChannelDescription] = []

        if let membersValue = self.membersValue {
            extractMediaChannelDescriptions(remainingSsrcs: &remainingSsrcs, participants: membersValue.participants, into: &result)
        }

        if !remainingSsrcs.isEmpty, let callInfo = self.internalState.callInfo {
            return (self.accountContext.engine.calls.getGroupCallParticipants(reference: .id(id: callInfo.id, accessHash: callInfo.accessHash), offset: "", ssrcs: Array(remainingSsrcs), limit: 100, sortAscending: callInfo.sortAscending)
            |> deliverOnMainQueue).start(next: { state in
                extractMediaChannelDescriptions(remainingSsrcs: &remainingSsrcs, participants: state.participants, into: &result)

                completion(result)
            })
        } else {
            completion(result)
            return EmptyDisposable
        }
    }
    
    private func startCheckingCallIfNeeded() {
        if self.checkCallDisposable != nil {
            return
        }
        if case let .established(callInfo, connectionMode, _, ssrc, _) = self.internalState, case .rtc = connectionMode {
            let checkSignal = self.accountContext.engine.calls.checkGroupCall(callId: callInfo.id, accessHash: callInfo.accessHash, ssrcs: [ssrc])
            
            self.checkCallDisposable = ((
                checkSignal
                |> castError(Bool.self)
                |> delay(4.0, queue: .mainQueue())
                |> mapToSignal { result -> Signal<Bool, Bool> in
                    var foundAll = true
                    for value in [ssrc] {
                        if !result.contains(value) {
                            foundAll = false
                            break
                        }
                    }
                    if foundAll {
                        return .fail(true)
                    } else {
                        return .single(true)
                    }
                }
            )
            |> restartIfError
            |> take(1)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let self else {
                    return
                }
                self.checkCallDisposable = nil
                self.requestCall(movingFromBroadcastToRtc: false)
            })
        }
    }
    
    private func updateIsAudioSessionActive(_ value: Bool) {
        if self.isAudioSessionActive != value {
            self.isAudioSessionActive = value
        }
    }

    private func beginTone(tone: PresentationCallTone?) {
        if self.isStream, let tone {
            switch tone {
            case .groupJoined, .groupLeft:
                return
            default:
                break
            }
        }
        if let tone, let toneData = presentationCallToneData(tone) {
            if let sharedAudioContext = self.sharedAudioContext {
                sharedAudioContext.audioDevice?.setTone(tone: OngoingCallContext.Tone(
                    samples: toneData,
                    sampleRate: 48000,
                    loopCount: tone.loopCount ?? 100000
                ))
            } else {
                self.genericCallContext?.setTone(tone: OngoingGroupCallContext.Tone(
                    samples: toneData,
                    sampleRate: 48000,
                    loopCount: tone.loopCount ?? 100000
                ))
            }
        } else {
            if let sharedAudioContext = self.sharedAudioContext {
                sharedAudioContext.audioDevice?.setTone(tone: nil)
            } else {
                self.genericCallContext?.setTone(tone: nil)
            }
        }
    }

    public func playTone(_ tone: PresentationGroupCallTone) {
        let name: String
        switch tone {
        case .unmuted:
            name = "voip_group_unmuted.mp3"
        case .recordingStarted:
            name = "voip_group_recording_started.mp3"
        }

        self.beginTone(tone: .custom(name: name, loopCount: 1))
    }
    
    private func markAsCanBeRemoved() {
        if self.markedAsCanBeRemoved {
            return
        }
        self.markedAsCanBeRemoved = true

        self.genericCallContext?.stop(account: self.account, reportCallId: nil, debugLog: self.debugLog)
        self.screencastIPCContext?.disableScreencast(account: self.account)

        self._canBeRemoved.set(.single(true))
        
        if let upgradedConferenceCall = self.upgradedConferenceCall {
            upgradedConferenceCall.internal_markAsCanBeRemoved()
        }
        
        if self.didConnectOnce {
            if let callManager = self.accountContext.sharedContext.callManager {
                let _ = (callManager.currentGroupCallSignal
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] call in
                    guard let self else {
                        return
                    }
                    if let call = call, call != .group(self) {
                        self.wasRemoved.set(.single(true))
                        return
                    }

                    self.beginTone(tone: .groupLeft)
                    
                    Queue.mainQueue().after(1.0, {
                        self.wasRemoved.set(.single(true))
                    })
                })
            }
        }
    }
    
    public func reconnect(with invite: String) {
        self.invite = invite
        self.requestCall(movingFromBroadcastToRtc: false)
    }
    
    public func reconnect(as peerId: EnginePeer.Id) {
        if peerId == self.joinAsPeerId {
            return
        }
        let _ = (self.accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { [weak self] myPeer in
            guard let self, let myPeer = myPeer else {
                return
            }
            
            let previousPeerId = self.joinAsPeerId
            if let localSsrc = self.currentLocalSsrc {
                self.ignorePreviousJoinAsPeerId = (previousPeerId, localSsrc)
            }
            self.joinAsPeerId = peerId
            
            if self.stateValue.scheduleTimestamp != nil {
                self.stateValue.myPeerId = peerId
                self.reconnectedAsEventsPipe.putNext(myPeer)
                self.switchToTemporaryScheduledParticipantsContext()
            } else {
                self.disableVideo()
                self.isMutedValue = .muted(isPushToTalkActive: false)
                self.isMutedPromise.set(self.isMutedValue)
                
                self.reconnectingAsPeer = myPeer
                
                if let participantsContext = self.participantsContext, let immediateState = participantsContext.immediateState {
                    for participant in immediateState.participants {
                        if participant.id == .peer(previousPeerId) {
                            self.temporaryJoinTimestamp = participant.joinTimestamp
                            self.temporaryActivityTimestamp = participant.activityTimestamp
                            self.temporaryActivityRank = participant.activityRank
                            self.temporaryRaiseHandRating = participant.raiseHandRating
                            self.temporaryHasRaiseHand = participant.hasRaiseHand
                            self.temporaryMuteState = participant.muteState
                            self.temporaryJoinedVideo = participant.joinedVideo
                        }
                    }
                    self.switchToTemporaryParticipantsContext(sourceContext: participantsContext, oldMyPeerId: previousPeerId)
                } else {
                    self.stateValue.myPeerId = peerId
                }
                
                self.requestCall(movingFromBroadcastToRtc: false)
            }
        })
    }
    
    public func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError> {
        self.leaving = true
        if let callInfo = self.internalState.callInfo {
            if terminateIfPossible {
                self.leaveDisposable.set((self.accountContext.engine.calls.stopGroupCall(peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.markAsCanBeRemoved()
                }))
            } else if let localSsrc = self.currentLocalSsrc {
                if let contexts = self.accountContext.cachedGroupCallContexts as? AccountGroupCallContextCacheImpl {
                    let engine = self.accountContext.engine
                    let id = callInfo.id
                    let accessHash = callInfo.accessHash
                    let source = localSsrc
                    contexts.impl.with { impl in
                        impl.leaveInBackground(engine: engine, id: id, accessHash: accessHash, source: source)
                    }
                }
                self.markAsCanBeRemoved()
            } else {
                self.markAsCanBeRemoved()
            }
        } else {
            self.markAsCanBeRemoved()
        }
        return self._canBeRemoved.get()
    }
    
    public func toggleIsMuted() {
        switch self.isMutedValue {
        case .muted:
            self.setIsMuted(action: .unmuted)
        case .unmuted:
            self.setIsMuted(action: .muted(isPushToTalkActive: false))
        }
    }
    
    public func setIsMuted(action: PresentationGroupCallMuteAction) {
        if self.isMutedValue == action {
            return
        }
        if let muteState = self.stateValue.muteState, !muteState.canUnmute {
            return
        }
        self.isMutedValue = action
        self.isMutedPromise.set(self.isMutedValue)
        let isEffectivelyMuted: Bool
        let isVisuallyMuted: Bool
        switch self.isMutedValue {
        case let .muted(isPushToTalkActive):
            isEffectivelyMuted = !isPushToTalkActive
            isVisuallyMuted = true
            let _ = self.updateMuteState(peerId: self.joinAsPeerId, isMuted: true)
        case .unmuted:
            isEffectivelyMuted = false
            isVisuallyMuted = false
            let _ = self.updateMuteState(peerId: self.joinAsPeerId, isMuted: false)
        }
        self.genericCallContext?.setIsMuted(isEffectivelyMuted)
        
        if let callId = self.callId {
            let context = self.accountContext
            let _ = (context.engine.calls.getGroupCallPersistentSettings(callId: callId)
            |> deliverOnMainQueue).startStandalone(next: { value in
                var value: PresentationGroupCallPersistentSettings = value?.get(PresentationGroupCallPersistentSettings.self) ?? PresentationGroupCallPersistentSettings.default
                value.isMicrophoneEnabledByDefault = !isVisuallyMuted
                if let entry = CodableEntry(value) {
                    context.engine.calls.setGroupCallPersistentSettings(callId: callId, value: entry)
                }
            })
        }
        
        if isVisuallyMuted {
            self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
        } else {
            self.stateValue.muteState = nil
        }
    }

    public func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool) {
        self.genericCallContext?.setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled)
    }
    
    public func toggleScheduledSubscription(_ subscribe: Bool) {
        guard case let .active(callInfo) = self.internalState, callInfo.scheduleTimestamp != nil else {
            return
        }
        self.participantsContext?.toggleScheduledSubscription(subscribe)
    }
    
    public func schedule(timestamp: Int32) {
        guard self.schedulePending else {
            return
        }
        guard let peerId = self.peerId else {
            return
        }
        
        self.schedulePending = false
        self.stateValue.scheduleTimestamp = timestamp
        
        self.summaryParticipantsState.set(.single(SummaryParticipantsState(
            participantCount: 1,
            topParticipants: [],
            activeSpeakers: Set()
        )))
        
        self.startDisposable.set((self.accountContext.engine.calls.createGroupCall(peerId: peerId, title: nil, scheduleDate: timestamp, isExternalStream: false)
        |> deliverOnMainQueue).start(next: { [weak self] callInfo in
            guard let self else {
                return
            }
            self.updateSessionState(internalState: .active(callInfo), audioSessionControl: self.audioSessionControl)
        }, error: { [weak self] error in
            if let self {
                self.markAsCanBeRemoved()
            }
        }))
    }
    
    
    public func startScheduled() {
        guard case let .active(callInfo) = self.internalState else {
            return
        }
        guard let peerId = self.peerId else {
            return
        }
        
        self.isScheduledStarted = true
        self.stateValue.scheduleTimestamp = nil
        
        self.startDisposable.set((self.accountContext.engine.calls.startScheduledGroupCall(peerId: peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
        |> deliverOnMainQueue).start(next: { [weak self] callInfo in
            guard let self else {
                return
            }
            self.updateSessionState(internalState: .active(callInfo), audioSessionControl: self.audioSessionControl)

            self.beginTone(tone: .groupJoined)
        }))
    }
    
    public func raiseHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.id == .peer(self.joinAsPeerId) {
                if participant.hasRaiseHand {
                    return
                }
                break
            }
        }
        
        self.participantsContext?.raiseHand()
    }
    
    public func lowerHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.id == .peer(self.joinAsPeerId) {
                if !participant.hasRaiseHand {
                    return
                }
                break
            }
        }
        
        self.participantsContext?.lowerHand()
    }
    
    public func makeOutgoingVideoView(requestClone: Bool, completion: @escaping (PresentationCallVideoView?, PresentationCallVideoView?) -> Void) {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer()
            self.videoCapturer = videoCapturer
        }

        guard let videoCapturer = self.videoCapturer else {
            completion(nil, nil)
            return
        }
        videoCapturer.makeOutgoingVideoView(requestClone: requestClone, completion: { mainView, cloneView in
            if let mainView = mainView {
                let setOnFirstFrameReceived = mainView.setOnFirstFrameReceived
                let setOnOrientationUpdated = mainView.setOnOrientationUpdated
                let setOnIsMirroredUpdated = mainView.setOnIsMirroredUpdated
                let updateIsEnabled = mainView.updateIsEnabled
                let mainVideoView = PresentationCallVideoView(
                    holder: mainView,
                    view: mainView.view,
                    setOnFirstFrameReceived: { f in
                        setOnFirstFrameReceived(f)
                    },
                    getOrientation: { [weak mainView] in
                        if let mainView = mainView {
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch mainView.getOrientation() {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            return mappedValue
                        } else {
                            return .rotation0
                        }
                    },
                    getAspect: { [weak mainView] in
                        if let mainView = mainView {
                            return mainView.getAspect()
                        } else {
                            return 0.0
                        }
                    },
                    setOnOrientationUpdated: { f in
                        setOnOrientationUpdated { value, aspect in
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch value {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            f?(mappedValue, aspect)
                        }
                    },
                    setOnIsMirroredUpdated: { f in
                        setOnIsMirroredUpdated { value in
                            f?(value)
                        }
                    },
                    updateIsEnabled: { value in
                        updateIsEnabled(value)
                    }
                )
                var cloneVideoView: PresentationCallVideoView?
                if let cloneView = cloneView {
                    let setOnFirstFrameReceived = cloneView.setOnFirstFrameReceived
                    let setOnOrientationUpdated = cloneView.setOnOrientationUpdated
                    let setOnIsMirroredUpdated = cloneView.setOnIsMirroredUpdated
                    let updateIsEnabled = cloneView.updateIsEnabled
                    cloneVideoView = PresentationCallVideoView(
                        holder: cloneView,
                        view: cloneView.view,
                        setOnFirstFrameReceived: { f in
                            setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak cloneView] in
                            if let cloneView = cloneView {
                                let mappedValue: PresentationCallVideoView.Orientation
                                switch cloneView.getOrientation() {
                                case .rotation0:
                                    mappedValue = .rotation0
                                case .rotation90:
                                    mappedValue = .rotation90
                                case .rotation180:
                                    mappedValue = .rotation180
                                case .rotation270:
                                    mappedValue = .rotation270
                                }
                                return mappedValue
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak cloneView] in
                            if let cloneView = cloneView {
                                return cloneView.getAspect()
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { f in
                            setOnOrientationUpdated { value, aspect in
                                let mappedValue: PresentationCallVideoView.Orientation
                                switch value {
                                case .rotation0:
                                    mappedValue = .rotation0
                                case .rotation90:
                                    mappedValue = .rotation90
                                case .rotation180:
                                    mappedValue = .rotation180
                                case .rotation270:
                                    mappedValue = .rotation270
                                }
                                f?(mappedValue, aspect)
                            }
                        },
                        setOnIsMirroredUpdated: { f in
                            setOnIsMirroredUpdated { value in
                                f?(value)
                            }
                        },
                        updateIsEnabled: { value in
                            updateIsEnabled(value)
                        }
                    )
                }
                completion(mainVideoView, cloneVideoView)
            } else {
                completion(nil, nil)
            }
        })
    }
    
    public func requestVideo() {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer()
            self.videoCapturer = videoCapturer
        }

        if let videoCapturer = self.videoCapturer {
            self.requestVideo(capturer: videoCapturer)

            var stateValue = self.stateValue
            stateValue.isMyVideoActive = true
            self.stateValue = stateValue
        }
    }

    func requestVideo(capturer: OngoingCallVideoCapturer, useFrontCamera: Bool = true) {
        self.videoCapturer = capturer
        self.useFrontCamera = useFrontCamera
        
        self.hasVideo = true
        if let videoCapturer = self.videoCapturer {
            self.genericCallContext?.requestVideo(videoCapturer)
            self.isVideoMuted = false
            self.isVideoMutedDisposable.set((videoCapturer.isActive
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                self.isVideoMuted = !value
                self.updateLocalVideoState()
            }))

            self.updateLocalVideoState()

            var stateValue = self.stateValue
            stateValue.isMyVideoActive = true
            self.stateValue = stateValue
        }
    }
    
    public func disableVideo() {
        self.hasVideo = false
        self.useFrontCamera = true;
        if let _ = self.videoCapturer {
            self.videoCapturer = nil
            self.isVideoMutedDisposable.set(nil)
            self.genericCallContext?.disableVideo()
            self.isVideoMuted = true
        
            self.updateLocalVideoState()

            var stateValue = self.stateValue
            stateValue.isMyVideoActive = false
            self.stateValue = stateValue
        }
    }

    private func updateLocalVideoState() {
        self.participantsContext?.updateVideoState(peerId: self.joinAsPeerId, isVideoMuted: self.videoCapturer == nil, isVideoPaused: self.isVideoMuted, isPresentationPaused: nil)
    }
    
    public func switchVideoCamera() {
        self.useFrontCamera = !self.useFrontCamera
        self.videoCapturer?.switchVideoInput(isFront: self.useFrontCamera)
    }

    private func requestScreencast() {
        guard let callInfo = self.internalState.callInfo else {
            return
        }
        
        self.hasScreencast = true
        if let screencastIPCContext = self.screencastIPCContext, let joinPayload = screencastIPCContext.requestScreencast() {
            self.screencastJoinDisposable.set((joinPayload
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] joinPayload in
                guard let self else {
                    return
                }

                self.requestDisposable.set((self.accountContext.engine.calls.joinGroupCallAsScreencast(
                    callId: callInfo.id,
                    accessHash: callInfo.accessHash,
                    joinPayload: joinPayload.0
                )
                |> deliverOnMainQueue).start(next: { [weak self] joinCallResult in
                    guard let self, let screencastIPCContext = self.screencastIPCContext else {
                        return
                    }
                    screencastIPCContext.setJoinResponse(clientParams: joinCallResult.jsonParams)
                    
                }, error: { _ in
                }))
            }))
        }
    }

    public func disableScreencast() {
        self.hasScreencast = false
        self.screencastIPCContext?.disableScreencast(account: self.account)
        
        let maybeCallInfo: GroupCallInfo? = self.internalState.callInfo

        if let callInfo = maybeCallInfo {
            self.screencastJoinDisposable.set(self.accountContext.engine.calls.leaveGroupCallAsScreencast(
                callId: callInfo.id,
                accessHash: callInfo.accessHash
            ).start())
        }
    }
    
    public func setVolume(peerId: PeerId, volume: Int32, sync: Bool) {
        var found = false
        for (ssrc, mapping) in self.ssrcMapping {
            if mapping.peerId == peerId {
                self.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                found = true
            }
        }
        if found && sync {
            self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: volume, raiseHand: nil)
        }
    }
    
    public func setRequestedVideoList(items: [PresentationGroupCallRequestedVideo]) {
        self.requestedVideoChannels = items.compactMap { item -> OngoingGroupCallContext.VideoChannel in
            let mappedMinQuality: OngoingGroupCallContext.VideoChannel.Quality
            let mappedMaxQuality: OngoingGroupCallContext.VideoChannel.Quality
            switch item.minQuality {
            case .thumbnail:
                mappedMinQuality = .thumbnail
            case .medium:
                mappedMinQuality = .medium
            case .full:
                mappedMinQuality = .full
            }
            switch item.maxQuality {
            case .thumbnail:
                mappedMaxQuality = .thumbnail
            case .medium:
                mappedMaxQuality = .medium
            case .full:
                mappedMaxQuality = .full
            }
            return OngoingGroupCallContext.VideoChannel(
                audioSsrc: item.audioSsrc,
                peerId: item.peerId,
                endpointId: item.endpointId,
                ssrcGroups: item.ssrcGroups.map { group in
                    return OngoingGroupCallContext.VideoChannel.SsrcGroup(semantics: group.semantics, ssrcs: group.ssrcs)
                },
                minQuality: mappedMinQuality,
                maxQuality: mappedMaxQuality
            )
        }
        if let genericCallContext = self.genericCallContext, !self.suspendVideoChannelRequests {
            genericCallContext.setRequestedVideoChannels(self.requestedVideoChannels)
        }
    }
    
    public func setSuspendVideoChannelRequests(_ value: Bool) {
        if self.suspendVideoChannelRequests != value {
            self.suspendVideoChannelRequests = value
            
            if let genericCallContext = self.genericCallContext {
                genericCallContext.setRequestedVideoChannels(self.suspendVideoChannelRequests ? [] : self.requestedVideoChannels)
            }
        }
    }
    
    public func setCurrentAudioOutput(_ output: AudioSessionOutput) {
        if let sharedAudioContext = self.sharedAudioContext {
            sharedAudioContext.setCurrentAudioOutput(output)
            return
        }
        guard self.currentSelectedAudioOutputValue != output else {
            return
        }
        self.currentSelectedAudioOutputValue = output
        
        self.updateProximityMonitoring()
        
        self.audioOutputStatePromise.set(.single((self.audioOutputStateValue.0, output))
        |> then(
            .single(self.audioOutputStateValue)
            |> delay(1.0, queue: Queue.mainQueue())
        ))
        
        if let audioSessionControl = self.audioSessionControl {
            if self.isStream {
                audioSessionControl.setOutputMode(.system)
            } else {
                audioSessionControl.setOutputMode(.custom(output))
            }
        }
    }
    
    private func updateProximityMonitoring() {
        if self.sharedAudioContext != nil {
            return
        }
        
        var shouldMonitorProximity = false
        switch self.currentSelectedAudioOutputValue {
        case .builtin:
            shouldMonitorProximity = true
        default:
            break
        }
        if case .muted(isPushToTalkActive: true) = self.isMutedValue {
            shouldMonitorProximity = false
        }
        
        if shouldMonitorProximity {
            if self.proximityManagerIndex == nil {
                self.proximityManagerIndex = DeviceProximityManager.shared().add { _ in
                }
            }
        } else {
            if let proximityManagerIndex = self.proximityManagerIndex {
                self.proximityManagerIndex = nil
                DeviceProximityManager.shared().remove(proximityManagerIndex)
            }
        }
    }
    
    private func updateAudioOutputs(availableOutputs: [AudioSessionOutput], currentOutput: AudioSessionOutput?) {
        if self.actualAudioOutputState?.0 != availableOutputs || self.actualAudioOutputState?.1 != currentOutput {
            self.actualAudioOutputState = (availableOutputs, currentOutput)
            
            self.setupAudioOutputs()
        }
    }
    
    private func setupAudioOutputs() {
        if let actualAudioOutputState = self.actualAudioOutputState, let currentOutput = actualAudioOutputState.1 {
            self.currentSelectedAudioOutputValue = currentOutput
            
            switch currentOutput {
            case .headphones, .speaker:
                break
            case let .port(port) where port.type == .bluetooth:
                break
            default:
                //self.setCurrentAudioOutput(.speaker)
                break
            }
        }
    }
    
    public func updateMuteState(peerId: PeerId, isMuted: Bool) -> GroupCallParticipantsContext.Participant.MuteState? {
        let canThenUnmute: Bool
        if isMuted {
            var mutedByYou = false
            if peerId == self.joinAsPeerId {
                canThenUnmute = true
            } else if self.stateValue.canManageCall {
                if self.stateValue.adminIds.contains(peerId) {
                    canThenUnmute = true
                } else {
                    canThenUnmute = false
                }
            } else if self.stateValue.adminIds.contains(self.accountContext.account.peerId) {
                canThenUnmute = true
            } else {
                self.setVolume(peerId: peerId, volume: 0, sync: false)
                mutedByYou = true
                canThenUnmute = true
            }
            let muteState = isMuted ? GroupCallParticipantsContext.Participant.MuteState(canUnmute: canThenUnmute, mutedByYou: mutedByYou) : nil
            self.participantsContext?.updateMuteState(peerId: peerId, muteState: muteState, volume: nil, raiseHand: nil)
            return muteState
        } else {
            if peerId == self.joinAsPeerId {
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: nil, raiseHand: nil)
                return nil
            } else if self.stateValue.canManageCall || self.stateValue.adminIds.contains(self.accountContext.account.peerId) {
                let muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: muteState, volume: nil, raiseHand: nil)
                return muteState
            } else {
                self.setVolume(peerId: peerId, volume: 10000, sync: true)
                self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: nil, raiseHand: nil)
                return nil
            }
        }
    }
    
    public func setShouldBeRecording(_ shouldBeRecording: Bool, title: String?, videoOrientation: Bool?) {
        if !self.stateValue.canManageCall {
            return
        }
        if (self.stateValue.recordingStartTimestamp != nil) == shouldBeRecording {
            return
        }
        self.participantsContext?.updateShouldBeRecording(shouldBeRecording, title: title, videoOrientation: videoOrientation)
    }
    
    private func requestCall(movingFromBroadcastToRtc: Bool) {
        if !self.didInitializeConnectionMode || self.currentConnectionMode != .none {
            self.didInitializeConnectionMode = true
            self.currentConnectionMode = .none
            if let genericCallContext = self.genericCallContext {
                switch genericCallContext {
                case let .call(callContext):
                    callContext.setConnectionMode(.none, keepBroadcastConnectedIfWasEnabled: movingFromBroadcastToRtc, isUnifiedBroadcast: false)
                case .mediaStream, .externalMediaStream:
                    assertionFailure()
                    break
                }
            }
        }
        
        self.internalState = .requesting
        self.internalStatePromise.set(.single(.requesting))
        self.isCurrentlyConnecting = nil
        
        enum CallError {
            case generic
        }
        
        let context = self.accountContext
        let currentCall: Signal<GroupCallInfo?, CallError>
        if let initialCall = self.initialCall {
            currentCall = context.engine.calls.getCurrentGroupCall(reference: initialCall.reference)
            |> mapError { _ -> CallError in
                return .generic
            }
            |> map { summary -> GroupCallInfo? in
                return summary?.info
            }
        } else if case let .active(callInfo) = self.internalState {
            currentCall = context.engine.calls.getCurrentGroupCall(reference: .id(id: callInfo.id, accessHash: callInfo.accessHash))
            |> mapError { _ -> CallError in
                return .generic
            }
            |> map { summary -> GroupCallInfo? in
                return summary?.info
            }
        } else {
            currentCall = .single(nil)
        }
        
        let currentOrRequestedCall = currentCall
        |> mapToSignal { callInfo -> Signal<GroupCallInfo?, CallError> in
            if let callInfo = callInfo {
                return .single(callInfo)
            } else {
                return .single(nil)
            }
        }
        
        self.networkStateDisposable.set(nil)
        self.joinDisposable.set(nil)
        
        self.checkCallDisposable?.dispose()
        self.checkCallDisposable = nil
        
        if movingFromBroadcastToRtc {
            self.stateValue.networkState = .connected
        } else {
            self.stateValue.networkState = .connecting
        }
        
        self.requestDisposable.set((currentOrRequestedCall
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            
            if let value = value {
                var reference: InternalGroupCallReference = .id(id: value.id, accessHash: value.accessHash)
                if let current = self.initialCall {
                    switch current.reference {
                    case .message, .link:
                        reference = current.reference
                    default:
                        break
                    }
                }
                self.initialCall = (EngineGroupCallDescription(id: value.id, accessHash: value.accessHash, title: value.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: value.isStream), reference)
                self.callId = value.id
                
                self.updateSessionState(internalState: .active(value), audioSessionControl: self.audioSessionControl)
            } else {
                self.markAsCanBeRemoved()
            }
        }))
    }
    
    public func invitePeer(_ peerId: PeerId, isVideo: Bool) -> Bool {
        if self.isConference {
            guard let initialCall = self.initialCall else {
                return false
            }
            
            if self.conferenceInvitationContexts[peerId] != nil {
                return false
            }
            var onStateUpdated: ((PendingConferenceInvitationContext.State) -> Void)?
            var onEnded: ((Bool) -> Void)?
            var didEndAlready = false
            let invitationContext = PendingConferenceInvitationContext(
                engine: self.accountContext.engine,
                reference: initialCall.reference,
                peerId: peerId,
                isVideo: isVideo,
                onStateUpdated: { state in
                    onStateUpdated?(state)
                },
                onEnded: { success in
                    didEndAlready = true
                    onEnded?(success)
                },
                onError: { [weak self] error in
                    guard let self else {
                        return
                    }
                    
                    let timestamp = CACurrentMediaTime()
                    if self.lastErrorAlertTimestamp > timestamp - 1.0 {
                        return
                    }
                    self.lastErrorAlertTimestamp = timestamp
                    
                    let presentationData = self.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkColorPresentationTheme)
                    
                    var errorText = presentationData.strings.Login_UnknownError
                    
                    switch error {
                    case let .privacy(peer):
                        if let peer {
                            if let currentInviteLinks = self.currentInviteLinks {
                                let inviteLinkScreen = self.accountContext.sharedContext.makeSendInviteLinkScreen(context: self.accountContext, subject: .groupCall(link: currentInviteLinks.listenerLink), peers: [TelegramForbiddenInvitePeer(peer: peer, canInviteWithPremium: false, premiumRequiredToContact: false)], theme: defaultDarkColorPresentationTheme)
                                if let navigationController = self.accountContext.sharedContext.mainWindow?.viewController as? NavigationController {
                                    navigationController.pushViewController(inviteLinkScreen)
                                }
                                return
                            } else {
                                errorText = presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).string
                            }
                        }
                    default:
                        break
                    }
                    
                    self.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                    ]), on: .root, blockInteraction: false, completion: {})
                }
            )
            if !didEndAlready {
                conferenceInvitationContexts[peerId] = invitationContext
                if !self.invitedPeersValue.contains(where: { $0.id == peerId }) {
                    self.invitedPeersValue.append(PresentationGroupCallInvitedPeer(id: peerId, state: .requesting))
                }
                onStateUpdated = { [weak self] state in
                    guard let self else {
                        return
                    }
                    if let index = self.invitedPeersValue.firstIndex(where: { $0.id == peerId }) {
                        var invitedPeer = self.invitedPeersValue[index]
                        switch state {
                        case .ringing:
                            invitedPeer.state = .ringing
                        }
                        self.invitedPeersValue[index] = invitedPeer
                    }
                }
                onEnded = { [weak self, weak invitationContext] success in
                    guard let self, let invitationContext else {
                        return
                    }
                    if self.conferenceInvitationContexts[peerId] === invitationContext {
                        self.conferenceInvitationContexts.removeValue(forKey: peerId)
                        
                        if success {
                            if let index = self.invitedPeersValue.firstIndex(where: { $0.id == peerId }) {
                                var invitedPeer = self.invitedPeersValue[index]
                                invitedPeer.state = .connecting
                                self.invitedPeersValue[index] = invitedPeer
                            }
                        } else {
                            self.invitedPeersValue.removeAll(where: { $0.id == peerId })
                        }
                    }
                }
            }
            
            return false
        } else {
            guard let callInfo = self.internalState.callInfo, !self.invitedPeersValue.contains(where: { $0.id == peerId }) else {
                return false
            }
            
            var updatedInvitedPeers = self.invitedPeersValue
            updatedInvitedPeers.insert(PresentationGroupCallInvitedPeer(id: peerId, state: nil), at: 0)
            self.invitedPeersValue = updatedInvitedPeers
            
            let _ = self.accountContext.engine.calls.inviteToGroupCall(callId: callInfo.id, accessHash: callInfo.accessHash, peerId: peerId).start()
            
            return true
        }
    }
    
    public func kickPeer(id: EnginePeer.Id) {
        if self.isConference {
            self.removedPeer(id)
            
            self.e2eContext?.kickPeer(id: id)
        }
    }
    
    public func removedPeer(_ peerId: PeerId) {
        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.removeAll(where: { $0.id == peerId})
        self.invitedPeersValue = updatedInvitedPeers
        
        if let conferenceInvitationContext = self.conferenceInvitationContexts[peerId] {
            self.conferenceInvitationContexts.removeValue(forKey: peerId)
            if let messageId = conferenceInvitationContext.messageId {
                self.accountContext.engine.account.callSessionManager.dropOutgoingConferenceRequest(messageId: messageId)
            }
        }
    }
    
    public func updateTitle(_ title: String) {
        guard let callInfo = self.internalState.callInfo else {
            return
        }
        self.stateValue.title = title.isEmpty ? nil : title
        let _ = self.accountContext.engine.calls.editGroupCallTitle(callId: callInfo.id, accessHash: callInfo.accessHash, title: title).start()
    }
    
    public var inviteLinks: Signal<GroupCallInviteLinks?, NoError> {
        let engine = self.accountContext.engine
        let initialCall = self.initialCall
        let isConference = self.isConference

        return self.state
        |> map { state -> PeerId in
            return state.myPeerId
        }
        |> distinctUntilChanged
        |> mapToSignal { _ -> Signal<GroupCallInviteLinks?, NoError> in
            return self.internalStatePromise.get()
            |> filter { state -> Bool in
                if case .requesting = state {
                    return false
                } else {
                    return true
                }
            }
            |> mapToSignal { state in
                if let callInfo = state.callInfo {
                    let reference: InternalGroupCallReference
                    if let initialCall = initialCall {
                        reference = initialCall.reference
                    } else {
                        reference = .id(id: callInfo.id, accessHash: callInfo.accessHash)
                    }
                    
                    return engine.calls.groupCallInviteLinks(reference: reference, isConference: isConference)
                } else {
                    return .complete()
                }
            }
        }
    }
    
    public var currentInviteLinks: GroupCallInviteLinks?
    
    private var currentMyAudioLevel: Float = 0.0
    private var currentMyAudioLevelTimestamp: Double = 0.0
    private var isSendingTyping: Bool = false
    
    private func restartMyAudioLevelTimer() {
        self.myAudioLevelTimer?.invalidate()
        
        guard let peerId = self.peerId else {
            return
        }
        let myAudioLevelTimer = SwiftSignalKit.Timer(timeout: 0.1, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.myAudioLevelTimer = nil
            
            let timestamp = CACurrentMediaTime()
            
            var shouldBeSendingTyping = false
            if self.currentMyAudioLevel > 0.01 && timestamp < self.currentMyAudioLevelTimestamp + 1.0 {
                self.restartMyAudioLevelTimer()
                shouldBeSendingTyping = true
            } else {
                if timestamp < self.currentMyAudioLevelTimestamp + 1.0 {
                    self.restartMyAudioLevelTimer()
                    shouldBeSendingTyping = true
                }
            }
            if shouldBeSendingTyping != self.isSendingTyping {
                self.isSendingTyping = shouldBeSendingTyping
                if shouldBeSendingTyping {
                    self.typingDisposable.set(self.accountContext.account.acquireLocalInputActivity(peerId: PeerActivitySpace(peerId: peerId, category: .voiceChat), activity: .speakingInGroupCall(timestamp: 0)))
                    self.restartMyAudioLevelTimer()
                } else {
                    self.typingDisposable.set(nil)
                }
            }
        }, queue: .mainQueue())
        self.myAudioLevelTimer = myAudioLevelTimer
        myAudioLevelTimer.start()
    }
    
    private func processMyAudioLevel(level: Float, hasVoice: Bool) {
        self.currentMyAudioLevel = level
        
        if level > 0.01 && hasVoice {
            self.currentMyAudioLevelTimestamp = CACurrentMediaTime()
            
            if self.myAudioLevelTimer == nil {
                self.restartMyAudioLevelTimer()
            }
        }
    }
    
    public func updateDefaultParticipantsAreMuted(isMuted: Bool) {
        self.participantsContext?.updateDefaultParticipantsAreMuted(isMuted: isMuted)
    }
    
    func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError>? {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            
            if let genericCallContext = self.genericCallContext {
                return genericCallContext.video(endpointId: endpointId).start(next: { value in
                    subscriber.putNext(value)
                })
            } else {
                let disposable = MetaDisposable()
                let index = self.pendingVideoSubscribers.add((endpointId, disposable, { value in
                    subscriber.putNext(value)
                }))
                
                return ActionDisposable { [weak self] in
                    disposable.dispose()
                    
                    Queue.mainQueue().async {
                        guard let self else {
                            return
                        }
                        self.pendingVideoSubscribers.remove(index)
                    }
                }
            }
        }
        |> runOn(.mainQueue())
    }
    
    private func connectPendingVideoSubscribers() {
        guard let genericCallContext = self.genericCallContext else {
            return
        }
        
        let items = self.pendingVideoSubscribers.copyItems()
        self.pendingVideoSubscribers.removeAll()
        
        for (endpointId, disposable, f) in items {
            disposable.set(genericCallContext.video(endpointId: endpointId).start(next: { value in
                f(value)
            }))
        }
    }
    
    public func loadMoreMembers(token: String) {
        self.participantsContext?.loadMore(token: token)
    }

    func getStats() -> Signal<OngoingGroupCallContext.Stats, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            if let genericCallContext = self.genericCallContext {
                genericCallContext.getStats(completion: { stats in
                    subscriber.putNext(stats)
                    subscriber.putCompletion()
                })
            } else {
                subscriber.putCompletion()
            }

            return EmptyDisposable
        }
        |> runOn(.mainQueue())
    }
    
    func moveConferenceCall(source: PresentationCall) {
        guard let source = source as? PresentationCallImpl else {
            return
        }
        
        self.pendingDisconnedUpgradedConferenceCall?.resetAsMovedToConference()
        self.pendingDisconnedUpgradedConferenceCall = source
        
        self.pendingDisconnedUpgradedConferenceCallTimer?.invalidate()
        self.pendingDisconnedUpgradedConferenceCallTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { [weak self] _ in
            guard let self else {
                return
            }
            if let pendingDisconnedUpgradedConferenceCall = self.pendingDisconnedUpgradedConferenceCall {
                self.pendingDisconnedUpgradedConferenceCall = nil
                pendingDisconnedUpgradedConferenceCall.resetAsMovedToConference()
            }
        })
    }
}

public final class TelegramE2EEncryptionProviderImpl: TelegramE2EEncryptionProvider {
    public static let shared = TelegramE2EEncryptionProviderImpl()
    
    public func generateKeyPair() -> TelegramKeyPair? {
        guard let keyPair = TdKeyPair.generate() else {
            return nil
        }
        guard let publicKey = TelegramPublicKey(data: keyPair.publicKey) else {
            return nil
        }
        return TelegramKeyPair(id: keyPair.keyId, publicKey: publicKey)
    }
    
    public func generateCallZeroBlock(keyPair: TelegramKeyPair, userId: Int64) -> Data? {
        guard let keyPair = TdKeyPair(keyId: keyPair.id, publicKey: keyPair.publicKey.data) else {
            return nil
        }
        return tdGenerateZeroBlock(keyPair, userId)
    }
}
