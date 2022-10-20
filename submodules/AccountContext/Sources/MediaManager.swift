import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import TelegramAudio
import UniversalMediaPlayer
import RangeSet

public enum PeerMessagesMediaPlaylistId: Equatable, SharedMediaPlaylistId {
    case peer(PeerId)
    case recentActions(PeerId)
    case feed(Int32)
    case custom
    
    public func isEqual(to: SharedMediaPlaylistId) -> Bool {
        if let to = to as? PeerMessagesMediaPlaylistId {
            return self == to
        }
        return false
    }
}
    
public enum PeerMessagesPlaylistLocation: Equatable, SharedMediaPlaylistLocation {
    case messages(chatLocation: ChatLocation, tagMask: MessageTags, at: MessageId)
    case singleMessage(MessageId)
    case recentActions(Message)
    case custom(messages: Signal<([Message], Int32, Bool), NoError>, at: MessageId, loadMore: (() -> Void)?)

    public var playlistId: PeerMessagesMediaPlaylistId {
        switch self {
            case let .messages(chatLocation, _, _):
                switch chatLocation {
                case let .peer(peerId):
                    return .peer(peerId)
                case let .replyThread(replyThreaMessage):
                    return .peer(replyThreaMessage.messageId.peerId)
                case let .feed(id):
                    return .feed(id)
                }
            case let .singleMessage(id):
                return .peer(id.peerId)
            case let .recentActions(message):
                return .recentActions(message.id.peerId)
            case .custom:
                return .custom
        }
    }
    
    public var messageId: MessageId? {
        switch self {
            case let .messages(_, _, messageId), let .singleMessage(messageId), let .custom(_, messageId, _):
                return messageId
            default:
                return nil
        }
    }
    
