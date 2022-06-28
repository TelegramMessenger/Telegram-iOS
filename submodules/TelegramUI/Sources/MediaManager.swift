import Foundation
import SwiftSignalKit
import AVFoundation
import MobileCoreServices
import Postbox
import TelegramCore
import MediaPlayer
import TelegramAudio
import UniversalMediaPlayer
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramUniversalVideoContent
import DeviceProximity
import MediaResources
import PhotoResources

enum SharedMediaPlayerGroup: Int {
    case music = 0
    case voiceAndInstantVideo = 1
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

public var test: Double?

public final class MediaManagerImpl: NSObject, MediaManager {
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
    
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let inForeground: Signal<Bool, NoError>
    private let presentationData: Signal<PresentationData, NoError>
    
    public let audioSession: ManagedAudioSession
    public let overlayMediaManager: OverlayMediaManager = OverlayMediaManager()
    let sharedVideoContextManager = SharedVideoContextManager()
    
    private var nextPlayerIndex: Int32 = 0
    
    private let voiceMediaPlayerStateDisposable = MetaDisposable()
    private var voiceMediaPlayer: SharedMediaPlayer? {
        didSet {
            if self.voiceMediaPlayer !== oldValue {
                if let voiceMediaPlayer = self.voiceMediaPlayer {
                    let account = voiceMediaPlayer.account
                    self.voiceMediaPlayerStateDisposable.set((voiceMediaPlayer.playbackState
                    |> deliverOnMainQueue).start(next: { [weak self, weak voiceMediaPlayer] state in
                        guard let strongSelf = self else {
                            return
                        }
                        guard let state = state, let voiceMediaPlayer = voiceMediaPlayer else {
                            strongSelf.voiceMediaPlayerStateValue.set(.single(nil))
                            return
                        }
                        if case let .item(item) = state {
                            strongSelf.voiceMediaPlayerStateValue.set(.single((account, .state(item))))
                            let audioLevelValue: (AccountRecordId, SharedMediaPlaylistId, SharedMediaPlaylistItemId, Signal<Float, NoError>)? = (account.id, item.playlistId, item.item.id, voiceMediaPlayer.audioLevel)
                            strongSelf.voiceMediaPlayerAudioLevelEvents.set(.single(audioLevelValue))
                        } else {
                            strongSelf.voiceMediaPlayerStateValue.set(.single((account, .loading)))
                            strongSelf.voiceMediaPlayerAudioLevelEvents.set(.single(nil))
                        }
                    }))
                } else {
                    self.voiceMediaPlayerStateDisposable.set(nil)
                    self.voiceMediaPlayerStateValue.set(.single(nil))
                    self.voiceMediaPlayerAudioLevelEvents.set(.single(nil))
                }
            }
        }
    }
    private let voiceMediaPlayerStateValue = Promise<(Account, SharedMediaPlayerItemPlaybackStateOrLoading)?>(nil)
    var voiceMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading)?, NoError> {
        return self.voiceMediaPlayerStateValue.get()
    }
    
    private let voiceMediaPlayerAudioLevelEvents = Promise<(AccountRecordId, SharedMediaPlaylistId, SharedMediaPlaylistItemId, Signal<Float, NoError>)?>(nil)
    
    private var musicMediaPlayer: SharedMediaPlayer? {
        didSet {
            if self.musicMediaPlayer !== oldValue {
                if let musicMediaPlayer = self.musicMediaPlayer {
                    let type = musicMediaPlayer.type
                    let account = musicMediaPlayer.account
                    self.musicMediaPlayerStateValue.set(musicMediaPlayer.playbackState
                    |> map { state -> (Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)? in
                        guard let state = state else {
                            return nil
                        }
                        if case let .item(item) = state {
                            return (account, .state(item), type)
                        } else {
                            return (account, .loading, type)
                        }
                    } |> deliverOnMainQueue)
                } else {
                    self.musicMediaPlayerStateValue.set(.single(nil))
                }
            }
        }
    }
    private let musicMediaPlayerStateValue = Promise<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?>(nil)
    public var musicMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> {
        return self.musicMediaPlayerStateValue.get()
    }
    
