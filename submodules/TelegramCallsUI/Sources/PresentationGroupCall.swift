import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
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

private extension GroupCallParticipantsContext.Participant {
    var allSsrcs: Set<UInt32> {
        var participantSsrcs = Set<UInt32>()
        if let ssrc = self.ssrc {
            participantSsrcs.insert(ssrc)
        }
        if let jsonParams = self.jsonParams, let jsonData = jsonParams.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            if let groups = json["ssrc-groups"] as? [Any] {
                for group in groups {
                    if let group = group as? [String: Any] {
                        if let groupSources = group["sources"] as? [UInt32] {
                            for source in groupSources {
                                participantSsrcs.insert(source)
                            }
                        }
                    }
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
    
    private let panelDataPromise = Promise<GroupCallPanelData>()
    public var panelData: Signal<GroupCallPanelData, NoError> {
        return self.panelDataPromise.get()
    }
    
    public init(account: Account, peerId: PeerId, call: CachedChannelData.ActiveCall) {
        self.panelDataPromise.set(.single(GroupCallPanelData(
            peerId: peerId,
            info: GroupCallInfo(
                id: call.id,
                accessHash: call.accessHash,
                participantCount: 0,
                clientParams: nil,
                streamDcId: nil,
                title: nil,
                recordingStartTimestamp: nil
            ),
            topParticipants: [],
            participantCount: 0,
            activeSpeakers: Set(),
            groupCall: nil
        )))
        
        self.disposable = (getGroupCallParticipants(account: account, callId: call.id, accessHash: call.accessHash, offset: "", ssrcs: [], limit: 100)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<GroupCallParticipantsContext.State?, NoError> in
            return .single(nil)
        }
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let strongSelf = self, let state = state else {
                return
            }
            let context = GroupCallParticipantsContext(
                account: account,
                peerId: peerId,
                myPeerId: account.peerId,
                id: call.id,
                accessHash: call.accessHash,
                state: state
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
                return GroupCallPanelData(
                    peerId: peerId,
                    info: GroupCallInfo(id: call.id, accessHash: call.accessHash, participantCount: state.totalCount, clientParams: nil, streamDcId: nil, title: nil, recordingStartTimestamp: nil),
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
        
        init(queue: Queue) {
            self.queue = queue
        }
        
        public func get(account: Account, peerId: PeerId, call: CachedChannelData.ActiveCall) -> AccountGroupCallContextImpl.Proxy {
            let result: Record
            if let current = self.contexts[call.id] {
                result = current
            } else {
                let context = AccountGroupCallContextImpl(account: account, peerId: peerId, call: call)
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
    static func initialValue(myPeerId: PeerId) -> PresentationGroupCallState {
        return PresentationGroupCallState(
            myPeerId: myPeerId,
            networkState: .connecting,
            canManageCall: false,
            adminIds: Set(),
            muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
            defaultParticipantMuteState: nil,
            recordingStartTimestamp: nil,
            title: nil
        )
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
    
    private var initialCall: CachedChannelData.ActiveCall?
    public let internalId: CallSessionInternalId
    public let peerId: PeerId
    private var joinAsPeerId: PeerId
    public let peer: Peer?
    
    public private(set) var isVideo: Bool
    
    private let temporaryJoinTimestamp: Int32
    
    private var internalState: InternalState = .requesting
    
    private var callContext: OngoingGroupCallContext?
    private var currentConnectionMode: OngoingGroupCallContext.ConnectionMode = .none
    private var ssrcMapping: [UInt32: PeerId] = [:]
    
    private var requestedSsrcs = Set<UInt32>()
    
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
    
    private let joinDisposable = MetaDisposable()
    private let requestDisposable = MetaDisposable()
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
    
    private let incomingVideoSourcePromise = Promise<[PeerId: UInt32]>([:])
    public var incomingVideoSources: Signal<[PeerId: UInt32], NoError> {
        return self.incomingVideoSourcePromise.get()
    }
    
    private var missingSsrcs = Set<UInt32>()
    private var processedMissingSsrcs = Set<UInt32>()
    private let missingSsrcsDisposable = MetaDisposable()
    private var isRequestingMissingSsrcs: Bool = false
    
    init(
        accountContext: AccountContext,
        audioSession: ManagedAudioSession,
        callKitIntegration: CallKitIntegration?,
        getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void),
        initialCall: CachedChannelData.ActiveCall?,
        internalId: CallSessionInternalId,
        peerId: PeerId,
        peer: Peer?,
        joinAsPeerId: PeerId?
    ) {
        self.account = accountContext.account
        self.accountContext = accountContext
        self.audioSession = audioSession
        self.callKitIntegration = callKitIntegration
        self.getDeviceAccessData = getDeviceAccessData
        
        self.initialCall = initialCall
        self.internalId = internalId
        self.peerId = peerId
        self.peer = peer
        self.joinAsPeerId = joinAsPeerId ?? accountContext.account.peerId
        
        self.stateValue = PresentationGroupCallState.initialValue(myPeerId: self.joinAsPeerId)
        self.statePromise = ValuePromise(self.stateValue)
        
        self.temporaryJoinTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        //self.videoCapturer = OngoingCallVideoCapturer(keepLandscape: true)
        self.isVideo = self.videoCapturer != nil
        
        var didReceiveAudioOutputs = false
        
        if !audioSession.getIsHeadsetPluggedIn() {
            self.currentSelectedAudioOutputValue = .speaker
            self.audioOutputStatePromise.set(.single(([], .speaker)))
        }
        
        self.audioSessionDisposable = audioSession.push(audioSessionType: .voiceCall, manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.updateSessionState(internalState: strongSelf.internalState, audioSessionControl: control)
                }
            }
        }, deactivate: { [weak self] in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateIsAudioSessionActive(false)
                        strongSelf.updateSessionState(internalState: strongSelf.internalState, audioSessionControl: nil)
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
            if let strongSelf = self {
                if value {
                    if let audioSessionControl = strongSelf.audioSessionControl {
                        //let audioSessionActive: Signal<Bool, NoError>
                        if let callKitIntegration = strongSelf.callKitIntegration {
                            _ = callKitIntegration.audioSessionActive
                            |> filter { $0 }
                            |> timeout(2.0, queue: Queue.mainQueue(), alternate: Signal { subscriber in
                                if let strongSelf = self, let _ = strongSelf.audioSessionControl {
                                }
                                subscriber.putNext(true)
                                subscriber.putCompletion()
                                return EmptyDisposable
                            })
                        } else {
                            audioSessionControl.activate({ [weak self] _ in
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
                var addedParticipants: [(UInt32, String?)] = []
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
                                    if let ssrc = participantUpdate.ssrc {
                                        addedParticipants.append((ssrc, participantUpdate.jsonParams))
                                    }
                                } else if let ssrc = participantUpdate.ssrc, strongSelf.ssrcMapping[ssrc] == nil {
                                    addedParticipants.append((ssrc, participantUpdate.jsonParams))
                                }
                            }
                        case let .call(isTerminated, _, _, _):
                            if isTerminated {
                                strongSelf.markAsCanBeRemoved()
                            }
                        }
                    }
                }
                if !removedSsrc.isEmpty {
                    strongSelf.callContext?.removeSsrcs(ssrcs: removedSsrc)
                }
                //strongSelf.callContext?.addParticipants(participants: addedParticipants)
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
            impl.get(account: accountContext.account, peerId: peerId, call: CachedChannelData.ActiveCall(id: initialCall.id, accessHash: initialCall.accessHash))
        }) {
            if let participantsContext = temporaryParticipantsContext.context.participantsContext, let immediateState = participantsContext.immediateState {
                self.switchToTemporaryParticipantsContext(sourceContext: participantsContext, initialState: immediateState, oldMyPeerId: self.joinAsPeerId)
            }
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
        
        self.requestCall(movingFromBroadcastToRtc: false)
    }
    
    deinit {
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.audioSessionActiveDisposable?.dispose()
        self.summaryStateDisposable?.dispose()
        self.audioSessionDisposable?.dispose()
        self.joinDisposable.dispose()
        self.requestDisposable.dispose()
        self.groupCallParticipantUpdatesDisposable?.dispose()
        self.leaveDisposable.dispose()
        self.isMutedDisposable.dispose()
        self.memberStatesDisposable.dispose()
        self.networkStateDisposable.dispose()
        self.checkCallDisposable?.dispose()
        self.audioLevelsDisposable.dispose()
        self.participantsContextStateDisposable.dispose()
        self.myAudioLevelDisposable.dispose()
        self.memberEventsPipeDisposable.dispose()
        self.missingSsrcsDisposable.dispose()
        
        self.myAudioLevelTimer?.invalidate()
        self.typingDisposable.dispose()
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
        
        self.audioOutputStateDisposable?.dispose()
        
        self.removedChannelMembersDisposable?.dispose()
    }
    
    private func switchToTemporaryParticipantsContext(sourceContext: GroupCallParticipantsContext, initialState: GroupCallParticipantsContext.State, oldMyPeerId: PeerId) {
        let myPeerId = self.joinAsPeerId
        let myPeer = self.accountContext.account.postbox.transaction { transaction -> (Peer, CachedPeerData?)? in
            if let peer = transaction.getPeer(myPeerId) {
                return (peer, transaction.getPeerCachedData(peerId: myPeerId))
            } else {
                return nil
            }
        }
        let temporaryParticipantsContext = GroupCallParticipantsContext(account: self.account, peerId: self.peerId, myPeerId: myPeerId, id: sourceContext.id, accessHash: sourceContext.accessHash, state: initialState)
        self.temporaryParticipantsContext = temporaryParticipantsContext
        self.participantsContextStateDisposable.set((combineLatest(queue: .mainQueue(),
            myPeer,
            temporaryParticipantsContext.state,
            temporaryParticipantsContext.activeSpeakers
        )
        |> take(1)).start(next: { [weak self] myPeerAndCachedData, state, activeSpeakers in
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
                if let (myPeer, cachedData) = myPeerAndCachedData {
                    let about: String?
                    if let cachedData = cachedData as? CachedUserData {
                        about = cachedData.about
                    } else if let cachedData = cachedData as? CachedUserData {
                        about = cachedData.about
                    } else {
                        about = nil
                    }
                    participants.append(GroupCallParticipantsContext.Participant(
                        peer: myPeer,
                        ssrc: nil,
                        jsonParams: nil,
                        joinTimestamp: strongSelf.temporaryJoinTimestamp,
                        raiseHandRating: nil,
                        activityTimestamp: nil,
                        activityRank: nil,
                        muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                        volume: nil,
                        about: about
                    ))
                    participants.sort()
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
    }
    
    private func updateSessionState(internalState: InternalState, audioSessionControl: ManagedAudioSessionControl?) {
        let previousControl = self.audioSessionControl
        self.audioSessionControl = audioSessionControl
        
        let previousInternalState = self.internalState
        self.internalState = internalState
        
        if let audioSessionControl = audioSessionControl, previousControl == nil {
            switch self.currentSelectedAudioOutputValue {
            case .speaker:
                audioSessionControl.setOutputMode(.custom(self.currentSelectedAudioOutputValue))
            default:
                break
            }
            audioSessionControl.setup(synchronous: true)
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
        
        switch previousInternalState {
        case .active:
            break
        default:
            if case let .active(callInfo) = internalState {
                let callContext: OngoingGroupCallContext
                if let current = self.callContext {
                    callContext = current
                } else {
                    callContext = OngoingGroupCallContext(video: self.videoCapturer, participantDescriptionsRequired: { [weak self] ssrcs in
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.maybeRequestParticipants(ssrcs: ssrcs)
                        }
                    }, audioStreamData: OngoingGroupCallContext.AudioStreamData(account: self.accountContext.account, callId: callInfo.id, accessHash: callInfo.accessHash), rejoinNeeded: { [weak self] in
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            if case .established = strongSelf.internalState {
                                strongSelf.requestCall(movingFromBroadcastToRtc: false)
                            }
                        }
                    })
                    self.incomingVideoSourcePromise.set(callContext.videoSources
                    |> deliverOnMainQueue
                    |> map { [weak self] sources -> [PeerId: UInt32] in
                        guard let strongSelf = self else {
                            return [:]
                        }
                        var result: [PeerId: UInt32] = [:]
                        for source in sources {
                            if let peerId = strongSelf.ssrcMapping[source] {
                                result[peerId] = source
                            }
                        }
                        return result
                    })
                    self.callContext = callContext
                }
                self.joinDisposable.set((callContext.joinPayload
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
                    strongSelf.requestDisposable.set((joinGroupCall(
                        account: strongSelf.account,
                        peerId: strongSelf.peerId,
                        joinAs: strongSelf.joinAsPeerId,
                        callId: callInfo.id,
                        accessHash: callInfo.accessHash,
                        preferMuted: true,
                        joinPayload: joinPayload
                    )
                    |> deliverOnMainQueue).start(next: { joinCallResult in
                        guard let strongSelf = self else {
                            return
                        }
                        if let clientParams = joinCallResult.callInfo.clientParams {
                            strongSelf.ssrcMapping.removeAll()
                            let addedParticipants: [(UInt32, String?)] = []
                            for participant in joinCallResult.state.participants {
                                if let ssrc = participant.ssrc {
                                    strongSelf.ssrcMapping[ssrc] = participant.peer.id
                                    //addedParticipants.append((participant.ssrc, participant.jsonParams))
                                }
                            }
                            
                            switch joinCallResult.connectionMode {
                            case .rtc:
                                strongSelf.currentConnectionMode = .rtc
                                strongSelf.callContext?.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false)
                                strongSelf.callContext?.setJoinResponse(payload: clientParams, participants: addedParticipants)
                            case .broadcast:
                                strongSelf.currentConnectionMode = .broadcast
                                strongSelf.callContext?.setConnectionMode(.broadcast, keepBroadcastConnectedIfWasEnabled: false)
                            }
                            
                            strongSelf.updateSessionState(internalState: .established(info: joinCallResult.callInfo, connectionMode: joinCallResult.connectionMode, clientParams: clientParams, localSsrc: ssrc, initialState: joinCallResult.state), audioSessionControl: strongSelf.audioSessionControl)
                        }
                    }, error: { error in
                        guard let strongSelf = self else {
                            return
                        }
                        if case .anonymousNotAllowed = error {
                            let presentationData = strongSelf.accountContext.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.VoiceChat_AnonymousDisabledAlertText, actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                            ]), on: .root, blockInteraction: false, completion: {})
                        } else if case .tooManyParticipants = error {
                            let presentationData = strongSelf.accountContext.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.accountContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.VoiceChat_ChatFullAlertText, actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                            ]), on: .root, blockInteraction: false, completion: {})
                        }
                        strongSelf.markAsCanBeRemoved()
                    }))
                }))
                
                self.networkStateDisposable.set((callContext.networkState
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
                            let toneRenderer = PresentationCallToneRenderer(tone: .groupConnecting)
                            strongSelf.toneRenderer = toneRenderer
                            toneRenderer.setAudioSessionActive(strongSelf.isAudioSessionActive)
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
                            
                            let toneRenderer = PresentationCallToneRenderer(tone: .groupJoined)
                            strongSelf.toneRenderer = toneRenderer
                            toneRenderer.setAudioSessionActive(strongSelf.isAudioSessionActive)
                        }
                    }
                }))
                
                self.audioLevelsDisposable.set((callContext.audioLevels
                |> deliverOnMainQueue).start(next: { [weak self] levels in
                    guard let strongSelf = self else {
                        return
                    }
                    var result: [(PeerId, UInt32, Float, Bool)] = []
                    var myLevel: Float = 0.0
                    var myLevelHasVoice: Bool = false
                    var missingSsrcs = Set<UInt32>()
                    for (ssrcKey, level, hasVoice) in levels {
                        var peerId: PeerId?
                        let ssrcValue: UInt32
                        switch ssrcKey {
                        case .local:
                            peerId = strongSelf.joinAsPeerId
                            ssrcValue = 0
                        case let .source(ssrc):
                            peerId = strongSelf.ssrcMapping[ssrc]
                            ssrcValue = ssrc
                        }
                        if let peerId = peerId {
                            if case .local = ssrcKey {
                                if !strongSelf.isMutedValue.isEffectivelyMuted {
                                    myLevel = level
                                    myLevelHasVoice = hasVoice
                                }
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
                    
                    if !missingSsrcs.isEmpty {
                        strongSelf.participantsContext?.ensureHaveParticipants(ssrcs: missingSsrcs)
                    }
                }))
            }
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
                
                let accountContext = self.accountContext
                let peerId = self.peerId
                let rawAdminIds = Signal<Set<PeerId>, NoError> { subscriber in
                    let (disposable, _) = accountContext.peerChannelMemberCategoriesContextsManager.admins(postbox: accountContext.account.postbox, network: accountContext.account.network, accountPeerId: accountContext.account.peerId, peerId: peerId, updated: { list in
                        subscriber.putNext(Set(list.list.map { $0.peer.id }))
                    })
                    return disposable
                }
                |> runOn(.mainQueue())
                
                let adminIds = combineLatest(queue: .mainQueue(),
                    rawAdminIds,
                    accountContext.account.postbox.combinedView(keys: [.basicPeer(peerId)])
                )
                |> map { rawAdminIds, view -> Set<PeerId> in
                    var rawAdminIds = rawAdminIds
                    if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer as? TelegramChannel {
                        if peer.hasPermission(.manageCalls) {
                            rawAdminIds.insert(accountContext.account.peerId)
                        } else {
                            rawAdminIds.remove(accountContext.account.peerId)
                        }
                    }
                    return rawAdminIds
                }
                |> distinctUntilChanged
                
                var initialState = initialState
                if let participantsContext = self.participantsContext, let immediateState = participantsContext.immediateState {
                    initialState.mergeActivity(from: immediateState)
                }
                
                let participantsContext = GroupCallParticipantsContext(
                    account: self.accountContext.account,
                    peerId: self.peerId,
                    myPeerId: self.joinAsPeerId,
                    id: callInfo.id,
                    accessHash: callInfo.accessHash,
                    state: initialState
                )
                self.temporaryParticipantsContext = nil
                self.participantsContext = participantsContext
                let myPeerId = self.joinAsPeerId
                let myPeer = self.accountContext.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(myPeerId)
                }
                self.participantsContextStateDisposable.set(combineLatest(queue: .mainQueue(),
                    participantsContext.state,
                    participantsContext.activeSpeakers,
                    self.speakingParticipantsContext.get(),
                    adminIds,
                    myPeer,
                    self.isReconnectingAsSpeakerPromise.get()
                ).start(next: { [weak self] state, activeSpeakers, speakingParticipants, adminIds, myPeer, isReconnectingAsSpeaker in
                    guard let strongSelf = self else {
                        return
                    }
                    
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
                    if !participants.contains(where: { $0.peer.id == myPeerId }) {
                        if let myPeer = myPeer {
                            participants.append(GroupCallParticipantsContext.Participant(
                                peer: myPeer,
                                ssrc: nil,
                                jsonParams: nil,
                                joinTimestamp: strongSelf.temporaryJoinTimestamp,
                                raiseHandRating: nil,
                                activityTimestamp: nil,
                                activityRank: nil,
                                muteState: GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false),
                                volume: nil,
                                about: nil
                            ))
                            participants.sort()
                        }
                    }
                    
                    for participant in participants {
                        members.participants.append(participant)
                        
                        if topParticipants.count < 3 {
                            topParticipants.append(participant)
                        }
                        
                        if let ssrc = participant.ssrc {
                            strongSelf.ssrcMapping[ssrc] = participant.peer.id
                        }
                        
                        if participant.peer.id == strongSelf.joinAsPeerId {
                            var filteredMuteState = participant.muteState
                            if isReconnectingAsSpeaker || strongSelf.currentConnectionMode != .rtc {
                                filteredMuteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: false, mutedByYou: false)
                            }

                            if let muteState = filteredMuteState {
                                if muteState.canUnmute {
                                    switch strongSelf.isMutedValue {
                                    case let .muted(isPushToTalkActive):
                                        if !isPushToTalkActive {
                                            strongSelf.callContext?.setIsMuted(true)
                                        }
                                    case .unmuted:
                                        strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                        strongSelf.callContext?.setIsMuted(true)
                                    }
                                } else {
                                    strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                    strongSelf.callContext?.setIsMuted(true)
                                }
                                strongSelf.stateValue.muteState = muteState
                            } else if let currentMuteState = strongSelf.stateValue.muteState, !currentMuteState.canUnmute {
                                strongSelf.isMutedValue = .muted(isPushToTalkActive: false)
                                strongSelf.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
                                strongSelf.callContext?.setIsMuted(true)
                            }
                        } else {
                            if let ssrc = participant.ssrc {
                                if let volume = participant.volume {
                                    strongSelf.callContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                                } else if participant.muteState?.mutedByYou == true {
                                    strongSelf.callContext?.setVolume(ssrc: ssrc, volume: 0.0)
                                }
                            }
                        }
                        
                        if let index = updatedInvitedPeers.firstIndex(of: participant.peer.id) {
                            updatedInvitedPeers.remove(at: index)
                            didUpdateInvitedPeers = true
                        }
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
                    
                    strongSelf.summaryParticipantsState.set(.single(SummaryParticipantsState(
                        participantCount: state.totalCount,
                        topParticipants: topParticipants,
                        activeSpeakers: activeSpeakers
                    )))
                    
                    if didUpdateInvitedPeers {
                        strongSelf.invitedPeersValue = updatedInvitedPeers
                    }
                }))
                
                let postbox = self.accountContext.account.postbox
                self.memberEventsPipeDisposable.set((participantsContext.memberEvents
                |> mapToSignal { event -> Signal<PresentationGroupCallMemberEvent, NoError> in
                    return postbox.transaction { transaction -> Signal<PresentationGroupCallMemberEvent, NoError> in
                        if let peer = transaction.getPeer(event.peerId) {
                            return .single(PresentationGroupCallMemberEvent(peer: peer, joined: event.joined))
                        } else {
                            return .complete()
                        }
                    }
                    |> switchToLatest
                }
                |> deliverOnMainQueue).start(next: { [weak self] event in
                    self?.memberEventsPipe.putNext(event)
                }))
                
                if let isCurrentlyConnecting = self.isCurrentlyConnecting, isCurrentlyConnecting {
                    self.startCheckingCallIfNeeded()
                }
            }
        }
    }
    
    private func maybeRequestParticipants(ssrcs: Set<UInt32>) {
        var missingSsrcs = ssrcs
        missingSsrcs.subtract(self.processedMissingSsrcs)
        if missingSsrcs.isEmpty {
            return
        }
        self.processedMissingSsrcs.formUnion(ssrcs)
        
        var addedParticipants: [(UInt32, String?)] = []
        
        if let membersValue = self.membersValue {
            for participant in membersValue.participants {
                let participantSsrcs = participant.allSsrcs
                
                if !missingSsrcs.intersection(participantSsrcs).isEmpty {
                    missingSsrcs.subtract(participantSsrcs)
                    self.processedMissingSsrcs.formUnion(participantSsrcs)
                    
                    if let ssrc = participant.ssrc {
                        addedParticipants.append((ssrc, participant.jsonParams))
                    }
                }
            }
        }
        
        if !addedParticipants.isEmpty {
            self.callContext?.addParticipants(participants: addedParticipants)
        }
        
        if !missingSsrcs.isEmpty {
            self.missingSsrcs.formUnion(missingSsrcs)
            self.maybeRequestMissingSsrcs()
        }
    }
    
    private func maybeRequestMissingSsrcs() {
        if self.isRequestingMissingSsrcs {
            return
        }
        if self.missingSsrcs.isEmpty {
            return
        }
        if case let .established(callInfo, _, _, _, _) = self.internalState {
            self.isRequestingMissingSsrcs = true
            
            let requestedSsrcs = self.missingSsrcs
            self.missingSsrcsDisposable.set((getGroupCallParticipants(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, offset: "", ssrcs: Array(requestedSsrcs), limit: 100)
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isRequestingMissingSsrcs = false
                strongSelf.missingSsrcs.subtract(requestedSsrcs)
                
                var addedParticipants: [(UInt32, String?)] = []
                
                for participant in state.participants {
                    if let ssrc = participant.ssrc {
                        addedParticipants.append((ssrc, participant.jsonParams))
                    }
                }
                
                if !addedParticipants.isEmpty {
                    strongSelf.callContext?.addParticipants(participants: addedParticipants)
                }
                
                strongSelf.maybeRequestMissingSsrcs()
            }))
        }
    }
    
    private func startCheckingCallIfNeeded() {
        if self.checkCallDisposable != nil {
            return
        }
        if case let .established(callInfo, connectionMode, _, ssrc, _) = self.internalState, case .rtc = connectionMode {
            let checkSignal = checkGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, ssrc: Int32(bitPattern: ssrc))
            
            self.checkCallDisposable = ((
                checkSignal
                |> castError(Bool.self)
                |> delay(4.0, queue: .mainQueue())
                |> mapToSignal { result -> Signal<Bool, Bool> in
                    if case .success = result {
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
    
    private func markAsCanBeRemoved() {
        if self.markedAsCanBeRemoved {
            return
        }
        self.markedAsCanBeRemoved = true

        self.callContext?.stop()
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
                    
                    let toneRenderer = PresentationCallToneRenderer(tone: .groupLeft)
                    strongSelf.toneRenderer = toneRenderer
                    toneRenderer.setAudioSessionActive(strongSelf.isAudioSessionActive)
                    
                    Queue.mainQueue().after(1.0, {
                        strongSelf.wasRemoved.set(.single(true))
                    })
                })
            }
        }
    }
    
    public func reconnect(as peerId: PeerId) {
        if peerId == self.joinAsPeerId {
            return
        }
        let _ = (self.accountContext.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] myPeer in
            guard let strongSelf = self, let _ = myPeer else {
                return
            }
            
            let previousPeerId = strongSelf.joinAsPeerId
            strongSelf.joinAsPeerId = peerId
            
            if let participantsContext = strongSelf.participantsContext, let immediateState = participantsContext.immediateState {
                strongSelf.switchToTemporaryParticipantsContext(sourceContext: participantsContext, initialState: immediateState, oldMyPeerId: previousPeerId)
            } else {
                strongSelf.stateValue.myPeerId = peerId
            }
            
            strongSelf.requestCall(movingFromBroadcastToRtc: false)
        })
    }
    
    public func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError> {
        if case let .established(callInfo, _, _, localSsrc, _) = self.internalState {
            if terminateIfPossible {
                self.leaveDisposable.set((stopGroupCall(account: self.account, peerId: self.peerId, callId: callInfo.id, accessHash: callInfo.accessHash)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.markAsCanBeRemoved()
                }))
            } else {
                self.leaveDisposable.set((leaveGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, source: localSsrc)
                |> deliverOnMainQueue).start(error: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.markAsCanBeRemoved()
                }, completed: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.markAsCanBeRemoved()
                }))
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
        self.callContext?.setIsMuted(isEffectivelyMuted)
        
        if isVisuallyMuted {
            self.stateValue.muteState = GroupCallParticipantsContext.Participant.MuteState(canUnmute: true, mutedByYou: false)
        } else {
            self.stateValue.muteState = nil
        }
    }
    
    public func raiseHand() {
        guard let membersValue = self.membersValue else {
            return
        }
        for participant in membersValue.participants {
            if participant.peer.id == self.joinAsPeerId {
                if participant.raiseHandRating != nil {
                    return
                }
                
                break
            }
        }
        
        self.participantsContext?.raiseHand()
    }
    
    public func requestVideo() {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer()
            self.videoCapturer = videoCapturer
        }
        self.isVideo = true
        if let videoCapturer = self.videoCapturer {
            self.callContext?.requestVideo(videoCapturer)
        }
    }
    
    public func disableVideo() {
        self.isVideo = false
        if let _ = self.videoCapturer {
            self.videoCapturer = nil
            self.callContext?.disableVideo()
        }
    }
    
    public func setVolume(peerId: PeerId, volume: Int32, sync: Bool) {
        for (ssrc, id) in self.ssrcMapping {
            if id == peerId {
                self.callContext?.setVolume(ssrc: ssrc, volume: Double(volume) / 10000.0)
                if sync {
                    self.participantsContext?.updateMuteState(peerId: peerId, muteState: nil, volume: volume, raiseHand: nil)
                }
                break
            }
        }
    }
    
    public func setFullSizeVideo(peerId: PeerId?) {
        var resolvedSsrc: UInt32?
        if let peerId = peerId {
            for (ssrc, id) in self.ssrcMapping {
                if id == peerId {
                    resolvedSsrc = ssrc
                    break
                }
            }
        }
        self.callContext?.setFullSizeVideoSsrc(ssrc: resolvedSsrc)
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
            audioSessionControl.setOutputMode(.custom(output))
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
    
    public func setShouldBeRecording(_ shouldBeRecording: Bool, title: String?) {
        if !self.stateValue.canManageCall {
            return
        }
        if (self.stateValue.recordingStartTimestamp != nil) == shouldBeRecording {
            return
        }
        self.participantsContext?.updateShouldBeRecording(shouldBeRecording, title: title)
    }
    
    private func requestCall(movingFromBroadcastToRtc: Bool) {
        self.currentConnectionMode = .none
        self.callContext?.setConnectionMode(.none, keepBroadcastConnectedIfWasEnabled: movingFromBroadcastToRtc)
        
        self.missingSsrcsDisposable.set(nil)
        self.missingSsrcs.removeAll()
        self.processedMissingSsrcs.removeAll()
        
        self.internalState = .requesting
        self.isCurrentlyConnecting = nil
        
        enum CallError {
            case generic
        }
        
        let account = self.account
        
        let currentCall: Signal<GroupCallInfo?, CallError>
        if let initialCall = self.initialCall {
            currentCall = getCurrentGroupCall(account: account, callId: initialCall.id, accessHash: initialCall.accessHash)
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

        if !movingFromBroadcastToRtc {
            self.stateValue.networkState = .connecting
        }
        
        self.requestDisposable.set((currentOrRequestedCall
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            if let value = value {
                strongSelf.initialCall = CachedChannelData.ActiveCall(id: value.id, accessHash: value.accessHash)
                
                strongSelf.updateSessionState(internalState: .active(value), audioSessionControl: strongSelf.audioSessionControl)
            } else {
                strongSelf.markAsCanBeRemoved()
            }
        }))
    }
    
    public func invitePeer(_ peerId: PeerId) -> Bool {
        guard case let .established(callInfo, _, _, _, _) = self.internalState, !self.invitedPeersValue.contains(peerId) else {
            return false
        }

        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.insert(peerId, at: 0)
        self.invitedPeersValue = updatedInvitedPeers
        
        let _ = inviteToGroupCall(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, peerId: peerId).start()
        
        return true
    }
    
    public func removedPeer(_ peerId: PeerId) {
        var updatedInvitedPeers = self.invitedPeersValue
        updatedInvitedPeers.removeAll(where: { $0 == peerId})
        self.invitedPeersValue = updatedInvitedPeers
    }
    
    public func updateTitle(_ title: String){
        guard case let .established(callInfo, _, _, _, _) = self.internalState else {
            return
        }
        
        let _ = editGroupCallTitle(account: self.account, callId: callInfo.id, accessHash: callInfo.accessHash, title: title).start()
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
    
    public func makeIncomingVideoView(source: UInt32, completion: @escaping (PresentationCallVideoView?) -> Void) {
        self.callContext?.makeIncomingVideoView(source: source, completion: { view in
            if let view = view {
                let setOnFirstFrameReceived = view.setOnFirstFrameReceived
                let setOnOrientationUpdated = view.setOnOrientationUpdated
                let setOnIsMirroredUpdated = view.setOnIsMirroredUpdated
                completion(PresentationCallVideoView(
                    holder: view,
                    view: view.view,
                    setOnFirstFrameReceived: { f in
                        setOnFirstFrameReceived(f)
                    },
                    getOrientation: { [weak view] in
                        if let view = view {
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch view.getOrientation() {
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
                    getAspect: { [weak view] in
                        if let view = view {
                            return view.getAspect()
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
                    }
                ))
            } else {
                completion(nil)
            }
        })
    }
    
    public func loadMoreMembers(token: String) {
        self.participantsContext?.loadMore(token: token)
    }
}
