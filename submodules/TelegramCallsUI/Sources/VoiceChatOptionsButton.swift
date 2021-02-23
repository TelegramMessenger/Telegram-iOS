import Foundation
import UIKit
import AsyncDisplayKit
import Display

func optionsBackgroundImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 14, topCapHeight: 14)
}

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
    
    var textNode: ImmediateTextNode?
    var dotNode: ASImageNode?
    
    init(rec: Bool = false) {
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.isGestureEnabled = false
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.contentMode = .scaleToFill
        
        if rec {
            self.textNode = ImmediateTextNode()
            self.textNode?.attributedText = NSAttributedString(string: "REC", font: Font.regular(12.0), textColor: .white)
            if let textNode = self.textNode {
                let textSize = textNode.updateLayout(CGSize(width: 58.0, height: 28.0))
                textNode.frame = CGRect(origin: CGPoint(), size: textSize)
            }
            self.dotNode = ASImageNode()
            self.dotNode?.displaysAsynchronously = false
            self.dotNode?.displayWithoutProcessing = true
            self.dotNode?.image = generateFilledCircleImage(diameter: 8.0, color: UIColor(rgb: 0xff3b30))
        }
        
        super.init()
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.iconNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.addSubnode(self.containerNode)
        
        if rec, let textNode = self.textNode, let dotNode = self.dotNode {
            self.extractedContainerNode.contentNode.addSubnode(textNode)
            self.extractedContainerNode.contentNode.addSubnode(dotNode)
        }
        
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
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: rec ? 58.0 : 28.0, height: 28.0))
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
        
        if let dotNode = self.dotNode {
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.0 as NSNumber]
            animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
            animation.duration = 0.5
            animation.autoreverses = true
            animation.repeatCount = Float.infinity
            dotNode.layer.add(animation, forKey: "recording")
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: self.dotNode != nil ? 58.0 : 28.0, height: 28.0)
    }
    
    override func layout() {
        super.layout()
        
        if let dotNode = self.dotNode, let textNode = self.textNode {
            dotNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: CGSize(width: 8.0, height: 8.0))
            textNode.frame = CGRect(origin: CGPoint(x: 22.0, y: 7.0), size: textNode.frame.size)
        }
    }
    
    func onLayout() {
    }
}
