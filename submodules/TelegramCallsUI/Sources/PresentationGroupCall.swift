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

private extension GroupCallParticipantsContext.Participant {
    var allSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let ssrc = self.ssrc {
            participantSsrcs.insert(ssrc)
        }
        if let videoDescription = self.videoDescription {
            for group in videoDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        if let presentationDescription = self.presentationDescription {
            for group in presentationDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        return participantSsrcs
    }

    var videoSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let videoDescription = self.videoDescription {
            for group in videoDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        return participantSsrcs
    }

    var presentationSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let presentationDescription = self.presentationDescription {
            for group in presentationDescription.ssrcGroups {
                for ssrc in group.ssrcs {
                    participantSsrcs.insert(ssrc)
                }
            }
        }
        return participantSsrcs
    }
}

public final class AccountGroupCallContextImpl: AccountGroupCallContext {
    public final class Proxy {
        public let context: AccountGroupCallContextImpl
        let removed: () -> Void
        
        public init(context: AccountGroupCallContextImpl, removed: @escaping () -> Void) {
            self.context = context
            self.removed = removed
        }
        
        deinit {
            self.removed()
        }
        
        public func keep() {
        }
    }
    
    var disposable: Disposable?
    public var participantsContext: GroupCallParticipantsContext?
    
    private let panelDataPromise = Promise<GroupCallPanelData?>()
    public var panelData: Signal<GroupCallPanelData?, NoError> {
        return self.panelDataPromise.get()
    }
    
    public init(account: Account, engine: TelegramEngine, peerId: PeerId, isChannel: Bool, call: EngineGroupCallDescription) {
        self.panelDataPromise.set(.single(nil))
        /*self.panelDataPromise.set(.single(GroupCallPanelData(
            peerId: peerId,
            isChannel: isChannel,
            info: GroupCallInfo(
                id: call.id,
                accessHash: call.accessHash,
                participantCount: 0,
                streamDcId: nil,
                title: call.title,
                scheduleTimestamp: call.scheduleTimestamp,
                subscribedToScheduled: call.subscribedToScheduled,
                recordingStartTimestamp: nil,
                sortAscending: true,
                defaultParticipantsAreMuted: nil,
                isVideoEnabled: false,
                unmutedVideoLimit: 0,
                isStream: call.isStream
            ),
            topParticipants: [],
            participantCount: 0,
            activeSpeakers: Set(),
            groupCall: nil
        )))*/

        let state = engine.calls.getGroupCallParticipants(callId: call.id, accessHash: call.accessHash, offset: "", ssrcs: [], limit: 100, sortAscending: nil)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<GroupCallParticipantsContext.State?, NoError> in
                return .single(nil)
            }
        
        self.disposable = (combineLatest(queue: .mainQueue(),
            state,
            engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        )
        |> deliverOnMainQueue).start(next: { [weak self] state, peer in
            guard let strongSelf = self, let state = state else {
                return
            }
            let context = engine.calls.groupCall(
                peerId: peerId,
                myPeerId: account.peerId,
                id: call.id,
                accessHash: call.accessHash,
                state: state,
                previousServiceState: nil
            )
                        
            strongSelf.participantsContext = context
            strongSelf.panelDataPromise.set(combineLatest(queue: .mainQueue(),
                context.state,
                context.activeSpeakers
            )
            |> map { state, activeSpeakers -> GroupCallPanelData in
                var topParticipants: [GroupCallParticipantsContext.Participant] = []
                for participant in state.participants {
                    if topParticipants.count >= 3 {
                        break
                    }
                    topParticipants.append(participant)
                }

                var isChannel = false
                if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                    isChannel = true
                }

                return GroupCallPanelData(
                    peerId: peerId,
                    isChannel: isChannel,
                    info: GroupCallInfo(id: call.id, accessHash: call.accessHash, participantCount: state.totalCount, streamDcId: nil, title: state.title, scheduleTimestamp: state.scheduleTimestamp, subscribedToScheduled: state.subscribedToScheduled, recordingStartTimestamp: nil, sortAscending: state.sortAscending, defaultParticipantsAreMuted: state.defaultParticipantsAreMuted, isVideoEnabled: state.isVideoEnabled, unmutedVideoLimit: state.unmutedVideoLimit, isStream: state.isStream),
                    topParticipants: topParticipants,
                    participantCount: state.totalCount,
                    activeSpeakers: activeSpeakers,
                    groupCall: nil
                )
            })
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

public final class AccountGroupCallContextCacheImpl: AccountGroupCallContextCache {
    public class Impl {
        private class Record {
            let context: AccountGroupCallContextImpl
            let subscribers = Bag<Void>()
            var removeTimer: SwiftSignalKit.Timer?
            
            init(context: AccountGroupCallContextImpl) {
                self.context = context
            }
        }
        
        private let queue: Queue
        private var contexts: [Int64: Record] = [:]

        private let leaveDisposables = DisposableSet()
        
        init(queue: Queue) {
            self.queue = queue
        }
        
        public func get(account: Account, engine: TelegramEngine, peerId: PeerId, isChannel: Bool, call: EngineGroupCallDescription) -> AccountGroupCallContextImpl.Proxy {
            let result: Record
            if let current = self.contexts[call.id] {
                result = current
            } else {
                let context = AccountGroupCallContextImpl(account: account, engine: engine, peerId: peerId, isChannel: isChannel, call: call)
                result = Record(context: context)
                self.contexts[call.id] = result
            }
            
            let index = result.subscribers.add(Void())
            result.removeTimer?.invalidate()
            result.removeTimer = nil
            return AccountGroupCallContextImpl.Proxy(context: result.context, removed: { [weak self, weak result] in
                Queue.mainQueue().async {
                    if let strongResult = result, let strongSelf = self, strongSelf.contexts[call.id] === strongResult {
                        strongResult.subscribers.remove(index)
                        if strongResult.subscribers.isEmpty {
                            let removeTimer = SwiftSignalKit.Timer(timeout: 30, repeat: false, completion: {
                                if let result = result, let strongSelf = self, strongSelf.contexts[call.id] === result, result.subscribers.isEmpty {
                                    strongSelf.contexts.removeValue(forKey: call.id)
                                }
                            }, queue: .mainQueue())
                            strongResult.removeTimer = removeTimer
                            removeTimer.start()
                        }
                    }
                }
            })
        }

        public func leaveInBackground(engine: TelegramEngine, id: Int64, accessHash: Int64, source: UInt32) {
            let disposable = engine.calls.leaveGroupCall(callId: id, accessHash: accessHash, source: source).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let context = strongSelf.contexts[id] {
                    context.context.participantsContext?.removeLocalPeerId()
                }
            })
            self.leaveDisposables.add(disposable)
        }
    }
    
    let queue: Queue = .mainQueue()
    public let impl: QueueLocalObject<Impl>
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
}

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
            isVideoWatchersLimitReached: false
        )
    }
}

private enum CurrentImpl {
    case call(OngoingGroupCallContext)
    case mediaStream(WrappedMediaStreamingContext)
}

