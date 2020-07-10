import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramAudio

public enum RequestCallResult {
    case requested
    case alreadyInProgress(PeerId)
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
        case terminating
        case terminated(CallId?, CallSessionTerminationReason?, Bool)
    }
    
    public enum VideoState: Equatable {
        case notAvailable
        case possible
        case outgoingRequested
        case incomingRequested
        case active
    }
    
    public enum RemoteVideoState: Equatable {
        case inactive
        case active
    }
    
    public var state: State
    public var videoState: VideoState
    public var remoteVideoState: RemoteVideoState
    
    public init(state: State, videoState: VideoState, remoteVideoState: RemoteVideoState) {
        self.state = state
        self.videoState = videoState
        self.remoteVideoState = remoteVideoState
    }
}

public final class PresentationCallVideoView {
    public let view: UIView
    public let setOnFirstFrameReceived: ((() -> Void)?) -> Void
    
    public init(
        view: UIView,
        setOnFirstFrameReceived: @escaping ((() -> Void)?) -> Void
    ) {
        self.view = view
        self.setOnFirstFrameReceived = setOnFirstFrameReceived
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

    var isMuted: Signal<Bool, NoError> { get }
    
    var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> { get }
    
    var canBeRemoved: Signal<Bool, NoError> { get }
    
    func answer()
    func hangUp() -> Signal<Bool, NoError>
    func rejectBusy()
    
    func toggleIsMuted()
    func setIsMuted(_ value: Bool)
    func requestVideo()
    func acceptVideo()
    func setOutgoingVideoIsPaused(_ isPaused: Bool)
    func switchVideoCamera()
    func setCurrentAudioOutput(_ output: AudioSessionOutput)
    func debugInfo() -> Signal<(String, String), NoError>
    
    func makeIncomingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void)
    func makeOutgoingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void)
}

public protocol PresentationCallManager: class {
    var currentCallSignal: Signal<PresentationCall?, NoError> { get }
    
    func requestCall(account: Account, peerId: PeerId, isVideo: Bool, endCurrentIfAny: Bool) -> RequestCallResult
}
