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

private final class SharedTelegramVideoContext: SharedVideoContext {
    let player: MediaPlayer
    let playerNode: MediaPlayerNode
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    init(audioSessionManager: ManagedAudioSession, postbox: Postbox, resource: MediaResource) {
        self.player = MediaPlayer(audioSessionManager: audioSessionManager, postbox: postbox, resource: resource, streamable: false, video: true, preferSoftwareDecoding: false, enableSound: false)
        var actionAtEndImpl: (() -> Void)?
        self.player.actionAtEnd = .stop
        self.playerNode = MediaPlayerNode(backgroundThread: false)
        self.player.attachPlayerNode(self.playerNode)
        
        super.init()
        
        actionAtEndImpl = { [weak self] in
            if let strongSelf = self {
                for listener in strongSelf.playbackCompletedListeners.copyItems() {
                    listener()
                }
            }
        }
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        self.player.play()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.togglePlayPause()
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if value {
            self.player.playOnceWithSound(playAndRecord: false)
        } else {
            self.player.continuePlayingWithoutSound()
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.player.seek(timestamp: timestamp)
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
}

enum TelegramVideoNodeSource {
    case messageMedia(stableId: UInt32, file: TelegramMediaFile)
    
    fileprivate var id: TelegramVideoNodeMessageMediaId {
        switch self {
        case let .messageMedia(stableId, _):
            return TelegramVideoNodeMessageMediaId(stableId: stableId)
        }
    }
    
    fileprivate var resource: MediaResource {
        switch self {
        case let .messageMedia(_, file):
            return file.resource
        }
    }
    
    fileprivate var file: TelegramMediaFile {
        switch self {
        case let .messageMedia(_, file):
            return file
        }
    }
}

private struct TelegramVideoNodeMessageMediaId: Hashable {
    let stableId: UInt32
    
    static func ==(lhs: TelegramVideoNodeMessageMediaId, rhs: TelegramVideoNodeMessageMediaId) -> Bool {
        return lhs.stableId == rhs.stableId
    }
    
    var hashValue: Int {
        return self.stableId.hashValue
    }
}

private let backgroundImage = UIImage(bundleImageName: "Chat/Message/OverlayPlainVideoShadow")?.precomposed().resizableImage(withCapInsets: UIEdgeInsets(top: 22.0, left: 25.0, bottom: 26.0, right: 25.0), resizingMode: .stretch)

final class TelegramVideoNode: OverlayMediaItemNode {
    private let manager: MediaManager
    private let source: TelegramVideoNodeSource
    private let priority: Int32
    private let withSound: Bool
    private let postbox: Postbox
    
    private var soundEnabled: Bool
    
    private var contextId: Int32?
    
    private var context: SharedTelegramVideoContext?
    private var contextPlaybackEndedIndex: Int?
    private var validLayout: CGSize?
    
    private let backgroundNode: ASImageNode
    private let imageNode: TransformImageNode
    private var snapshotView: UIView?
    private let progressNode: RadialProgressNode
    private let controlsNode: PictureInPictureVideoControlsNode?
    private var minimizedBlurView: UIVisualEffectView?
    private var minimizedArrowView: TGEmbedPIPPullArrowView?
    private var minimizedEdge: OverlayMediaItemMinimizationEdge?
    
    private var statusDisposable: Disposable?
    
    var playbackEnded: (() -> Void)?
    var tapped: (() -> Void)?
    var dismissed: (() -> Void)?
    var unembed: (() -> Void)?
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    override var group: OverlayMediaItemNodeGroup? {
        return OverlayMediaItemNodeGroup(rawValue: 0)
    }
    
    let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    override var isMinimizeable: Bool {
        return true
    }
    
    init(manager: MediaManager, account: Account, source: TelegramVideoNodeSource, priority: Int32, withSound: Bool, withOverlayControls: Bool = false) {
        self.manager = manager
        self.source = source
        self.priority = priority
        self.withSound = withSound
        self.soundEnabled = withSound
        self.postbox = account.postbox
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(white: 0.0, alpha: 0.6), foregroundColor: UIColor(white: 1.0, alpha: 1.0), icon: nil))
        
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
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        if let controlsNode = self.controlsNode {
            self.addSubnode(controlsNode)
        }
        
        self.imageNode.setSignal(chatMessageVideo(postbox: account.postbox, video: source.file))
    }
    
