import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AVFoundation
import UniversalMediaPlayer
import TelegramAudio
import AccountContext
import PhotoResources
import RangeSet

public enum PlatformVideoContentId: Hashable {
    case message(MessageId, UInt32, MediaId)
    case instantPage(MediaId, MediaId)
    
    public static func ==(lhs: PlatformVideoContentId, rhs: PlatformVideoContentId) -> Bool {
        switch lhs {
        case let .message(messageId, stableId, mediaId):
            if case .message(messageId, stableId, mediaId) = rhs {
                return true
            } else {
                return false
            }
        case let .instantPage(pageId, mediaId):
            if case .instantPage(pageId, mediaId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .message(messageId, _, mediaId):
            hasher.combine(messageId)
            hasher.combine(mediaId)
        case let .instantPage(pageId, mediaId):
            hasher.combine(pageId)
            hasher.combine(mediaId)
        }
    }
}

public final class PlatformVideoContent: UniversalVideoContent {
    public enum Content {
        case file(FileMediaReference)
        case url(String)
        
        var duration: Int32? {
            switch self {
            case let .file(file):
                return file.media.duration
            case .url:
                return nil
            }
        }
        
        var dimensions: PixelDimensions? {
            switch self {
            case let .file(file):
                return file.media.dimensions
            case .url:
                return PixelDimensions(width: 480, height: 300)
            }
        }
    }
    
    public let id: AnyHashable
    let nativeId: PlatformVideoContentId
    let content: Content
    public let dimensions: CGSize
    public let duration: Int32
    let streamVideo: Bool
    let loopVideo: Bool
    let enableSound: Bool
    let baseRate: Double
    let fetchAutomatically: Bool
    
    public init(id: PlatformVideoContentId, content: Content, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true) {
        self.id = id
        self.nativeId = id
        self.content = content
        self.dimensions = self.content.dimensions?.cgSize ?? CGSize(width: 480, height: 320)
        self.duration = self.content.duration ?? 0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
    }
    
    public func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return PlatformVideoContentNode(postbox: postbox, audioSessionManager: audioSession, content: self.content, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically)
    }
    
