import Foundation
import TelegramCore
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import TelegramAudio
import UniversalMediaPlayer
import RangeSet

public enum PeerMessagesMediaPlaylistId: Equatable, SharedMediaPlaylistId {
    case peer(EnginePeer.Id)
    case recentActions(EnginePeer.Id)
    case feed(Int32)
    case savedMusic(EnginePeer.Id)
    case custom
    
    public func isEqual(to: SharedMediaPlaylistId) -> Bool {
        if let to = to as? PeerMessagesMediaPlaylistId {
            return self == to
        }
        return false
    }
}
    
/// Where an `InstantPageMediaPlaylist` came from: an Instant View page, or — when `messageId` is
/// non-nil — the `RichTextMessageAttribute` of that chat message.
///
/// It lives HERE rather than beside the playlist in `InstantPageUI` because the shared media
/// accessory panel (`MediaPlaybackHeaderPanelComponent`) has to recognise it, and both modules
/// already depend on `AccountContext`; routing the panel through `InstantPageUI` instead would drag
/// the whole Instant View renderer into the chat-list header.
///
/// `messageId` is what makes the panel actionable: tapping the mini player opens the full music
/// player for that message. An Instant View page (`messageId == nil`) has no message to open, so the
/// panel tap stays inert there, as it always was.
/// One audio track of an InstantPage playlist, as the player queue needs to render it.
/// `index` is `InstantPageMedia.index` — the playlist's item identity — so a queue row maps back
/// to a playlist item exactly. Declared here rather than reusing `InstantPageMedia` because
/// `AccountContext` does not (and must not) depend on `InstantPageUI`.
public struct InstantPagePlaylistTrack: Equatable {
    public let index: Int
    public let file: TelegramMediaFile

    public init(index: Int, file: TelegramMediaFile) {
        self.index = index
        self.file = file
    }
}

public struct InstantPagePlaylistLocation: SharedMediaPlaylistLocation {
    public let webpageId: EngineMedia.Id
    public let messageId: EngineMessage.Id?
    /// Display payload for the player queue, NOT part of this location's identity.
    public let tracks: [InstantPagePlaylistTrack]
    /// Everything needed to rebuild the SAME playlist re-anchored on another track when a queue
    /// row is tapped. Both are TelegramCore types, so carrying them adds no module dependency.
    public let webPage: TelegramMediaWebpage?
    public let messageReference: MessageReference?

    public init(webpageId: EngineMedia.Id, messageId: EngineMessage.Id?, tracks: [InstantPagePlaylistTrack] = [], webPage: TelegramMediaWebpage? = nil, messageReference: MessageReference? = nil) {
        self.webpageId = webpageId
        self.messageId = messageId
        self.tracks = tracks
        self.webPage = webPage
        self.messageReference = messageReference
    }

    public func isEqual(to: SharedMediaPlaylistLocation) -> Bool {
        guard let to = to as? InstantPagePlaylistLocation else {
            return false
        }
        // Identity is the page and the message only. Including `tracks` would make
        // `areSharedMediaPlaylistsEqual` report a different playlist whenever the list is rebuilt.
        return self.webpageId == to.webpageId && self.messageId == to.messageId
    }
}

public enum PeerMessagesPlaylistLocation: Equatable, SharedMediaPlaylistLocation {
    case messages(chatLocation: ChatLocation, tagMask: EngineMessage.Tags, at: EngineMessage.Id)
    case singleMessage(EngineMessage.Id)
    case recentActions(EngineRawMessage)
    case savedMusic(context: ProfileSavedMusicContext, at: Int32, canReorder: Bool)
    case custom(messages: Signal<([EngineRawMessage], Int32, Bool), NoError>, canReorder: Bool, at: EngineMessage.Id, loadMore: (() -> Void)?, hidePanel: Bool)

    public var playlistId: PeerMessagesMediaPlaylistId {
        switch self {
            case let .messages(chatLocation, _, _):
                switch chatLocation {
                case let .peer(peerId):
                    return .peer(peerId)
                case let .replyThread(replyThreaMessage):
                    return .peer(replyThreaMessage.peerId)
                case .customChatContents:
                    return .custom
                }
            case let .singleMessage(id):
                return .peer(id.peerId)
            case let .recentActions(message):
                return .recentActions(message.id.peerId)
            case let .savedMusic(context, _, _):
                return .savedMusic(context.peerId)
            case .custom:
                return .custom
        }
    }
    
