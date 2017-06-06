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
    case videoContext(ManagedMediaId, MediaResource, MediaPlayer, Disposable)
    
    var player: MediaPlayer {
        switch self {
            case let .player(player):
                return player
            case let .videoContext(_, _, player, _):
                return player
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
    private weak var mediaManager: MediaManager?
    private let postbox: Postbox
    let playlist: AudioPlaylist
    
    private let currentState = Atomic<AudioPlaylistInternalState>(value: AudioPlaylistInternalState())
    private let currentStateAndStatusValue = Promise<AudioPlaylistStateAndStatus?>()
    private let overlayContextValue = Promise<(ManagedMediaId, MediaResource, Disposable)?>(nil)
    
    var stateAndStatus: Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.currentStateAndStatusValue.get()
    }
    
    var currentContext: (ManagedMediaId, MediaResource, Disposable)?
    
    var overlayContextDisposable: Disposable?
    
    init(audioSessionManager: ManagedAudioSession, overlayMediaManager: OverlayMediaManager, mediaManager: MediaManager, postbox: Postbox, playlist: AudioPlaylist) {
        self.audioSessionManager = audioSessionManager
        self.overlayMediaManager = overlayMediaManager
        self.mediaManager = mediaManager
        self.postbox = postbox
        self.playlist = playlist
        
        self.overlayContextDisposable = (self.overlayContextValue.get() |> deliverOnMainQueue).start(next: { [weak self] context in
            if let strongSelf = self {
                var updated = false
                if let lhsId = strongSelf.currentContext?.0, let rhsId = context?.0 {
                    updated = !lhsId.isEqual(to: rhsId)
                } else if (strongSelf.currentContext?.0 != nil) != (context?.0 != nil) {
                    updated = true
                }
                if updated {
                    strongSelf.currentContext?.2.dispose()
                    if let id = strongSelf.currentContext?.0 {
                        strongSelf.overlayMediaManager.controller?.removeVideoContext(id: id)
                    }
                    strongSelf.currentContext = context
                    if let (id, resource, _) = context, let mediaManager = strongSelf.mediaManager {
                        strongSelf.overlayMediaManager.controller?.addVideoContext(mediaManager: mediaManager, postbox: postbox, id: id, resource: resource, priority: 0)
                    }
                }
            }
        })
    }
    
    deinit {
        self.overlayContextDisposable?.dispose()
        if let id = self.currentContext?.0 {
            self.overlayMediaManager.controller?.removeVideoContext(id: id)
        }
        self.currentContext?.2.dispose()
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
                                item.player?.player.play()
                            case .pause:
                                item.player?.player.pause()
                            case .togglePlayPause:
                                item.player?.player.togglePlayPause()
                            case let .seek(timestamp):
                                item.player?.player.seek(timestamp: timestamp)
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
                let overlayMediaManager = self.overlayMediaManager
                let mediaManager = self.mediaManager
                disposable.set((self.playlist.navigate(currentItem, navigation)
                    |> deliverOnMainQueue
                    |> mapToSignal { [weak mediaManager] item -> Signal<(AudioPlaylistItem, AudioPlaylistItemState)?, NoError> in
                        if let item = item {
                            var instantVideo: (MediaResource, MessageId)?
                            if let item = item as? PeerMessageHistoryAudioPlaylistItem {
                                switch item.entry {
                                case let .MessageEntry(message, _, _, _):
                                    for media in message.media {
                                        if let file = media as? TelegramMediaFile {
                                            if file.isInstantVideo {
                                                instantVideo = (file.resource, message.id)
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
                                    if let mediaManager = mediaManager {
                                        let (player, disposable) = mediaManager.videoContext(postbox: postbox, id: PeerMessageManagedMediaId(messageId: instantVideo.1), resource: instantVideo.0, preferSoftwareDecoding: false, backgroundThread: false, priority: -1, initiatePlayback: true, activate: { _ in
                                        }, deactivate: {
                                            return .complete()
                                        })
                                        itemPlayer = .videoContext(PeerMessageManagedMediaId(messageId: instantVideo.1), instantVideo.0, player, disposable)
                                    }
                                } else {
                                    let player = MediaPlayer(audioSessionManager: audioSessionManager, overlayMediaManager: overlayMediaManager, postbox: postbox, resource: resource, streamable: item.streamable, video: false, preferSoftwareDecoding: false, enableSound: true)
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
                                    if let player = itemState.player {
                                        switch player {
                                            case let .player(player):
                                                player.play()
                                                player.actionAtEnd = .action({
                                                    if let strongSelf = self {
                                                        strongSelf.control(.navigation(.next))
                                                    }
                                                })
                                            case let .videoContext(_, _, player, _):
                                                player.actionAtEnd = .loopDisablingSound({
                                                    if let strongSelf = self {
                                                        strongSelf.control(.navigation(.next))
                                                    }
                                                })
                                                player.playOnceWithSound()
                                        }
                                    }
                                    let playbackId = state.nextPlaybackId
                                    state.nextPlaybackId += 1
                                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: item), playbackId: playbackId, status: itemState.player?.player.status)
                                } else {
                                    state.currentItem = nil
                                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: nil), playbackId: 0, status: nil)
                                }
                            }
                            strongSelf.currentStateAndStatusValue.set(.single(updatedStateAndStatus))
                            var overlayContextValue: (ManagedMediaId, MediaResource, Disposable)?
                            if let (_, itemState) = next {
                                if let player = itemState.player, case let .videoContext(id, resource, _, disposable) = player {
                                    overlayContextValue = (id, resource, disposable)
                                }
                            }
                            strongSelf.overlayContextValue.set(.single(overlayContextValue))
                        }
                    }))
        }
    }
}
