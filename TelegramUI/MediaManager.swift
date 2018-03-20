import Foundation
import SwiftSignalKit
import Postbox
import AVFoundation
import MobileCoreServices
import TelegramCore
import MediaPlayer

import TelegramUIPrivateModule

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

public enum MediaManagerPlayerType {
    case voice
    case music
}

private let sharedAudioSession: ManagedAudioSession = {
    let audioSession = ManagedAudioSession()
    let _ = (audioSession.headsetConnected() |> deliverOnMainQueue).start(next: { value in
        DeviceProximityManager.shared().setGloballyEnabled(!value)
    })
    return audioSession
}()

public final class MediaManager: NSObject {
    public static var globalAudioSession: ManagedAudioSession {
        return sharedAudioSession
    }
    
    private let queue = Queue.mainQueue()
    
    private let postbox: Postbox
    private let inForeground: Signal<Bool, NoError>
    
    public let audioSession: ManagedAudioSession
    let overlayMediaManager = OverlayMediaManager()
    let sharedVideoContextManager = SharedVideoContextManager()
    
    private var nextPlayerIndex: Int32 = 0
    
    private var voiceMediaPlayer: SharedMediaPlayer? {
        didSet {
            if self.voiceMediaPlayer !== oldValue {
                if let voiceMediaPlayer = self.voiceMediaPlayer {
                    self.voiceMediaPlayerStateValue.set(voiceMediaPlayer.playbackState |> map { state in
                        if let state = state, case let .item(item) = state {
                            return item
                        } else {
                            return nil
                        }
                    } |> deliverOnMainQueue)
                } else {
                    self.voiceMediaPlayerStateValue.set(.single(nil))
                }
            }
        }
    }
    private let voiceMediaPlayerStateValue = Promise<SharedMediaPlayerItemPlaybackState?>(nil)
    var voiceMediaPlayerState: Signal<SharedMediaPlayerItemPlaybackState?, NoError> {
        return self.voiceMediaPlayerStateValue.get()
    }
    
    private var musicMediaPlayer: SharedMediaPlayer? {
        didSet {
            if self.musicMediaPlayer !== oldValue {
                if let musicMediaPlayer = self.musicMediaPlayer {
                    self.musicMediaPlayerStateValue.set(musicMediaPlayer.playbackState |> map { state in
                        if let state = state, case let .item(item) = state {
                            return item
                        } else {
                            return nil
                        }
                    } |> deliverOnMainQueue)
                } else {
                    self.musicMediaPlayerStateValue.set(.single(nil))
                }
            }
        }
    }
    private let musicMediaPlayerStateValue = Promise<SharedMediaPlayerItemPlaybackState?>(nil)
    var musicMediaPlayerState: Signal<SharedMediaPlayerItemPlaybackState?, NoError> {
        return self.musicMediaPlayerStateValue.get()
    }
    