private extension CurrentImpl {
    var joinPayload: Signal<(String, UInt32), NoError> {
        switch self {
        case let .call(callContext):
            return callContext.joinPayload
        case .mediaStream:
            let ssrcId = UInt32.random(in: 0 ..< UInt32(Int32.max - 1))
            let dict: [String: Any] = [
                "fingerprints": [],
                "ufrag": "",
                "pwd": "",
                "ssrc": Int32(bitPattern: ssrcId),
                "ssrc-groups": []
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
        case .mediaStream:
            return .single(OngoingGroupCallContext.NetworkState(isConnected: true, isTransitioningFromBroadcastToRtc: false))
        }
    }
    
    var audioLevels: Signal<[(OngoingGroupCallContext.AudioLevelKey, Float, Bool)], NoError> {
        switch self {
        case let .call(callContext):
            return callContext.audioLevels
        case .mediaStream:
            return .single([])
        }
    }
    
    var isMuted: Signal<Bool, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.isMuted
        case .mediaStream:
            return .single(true)
        }
    }

    var isNoiseSuppressionEnabled: Signal<Bool, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.isNoiseSuppressionEnabled
        case .mediaStream:
            return .single(false)
        }
    }
    
    func stop() {
        switch self {
        case let .call(callContext):
            callContext.stop()
        case .mediaStream:
            break
        }
    }
    
    func setIsMuted(_ isMuted: Bool) {
        switch self {
        case let .call(callContext):
            callContext.setIsMuted(isMuted)
        case .mediaStream:
            break
        }
    }

    func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool) {
        switch self {
        case let .call(callContext):
            callContext.setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled)
        case .mediaStream:
            break
        }
    }
    
    func requestVideo(_ capturer: OngoingCallVideoCapturer?) {
        switch self {
        case let .call(callContext):
            callContext.requestVideo(capturer)
        case .mediaStream:
            break
        }
    }
    
    func disableVideo() {
        switch self {
        case let .call(callContext):
            callContext.disableVideo()
        case .mediaStream:
            break
        }
    }
    
    func setVolume(ssrc: UInt32, volume: Double) {
        switch self {
        case let .call(callContext):
            callContext.setVolume(ssrc: ssrc, volume: volume)
        case .mediaStream:
            break
        }
    }

    func setRequestedVideoChannels(_ channels: [OngoingGroupCallContext.VideoChannel]) {
        switch self {
        case let .call(callContext):
            callContext.setRequestedVideoChannels(channels)
        case .mediaStream:
            break
        }
    }
    
    func makeIncomingVideoView(endpointId: String, requestClone: Bool, completion: @escaping (OngoingCallContextPresentationCallVideoView?, OngoingCallContextPresentationCallVideoView?) -> Void) {
        switch self {
        case let .call(callContext):
            callContext.makeIncomingVideoView(endpointId: endpointId, requestClone: requestClone, completion: completion)
        case .mediaStream:
            break
        }
    }

    func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        switch self {
        case let .call(callContext):
            return callContext.video(endpointId: endpointId)
        case let .mediaStream(mediaStreamContext):
            return mediaStreamContext.video()
        }
    }

    func addExternalAudioData(data: Data) {
        switch self {
        case let .call(callContext):
            callContext.addExternalAudioData(data: data)
        case .mediaStream:
            break
        }
    }

    func getStats(completion: @escaping (OngoingGroupCallContext.Stats) -> Void) {
        switch self {
        case let .call(callContext):
            callContext.getStats(completion: completion)
        case .mediaStream:
            break
        }
    }
}

public func groupCallLogsPath(account: Account) -> String {
    return account.basePath + "/group-calls"
}

private func cleanupGroupCallLogs(account: Account) {
    let path = groupCallLogsPath(account: account)
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path, isDirectory: nil) {
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    var oldest: [(URL, Date)] = []
    var count = 0
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
        for url in enumerator {
            if let url = url as? URL {
                if let date = (try? url.resourceValues(forKeys: Set([.contentModificationDateKey])))?.contentModificationDate {
                    oldest.append((url, date))
                    count += 1
                }
            }
        }
    }
    let callLogsLimit = 20
    if count > callLogsLimit {
        oldest.sort(by: { $0.1 > $1.1 })
        while oldest.count > callLogsLimit {
            try? fileManager.removeItem(atPath: oldest[oldest.count - 1].0.path)
            oldest.removeLast()
        }
    }
}

