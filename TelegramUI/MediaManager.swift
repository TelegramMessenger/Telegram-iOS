import Foundation
import SwiftSignalKit
import Postbox
import AVFoundation
import MobileCoreServices
import TelegramCore
import MediaPlayer

private struct WrappedAudioPlaylistItemId: Hashable, Equatable {
    let playlistId: AudioPlaylistId
    let itemId: AudioPlaylistItemId
    
    static func ==(lhs: WrappedAudioPlaylistItemId, rhs: WrappedAudioPlaylistItemId) -> Bool {
        return lhs.itemId.isEqual(to: rhs.itemId) && lhs.playlistId.isEqual(to: rhs.playlistId)
    }
    
    var hashValue: Int {
        return self.itemId.hashValue
    }
}

struct WrappedManagedMediaId: Hashable {
    let id: ManagedMediaId
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    static func ==(lhs: WrappedManagedMediaId, rhs: WrappedManagedMediaId) -> Bool {
        return lhs.id.isEqual(to: rhs.id)
    }
}

final class ManagedVideoContext {
    let mediaPlayer: MediaPlayer
    let playerNode: MediaPlayerNode?
    
    init(mediaPlayer: MediaPlayer, playerNode: MediaPlayerNode?) {
        self.mediaPlayer = mediaPlayer
        self.playerNode = playerNode
    }
}

final class ManagedVideoContextSubscriber {
    let id: Int32
    let priority: Int32
    var active = false
    let activate: (MediaPlayerNode) -> Void
    let deactivate: () -> Signal<Void, NoError>
    var deactivatingDisposable: Disposable? = nil
    
    init(id: Int32, priority: Int32, activate: @escaping (MediaPlayerNode) -> Void, deactivate: @escaping () -> Signal<Void, NoError>) {
        self.id = id
        self.priority = priority
        self.activate = activate
        self.deactivate = deactivate
    }
}

private final class ActiveManagedVideoContext {
    let mediaPlayer: MediaPlayer
    let playerNode: MediaPlayerNode
    private var becameEmpty: () -> Void
    private var nextSubscriberId: Int32 = 0
    var contextSubscribers: [ManagedVideoContextSubscriber] = []
    
    init(mediaPlayer: MediaPlayer, playerNode: MediaPlayerNode, becameEmpty: @escaping () -> Void) {
        self.mediaPlayer = mediaPlayer
        self.playerNode = playerNode
        self.becameEmpty = becameEmpty
    }
    
    func addContextSubscriber(priority: Int32, activate: @escaping (MediaPlayerNode) -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> Disposable {
        let id = self.nextSubscriberId
        self.nextSubscriberId += 1
        self.contextSubscribers.append(ManagedVideoContextSubscriber(id: id, priority: priority, activate: activate, deactivate: deactivate))
        self.contextSubscribers.sort(by: { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            } else {
                return lhs.id < rhs.id
            }
        })
        self.updateSubscribers()
        
        return ActionDisposable { [weak self] in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.removeDeactivatedSubscriber(id: id)
                }
            }
        }
    }
    
    private func removeDeactivatedSubscriber(id: Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        for i in 0 ..< self.contextSubscribers.count {
            if self.contextSubscribers[i].id == id {
                self.contextSubscribers[i].deactivatingDisposable?.dispose()
                self.contextSubscribers.remove(at: i)
                self.updateSubscribers()
                break
            }
        }
    }
    
    private func updateSubscribers() {
        assert(Queue.mainQueue().isCurrent())
        
        if !self.contextSubscribers.isEmpty {
            var activeIndex: Int?
            var deactivating = false
            var index = 0
            for subscriber in self.contextSubscribers {
                if subscriber.active {
                    activeIndex = index
                    break
                }
                else if subscriber.deactivatingDisposable != nil {
                    deactivating = false
                }
                index += 1
            }
            if !deactivating {
                if let activeIndex = activeIndex, activeIndex != self.contextSubscribers.count - 1 {
                    self.contextSubscribers[activeIndex].active = false
                    let id = self.contextSubscribers[activeIndex].id
                    self.contextSubscribers[activeIndex].deactivatingDisposable = (self.contextSubscribers[activeIndex].deactivate() |> deliverOn(Queue.mainQueue())).start(completed: { [weak self] in
                        if let strongSelf = self {
                            var index = 0
                            for currentRecord in strongSelf.contextSubscribers {
                                if currentRecord.id == id {
                                    currentRecord.deactivatingDisposable = nil
                                    break
                                }
                                index += 1
                            }
                            strongSelf.updateSubscribers()
                        }
                    })
                } else if activeIndex == nil {
                    let lastIndex = self.contextSubscribers.count - 1
                    self.contextSubscribers[lastIndex].active = true
                    //self.applyType(self.contextSubscribers[lastIndex].audioSessionType)
                    
                    self.contextSubscribers[lastIndex].activate(self.playerNode)
                }
            }
        } else {
            self.becameEmpty()
        }
    }
}

enum SharedMediaPlayerGroup: Int {
    case music = 0
    case voiceAndInstantVideo = 1
}