    private let globalMediaPlayerStateValue = Promise<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?>()
    public var globalMediaPlayerState: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> {
        return self.globalMediaPlayerStateValue.get()
    }
    public var activeGlobalMediaPlayerAccountId: Signal<(AccountRecordId, Bool)?, NoError> {
        return self.globalMediaPlayerStateValue.get()
        |> map { state -> (AccountRecordId, Bool)? in
            return state.flatMap { state -> (AccountRecordId, Bool) in
                var isPlaying = false
                if case let .state(value) = state.1 {
                    switch value.status.status {
                    case .playing:
                        isPlaying = true
                    case .buffering(_, true, _, _):
                        isPlaying = true
                    default:
                        break
                    }
                }
                return (state.0.id, isPlaying)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs?.0 != rhs?.0 {
                return false
            }
            if lhs?.1 != rhs?.1 {
                return false
            }
            return true
        })
    }
    
    private let setPlaylistByTypeDisposables = DisposableDict<MediaManagerPlayerType>()
    private var mediaPlaybackStateDisposable = MetaDisposable()
    
    private let sharedPlayerByGroup: [SharedMediaPlayerGroup: SharedMediaPlayer] = [:]
    private var currentOverlayVideoNode: OverlayMediaItemNode?
    
    private let globalControlsStatus = Promise<MediaPlayerStatus?>(nil)
    
    private let globalControlsDisposable = MetaDisposable()
    private let globalControlsArtworkDisposable = MetaDisposable()
    private let globalControlsArtwork = Promise<(Account, SharedMediaPlaybackAlbumArt)?>(nil)
    private let globalControlsStatusDisposable = MetaDisposable()
    private let globalAudioSessionForegroundDisposable = MetaDisposable()
    
    public let universalVideoManager: UniversalVideoManager = UniversalVideoManagerImpl()
    