    public func isEqual(to other: UniversalVideoContent) -> Bool {
        if let other = other as? PlatformVideoContent {
            if case let .message(_, stableId, _) = self.nativeId {
                if case .message(_, stableId, _) = other.nativeId {
                    if case let .file(file) = self.content {
                        if file.media.isInstantVideo {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
}

private final class PlatformVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let postbox: Postbox
    private let content: PlatformVideoContent.Content
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
    private var isBuffering = false
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private let imageNode: TransformImageNode
    
    private var playerItem: AVPlayerItem?
    private let player: AVPlayer
    private let playerNode: ASDisplayNode
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    private var playerItemFailedToPlayToEndTimeObserver: NSObjectProtocol?
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: CGSize?
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, content: PlatformVideoContent.Content, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool) {
        self.postbox = postbox
        self.content = content
        self.approximateDuration = Double(content.duration ?? 1)
        self.audioSessionManager = audioSessionManager
        
        self.imageNode = TransformImageNode()
        
        let player = AVPlayer(playerItem: nil)
        self.player = player
        
        self.playerNode = ASDisplayNode()
        self.playerNode.setLayerBlock({
            return AVPlayerLayer(player: player)
        })
        
        self.intrinsicDimensions = content.dimensions?.cgSize ?? CGSize()
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        
        super.init()
        
        switch content {
        case let .file(file):
            self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, videoReference: file) |> map { [weak self] getSize, getData in
                Queue.mainQueue().async {
                    if let strongSelf = self, strongSelf.dimensions == nil {
                        if let dimensions = getSize() {
                            strongSelf.dimensions = dimensions
                            strongSelf.dimensionsPromise.set(dimensions)
                            if let size = strongSelf.validLayout {
                                strongSelf.updateLayout(size: size, transition: .immediate)
                            }
                        }
                    }
                }
                return getData
            })
        case .url:
            break
        }
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self.player.actionAtItemEnd = .pause
        
        self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: nil, using: { [weak self] notification in
            self?.performActionAtEnd()
        })
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        self._bufferingStatus.set(.single(nil))
        
        let playerItem: AVPlayerItem
        switch content {
        case let .file(file):
            playerItem = AVPlayerItem(url: URL(string: postbox.mediaBox.completedResourcePath(file.media.resource, pathExtension: "mov") ?? "")!)
        case let .url(url):
            playerItem = AVPlayerItem(url: URL(string: url)!)
        }
        self.setPlayerItem(playerItem)
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let strongSelf = self, let layer = strongSelf.playerNode.layer as? AVPlayerLayer else {
                return
            }
            layer.player = strongSelf.player
        })
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let strongSelf = self, let layer = strongSelf.playerNode.layer as? AVPlayerLayer else {
                return
            }
            layer.player = nil
        })
    }
    
    deinit {
        self.player.removeObserver(self, forKeyPath: "rate")
        
        self.setPlayerItem(nil)
        
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.statusDisposable?.dispose()
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let willResignActiveObserver = self.willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
    }
    
    private func setPlayerItem(_ item: AVPlayerItem?) {
        if let playerItem = self.playerItem {
            playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            playerItem.removeObserver(self, forKeyPath: "playbackBufferFull")
            playerItem.removeObserver(self, forKeyPath: "status")
            if let playerItemFailedToPlayToEndTimeObserver = self.playerItemFailedToPlayToEndTimeObserver {
                NotificationCenter.default.removeObserver(playerItemFailedToPlayToEndTimeObserver)
                self.playerItemFailedToPlayToEndTimeObserver = nil
            }
        }
        
        self.playerItem = item
        
        if let playerItem = self.playerItem {
            playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            self.playerItemFailedToPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: OperationQueue.main, using: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                switch strongSelf.content {
                case .file:
                    break
                case let .url(url):
                    let updatedPlayerItem = AVPlayerItem(url: URL(string: url)!)
                    strongSelf.setPlayerItem(updatedPlayerItem)
                }
            })
        }
        
        self.player.replaceCurrentItem(with: self.playerItem)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            let isPlaying = !self.player.rate.isZero
            let status: MediaPlayerPlaybackStatus
            if isPlaying {
               self.isBuffering = false
            }
            if self.isBuffering {
                status = .buffering(initial: false, whilePlaying: isPlaying, progress: 0.0, display: true)
            } else {
                status = isPlaying ? .playing : .paused
            }
            self.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: status, soundEnabled: true)
            self._status.set(self.statusValue)
        } else if keyPath == "playbackBufferEmpty" {
            let isPlaying = !self.player.rate.isZero
            let status: MediaPlayerPlaybackStatus
            self.isBuffering = true
            if self.isBuffering {
                status = .buffering(initial: false, whilePlaying: isPlaying, progress: 0.0, display: true)
            } else {
                status = isPlaying ? .playing : .paused
            }
            self.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: status, soundEnabled: true)
            self._status.set(self.statusValue)
        } else if keyPath == "playbackLikelyToKeepUp" || keyPath == "playbackBufferFull" {
            let isPlaying = !self.player.rate.isZero
            let status: MediaPlayerPlaybackStatus
            self.isBuffering = false
            if self.isBuffering {
                status = .buffering(initial: false, whilePlaying: isPlaying, progress: 0.0, display: true)
            } else {
                status = isPlaying ? .playing : .paused
            }
            self.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: status, soundEnabled: true)
            self._status.set(self.statusValue)
        } else if keyPath == "status" {
            /*if let playerItem = self.playerItem, false {
                switch playerItem.status {
                case .failed:
                    switch self.content {
                    case .file:
                        break
                    case let .url(url):
                        let updatedPlayerItem = AVPlayerItem(url: URL(string: url)!)
                        self.setPlayerItem(updatedPlayerItem)
                    }
                default:
                    break
                }
            }*/
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(node: self.playerNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(node: self.playerNode, scale: size.width / self.intrinsicDimensions.width)
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let makeImageLayout = self.imageNode.asyncLayout()
        let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        applyImageLayout()
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true))
        }
        if !self.hasAudioSession {
            self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play, activate: { [weak self] _ in
                self?.hasAudioSession = true
                self?.player.play()
            }, deactivate: { [weak self] _ in
                self?.hasAudioSession = false
                self?.player.pause()
                return .complete()
            }))
        } else {
            self.player.play()
        }
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true))
        }
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        if self.player.rate.isZero {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.player.seek(to: CMTime(seconds: timestamp, preferredTimescale: 30))
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {   
    }
    
    func setBaseRate(_ baseRate: Double) {
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
    }

    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
    }
}
