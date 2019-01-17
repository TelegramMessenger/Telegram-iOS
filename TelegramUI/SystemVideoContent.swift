import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

import LegacyComponents

final class SystemVideoContent: UniversalVideoContent {
    let id: AnyHashable
    let url: String
    let imageReference: ImageMediaReference
    let dimensions: CGSize
    let duration: Int32
    
    init(url: String, imageReference: ImageMediaReference, dimensions: CGSize, duration: Int32) {
        self.id = AnyHashable(url)
        self.url = url
        self.imageReference = imageReference
        self.dimensions = dimensions
        self.duration = duration
    }
    
    func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return SystemVideoContentNode(postbox: postbox, audioSessionManager: audioSession, url: self.url, imageReference: self.imageReference, intrinsicDimensions: self.dimensions, approximateDuration: self.duration)
    }
}

private final class SystemVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let url: String
    private let intrinsicDimensions: CGSize
    private let approximateDuration: Int32
    
    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused)
    private var isBuffering = false
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(IndexSet, Int)?>()
    var bufferingStatus: Signal<(IndexSet, Int)?, NoError> {
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
    private let playerItem: AVPlayerItem
    private let player: AVPlayer
    private let playerNode: ASDisplayNode
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, url: String, imageReference: ImageMediaReference, intrinsicDimensions: CGSize, approximateDuration: Int32) {
        self.audioSessionManager = audioSessionManager
        
        self.url = url
        self.intrinsicDimensions = intrinsicDimensions
        self.approximateDuration = approximateDuration
        
        self.imageNode = TransformImageNode()
        
        self.playerItem = AVPlayerItem(url: URL(string: url)!)
        let player = AVPlayer(playerItem: self.playerItem)
        self.player = player
        
        self.playerNode = ASDisplayNode()
        self.playerNode.setLayerBlock({
            return AVPlayerLayer(player: player)
        })
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: intrinsicDimensions)
        self.isBuffering = true
        
        super.init()
        
        self.imageNode.setSignal(chatMessagePhoto(postbox: postbox, photoReference: imageReference))
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self.player.actionAtItemEnd = .pause
        
        self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: nil, using: { [weak self] notification in
            if let strongSelf = self {
                strongSelf.player.seek(to: CMTime(seconds: 0.0, preferredTimescale: 30))
                strongSelf.play()
            }
        })
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        self.playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        self.playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        self.playerItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
        
        self._bufferingStatus.set(.single(nil))
    }
    
    deinit {
        self.player.removeObserver(self, forKeyPath: "rate")
        self.playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        self.playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        self.playerItem.removeObserver(self, forKeyPath: "playbackBufferFull")
        
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.statusDisposable?.dispose()
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            let isPlaying = !self.player.rate.isZero
            let status: MediaPlayerPlaybackStatus
            if self.isBuffering {
                status = .buffering(initial: false, whilePlaying: isPlaying)
            } else {
                status = isPlaying ? .playing : .paused
            }
            self.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: status)
            self._status.set(self.statusValue)
        } else if keyPath == "playbackBufferEmpty" {
            let isPlaying = !self.player.rate.isZero
            let status: MediaPlayerPlaybackStatus
            self.isBuffering = true
            if self.isBuffering {
                status = .buffering(initial: false, whilePlaying: isPlaying)
            } else {
                status = isPlaying ? .playing : .paused
            }
            self.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: status)
            self._status.set(self.statusValue)
        } else if keyPath == "playbackLikelyToKeepUp" || keyPath == "playbackBufferFull" {
            let isPlaying = !self.player.rate.isZero
            let status: MediaPlayerPlaybackStatus
            self.isBuffering = false
            if self.isBuffering {
                status = .buffering(initial: false, whilePlaying: isPlaying)
            } else {
                status = isPlaying ? .playing : .paused
            }
            self.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: status)
            self._status.set(self.statusValue)
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
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true)))
        }
        if !self.hasAudioSession {
            self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play, activate: { [weak self] _ in
                self?.hasAudioSession = true
                self?.player.play()
            }, deactivate: { [weak self] in
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
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused))
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
        //self.playerView.seek(toPosition: timestamp)
    }
    
    func playOnceWithSound(playAndRecord: Bool) {
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound() {
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
}

