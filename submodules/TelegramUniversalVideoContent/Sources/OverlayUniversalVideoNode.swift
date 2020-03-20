import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import SyncCore
import Postbox
import TelegramAudio
import AccountContext

public final class OverlayUniversalVideoNode: OverlayMediaItemNode {
    private let content: UniversalVideoContent
    private let videoNode: UniversalVideoNode
    private let decoration: OverlayVideoDecoration
    
    private var validLayoutSize: CGSize?
    
    override public var group: OverlayMediaItemNodeGroup? {
        return OverlayMediaItemNodeGroup(rawValue: 0)
    }
    
    override public var isMinimizeable: Bool {
        return true
    }
    
    public var canAttachContent: Bool = true {
        didSet {
            self.videoNode.canAttachContent = self.canAttachContent
        }
    }
    
    public init(postbox: Postbox, audioSession: ManagedAudioSession, manager: UniversalVideoManager, content: UniversalVideoContent, expand: @escaping () -> Void, close: @escaping () -> Void) {
        self.content = content
        var unminimizeImpl: (() -> Void)?
        var togglePlayPauseImpl: (() -> Void)?
        var closeImpl: (() -> Void)?
        let decoration = OverlayVideoDecoration(unminimize: {
            unminimizeImpl?()
        }, togglePlayPause: {
            togglePlayPauseImpl?()
        }, expand: {
            expand()
        }, close: {
            closeImpl?()
        })
        self.videoNode = UniversalVideoNode(postbox: postbox, audioSession: audioSession, manager: manager, decoration: decoration, content: content, priority: .overlay)
        self.decoration = decoration
        
        super.init()
        
        unminimizeImpl = { [weak self] in
            self?.unminimize?()
        }
        togglePlayPauseImpl = { [weak self] in
            self?.videoNode.togglePlayPause()
        }
        closeImpl = { [weak self] in
            if let strongSelf = self {
                if strongSelf.videoNode.hasAttachedContext {
                    strongSelf.videoNode.continuePlayingWithoutSound()
                }
                strongSelf.layer.animateScale(from: 1.0, to: 0.1, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    self?.dismiss()
                    close()
                })
                strongSelf.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            }
        }

        self.clipsToBounds = true
        self.cornerRadius = 4.0
        
        self.addSubnode(self.videoNode)
        self.videoNode.ownsContentNodeUpdated = { [weak self] value in
            if let strongSelf = self {
                let previous = strongSelf.hasAttachedContext
                strongSelf.hasAttachedContext = value
                strongSelf.hasAttachedContextUpdated?(value)
                
                if previous != value {
                    if !value {
                        strongSelf.dismiss()
                        close()
                    }
                }
            }
        }
        
        self.videoNode.canAttachContent = true
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    override public func layout() {
        self.updateLayout(self.bounds.size)
    }
    
    override public func preferredSizeForOverlayDisplay(boundingSize: CGSize) -> CGSize {
        return self.content.dimensions.aspectFitted(CGSize(width: 300.0, height: 300.0))
    }
    
    override public func updateLayout(_ size: CGSize) {
        if size != self.validLayoutSize {
            self.updateLayoutImpl(size)
        }
    }
    
    private func updateLayoutImpl(_ size: CGSize) {
        self.validLayoutSize = size
        
        self.videoNode.frame = CGRect(origin: CGPoint(), size: size)
        self.videoNode.updateLayout(size: size, transition: .immediate)
    }
    
    override public func updateMinimizedEdge(_ edge: OverlayMediaItemMinimizationEdge?, adjusting: Bool) {
        self.decoration.updateMinimizedEdge(edge, adjusting: adjusting)
    }
}
