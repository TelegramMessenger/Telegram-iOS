import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramAudio

public enum RequestCallResult {
    case requested
    case alreadyInProgress(PeerId?)
}

public enum JoinGroupCallManagerResult {
    case joined
    case alreadyInProgress(PeerId?)
}

public enum RequestScheduleGroupCallResult {
    case success
    case alreadyInProgress(PeerId?)
}

public struct CallAuxiliaryServer {
    public enum Connection {
        case stun
        case turn(username: String, password: String)
    }
    
    public let host: String
    public let port: Int
    public let connection: Connection
    
    public init(
        host: String,
        port: Int,
        connection: Connection
    ) {
        self.host = host
        self.port = port
        self.connection = connection
    }
}

public struct PresentationCallState: Equatable {
    public enum State: Equatable {
        case waiting
        case ringing
        case requesting(Bool)
        case connecting(Data?)
        case active(Double, Int32?, Data)
        case reconnecting(Double, Int32?, Data)
        case terminating(CallSessionTerminationReason?)
        case terminated(CallId?, CallSessionTerminationReason?, Bool)
    }
    
    public enum VideoState: Equatable {
        case notAvailable
        case inactive
        case active(isScreencast: Bool)
        case paused(isScreencast: Bool)
    }
    
    public enum RemoteVideoState: Equatable {
        case inactive
        case active
        case paused
    }
    
    public enum RemoteAudioState: Equatable {
        case active
        case muted
    }
    
    public enum RemoteBatteryLevel: Equatable {
        case normal
        case low
    }
    
    public var state: State
    public var videoState: VideoState
    public var remoteVideoState: RemoteVideoState
    public var remoteAudioState: RemoteAudioState
    public var remoteBatteryLevel: RemoteBatteryLevel
    
    public init(state: State, videoState: VideoState, remoteVideoState: RemoteVideoState, remoteAudioState: RemoteAudioState, remoteBatteryLevel: RemoteBatteryLevel) {
        self.state = state
        self.videoState = videoState
        self.remoteVideoState = remoteVideoState
        self.remoteAudioState = remoteAudioState
        self.remoteBatteryLevel = remoteBatteryLevel
    }
}

public final class PresentationCallVideoView {
    public enum Orientation {
        case rotation0
        case rotation90
        case rotation180
        case rotation270
    }
    
    public let holder: AnyObject
    public let view: UIView
    public let setOnFirstFrameReceived: (((Float) -> Void)?) -> Void
    
    public let getOrientation: () -> Orientation
    public let getAspect: () -> CGFloat
    public let setOnOrientationUpdated: (((Orientation, CGFloat) -> Void)?) -> Void
    public let setOnIsMirroredUpdated: (((Bool) -> Void)?) -> Void
    public let updateIsEnabled: (Bool) -> Void
    
    public init(
        holder: AnyObject,
        view: UIView,
        setOnFirstFrameReceived: @escaping (((Float) -> Void)?) -> Void,
        getOrientation: @escaping () -> Orientation,
        getAspect: @escaping () -> CGFloat,
        setOnOrientationUpdated: @escaping (((Orientation, CGFloat) -> Void)?) -> Void,
        setOnIsMirroredUpdated: @escaping (((Bool) -> Void)?) -> Void,
        updateIsEnabled: @escaping (Bool) -> Void
    ) {
        self.holder = holder
        self.view = view
        self.setOnFirstFrameReceived = setOnFirstFrameReceived
        self.getOrientation = getOrientation
        self.getAspect = getAspect
        self.setOnOrientationUpdated = setOnOrientationUpdated
        self.setOnIsMirroredUpdated = setOnIsMirroredUpdated
        self.updateIsEnabled = updateIsEnabled
    }
}

public protocol PresentationCall: AnyObject {
    var context: AccountContext { get }
    var isIntegratedWithCallKit: Bool { get }
    var internalId: CallSessionInternalId { get }
    var peerId: PeerId { get }
    var isOutgoing: Bool { get }
    var isVideo: Bool { get }
    var isVideoPossible: Bool { get }
    var peer: Peer? { get }
    
