import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import UniversalMediaPlayer
import TelegramAudio
import AccountContext
import TelegramUniversalVideoContent
import DeviceProximity

private enum SharedMediaPlaybackItem: Equatable {
    case audio(MediaPlayer)
    case instantVideo(OverlayInstantVideoNode)
    
    var playbackStatus: Signal<MediaPlayerStatus, NoError> {
        switch self {
            case let .audio(player):
                return player.status
            case let .instantVideo(node):
                return node.status |> map { status in
                    if let status = status {
                        return status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
        }
    }
    
    static func ==(lhs: SharedMediaPlaybackItem, rhs: SharedMediaPlaybackItem) -> Bool {
        switch lhs {
            case let .audio(lhsPlayer):
                if case let .audio(rhsPlayer) = rhs, lhsPlayer === rhsPlayer {
                    return true
                } else {
                    return false
                }
            case let .instantVideo(lhsNode):
                if case let .instantVideo(rhsNode) = rhs, lhsNode === rhsNode {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func setActionAtEnd(_ f: @escaping () -> Void) {
        switch self {
            case let .audio(player):
                player.actionAtEnd = .action(f)
            case let .instantVideo(node):
                node.playbackEnded = f
        }
    }
    
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
                player.togglePlayPause(faded: true)
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
    
    func setForceAudioToSpeaker(_ value: Bool) {
        switch self {
            case let .audio(player):
                player.setForceAudioToSpeaker(value)
            case let .instantVideo(node):
                node.setForceAudioToSpeaker(value)
        }
    }
}

final class SharedMediaPlayer {
    private weak var mediaManager: MediaManager?
    let account: Account
    private let audioSession: ManagedAudioSession
    private let overlayMediaManager: OverlayMediaManager
    private let playerIndex: Int32
    private let playlist: SharedMediaPlaylist
    
    private var playbackRate: AudioPlaybackRate
    
    private var proximityManagerIndex: Int?
    private let controlPlaybackWithProximity: Bool
    private var forceAudioToSpeaker = false
    
    private var stateDisposable: Disposable?
    
    private var stateValue: SharedMediaPlaylistState? {
        didSet {
            if self.stateValue != oldValue {
                self.state.set(.single(self.stateValue))
            }
        }
    }
    private let state = Promise<SharedMediaPlaylistState?>(nil)
    
    private var playbackStateValueDisposable: Disposable?
    private var _playbackStateValue: SharedMediaPlayerState?
    private let playbackStateValue = Promise<SharedMediaPlayerState?>()
    var playbackState: Signal<SharedMediaPlayerState?, NoError> {
        return self.playbackStateValue.get()
    }
    
    private let audioLevelPipe = ValuePipe<Float>()
    var audioLevel: Signal<Float, NoError> {
        return self.audioLevelPipe.signal()
    }
    private let audioLevelDisposable = MetaDisposable()
    
    private var playbackItem: SharedMediaPlaybackItem? {
        didSet {
            if playbackItem != oldValue {
                switch playbackItem {
                case let .audio(player):
                    let audioLevelPipe = self.audioLevelPipe
                    self.audioLevelDisposable.set((player.audioLevelEvents.start(next: { [weak audioLevelPipe] value in
                        audioLevelPipe?.putNext(value)
                    })))
                default:
                    self.audioLevelDisposable.set(nil)
                }
            }
        }
    }
    private var currentPlayedToEnd = false
    private var scheduledPlaybackAction: SharedMediaPlayerPlaybackControlAction?
    private var scheduledStartTime: Double?
    
    private let markItemAsPlayedDisposable = MetaDisposable()
    
    var playedToEnd: (() -> Void)?
    var cancelled: (() -> Void)?
    
    private var inForegroundDisposable: Disposable?
    
    private var currentPrefetchItems: (SharedMediaPlaybackDataSource, SharedMediaPlaybackDataSource)?
    private let prefetchDisposable = MetaDisposable()
    
    let type: MediaManagerPlayerType
    
    init(mediaManager: MediaManager, inForeground: Signal<Bool, NoError>, account: Account, audioSession: ManagedAudioSession, overlayMediaManager: OverlayMediaManager, playlist: SharedMediaPlaylist, initialOrder: MusicPlaybackSettingsOrder, initialLooping: MusicPlaybackSettingsLooping, initialPlaybackRate: AudioPlaybackRate, playerIndex: Int32, controlPlaybackWithProximity: Bool, type: MediaManagerPlayerType) {
        self.mediaManager = mediaManager
        self.account = account
        self.audioSession = audioSession
        self.overlayMediaManager = overlayMediaManager
        playlist.setOrder(initialOrder)
        playlist.setLooping(initialLooping)
        self.playlist = playlist
        self.playerIndex = playerIndex
        self.playbackRate = initialPlaybackRate
        self.controlPlaybackWithProximity = controlPlaybackWithProximity
        self.type = type
        
        if controlPlaybackWithProximity {
            self.forceAudioToSpeaker = !DeviceProximityManager.shared().currentValue()
        }
        
        playlist.currentItemDisappeared = { [weak self] in
            self?.cancelled?()
        }
        
        self.stateDisposable = (playlist.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                let previousPlaybackItem = strongSelf.playbackItem
                strongSelf.updatePrefetchItems(item: state.item, previousItem: state.previousItem, nextItem: state.nextItem, ordering: state.order)
                if state.item?.playbackData != strongSelf.stateValue?.item?.playbackData {
                    if let playbackItem = strongSelf.playbackItem {
                        switch playbackItem {
                            case .audio:
                                playbackItem.pause()
                            case let .instantVideo(node):
                               node.setSoundEnabled(false)
                               strongSelf.overlayMediaManager.controller?.removeNode(node, customTransition: false)
                        }
                    }
                    strongSelf.playbackItem = nil
                    if let item = state.item, let playbackData = item.playbackData {
                        let rateValue: Double
                        if case .music = playbackData.type {
                            rateValue = 1.0
                        } else {
                            rateValue = strongSelf.playbackRate.doubleValue
                        }
                        
                        switch playbackData.type {
                            case .voice, .music:
                                switch playbackData.source {
                                    case let .telegramFile(fileReference, _):
                                        strongSelf.playbackItem = .audio(MediaPlayer(audioSessionManager: strongSelf.audioSession, postbox: strongSelf.account.postbox, resourceReference: fileReference.resourceReference(fileReference.media.resource), streamable: playbackData.type == .music ? .conservative : .none, video: false, preferSoftwareDecoding: false, enableSound: true, baseRate: rateValue, fetchAutomatically: true, playAndRecord: controlPlaybackWithProximity))
                                }
                            case .instantVideo:
                                if let mediaManager = strongSelf.mediaManager, let item = item as? MessageMediaPlaylistItem {
                                    switch playbackData.source {
                                        case let .telegramFile(fileReference, _):
                                            let videoNode = OverlayInstantVideoNode(postbox: strongSelf.account.postbox, audioSession: strongSelf.audioSession, manager: mediaManager.universalVideoManager, content: NativeVideoContent(id: .message(item.message.stableId, fileReference.media.fileId), fileReference: fileReference, enableSound: false, baseRate: rateValue, captureProtected: item.message.isCopyProtected()), close: { [weak mediaManager] in
                                                mediaManager?.setPlaylist(nil, type: .voice, control: .playback(.pause))
                                            })
                                            strongSelf.playbackItem = .instantVideo(videoNode)
                                            videoNode.setSoundEnabled(true)
                                        videoNode.setBaseRate(rateValue)
                                    }
                                }
                        }
                    }
                    if let playbackItem = strongSelf.playbackItem {
                        playbackItem.setForceAudioToSpeaker(strongSelf.forceAudioToSpeaker)
                        playbackItem.setActionAtEnd({
                            Queue.mainQueue().async {
                                if let strongSelf = self {
                                    switch strongSelf.playlist.looping {
                                        case .item:
                                            strongSelf.playbackItem?.seek(0.0)
                                            strongSelf.playbackItem?.play()
                                        default:
                                            strongSelf.scheduledPlaybackAction = .play
                                            strongSelf.control(.next)
                                    }
                                }
                            }
                        })
                        switch playbackItem {
                            case .audio:
                                break
                            case let .instantVideo(node):
                                strongSelf.overlayMediaManager.controller?.addNode(node, customTransition: false)
                        }
                        
                        if let scheduledPlaybackAction = strongSelf.scheduledPlaybackAction {
                            strongSelf.scheduledPlaybackAction = nil
                            let scheduledStartTime = strongSelf.scheduledStartTime
                            strongSelf.scheduledStartTime = nil
                            
                            switch scheduledPlaybackAction {
                                case .play:
                                    switch playbackItem {
                                        case let .audio(player):
                                            if let scheduledStartTime = scheduledStartTime {
                                                player.seek(timestamp: scheduledStartTime)
                                                player.play()
                                            } else {
                                                player.play()
                                            }
                                        case let .instantVideo(node):
                                            if let scheduledStartTime = scheduledStartTime {
                                                node.seek(scheduledStartTime)
                                                node.playOnceWithSound(playAndRecord: controlPlaybackWithProximity)
                                            } else {
                                                node.playOnceWithSound(playAndRecord: controlPlaybackWithProximity)
                                            }
                                    }
                                case .pause:
                                    playbackItem.pause()
                                case .togglePlayPause:
                                    playbackItem.togglePlayPause()
                            }
                        }
                    }
                }
                
                if strongSelf.currentPlayedToEnd != state.playedToEnd {
                    strongSelf.currentPlayedToEnd = state.playedToEnd
                    if state.playedToEnd {
                        if let playbackItem = strongSelf.playbackItem {
                            switch playbackItem {
                                case let .audio(player):
                                    player.pause()
                                case let .instantVideo(node):
                                    node.setSoundEnabled(false)
                            }
                        }
                        strongSelf.playedToEnd?()
                    }
                }
                
                let updatePlaybackState = strongSelf.stateValue != state || strongSelf.playbackItem != previousPlaybackItem
                strongSelf.stateValue = state
                
                if updatePlaybackState {
                    let playlistId = strongSelf.playlist.id
                    let playlistLocation = strongSelf.playlist.location
                    let playerIndex = strongSelf.playerIndex
                    if let playbackItem = strongSelf.playbackItem, let item = state.item {
                        strongSelf.playbackStateValue.set(playbackItem.playbackStatus
                        |> map { itemStatus in
                            return .item(SharedMediaPlayerItemPlaybackState(playlistId: playlistId, playlistLocation: playlistLocation, item: item, previousItem: state.previousItem, nextItem: state.nextItem, status: itemStatus, order: state.order, looping: state.looping, playerIndex: playerIndex))
                        })
                    strongSelf.markItemAsPlayedDisposable.set((playbackItem.playbackStatus
                        |> filter { status in
                            if case .playing = status.status {
                                return true
                            } else {
                                return false
                            }
                        }
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { next in
                            if let strongSelf = self {
                                strongSelf.playlist.onItemPlaybackStarted(item)
                            }
                        }))
                    } else {
                        if state.item != nil || state.loading {
                            strongSelf.playbackStateValue.set(.single(.loading))
                        } else {
                            strongSelf.playbackStateValue.set(.single(nil))
                            if !state.loading {
                                if let proximityManagerIndex = strongSelf.proximityManagerIndex {
                                    DeviceProximityManager.shared().remove(proximityManagerIndex)
                                }
                            }
                        }
                    }
                }
            }
        })
        
        self.playbackStateValueDisposable = (self.playbackState
        |> deliverOnMainQueue).start(next: { [weak self] value in
            self?._playbackStateValue = value
        })
        
        if controlPlaybackWithProximity {
            self.proximityManagerIndex = DeviceProximityManager.shared().add { [weak self] value in
                let forceAudioToSpeaker = !value
                if let strongSelf = self, strongSelf.forceAudioToSpeaker != forceAudioToSpeaker {
                    strongSelf.forceAudioToSpeaker = forceAudioToSpeaker
                    strongSelf.playbackItem?.setForceAudioToSpeaker(forceAudioToSpeaker)
                    if !forceAudioToSpeaker {
                        strongSelf.control(.playback(.play))
                    } else {
                        strongSelf.control(.playback(.pause))
                    }
                }
            }
        }
    }
    
    deinit {
        self.stateDisposable?.dispose()
        self.markItemAsPlayedDisposable.dispose()
        self.inForegroundDisposable?.dispose()
        self.playbackStateValueDisposable?.dispose()
        self.prefetchDisposable.dispose()
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
        
        if let playbackItem = self.playbackItem {
            switch playbackItem {
                case .audio:
                    playbackItem.pause()
                case let .instantVideo(node):
                    node.setSoundEnabled(false)
                    self.overlayMediaManager.controller?.removeNode(node, customTransition: false)
            }
        }
    }
    
    func control(_ action: SharedMediaPlayerControlAction) {
        switch action {
            case .next:
                self.scheduledPlaybackAction = .play
                self.playlist.control(.next)
            case .previous:
                let threshold: Double = 5.0
                if let playbackStateValue = self._playbackStateValue, case let .item(item) = playbackStateValue, item.status.duration > threshold, item.status.timestamp > threshold {
                    self.control(.seek(0.0))
                } else {
                    self.scheduledPlaybackAction = .play
                    self.playlist.control(.previous)
                }
            case let .playback(action):
                if let playbackItem = self.playbackItem {
                    switch action {
                        case .play:
                            playbackItem.play()
                        case .pause:
                            playbackItem.pause()
                        case .togglePlayPause:
                            playbackItem.togglePlayPause()
                    }
                } else {
                    self.scheduledPlaybackAction = action
                }
            case let .seek(timestamp):
                if let playbackItem = self.playbackItem {
                    playbackItem.seek(timestamp)
                } else {
                    self.scheduledPlaybackAction = .play
                    self.scheduledStartTime = timestamp
                }
            case let .setOrder(order):
                self.playlist.setOrder(order)
            case let .setLooping(looping):
                self.playlist.setLooping(looping)
            case let .setBaseRate(baseRate):
                self.playbackRate = baseRate
                if let playbackItem = self.playbackItem {
                    let rateValue: Double = baseRate.doubleValue
                    switch playbackItem {
                        case let .audio(player):
                            player.setBaseRate(rateValue)
                        case let .instantVideo(node):
                            node.setBaseRate(rateValue)
                    }
                }
        }
    }
    
    func stop() {
        if let playbackItem = self.playbackItem {
            switch playbackItem {
                case let .audio(player):
                    player.pause()
                case let .instantVideo(node):
                    node.setSoundEnabled(false)
            }
        }
    }
    
    private func updatePrefetchItems(item: SharedMediaPlaylistItem?, previousItem: SharedMediaPlaylistItem?, nextItem: SharedMediaPlaylistItem?, ordering: MusicPlaybackSettingsOrder) {
        var prefetchItems: (SharedMediaPlaybackDataSource, SharedMediaPlaybackDataSource)?
        if let playbackData = item?.playbackData {
            switch ordering {
                case .regular:
                    if let previousItem = previousItem?.playbackData {
                        prefetchItems = (playbackData.source, previousItem.source)
                    }
                case .reversed:
                    if let nextItem = nextItem?.playbackData {
                        prefetchItems = (playbackData.source, nextItem.source)
                    }
                case .random:
                    break
            }
        }
        if self.currentPrefetchItems?.0 != prefetchItems?.0 || self.currentPrefetchItems?.1 != prefetchItems?.1 {
            self.currentPrefetchItems = prefetchItems
            if let (current, next) = prefetchItems {
                let fetchedCurrentSignal: Signal<Never, NoError>
                let fetchedNextSignal: Signal<Never, NoError>
                switch current {
                    case let .telegramFile(file, _):
                        fetchedCurrentSignal = self.account.postbox.mediaBox.resourceData(file.media.resource)
                        |> mapToSignal { data -> Signal<Void, NoError> in
                            if data.complete {
                                return .single(Void())
                            } else {
                                return .complete()
                            }
                        }
                        |> take(1)
                        |> ignoreValues
                }
                switch next {
                    case let .telegramFile(file, _):
                        fetchedNextSignal = fetchedMediaResource(mediaBox: self.account.postbox.mediaBox, reference: file.resourceReference(file.media.resource))
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                }
                self.prefetchDisposable.set((fetchedCurrentSignal |> then(fetchedNextSignal)).start())
            } else {
                self.prefetchDisposable.set(nil)
            }
        }
    }
}
