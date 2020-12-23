import Foundation
import UIKit
import AsyncDisplayKit
import Display

func optionsButtonImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 6.0, y: 12.0, width: 4.0, height: 4.0))
        context.fillEllipse(in: CGRect(x: 12.0, y: 12.0, width: 4.0, height: 4.0))
        context.fillEllipse(in: CGRect(x: 18.0, y: 12.0, width: 4.0, height: 4.0))
    })
}

func closeButtonImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
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

final class VoiceChatHeaderButton: HighlightableButtonNode {
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
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }
        
        self.iconNode.image = optionsButtonImage(dark: false)
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 28.0, height: 28.0))
        self.extractedContainerNode.frame = self.containerNode.bounds
        self.extractedContainerNode.contentRect = self.containerNode.bounds
        self.iconNode.frame = self.containerNode.bounds
    }
    
    func setImage(_ image: UIImage?, animated: Bool = false) {
        if animated, let snapshotView = self.iconNode.view.snapshotContentTree() {
            snapshotView.frame = self.iconNode.frame
            self.view.addSubview(snapshotView)
            
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
        }
        self.iconNode.image = image
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
