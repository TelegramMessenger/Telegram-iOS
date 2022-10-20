import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import UniversalMediaPlayer
import AccountContext

public final class ChatBubbleInstantVideoDecoration: UniversalVideoDecoration {
    public let backgroundNode: ASDisplayNode?
    public let contentContainerNode: ASDisplayNode
    public let foregroundNode: ASDisplayNode?
    
    private let tapped: () -> Void
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    private let inset: CGFloat
    
    private var validLayoutSize: CGSize?
    
    public init(inset: CGFloat, backgroundImage: UIImage?, tapped: @escaping () -> Void) {
        self.inset = inset
        self.tapped = tapped
        
        let backgroundNode = ASImageNode()
        backgroundNode.isLayerBacked = true
        backgroundNode.displaysAsynchronously = false
        backgroundNode.displayWithoutProcessing = true
        backgroundNode.image = backgroundImage
        self.backgroundNode = backgroundNode
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.clipsToBounds = true
        
        let foregroundNode = ASDisplayNode()
        self.foregroundNode = foregroundNode
        //foregroundNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
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
    
    public func updateContentNodeSnapshot(_ snapshot: UIView?) {
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let diameter = size.width + inset
        self.contentContainerNode.cornerRadius = (diameter - 3.0) / 2.0
        
        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        }
        if let foregroundNode = self.foregroundNode {
            transition.updateFrame(node: foregroundNode, frame: CGRect(origin: CGPoint(), size: size))
        }
        let contentFrame = CGRect(origin: CGPoint(x: 1.5, y: 1.5), size: CGSize(width: size.width - 3.0, height: size.height - 3.0))
        transition.updateFrame(node: self.contentContainerNode, frame: contentFrame)
        self.contentContainerNode.subnodeTransform = CATransform3DMakeScale((contentFrame.width + 2.0) / contentFrame.width, (contentFrame.width + 2.0) / contentFrame.width, 1.0)
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    public func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            //self.tapped()
        }
    }
    
    public func tap() {
        self.tapped()
    }
}
