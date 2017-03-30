import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum AudioPlaylistItemLabelInfo: Equatable {
    case music(title: String?, performer: String?)
    case voice
    
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

private final class AudioPlaylistItemState {
    let item: AudioPlaylistItem
    let player: MediaPlayer?
    
    init(item: AudioPlaylistItem, player: MediaPlayer?) {
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
    private let postbox: Postbox
    let playlist: AudioPlaylist
    
    private let currentState = Atomic<AudioPlaylistInternalState>(value: AudioPlaylistInternalState())
    private let currentStateAndStatusValue = Promise<AudioPlaylistStateAndStatus?>()
    
    var stateAndStatus: Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.currentStateAndStatusValue.get()
    }
    
    init(audioSessionManager: ManagedAudioSession, postbox: Postbox, playlist: AudioPlaylist) {
        self.audioSessionManager = audioSessionManager
        self.postbox = postbox
        self.playlist = playlist
    }
    
    deinit {
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
                                item.player?.seek(timestamp: timestamp)
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
                disposable.set(self.playlist.navigate(currentItem, navigation).start(next: { [weak self] item in
                    if let strongSelf = self {
                        let updatedStateAndStatus = strongSelf.currentState.with { state -> AudioPlaylistStateAndStatus in
                            if let item = item {
                                if let item = item as? PeerMessageHistoryAudioPlaylistItem {
                                    switch item.entry {
                                        case let .MessageEntry(message, _, _, _):
                                            if message.flags.contains(.Incoming) {
                                                for attribute in message.attributes {
                                                    if let attribute = attribute as? ConsumableContentMessageAttribute {
                                                        if !attribute.consumed {
                                                            let _ = markMessageContentAsConsumedInteractively(postbox: strongSelf.postbox, messageId: message.id).start()
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
                                    let player = MediaPlayer(audioSessionManager: strongSelf.audioSessionManager, postbox: strongSelf.postbox, resource: resource, streamable: item.streamable)
                                    player.actionAtEnd = .action({
                                        if let strongSelf = self {
                                            strongSelf.control(.navigation(.next))
                                        }
                                    })
                                    state.currentItem = AudioPlaylistItemState(item: item, player: player)
                                    player.play()
                                    let playbackId = state.nextPlaybackId
                                    state.nextPlaybackId += 1
                                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: item), playbackId: playbackId, status: player.status)
                                } else {
                                    state.currentItem = AudioPlaylistItemState(item: item, player: nil)
                                    return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: item), playbackId: 0, status: nil)
                                }
                            } else {
                                state.currentItem = nil
                                return AudioPlaylistStateAndStatus(state: AudioPlaylistState(playlistId: strongSelf.playlist.id, item: nil), playbackId: 0, status: nil)
                            }
                        }
                        strongSelf.currentStateAndStatusValue.set(.single(updatedStateAndStatus))
                    }
                }))
        }
    }
}
