import Foundation
import UIKit
import AsyncDisplayKit
import Display

func optionsButtonImage() -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 6.0, y: 12.0, width: 4.0, height: 4.0))
        context.fillEllipse(in: CGRect(x: 12.0, y: 12.0, width: 4.0, height: 4.0))
        context.fillEllipse(in: CGRect(x: 18.0, y: 12.0, width: 4.0, height: 4.0))
    })
}

func closeButtonImage() -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: 0x1c1c1e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(UIColor.white.cgColor)
        
        context.move(to: CGPoint(x: 9.0, y: 9.0))
        context.addLine(to: CGPoint(x: 19.0, y: 19.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 19.0, y: 9.0))
        context.addLine(to: CGPoint(x: 9.0, y: 19.0))
        context.strokePath()
    })
}

final class VoiceChatOptionsButton: HighlightableButtonNode {
    let extractedContainerNode: ContextExtractedContentContainingNode
    let containerNode: ContextControllerSourceNode
    private let iconNode: ASImageNode
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init() {
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.isGestureEnabled = false
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init()
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.iconNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }
        
        self.iconNode.image = generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(UIColor(rgb: 0x1c1c1e).cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: 6.0, y: 12.0, width: 4.0, height: 4.0))
            context.fillEllipse(in: CGRect(x: 12.0, y: 12.0, width: 4.0, height: 4.0))
            context.fillEllipse(in: CGRect(x: 18.0, y: 12.0, width: 4.0, height: 4.0))
        })
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 28.0, height: 28.0))
        self.extractedContainerNode.frame = self.containerNode.bounds
        self.extractedContainerNode.contentRect = self.containerNode.bounds
        self.iconNode.frame = self.containerNode.bounds
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 28.0, height: 28.0)
    }
    
    func onLayout() {
    }
}