    public func isEqual(to: SharedMediaPlaylistLocation) -> Bool {
        if let to = to as? PeerMessagesPlaylistLocation {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: PeerMessagesPlaylistLocation, rhs: PeerMessagesPlaylistLocation) -> Bool {
        switch lhs {
            case let .messages(chatLocation, tagMask, at):
                if case .messages(chatLocation, tagMask, at) = rhs {
                    return true
                } else {
                    return false
                }
            case let .singleMessage(messageId):
                if case .singleMessage(messageId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .recentActions(lhsMessage):
                if case let .recentActions(rhsMessage) = rhs, lhsMessage.id == rhsMessage.id {
                    return true
                } else {
                    return false
                }
            case let .custom(_, lhsAt, _):
                if case let .custom(_, rhsAt, _) = rhs, lhsAt == rhsAt {
                    return true
                } else {
                    return false
                }
        }
    }
}

public func peerMessageMediaPlayerType(_ message: Message) -> MediaManagerPlayerType? {
    func extractFileMedia(_ message: Message) -> TelegramMediaFile? {
        var file: TelegramMediaFile?
        for media in message.media {
            if let media = media as? TelegramMediaFile {
                file = media
                break
            } else if let media = media as? TelegramMediaWebpage, case let .Loaded(content) = media.content, let f = content.file {
                file = f
                break
            }
        }
        return file
    }
    
    if let file = extractFileMedia(message) {
        if file.isVoice || file.isInstantVideo {
            return .voice
        } else if file.isMusic {
            return .music
        }
    }
    return nil
}
    
public func peerMessagesMediaPlaylistAndItemId(_ message: Message, isRecentActions: Bool, isGlobalSearch: Bool, isDownloadList: Bool) -> (SharedMediaPlaylistId, SharedMediaPlaylistItemId)? {
    if isGlobalSearch && !isDownloadList {
        return (PeerMessagesMediaPlaylistId.custom, PeerMessagesMediaPlaylistItemId(messageId: message.id, messageIndex: message.index))
    } else if isRecentActions && !isDownloadList {
        return (PeerMessagesMediaPlaylistId.recentActions(message.id.peerId), PeerMessagesMediaPlaylistItemId(messageId: message.id, messageIndex: message.index))
    } else {
        return (PeerMessagesMediaPlaylistId.peer(message.id.peerId), PeerMessagesMediaPlaylistItemId(messageId: message.id, messageIndex: message.index))
    }
}

public enum MediaManagerPlayerType {
    case voice
    case music
    case file
}

public protocol MediaManager: AnyObject {
    var audioSession: ManagedAudioSession { get }
    var galleryHiddenMediaManager: GalleryHiddenMediaManager { get }
    var universalVideoManager: UniversalVideoManager { get }
    var overlayMediaManager: OverlayMediaManager { get }
    
    var globalMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> { get }
    var musicMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> { get }
    var activeGlobalMediaPlayerAccountId: Signal<(AccountRecordId, Bool)?, NoError> { get }
    
    func setPlaylist(_ playlist: (Account, SharedMediaPlaylist)?, type: MediaManagerPlayerType, control: SharedMediaPlayerControlAction)
    func playlistControl(_ control: SharedMediaPlayerControlAction, type: MediaManagerPlayerType?)
    
    func filteredPlaylistState(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<SharedMediaPlayerItemPlaybackState?, NoError>
    func filteredPlayerAudioLevelEvents(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<Float, NoError>
    
    func setOverlayVideoNode(_ node: OverlayMediaItemNode?)
    func hasOverlayVideoNode(_ node: OverlayMediaItemNode) -> Bool
    
    func audioRecorder(beginWithTone: Bool, applicationBindings: TelegramApplicationBindings, beganWithTone: @escaping (Bool) -> Void) -> Signal<ManagedAudioRecorder?, NoError>
}

public enum GalleryHiddenMediaId: Hashable {
    case chat(AccountRecordId, MessageId, Media)
    
    public static func ==(lhs: GalleryHiddenMediaId, rhs: GalleryHiddenMediaId) -> Bool {
        switch lhs {
        case let .chat(lhsAccountId ,lhsMessageId, lhsMedia):
            if case let .chat(rhsAccountId, rhsMessageId, rhsMedia) = rhs, lhsAccountId == rhsAccountId, lhsMessageId == rhsMessageId, lhsMedia.isEqual(to: rhsMedia) {
                return true
            } else {
                return false
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .chat(accountId, messageId, _):
            hasher.combine(accountId)
            hasher.combine(messageId)
        }
    }
}

public protocol GalleryHiddenMediaTarget: AnyObject {
    func getTransitionInfo(messageId: MessageId, media: Media) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))?
}

public protocol GalleryHiddenMediaManager: AnyObject {
    func hiddenIds() -> Signal<Set<GalleryHiddenMediaId>, NoError>
    func addSource(_ signal: Signal<GalleryHiddenMediaId?, NoError>) -> Int
    func removeSource(_ index: Int)
    func addTarget(_ target: GalleryHiddenMediaTarget)
    func removeTarget(_ target: GalleryHiddenMediaTarget)
    func findTarget(messageId: MessageId, media: Media) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))?
}

public protocol UniversalVideoManager: AnyObject {
    func attachUniversalVideoContent(content: UniversalVideoContent, priority: UniversalVideoPriority, create: () -> UniversalVideoContentNode & ASDisplayNode, update: @escaping (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void) -> (AnyHashable, Int32)
    func detachUniversalVideoContent(id: AnyHashable, index: Int32)
    func withUniversalVideoContent(id: AnyHashable, _ f: ((UniversalVideoContentNode & ASDisplayNode)?) -> Void)
    func addPlaybackCompleted(id: AnyHashable, _ f: @escaping () -> Void) -> Int
    func removePlaybackCompleted(id: AnyHashable, index: Int)
    func statusSignal(content: UniversalVideoContent) -> Signal<MediaPlayerStatus?, NoError>
    func bufferingStatusSignal(content: UniversalVideoContent) -> Signal<(RangeSet<Int64>, Int64)?, NoError>
}

public enum AudioRecordingState: Equatable {
    case paused(duration: Double)
    case recording(duration: Double, durationMediaTimestamp: Double)
    case stopped
}

public struct RecordedAudioData {
    public let compressedData: Data
    public let duration: Double
    public let waveform: Data?
    
    public init(compressedData: Data, duration: Double, waveform: Data?) {
        self.compressedData = compressedData
        self.duration = duration
        self.waveform = waveform
    }
}

public protocol ManagedAudioRecorder: AnyObject {
    var beginWithTone: Bool { get }
    var micLevel: Signal<Float, NoError> { get }
    var recordingState: Signal<AudioRecordingState, NoError> { get }
    
    func start()
    func stop()
    func takenRecordedData() -> Signal<RecordedAudioData?, NoError>
}