    var state: Signal<PresentationCallState, NoError> { get }
    var audioLevel: Signal<Float, NoError> { get }

    var isMuted: Signal<Bool, NoError> { get }
    
    var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> { get }
    
    var canBeRemoved: Signal<Bool, NoError> { get }
    
    func answer()
    func hangUp() -> Signal<Bool, NoError>
    func rejectBusy()
    
    func toggleIsMuted()
    func setIsMuted(_ value: Bool)
    func requestVideo()
    func setRequestedVideoAspect(_ aspect: Float)
    func disableVideo()
    func setOutgoingVideoIsPaused(_ isPaused: Bool)
    func switchVideoCamera()
    func setCurrentAudioOutput(_ output: AudioSessionOutput)
    func debugInfo() -> Signal<(String, String), NoError>
    
    func makeIncomingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void)
    func makeOutgoingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void)
}

public struct VoiceChatConfiguration {
    public static var defaultValue: VoiceChatConfiguration {
        return VoiceChatConfiguration(videoParticipantsMaxCount: 30)
    }
    
    public let videoParticipantsMaxCount: Int32
    
    fileprivate init(videoParticipantsMaxCount: Int32) {
        self.videoParticipantsMaxCount = videoParticipantsMaxCount
    }
    
    public static func with(appConfiguration: AppConfiguration) -> VoiceChatConfiguration {
        if let data = appConfiguration.data, let value = data["groupcall_video_participants_max"] as? Double {
            return VoiceChatConfiguration(videoParticipantsMaxCount: Int32(value))
        } else {
            return .defaultValue
        }
    }
}

public struct PresentationGroupCallState: Equatable {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public enum DefaultParticipantMuteState {
        case unmuted
        case muted
    }
    
    public var myPeerId: PeerId
    public var networkState: NetworkState
    public var canManageCall: Bool
    public var adminIds: Set<PeerId>
    public var muteState: GroupCallParticipantsContext.Participant.MuteState?
    public var defaultParticipantMuteState: DefaultParticipantMuteState?
    public var recordingStartTimestamp: Int32?
    public var title: String?
    public var raisedHand: Bool
    public var scheduleTimestamp: Int32?
    public var subscribedToScheduled: Bool
    public var isVideoEnabled: Bool
    public var isVideoWatchersLimitReached: Bool
    
    public init(
        myPeerId: PeerId,
        networkState: NetworkState,
        canManageCall: Bool,
        adminIds: Set<PeerId>,
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        defaultParticipantMuteState: DefaultParticipantMuteState?,
        recordingStartTimestamp: Int32?,
        title: String?,
        raisedHand: Bool,
        scheduleTimestamp: Int32?,
        subscribedToScheduled: Bool,
        isVideoEnabled: Bool,
        isVideoWatchersLimitReached: Bool
    ) {
        self.myPeerId = myPeerId
        self.networkState = networkState
        self.canManageCall = canManageCall
        self.adminIds = adminIds
        self.muteState = muteState
        self.defaultParticipantMuteState = defaultParticipantMuteState
        self.recordingStartTimestamp = recordingStartTimestamp
        self.title = title
        self.raisedHand = raisedHand
        self.scheduleTimestamp = scheduleTimestamp
        self.subscribedToScheduled = subscribedToScheduled
        self.isVideoEnabled = isVideoEnabled
        self.isVideoWatchersLimitReached = isVideoWatchersLimitReached
    }
}

public struct PresentationGroupCallSummaryState: Equatable {
    public var info: GroupCallInfo?
    public var participantCount: Int
    public var callState: PresentationGroupCallState
    public var topParticipants: [GroupCallParticipantsContext.Participant]
    public var activeSpeakers: Set<PeerId>
    
    public init(
        info: GroupCallInfo?,
        participantCount: Int,
        callState: PresentationGroupCallState,
        topParticipants: [GroupCallParticipantsContext.Participant],
        activeSpeakers: Set<PeerId>
    ) {
        self.info = info
        self.participantCount = participantCount
        self.callState = callState
        self.topParticipants = topParticipants
        self.activeSpeakers = activeSpeakers
    }
}

