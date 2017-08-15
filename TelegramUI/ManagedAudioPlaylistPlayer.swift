import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum AudioPlaylistItemLabelInfo: Equatable {
    case music(title: String?, performer: String?)
    case voice
    case video
    
    static func ==(lhs: AudioPlaylistItemLabelInfo, rhs: AudioPlaylistItemLabelInfo) -> Bool {
        switch lhs {
            case let .music(lhsTitle, lhsPerformer):
                if case let .music(rhsTitle, rhsPerformer) = rhs, lhsTitle == rhsTitle, lhsPerformer == rhsPerformer {
                    return true
                } else {
                    return false
                }
            case .voice:
                if case .voice = rhs {
                    return true
                } else {
                    return false
                }
            case .video:
                if case .video = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct AudioPlaylistItemInfo: Equatable {
    let duration: Double
    let labelInfo: AudioPlaylistItemLabelInfo
    
    static func ==(lhs: AudioPlaylistItemInfo, rhs: AudioPlaylistItemInfo) -> Bool {
        if !lhs.duration.isEqual(to: rhs.duration) {
            return false
        }
        if lhs.labelInfo != rhs.labelInfo {
            return false
        }
        return true
    }
}

protocol AudioPlaylistItemId {
    var hashValue: Int { get }
    func isEqual(to: AudioPlaylistItemId) -> Bool
}

protocol AudioPlaylistItem {
    var id: AudioPlaylistItemId { get }
    var resource: MediaResource? { get }
    var info: AudioPlaylistItemInfo? { get }
    var streamable: Bool { get }
    
    func isEqual(to: AudioPlaylistItem) -> Bool
}

enum AudioPlaylistNavigation {
    case next
    case previous
}

enum AudioPlaylistPlayback {
    case play
    case pause
    case togglePlayPause
    case seek(Double)
}

enum AudioPlaylistControl {
    case navigation(AudioPlaylistNavigation)
    case playback(AudioPlaylistPlayback)
    case stop
}

protocol AudioPlaylistId {
    func isEqual(to: AudioPlaylistId) -> Bool
}

struct AudioPlaylist {
    let id: AudioPlaylistId
    let navigate: (AudioPlaylistItem?, AudioPlaylistNavigation) -> Signal<AudioPlaylistItem?, NoError>
}

struct AudioPlaylistState: Equatable {
    let playlistId: AudioPlaylistId
    let item: AudioPlaylistItem?
    
    static func ==(lhs: AudioPlaylistState, rhs: AudioPlaylistState) -> Bool {
        if !lhs.playlistId.isEqual(to: rhs.playlistId) {
            return false
        }
        
        if let lhsItem = lhs.item, let rhsItem = rhs.item {
            if !lhsItem.isEqual(to: rhsItem) {
                return false
            }
        } else if (lhs.item != nil) != (rhs.item != nil) {
            return false
        }
        return true
    }
}

struct AudioPlaylistStateAndStatus: Equatable {
    let state: AudioPlaylistState
    let playbackId: Int32
    let status: Signal<MediaPlayerStatus, NoError>?
    
    static func ==(lhs: AudioPlaylistStateAndStatus, rhs: AudioPlaylistStateAndStatus) -> Bool {
        return lhs.state == rhs.state && lhs.playbackId == rhs.playbackId
    }
}

private enum AudioPlaylistItemPlayer {
    case player(MediaPlayer)
    case sharedVideo(InstantVideoNode)
    
    func play() {
        switch self {
            case let .player(player):
                player.play()
            case let .sharedVideo(node):
                node.play()
        }
    }
    
    func pause() {
        switch self {
            case let .player(player):
                player.pause()
            case let .sharedVideo(node):
                node.pause()
        }
    }
    
    func togglePlayPause() {
        switch self {
            case let .player(player):
                player.togglePlayPause()
            case let .sharedVideo(node):
                node.togglePlayPause()
        }
    }
    
    func seek(_ timestamp: Double) {
        switch self {
            case let .player(player):
                player.seek(timestamp: timestamp)
            case let .sharedVideo(node):
                node.seek(timestamp)
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        switch self {
            case .player:
                break
            case let .sharedVideo(node):
                node.setSoundEnabled(value)
        }
    }
}

private final class AudioPlaylistItemState {
    let item: AudioPlaylistItem
    let player: AudioPlaylistItemPlayer?
    
    init(item: AudioPlaylistItem, player: AudioPlaylistItemPlayer?) {
        self.item = item
        self.player = player
    }
}

private final class AudioPlaylistInternalState {
    var currentItem: AudioPlaylistItemState?
    let navigationDisposable = MetaDisposable()
    var nextPlaybackId: Int32 = 0
}

final class ManagedAudioPlaylistPlayer {
    private let audioSessionManager: ManagedAudioSession
    private let overlayMediaManager: OverlayMediaManager
    private weak var account: Account?
    private weak var mediaManager: MediaManager?
    private let postbox: Postbox
    let playlist: AudioPlaylist
    
    private let currentState = Atomic<AudioPlaylistInternalState>(value: AudioPlaylistInternalState())
    private let currentStateAndStatusValue = Promise<AudioPlaylistStateAndStatus?>()
    private let overlayContextValue = Promise<InstantVideoNode?>(nil)
    
    var stateAndStatus: Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.currentStateAndStatusValue.get()
    }
    
    var currentVideoNode: InstantVideoNode?
    var overlayContextDisposable: Disposable?
    
    init(audioSessionManager: ManagedAudioSession, overlayMediaManager: OverlayMediaManager, mediaManager: MediaManager, account: Account, postbox: Postbox, playlist: AudioPlaylist) {
        self.audioSessionManager = audioSessionManager
        self.overlayMediaManager = overlayMediaManager
        self.mediaManager = mediaManager
        self.account = account
        self.postbox = postbox
        self.playlist = playlist
        
        self.overlayContextDisposable = (self.overlayContextValue.get() |> deliverOnMainQueue).start(next: { [weak self] node in
            if let strongSelf = self {
                if strongSelf.currentVideoNode !== node {
                    if let currentVideoNode = strongSelf.currentVideoNode {
                        currentVideoNode.setSoundEnabled(false)
                        strongSelf.overlayMediaManager.controller?.removeNode(currentVideoNode)
                    }
                    strongSelf.currentVideoNode = node
                    if let node = node {
                        strongSelf.overlayMediaManager.controller?.addNode(node)
                    }
                }
            }
        })
    }
    
    deinit {
        self.overlayContextDisposable?.dispose()
        if let currentVideoNode = self.currentVideoNode {
            self.overlayMediaManager.controller?.removeNode(currentVideoNode)
            currentVideoNode.setSoundEnabled(false)
        }
        self.currentState.with { state -> Void in
            state.navigationDisposable.dispose()
        }
    }
    
    func control(_ control: AudioPlaylistControl) {
        switch control {
            case let .playback(playback):
                self.currentState.with { state -> Void in
                    if let item = state.currentItem {
                        switch playback {
                            case .play:
                                item.player?.play()
                            case .pause:
                                item.player?.pause()
                            case .togglePlayPause:
                                item.player?.togglePlayPause()
                            case let .seek(timestamp):
                                item.player?.seek(timestamp)
                        }
                    }
                }
            case let .navigation(navigation):
                let disposable = MetaDisposable()
                var currentItem: AudioPlaylistItem?
                self.currentState.with { state -> Void in
                    state.navigationDisposable.set(disposable)
                    currentItem = state.currentItem?.item
                }
                let postbox = self.postbox
                let audioSessionManager = self.audioSessionManager
                let mediaManager = self.mediaManager
                let account = self.account
                disposable.set((self.playlist.navigate(currentItem, navigation)
                    |> deliverOnMainQueue
                    |> mapToSignal { [weak mediaManager] item -> Signal<(AudioPlaylistItem, AudioPlaylistItemState)?, NoError> in
                        if let item = item {
                            var instantVideo: (TelegramMediaFile, MessageId, UInt32)?
                            if let item = item as? PeerMessageHistoryAudioPlaylistItem {
                                switch item.entry {
                                case let .MessageEntry(message, _, _, _):
                                    for media in message.media {
                                        if let file = media as? TelegramMediaFile {
                                            if file.isInstantVideo {
                                                instantVideo = (file, message.id, message.stableId)
                                            }
                                        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                            if let file = content.file {
                                                if file.isInstantVideo {
                                                    instantVideo = (file, message.id, message.stableId)
                                                }
                                            }
                                        }
                                    }
                                    if message.flags.contains(.Incoming) {
                                        for attribute in message.attributes {
                                            if let attribute = attribute as? ConsumableContentMessageAttribute {
                                                if !attribute.consumed {
                                                    let _ = markMessageContentAsConsumedInteractively(postbox: postbox, messageId: message.id).start()
                                                }
                                                break
                                            }
                                        }
                                    }
                                case .HoleEntry:
                                    break
                                }
                            }
                            
                            if let resource = item.resource {
                                var itemPlayer: AudioPlaylistItemPlayer?
                                if let instantVideo = instantVideo {
                                    if let mediaManager = mediaManager, let account = account {
                                        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                                        let videoNode = InstantVideoNode(theme: presentationData.theme, manager: mediaManager, account: account, source: .messageMedia(stableId: instantVideo.2, file: instantVideo.0), priority: 0, withSound: true)
                                        videoNode.tapped = { [weak videoNode] in
                                            videoNode?.togglePlayPause()
                                        }
                                        itemPlayer = .sharedVideo(videoNode)
                                    }
                                } else {
                                    let player = MediaPlayer(audioSessionManager: audioSessionManager, postbox: postbox, resource: resource, streamable: item.streamable, video: false, preferSoftwareDecoding: false, enableSound: true)
                                    itemPlayer = .player(player)
                                }
                                return .single((item, AudioPlaylistItemState(item: item, player: itemPlayer)))
                            } else {
                                return .single((item, AudioPlaylistItemState(item: item, player: nil)))
                            }
                        } else {
                            return .single(nil)
                        }
                    }).start(next: { [weak self] next in
                        if let strongSelf = self {
                            let updatedStateAndStatus = strongSelf.currentState.with { state -> AudioPlaylistStateAndStatus in
                                if let (item, itemState) = next {
                                    state.currentItem = itemState
                                    var status: Signal<MediaPlayerStatus, NoError>?
                                    if let player = itemState.player {
                                        switch player {
                                            case let .player(player):
                                                player.play()
                                                player.actionAtEnd = .action({
                                                    if let strongSelf = self {
                                                        strongSelf.control(.navigation(.next))
                                                    }
                                                })
                                                status = player.status
                                            case let .sharedVideo(videoNode):
                                                videoNode.playbackEnded = { [weak videoNode] in
                                                    Queue.mainQueue().async {
                                                        if let videoNode = videoNode {
                                                            videoNode.setSoundEnabled(false)
                                                            videoNode.play()
                                                        }
                                                        if let strongSelf = self {
                                                            strongSelf.control(.navigation(.next))
                                                        }
                                                    }
                                                }
                                                videoNode.dismissed = {
                                                    if let strongSelf = self {
                                                        strongSelf.control(.stop)
                                                    }
                                                }
                                                status = videoNode.status
                                        }
                                    }
                                    let playbackId = state.nextPlaybackId
                                    state.nextPlaybackId += 1
                                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: item), playbackId: playbackId, status: status)
                                } else {
                                    state.currentItem = nil
                                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: nil), playbackId: 0, status: nil)
                                }
                            }
                            strongSelf.currentStateAndStatusValue.set(.single(updatedStateAndStatus))
                            var overlayContextValue: InstantVideoNode?
                            if let (_, itemState) = next {
                                if let player = itemState.player, case let .sharedVideo(node) = player {
                                    overlayContextValue = node
                                    node.setSoundEnabled(true)
                                }
                            }
                            strongSelf.overlayContextValue.set(.single(overlayContextValue))
                        }
                    }))
            case .stop:
                let updatedStateAndStatus = self.currentState.with { state -> AudioPlaylistStateAndStatus in
                    state.currentItem = nil
                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: self.playlist.id, item: nil), playbackId: 0, status: nil)
                }
                self.currentStateAndStatusValue.set(.single(updatedStateAndStatus))
                self.overlayContextValue.set(.single(nil))
        }
    }
}
