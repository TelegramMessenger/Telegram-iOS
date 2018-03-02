import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

import LegacyComponents

private func setupArrowFrame(size: CGSize, edge: OverlayMediaItemMinimizationEdge, view: TGEmbedPIPPullArrowView) {
    let arrowX: CGFloat
    switch edge {
    case .left:
        view.transform = .identity
        arrowX = size.width - 40.0 + floor((40.0 - view.bounds.size.width) / 2.0)
    case .right:
        view.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        arrowX = floor((40.0 - view.bounds.size.width) / 2.0)
    }
    
    view.frame = CGRect(origin: CGPoint(x: arrowX, y: floor((size.height - view.bounds.size.height) / 2.0)), size: view.bounds.size)
}

private final class SharedEmbedVideoContext: SharedVideoContext {
    let playerView: TGEmbedPlayerView
    let intrinsicSize: CGSize
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
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
    
    init(account: Account, audioSessionManager: ManagedAudioSession, webpage: TelegramMediaWebpageLoadedContent) {
        let converted = TGWebPageMediaAttachment()
        
        converted.url = webpage.url
        converted.displayUrl = webpage.displayUrl
        converted.pageType = webpage.type
        converted.siteName = webpage.websiteName
        converted.title = webpage.title
        converted.pageDescription = webpage.text
        converted.embedUrl = webpage.embedUrl
        converted.embedType = webpage.embedType
        converted.embedSize = webpage.embedSize ?? CGSize()
        converted.duration = webpage.duration.flatMap { NSNumber.init(value: $0) } ?? 0
        converted.author = webpage.author
        
        if let embedSize = webpage.embedSize {
            self.intrinsicSize = embedSize
        } else {
            self.intrinsicSize = CGSize(width: 480.0, height: 320.0)
        }
        
        var thumbmnailSignal: SSignal?
        if let _ = webpage.image {
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
        self.playerView.frame = CGRect(origin: CGPoint(), size: self.intrinsicSize)
        self.playerView.disallowPIP = true
        self.playerView.isUserInteractionEnabled = false
        
        super.init()
        
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
        
        if let image = webpage.image {
            self.thumbnailDisposable = (rawMessagePhoto(postbox: account.postbox, photo: image) |> deliverOnMainQueue).start(next: { [weak self] image in
                if let strongSelf = self {
                    strongSelf.thumbnail.set(.single(image))
                    strongSelf._ready.set(.single(Void()))
                }
            })
        } else {
            self._ready.set(.single(Void()))
        }
        
        self.playerView.stateSignal()
    }
    
    deinit {
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.thumbnailDisposable?.dispose()
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
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.playerView.seek(toPosition: timestamp)
    }
}

enum EmbedVideoNodeSource {
    case webpage(TelegramMediaWebpageLoadedContent)
    
    fileprivate var id: EmbedVideoNodeMessageMediaId {
        switch self {
            case let .webpage(content):
                return EmbedVideoNodeMessageMediaId(url: content.url)
        }
    }
    
    fileprivate var image: TelegramMediaImage? {
        switch self {
            case let .webpage(content):
                return content.image
        }
    }
}

private struct EmbedVideoNodeMessageMediaId: Hashable {
    let url: String
    
    static func ==(lhs: EmbedVideoNodeMessageMediaId, rhs: EmbedVideoNodeMessageMediaId) -> Bool {
        return lhs.url == rhs.url
    }
    
    var hashValue: Int {
        return self.url.hashValue
    }
}

private let backgroundImage = UIImage(bundleImageName: "Chat/Message/OverlayPlainVideoShadow")?.precomposed().resizableImage(withCapInsets: UIEdgeInsets(top: 22.0, left: 25.0, bottom: 26.0, right: 25.0), resizingMode: .stretch)

final class EmbedVideoNode: OverlayMediaItemNode {
    private let manager: MediaManager
    private let account: Account
    private let source: EmbedVideoNodeSource
    private let priority: Int32
    private let withSound: Bool
    private let postbox: Postbox
    
    private var soundEnabled: Bool
    
    private var contextId: Int32?
    
    private var context: SharedEmbedVideoContext?
    private var contextPlaybackEndedIndex: Int?
    private var validLayout: CGSize?
    