    private let globalMediaPlayerStateValue = Promise<(SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?>()
    var globalMediaPlayerState: Signal<(SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> {
        return self.globalMediaPlayerStateValue.get()
    }
    
    private let setPlaylistByTypeDisposables = DisposableDict<MediaManagerPlayerType>()
    
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
    private let globalControlsArtworkDisposable = MetaDisposable()
    private let globalControlsArtwork = Promise<SharedMediaPlaybackAlbumArt?>(nil)
    private let globalControlsStatusDisposable = MetaDisposable()
    private let globalAudioSessionForegroundDisposable = MetaDisposable()
    
    private var managedVideoContexts: [WrappedManagedMediaId: ActiveManagedVideoContext] = [:]
    
    let universalVideoManager = UniversalVideoContentManager()
    
    let galleryHiddenMediaManager = GalleryHiddenMediaManager()
    
    init(postbox: Postbox, inForeground: Signal<Bool, NoError>) {
        self.postbox = postbox
        self.inForeground = inForeground
        
        self.audioSession = sharedAudioSession
        
        super.init()
       
        let combinedPlayersSignal: Signal<(SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> = combineLatest(self.voiceMediaPlayerState, self.musicMediaPlayerState) |> map { voice, music -> (SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)? in
            if let voice = voice {
                return (voice, .voice)
            } else if let music = music {
                return (music, .music)
            } else {
                return nil
            }
        }
        self.globalMediaPlayerStateValue.set(combinedPlayersSignal |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs?.0 == rhs?.0 && lhs?.1 == rhs?.1
        }))
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget(self, action: #selector(playCommandEvent(_:)))
        commandCenter.pauseCommand.addTarget(self, action: #selector(pauseCommandEvent(_:)))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(previousTrackCommandEvent(_:)))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(nextTrackCommandEvent(_:)))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(togglePlayPauseCommandEvent(_:)))
        if #available(iOSApplicationExtension 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget(handler: { [weak self] event in
                if let strongSelf = self, let event = event as? MPChangePlaybackPositionCommandEvent {
                    strongSelf.playlistControl(.seek(event.positionTime))
                }
                return .success
            })
        }
        
        var previousState: SharedMediaPlayerItemPlaybackState?
        var previousDisplayData: SharedMediaPlaybackDisplayData?
        let globalControlsArtwork = self.globalControlsArtwork
        let globalControlsStatus = self.globalControlsStatus
        
        var baseNowPlayingInfo: [String: Any]?
        
        self.globalControlsDisposable.set((self.globalMediaPlayerState |> deliverOnMainQueue).start(next: { stateAndType in
            if let (state, type) = stateAndType, type == .music, let displayData = state.item.displayData {
                if previousDisplayData != displayData {
                    previousDisplayData = displayData
                
                    let commandCenter = MPRemoteCommandCenter.shared()
                    commandCenter.playCommand.isEnabled = true
                    commandCenter.pauseCommand.isEnabled = true
                    commandCenter.previousTrackCommand.isEnabled = true
                    commandCenter.nextTrackCommand.isEnabled = true
                    commandCenter.togglePlayPauseCommand.isEnabled = true
                    
                    var nowPlayingInfo: [String: Any] = [:]
                    
                    var artwork: SharedMediaPlaybackAlbumArt?
                    
                    switch displayData {
                        case let .music(title, performer, artworkValue):
                            artwork = artworkValue
                            
                            let titleText: String = title ?? "Unknown Track"
                            let subtitleText: String = performer ?? "Unknown Artist"
                            
                            nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                            nowPlayingInfo[MPMediaItemPropertyArtist] = subtitleText
                        case let .voice(author, _):
                            let titleText: String = author?.displayTitle ?? ""
                            
                            nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                        case let .instantVideo(author, _):
                            let titleText: String = author?.displayTitle ?? ""
                            
                            nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                    }
                    
                    globalControlsArtwork.set(.single(artwork))
                    
                    baseNowPlayingInfo = nowPlayingInfo
                    
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
                
                if previousState != state {
                    previousState = state
                    globalControlsStatus.set(.single(state.status))
                }
            } else {
                previousState = nil
                previousDisplayData = nil
                baseNowPlayingInfo = nil
                globalControlsStatus.set(.single(nil))
                globalControlsArtwork.set(.single(nil))
                
                let commandCenter = MPRemoteCommandCenter.shared()
                commandCenter.playCommand.isEnabled = false
                commandCenter.pauseCommand.isEnabled = false
                commandCenter.previousTrackCommand.isEnabled = false
                commandCenter.nextTrackCommand.isEnabled = false
                commandCenter.togglePlayPauseCommand.isEnabled = false
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
        }))
        
        self.globalControlsArtworkDisposable.set((self.globalControlsArtwork.get()
        |> distinctUntilChanged(isEqual: { $0 == $1 })
        |> mapToSignal { value -> Signal<UIImage?, NoError> in
            if let value = value {
                return Signal { subscriber in
                    let fetched = postbox.mediaBox.fetchedResource(value.fullSizeResource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start()
                    let data = postbox.mediaBox.resourceData(value.fullSizeResource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false)).start(next: { data in
                        if data.complete, let value = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            subscriber.putNext(UIImage(data: value))
                            subscriber.putCompletion()
                        }
                    })
                    return ActionDisposable {
                        fetched.dispose()
                        data.dispose()
                    }
                }
            } else {
                return .single(nil)
            }
        } |> deliverOnMainQueue).start(next: { image in
            if var nowPlayingInfo = baseNowPlayingInfo {
                if let image = image {
                    if #available(iOSApplicationExtension 10.0, *) {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { size in
                            return image
                        })
                    } else {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
                    }
                } else {
                    nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                baseNowPlayingInfo = nowPlayingInfo
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
        
       
        let shouldKeepAudioSession: Signal<Bool, NoError> = combineLatest(self.globalMediaPlayerState |> deliverOnMainQueue, inForeground |> deliverOnMainQueue)
        |> map { stateAndType, inForeground -> Bool in
            var isPlaying = false
            if let (state, _) = stateAndType {
                switch state.status.status {
                    case .playing:
                        isPlaying = true
                    case let .buffering(_, whilePlaying):
                        isPlaying = whilePlaying
                    default:
                        break
                }
            }
            if !inForeground {
                if !isPlaying {
                    return true
                }
            }
            return false
        }
        |> distinctUntilChanged
        |> mapToSignal { value -> Signal<Bool, NoError> in
            if value {
                return .single(true) |> delay(0.8, queue: Queue.mainQueue())
            } else {
                return .single(false)
            }
        }
        
        self.globalAudioSessionForegroundDisposable.set((shouldKeepAudioSession |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.audioSession.dropAll()
            }
        }))
    }
    
    deinit {
        self.playlistPlayerStateValueDisposable.dispose()
        self.globalControlsDisposable.dispose()
        self.globalControlsArtworkDisposable.dispose()
        self.globalControlsStatusDisposable.dispose()
        self.setPlaylistByTypeDisposables.dispose()
        self.globalAudioSessionForegroundDisposable.dispose()
    }
    
    func videoContext(postbox: Postbox, id: ManagedMediaId, resource: MediaResource, preferSoftwareDecoding: Bool, backgroundThread: Bool, priority: Int32, initiatePlayback: Bool, activate: @escaping (MediaPlayerNode) -> Void, deactivate: @escaping () -> Signal<Void, NoError>) -> (MediaPlayer, Disposable) {
        assert(Queue.mainQueue().isCurrent())
        
        let wrappedId = WrappedManagedMediaId(id: id)
        let activeContext: ActiveManagedVideoContext
        var startPlayback = false
        if let currentActiveContext = self.managedVideoContexts[wrappedId] {
            activeContext = currentActiveContext
        } else {
            let mediaPlayer = MediaPlayer(audioSessionManager: self.audioSession, postbox: postbox, resource: resource, streamable: false, video: true, preferSoftwareDecoding: preferSoftwareDecoding, enableSound: false, fetchAutomatically: true)
            mediaPlayer.actionAtEnd = .loop(nil)
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
    
    func audioRecorder(beginWithTone: Bool, applicationBindings: TelegramApplicationBindings, beganWithTone: @escaping (Bool) -> Void) -> Signal<ManagedAudioRecorder?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let audioRecorder = ManagedAudioRecorder(mediaManager: self, pushIdleTimerExtension: { [weak applicationBindings] in
                    return applicationBindings?.pushIdleTimerExtension() ?? EmptyDisposable
                }, beginWithTone: beginWithTone, beganWithTone: beganWithTone)
                subscriber.putNext(audioRecorder)
                
                disposable.set(ActionDisposable {
                })
            }
            
            return disposable
        }
    }
    
