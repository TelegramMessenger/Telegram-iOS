import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

import LegacyComponents

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
    
    func makeContentNode(account: Account) -> UniversalVideoContentNode & ASDisplayNode {
        return WebEmbedVideoContentNode(account: account, audioSessionManager: account.telegramApplicationContext.mediaManager.audioSession, webpageContent: self.webpageContent)
    }
}

private final class WebEmbedVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let webpageContent: TelegramMediaWebpageLoadedContent
    private let intrinsicDimensions: CGSize
    
    private let playerView: TGEmbedPlayerView
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
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
    
    init(account: Account, audioSessionManager: ManagedAudioSession, webpageContent: TelegramMediaWebpageLoadedContent) {
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
        converted.duration = webpageContent.duration.flatMap { NSNumber.init(value: $0) } ?? 0
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
        
        self.playerView = TGEmbedPlayerView.make(forWebPage: converted, thumbnailSignal: thumbmnailSignal)!
        self.playerView.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        self.playerView.disallowPIP = true
        self.playerView.isUserInteractionEnabled = false
        self.playerView.disallowAutoplay = true
        self.playerView.disableControls = true
        
        super.init()
        
        self.view.addSubview(self.playerView)
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
            self.thumbnailDisposable = (rawMessagePhoto(account: account, photo: image) |> deliverOnMainQueue).start(next: { [weak self] image in
                if let strongSelf = self {
                    strongSelf.thumbnail.set(.single(image))
                    strongSelf._ready.set(.single(Void()))
                }
            })
        } else {
            self._ready.set(.single(Void()))
        }
        
        let stateSignal = self.playerView.stateSignal()!
        self._status.set(Signal { subscriber in
            let innerDisposable = stateSignal.start(next: { next in
                if let next = next as? TGEmbedPlayerState {
                    let status: MediaPlayerPlaybackStatus
                    if next.playing {
                        status = .playing
                    } else if next.downloadProgress.isEqual(to: 1.0) {
                        status = .buffering(whilePlaying: next.playing)
                    } else {
                        status = .paused
                    }
                    subscriber.putNext(MediaPlayerStatus(generationTimestamp: 0.0, duration: next.duration, timestamp: next.position, status: status))
                }
            })
            return ActionDisposable {
                innerDisposable?.dispose()
            }
        })
        
        //self._status.set(self.player.status)
    }
    
    deinit {
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.thumbnailDisposable?.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.playerView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        self.playerView.transform = CGAffineTransform(scaleX: size.width / self.intrinsicDimensions.width, y: size.height / self.intrinsicDimensions.height)
        
        //self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        //self.playerNode.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        self.playerView.playVideo()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
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
        self.playerView.seek(toPosition: timestamp)
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
}
