import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class ChatBubbleVideoDecoration: UniversalVideoDecoration {
    let backgroundNode: ASDisplayNode? = nil
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    init(cornerRadius: CGFloat) {
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.clipsToBounds = true
        self.contentContainerNode.cornerRadius = cornerRadius
    }
    
    func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
        if self.contentNode !== contentNode {
            let previous = self.contentNode
            self.contentNode = contentNode
            
            if let previous = previous {
                if previous.supernode === self.contentContainerNode {
                    previous.removeFromSupernode()
                }
            }
            
            if let contentNode = contentNode {
                if contentNode.supernode !== self.contentContainerNode {
                    self.contentContainerNode.addSubnode(contentNode)
                    if let validLayoutSize = self.validLayoutSize {
                        contentNode.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                        contentNode.updateLayout(size: validLayoutSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        }
        if let foregroundNode = self.foregroundNode {
            transition.updateFrame(node: foregroundNode, frame: CGRect(origin: CGPoint(), size: size))
        }
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    func tap() {
    }
}