    private let backgroundNode: ASImageNode
    private let imageNode: TransformImageNode
    private var snapshotView: UIView?
    private var statusNode: RadialStatusNode?
    private let controlsNode: PictureInPictureVideoControlsNode?
    private var minimizedBlurView: UIVisualEffectView?
    private var minimizedArrowView: TGEmbedPIPPullArrowView?
    private var minimizedEdge: OverlayMediaItemMinimizationEdge?
    
    private var preloadDisposable: Disposable?
    
    var tapped: (() -> Void)?
    var dismissed: (() -> Void)?
    var unembed: (() -> Void)?
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override var group: OverlayMediaItemNodeGroup? {
        return OverlayMediaItemNodeGroup(rawValue: 1)
    }
    
    override var isMinimizeable: Bool {
        return true
    }
    
    init(manager: MediaManager, account: Account, source: EmbedVideoNodeSource, priority: Int32, withSound: Bool, withOverlayControls: Bool = false) {
        self.manager = manager
        self.account = account
        self.source = source
        self.priority = priority
        self.withSound = withSound
        self.soundEnabled = withSound
        self.postbox = account.postbox
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        
        var leaveImpl: (() -> Void)?
        var togglePlayPauseImpl: (() -> Void)?
        var closeImpl: (() -> Void)?
        
        if withOverlayControls {
            let controlsNode = PictureInPictureVideoControlsNode(leave: {
                leaveImpl?()
            }, playPause: {
                togglePlayPauseImpl?()
            }, close: {
                closeImpl?()
            })
            controlsNode.alpha = 0.0
            self.controlsNode = controlsNode
        } else {
            self.controlsNode = nil
        }
        
        super.init()
        
        leaveImpl = { [weak self] in
            self?.unembed?()
        }
        
        togglePlayPauseImpl = { [weak self] in
            self?.togglePlayPause()
        }
        
        closeImpl = { [weak self] in
            if let strongSelf = self {
                if withOverlayControls {
                    strongSelf.layer.animateScale(from: 1.0, to: 0.1, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        self?.dismiss()
                    })
                    strongSelf.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                } else {
                    strongSelf.dismiss()
                }
            }
        }
        
        if withOverlayControls {
            self.backgroundNode.image = backgroundImage
            
            self.layer.masksToBounds = true
            self.layer.cornerRadius = 2.5
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        if let controlsNode = self.controlsNode {
            controlsNode.status = self.status
            self.addSubnode(controlsNode)
        }
        
        if let image = source.image {
            self.imageNode.setSignal(chatMessagePhoto(postbox: account.postbox, photo: image))
        }
    }
    
    deinit {
        if let context = self.context {
            if context.playerView.superview === self.view {
                context.playerView.removeFromSuperview()
            }
        }
        
        let manager = self.manager
        let source = self.source
        let contextId = self.contextId
        
        Queue.mainQueue().async {
            if let contextId = contextId {
                manager.sharedVideoContextManager.detachSharedVideoContext(id: source.id, index: contextId)
            }
        }
        
        self.preloadDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    private func updateContext(_ context: SharedEmbedVideoContext?) {
        assert(Queue.mainQueue().isCurrent())
        
        let previous = self.context
        self.context = context
        if previous !== context {
            if let snapshotView = self.snapshotView {
                snapshotView.removeFromSuperview()
                self.snapshotView = nil
            }
            if let previous = previous {
                self.contextPlaybackEndedIndex = nil
                if previous.playerView.superview === self.view {
                    previous.playerView.removeFromSuperview()
                }
            }
            if let context = context {
                if context.playerView.superview !== self {
                    if let controlsNode = self.controlsNode {
                        self.view.insertSubview(context.playerView, belowSubview: controlsNode.view)
                    } else {
                        self.view.addSubview(context.playerView)
                    }
                    if let validLayout = self.validLayout {
                        self.updateLayoutImpl(validLayout)
                    }
                }
            }
            if self.hasAttachedContext != (context !== nil) {
                self.hasAttachedContext = (context !== nil)
                self.hasAttachedContextUpdated?(self.hasAttachedContext)
            }
        }
    }
    
    override func layout() {
        self.updateLayout(self.bounds.size)
    }
    
    override func updateLayout(_ size: CGSize) {
        if size != self.validLayout {
            self.updateLayoutImpl(size)
        }
    }
    
    private func updateLayoutImpl(_ size: CGSize) {
        self.validLayout = size
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets())
        let videoFrame = CGRect(origin: CGPoint(), size: arguments.boundingSize)
        
        if let context = self.context {
            context.playerView.center = CGPoint(x: videoFrame.midX, y: videoFrame.midY)
            context.playerView.transform = CGAffineTransform(scaleX: videoFrame.size.width / context.intrinsicSize.width, y: videoFrame.size.height / context.intrinsicSize.height)
        }
        
        let backgroundInsets = UIEdgeInsets(top: 11.5, left: 13.5, bottom: 11.5, right: 13.5)
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: -backgroundInsets.left, y: -backgroundInsets.top), size: CGSize(width: videoFrame.size.width + backgroundInsets.left + backgroundInsets.right, height: videoFrame.size.height + backgroundInsets.top + backgroundInsets.bottom))
        