    public let galleryHiddenMediaManager: GalleryHiddenMediaManager = GalleryHiddenMediaManagerImpl()
    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, inForeground: Signal<Bool, NoError>, presentationData: Signal<PresentationData, NoError>) {
        self.accountManager = accountManager
        self.inForeground = inForeground
        self.presentationData = presentationData
        
        self.audioSession = sharedAudioSession
        
        super.init()
       
        let combinedPlayersSignal: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> = combineLatest(queue: Queue.mainQueue(), self.voiceMediaPlayerState, self.musicMediaPlayerState)
        |> map { voice, music -> (Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)? in
            if let voice = voice {
                return (voice.0, voice.1, .voice)
            } else if let music = music {
                return (music.0, music.1, music.2)
            } else {
                return nil
            }
        }
        self.globalMediaPlayerStateValue.set(combinedPlayersSignal
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs?.0 === rhs?.0 && lhs?.1 == rhs?.1 && lhs?.2 == rhs?.2
        }))
        
        var baseNowPlayingInfo: [String: Any]?
        
        var previousState: SharedMediaPlayerItemPlaybackState?
        var previousDisplayData: SharedMediaPlaybackDisplayData?
        let globalControlsArtwork = self.globalControlsArtwork
        let globalControlsStatus = self.globalControlsStatus
        
        var currentGlobalControlsOptions = GlobalControlOptions()
        
        self.globalControlsDisposable.set((combineLatest(self.globalMediaPlayerState, self.presentationData)
        |> deliverOnMainQueue).start(next: { stateAndType, presentationData in
            var updatedGlobalControlOptions = GlobalControlOptions()
            if let (_, stateOrLoading, type) = stateAndType, case let .state(state) = stateOrLoading {
                if type == .music {
                    updatedGlobalControlOptions.insert(.previous)
                    updatedGlobalControlOptions.insert(.next)
                    updatedGlobalControlOptions.insert(.seek)
                    switch state.status.status {
                        case .playing, .buffering(_, true, _, _):
                            updatedGlobalControlOptions.insert(.pause)
                        default:
                            updatedGlobalControlOptions.insert(.play)
                    }
                }
            }
            
            if let (account, stateOrLoading, type) = stateAndType, type == .music, case let .state(state) = stateOrLoading, let displayData = state.item.displayData {
                if previousDisplayData != displayData {
                    previousDisplayData = displayData
                    
                    var nowPlayingInfo: [String: Any] = [:]
                    
                    var artwork: SharedMediaPlaybackAlbumArt?
                    
                    switch displayData {
                        case let .music(title, performer, artworkValue, _):
                            artwork = artworkValue
                            
                            let titleText: String = title ?? presentationData.strings.MediaPlayer_UnknownTrack
                            let subtitleText: String = performer ?? presentationData.strings.MediaPlayer_UnknownArtist
                            
                            nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                            nowPlayingInfo[MPMediaItemPropertyArtist] = subtitleText
                        case let .voice(author, _):
                            let titleText: String = author?.debugDisplayTitle ?? ""
                            
                            nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                        case let .instantVideo(author, _, _):
                            let titleText: String = author?.debugDisplayTitle ?? ""
                            
                            nowPlayingInfo[MPMediaItemPropertyTitle] = titleText
                    }
                    
                    globalControlsArtwork.set(.single(artwork.flatMap({ (account, $0) })))
                    
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
                if #available(iOSApplicationExtension 9.1, iOS 9.1, *) {
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
        |> distinctUntilChanged(isEqual: { $0?.0 === $1?.0 && $0?.1 == $1?.1 })
        |> mapToSignal { value -> Signal<UIImage?, NoError> in
            if let (account, value) = value {
                return albumArtThumbnailData(engine: TelegramEngine(account: account), thumbnail: value.fullSizeResource)
                |> map { data -> UIImage? in
                    return data.flatMap(UIImage.init(data:))
                }
                /*return Signal { subscriber in
                    let fetched = account.postbox.mediaBox.fetchedResource(value.fullSizeResource, parameters: nil).start()
                    let data = account.postbox.mediaBox.resourceData(value.fullSizeResource, pathExtension: nil, option: .complete(waitUntilFetchStatus: false)).start(next: { data in
                        if data.complete, let value = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            subscriber.putNext(UIImage(data: value))
                            subscriber.putCompletion()
                        }
                    })
                    return ActionDisposable {
                        fetched.dispose()
                        data.dispose()
                    }
                }*/
            } else {
                return .single(nil)
            }
        } |> deliverOnMainQueue).start(next: { image in
            if var nowPlayingInfo = baseNowPlayingInfo {
                if let image = image {
                    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
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
            if let (_, stateOrLoading, _) = stateAndType, case let .state(state) = stateOrLoading {
                switch state.status.status {
                    case .playing:
                        isPlaying = true
                    case let .buffering(_, whilePlaying, _, _):
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
        
        let throttledSignal = self.globalMediaPlayerState
        |> mapToThrottled { next -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> in
            return .single(next) |> then(.complete() |> delay(2.0, queue: Queue.concurrentDefaultQueue()))
        }
        
        self.mediaPlaybackStateDisposable.set(throttledSignal.start(next: { accountStateAndType in
            let minimumStoreDuration: Double?
            if let (account, stateOrLoading, type) = accountStateAndType {
                switch type {
                    case .music:
                        minimumStoreDuration = 10.0 * 60.0
                    case .voice:
                        minimumStoreDuration = 5.0 * 60.0
                    case .file:
                        minimumStoreDuration = nil
                }
            
                if let minimumStoreDuration = minimumStoreDuration, case let .state(state) = stateOrLoading, state.status.duration >= minimumStoreDuration, case .playing = state.status.status {
                    if let item = state.item as? MessageMediaPlaylistItem {
                        var storedState: MediaPlaybackStoredState?
                        if state.status.timestamp > 5.0 && state.status.timestamp < state.status.duration - 5.0 {
                            storedState = MediaPlaybackStoredState(timestamp: state.status.timestamp, playbackRate: state.status.baseRate > 1.0 ? .x2 : .x1)
                        }
                        let _ = updateMediaPlaybackStoredStateInteractively(engine: TelegramEngine(account: account), messageId: item.message.id, state: storedState).start()
                    }
                }
            }
        }))
        
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
        self.mediaPlaybackStateDisposable.dispose()
        self.globalAudioSessionForegroundDisposable.dispose()
        self.voiceMediaPlayerStateDisposable.dispose()
    }
    
    public func audioRecorder(beginWithTone: Bool, applicationBindings: TelegramApplicationBindings, beganWithTone: @escaping (Bool) -> Void) -> Signal<ManagedAudioRecorder?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let audioRecorder = ManagedAudioRecorderImpl(mediaManager: self, pushIdleTimerExtension: { [weak applicationBindings] in
                    return applicationBindings?.pushIdleTimerExtension() ?? EmptyDisposable
                }, beginWithTone: beginWithTone, beganWithTone: beganWithTone)
                subscriber.putNext(audioRecorder)
                
                disposable.set(ActionDisposable {
                })
            }
            return disposable
        }
    }
    
    public func setPlaylist(_ playlist: (Account, SharedMediaPlaylist)?, type: MediaManagerPlayerType, control: SharedMediaPlayerControlAction) {
        assert(Queue.mainQueue().isCurrent())
        let inputData: Signal<(Account, SharedMediaPlaylist, MusicPlaybackSettings, MediaPlaybackStoredState?)?, NoError>
        if let (account, playlist) = playlist {
            inputData = self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.musicPlaybackSettings])
            |> take(1)
            |> mapToSignal { sharedData -> Signal<(Account, SharedMediaPlaylist, MusicPlaybackSettings, MediaPlaybackStoredState?)?, NoError> in
                let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.musicPlaybackSettings]?.get(MusicPlaybackSettings.self) ?? MusicPlaybackSettings.defaultSettings
                
                if let location = playlist.location as? PeerMessagesPlaylistLocation, let messageId = location.messageId {
                    return mediaPlaybackStoredState(engine: TelegramEngine(account: account), messageId: messageId)
                    |> map { storedState in
                        return (account, playlist, settings, storedState)
                    }
                } else {
                    return .single((account, playlist, settings, nil))
                }
            }
        } else {
            inputData = .single(nil)
        }
        
        self.setPlaylistByTypeDisposables.set((inputData
        |> deliverOnMainQueue).start(next: { [weak self] inputData in
            if let strongSelf = self {
                let nextPlayerIndex = strongSelf.nextPlayerIndex
                strongSelf.nextPlayerIndex += 1
                switch type {
                    case .voice:
                        strongSelf.musicMediaPlayer?.control(.playback(.pause))
                        strongSelf.voiceMediaPlayer?.stop()
                        if let (account, playlist, settings, storedState) = inputData {
                            let voiceMediaPlayer = SharedMediaPlayer(mediaManager: strongSelf, inForeground: strongSelf.inForeground, account: account, audioSession: strongSelf.audioSession, overlayMediaManager: strongSelf.overlayMediaManager, playlist: playlist, initialOrder: .reversed, initialLooping: .none, initialPlaybackRate: settings.voicePlaybackRate, playerIndex: nextPlayerIndex, controlPlaybackWithProximity: true, type: type)
                            strongSelf.voiceMediaPlayer = voiceMediaPlayer
                            voiceMediaPlayer.playedToEnd = { [weak voiceMediaPlayer] in
                                if let strongSelf = self, let voiceMediaPlayer = voiceMediaPlayer, voiceMediaPlayer === strongSelf.voiceMediaPlayer {
                                    voiceMediaPlayer.stop()
                                    strongSelf.voiceMediaPlayer = nil
                                }
                            }
                            voiceMediaPlayer.cancelled = { [weak voiceMediaPlayer] in
                                if let strongSelf = self, let voiceMediaPlayer = voiceMediaPlayer, voiceMediaPlayer === strongSelf.voiceMediaPlayer {
                                    voiceMediaPlayer.stop()
                                    strongSelf.voiceMediaPlayer = nil
                                }
                            }
                            
                            var control = control
                            if let timestamp = storedState?.timestamp {
                                control = .seek(timestamp)
                            }
                            voiceMediaPlayer.control(control)
                        } else {
                            strongSelf.voiceMediaPlayer = nil
                        }
                    case .music, .file:
                        strongSelf.musicMediaPlayer?.stop()
                        strongSelf.voiceMediaPlayer?.control(.playback(.pause))
                        if let (account, playlist, settings, storedState) = inputData {
                            let musicMediaPlayer = SharedMediaPlayer(mediaManager: strongSelf, inForeground: strongSelf.inForeground, account: account, audioSession: strongSelf.audioSession, overlayMediaManager: strongSelf.overlayMediaManager, playlist: playlist, initialOrder: settings.order, initialLooping: settings.looping, initialPlaybackRate: storedState?.playbackRate ?? .x1, playerIndex: nextPlayerIndex, controlPlaybackWithProximity: false, type: type)
                            strongSelf.musicMediaPlayer = musicMediaPlayer
                            musicMediaPlayer.cancelled = { [weak musicMediaPlayer] in
                                if let strongSelf = self, let musicMediaPlayer = musicMediaPlayer, musicMediaPlayer === strongSelf.musicMediaPlayer {
                                    musicMediaPlayer.stop()
                                    strongSelf.musicMediaPlayer = nil
                                }
                            }
                            
                            var control = control
                            if let timestamp = storedState?.timestamp {
                                control = .seek(timestamp)
                            }
                            strongSelf.musicMediaPlayer?.control(control)
                        } else {
                            strongSelf.musicMediaPlayer = nil
                        }
                }
            }
        }), forKey: type)
    }
    
    public func playlistControl(_ control: SharedMediaPlayerControlAction, type: MediaManagerPlayerType?) {
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
            case .music, .file:
                if self.voiceMediaPlayer != nil {
                    switch control {
                        case .playback(.play), .playback(.togglePlayPause):
                            self.setPlaylist(nil, type: .voice, control: .playback(.pause))
                        default:
                            break
                    }
                }
                self.musicMediaPlayer?.control(control)
        }
    }
    
    public func filteredPlaylistState(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<SharedMediaPlayerItemPlaybackState?, NoError> {
        let signal: Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading)?, NoError>
        switch type {
            case .voice:
                signal = self.voiceMediaPlayerState
            case .music, .file:
                signal = self.musicMediaPlayerState
                |> map { value in
                    return value.flatMap { ($0.0, $0.1) }
                }
        }
        return signal
        |> map { stateOrLoading -> SharedMediaPlayerItemPlaybackState? in
            if let (account, stateOrLoading) = stateOrLoading, account.id == accountId, case let .state(state) = stateOrLoading {
                if state.playlistId.isEqual(to: playlistId) && state.item.id.isEqual(to: itemId) {
                    return state
                }
            }
            return nil
        } |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
    }
    
    public func filteredPlayerAudioLevelEvents(accountId: AccountRecordId, playlistId: SharedMediaPlaylistId, itemId: SharedMediaPlaylistItemId, type: MediaManagerPlayerType) -> Signal<Float, NoError> {
        switch type {
            case .voice:
                return self.voiceMediaPlayerAudioLevelEvents.get()
                |> mapToSignal { value -> Signal<Float, NoError> in
                    guard let value = value else {
                        return .never()
                    }
                    let (accountIdValue, playlistIdValue, itemIdValue, signal) = value
                    if accountIdValue == accountId && playlistId.isEqual(to: playlistIdValue) && itemId.isEqual(to: itemIdValue) {
                        return signal
                    } else {
                        return .never()
                    }
                }
            case .music, .file:
                return .never()
        }
    }
    
    @objc func playCommandEvent(_ command: AnyObject) -> MPRemoteCommandHandlerStatus {
        self.playlistControl(.playback(.play), type: nil)
        
        return .success
    }
    
    @objc func pauseCommandEvent(_ command: AnyObject) -> MPRemoteCommandHandlerStatus {
        self.playlistControl(.playback(.pause), type: nil)
        
        return .success
    }
    
    @objc func previousTrackCommandEvent(_ command: AnyObject) -> MPRemoteCommandHandlerStatus {
        self.playlistControl(.previous, type: nil)
        
        return .success
    }
    
    @objc func nextTrackCommandEvent(_ command: AnyObject) -> MPRemoteCommandHandlerStatus {
        self.playlistControl(.next, type: nil)
        
        return .success
    }
    
    @objc func togglePlayPauseCommandEvent(_ command: AnyObject) -> MPRemoteCommandHandlerStatus {
        self.playlistControl(.playback(.togglePlayPause), type: nil)
        
        return .success
    }
    
    @objc func changePlaybackPositionCommandEvent(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.playlistControl(.seek(event.positionTime), type: nil)
        
        return .success
    }
    
    public func setOverlayVideoNode(_ node: OverlayMediaItemNode?) {
        if let currentOverlayVideoNode = self.currentOverlayVideoNode {
            self.overlayMediaManager.controller?.removeNode(currentOverlayVideoNode, customTransition: true)
            self.currentOverlayVideoNode = nil
        }
        
        if let node = node {
            self.currentOverlayVideoNode = node
            self.overlayMediaManager.controller?.addNode(node, customTransition: true)
        }
    }
    
    public func hasOverlayVideoNode(_ node: OverlayMediaItemNode) -> Bool {
        return self.currentOverlayVideoNode === node
    }
}
