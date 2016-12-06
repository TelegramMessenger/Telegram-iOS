import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum AudioPlaylistItemLabelInfo {
    case music(title: String?, performer: String?)
    case voice
}

struct AudioPlaylistItemInfo {
    let duration: Double
    let labelInfo: AudioPlaylistItemLabelInfo
}

protocol AudioPlaylistItemId {
    var hashValue: Int { get }
    func isEqual(other: AudioPlaylistItemId) -> Bool
}

protocol AudioPlaylistItem {
    var id: AudioPlaylistItemId { get }
    var resource: MediaResource? { get }
    var info: AudioPlaylistItemInfo? { get }
    
    func isEqual(other: AudioPlaylistItem) -> Bool
}

enum AudioPlaylistNavigation {
    case next
    case previous
}

enum AudioPlaylistPlayback {
    case play
    case pause
}

enum AudioPlaylistControl {
    case navigation(AudioPlaylistNavigation)
    case playback(AudioPlaylistPlayback)
}

protocol AudioPlaylistId {
    func isEqual(other: AudioPlaylistId) -> Bool
}

struct AudioPlaylist {
    let id: AudioPlaylistId
    let navigate: (AudioPlaylistItem?, AudioPlaylistNavigation) -> Signal<AudioPlaylistItem?, NoError>
}

struct AudioPlaylistState: Equatable {
    let playlistId: AudioPlaylistId
    let item: AudioPlaylistItem?
    
    static func ==(lhs: AudioPlaylistState, rhs: AudioPlaylistState) -> Bool {
        if !lhs.playlistId.isEqual(other: rhs.playlistId) {
            return false
        }
        
        if let lhsItem = lhs.item, let rhsItem = rhs.item {
            if !lhsItem.isEqual(other: rhsItem) {
                return false
            }
        } else if (lhs.item != nil) != (rhs.item != nil) {
            return false
        }
        return true
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
}

final class ManagedAudioPlaylistPlayer {
    private let postbox: Postbox
    let playlist: AudioPlaylist
    
    private let currentState = Atomic<AudioPlaylistInternalState>(value: AudioPlaylistInternalState())
    private let currentStateValue = Promise<AudioPlaylistState?>()
    
    var state: Signal<AudioPlaylistState?, NoError> {
        return self.currentStateValue.get()
    }
    
    init(postbox: Postbox, playlist: AudioPlaylist) {
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
                        }
                    }
                }
            case let .navigation(navigation):
                let disposable = MetaDisposable()
                var currentItem: AudioPlaylistItem?
                self.currentState.with { state -> Void in
                    state.navigationDisposable.set(disposable)
                }
                disposable.set(self.playlist.navigate(currentItem, navigation).start(next: { [weak self] item in
                    if let strongSelf = self {
                        let updatedState = strongSelf.currentState.with { state -> AudioPlaylistState in
                            if let item = item {
                                var player: MediaPlayer?
                                if let resource = item.resource {
                                    player = MediaPlayer(postbox: strongSelf.postbox, resource: resource)
                                }
                                state.currentItem = AudioPlaylistItemState(item: item, player: player)
                                player?.play()
                                return AudioPlaylistState(playlistId: strongSelf.playlist.id, item: item)
                            } else {
                                state.currentItem = nil
                                return AudioPlaylistState(playlistId: strongSelf.playlist.id, item: nil)
                            }
                        }
                        strongSelf.currentStateValue.set(.single(updatedState))
                    }
                }))
        }
    }
}
