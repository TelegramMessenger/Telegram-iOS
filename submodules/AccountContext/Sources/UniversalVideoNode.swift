import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Display
import TelegramAudio
import UniversalMediaPlayer
import AVFoundation
import RangeSet

public protocol UniversalVideoContentNode: AnyObject {
    var ready: Signal<Void, NoError> { get }
    var status: Signal<MediaPlayerStatus, NoError> { get }
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> { get }
        
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    
    func play()
    func pause()
    func togglePlayPause()
    func setSoundEnabled(_ value: Bool)
    func seek(_ timestamp: Double)
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd)
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool)
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd)
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool)
    func setBaseRate(_ baseRate: Double)
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int
    func removePlaybackCompleted(_ index: Int)
    func fetchControl(_ control: UniversalVideoNodeFetchControl)
    func notifyPlaybackControlsHidden(_ hidden: Bool)
    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool)
}

public protocol UniversalVideoContent {
    var id: AnyHashable { get }
    var dimensions: CGSize { get }
    var duration: Int32 { get }
    
    func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode
    
    func isEqual(to other: UniversalVideoContent) -> Bool
}

public extension UniversalVideoContent {
    func isEqual(to other: UniversalVideoContent) -> Bool {
        return false
    }
}

public protocol UniversalVideoDecoration: AnyObject {
    var backgroundNode: ASDisplayNode? { get }
    var contentContainerNode: ASDisplayNode { get }
    var foregroundNode: ASDisplayNode? { get }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>)
    
    func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?)
    func updateContentNodeSnapshot(_ snapshot: UIView?)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    func tap()
}

public enum UniversalVideoPriority: Int32, Comparable {
    case minimal = 0
    case secondaryOverlay = 1
    case embedded = 2
    case gallery = 3
    case overlay = 4
    
