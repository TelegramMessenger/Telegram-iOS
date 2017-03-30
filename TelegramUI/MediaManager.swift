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

private final class ManagedAudioPlaylistPlayerStatusesContext {
    private var subscribers: [WrappedAudioPlaylistItemId: Bag<(AudioPlaylistState?) -> Void>] = [:]
    
    func addSubscriber(id: WrappedAudioPlaylistItemId, _ f: @escaping (AudioPlaylistState?) -> Void) -> Int {
        let bag: Bag<(AudioPlaylistState?) -> Void>
        if let currentBag = self.subscribers[id] {
            bag = currentBag
        } else {
            bag = Bag()
            self.subscribers[id] = bag
        }
        return bag.add(f)
    }
    
    func removeSubscriber(id: WrappedAudioPlaylistItemId, index: Int) {
        if let bag = subscribers[id] {
            bag.remove(index)
            if bag.isEmpty {
                self.subscribers.removeValue(forKey: id)
            }
        }
    }
    
    func subscribersForId(_ id: WrappedAudioPlaylistItemId) -> [(AudioPlaylistState) -> Void]? {
        return self.subscribers[id]?.copyItems()
    }
}

private struct WrappedManagedMediaId: Hashable {
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
    let playerNode: MediaPlayerNode
    
    init(mediaPlayer: MediaPlayer, playerNode: MediaPlayerNode) {
        self.mediaPlayer = mediaPlayer
        self.playerNode = playerNode
    }
}

private final class ActiveManagedVideoContext {
    let context: ManagedVideoContext
    let contextSubscribers = Bag<(ManagedVideoContext?) -> Void>()
    
    init(context: ManagedVideoContext) {
        self.context = context
    }
}

final class MediaManager: NSObject {
    private let queue = Queue.mainQueue()
    
    let audioSession = ManagedAudioSession()
    
    private let playlistPlayer = Atomic<ManagedAudioPlaylistPlayer?>(value: nil)
    private let playlistPlayerStateAndStatusValue = Promise<AudioPlaylistStateAndStatus?>(nil)
    var playlistPlayerStateAndStatus: Signal<AudioPlaylistStateAndStatus?, NoError> {
        return self.playlistPlayerStateAndStatusValue.get()
    }
    private let playlistPlayerStateValueDisposable = MetaDisposable()
    private let playlistPlayerStatusesContext = Atomic(value: ManagedAudioPlaylistPlayerStatusesContext())
    
    private let globalControlsStatus = Promise<MediaPlayerStatus?>(nil)
    
    private let globalControlsDisposable = MetaDisposable()
    private let globalControlsStatusDisposable = MetaDisposable()
    
    private var managedVideoContexts: [WrappedManagedMediaId: ActiveManagedVideoContext] = [:]
    
    override init() {
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
    
    func videoContext(account: Account, id: ManagedMediaId, resource: MediaResource) -> Signal<ManagedVideoContext?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let wrappedId = WrappedManagedMediaId(id: id)
                let activeContext: ActiveManagedVideoContext
                if let currentActiveContext = self.managedVideoContexts[wrappedId] {
                    activeContext = currentActiveContext
                } else {
                    let mediaPlayer = MediaPlayer(audioSessionManager: self.audioSession, postbox: account.postbox, resource: resource, streamable: false)
                    let playerNode = MediaPlayerNode()
                    mediaPlayer.attachPlayerNode(playerNode)
                    activeContext = ActiveManagedVideoContext(context: ManagedVideoContext(mediaPlayer: mediaPlayer, playerNode: playerNode))
                    self.managedVideoContexts[wrappedId] = activeContext
                }
                
                let index = activeContext.contextSubscribers.add({ context in
                    subscriber.putNext(context)
                })
                
                for (subscriberIndex, subscriberSink) in activeContext.contextSubscribers.copyItemsWithIndices() {
                    if subscriberIndex == index {
                        subscriberSink(activeContext.context)
                    } else {
                        subscriberSink(nil)
                    }
                }
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        if let activeContext = self.managedVideoContexts[wrappedId] {
                            activeContext.contextSubscribers.remove(index)
                            
                            if activeContext.contextSubscribers.isEmpty {
                                self.managedVideoContexts.removeValue(forKey: wrappedId)
                            } else {
                                let lastSubscriber = activeContext.contextSubscribers.copyItemsWithIndices().last!.1
                                lastSubscriber(activeContext.context)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
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
    
    private func updatePlaylistPlayerStateValue() {
        
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
        /*return Signal { subscriber in
            let id = WrappedAudioPlaylistItemId(playlistId: playlistId, itemId: itemId)
            let index = self.playlistPlayerStatusesContext.with { context -> Int in
                context.addSubscriber(id: id, { state in
                    subscriber.putNext(state)
                })
            }
            
            
            
            return ActionDisposable { [weak self] in
                if let strongSelf = self {
                    strongSelf.playlistPlayerStatusesContext.with { context -> Void in
                        context.removeSubscriber(id: id, index: index)
                    }
                }
            }
        }*/
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
}