public final class MediaManager: NSObject {
    private let queue = Queue.mainQueue()
    
    public let audioSession: ManagedAudioSession
    let overlayMediaManager = OverlayMediaManager()
    let sharedVideoContextManager = SharedVideoContextManager()
    
    private let playlistPlayer = Atomic<ManagedAudioPlaylistPlayer?>(value: nil)
    private let playlistPlayerStateAndStatusValue = Promise<AudioPlaylistStateAndStatus?>(nil)
    var playlistPlayerStateAndStatus: Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.playlistPlayerStateAndStatusValue.get()
    }
    private let playlistPlayerStateValueDisposable = MetaDisposable()
    
    private let sharedPlayerByGroup: [SharedMediaPlayerGroup: SharedMediaPlayer] = [:]
    private var currentOverlayVideoNode: OverlayMediaItemNode?
    
    private let globalControlsStatus = Promise<MediaPlayerStatus?>(nil)
    
    private let globalControlsDisposable = MetaDisposable()
    private let globalControlsStatusDisposable = MetaDisposable()
    
    private var managedVideoContexts: [WrappedManagedMediaId: ActiveManagedVideoContext] = [:]
    
    let universalVideoManager = UniversalVideoContentManager()
    
    override init() {
        self.audioSession = ManagedAudioSession()
        
        super.init()
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget(self, action: #selector(playCommandEvent(_:)))
        commandCenter.pauseCommand.addTarget(self, action: #selector(pauseCommandEvent(_:)))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(previousTrackCommandEvent(_:)))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(nextTrackCommandEvent(_:)))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(togglePlayPauseCommandEvent(_:)))
        if #available(iOSApplicationExtension 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget(handler: { [weak self] event in
                if let strongSelf = self, let event = event as? MPChangePlaybackPositionCommandEvent {
                    strongSelf.playlistPlayerControl(.playback(.seek(event.positionTime)))
                }
                return .success
            })
        }
        
        var previousStateAndStatus: AudioPlaylistStateAndStatus?
        let globalControlsStatus = self.globalControlsStatus
        
        var baseNowPlayingInfo: [String: Any]?
        
        self.globalControlsDisposable.set((self.playlistPlayerStateAndStatusValue.get() |> deliverOnMainQueue).start(next: { next in
            if let next = next, let item = next.state.item, let info = item.info {
                let commandCenter = MPRemoteCommandCenter.shared()
                commandCenter.playCommand.isEnabled = true
                commandCenter.pauseCommand.isEnabled = true
                commandCenter.previousTrackCommand.isEnabled = true
                commandCenter.nextTrackCommand.isEnabled = true
                commandCenter.togglePlayPauseCommand.isEnabled = true
                
                var nowPlayingInfo: [String: Any] = [:]
                
                switch info.labelInfo {
                    case let .music(title, performer):
                        let titleText: String = title ?? "Unknown Track"
                        let subtitleText: String = performer ?? "Unknown Artist"
                        
                        nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                        nowPlayingInfo[MPMediaItemPropertyArtist] = subtitleText
                    case .voice:
                        let titleText: String = "Voice Message"
                        
                        nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                    case .video:
                        let titleText: String = "Video Message"
                        
                        nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                }
                
                baseNowPlayingInfo = nowPlayingInfo
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                
                if previousStateAndStatus != next {
                    previousStateAndStatus = next
                    if let status = next.status {
                        globalControlsStatus.set(status |> map { Optional($0) })
                    } else {
                        globalControlsStatus.set(.single(nil))
                    }
                }
            } else {
                previousStateAndStatus = nil
                baseNowPlayingInfo = nil
                globalControlsStatus.set(.single(nil))
                
                let commandCenter = MPRemoteCommandCenter.shared()
                commandCenter.playCommand.isEnabled = false
                commandCenter.pauseCommand.isEnabled = false
                commandCenter.previousTrackCommand.isEnabled = false
                commandCenter.nextTrackCommand.isEnabled = false
                commandCenter.togglePlayPauseCommand.isEnabled = false
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
        }))
        
        self.globalControlsStatusDisposable.set((self.globalControlsStatus.get() |> deliverOnMainQueue).start(next: { next in
            if let next = next {
                if var nowPlayingInfo = baseNowPlayingInfo {
                    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = next.duration as NSNumber
                    switch next.status {
                        case .playing:
                            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0 as NSNumber
                        case .buffering, .paused:
                            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0 as NSNumber
                    }
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = next.timestamp as NSNumber
                    
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }/* else {
                if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                    nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyPlaybackDuration)
                    nowPlayingInfo.removeValue(forKey: MPNowPlayingInfoPropertyPlaybackRate)
                    nowPlayingInfo.removeValue(forKey: MPNowPlayingInfoPropertyElapsedPlaybackTime)
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }*/
        }))
    }
    
    deinit {
        self.playlistPlayerStateValueDisposable.dispose()
        self.globalControlsDisposable.dispose()
        self.globalControlsStatusDisposable.dispose()
    }
    
    func videoContext(postbox: Postbox, id: ManagedMediaId, resource: MediaResource, preferSoftwareDecoding: Bool, backgroundThread: Bool, priority: Int32, initiatePlayback: Bool, activate: @escaping (MediaPlayerNode) -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> (MediaPlayer, Disposable) {
        assert(Queue.mainQueue().isCurrent())
        
        let wrappedId = WrappedManagedMediaId(id: id)
        let activeContext: ActiveManagedVideoContext
        var startPlayback = false
        if let currentActiveContext = self.managedVideoContexts[wrappedId] {
            activeContext = currentActiveContext
        } else {
            let mediaPlayer = MediaPlayer(audioSessionManager: self.audioSession, postbox: postbox, resource: resource, streamable: false, video: true, preferSoftwareDecoding: preferSoftwareDecoding, enableSound: false)
            mediaPlayer.actionAtEnd = .loop
            let playerNode = MediaPlayerNode(backgroundThread: backgroundThread)
            mediaPlayer.attachPlayerNode(playerNode)
            
            activeContext = ActiveManagedVideoContext(mediaPlayer: mediaPlayer, playerNode: playerNode, becameEmpty: { [weak self] in
                if let strongSelf = self {
                    strongSelf.managedVideoContexts[wrappedId]?.playerNode.removeFromSupernode()
                    strongSelf.managedVideoContexts.removeValue(forKey: wrappedId)
                }
            })
            self.managedVideoContexts[wrappedId] = activeContext
            if initiatePlayback {
                startPlayback = true
            }
        }
        
        if startPlayback {
            activeContext.mediaPlayer.play()
        }
        
        return (activeContext.mediaPlayer, activeContext.addContextSubscriber(priority: priority, activate: activate, deactivate: deactivate))
    }
    
    func audioRecorder() -> Signal<ManagedAudioRecorder?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let audioRecorder = ManagedAudioRecorder(mediaManager: self)
                subscriber.putNext(audioRecorder)
                
                disposable.set(ActionDisposable {
                })
            }
            
            return disposable
        }
    }
    
    func setPlaylistPlayer(_ player: ManagedAudioPlaylistPlayer?) {
        var disposePlayer: ManagedAudioPlaylistPlayer?
        var updatedPlayer = false
        let _ = self.playlistPlayer.modify { currentPlayer in
            if currentPlayer !== player {
                disposePlayer = currentPlayer
                updatedPlayer = true
                return player
            } else {
                return currentPlayer
            }
        }
        
        if let disposePlayer = disposePlayer {
            withExtendedLifetime(disposePlayer, {
                
            })
        }
        
        if updatedPlayer {
            if let player = player {
                self.playlistPlayerStateAndStatusValue.set(player.stateAndStatus)
                self.playlistPlayerStateValueDisposable.set(player.stateAndStatus.start(next: { [weak self] next in
                    if let next = next {
                        if next.state.item == nil {
                            Queue.mainQueue().async {
                                self?.setPlaylistPlayer(nil)
                            }
                        }
                    }
                }))
            } else {
                self.playlistPlayerStateAndStatusValue.set(.single(nil))
            }
        }
    }
    
    func playlistPlayerControl(_ control: AudioPlaylistControl) {
        var player: ManagedAudioPlaylistPlayer?
        self.playlistPlayer.with { currentPlayer -> Void in
            player = currentPlayer
        }
        
        if let player = player {
            player.control(control)
        }
    }
    
    func filteredPlaylistPlayerStateAndStatus(playlistId: AudioPlaylistId, itemId: AudioPlaylistItemId) -> Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.playlistPlayerStateAndStatusValue.get()
            |> map { state -> AudioPlaylistStateAndStatus? in
                if let state = state, let item = state.state.item, state.state.playlistId.isEqual(to: playlistId), item.id.isEqual(to: itemId) {
                    return state
                }
                return nil
            }
    }
    
    @objc func playCommandEvent(_ command: AnyObject) {
        self.playlistPlayerControl(.playback(.play))
    }
    
    @objc func pauseCommandEvent(_ command: AnyObject) {
        self.playlistPlayerControl(.playback(.pause))
    }
    
    @objc func previousTrackCommandEvent(_ command: AnyObject) {
        self.playlistPlayerControl(.navigation(.previous))
    }
    
    @objc func nextTrackCommandEvent(_ command: AnyObject) {
        self.playlistPlayerControl(.navigation(.next))
    }
    
    @objc func togglePlayPauseCommandEvent(_ command: AnyObject) {
        self.playlistPlayerControl(.playback(.togglePlayPause))
    }
    
    func setOverlayVideoNode(_ node: OverlayMediaItemNode?) {
        if let currentOverlayVideoNode = self.currentOverlayVideoNode {
            self.overlayMediaManager.controller?.removeNode(currentOverlayVideoNode, customTransition: true)
            self.currentOverlayVideoNode = nil
        }
        
        if let node = node {
            self.currentOverlayVideoNode = node
            self.overlayMediaManager.controller?.addNode(node, customTransition: true)
        }
    }
}
