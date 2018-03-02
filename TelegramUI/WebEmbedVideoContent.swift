import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

import LegacyComponents

func webEmbedVideoContentSupportsWebpage(_ webpageContent: TelegramMediaWebpageLoadedContent) -> Bool {
    switch websiteType(of: webpageContent) {
        case .instagram:
            return true
        default:
            break
    }
        
    let converted = TGWebPageMediaAttachment()
    
    converted.url = webpageContent.url
    converted.displayUrl = webpageContent.displayUrl
    converted.pageType = webpageContent.type
    converted.siteName = webpageContent.websiteName
    converted.title = webpageContent.title
    converted.pageDescription = webpageContent.text
    converted.embedUrl = webpageContent.embedUrl
    converted.embedType = webpageContent.embedType
    converted.embedSize = webpageContent.embedSize ?? CGSize()
    let approximateDuration = Int32(webpageContent.duration ?? 0)
    converted.duration = approximateDuration as NSNumber
    converted.author = webpageContent.author
    
    return TGEmbedPlayerView.hasNativeSupportFor(x: converted)
}

final class WebEmbedVideoContent: UniversalVideoContent {
    let id: AnyHashable
    let webpageContent: TelegramMediaWebpageLoadedContent
    let dimensions: CGSize
    let duration: Int32
    
    init?(webpageContent: TelegramMediaWebpageLoadedContent) {
        guard let embedUrl = webpageContent.embedUrl else {
            return nil
        }
        self.id = AnyHashable(embedUrl)
        self.webpageContent = webpageContent
        self.dimensions = webpageContent.embedSize ?? CGSize(width: 128.0, height: 128.0)
        self.duration = Int32(webpageContent.duration ?? (0 as Int))
    }
    
    func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return WebEmbedVideoContentNode(postbox: postbox, audioSessionManager: audioSession, webpageContent: self.webpageContent)
    }
}

private final class WebEmbedVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let webpageContent: TelegramMediaWebpageLoadedContent
    private let intrinsicDimensions: CGSize
    private let approximateDuration: Int32
    
    private let playerView: TGEmbedPlayerView
    private let playerViewContainer: UIView
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(IndexSet, Int)?>()
    var bufferingStatus: Signal<(IndexSet, Int)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private var seekId: Int = 0
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private let thumbnail = Promise<UIImage?>()
    private var thumbnailDisposable: Disposable?
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, webpageContent: TelegramMediaWebpageLoadedContent) {
        self.webpageContent = webpageContent
        
        let converted = TGWebPageMediaAttachment()
        
        converted.url = webpageContent.url
        converted.displayUrl = webpageContent.displayUrl
        converted.pageType = webpageContent.type
        converted.siteName = webpageContent.websiteName
        converted.title = webpageContent.title
        converted.pageDescription = webpageContent.text
        converted.embedUrl = webpageContent.embedUrl
        converted.embedType = webpageContent.embedType
        converted.embedSize = webpageContent.embedSize ?? CGSize()
        self.approximateDuration = Int32(webpageContent.duration ?? 0)
        converted.duration = self.approximateDuration as NSNumber
        converted.author = webpageContent.author
        
        if let embedSize = webpageContent.embedSize {
            self.intrinsicDimensions = embedSize
        } else {
            self.intrinsicDimensions = CGSize(width: 480.0, height: 320.0)
        }
        
        var thumbmnailSignal: SSignal?
        if let _ = webpageContent.image {
            let thumbnail = self.thumbnail
            thumbmnailSignal = SSignal(generator: { subscriber in
                let disposable = thumbnail.get().start(next: { image in
                    subscriber?.putNext(image)
                })
                
                return SBlockDisposable(block: {
                    disposable.dispose()
                })
            })
        }
        
        self.playerViewContainer = UIView()
        
        self.playerView = TGEmbedPlayerView.make(forWebPage: converted, thumbnailSignal: thumbmnailSignal)!
        self.playerView.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        self.playerViewContainer.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        self.playerView.disallowPIP = true
        self.playerView.isUserInteractionEnabled = false
        //self.playerView.disallowAutoplay = true
        self.playerView.disableControls = true
        
        super.init()
        
        self.playerViewContainer.addSubview(self.playerView)
        self.view.addSubview(self.playerViewContainer)
        self.playerView.setup(withEmbedSize: self.intrinsicDimensions)
        
        let nativeLoadProgress = self.playerView.loadProgress()
        let loadProgress: Signal<Float, NoError> = Signal { subscriber in
            let disposable = nativeLoadProgress?.start(next: { value in
                subscriber.putNext((value as! NSNumber).floatValue)
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
        self.loadProgressDisposable = (loadProgress |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf._preloadCompleted.set(value.isEqual(to: 1.0))
            }
        })
        
        if let image = webpageContent.image {
            self.thumbnailDisposable = (rawMessagePhoto(postbox: postbox, photo: image) |> deliverOnMainQueue).start(next: { [weak self] image in
                if let strongSelf = self {
                    strongSelf.thumbnail.set(.single(image))
                    strongSelf._ready.set(.single(Void()))
                }
            })
        } else {
            self._ready.set(.single(Void()))
        }
        
        self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true)))
        
        let stateSignal = self.playerView.stateSignal()!
        self.statusDisposable = (Signal<MediaPlayerStatus, NoError> { subscriber in
            let innerDisposable = stateSignal.start(next: { next in
                if let next = next as? TGEmbedPlayerState {
                    let status: MediaPlayerPlaybackStatus
                    if next.playing {
                        status = .playing
                    } else if next.buffering {
                        status = .buffering(initial: false, whilePlaying: next.playing)
                    } else {
                        status = .paused
                    }
                    subscriber.putNext(MediaPlayerStatus(generationTimestamp: 0.0, duration: next.duration, dimensions: CGSize(), timestamp: max(0.0, next.position), seekId: 0, status: status))
                }
            })
            return ActionDisposable {
                innerDisposable?.dispose()
            }
        } |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if !strongSelf.initializedStatus {
                    if case .paused = value.status {
                        return
                    }
                }
                strongSelf.initializedStatus = true
                strongSelf._status.set(MediaPlayerStatus(generationTimestamp: value.generationTimestamp, duration: value.duration, dimensions: CGSize(), timestamp: value.timestamp, seekId: strongSelf.seekId, status: value.status))
            }
        })
        
        self._bufferingStatus.set(.single(nil))
    }
    
    deinit {
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.thumbnailDisposable?.dispose()
        self.statusDisposable?.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(layer: self.playerViewContainer.layer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(layer: self.playerViewContainer.layer, scale: size.width / self.intrinsicDimensions.width)
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true)))
        } else {
            self.playerView.playVideo()
        }
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, seekId: self.seekId, status: .paused))
        }
        self.playerView.pauseVideo()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        if let state = self.playerView.state, state.playing {
            self.pause()
        } else {
            self.play()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        /*if value {
            self.player.playOnceWithSound()
        } else {
            self.player.continuePlayingWithoutSound()
        }*/
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        self.playerView.seek(toPosition: timestamp)
    }
    
    func playOnceWithSound(playAndRecord: Bool) {
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound() {
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
