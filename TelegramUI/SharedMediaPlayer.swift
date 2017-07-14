import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

enum SharedMediaPlayerControlAction {
    case next
    case previous
    case play
    case pause
    case togglePlayPause
}

enum SharedMediaPlaylistControlAction {
    case next
    case previous
}

enum SharedMediaPlaybackDataType {
    case music
    case voice
    case instantVideo
}

enum SharedMediaPlaybackDataSource: Equatable {
    case telegramFile(TelegramMediaFile)
    
    static func ==(lhs: SharedMediaPlaybackDataSource, rhs: SharedMediaPlaybackDataSource) -> Bool {
        switch lhs {
            case let .telegramFile(lhsFile):
                if case let .telegramFile(rhsFile) = rhs {
                    return lhsFile.isEqual(rhsFile)
                } else {
                    return false
                }
        }
    }
}

struct SharedMediaPlaybackData: Equatable {
    let type: SharedMediaPlaybackDataType
    let source: SharedMediaPlaybackDataSource
    
    static func ==(lhs: SharedMediaPlaybackData, rhs: SharedMediaPlaybackData) -> Bool {
        return lhs.type == rhs.type && lhs.source == rhs.source
    }
}

enum SharedMediaPlaybackDisplayData: Equatable {
    case music(title: String?, performer: String?)
    case voice(author: Peer?, peer: Peer?)
    case instantVideo(author: Peer?, peer: Peer?)
    
    static func ==(lhs: SharedMediaPlaybackDisplayData, rhs: SharedMediaPlaybackDisplayData) -> Bool {
        switch lhs {
            case let .music(lhsTitle, lhsPerformer):
                if case let .music(rhsTitle, rhsPerformer) = rhs, lhsTitle == rhsTitle, lhsPerformer == rhsPerformer {
                    return true
                } else {
                    return false
                }
            case let .voice(lhsAuthor, lhsPeer):
                if case let .voice(rhsAuthor, rhsPeer) = rhs, arePeersEqual(lhsAuthor, rhsAuthor), arePeersEqual(lhsPeer, rhsPeer) {
                    return true
                } else {
                    return false
                }
            case let .instantVideo(lhsAuthor, lhsPeer):
                if case let .instantVideo(rhsAuthor, rhsPeer) = rhs, arePeersEqual(lhsAuthor, rhsAuthor), arePeersEqual(lhsPeer, rhsPeer) {
                    return true
                } else {
                    return false
                }
        }
    }
}

protocol SharedMediaPlaylistItem {
    var stableId: AnyHashable { get }
    var playbackData: SharedMediaPlaybackData? { get }
    var displayData: SharedMediaPlaybackDisplayData? { get }
}

final class SharedMediaPlaylistState {
    let loading: Bool
    let item: SharedMediaPlaylistItem?
    
    init(loading: Bool, item: SharedMediaPlaylistItem?) {
        self.loading = loading
        self.item = item
    }
}

protocol SharedMediaPlaylist {
    var state: Signal<SharedMediaPlaylistState, NoError> { get }
        
    func control(_ action: SharedMediaPlaylistControlAction)
}

private enum SharedMediaPlaybackItem {
    case audio(MediaPlayer)
    case instantVideo(InstantVideoNode)
    
    func play() {
        switch self {
            case let .audio(player):
                player.play()
            case let .instantVideo(node):
                node.play()
        }
    }
    
    func pause() {
        switch self {
            case let .audio(player):
                player.pause()
            case let .instantVideo(node):
                node.pause()
        }
    }
    
    func togglePlayPause() {
        switch self {
            case let .audio(player):
                player.togglePlayPause()
            case let .instantVideo(node):
                node.togglePlayPause()
        }
    }
    
    func seek(_ timestamp: Double) {
        switch self {
            case let .audio(player):
                player.seek(timestamp: timestamp)
            case let .instantVideo(node):
                node.seek(timestamp)
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        switch self {
            case .audio:
                break
            case let .instantVideo(node):
                node.setSoundEnabled(value)
        }
    }
}

final class SharedMediaPlayer {
    private let account: Account
    private let manager: MediaManager
    private let playlist: SharedMediaPlaylist
    
    private var stateDisposable: Disposable?
    
    private var stateValue: SharedMediaPlaylistState?
    private var playbackItem: SharedMediaPlaybackItem?
    
    init(account: Account, manager: MediaManager, playlist: SharedMediaPlaylist) {
        self.account = account
        self.manager = manager
        self.playlist = playlist
        
        self.stateDisposable = (playlist.state |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                if state.item?.playbackData != strongSelf.stateValue?.item?.playbackData {
                    strongSelf.playbackItem?.pause()
                    if let playbackItem = strongSelf.playbackItem {
                        switch playbackItem {
                            case .audio:
                                break
                            case let .instantVideo(node):
                                strongSelf.manager.overlayMediaManager.controller?.removeNode(node)
                        }
                    }
                    strongSelf.playbackItem = nil
                    if let item = state.item, let playbackData = item.playbackData {
                        switch playbackData.type {
                            case .voice, .music:
                                switch playbackData.source {
                                    case let .telegramFile(file):
                                        strongSelf.playbackItem = .audio(MediaPlayer(audioSessionManager: strongSelf.manager.audioSession, postbox: strongSelf.account.postbox, resource: file.resource, streamable: true, video: false, preferSoftwareDecoding: false, enableSound: true))
                                }
                            case .instantVideo:
                                let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                                switch playbackData.source {
                                    case let .telegramFile(file):
                                        strongSelf.playbackItem = .instantVideo(InstantVideoNode(theme: presentationData.theme, manager: strongSelf.manager, account: strongSelf.account, source: .messageMedia(stableId: item.stableId, file: file), priority: 0, withSound: true))
                                }
                        }
                    }
                    if let playbackItem = strongSelf.playbackItem {
                        switch playbackItem {
                            case .audio:
                                break
                            case let .instantVideo(node):
                                strongSelf.manager.overlayMediaManager.controller?.addNode(node)
                        }
                    }
                }
                strongSelf.stateValue = state
            }
        })
    }
    
    deinit {
        self.stateDisposable?.dispose()
    }
    
    func control(_ action: SharedMediaPlayerControlAction) {
        switch action {
            case .next:
                self.playlist.control(.next)
            case .previous:
                self.playlist.control(.previous)
            case .play, .pause, .togglePlayPause:
                break
        }
    }
}
