import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

import LegacyComponents

final class WebEmbedVideoContent: UniversalVideoContent {
    let id: AnyHashable
    let webPage: TelegramMediaWebpage
    let webpageContent: TelegramMediaWebpageLoadedContent
    let dimensions: CGSize
    let duration: Int32
    
    init?(webPage: TelegramMediaWebpage, webpageContent: TelegramMediaWebpageLoadedContent) {
        guard let embedUrl = webpageContent.embedUrl else {
            return nil
        }
        self.id = AnyHashable(embedUrl)
        self.webPage = webPage
        self.webpageContent = webpageContent
        self.dimensions = webpageContent.embedSize ?? CGSize(width: 128.0, height: 128.0)
        self.duration = Int32(webpageContent.duration ?? (0 as Int))
    }
    
    func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return WebEmbedVideoContentNode(postbox: postbox, audioSessionManager: audioSession, webPage: self.webPage, webpageContent: self.webpageContent)
    }
}

private final class WebEmbedVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let webpageContent: TelegramMediaWebpageLoadedContent
    private let intrinsicDimensions: CGSize
    private let approximateDuration: Int32
    
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
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
    
    private let imageNode: TransformImageNode
    private let playerNode: WebEmbedPlayerNode
    
    private let thumbnail = Promise<UIImage?>()
    private var thumbnailDisposable: Disposable?
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, webPage: TelegramMediaWebpage, webpageContent: TelegramMediaWebpageLoadedContent) {
        self.webpageContent = webpageContent
        self.approximateDuration = Int32(webpageContent.duration ?? 0)
        
        if let embedSize = webpageContent.embedSize {
            self.intrinsicDimensions = embedSize
        } else {
            self.intrinsicDimensions = CGSize(width: 480.0, height: 320.0)
        }
    
        self.imageNode = TransformImageNode()
        if let embedUrl = webpageContent.embedUrl {
            let impl = webEmbedImplementation(embedUrl: embedUrl, url: webpageContent.url)
            self.playerNode = WebEmbedPlayerNode(impl: impl, intrinsicDimensions: self.intrinsicDimensions)
        } else {
            let impl = GenericEmbedImplementation(url: webpageContent.url)
            self.playerNode = WebEmbedPlayerNode(impl: impl, intrinsicDimensions: self.intrinsicDimensions)
        }
        
        super.init()
        
        //self.addSubnode(self.playerNode)
        self.addSubnode(self.imageNode)
        
        self._preloadCompleted.set(true)
        
        if let image = webpageContent.image {
            self.imageNode.setSignal(chatMessagePhoto(postbox: postbox, photoReference: .webPage(webPage: WebpageReference(webPage), media: image)))
            
            self.thumbnailDisposable = (rawMessagePhoto(postbox: postbox, photoReference: .webPage(webPage: WebpageReference(webPage), media: image))
            |> deliverOnMainQueue).start(next: { [weak self] image in
                if let strongSelf = self {
                    strongSelf.thumbnail.set(.single(image))
                    strongSelf._ready.set(.single(Void()))
                }
            })
        } else {
            self._ready.set(.single(Void()))
        }
        self._status.set(self.playerNode.status)

//
//        self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true)))
//
//        let stateSignal = self.playerView.stateSignal()!
//        self.statusDisposable = (Signal<MediaPlayerStatus, NoError> { subscriber in
//            let innerDisposable = stateSignal.start(next: { next in
//                if let next = next as? TGEmbedPlayerState {
//                    let status: MediaPlayerPlaybackStatus
//                    if next.playing {
//                        status = .playing
//                    } else if next.buffering {
//                        status = .buffering(initial: false, whilePlaying: next.playing)
//                    } else {
//                        status = .paused
//                    }
//                    subscriber.putNext(MediaPlayerStatus(generationTimestamp: 0.0, duration: next.duration, dimensions: CGSize(), timestamp: max(0.0, next.position), baseRate: 1.0, seekId: 0, status: status))
//                }
//            })
//            return ActionDisposable {
//                innerDisposable?.dispose()
//            }
//        } |> deliverOnMainQueue).start(next: { [weak self] value in
//            if let strongSelf = self {
//                if !strongSelf.initializedStatus {
//                    if case .paused = value.status {
//                        return
//                    }
//                }
//                strongSelf.initializedStatus = true
//                strongSelf._status.set(MediaPlayerStatus(generationTimestamp: value.generationTimestamp, duration: value.duration, dimensions: CGSize(), timestamp: value.timestamp, baseRate: 1.0, seekId: strongSelf.seekId, status: value.status))
//            }
//        })
//
//>>>>>>> 368a96b2910b01bf361ed88aefd8662804f55f0a
        self._bufferingStatus.set(.single(nil))
    }
    
    deinit {
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.thumbnailDisposable?.dispose()
        self.statusDisposable?.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(node: self.playerNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(node: self.playerNode, scale: size.width / self.intrinsicDimensions.width)

        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())

        self.playerNode.play()

//        if !self.initializedStatus {
//            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true)))
//        } else {
//            self.playerView.playVideo()
//        }
//>>>>>>> 368a96b2910b01bf361ed88aefd8662804f55f0a
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())

        self.playerNode.pause()

//        if !self.initializedStatus {
//            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: self.seekId, status: .paused))
//        }
//        self.playerView.pauseVideo()
//>>>>>>> 368a96b2910b01bf361ed88aefd8662804f55f0a
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.playerNode.togglePlayPause()
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
        self.playerNode.seek(timestamp: timestamp)
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
