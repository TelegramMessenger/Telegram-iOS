import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramAudio
import UniversalMediaPlayer
import LegacyComponents
import AccountContext
import PhotoResources
import RangeSet

public final class WebEmbedVideoContent: UniversalVideoContent {
    public let id: AnyHashable
    let webPage: TelegramMediaWebpage
    public let webpageContent: TelegramMediaWebpageLoadedContent
    public let dimensions: CGSize
    public let duration: Int32
    let forcedTimestamp: Int?
    let openUrl: (URL) -> Void
    
    public init?(webPage: TelegramMediaWebpage, webpageContent: TelegramMediaWebpageLoadedContent, forcedTimestamp: Int? = nil, openUrl: @escaping (URL) -> Void) {
        guard let embedUrl = webpageContent.embedUrl else {
            return nil
        }
        self.id = AnyHashable(embedUrl)
        self.webPage = webPage
        self.webpageContent = webpageContent
        self.dimensions = webpageContent.embedSize?.cgSize ?? CGSize(width: 128.0, height: 128.0)
        self.duration = Int32(webpageContent.duration ?? (0 as Int))
        self.forcedTimestamp = forcedTimestamp
        self.openUrl = openUrl
    }
    
    public func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return WebEmbedVideoContentNode(postbox: postbox, audioSessionManager: audioSession, webPage: self.webPage, webpageContent: self.webpageContent, forcedTimestamp: self.forcedTimestamp, openUrl: self.openUrl)
    }
}
 
final class WebEmbedVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let webpageContent: TelegramMediaWebpageLoadedContent
    private let intrinsicDimensions: CGSize
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private var seekId: Int = 0
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let imageNode: TransformImageNode
    private let playerNode: WebEmbedPlayerNode
    
    var impl: WebEmbedImplementation {
        return playerNode.impl
    }
        
    private var readyDisposable = MetaDisposable()
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, webPage: TelegramMediaWebpage, webpageContent: TelegramMediaWebpageLoadedContent, forcedTimestamp: Int? = nil, openUrl: @escaping (URL) -> Void) {
        self.webpageContent = webpageContent
        
        if let embedSize = webpageContent.embedSize {
            self.intrinsicDimensions = embedSize.cgSize
        } else {
            self.intrinsicDimensions = CGSize(width: 480.0, height: 320.0)
        }
    
        self.imageNode = TransformImageNode()
        
        let embedType = webEmbedType(content: webpageContent, forcedTimestamp: forcedTimestamp)
        let embedImpl = webEmbedImplementation(for: embedType)
        self.playerNode = WebEmbedPlayerNode(impl: embedImpl, intrinsicDimensions: self.intrinsicDimensions, openUrl: openUrl)
        
        super.init()
        
        self.addSubnode(self.playerNode)
        self.addSubnode(self.imageNode)
        
        if let image = webpageContent.image {
            self.imageNode.setSignal(chatMessagePhoto(postbox: postbox, photoReference: .webPage(webPage: WebpageReference(webPage), media: image)))
            self.imageNode.imageUpdated = { [weak self] _ in
                self?._ready.set(.single(Void()))
            }
        } else {
            self._ready.set(.single(Void()))
        }
        self._status.set(self.playerNode.status)
        self._bufferingStatus.set(.single(nil))
        
        self.readyDisposable.set(self.playerNode.ready.start(next: { [weak self] ready in
            if ready {
                self?.imageNode.isHidden = true
            }
        }, error: { _ in }, completed: {}))
    }
    
    deinit {
        self.readyDisposable.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(node: self.playerNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(node: self.playerNode, scale: size.width / self.intrinsicDimensions.width)

        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if let image = webpageContent.image, let representation = image.representationForDisplayAtSize(PixelDimensions(self.intrinsicDimensions)) {
            let makeImageLayout = self.imageNode.asyncLayout()
            let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: representation.dimensions.cgSize.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
            applyImageLayout()
        }
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())

        self.playerNode.play()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())

        self.playerNode.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.playerNode.togglePlayPause()
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        self.playerNode.seek(timestamp: timestamp)
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        if case let .timecode(time) = seek {
            self.playerNode.seek(timestamp: time)
        } else {
            self.playerNode.play()
        }
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {   
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.playerNode.setBaseRate(baseRate)
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
        self.playerNode.notifyPlaybackControlsHidden(hidden)
    }

    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
    }
}