public func allocateCallLogPath(account: Account) -> String {
    let path = groupCallLogsPath(account: account)
    
    let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true, attributes: nil)
    
    let name = "log-\(Date())".replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    
    return "\(path)/\(name).log"
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
        public var activeSpeakers: Set<PeerId>
    
        public init(
            participantCount: Int,
            topParticipants: [GroupCallParticipantsContext.Participant],
            activeSpeakers: Set<PeerId>
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
        
        private var participants: [PeerId: Participant] = [:]
        private let speakingParticipantsPromise = ValuePromise<[PeerId: UInt32]>()
        private var speakingParticipants = [PeerId: UInt32]() {
            didSet {
                self.speakingParticipantsPromise.set(self.speakingParticipants)
            }
        }
        
        private let audioLevelsPromise = Promise<[(PeerId, UInt32, Float, Bool)]>()
        
        init() {
        }
        
        func update(levels: [(PeerId, UInt32, Float, Bool)]) {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            let currentParticipants: [PeerId: Participant] = self.participants
            
            var validSpeakers: [PeerId: Participant] = [:]
            var silentParticipants = Set<PeerId>()
            var speakingParticipants = [PeerId: UInt32]()
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
            
            var audioLevels: [(PeerId, UInt32, Float, Bool)] = []
            for (peerId, source, level, hasVoice) in levels {
                if level > 0.001 {
                    audioLevels.append((peerId, source, level, hasVoice))
                }
            }
            
            self.participants = validSpeakers
            self.speakingParticipants = speakingParticipants
            self.audioLevelsPromise.set(.single(audioLevels))
        }
        
        func get() -> Signal<[PeerId: UInt32], NoError> {
            return self.speakingParticipantsPromise.get()
        }
        
        func getAudioLevels() -> Signal<[(PeerId, UInt32, Float, Bool)], NoError> {
            return self.audioLevelsPromise.get()
        }
    }
    
    public let account: Account
    public let accountContext: AccountContext
    private let audioSession: ManagedAudioSession
    private let callKitIntegration: CallKitIntegration?
    public var isIntegratedWithCallKit: Bool {
        return self.callKitIntegration != nil
    }
    
    private let getDeviceAccessData: () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void)
    
    private var initialCall: EngineGroupCallDescription?
    public let internalId: CallSessionInternalId
    public let peerId: PeerId
    private let isChannel: Bool
    private var invite: String?
    private var joinAsPeerId: PeerId
    private var ignorePreviousJoinAsPeerId: (PeerId, UInt32)?
    private var reconnectingAsPeer: Peer?
    
    public private(set) var hasVideo: Bool
    public private(set) var hasScreencast: Bool
    private let isVideoEnabled: Bool
    
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

    private var screencastCallContext: OngoingGroupCallContext?
    private var screencastBufferServerContext: IpcGroupCallBufferAppContext?
    private var screencastCapturer: OngoingCallVideoCapturer?

    private struct SsrcMapping {
        var peerId: PeerId
        var isPresentation: Bool
    }
    private var ssrcMapping: [UInt32: SsrcMapping] = [:]
    
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

    private var isVideoMuted: Bool = false
    private let isVideoMutedDisposable = MetaDisposable()
    
    private let audioOutputStatePromise = Promise<([AudioSessionOutput], AudioSessionOutput?)>(([], nil))
    private var audioOutputStateDisposable: Disposable?
    private var actualAudioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
    private var audioOutputStateValue: ([AudioSessionOutput], AudioSessionOutput?) = ([], nil)
    private var currentSelectedAudioOutputValue: AudioSessionOutput = .builtin
    public var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> {
        return self.audioOutputStatePromise.get()
    }
    
    private var audioLevelsDisposable = MetaDisposable()
    
    private let speakingParticipantsContext = SpeakingParticipantsContext()
    private var speakingParticipantsReportTimestamp: [PeerId: Double] = [:]
    public var audioLevels: Signal<[(PeerId, UInt32, Float, Bool)], NoError> {
        return self.speakingParticipantsContext.getAudioLevels()
    }
    
    private var participantsContextStateDisposable = MetaDisposable()
    private var temporaryParticipantsContext: GroupCallParticipantsContext?
    private var participantsContext: GroupCallParticipantsContext?
    
    private let myAudioLevelPipe = ValuePipe<Float>()
    public var myAudioLevel: Signal<Float, NoError> {
        return self.myAudioLevelPipe.signal()
    }
    private var myAudioLevelDisposable = MetaDisposable()
    
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
    
    private var invitedPeersValue: [PeerId] = [] {
        didSet {
            if self.invitedPeersValue != oldValue {
                self.inivitedPeersPromise.set(self.invitedPeersValue)
            }
        }
    }
    private let inivitedPeersPromise = ValuePromise<[PeerId]>([])
    public var invitedPeers: Signal<[PeerId], NoError> {
        return self.inivitedPeersPromise.get()
    }
    
    private let memberEventsPipe = ValuePipe<PresentationGroupCallMemberEvent>()
    public var memberEvents: Signal<PresentationGroupCallMemberEvent, NoError> {
        return self.memberEventsPipe.signal()
    }
    private let memberEventsPipeDisposable = MetaDisposable()

    private let reconnectedAsEventsPipe = ValuePipe<Peer>()
    public var reconnectedAsEvents: Signal<Peer, NoError> {
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
    private var toneRenderer: PresentationCallToneRenderer?
    
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
    
    private var screencastFramesDisposable: Disposable?
    private var screencastAudioDataDisposable: Disposable?
    private var screencastStateDisposable: Disposable?
    
    public let isStream: Bool
    
    init(
        accountContext: AccountContext,
        audioSession: ManagedAudioSession,
        callKitIntegration: CallKitIntegration?,
        getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void),
        initialCall: EngineGroupCallDescription?,
        internalId: CallSessionInternalId,
        peerId: PeerId,
        isChannel: Bool,
        invite: String?,
        joinAsPeerId: PeerId?,
        isStream: Bool
    ) {
        self.account = accountContext.account
        self.accountContext = accountContext
        self.audioSession = audioSession
        self.callKitIntegration = callKitIntegration
        self.getDeviceAccessData = getDeviceAccessData
        
        self.initialCall = initialCall
        self.internalId = internalId
        self.peerId = peerId
        self.isChannel = isChannel
        self.invite = invite
        self.joinAsPeerId = joinAsPeerId ?? accountContext.account.peerId
        self.schedulePending = initialCall == nil
        self.isScheduled = initialCall == nil || initialCall?.scheduleTimestamp != nil
        
        self.stateValue = PresentationGroupCallState.initialValue(myPeerId: self.joinAsPeerId, title: initialCall?.title, scheduleTimestamp: initialCall?.scheduleTimestamp, subscribedToScheduled: initialCall?.subscribedToScheduled ?? false)
        self.statePromise = ValuePromise(self.stateValue)
        
        self.temporaryJoinTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)

        self.isVideoEnabled = true
        self.hasVideo = false
        self.hasScreencast = false
        self.isStream = isStream
        
        var didReceiveAudioOutputs = false
        
        if !audioSession.getIsHeadsetPluggedIn() {
            self.currentSelectedAudioOutputValue = .speaker
            self.audioOutputStatePromise.set(.single(([], .speaker)))
        }
        
        self.audioSessionDisposable = audioSession.push(audioSessionType: self.isStream ? .play : .voiceCall, activateImmediately: true, manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.updateSessionState(internalState: strongSelf.internalState, audioSessionControl: control)
                }
            }
        }, deactivate: { [weak self] _ in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateIsAudioSessionActive(false)
                        strongSelf.updateSessionState(internalState: strongSelf.internalState, audioSessionControl: nil)
                        
                        if strongSelf.isStream {
                            let _ = strongSelf.leave(terminateIfPossible: false)
                        }
                    }
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }, availableOutputsChanged: { [weak self] availableOutputs, currentOutput in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.audioOutputStateValue = (availableOutputs, currentOutput)
                
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
                strongSelf.audioOutputStatePromise.set(signal)
            }
        })
        
        self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if value {
                if let audioSessionControl = strongSelf.audioSessionControl {
                    if !strongSelf.isStream, let callKitIntegration = strongSelf.callKitIntegration {
                        _ = callKitIntegration.audioSessionActive
                        |> filter { $0 }
                        |> timeout(2.0, queue: Queue.mainQueue(), alternate: Signal { subscriber in
                            subscriber.putNext(true)
                            subscriber.putCompletion()
                            return EmptyDisposable
                        })
                    } else {
                        audioSessionControl.activate({ _ in
                            Queue.mainQueue().async {
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.audioSessionActive.set(.single(true))
                            }
                        })
                    }
                } else {
                    strongSelf.audioSessionActive.set(.single(false))
                }
            } else {
                strongSelf.audioSessionActive.set(.single(false))
            }
        })
        
        self.audioSessionActiveDisposable = (self.audioSessionActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateIsAudioSessionActive(value)
            }
        })
        
        self.audioOutputStateDisposable = (self.audioOutputStatePromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] availableOutputs, currentOutput in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateAudioOutputs(availableOutputs: availableOutputs, currentOutput: currentOutput)
        })
        
        self.groupCallParticipantUpdatesDisposable = (self.account.stateManager.groupCallParticipantUpdates
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let strongSelf = self else {
                return
            }
            if case let .established(callInfo, _, _, _, _) = strongSelf.internalState {
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
                                    
                                    if participantUpdate.peerId == strongSelf.joinAsPeerId {
                                        if case let .established(_, _, _, ssrc, _) = strongSelf.internalState, ssrc == participantUpdate.ssrc {
                                            strongSelf.markAsCanBeRemoved()
                                        }
                                    }
                                } else if participantUpdate.peerId == strongSelf.joinAsPeerId {
                                    if case let .established(_, connectionMode, _, ssrc, _) = strongSelf.internalState {
                                        if ssrc != participantUpdate.ssrc {
                                            strongSelf.markAsCanBeRemoved()
                                        } else if case .broadcast = connectionMode {
                                            let canUnmute: Bool
                                            if let muteState = participantUpdate.muteState {
                                                canUnmute = muteState.canUnmute
                                            } else {
                                                canUnmute = true
                                            }
                                            
                                            if canUnmute {
                                                strongSelf.requestCall(movingFromBroadcastToRtc: true)
                                            }
                                        }
                                    }
                                } else if case .joined = participantUpdate.participationStatusChange {
                                } else if let ssrc = participantUpdate.ssrc, strongSelf.ssrcMapping[ssrc] == nil {
                                }
                            }
                        case let .call(isTerminated, _, _, _, _, _, _):
                            if isTerminated {
                                strongSelf.markAsCanBeRemoved()
                            }
                        }
                    }
                }
                if !removedSsrc.isEmpty {
                    if case let .call(callContext) = strongSelf.genericCallContext {
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
        
        if let initialCall = initialCall, let temporaryParticipantsContext = (self.accountContext.cachedGroupCallContexts as? AccountGroupCallContextCacheImpl)?.impl.syncWith({ impl in
            impl.get(account: accountContext.account, engine: accountContext.engine, peerId: peerId, isChannel: isChannel, call: EngineGroupCallDescription(id: initialCall.id, accessHash: initialCall.accessHash, title: initialCall.title, scheduleTimestamp: initialCall.scheduleTimestamp, subscribedToScheduled: initialCall.subscribedToScheduled, isStream: initialCall.isStream))
        }) {
            self.switchToTemporaryParticipantsContext(sourceContext: temporaryParticipantsContext.context.participantsContext, oldMyPeerId: self.joinAsPeerId)
        } else {
            self.switchToTemporaryParticipantsContext(sourceContext: nil, oldMyPeerId: self.joinAsPeerId)
        }
        
        self.removedChannelMembersDisposable = (accountContext.peerChannelMemberCategoriesContextsManager.removedChannelMembers
        |> deliverOnMainQueue).start(next: { [weak self] pairs in
            guard let strongSelf = self else {
                return
            }
            for (channelId, memberId) in pairs {
                if channelId == strongSelf.peerId {
                    strongSelf.removedPeer(memberId)
                }
            }
        })
        
        let _ = (self.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self else {
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
                strongSelf.peerUpdatesSubscription = strongSelf.accountContext.account.viewTracker.polledChannel(peerId: peer.id).start()
            }
            var updatedValue = strongSelf.stateValue
            updatedValue.canManageCall = canManageCall
            strongSelf.stateValue = updatedValue
        })
        
        if let _ = self.initialCall {
            self.requestCall(movingFromBroadcastToRtc: false)
        }

        let basePath = self.accountContext.sharedContext.basePath + "/broadcast-coordination"
        let screencastBufferServerContext = IpcGroupCallBufferAppContext(basePath: basePath)
        self.screencastBufferServerContext = screencastBufferServerContext
        let screencastCapturer = OngoingCallVideoCapturer(isCustom: true)
        self.screencastCapturer = screencastCapturer
        self.screencastFramesDisposable = (screencastBufferServerContext.frames
        |> deliverOnMainQueue).start(next: { [weak screencastCapturer] screencastFrame in
            guard let screencastCapturer = screencastCapturer else {
                return
            }
            screencastCapturer.injectPixelBuffer(screencastFrame.0, rotation: screencastFrame.1)
        })
        self.screencastAudioDataDisposable = (screencastBufferServerContext.audioData
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let strongSelf = self else {
                return
            }
            strongSelf.screencastCallContext?.addExternalAudioData(data: data)
        })
        self.screencastStateDisposable = (screencastBufferServerContext.isActive
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] isActive in
            guard let strongSelf = self else {
                return
            }
            if isActive {
                strongSelf.requestScreencast()
            } else {
                strongSelf.disableScreencast()
            }
        })

        /*Queue.mainQueue().after(2.0, { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.screencastBufferClientContext = IpcGroupCallBufferBroadcastContext(basePath: basePath)
        })*/
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
        
        self.myAudioLevelTimer?.invalidate()
        self.typingDisposable.dispose()
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
        
        self.audioOutputStateDisposable?.dispose()
        
        self.removedChannelMembersDisposable?.dispose()

        self.peerUpdatesSubscription?.dispose()

        self.screencastFramesDisposable?.dispose()
        self.screencastAudioDataDisposable?.dispose()
        self.screencastStateDisposable?.dispose()
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
            let temporaryParticipantsContext = self.accountContext.engine.calls.groupCall(peerId: self.peerId, myPeerId: myPeerId, id: sourceContext.id, accessHash: sourceContext.accessHash, state: initialState, previousServiceState: sourceContext.serviceState)
            self.temporaryParticipantsContext = temporaryParticipantsContext
            self.participantsContextStateDisposable.set((combineLatest(queue: .mainQueue(),
                myPeerData,
                temporaryParticipantsContext.state,
                temporaryParticipantsContext.activeSpeakers
            )
            |> take(1)).start(next: { [weak self] myPeerData, state, activeSpeakers in
                guard let strongSelf = self else {
                    return
                }
                
                var topParticipants: [GroupCallParticipantsContext.Participant] = []

                var members = PresentationGroupCallMembers(
                    participants: [],
                    speakingParticipants: [],
                    totalCount: 0,
                    loadMoreToken: nil
                )

                var updatedInvitedPeers = strongSelf.invitedPeersValue
                var didUpdateInvitedPeers = false

                var participants = state.participants

                if oldMyPeerId != myPeerId {
                    for i in 0 ..< participants.count {
                        if participants[i].peer.id == oldMyPeerId {
                            participants.remove(at: i)
                            break
                        }
                    }
                }

                if !participants.contains(where: { $0.peer.id == myPeerId }) {
                    if let (myPeer, aboutText) = myPeerData {
                        let about: String?
                        if let aboutText = aboutText {
                            about = aboutText
                        } else {
                            about = " "
                        }
                        participants.append(GroupCallParticipantsContext.Participant(
                            peer: myPeer._asPeer(),
                            ssrc: nil,
                            videoDescription: nil,
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: strongSelf.temporaryRaiseHandRating,
                            hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                            activityTimestamp: strongSelf.temporaryActivityTimestamp,
                            activityRank: strongSelf.temporaryActivityRank,
                            muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                            volume: nil,
                            about: about,
                            joinedVideo: strongSelf.temporaryJoinedVideo
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                    }
                }

                for participant in participants {
                    members.participants.append(participant)

                    if topParticipants.count < 3 {
                        topParticipants.append(participant)
                    }

                    if let index = updatedInvitedPeers.firstIndex(of: participant.peer.id) {
                        updatedInvitedPeers.remove(at: index)
                        didUpdateInvitedPeers = true
                    }
                }

                members.totalCount = state.totalCount
                members.loadMoreToken = state.nextParticipantsFetchOffset

                strongSelf.membersValue = members

                var stateValue = strongSelf.stateValue
                stateValue.myPeerId = strongSelf.joinAsPeerId
                stateValue.adminIds = state.adminIds

                strongSelf.stateValue = stateValue

                strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                    participantCount: state.totalCount,
                    topParticipants: topParticipants,
                    activeSpeakers: activeSpeakers
                )))

                if didUpdateInvitedPeers {
                    strongSelf.invitedPeersValue = updatedInvitedPeers
                }
            }))
        } else {
            self.temporaryParticipantsContext = nil
            self.participantsContextStateDisposable.set((myPeerData
            |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] myPeerData in
                guard let strongSelf = self else {
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
                        peer: myPeer._asPeer(),
                        ssrc: nil,
                        videoDescription: nil,
                        presentationDescription: nil,
                        joinTimestamp: strongSelf.temporaryJoinTimestamp,
                        raiseHandRating: strongSelf.temporaryRaiseHandRating,
                        hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                        activityTimestamp: strongSelf.temporaryActivityTimestamp,
                        activityRank: strongSelf.temporaryActivityRank,
                        muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                        volume: nil,
                        about: about,
                        joinedVideo: strongSelf.temporaryJoinedVideo
                    ))
                }

                for participant in participants {
                    members.participants.append(participant)

                    if topParticipants.count < 3 {
                        topParticipants.append(participant)
                    }
                }

                strongSelf.membersValue = members

                var stateValue = strongSelf.stateValue
                stateValue.myPeerId = strongSelf.joinAsPeerId

                strongSelf.stateValue = stateValue
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
        
        let adminIds = combineLatest(queue: .mainQueue(),
            rawAdminIds,
            accountContext.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        )
        |> map { rawAdminIds, peer -> Set<PeerId> in
            var rawAdminIds = rawAdminIds
            if case let .channel(peer) = peer {
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
            accessHash: callInfo.accessHash,
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
            previousServiceState: nil
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
        
        self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
            participantsContext.state,
            adminIds,
            myPeerData,
            accountContext.account.postbox.peerView(id: peerId)
        ).start(next: { [weak self] state, adminIds, myPeerData, view in
            guard let strongSelf = self else {
                return
            }
            
            var members = PresentationGroupCallMembers(
                participants: [],
                speakingParticipants: Set(),
                totalCount: state.totalCount,
                loadMoreToken: state.nextParticipantsFetchOffset
            )
            
            strongSelf.stateValue.adminIds = adminIds
            let canManageCall = state.isCreator || strongSelf.stateValue.adminIds.contains(strongSelf.accountContext.account.peerId)
            
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
                    peer: myPeer._asPeer(),
                    ssrc: nil,
                    videoDescription: nil,
                    presentationDescription: nil,
                    joinTimestamp: strongSelf.temporaryJoinTimestamp,
                    raiseHandRating: strongSelf.temporaryRaiseHandRating,
                    hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                    activityTimestamp: strongSelf.temporaryActivityTimestamp,
                    activityRank: strongSelf.temporaryActivityRank,
                    muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: canManageCall || !state.defaultParticipantsAreMuted.isMuted, mutedByYou: false),
                    volume: nil,
                    about: about,
                    joinedVideo: strongSelf.temporaryJoinedVideo
                ))
            }

            for participant in participants {
                members.participants.append(participant)

                if topParticipants.count < 3 {
                    topParticipants.append(participant)
                }
            }
            
            strongSelf.membersValue = members
            strongSelf.stateValue.canManageCall = state.isCreator || adminIds.contains(strongSelf.accountContext.account.peerId)
            strongSelf.stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
            
            
            strongSelf.stateValue.recordingStartTimestamp = state.recordingStartTimestamp
            strongSelf.stateValue.title = state.title
            strongSelf.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: canManageCall || !state.defaultParticipantsAreMuted.isMuted, mutedByYou: false)
        
            strongSelf.stateValue.subscribedToScheduled = state.subscribedToScheduled
            strongSelf.stateValue.scheduleTimestamp = strongSelf.isScheduledStarted ? nil : state.scheduleTimestamp
            if state.scheduleTimestamp == nil && !strongSelf.isScheduledStarted {
                strongSelf.updateSessionState(internalState: .active(GroupCallInfo(id: callInfo.id, accessHash: callInfo.accessHash, participantCount: state.totalCount, streamDcId: callInfo.streamDcId, title: state.title, scheduleTimestamp: nil, subscribedToScheduled: false, recordingStartTimestamp: nil, sortAscending: true, defaultParticipantsAreMuted: callInfo.defaultParticipantsAreMuted ?? state.defaultParticipantsAreMuted, isVideoEnabled: callInfo.isVideoEnabled, unmutedVideoLimit: callInfo.unmutedVideoLimit, isStream: callInfo.isStream)), audioSessionControl: strongSelf.audioSessionControl)
            } else {
                strongSelf.summaryInfoState.set(.single(SummaryInfoState(info: GroupCallInfo(
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
                    isStream: callInfo.isStream
                ))))
                
                strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
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
        
        if let audioSessionControl = audioSessionControl, previousControl == nil {
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
                if self.isStream, !"".isEmpty {
                    genericCallContext = .mediaStream(WrappedMediaStreamingContext(rejoinNeeded: { [weak self] in
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.leaving {
                                return
                            }
                            if case .established = strongSelf.internalState {
                                strongSelf.requestCall(movingFromBroadcastToRtc: false)
                            }
                        }
                    }))
                } else {
                    var outgoingAudioBitrateKbit: Int32?
                    let appConfiguration = self.accountContext.currentAppConfiguration.with({ $0 })
                    if let data = appConfiguration.data, let value = data["voice_chat_send_bitrate"] as? Double {
                        outgoingAudioBitrateKbit = Int32(value)
                    }

                    genericCallContext = .call(OngoingGroupCallContext(video: self.videoCapturer, requestMediaChannelDescriptions: { [weak self] ssrcs, completion in
                        let disposable = MetaDisposable()
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            disposable.set(strongSelf.requestMediaChannelDescriptions(ssrcs: ssrcs, completion: completion))
                        }
                        return disposable
                    }, rejoinNeeded: { [weak self] in
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            if case .established = strongSelf.internalState {
                                strongSelf.requestCall(movingFromBroadcastToRtc: false)
                            }
                        }
                    }, outgoingAudioBitrateKbit: outgoingAudioBitrateKbit, videoContentType: self.isVideoEnabled ? .generic : .none, enableNoiseSuppression: false, disableAudioInput: self.isStream, preferX264: self.accountContext.sharedContext.immediateExperimentalUISettings.preferredVideoCodec == "H264", logPath: allocateCallLogPath(account: self.account)
                    ))
                }

                self.genericCallContext = genericCallContext
                self.stateVersionValue += 1
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
                guard let strongSelf = self else {
                    return
                }

                let peerAdminIds: Signal<[PeerId], NoError>
                let peerId = strongSelf.peerId
                if strongSelf.peerId.namespace == Namespaces.Peer.CloudChannel {
                    peerAdminIds = Signal { subscriber in
                        let (disposable, _) = strongSelf.accountContext.peerChannelMemberCategoriesContextsManager.admins(engine: strongSelf.accountContext.engine, postbox: strongSelf.accountContext.account.postbox, network: strongSelf.accountContext.account.network, accountPeerId: strongSelf.accountContext.account.peerId, peerId: peerId, updated: { list in
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
                    peerAdminIds = strongSelf.accountContext.engine.data.get(
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

                strongSelf.currentLocalSsrc = ssrc
                strongSelf.requestDisposable.set((strongSelf.accountContext.engine.calls.joinGroupCall(
                    peerId: strongSelf.peerId,
                    joinAs: strongSelf.joinAsPeerId,
                    callId: callInfo.id,
                    accessHash: callInfo.accessHash,
                    preferMuted: true,
                    joinPayload: joinPayload,
                    peerAdminIds: peerAdminIds,
                    inviteHash: strongSelf.invite
                )
                |> deliverOnMainQueue).start(next: { joinCallResult in
                    guard let strongSelf = self else {
                        return
                    }
                    let clientParams = joinCallResult.jsonParams
                    if let data = clientParams.data(using: .utf8), let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
                        if let video = dict["video"] as? [String: Any] {
                            if let endpointId = video["endpoint"] as? String {
                                strongSelf.currentLocalEndpointId = endpointId
                            }
                        }
                    }

                    strongSelf.ssrcMapping.removeAll()
                    for participant in joinCallResult.state.participants {
                        if let ssrc = participant.ssrc {
                            strongSelf.ssrcMapping[ssrc] = SsrcMapping(peerId: participant.peer.id, isPresentation: false)
                        }
                        if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                            strongSelf.ssrcMapping[presentationSsrc] = SsrcMapping(peerId: participant.peer.id, isPresentation: true)
                        }
                    }

                    if let genericCallContext = strongSelf.genericCallContext {
                        switch genericCallContext {
                        case let .call(callContext):
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                strongSelf.currentConnectionMode = .rtc
                                callContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
                                callContext.setJoinResponse(payload: clientParams)
                            case .broadcast:
                                strongSelf.currentConnectionMode = .broadcast
                                callContext.setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData(engine: strongSelf.accountContext.engine, callId: callInfo.id, accessHash: callInfo.accessHash, isExternalStream: callInfo.isStream))
                                callContext.setConnectionMode(.broadcast, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: callInfo.isStream)
                            }
                        case let .mediaStream(mediaStreamContext):
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                strongSelf.currentConnectionMode = .rtc
                            case .broadcast:
                                strongSelf.currentConnectionMode = .broadcast
                                mediaStreamContext.setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData(engine: strongSelf.accountContext.engine, callId: callInfo.id, accessHash: callInfo.accessHash, isExternalStream: callInfo.isStream))
                            }
                        }
                    }

                    strongSelf.updateSessionState(internalState: .established(info: joinCallResult.callInfo, connectionMode: joinCallResult.connectionMode, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state), audioSessionControl: strongSelf.audioSessionControl)
                }, error: { error in
                    guard let strongSelf = self else {
                        return
                    }
                    if case .anonymousNotAllowed = error {
                        let presentationData = strongSelf.accountContext.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: strongSelf.isChannel ? presentationData.strings.LiveStream_AnonymousDisabledAlertText : presentationData.strings.VoiceChat_AnonymousDisabledAlertText, actions: [
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                        ]), on: .root, blockInteraction: false, completion: {})
                    } else if case .tooManyParticipants = error {
                        let presentationData = strongSelf.accountContext.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: strongSelf.isChannel ? presentationData.strings.LiveStream_ChatFullAlertText : presentationData.strings.VoiceChat_ChatFullAlertText, actions: [
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                        ]), on: .root, blockInteraction: false, completion: {})
                    } else if case .invalidJoinAsPeer = error {
                        let peerId = strongSelf.peerId
                        let _ = strongSelf.accountContext.engine.calls.clearCachedGroupCallDisplayAsAvailablePeers(peerId: peerId).start()
                    }
                    strongSelf.markAsCanBeRemoved()
                }))
            }))
            
            self.networkStateDisposable.set((genericCallContext.networkState
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                let mappedState: PresentationGroupCallState.NetworkState
                if state.isConnected {
                    mappedState = .connected
                } else {
                    mappedState = .connecting
                }

                let wasConnecting = strongSelf.stateValue.networkState == .connecting
                if strongSelf.stateValue.networkState != mappedState {
                    strongSelf.stateValue.networkState = mappedState
                }
                let isConnecting = mappedState == .connecting
                
                if strongSelf.isCurrentlyConnecting != isConnecting {
                    strongSelf.isCurrentlyConnecting = isConnecting
                    if isConnecting {
                        strongSelf.startCheckingCallIfNeeded()
                    } else {
                        strongSelf.checkCallDisposable?.dispose()
                        strongSelf.checkCallDisposable = nil
                    }
                }

                strongSelf.isReconnectingAsSpeaker = state.isTransitioningFromBroadcastToRtc
                
                if (wasConnecting != isConnecting && strongSelf.didConnectOnce) {
                    if isConnecting {
                        strongSelf.beginTone(tone: .groupConnecting)
                    } else {
                        strongSelf.toneRenderer = nil
                    }
                }
                
                if isConnecting {
                    strongSelf.didStartConnectingOnce = true
                }
                
                if state.isConnected {
                    if !strongSelf.didConnectOnce {
                        strongSelf.didConnectOnce = true
                        
                        if !strongSelf.isScheduled {
                            strongSelf.beginTone(tone: .groupJoined)
                        }
                    }

                    if let peer = strongSelf.reconnectingAsPeer {
                        strongSelf.reconnectingAsPeer = nil
                        strongSelf.reconnectedAsEventsPipe.putNext(peer)
                    }
                }
            }))

            self.isNoiseSuppressionEnabledDisposable.set((genericCallContext.isNoiseSuppressionEnabled
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isNoiseSuppressionEnabledPromise.set(value)
            }))
            
            self.audioLevelsDisposable.set((genericCallContext.audioLevels
            |> deliverOnMainQueue).start(next: { [weak self] levels in
                guard let strongSelf = self else {
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
                        peerId = strongSelf.joinAsPeerId
                        ssrcValue = 0
                    case let .source(ssrc):
                        if let mapping = strongSelf.ssrcMapping[ssrc] {
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
                
                strongSelf.speakingParticipantsContext.update(levels: result)
                
                let mappedLevel = myLevel * 1.5
                strongSelf.myAudioLevelPipe.putNext(mappedLevel)
                strongSelf.processMyAudioLevel(level: mappedLevel, hasVoice: myLevelHasVoice)
                strongSelf.isSpeakingPromise.set(orignalMyLevelHasVoice)
                
                if !missingSsrcs.isEmpty && !strongSelf.isStream {
                    strongSelf.participantsContext?.ensureHaveParticipants(ssrcs: missingSsrcs)
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
                
                let adminIds = combineLatest(queue: .mainQueue(),
                    rawAdminIds,
                    accountContext.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                )
                |> map { rawAdminIds, peer -> Set<PeerId> in
                    var rawAdminIds = rawAdminIds
                    if case let .channel(peer) = peer {
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
                
                let participantsContext = self.accountContext.engine.calls.groupCall(
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: initialState,
                    previousServiceState: serviceState
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
                
                let chatPeer = self.accountContext.account.postbox.peerView(id: self.peerId)
                |> map { view -> Peer? in
                    if let peer = peerViewMainPeer(view) {
                        return peer
                    } else {
                        return nil
                    }
                }
                
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    participantsContext.activeSpeakers,
                    self.speakingParticipantsContext.get(),
                    adminIds,
                    myPeer,
                    chatPeer,
                    accountContext.account.postbox.peerView(id: peerId),
                    self.isReconnectingAsSpeakerPromise.get()
                ).start(next: { [weak self] state, activeSpeakers, speakingParticipants, adminIds, myPeerAndCachedData, chatPeer, view, isReconnectingAsSpeaker in
                    guard let strongSelf = self else {
                        return
                    }
                    let appConfiguration = strongSelf.accountContext.currentAppConfiguration.with({ $0 })
                    let configuration = VoiceChatConfiguration.with(appConfiguration: appConfiguration)
                    
                    strongSelf.participantsContext?.updateAdminIds(adminIds)
                    
                    var topParticipants: [GroupCallParticipantsContext.Participant] = []
                    
                    var reportSpeakingParticipants: [PeerId: UInt32] = [:]
                    let timestamp = CACurrentMediaTime()
                    for (peerId, ssrc) in speakingParticipants {
                        let shouldReport: Bool
                        if let previousTimestamp = strongSelf.speakingParticipantsReportTimestamp[peerId] {
                            shouldReport = previousTimestamp + 1.0 < timestamp
                        } else {
                            shouldReport = true
                        }
                        if shouldReport {
                            strongSelf.speakingParticipantsReportTimestamp[peerId] = timestamp
                            reportSpeakingParticipants[peerId] = ssrc
                        }
                    }
                    
                    if !reportSpeakingParticipants.isEmpty {
                        Queue.mainQueue().justDispatch {
                            self?.participantsContext?.reportSpeakingParticipants(ids: reportSpeakingParticipants)
                        }
                    }
                    
                    var members = PresentationGroupCallMembers(
                        participants: [],
                        speakingParticipants: Set(speakingParticipants.keys),
                        totalCount: 0,
                        loadMoreToken: nil
                    )
                    
                    var updatedInvitedPeers = strongSelf.invitedPeersValue
                    var didUpdateInvitedPeers = false

                    var participants = state.participants

                    if let (ignorePeerId, ignoreSsrc) = strongSelf.ignorePreviousJoinAsPeerId {
                        for i in 0 ..< participants.count {
                            if participants[i].peer.id == ignorePeerId && participants[i].ssrc == ignoreSsrc {
                                participants.remove(at: i)
                                break
                            }
                        }
                    }

                    if !participants.contains(where: { $0.peer.id == myPeerId }) && !strongSelf.leaving {
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
                                peer: myPeer,
                                ssrc: nil,
                                videoDescription: nil,
                                presentationDescription: nil,
                                joinTimestamp: strongSelf.temporaryJoinTimestamp,
                                raiseHandRating: strongSelf.temporaryRaiseHandRating,
                                hasRaiseHand: strongSelf.temporaryHasRaiseHand,
                                activityTimestamp: strongSelf.temporaryActivityTimestamp,
                                activityRank: strongSelf.temporaryActivityRank,
                                muteState: strongSelf.temporaryMuteState ?? GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                                volume: nil,
                                about: about,
                                joinedVideo: strongSelf.temporaryJoinedVideo
                            ))
                            participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                        }
                    }
                    
                    /*if let chatPeer = chatPeer, !participants.contains(where: { $0.peer.id == chatPeer.id }) {
                        participants.append(GroupCallParticipantsContext.Participant(
                            peer: chatPeer,
                            ssrc: 100,
                            videoDescription: GroupCallParticipantsContext.Participant.VideoDescription(
                                endpointId: "unified",
                                ssrcGroups: [],
                                audioSsrc: 100,
                                isPaused: false
                            ),
                            presentationDescription: nil,
                            joinTimestamp: strongSelf.temporaryJoinTimestamp,
                            raiseHandRating: nil,
                            hasRaiseHand: false,
                            activityTimestamp: nil,
                            activityRank: nil,
                            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false),
                            volume: nil,
                            about: nil,
                            joinedVideo: false
                        ))
                        participants.sort(by: { GroupCallParticipantsContext.Participant.compare(lhs: $0, rhs: $1, sortAscending: state.sortAscending) })
                    }*/

                    var otherParticipantsWithVideo = 0
                    var videoWatchingParticipants = 0
                    
                    for participant in participants {
                        var participant = participant
                        
                        if topParticipants.count < 3 {
                            topParticipants.append(participant)
                        }
                        
                        if let ssrc = participant.ssrc {
                            strongSelf.ssrcMapping[ssrc] = SsrcMapping(peerId: participant.peer.id, isPresentation: false)
                        }
                        if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                            strongSelf.ssrcMapping[presentationSsrc] = SsrcMapping(peerId: participant.peer.id, isPresentation: true)
                        }
                        
                        if participant.peer.id == strongSelf.joinAsPeerId {
                            if let (myPeer, cachedData) = myPeerAndCachedData {
                                let about: String?
                                if let cachedData = cachedData as? CachedUserData {
                                    about = cachedData.about
                                } else if let cachedData = cachedData as? CachedChannelData {
                                    about = cachedData.about
                                } else {
                                    about = " "
                                }
                                participant.peer = myPeer
                                participant.about = about
                            }
                        
                            var filteredMuteState = participant.muteState
                            if isReconnectingAsSpeaker || strongSelf.currentConnectionMode != .rtc {
                                filteredMuteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false)
                                participant.muteState = filteredMuteState
                            }

                            let previousRaisedHand = strongSelf.stateValue.raisedHand
                            if !(strongSelf.stateValue.muteState?.canUnmute ?? false) {
                                strongSelf.stateValue.raisedHand = participant.hasRaiseHand
                            }
                            
                            if let muteState = participant.muteState, muteState.canUnmute && previousRaisedHand { 
                                let _ = (strongSelf.accountContext.sharedContext.hasGroupCallOnScreen
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { hasGroupCallOnScreen in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let presentationData = strongSelf.accountContext.sharedContext.currentPresentationData.with { $0 }
                                    if !hasGroupCallOnScreen {
                                        let title: String?
                                        if let voiceChatTitle = strongSelf.stateValue.title {
                                            title = voiceChatTitle
                                        } else if let peer = peerViewMainPeer(view) {
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
                                        strongSelf.accountContext.sharedContext.mainWindow?.present(UndoOverlayController(presentationData: presentationData, content: .voiceChatCanSpeak(text: text), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return true }), on: .root, blockInteraction: false, completion: {})
                                        strongSelf.playTone(.unmuted)
                                    }
                                })
                            }

                            if let muteState = filteredMuteState {
                                if muteState.canUnmute {
                                    switch strongSelf.isMutedValue {
                                    case let .muted(isPushToTalkActive):
                                        if !isPushToTalkActive {
                                            strongSelf.genericCallContext?.setIsMuted(true)
                                        }
                                    case .unmuted:
                                        strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                        strongSelf.genericCallContext?.setIsMuted(true)
                                    }
                                } else {
                                    strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                    strongSelf.genericCallContext?.setIsMuted(true)
                                }
                                strongSelf.stateValue.muteState = muteState
                            } else if let currentMuteState = strongSelf.stateValue.muteState, !currentMuteState.canUnmute {
                                strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                strongSelf.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                                strongSelf.genericCallContext?.setIsMuted(true)
                            }
                            
                            if participant.joinedVideo {
                                videoWatchingParticipants += 1
                            }
                        } else {
                            if let ssrc = participant.ssrc {
                                if let volume = participant.volume {
                                    strongSelf.genericCallContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    strongSelf.genericCallContext?.setVolume(ssrc: ssrc, volume: 0.0)
                                }
                            }
                            if let presentationSsrc = participant.presentationDescription?.audioSsrc {
                                if let volume = participant.volume {
                                    strongSelf.genericCallContext?.setVolume(ssrc: presentationSsrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    strongSelf.genericCallContext?.setVolume(ssrc: presentationSsrc, volume: 0.0)
                                }
                            }

                            if participant.videoDescription != nil || participant.presentationDescription != nil {
                                otherParticipantsWithVideo += 1
                            }
                            if participant.joinedVideo {
                                videoWatchingParticipants += 1
                            }
                        }
                        
                        if let index = updatedInvitedPeers.firstIndex(of: participant.peer.id) {
                            updatedInvitedPeers.remove(at: index)
                            didUpdateInvitedPeers = true
                        }

                        members.participants.append(participant)
                    }
                    
                    members.totalCount = state.totalCount
                    members.loadMoreToken = state.nextParticipantsFetchOffset
                    
                    strongSelf.membersValue = members
                    
                    strongSelf.stateValue.adminIds = adminIds
                    
                    strongSelf.stateValue.canManageCall = state.isCreator || adminIds.contains(strongSelf.accountContext.account.peerId)
                    if (state.isCreator || strongSelf.stateValue.adminIds.contains(strongSelf.accountContext.account.peerId)) && state.defaultParticipantsAreMuted.canChange {
                        strongSelf.stateValue.defaultParticipantMuteState = state.defaultParticipantsAreMuted.isMuted ? .muted : .unmuted
                    }
                    strongSelf.stateValue.recordingStartTimestamp = state.recordingStartTimestamp
                    strongSelf.stateValue.title = state.title
                    strongSelf.stateValue.scheduleTimestamp = state.scheduleTimestamp
                    strongSelf.stateValue.isVideoEnabled = state.isVideoEnabled && otherParticipantsWithVideo < state.unmutedVideoLimit
                    strongSelf.stateValue.isVideoWatchersLimitReached = videoWatchingParticipants >= configuration.videoParticipantsMaxCount
                    
                    strongSelf.summaryInfoState.set(.single(SummaryInfoState(info: GroupCallInfo(
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
                        isStream: callInfo.isStream
                    ))))
                    
                    strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                        participantCount: state.totalCount,
                        topParticipants: topParticipants,
                        activeSpeakers: activeSpeakers
                    )))
                    
                    if didUpdateInvitedPeers {
                        strongSelf.invitedPeersValue = updatedInvitedPeers
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
                            return .single(PresentationGroupCallMemberEvent(peer: peer._asPeer(), isContact: isContact, isInChatList: isInChatList, canUnmute: event.canUnmute, joined: event.joined))
                        } else {
                            return .complete()
                        }
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] event in
                    guard let strongSelf = self, event.peer.id != strongSelf.stateValue.myPeerId else {
                        return
                    }
                    var skip = false
                    if let participantsCount = strongSelf.participantsContext?.immediateState?.totalCount, participantsCount >= 250 {
                        if event.peer.isVerified || event.isContact || event.isInChatList || (strongSelf.stateValue.defaultParticipantMuteState == .muted && event.canUnmute) {
                            skip = false
                        } else {
                            skip = true
                        }
                    }
                    if !skip {
                        strongSelf.memberEventsPipe.putNext(event)
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
    
    private func requestMediaChannelDescriptions(ssrcs: Set<UInt32>, completion: @escaping ([OngoingGroupCallContext.MediaChannelDescription]) -> Void) -> Disposable {
        func extractMediaChannelDescriptions(remainingSsrcs: inout Set<UInt32>, participants: [GroupCallParticipantsContext.Participant], into result: inout [OngoingGroupCallContext.MediaChannelDescription]) {
            for participant in participants {
                guard let audioSsrc = participant.ssrc else {
                    continue
                }

                if remainingSsrcs.contains(audioSsrc) {
                    remainingSsrcs.remove(audioSsrc)

                    result.append(OngoingGroupCallContext.MediaChannelDescription(
                        kind: .audio,
                        audioSsrc: audioSsrc,
                        videoDescription: nil
                    ))
                }

                if let screencastSsrc = participant.presentationDescription?.audioSsrc {
                    if remainingSsrcs.contains(screencastSsrc) {
                        remainingSsrcs.remove(screencastSsrc)

                        result.append(OngoingGroupCallContext.MediaChannelDescription(
                            kind: .audio,
                            audioSsrc: screencastSsrc,
                            videoDescription: nil
                        ))
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
            return (self.accountContext.engine.calls.getGroupCallParticipants(callId: callInfo.id, accessHash: callInfo.accessHash, offset: "", ssrcs: Array(remainingSsrcs), limit: 100, sortAscending: callInfo.sortAscending)
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
                guard let strongSelf = self else {
                    return
                }
                strongSelf.checkCallDisposable = nil
                strongSelf.requestCall(movingFromBroadcastToRtc: false)
            })
        }
    }
    
    private func updateIsAudioSessionActive(_ value: Bool) {
        if self.isAudioSessionActive != value {
            self.isAudioSessionActive = value
            self.toneRenderer?.setAudioSessionActive(value)
        }
    }

    private func beginTone(tone: PresentationCallTone) {
        if self.isStream {
            switch tone {
            case .groupJoined, .groupLeft:
                return
            default:
                break
            }
        }
        var completed: (() -> Void)?
        let toneRenderer = PresentationCallToneRenderer(tone: tone, completed: {
            completed?()
        })
        completed = { [weak self, weak toneRenderer] in
            Queue.mainQueue().async {
                guard let strongSelf = self, let toneRenderer = toneRenderer, toneRenderer === strongSelf.toneRenderer else {
                    return
                }
                strongSelf.toneRenderer = nil
            }
        }

        self.toneRenderer = toneRenderer
        toneRenderer.setAudioSessionActive(self.isAudioSessionActive)
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

        self.genericCallContext?.stop()

        //self.screencastIpcContext = nil
        self.screencastCallContext?.stop()

        self._canBeRemoved.set(.single(true))
        
        if self.didConnectOnce {
            if let callManager = self.accountContext.sharedContext.callManager {
                let _ = (callManager.currentGroupCallSignal
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] call in
                    guard let strongSelf = self else {
                        return
                    }
                    if let call = call, call !== strongSelf {
                        strongSelf.wasRemoved.set(.single(true))
                        return
                    }

                    strongSelf.beginTone(tone: .groupLeft)
                    
                    Queue.mainQueue().after(1.0, {
                        strongSelf.wasRemoved.set(.single(true))
                    })
                })
            }
        }
    }
    
    public func reconnect(with invite: String) {
        self.invite = invite
        self.requestCall(movingFromBroadcastToRtc: false)
    }
    
    public func reconnect(as peerId: PeerId) {
        if peerId == self.joinAsPeerId {
            return
        }
        let _ = (self.accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { [weak self] myPeer in
            guard let strongSelf = self, let myPeer = myPeer else {
                return
            }
            
            let previousPeerId = strongSelf.joinAsPeerId
            if let localSsrc = strongSelf.currentLocalSsrc {
                strongSelf.ignorePreviousJoinAsPeerId = (previousPeerId, localSsrc)
            }
            strongSelf.joinAsPeerId = peerId
            
            if strongSelf.stateValue.scheduleTimestamp != nil {
                strongSelf.stateValue.myPeerId = peerId
                strongSelf.reconnectedAsEventsPipe.putNext(myPeer._asPeer())
                strongSelf.switchToTemporaryScheduledParticipantsContext()
            } else {
                strongSelf.disableVideo()
                strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                strongSelf.isMutedPromise.set(strongSelf.isMutedValue)
                
                strongSelf.reconnectingAsPeer = myPeer._asPeer()
                
                if let participantsContext = strongSelf.participantsContext, let immediateState = participantsContext.immediateState {
                    for participant in immediateState.participants {
                        if participant.peer.id == previousPeerId {
                            strongSelf.temporaryJoinTimestamp = participant.joinTimestamp
                            strongSelf.temporaryActivityTimestamp = participant.activityTimestamp
                            strongSelf.temporaryActivityRank = participant.activityRank
                            strongSelf.temporaryRaiseHandRating = participant.raiseHandRating
                            strongSelf.temporaryHasRaiseHand = participant.hasRaiseHand
                            strongSelf.temporaryMuteState = participant.muteState
                            strongSelf.temporaryJoinedVideo = participant.joinedVideo
                        }
                    }
                    strongSelf.switchToTemporaryParticipantsContext(sourceContext: participantsContext, oldMyPeerId: previousPeerId)
                } else {
                    strongSelf.stateValue.myPeerId = peerId
                }
                
                strongSelf.requestCall(movingFromBroadcastToRtc: false)
            }
        })
    }
    
    public func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError> {
        self.leaving = true
        if let callInfo = self.internalState.callInfo {
            if terminateIfPossible {
                self.leaveDisposable.set((self.accountContext.engine.calls.stopGroupCall(peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.markAsCanBeRemoved()
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
        
        self.schedulePending = false
        self.stateValue.scheduleTimestamp = timestamp
        
        self.summaryParticipantsState.set(.single(SummaryParticipantsState(
            participantCount: 1,
            topParticipants: [],
            activeSpeakers: Set()
        )))
        
        self.startDisposable.set((self.accountContext.engine.calls.createGroupCall(peerId: self.peerId, title: nil, scheduleDate: timestamp, isExternalStream: false)
        |> deliverOnMainQueue).start(next: { [weak self] callInfo in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateSessionState(internalState: .active(callInfo), audioSessionControl: strongSelf.audioSessionControl)
        }, error: { [weak self] error in
            if let strongSelf = self {
                strongSelf.markAsCanBeRemoved()
            }
        }))
    }
    
    
    public func startScheduled() {
        guard case let .active(callInfo) = self.internalState else {
            return
        }
        
        self.isScheduledStarted = true
        self.stateValue.scheduleTimestamp = nil
        
        self.startDisposable.set((self.accountContext.engine.calls.startScheduledGroupCall(peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
        |> deliverOnMainQueue).start(next: { [weak self] callInfo in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateSessionState(internalState: .active(callInfo), audioSessionControl: strongSelf.audioSessionControl)

            strongSelf.beginTone(tone: .groupJoined)
        }))
    }
    
    public func raiseHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.peer.id == self.joinAsPeerId {
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
            if participant.peer.id == self.joinAsPeerId {
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
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isVideoMuted = !value
                strongSelf.updateLocalVideoState()
            }))

            self.updateLocalVideoState()
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
        guard let callInfo = self.internalState.callInfo, self.screencastCallContext == nil else {
            return
        }
        
        self.hasScreencast = true

        let screencastCallContext = OngoingGroupCallContext(video: self.screencastCapturer, requestMediaChannelDescriptions: { _, _ in EmptyDisposable }, rejoinNeeded: { }, outgoingAudioBitrateKbit: nil, videoContentType: .screencast, enableNoiseSuppression: false, disableAudioInput: true, preferX264: false, logPath: "")
        self.screencastCallContext = screencastCallContext

        self.screencastJoinDisposable.set((screencastCallContext.joinPayload
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] joinPayload in
            guard let strongSelf = self else {
                return
            }

            strongSelf.requestDisposable.set((strongSelf.accountContext.engine.calls.joinGroupCallAsScreencast(
                peerId: strongSelf.peerId,
                callId: callInfo.id,
                accessHash: callInfo.accessHash,
                joinPayload: joinPayload.0
            )
            |> deliverOnMainQueue).start(next: { joinCallResult in
                guard let strongSelf = self, let screencastCallContext = strongSelf.screencastCallContext else {
                    return
                }
                let clientParams = joinCallResult.jsonParams

                screencastCallContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
                screencastCallContext.setJoinResponse(payload: clientParams)
            }, error: { error in
                guard let _ = self else {
                    return
                }
            }))
        }))
    }

    public func disableScreencast() {
        self.hasScreencast = false
        if let screencastCallContext = self.screencastCallContext {
            self.screencastCallContext = nil
            screencastCallContext.stop()

            let maybeCallInfo: GroupCallInfo? = self.internalState.callInfo

            if let callInfo = maybeCallInfo {
                self.screencastJoinDisposable.set(self.accountContext.engine.calls.leaveGroupCallAsScreencast(
                    callId: callInfo.id,
                    accessHash: callInfo.accessHash
                ).start())
            }
            
            self.screencastBufferServerContext?.stopScreencast()
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
        self.genericCallContext?.setRequestedVideoChannels(items.compactMap { item -> OngoingGroupCallContext.VideoChannel in
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
                endpointId: item.endpointId,
                ssrcGroups: item.ssrcGroups.map { group in
                    return OngoingGroupCallContext.VideoChannel.SsrcGroup(semantics: group.semantics, ssrcs: group.ssrcs)
                },
                minQuality: mappedMinQuality,
                maxQuality: mappedMaxQuality
            )
        })
    }
    
    public func setCurrentAudioOutput(_ output: AudioSessionOutput) {
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
                case .mediaStream:
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
            currentCall = context.engine.calls.getCurrentGroupCall(callId: initialCall.id, accessHash: initialCall.accessHash)
            |> mapError { _ -> CallError in
                return .generic
            }
            |> map { summary -> GroupCallInfo? in
                return summary?.info
            }
        } else if case let .active(callInfo) = self.internalState {
            currentCall = context.engine.calls.getCurrentGroupCall(callId: callInfo.id, accessHash: callInfo.accessHash)
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
            guard let strongSelf = self else {
                return
            }
            
            if let value = value {
                strongSelf.initialCall = EngineGroupCallDescription(id: value.id, accessHash: value.accessHash, title: value.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: value.isStream)
                
                strongSelf.updateSessionState(internalState: .active(value), audioSessionControl: strongSelf.audioSessionControl)
            } else {
                strongSelf.markAsCanBeRemoved()
            }
        }))
    }
    
    public func invitePeer(_ peerId: PeerId) -> Bool {
        guard let callInfo = self.internalState.callInfo, !self.invitedPeersValue.contains(peerId) else {
            return false
        }

        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.insert(peerId, at: 0)
        self.invitedPeersValue = updatedInvitedPeers
        
        let _ = self.accountContext.engine.calls.inviteToGroupCall(callId: callInfo.id, accessHash: callInfo.accessHash, peerId: peerId).start()
        
        return true
    }
    
    public func removedPeer(_ peerId: PeerId) {
        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.removeAll(where: { $0 == peerId})
        self.invitedPeersValue = updatedInvitedPeers
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
                if let callInfo =  state.callInfo {
                    return engine.calls.groupCallInviteLinks(callId: callInfo.id, accessHash: callInfo.accessHash)
                } else {
                    return .complete()
                }
            }
        }
    }
    
    private var currentMyAudioLevel: Float = 0.0
    private var currentMyAudioLevelTimestamp: Double = 0.0
    private var isSendingTyping: Bool = false
    
    private func restartMyAudioLevelTimer() {
        self.myAudioLevelTimer?.invalidate()
        let myAudioLevelTimer = SwiftSignalKit.Timer(timeout: 0.1, repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.myAudioLevelTimer = nil
            
            let timestamp = CACurrentMediaTime()
            
            var shouldBeSendingTyping = false
            if strongSelf.currentMyAudioLevel > 0.01 && timestamp < strongSelf.currentMyAudioLevelTimestamp + 1.0 {
                strongSelf.restartMyAudioLevelTimer()
                shouldBeSendingTyping = true
            } else {
                if timestamp < strongSelf.currentMyAudioLevelTimestamp + 1.0 {
                    strongSelf.restartMyAudioLevelTimer()
                    shouldBeSendingTyping = true
                }
            }
            if shouldBeSendingTyping != strongSelf.isSendingTyping {
                strongSelf.isSendingTyping = shouldBeSendingTyping
                if shouldBeSendingTyping {
                    strongSelf.typingDisposable.set(strongSelf.accountContext.account.acquireLocalInputActivity(peerId: PeerActivitySpace(peerId: strongSelf.peerId, category: .voiceChat), activity: .speakingInGroupCall(timestamp: 0)))
                    strongSelf.restartMyAudioLevelTimer()
                } else {
                    strongSelf.typingDisposable.set(nil)
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
    
    public func makeIncomingVideoView(endpointId: String, requestClone: Bool, completion: @escaping (PresentationCallVideoView?, PresentationCallVideoView?) -> Void) {
        if endpointId == self.currentLocalEndpointId {
            self.makeOutgoingVideoView(requestClone: requestClone, completion: completion)
            return
        }

        self.genericCallContext?.makeIncomingVideoView(endpointId: endpointId, requestClone: requestClone, completion: { mainView, cloneView in
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

    func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError>? {
        return self.genericCallContext?.video(endpointId: endpointId)
    }
    
    public func loadMoreMembers(token: String) {
        self.participantsContext?.loadMore(token: token)
    }

    func getStats() -> Signal<OngoingGroupCallContext.Stats, NoError> {
        return Signal { [weak self] subscriber in
            guard let strongSelf = self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            if let genericCallContext = strongSelf.genericCallContext {
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
}
