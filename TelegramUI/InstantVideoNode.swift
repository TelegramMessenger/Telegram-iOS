import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private final class SharedInstantVideoContext: SharedVideoContext {
    let player: MediaPlayer
    let playerNode: MediaPlayerNode
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    init(audioSessionManager: ManagedAudioSession, postbox: Postbox, resource: MediaResource) {
        self.player = MediaPlayer(audioSessionManager: audioSessionManager, postbox: postbox, resource: resource, streamable: false, video: true, preferSoftwareDecoding: false, enableSound: false)
        var actionAtEndImpl: (() -> Void)?
        self.player.actionAtEnd = .loopDisablingSound({
            actionAtEndImpl?()
        })
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
            self.player.playOnceWithSound(playAndRecord: true)
        } else {
            self.player.continuePlayingWithoutSound()
        }
    }
    
    func setForceAudioToSpeaker(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        self.player.setForceAudioToSpeaker(value)
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

enum InstantVideoNodeSource {
    case messageMedia(stableId: AnyHashable, file: TelegramMediaFile)
    
    fileprivate var id: AnyHashable {
        switch self {
            case let .messageMedia(stableId, _):
                return stableId
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

private let backgroundImage = UIImage(bundleImageName: "Chat/Message/OverlayInstantVideoShadow")?.precomposed()

final class InstantVideoNode: OverlayMediaItemNode {
    private let manager: MediaManager
    private let source: InstantVideoNodeSource
    private let priority: Int32
    private let withSound: Bool
    private let postbox: Postbox
    
    private var soundEnabled: Bool
    private var forceAudioToSpeaker: Bool
    
    private var contextId: Int32?
    
    private var context: SharedInstantVideoContext?
    private var contextPlaybackEndedIndex: Int?
    private var validLayout: CGSize?
    
    private var theme: PresentationTheme
    
    private let backgroundNode: ASImageNode
    private let imageNode: TransformImageNode
    private var snapshotView: UIView?
    private let progressNode: RadialProgressNode
    
    private var statusDisposable: Disposable?
    
    var playbackEnded: (() -> Void)?
    var tapped: (() -> Void)?
    var dismissed: (() -> Void)?
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    override var group: OverlayMediaItemNodeGroup? {
        return OverlayMediaItemNodeGroup(rawValue: 0)
    }
    
    override var tempExtendedTopInset: Bool {
        return true
    }
    
    init(theme: PresentationTheme, manager: MediaManager, postbox: Postbox, source: InstantVideoNodeSource, priority: Int32, withSound: Bool, forceAudioToSpeaker: Bool) {
        self.theme = theme
        self.manager = manager
        self.source = source
        self.priority = priority
        self.withSound = withSound
        self.forceAudioToSpeaker = forceAudioToSpeaker
        self.soundEnabled = withSound
        self.postbox = postbox
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: theme.chat.bubble.mediaOverlayControlBackgroundColor, foregroundColor: theme.chat.bubble.mediaOverlayControlForegroundColor, icon: nil))
        
        super.init()
        
        self.backgroundNode.image = backgroundImage
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.imageNode)
        
        self.imageNode.setSignal(chatMessageVideo(postbox: postbox, video: source.file))
        
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { [weak self] context in
            if let strongSelf = self, let context = context as? SharedInstantVideoContext {
                context.addPlaybackCompleted {
                    if let strongSelf = self {
                        strongSelf.playbackEnded?()
                    }
                }
            }
        })
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
    
    private func updateContext(_ context: SharedInstantVideoContext?) {
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
                if let snapshotView = previous.playerNode.view.snapshotView(afterScreenUpdates: false) {
                    self.snapshotView = snapshotView
                    snapshotView.frame = self.imageNode.frame
                    self.view.addSubview(snapshotView)
                }
                if previous.playerNode.supernode === self {
                    previous.playerNode.removeFromSupernode()
                }
            }
            if let context = context {
                self.contextPlaybackEndedIndex = context.addPlaybackCompleted { [weak self] in
                    self?.playbackEnded?()
                }
                if context.playerNode.supernode !== self {
                    self.addSubnode(context.playerNode)
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
    
    override func updateLayout(_ size: CGSize) {
        if size != self.validLayout {
            self.updateLayoutImpl(size)
        }
    }
        
    private func updateLayoutImpl(_ size: CGSize) {
        self.validLayout = size
        
        let arguments = TransformImageArguments(corners: ImageCorners(radius: size.width / 2.0), imageSize: CGSize(width: size.width + 2.0, height: size.height + 2.0), boundingSize: size, intrinsicInsets: UIEdgeInsets())
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
    }
    
    func play() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedInstantVideoContext {
                context.play()
            }
        })
    }
    
    func pause() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedInstantVideoContext {
                context.pause()
            }
        })
    }
    
    func togglePlayPause() {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedInstantVideoContext {
                context.togglePlayPause()
            }
        })
    }
    
    func setSoundEnabled(_ value: Bool) {
        self.soundEnabled = value
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedInstantVideoContext {
                context.setSoundEnabled(value)
            }
        })
    }
    
    func setForceAudioToSpeaker(_ value: Bool) {
        self.forceAudioToSpeaker = value
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedInstantVideoContext {
                context.setForceAudioToSpeaker(value)
            }
        })
    }
    
    func seek(_ timestamp: Double) {
        self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
            if let context = context as? SharedInstantVideoContext {
                context.seek(timestamp)
            }
        })
    }
    
    override func setShouldAcquireContext(_ value: Bool) {
        if value {
            if self.contextId == nil {
                self.contextId = self.manager.sharedVideoContextManager.attachSharedVideoContext(id: source.id, priority: self.priority, create: {
                    let context = SharedInstantVideoContext(audioSessionManager: manager.audioSession, postbox: self.postbox, resource: self.source.resource)
                    context.setSoundEnabled(self.soundEnabled)
                    context.setForceAudioToSpeaker(self.forceAudioToSpeaker)
                    context.play()
                    return context
                }, update: { [weak self] context in
                    if let strongSelf = self {
                        strongSelf.updateContext(context as? SharedInstantVideoContext)
                    }
                })
            }
        } else if let contextId = self.contextId {
            self.manager.sharedVideoContextManager.detachSharedVideoContext(id: self.source.id, index: contextId)
            self.contextId = nil
        }
        
        if !self.initializedStatus {
            self.manager.sharedVideoContextManager.withSharedVideoContext(id: self.source.id, { context in
                if let context = context as? SharedInstantVideoContext {
                    self.initializedStatus = true
                    self._status.set(context.player.status)
                }
            })
        }
    }
    
    override func preferredSizeForOverlayDisplay() -> CGSize {
        return CGSize(width: 124.0, height: 124.0)
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    override func dismiss() {
        self.dismissed?()
    }
}