    public func effectiveLocation(context: AccountContext) -> PeerMessagesPlaylistLocation {
        switch self {
        case let .savedMusic(savedMusicContext, at, canReorder):
            let peerId = savedMusicContext.peerId
            return .custom(
                messages: combineLatest(
                    savedMusicContext.state,
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: savedMusicContext.peerId))
                )
                |> map { state, peer in
                    var messages: [EngineRawMessage] = []
                    var peers = EngineSimpleDictionary<EnginePeer.Id, EngineRawPeer>()
                    if let peer {
                        peers[peerId] = peer._asPeer()
                    }
                    for file in state.files {
                        let stableId = UInt32(clamping: file.fileId.id % Int64(Int32.max))
                        messages.append(EngineRawMessage(stableId: stableId, stableVersion: 0, id: EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Local, id: Int32(stableId)), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [.music], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file], peers: peers, associatedMessages: EngineSimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:]))
                    }
                    var canLoadMore = false
                    if case let .ready(canLoadMoreValue) = state.dataState {
                        canLoadMore = canLoadMoreValue
                    }
                    return (messages, Int32(messages.count), canLoadMore)
                },
                canReorder: canReorder,
                at: EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Local, id: at),
                loadMore: { [weak savedMusicContext] in
                    guard let savedMusicContext else {
                        return
                    }
                    savedMusicContext.loadMore()
                },
                hidePanel: false
            )
        default:
            return self
        }
    }
    
    public var messageId: EngineMessage.Id? {
        switch self {
            case let .messages(_, _, messageId), let .singleMessage(messageId), let .custom(_, _, messageId, _, _):
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
            case let .savedMusic(lhsContext, lhsAt, _):
                if case let .savedMusic(rhsContext, rhsAt, _) = rhs {
                    return lhsContext.peerId == rhsContext.peerId && lhsAt == rhsAt
                } else {
                    return false
                }
            case let .custom(_, _, lhsAt, _, _):
                if case let .custom(_, _, rhsAt, _, _) = rhs, lhsAt == rhsAt {
                    return true
                } else {
                    return false
                }
        }
    }
}

