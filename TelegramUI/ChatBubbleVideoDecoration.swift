import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class ChatBubbleVideoDecoration: UniversalVideoDecoration {
    private let nativeSize: CGSize
    
    let backgroundNode: ASDisplayNode? = nil
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    init(cornerRadius: CGFloat, nativeSize: CGSize, backgroudColor: UIColor) {
        self.nativeSize = nativeSize
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = backgroudColor
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
                    if let size = self.validLayoutSize {
                        var scaledSize = self.nativeSize.aspectFitted(size)
                        if abs(scaledSize.width - size.width) < 2.0 {
                            scaledSize.width = size.width
                        }
                        if abs(scaledSize.height - size.height) < 2.0 {
                            scaledSize.height = size.height
                        }
                        
                        contentNode.frame = CGRect(origin: CGPoint(x: floor((size.width - scaledSize.width) / 2.0), y: floor((size.height - scaledSize.height) / 2.0)), size: scaledSize)
                        contentNode.updateLayout(size: scaledSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    func updateContentNodeSnapshot(_ snapshot: UIView?) {
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
            var scaledSize = self.nativeSize.aspectFitted(size)
            if abs(scaledSize.width - size.width) < 2.0 {
                scaledSize.width = size.width
            }
            if abs(scaledSize.height - size.height) < 2.0 {
                scaledSize.height = size.height
            }
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor((size.width - scaledSize.width) / 2.0), y: floor((size.height - scaledSize.height) / 2.0)), size: scaledSize))
            contentNode.updateLayout(size: scaledSize, transition: transition)
        }
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    func tap() {
    }
}