    func setPlaylist(_ playlist: SharedMediaPlaylist?, type: MediaManagerPlayerType) {
        assert(Queue.mainQueue().isCurrent())
        self.setPlaylistByTypeDisposables.set((self.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.musicPlaybackSettings])
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                let settings = (view.values[ApplicationSpecificPreferencesKeys.musicPlaybackSettings] as? MusicPlaybackSettings) ?? MusicPlaybackSettings.defaultSettings
                let nextPlayerIndex = strongSelf.nextPlayerIndex
                strongSelf.nextPlayerIndex += 1
                switch type {
                    case .voice:
                        strongSelf.musicMediaPlayer?.control(.playback(.pause))
                        strongSelf.voiceMediaPlayer?.stop()
                        if let playlist = playlist {
                            let voiceMediaPlayer = SharedMediaPlayer(mediaManager: strongSelf, inForeground: strongSelf.inForeground, postbox: strongSelf.postbox, audioSession: strongSelf.audioSession, overlayMediaManager: strongSelf.overlayMediaManager, playlist: playlist, initialOrder: .reversed, initialLooping: .none, playerIndex: nextPlayerIndex, controlPlaybackWithProximity: true)
                            strongSelf.voiceMediaPlayer = voiceMediaPlayer
                            voiceMediaPlayer.playedToEnd = { [weak voiceMediaPlayer] in
                                if let strongSelf = self, let voiceMediaPlayer = voiceMediaPlayer, voiceMediaPlayer === strongSelf.voiceMediaPlayer {
                                    strongSelf.voiceMediaPlayer = nil
                                }
                            }
                            voiceMediaPlayer.control(.playback(.play))
                        } else {
                            strongSelf.voiceMediaPlayer = nil
                        }
                    case .music:
                        strongSelf.musicMediaPlayer?.stop()
                        strongSelf.voiceMediaPlayer?.control(.playback(.pause))
                        if let playlist = playlist {
                            strongSelf.musicMediaPlayer = SharedMediaPlayer(mediaManager: strongSelf, inForeground: strongSelf.inForeground, postbox: strongSelf.postbox, audioSession: strongSelf.audioSession, overlayMediaManager: strongSelf.overlayMediaManager, playlist: playlist, initialOrder: settings.order, initialLooping: settings.looping, playerIndex: nextPlayerIndex, controlPlaybackWithProximity: false)
                            strongSelf.musicMediaPlayer?.control(.playback(.play))
                        } else {
                            strongSelf.musicMediaPlayer = nil
                        }
                }
            }
        }), forKey: type)
    }
    
    func playlistControl(_ control: SharedMediaPlayerControlAction, type: MediaManagerPlayerType? = nil) {
        assert(Queue.mainQueue().isCurrent())
        let selectedType: MediaManagerPlayerType
        if let type = type {
            selectedType = type
        } else if self.voiceMediaPlayer != nil {
            selectedType = .voice
        } else {
            selectedType = .music
        }
        switch selectedType {
            case .voice:
                self.voiceMediaPlayer?.control(control)
            case .music:
                if self.voiceMediaPlayer != nil {
                    switch control {
                        case .playback(.play), .playback(.togglePlayPause):
                            self.setPlaylist(nil, type: .voice)
                        default:
                            break
                    }
                }
                self.musicMediaPlayer?.control(control)
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
    
    func filteredPlaylistState(playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<SharedMediaPlayerItemPlaybackState?, NoError> {
        let signal: Signal<SharedMediaPlayerItemPlaybackState?, NoError>
        switch type {
            case .voice:
                signal = self.voiceMediaPlayerState
            case .music:
                signal = self.musicMediaPlayerState
        }
        return signal |> map { state in
            if let state = state {
                if state.playlistId.isEqual(to: playlistId) && state.item.id.isEqual(to: itemId) {
                    return state
                }
            }
            return nil
        } |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
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
        self.playlistControl(.playback(.play))
    }
    
    @objc func pauseCommandEvent(_ command: AnyObject) {
        self.playlistControl(.playback(.pause))
    }
    
    @objc func previousTrackCommandEvent(_ command: AnyObject) {
        self.playlistControl(.previous)
    }
    
    @objc func nextTrackCommandEvent(_ command: AnyObject) {
        self.playlistControl(.next)
    }
    
    @objc func togglePlayPauseCommandEvent(_ command: AnyObject) {
        self.playlistControl(.playback(.togglePlayPause))
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