    deinit {
        if let context = self.context {
            if context.playerNode.supernode === self {
                context.playerNode.removeFromSupernode()
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
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    private func updateContext(_ context: SharedTelegramVideoContext?) {
        assert(Queue.mainQueue().isCurrent())
        
        let previous = self.context
        self.context = context
        if previous !== context {
            if let snapshotView = self.snapshotView {
                snapshotView.removeFromSuperview()
                self.snapshotView = nil
            }
            if let previous = previous {
                if let contextPlaybackEndedIndex = self.contextPlaybackEndedIndex {
                    previous.removePlaybackCompleted(contextPlaybackEndedIndex)
                }
                self.contextPlaybackEndedIndex = nil
                /*if let snapshotView = previous.playerNode.view.snapshotView(afterScreenUpdates: false) {
                    self.snapshotView = snapshotView
                    snapshotView.frame = self.imageNode.frame
                    self.view.addSubview(snapshotView)
                }*/
                if previous.playerNode.supernode === self {
                    previous.playerNode.removeFromSupernode()
                }
            }
            if let context = context {
                self.contextPlaybackEndedIndex = context.addPlaybackCompleted { [weak self] in
                    self?.playbackEnded?()
                }
                if context.playerNode.supernode !== self {
                    if let controlsNode = self.controlsNode {
                        self.insertSubnode(context.playerNode, belowSubnode: controlsNode)
                    } else {
                        self.addSubnode(context.playerNode)
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
        self.imageNode.isHidden = !self.hasAttachedContext
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
            context.playerNode.transformArguments = arguments
            context.playerNode.frame = videoFrame
        }
        
        let backgroundInsets = UIEdgeInsets(top: 2.0, left: 3.0, bottom: 4.0, right: 3.0)
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: -backgroundInsets.left, y: -backgroundInsets.top), size: CGSize(width: videoFrame.size.width + backgroundInsets.left + backgroundInsets.right, height: videoFrame.size.height + backgroundInsets.top + backgroundInsets.bottom))
        
        self.imageNode.asyncLayout()(arguments)()
        self.imageNode.frame = videoFrame
        self.snapshotView?.frame = self.imageNode.frame
        
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
            if let context = context as? SharedTelegramVideoContext {
                context.play()
            }
        })
    }
    
    func pause() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedTelegramVideoContext {
                context.pause()
            }
        })
    }
    
    func togglePlayPause() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedTelegramVideoContext {
                context.togglePlayPause()
            }
        })
    }
    
    func setSoundEnabled(_ value: Bool) {
        self.soundEnabled = value
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedTelegramVideoContext {
                context.setSoundEnabled(value)
            }
        })
    }
    
    func seek(_ timestamp: Double) {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedTelegramVideoContext {
                context.seek(timestamp)
            }
        })
    }
    
    override func setShouldAcquireContext(_ value: Bool) {
        if value {
            if self.contextId == nil {
                self.contextId = self.manager.sharedVideoContextManager.attachSharedVideoContext(id: source.id, priority: self.priority, create: {
                    let context = SharedTelegramVideoContext(audioSessionManager: manager.audioSession, postbox: self.postbox, resource: self.source.resource)
                    context.setSoundEnabled(self.soundEnabled)
                    //context.play()
                    return context
                }, update: { [weak self] context in
                    if let strongSelf = self {
                        strongSelf.updateContext(context as? SharedTelegramVideoContext)
                    }
                })
            }
        } else if let contextId = self.contextId {
            self.manager.sharedVideoContextManager.detachSharedVideoContext(id: self.source.id, index: contextId)
            self.contextId = nil
        }
        
        if !self.initializedStatus {
            self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
                if let context = context as? SharedTelegramVideoContext {
                    self.initializedStatus = true
                    self._status.set(context.player.status)
                    self.controlsNode?.status = context.player.status
                }
            })
        }
    }
    
    override func preferredSizeForOverlayDisplay() -> CGSize {
        switch self.source {
            case let .messageMedia(_, file):
                if let dimensions = file.dimensions {
                    return dimensions.aspectFitted(CGSize(width: 300.0, height: 300.0))
                }
        }
        return CGSize(width: 100.0, height: 100.0)
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