    public static func <(lhs: UniversalVideoPriority, rhs: UniversalVideoPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public enum UniversalVideoNodeFetchControl {
    case fetch
    case cancel
}

public final class UniversalVideoNode: ASDisplayNode {
    private let postbox: Postbox
    private let audioSession: ManagedAudioSession
    private let manager: UniversalVideoManager
    private let content: UniversalVideoContent
    private let priority: UniversalVideoPriority
    public let decoration: UniversalVideoDecoration
    private let autoplay: Bool
    private let snapshotContentWhenGone: Bool
    
    private var contentNode: (UniversalVideoContentNode & ASDisplayNode)?
    private var contentNodeId: Int32?
    
    private var playbackCompletedIndex: Int?
    private var contentRequestIndex: (AnyHashable, Int32)?
    
    public var playbackCompleted: (() -> Void)?
    
    public private(set) var ownsContentNode: Bool = false
    public var ownsContentNodeUpdated: ((Bool) -> Void)?
    
    private let _status = Promise<MediaPlayerStatus?>()
    public var status: Signal<MediaPlayerStatus?, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    public var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    public var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    public var canAttachContent: Bool = false {
        didSet {
            if self.canAttachContent != oldValue {
                if self.canAttachContent {
                    assert(self.contentRequestIndex == nil)
                    
                    let content = self.content
                    let postbox = self.postbox
                    let audioSession = self.audioSession
                    self.contentRequestIndex = self.manager.attachUniversalVideoContent(content: self.content, priority: self.priority, create: {
                        return content.makeContentNode(postbox: postbox, audioSession: audioSession)
                    }, update: { [weak self] contentNodeAndFlags in
                        if let strongSelf = self {
                            strongSelf.updateContentNode(contentNodeAndFlags)
                        }
                    })
                } else {
                    assert(self.contentRequestIndex != nil)
                    if let (id, index) = self.contentRequestIndex {
                        self.contentRequestIndex = nil
                        self.manager.detachUniversalVideoContent(id: id, index: index)
                    }
                }
            }
        }
    }
    
    public var hasAttachedContext: Bool {
        return self.contentNode != nil
    }
    
    public init(postbox: Postbox, audioSession: ManagedAudioSession, manager: UniversalVideoManager, decoration: UniversalVideoDecoration, content: UniversalVideoContent, priority: UniversalVideoPriority, autoplay: Bool = false, snapshotContentWhenGone: Bool = false) {
        self.postbox = postbox
        self.audioSession = audioSession
        self.manager = manager
        self.content = content
        self.priority = priority
        self.decoration = decoration
        self.autoplay = autoplay
        self.snapshotContentWhenGone = snapshotContentWhenGone
        
        super.init()
        
        self.playbackCompletedIndex = self.manager.addPlaybackCompleted(id: self.content.id, { [weak self] in
            self?.playbackCompleted?()
        })
        
        self._status.set(self.manager.statusSignal(content: self.content))
        self._bufferingStatus.set(self.manager.bufferingStatusSignal(content: self.content))
        
        self.decoration.setStatus(self.status)
        
        if let backgroundNode = self.decoration.backgroundNode {
            self.addSubnode(backgroundNode)
        }
        
        self.addSubnode(self.decoration.contentContainerNode)
        
        if let foregroundNode = self.decoration.foregroundNode {
            self.addSubnode(foregroundNode)
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        
        if let playbackCompletedIndex = self.playbackCompletedIndex {
            self.manager.removePlaybackCompleted(id: self.content.id, index: playbackCompletedIndex)
        }
        
        if let (id, index) = self.contentRequestIndex {
            self.contentRequestIndex = nil
            self.manager.detachUniversalVideoContent(id: id, index: index)
        }
    }
    
    private func updateContentNode(_ contentNode: ((UniversalVideoContentNode & ASDisplayNode), Bool)?) {
        let previous = self.contentNode
        self.contentNode = contentNode?.0
        if previous !== contentNode?.0 {
            if let previous = previous, contentNode?.0 == nil && self.snapshotContentWhenGone {
                if let snapshotView = previous.view.snapshotView(afterScreenUpdates: false) {
                    self.decoration.updateContentNodeSnapshot(snapshotView)
                }
            }
            if let (contentNode, initiatedCreation) = contentNode {
                contentNode.layer.removeAllAnimations()
                self._ready.set(contentNode.ready)
                if initiatedCreation && self.autoplay {
                    self.play()
                }
            }
            if contentNode?.0 != nil && self.snapshotContentWhenGone {
                self.decoration.updateContentNodeSnapshot(nil)
            }
            self.decoration.updateContentNode(contentNode?.0)
            
            let ownsContentNode = contentNode?.0 !== nil
            if self.ownsContentNode != ownsContentNode {
                self.ownsContentNode = ownsContentNode
                self.ownsContentNodeUpdated?(ownsContentNode)
            }
        }
        
        if contentNode == nil {
            self._ready.set(.single(Void()))
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.decoration.updateLayout(size: size, transition: transition)
    }
    
    public func play() {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.play()
            }
        })
    }
    
    public func pause() {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.pause()
            }
        })
    }
    
    public func togglePlayPause() {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.togglePlayPause()
            }
        })
    }
    
    public func setSoundEnabled(_ value: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setSoundEnabled(value)
            }
        })
    }
    
    public func seek(_ timestamp: Double) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.seek(timestamp)
            }
        })
    }
    
    public func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek = .start, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd = .loopDisablingSound) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.playOnceWithSound(playAndRecord: playAndRecord, seek: seek, actionAtEnd: actionAtEnd)
            }
        })
    }
    
    public func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setContinuePlayingWithoutSoundOnLostAudioSession(value)
            }
        })
    }
    
    public func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setForceAudioToSpeaker(forceAudioToSpeaker)
            }
        })
    }
    
    public func setBaseRate(_ baseRate: Double) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setBaseRate(baseRate)
            }
        })
    }
    
    public func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd = .loopDisablingSound) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.continuePlayingWithoutSound(actionAtEnd: actionAtEnd)
            }
        })
    }
    
    public func fetchControl(_ control: UniversalVideoNodeFetchControl) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.fetchControl(control)
            }
        })
    }
    
    public func notifyPlaybackControlsHidden(_ hidden: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.notifyPlaybackControlsHidden(hidden)
            }
        })
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.decoration.tap()
        }
    }

    public func getVideoLayer() -> AVSampleBufferDisplayLayer? {
        guard let contentNode = self.contentNode else {
            return nil
        }

        func findVideoLayer(layer: CALayer) -> AVSampleBufferDisplayLayer? {
            if let layer = layer as? AVSampleBufferDisplayLayer {
                return layer
            }

            if let sublayers = layer.sublayers {
                for sublayer in sublayers {
                    if let result = findVideoLayer(layer: sublayer) {
                        return result
                    }
                }
            }

            return nil
        }

        return findVideoLayer(layer: contentNode.layer)
    }

    public func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setCanPlaybackWithoutHierarchy(canPlaybackWithoutHierarchy)
            }
        })
    }
}