public struct PresentationGroupCallMemberState: Equatable {
    public var ssrc: UInt32
    public var muteState: GroupCallParticipantsContext.Participant.MuteState?
    public var speaking: Bool
    
    public init(
        ssrc: UInt32,
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        speaking: Bool
    ) {
        self.ssrc = ssrc
        self.muteState = muteState
        self.speaking = speaking
    }
}

public enum PresentationGroupCallMuteAction: Equatable {
    case muted(isPushToTalkActive: Bool)
    case unmuted
    
    public var isEffectivelyMuted: Bool {
        switch self {
            case let .muted(isPushToTalkActive):
                return !isPushToTalkActive
            case .unmuted:
                return false
        }
    }
}

public struct PresentationGroupCallMembers: Equatable {
    public var participants: [GroupCallParticipantsContext.Participant]
    public var speakingParticipants: Set<PeerId>
    public var totalCount: Int
    public var loadMoreToken: String?
    
    public init(
        participants: [GroupCallParticipantsContext.Participant],
        speakingParticipants: Set<PeerId>,
        totalCount: Int,
        loadMoreToken: String?
    ) {
        self.participants = participants
        self.speakingParticipants = speakingParticipants
        self.totalCount = totalCount
        self.loadMoreToken = loadMoreToken
    }
}

public final class PresentationGroupCallMemberEvent {
    public let peer: Peer
    public let isContact: Bool
    public let isInChatList: Bool
    public let canUnmute: Bool
    public let joined: Bool
    
    public init(peer: Peer, isContact: Bool, isInChatList: Bool, canUnmute: Bool, joined: Bool) {
        self.peer = peer
        self.isContact = isContact
        self.isInChatList = isInChatList
        self.canUnmute = canUnmute
        self.joined = joined
    }
}

public enum PresentationGroupCallTone {
    case unmuted
    case recordingStarted
}

public struct PresentationGroupCallRequestedVideo {
    public enum Quality {
        case thumbnail
        case medium
        case full
    }

    public struct SsrcGroup {
        public var semantics: String
        public var ssrcs: [UInt32]
    }

    public var audioSsrc: UInt32
    public var endpointId: String
    public var ssrcGroups: [SsrcGroup]
    public var minQuality: Quality
    public var maxQuality: Quality
}

public extension GroupCallParticipantsContext.Participant {
    var videoEndpointId: String? {
        return self.videoDescription?.endpointId
    }

    var presentationEndpointId: String? {
        return self.presentationDescription?.endpointId
    }
}

public extension GroupCallParticipantsContext.Participant {
    func requestedVideoChannel(minQuality: PresentationGroupCallRequestedVideo.Quality, maxQuality: PresentationGroupCallRequestedVideo.Quality) -> PresentationGroupCallRequestedVideo? {
        guard let audioSsrc = self.ssrc else {
            return nil
        }
        guard let videoDescription = self.videoDescription else {
            return nil
        }
        return PresentationGroupCallRequestedVideo(audioSsrc: audioSsrc, endpointId: videoDescription.endpointId, ssrcGroups: videoDescription.ssrcGroups.map { group in
            PresentationGroupCallRequestedVideo.SsrcGroup(semantics: group.semantics, ssrcs: group.ssrcs)
        }, minQuality: minQuality, maxQuality: maxQuality)
    }

    func requestedPresentationVideoChannel(minQuality: PresentationGroupCallRequestedVideo.Quality, maxQuality: PresentationGroupCallRequestedVideo.Quality) -> PresentationGroupCallRequestedVideo? {
        guard let audioSsrc = self.ssrc else {
            return nil
        }
        guard let presentationDescription = self.presentationDescription else {
            return nil
        }
        return PresentationGroupCallRequestedVideo(audioSsrc: audioSsrc, endpointId: presentationDescription.endpointId, ssrcGroups: presentationDescription.ssrcGroups.map { group in
            PresentationGroupCallRequestedVideo.SsrcGroup(semantics: group.semantics, ssrcs: group.ssrcs)
        }, minQuality: minQuality, maxQuality: maxQuality)
    }
}

