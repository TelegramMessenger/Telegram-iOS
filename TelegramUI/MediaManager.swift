import Foundation
import SwiftSignalKit
import Postbox
import AVFoundation
import MobileCoreServices
import TelegramCore
import MediaPlayer

import TelegramUIPrivateModule

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

private struct GlobalControlOptions: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32 = 0) {
        self.rawValue = rawValue
    }
    
    static let play = GlobalControlOptions(rawValue: 1 << 0)
    static let pause = GlobalControlOptions(rawValue: 1 << 1)
    static let previous = GlobalControlOptions(rawValue: 1 << 2)
    static let next = GlobalControlOptions(rawValue: 1 << 3)
    static let playPause = GlobalControlOptions(rawValue: 1 << 4)
    static let seek = GlobalControlOptions(rawValue: 1 << 5)
}

public final class MediaManager: NSObject {
    public static var globalAudioSession: ManagedAudioSession {
        return sharedAudioSession
    }
    
    private let isCurrentPromise = ValuePromise<Bool>(false)
    var isCurrent: Bool = false {
        didSet {
            if self.isCurrent != oldValue {
                self.isCurrentPromise.set(self.isCurrent)
            }
        }
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
    
    private let sharedPlayerByGroup: [SharedMediaPlayerGroup: SharedMediaPlayer] = [:]
    private var currentOverlayVideoNode: OverlayMediaItemNode?
    
    private let globalControlsStatus = Promise<MediaPlayerStatus?>(nil)
    
    private let globalControlsDisposable = MetaDisposable()
    private let globalControlsArtworkDisposable = MetaDisposable()
    private let globalControlsArtwork = Promise<SharedMediaPlaybackAlbumArt?>(nil)
    private let globalControlsStatusDisposable = MetaDisposable()
    private let globalAudioSessionForegroundDisposable = MetaDisposable()
    
    let universalVideoManager = UniversalVideoContentManager()
    
    let galleryHiddenMediaManager = GalleryHiddenMediaManager()
    
    init(postbox: Postbox, inForeground: Signal<Bool, NoError>) {
        self.postbox = postbox
        self.inForeground = inForeground
        
        self.audioSession = sharedAudioSession
        
        super.init()
       
        let combinedPlayersSignal: Signal<(SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> = combineLatest(queue: Queue.mainQueue(), self.voiceMediaPlayerState, self.musicMediaPlayerState)
        |> map { voice, music -> (SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)? in
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
        
        /*let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = false*/
        
        /*commandCenter.pauseCommand.isEnabled = false
        commandCenter.pauseCommand.addTarget(self, action: #selector(pauseCommandEvent(_:)))
        
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(previousTrackCommandEvent(_:)))
        
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(nextTrackCommandEvent(_:)))
        
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(togglePlayPauseCommandEvent(_:)))*/
        
        var baseNowPlayingInfo: [String: Any]?
        
        /*if #available(iOSApplicationExtension 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = false
            commandCenter.changePlaybackPositionCommand.addTarget(handler: { [weak self] event in
                if let strongSelf = self, let event = event as? MPChangePlaybackPositionCommandEvent {
                    strongSelf.playlistControl(.seek(event.positionTime))
                }
                if baseNowPlayingInfo != nil {
                    return .success
                } else {
                    return .noActionableNowPlayingItem
                }
            })
        }*/
        
        var previousState: SharedMediaPlayerItemPlaybackState?
        var previousDisplayData: SharedMediaPlaybackDisplayData?
        let globalControlsArtwork = self.globalControlsArtwork
        let globalControlsStatus = self.globalControlsStatus
        
        var currentGlobalControlsOptions = GlobalControlOptions()
        
        self.globalControlsDisposable.set((self.globalMediaPlayerState
        |> deliverOnMainQueue).start(next: { stateAndType in
            var updatedGlobalControlOptions = GlobalControlOptions()
            if let (state, type) = stateAndType {
                if type == .music {
                    updatedGlobalControlOptions.insert(.previous)
                    updatedGlobalControlOptions.insert(.next)
                    updatedGlobalControlOptions.insert(.seek)
                    switch state.status.status {
                        case .playing, .buffering(_, true):
                            updatedGlobalControlOptions.insert(.pause)
                        default:
                            updatedGlobalControlOptions.insert(.play)
                    }
                }
            }
            
            if let (state, type) = stateAndType, type == .music, let displayData = state.item.displayData {
                if previousDisplayData != displayData {
                    previousDisplayData = displayData
                    
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
                        case let .instantVideo(author, _, _):
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
                globalControlsStatus.set(.single(nil))
                globalControlsArtwork.set(.single(nil))
                
                if baseNowPlayingInfo != nil {
                    baseNowPlayingInfo = nil
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                }
            }
            
            if currentGlobalControlsOptions != updatedGlobalControlOptions {
                let commandCenter = MPRemoteCommandCenter.shared()
                
                var optionsAndCommands: [(GlobalControlOptions, MPRemoteCommand, Selector)] = [
                    (.play, commandCenter.playCommand, #selector(self.playCommandEvent(_:))),
                    (.pause, commandCenter.pauseCommand, #selector(self.pauseCommandEvent(_:))),
                    (.previous, commandCenter.previousTrackCommand, #selector(self.previousTrackCommandEvent(_:))),
                    (.next, commandCenter.nextTrackCommand, #selector(self.nextTrackCommandEvent(_:))),
                    ([.play, .pause], commandCenter.togglePlayPauseCommand, #selector(self.togglePlayPauseCommandEvent(_:)))
                ]
                if #available(iOSApplicationExtension 9.1, *) {
                    optionsAndCommands.append((.seek, commandCenter.changePlaybackPositionCommand, #selector(self.changePlaybackPositionCommandEvent(_:))))
                }
                
                for (option, command, selector) in optionsAndCommands {
                    let previousValue = !currentGlobalControlsOptions.intersection(option).isEmpty
                    let updatedValue = !updatedGlobalControlOptions.intersection(option).isEmpty
                    if previousValue != updatedValue {
                        if updatedValue {
                            command.isEnabled = true
                            command.addTarget(self, action: selector)
                        } else {
                            command.isEnabled = false
                            command.removeTarget(self, action: selector)
                        }
                    }
                }
                
                currentGlobalControlsOptions = updatedGlobalControlOptions
            }
        }))
        
        self.globalControlsArtworkDisposable.set((self.globalControlsArtwork.get()
        |> distinctUntilChanged(isEqual: { $0 == $1 })
        |> mapToSignal { value -> Signal<UIImage?, NoError> in
            if let value = value {
                return Signal { subscriber in
                    let fetched = postbox.mediaBox.fetchedResource(value.fullSizeResource, parameters: nil).start()
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
        
        self.globalControlsStatusDisposable.set((self.globalControlsStatus.get()
        |> deliverOnMainQueue).start(next: { next in
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
            }
        }))
        
       
        let shouldKeepAudioSession: Signal<Bool, NoError> = combineLatest(queue: Queue.mainQueue(), self.globalMediaPlayerState, inForeground)
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
            guard let strongSelf = self else {
                return
            }
            if strongSelf.isCurrent && value {
                strongSelf.audioSession.dropAll()
            }
        }))
    }
    
    deinit {
        self.globalControlsDisposable.dispose()
        self.globalControlsArtworkDisposable.dispose()
        self.globalControlsStatusDisposable.dispose()
        self.setPlaylistByTypeDisposables.dispose()
        self.globalAudioSessionForegroundDisposable.dispose()
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
                            let voiceMediaPlayer = SharedMediaPlayer(mediaManager: strongSelf, inForeground: strongSelf.inForeground, postbox: strongSelf.postbox, audioSession: strongSelf.audioSession, overlayMediaManager: strongSelf.overlayMediaManager, playlist: playlist, initialOrder: .reversed, initialLooping: .none, initialPlaybackRate: settings.voicePlaybackRate, playerIndex: nextPlayerIndex, controlPlaybackWithProximity: true)
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
                            strongSelf.musicMediaPlayer = SharedMediaPlayer(mediaManager: strongSelf, inForeground: strongSelf.inForeground, postbox: strongSelf.postbox, audioSession: strongSelf.audioSession, overlayMediaManager: strongSelf.overlayMediaManager, playlist: playlist, initialOrder: settings.order, initialLooping: settings.looping, initialPlaybackRate: .x1, playerIndex: nextPlayerIndex, controlPlaybackWithProximity: false)
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
    
    @objc func changePlaybackPositionCommandEvent(_ event: MPChangePlaybackPositionCommandEvent) {
        self.playlistControl(.seek(event.positionTime))
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
