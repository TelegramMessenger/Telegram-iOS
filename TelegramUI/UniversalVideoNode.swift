import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Display

protocol UniversalVideoContentNode: class {
    var ready: Signal<Void, NoError> { get }
    var status: Signal<MediaPlayerStatus, NoError> { get }
    var bufferingStatus: Signal<(IndexSet, Int)?, NoError> { get }
        
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
}

protocol UniversalVideoContent {
    var id: AnyHashable { get }
    var dimensions: CGSize { get }
    var duration: Int32 { get }
    
    func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode
    
    func isEqual(to other: UniversalVideoContent) -> Bool
}

extension UniversalVideoContent {
    func isEqual(to other: UniversalVideoContent) -> Bool {
        return false
    }
}

protocol UniversalVideoDecoration: class {
    var backgroundNode: ASDisplayNode? { get }
    var contentContainerNode: ASDisplayNode { get }
    var foregroundNode: ASDisplayNode? { get }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>)
    
    func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?)
    func updateContentNodeSnapshot(_ snapshot: UIView?)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    func tap()
}

enum UniversalVideoPriority: Int32, Comparable {
    case secondaryOverlay = 0
    case embedded = 1
    case gallery = 2
    case overlay = 3
    
    static func <(lhs: UniversalVideoPriority, rhs: UniversalVideoPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static func ==(lhs: UniversalVideoPriority, rhs: UniversalVideoPriority) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

enum UniversalVideoNodeFetchControl {
    case fetch
    case cancel
}

final class UniversalVideoNode: ASDisplayNode {
    private let postbox: Postbox
    private let audioSession: ManagedAudioSession
    private let manager: UniversalVideoContentManager
    private let content: UniversalVideoContent
    private let priority: UniversalVideoPriority
    let decoration: UniversalVideoDecoration
    private let autoplay: Bool
    private let snapshotContentWhenGone: Bool
    
    private var contentNode: (UniversalVideoContentNode & ASDisplayNode)?
    private var contentNodeId: Int32?
    
    private var playbackCompletedIndex: Int?
    private var contentRequestIndex: (AnyHashable, Int32)?
    
    var playbackCompleted: (() -> Void)?
    
    private(set) var ownsContentNode: Bool = false
    var ownsContentNodeUpdated: ((Bool) -> Void)?
    
    private let _status = Promise<MediaPlayerStatus?>()
    var status: Signal<MediaPlayerStatus?, NoError> {
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
    
    var canAttachContent: Bool = false {
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
    
    var hasAttachedContext: Bool {
        return self.contentNode != nil
    }
    
    init(postbox: Postbox, audioSession: ManagedAudioSession, manager: UniversalVideoContentManager, decoration: UniversalVideoDecoration, content: UniversalVideoContent, priority: UniversalVideoPriority, autoplay: Bool = false, snapshotContentWhenGone: Bool = false) {
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
    
    override func didLoad() {
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
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.decoration.updateLayout(size: size, transition: transition)
    }
    
    func play() {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.play()
            }
        })
    }
    
    func pause() {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.pause()
            }
        })
    }
    
    func togglePlayPause() {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.togglePlayPause()
            }
        })
    }
    
    func setSoundEnabled(_ value: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setSoundEnabled(value)
            }
        })
    }
    
    func seek(_ timestamp: Double) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.seek(timestamp)
            }
        })
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek = .start, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd = .loopDisablingSound) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.playOnceWithSound(playAndRecord: playAndRecord, seek: seek, actionAtEnd: actionAtEnd)
            }
        })
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setContinuePlayingWithoutSoundOnLostAudioSession(value)
            }
        })
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setForceAudioToSpeaker(forceAudioToSpeaker)
            }
        })
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.setBaseRate(baseRate)
            }
        })
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd = .loopDisablingSound) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.continuePlayingWithoutSound(actionAtEnd: actionAtEnd)
            }
        })
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
        self.manager.withUniversalVideoContent(id: self.content.id, { contentNode in
            if let contentNode = contentNode {
                contentNode.fetchControl(control)
            }
        })
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.decoration.tap()
        }
    }
}
