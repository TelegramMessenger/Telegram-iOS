import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
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
        case active
        case paused
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
    
    public init(
        holder: AnyObject,
        view: UIView,
        setOnFirstFrameReceived: @escaping (((Float) -> Void)?) -> Void,
        getOrientation: @escaping () -> Orientation,
        getAspect: @escaping () -> CGFloat,
        setOnOrientationUpdated: @escaping (((Orientation, CGFloat) -> Void)?) -> Void,
        setOnIsMirroredUpdated: @escaping (((Bool) -> Void)?) -> Void
    ) {
        self.holder = holder
        self.view = view
        self.setOnFirstFrameReceived = setOnFirstFrameReceived
        self.getOrientation = getOrientation
        self.getAspect = getAspect
        self.setOnOrientationUpdated = setOnOrientationUpdated
        self.setOnIsMirroredUpdated = setOnIsMirroredUpdated
    }
}

public protocol PresentationCall: class {
    var account: Account { get }
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

public struct PresentationGroupCallState: Equatable {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public enum DefaultParticipantMuteState {
        case unmuted
        case muted
    }
    
    public var networkState: NetworkState
    public var canManageCall: Bool
    public var adminIds: Set<PeerId>
    public var muteState: GroupCallParticipantsContext.Participant.MuteState?
    public var defaultParticipantMuteState: DefaultParticipantMuteState?
    
    public init(
        networkState: NetworkState,
        canManageCall: Bool,
        adminIds: Set<PeerId>,
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        defaultParticipantMuteState: DefaultParticipantMuteState?
    ) {
        self.networkState = networkState
        self.canManageCall = canManageCall
        self.adminIds = adminIds
        self.muteState = muteState
        self.defaultParticipantMuteState = defaultParticipantMuteState
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
    public let joined: Bool
    
    public init(peer: Peer, joined: Bool) {
        self.peer = peer
        self.joined = joined
    }
}

public protocol PresentationGroupCall: class {
    var account: Account { get }
    var accountContext: AccountContext { get }
    var internalId: CallSessionInternalId { get }
    var peerId: PeerId { get }
    
    var isVideo: Bool { get }
    
    var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> { get }
    
    var canBeRemoved: Signal<Bool, NoError> { get }
    var state: Signal<PresentationGroupCallState, NoError> { get }
    var summaryState: Signal<PresentationGroupCallSummaryState?, NoError> { get }
    var members: Signal<PresentationGroupCallMembers?, NoError> { get }
    var audioLevels: Signal<[(PeerId, UInt32, Float, Bool)], NoError> { get }
    var myAudioLevel: Signal<Float, NoError> { get }
    var isMuted: Signal<Bool, NoError> { get }
    
    var memberEvents: Signal<PresentationGroupCallMemberEvent, NoError> { get }
    
    func leave(terminateIfPossible: Bool) -> Signal<Bool, NoError>
    
    func toggleIsMuted()
    func setIsMuted(action: PresentationGroupCallMuteAction)
    func requestVideo()
    func disableVideo()
    func updateDefaultParticipantsAreMuted(isMuted: Bool)
    func setVolume(peerId: PeerId, volume: Int32, sync: Bool)
    func setFullSizeVideo(peerId: PeerId?)
    func setCurrentAudioOutput(_ output: AudioSessionOutput)
    
    func updateMuteState(peerId: PeerId, isMuted: Bool) -> GroupCallParticipantsContext.Participant.MuteState?
    
    func invitePeer(_ peerId: PeerId) -> Bool
    func removedPeer(_ peerId: PeerId)
    var invitedPeers: Signal<[PeerId], NoError> { get }
    
    var incomingVideoSources: Signal<[PeerId: UInt32], NoError> { get }
    
    func makeIncomingVideoView(source: UInt32, completion: @escaping (PresentationCallVideoView?) -> Void)
    
    func loadMoreMembers(token: String)
}

public protocol PresentationCallManager: class {
    var currentCallSignal: Signal<PresentationCall?, NoError> { get }
    var currentGroupCallSignal: Signal<PresentationGroupCall?, NoError> { get }
    
    func requestCall(context: AccountContext, peerId: PeerId, isVideo: Bool, endCurrentIfAny: Bool) -> RequestCallResult
    func joinGroupCall(context: AccountContext, peerId: PeerId, initialCall: CachedChannelData.ActiveCall, endCurrentIfAny: Bool) -> JoinGroupCallManagerResult
}
