import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Display

protocol UniversalVideoContentNode: class {
    var status: Signal<MediaPlayerStatus, NoError> { get }
        
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    
    func play()
    func pause()
    func togglePlayPause()
    func setSoundEnabled(_ value: Bool)
    func seek(_ timestamp: Double)
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int
    func removePlaybackCompleted(_ index: Int)
}

protocol UniversalVideoContent {
    var id: AnyHashable { get }
    var dimensions: CGSize { get }
    var duration: Int32 { get }
    func makeContentNode(account: Account) -> UniversalVideoContentNode & ASDisplayNode
}

protocol UniversalVideoDecoration: class {
    var backgroundNode: ASDisplayNode? { get }
    var contentContainerNode: ASDisplayNode { get }
    var foregroundNode: ASDisplayNode? { get }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>)
    
    func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    func tap()
}

enum UniversalVideoPriority: Int32, Comparable {
    case embedded = 0
    case gallery = 1
    case overlay = 2
    
    static func <(lhs: UniversalVideoPriority, rhs: UniversalVideoPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static func ==(lhs: UniversalVideoPriority, rhs: UniversalVideoPriority) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

final class UniversalVideoNode: ASDisplayNode {
    private let account: Account
    private let manager: UniversalVideoContentManager
    private let content: UniversalVideoContent
    private let priority: UniversalVideoPriority
    private let decoration: UniversalVideoDecoration
    
    private var contentNode: (UniversalVideoContentNode & ASDisplayNode)?
    private var contentNodeId: Int32?
    
    private var playbackCompletedIndex: Int?
    private var contentRequestIndex: Int32?
    
    var playbackCompleted: (() -> Void)?
    
    private(set) var ownsContentNode: Bool = false
    var ownsContentNodeUpdated: ((Bool) -> Void)?
    
    private let _status = Promise<MediaPlayerStatus?>()
    var status: Signal<MediaPlayerStatus?, NoError> {
        return self._status.get()
    }
    
    var canAttachContent: Bool = false {
        didSet {
            if self.canAttachContent != oldValue {
                if self.canAttachContent {
                    assert(self.contentRequestIndex == nil)
                    
                    let content = self.content
                    let account = self.account
                    self.contentRequestIndex = self.manager.attachUniversalVideoContent(id: self.content.id, priority: self.priority, create: {
                        return content.makeContentNode(account: account)
                    }, update: { [weak self] contentNode in
                        if let strongSelf = self {
                            strongSelf.updateContentNode(contentNode)
                        }
                    })
                } else {
                    assert(self.contentRequestIndex != nil)
                    if let contentRequestIndex = self.contentRequestIndex {
                        self.contentRequestIndex = nil
                        self.manager.detachUniversalVideoContent(id: self.content.id, index: contentRequestIndex)
                    }
                }
            }
        }
    }
    
    init(account: Account, manager: UniversalVideoContentManager, decoration: UniversalVideoDecoration, content: UniversalVideoContent, priority: UniversalVideoPriority) {
        self.account = account
        self.manager = manager
        self.content = content
        self.priority = priority
        self.decoration = decoration
        
        super.init()
        
        self.playbackCompletedIndex = self.manager.addPlaybackCompleted(id: self.content.id, { [weak self] in
            self?.playbackCompleted?()
        })
        
        self._status.set(self.manager.statusSignal(content: self.content))
        
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
        
        if let contentRequestIndex = self.contentRequestIndex {
            self.contentRequestIndex = nil
            self.manager.detachUniversalVideoContent(id: self.content.id, index: contentRequestIndex)
        }
    }
    
    private func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
        let previous = self.contentNode
        self.contentNode = contentNode
        if previous !== contentNode {
            if let previous = previous {
                /*if let contextPlaybackEndedIndex = self.contextPlaybackEndedIndex {
                    previous.removePlaybackCompleted(contextPlaybackEndedIndex)
                }
                self.contextPlaybackEndedIndex = nil*/
                /*if let snapshotView = previous.playerNode.view.snapshotView(afterScreenUpdates: false) {
                 self.snapshotView = snapshotView
                 snapshotView.frame = self.imageNode.frame
                 self.view.addSubview(snapshotView)
                 }*/
            }
            if let contentNode = contentNode {
                /*self.contextPlaybackEndedIndex = context.addPlaybackCompleted { [weak self] in
                    self?.playbackEnded?()
                }*/
                
            }
            self.decoration.updateContentNode(contentNode)
            /*if self.hasAttachedContext != (context !== nil) {
                self.hasAttachedContext = (context !== nil)
                self.hasAttachedContextUpdated?(self.hasAttachedContext)
            }*/
            
            let ownsContentNode = contentNode !== nil
            if self.ownsContentNode != ownsContentNode {
                self.ownsContentNode = ownsContentNode
                self.ownsContentNodeUpdated?(ownsContentNode)
            }
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
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.decoration.tap()
        }
    }
}