public func peerMessageMediaPlayerType(_ message: EngineMessage) -> MediaManagerPlayerType? {
    func extractFileMedia(_ message: EngineMessage) -> TelegramMediaFile? {
        var file: TelegramMediaFile?
        for media in message.media {
            if let media = media as? TelegramMediaFile {
                file = media
                break
            } else if let media = media as? TelegramMediaWebpage, case let .Loaded(content) = media.content, let f = content.file {
                file = f
                break
            } else if let media = media as? TelegramMediaPoll, let f = media.attachedMedia as? TelegramMediaFile {
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
    
public func peerMessagesMediaPlaylistAndItemId(_ message: EngineMessage, isRecentActions: Bool, isGlobalSearch: Bool, isDownloadList: Bool, isSavedMusic: Bool, isAttachMusic: Bool, richMessageQueueId: EngineMessage.Id? = nil) -> (SharedMediaPlaylistId, SharedMediaPlaylistItemId)? {
    if let richMessageQueueId {
        // A rich message's audio queue renders synthesized Local-id rows whose id.id IS the
        // InstantPageMedia index. The playing playlist is an InstantPageMediaPlaylist, so its
        // identity — not a PeerMessages one — is what the row must be compared against.
        return (RichMessagePlaylistId(messageId: richMessageQueueId), RichMessagePlaylistItemId(index: Int(message.id.id)))
    }
    if isSavedMusic {
        return (PeerMessagesMediaPlaylistId.savedMusic(message.id.peerId), PeerMessagesMediaPlaylistItemId(messageId: message.id, messageIndex: message.index))
    } else if isAttachMusic || (isGlobalSearch && !isDownloadList) {
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

public struct AudioRecorderResumeData {
    public let compressedData: Data
    public let resumeData: Data
    
    public init(compressedData: Data, resumeData: Data) {
        self.compressedData = compressedData
        self.resumeData = resumeData
    }
}

public protocol MediaManager: AnyObject {
    var audioSession: ManagedAudioSession { get }
    var galleryHiddenMediaManager: GalleryHiddenMediaManager { get }
    var universalVideoManager: UniversalVideoManager { get }
    var overlayMediaManager: OverlayMediaManager { get }
    
    var currentPictureInPictureNode: AnyObject? { get set }
    
    var globalMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> { get }
    var musicMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> { get }
    var activeGlobalMediaPlayerAccountId: Signal<(AccountRecordId, Bool)?, NoError> { get }
    
    func setPlaylist(_ playlist: (AccountContext, SharedMediaPlaylist)?, type: MediaManagerPlayerType, control: SharedMediaPlayerControlAction)
    func playlistControl(_ control: SharedMediaPlayerControlAction, type: MediaManagerPlayerType?)
    
    func filteredPlaylistState(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<SharedMediaPlayerItemPlaybackState?, NoError>
    func filteredPlayerAudioLevelEvents(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<Float, NoError>
    
    func setOverlayVideoNode(_ node: OverlayMediaItemNode?)
    func hasOverlayVideoNode(_ node: OverlayMediaItemNode) -> Bool
    
    func audioRecorder(
        resumeData: AudioRecorderResumeData?,
        beginWithTone: Bool,
        pauseMusicOnRecording: Bool,
        applicationBindings: TelegramApplicationBindings,
        beganWithTone: @escaping (Bool) -> Void
    ) -> Signal<ManagedAudioRecorder?, NoError>
}

public enum GalleryHiddenMediaId: Hashable {
    case chat(AccountRecordId, EngineMessage.Id, EngineRawMedia)
    
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
    func getTransitionInfo(messageId: EngineMessage.Id, media: EngineMedia) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))?
}

public protocol GalleryHiddenMediaManager: AnyObject {
    func hiddenIds() -> Signal<Set<GalleryHiddenMediaId>, NoError>
    func addSource(_ signal: Signal<GalleryHiddenMediaId?, NoError>) -> Int
    func removeSource(_ index: Int)
    func addTarget(_ target: GalleryHiddenMediaTarget)
    func removeTarget(_ target: GalleryHiddenMediaTarget)
    func findTarget(messageId: EngineMessage.Id, media: EngineMedia) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))?
}

public protocol UniversalVideoManager: AnyObject {
    func attachUniversalVideoContent(content: UniversalVideoContent, priority: UniversalVideoPriority, create: () -> UniversalVideoContentNode & ASDisplayNode, update: @escaping (((UniversalVideoContentNode & ASDisplayNode), Bool)?) -> Void) -> (AnyHashable, Int32)
    func detachUniversalVideoContent(id: AnyHashable, index: Int32)
    func withUniversalVideoContent(id: AnyHashable, _ f: ((UniversalVideoContentNode & ASDisplayNode)?) -> Void)
    func addPlaybackCompleted(id: AnyHashable, _ f: @escaping () -> Void) -> Int
    func removePlaybackCompleted(id: AnyHashable, index: Int)
    func statusSignal(content: UniversalVideoContent) -> Signal<MediaPlayerStatus?, NoError>
    func bufferingStatusSignal(content: UniversalVideoContent) -> Signal<(RangeSet<Int64>, Int64)?, NoError>
    func isNativePictureInPictureActiveSignal(content: UniversalVideoContent) -> Signal<Bool, NoError>
}

public enum AudioRecordingState: Equatable {
    case paused(duration: Double)
    case recording(duration: Double, durationMediaTimestamp: Double)
    case stopped
}

public struct RecordedAudioData {
    public let compressedData: Data
    public let resumeData: Data?
    public let duration: Double
    public let waveform: Data?
    public let trimRange: Range<Double>?
    
    public init(compressedData: Data, resumeData: Data?, duration: Double, waveform: Data?, trimRange: Range<Double>?) {
        self.compressedData = compressedData
        self.resumeData = resumeData
        self.duration = duration
        self.waveform = waveform
        self.trimRange = trimRange
    }
}

public protocol ManagedAudioRecorder: AnyObject {
    var beginWithTone: Bool { get }
    var micLevel: Signal<Float, NoError> { get }
    var recordingState: Signal<AudioRecordingState, NoError> { get }
    
    func start()
    func pause()
    func resume()
    func stop()
    func takenRecordedData() -> Signal<RecordedAudioData?, NoError>
    
    func updateTrimRange(start: Double, end: Double, updatedEnd: Bool, apply: Bool)
}
