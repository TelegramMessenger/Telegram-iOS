import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class ChatBubbleInstantVideoDecoration: UniversalVideoDecoration {
    let backgroundNode: ASDisplayNode?
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode?
    
    private let tapped: () -> Void
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    init(diameter: CGFloat, backgroundImage: UIImage?, tapped: @escaping () -> Void) {
        self.tapped = tapped
        
        let backgroundNode = ASImageNode()
        backgroundNode.isLayerBacked = true
        backgroundNode.displaysAsynchronously = false
        backgroundNode.displayWithoutProcessing = true
        backgroundNode.image = backgroundImage
        self.backgroundNode = backgroundNode
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.clipsToBounds = true
        self.contentContainerNode.cornerRadius = (diameter - 3.0) / 2.0
        
        let foregroundNode = ASDisplayNode()
        self.foregroundNode = foregroundNode
        //foregroundNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
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
        let contentFrame = CGRect(origin: CGPoint(x: 1.5, y: 1.5), size: CGSize(width: size.width - 3.0, height: size.height - 3.0))
        transition.updateFrame(node: self.contentContainerNode, frame: contentFrame)
        self.contentContainerNode.subnodeTransform = CATransform3DMakeScale((contentFrame.width + 2.0) / contentFrame.width, (contentFrame.width + 2.0) / contentFrame.width, 1.0)
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            //self.tapped()
        }
    }
    
    func tap() {
        self.tapped()
    }
}