public protocol PresentationGroupCall: AnyObject {
    var account: Account { get }
    var accountContext: AccountContext { get }
    var internalId: CallSessionInternalId { get }
    var peerId: PeerId { get }
    
    var hasVideo: Bool { get }
    var hasScreencast: Bool { get }
    
    var schedulePending: Bool { get }
    
    var isStream: Bool { get }
    
    var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> { get }
    
    var isSpeaking: Signal<Bool, NoError> { get }
    var canBeRemoved: Signal<Bool, NoError> { get }
    var state: Signal<PresentationGroupCallState, NoError> { get }
    var stateVersion: Signal<Int, NoError> { get }
    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> { get }
    var members: Signal<PresentationGroupCallMembers?, NoError> { get }
    var audioLevels: Signal<[(PeerId, UInt32, Float, Bool)], NoError> { get }
    var myAudioLevel: Signal<Float, NoError> { get }
    var isMuted: Signal<Bool, NoError> { get }
    var isNoiseSuppressionEnabled: Signal<Bool, NoError> { get }
    
    var memberEvents: Signal<PresentationGroupCallMemberEvent, NoError> { get }
    var reconnectedAsEvents: Signal<Peer, NoError> { get }
    
    func toggleScheduledSubscription(_ subscribe: Bool)
    func schedule(timestamp: Int32)
    func startScheduled()
    
    func reconnect(with invite: String)
    func reconnect(as peerId: PeerId)
    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError>
    
    func toggleIsMuted()
    func setIsMuted(action: PresentationGroupCallMuteAction)
    func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool)
    func raiseHand()
    func lowerHand()
    func requestVideo()
    func disableVideo()
    func disableScreencast()
    func switchVideoCamera()
    func updateDefaultParticipantsAreMuted(isMuted: Bool)
    func setVolume(peerId: PeerId, volume: Int32, sync: Bool)
    func setRequestedVideoList(items: [PresentationGroupCallRequestedVideo])
    func setCurrentAudioOutput(_ output: AudioSessionOutput)

    func playTone(_ tone: PresentationGroupCallTone)
    
    func updateMuteState(peerId: PeerId, isMuted: Bool) -> GroupCallParticipantsContext.Participant.MuteState?
    func setShouldBeRecording(_ shouldBeRecording: Bool, title: String?, videoOrientation: Bool?)
    
    func updateTitle(_ title: String)
    
    func invitePeer(_ peerId: PeerId) -> Bool
    func removedPeer(_ peerId: PeerId)
    var invitedPeers: Signal<[PeerId], NoError> { get }
    
    var inviteLinks: Signal<GroupCallInviteLinks?, NoError> { get }
    
    func makeIncomingVideoView(endpointId: String, requestClone: Bool, completion: @escaping (PresentationCallVideoView?, PresentationCallVideoView?) -> Void)
    func makeOutgoingVideoView(requestClone: Bool, completion: @escaping (PresentationCallVideoView?, PresentationCallVideoView?) -> Void)
    
    func loadMoreMembers(token: String)
}

public protocol PresentationCallManager: AnyObject {
    var currentCallSignal: Signal<PresentationCall?, NoError> { get }
    var currentGroupCallSignal: Signal<PresentationGroupCall?, NoError> { get }
    
    func requestCall(context: AccountContext, peerId: PeerId, isVideo: Bool, endCurrentIfAny: Bool) -> RequestCallResult
    func joinGroupCall(context: AccountContext, peerId: PeerId, invite: String?, requestJoinAsPeerId: ((@escaping (PeerId?) -> Void) -> Void)?, initialCall: EngineGroupCallDescription, endCurrentIfAny: Bool) -> JoinGroupCallManagerResult
    func scheduleGroupCall(context: AccountContext, peerId: PeerId, endCurrentIfAny: Bool) -> RequestScheduleGroupCallResult
}