        self.imageNode.asyncLayout()(arguments)()
        self.imageNode.frame = videoFrame
        self.snapshotView?.frame = self.imageNode.frame
        
        if let statusNode = self.statusNode {
            statusNode.frame = CGRect(origin: CGPoint(x: floor((size.width - 50.0) / 2.0), y: floor((size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0))
        }
        
        if let controlsNode = self.controlsNode {
            controlsNode.frame = videoFrame
            controlsNode.updateLayout(size: videoFrame.size, transition: .immediate)
        }
        
        if let minimizedBlurView = self.minimizedBlurView {
            minimizedBlurView.frame = videoFrame
        }
        
        if let minimizedArrowView = self.minimizedArrowView, let minimizedEdge = self.minimizedEdge {
            setupArrowFrame(size: videoFrame.size, edge: minimizedEdge, view: minimizedArrowView)
        }
    }
    
    func play() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedEmbedVideoContext {
                context.play()
            }
        })
    }
    
    func pause() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedEmbedVideoContext {
                context.pause()
            }
        })
    }
    
    func togglePlayPause() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedEmbedVideoContext {
                context.togglePlayPause()
            }
        })
    }
    
    func setSoundEnabled(_ value: Bool) {
        self.soundEnabled = value
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedEmbedVideoContext {
                //context.setSoundEnabled(value)
            }
        })
    }
    
    func seek(_ timestamp: Double) {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedEmbedVideoContext {
                context.seek(timestamp)
            }
        })
    }
    
    override func setShouldAcquireContext(_ value: Bool) {
        if value {
            if self.contextId == nil {
                self.contextId = self.manager.sharedVideoContextManager.attachSharedVideoContext(id: source.id, priority: self.priority, create: {
                    switch self.source {
                        case let .webpage(content):
                            var size = CGSize(width: 100.0, height: 100.0)
                            if let embedSize = content.embedSize {
                                size = embedSize
                            }
                            let context = SharedEmbedVideoContext(account: self.account, audioSessionManager: manager.audioSession, webpage: content)
                            context.playerView.setup(withEmbedSize: size)
                            //context.setSoundEnabled(self.soundEnabled)
                            return context
                    }
                }, update: { [weak self] context in
                    if let strongSelf = self {
                        strongSelf.updateContext(context as? SharedEmbedVideoContext)
                    }
                })
            }
        } else if let contextId = self.contextId {
            self.manager.sharedVideoContextManager.detachSharedVideoContext(id: self.source.id, index: contextId)
            self.contextId = nil
        }
        
        if !self.initializedStatus {
            self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
                if let context = context as? SharedEmbedVideoContext {
                    self.initializedStatus = true
                    self._status.set(Signal { subscriber in
                        let innerDisposable = context.playerView.stateSignal().start(next: { next in
                            if let next = next as? TGEmbedPlayerState {
                                let status: MediaPlayerPlaybackStatus
                                if next.playing {
                                    status = .playing
                                } else if next.downloadProgress.isEqual(to: 1.0) {
                                    status = .buffering(initial: false, whilePlaying: next.playing)
                                } else {
                                    status = .paused
                                }
                                subscriber.putNext(MediaPlayerStatus(generationTimestamp: 0.0, duration: next.duration, dimensions: CGSize(), timestamp: next.position, seekId: 0, status: status))
                            }
                        })
                        return ActionDisposable {
                            innerDisposable?.dispose()
                        }
                    })
                    self._ready.set(context.ready)
                    
                    self.preloadDisposable = (context.preloadCompleted |> deliverOnMainQueue).start(next: { [weak self] value in
                        if let strongSelf = self {
                            if value {
                                if let statusNode = strongSelf.statusNode {
                                    strongSelf.statusNode = nil
                                    statusNode.transitionToState(.none, completion: { [weak statusNode] in
                                        statusNode?.removeFromSupernode()
                                    })
                                }
                            } else {
                                if strongSelf.statusNode == nil {
                                    let statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
                                    strongSelf.statusNode = statusNode
                                    strongSelf.addSubnode(statusNode)
                                    let size = strongSelf.bounds.size
                                    statusNode.frame = CGRect(origin: CGPoint(x: floor((size.width - 50.0) / 2.0), y: floor((size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0))
                                    statusNode.transitionToState(.progress(color: .white, value: nil, cancelEnabled: false), completion: {})
                                }
                            }
                        }
                    })
                }
            })
        }
    }
    
    override func preferredSizeForOverlayDisplay() -> CGSize {
        var size = CGSize(width: 100.0, height: 100.0)
        switch self.source {
            case let .webpage(content):
                if let embedSize = content.embedSize {
                    size = embedSize
                }
        }
        return size.aspectFitted(CGSize(width: 300.0, height: 300.0))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
            
            if let controlsNode = self.controlsNode {
                if controlsNode.alpha.isZero {
                    controlsNode.alpha = 1.0
                    controlsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                } else {
                    controlsNode.alpha = 0.0
                    controlsNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
            
            if let _ = self.minimizedEdge {
                self.unminimize?()
            }
        }
    }
    
    override func dismiss() {
        self.dismissed?()
    }
    
    override func updateMinimizedEdge(_ edge: OverlayMediaItemMinimizationEdge?, adjusting: Bool) {
        if self.minimizedEdge == edge {
            if let minimizedArrowView = self.minimizedArrowView {
                minimizedArrowView.setAngled(!adjusting, animated: true)
            }
            return
        }
        
        self.minimizedEdge = edge
        
        if let edge = edge {
            if self.minimizedBlurView == nil {
                let minimizedBlurView = UIVisualEffectView(effect: nil)
                self.minimizedBlurView = minimizedBlurView
                minimizedBlurView.frame = self.bounds
                minimizedBlurView.isHidden = true
                self.view.addSubview(minimizedBlurView)
            }
            if self.minimizedArrowView == nil {
                let minimizedArrowView = TGEmbedPIPPullArrowView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 8.0, height: 38.0)))
                minimizedArrowView.alpha = 0.0
                self.minimizedArrowView = minimizedArrowView
                self.minimizedBlurView?.contentView.addSubview(minimizedArrowView)
            }
            if let minimizedArrowView = self.minimizedArrowView {
                setupArrowFrame(size: self.bounds.size, edge: edge, view: minimizedArrowView)
                minimizedArrowView.setAngled(!adjusting, animated: true)
            }
        }
        
        let effect: UIBlurEffect? = edge != nil ? UIBlurEffect(style: .light) : nil
        if true {
            if let edge = edge {
                self.minimizedBlurView?.isHidden = false
                
                switch edge {
                    case .left:
                        break
                    case .right:
                        break
                }
            }
            
            UIView.animate(withDuration: 0.35, animations: {
                self.minimizedBlurView?.effect = effect
                self.minimizedArrowView?.alpha = edge != nil ? 1.0 : 0.0;
            }, completion: { [weak self] finished in
                if let strongSelf = self {
                    if finished && edge == nil {
                        strongSelf.minimizedBlurView?.isHidden = true
                    }
                }
            })
        } else {
            self.minimizedBlurView?.effect = effect;
            self.minimizedBlurView?.isHidden = edge == nil
            self.minimizedArrowView?.alpha = edge != nil ? 1.0 : 0.0
        }
    }
}
