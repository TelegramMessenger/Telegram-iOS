import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private let transitionDuration = 0.2
private let animationKey = "animation"

public class ChatTitleActivityIndicatorNode: ASDisplayNode {
    public var duration: CFTimeInterval {
        return 0.0
    }
    
    public var timingFunction: CAMediaTimingFunction {
        return CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
    }
    
    public var color: UIColor? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    public var progress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    public init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = true
        self.isOpaque = false
    }
    
    deinit {
        self.stopAnimation()
    }
    
    private func startAnimation() {
        self.stopAnimation()
        
        let animation = POPBasicAnimation()
        animation.property = POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! ChatTitleActivityIndicatorNode).progress
            }
            property?.writeBlock = { node, values in
                (node as! ChatTitleActivityIndicatorNode).progress = values!.pointee
            }
            property?.threshold = 0.01
        }) as? POPAnimatableProperty
        animation.fromValue = 0.0 as NSNumber
        animation.toValue = 1.0 as NSNumber
        animation.timingFunction = self.timingFunction
        animation.duration = self.duration
        animation.repeatForever = true
        
        self.pop_add(animation, forKey: animationKey)
    }
    
    private func stopAnimation() {
        self.pop_removeAnimation(forKey: animationKey)
    }
    
    override public func didEnterHierarchy() {
        super.didEnterHierarchy()
        self.startAnimation()
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        self.stopAnimation()
    }
}

public class ChatTitleActivityContentNode: ASDisplayNode {
    public let textNode: ImmediateTextNode
    
    public init(text: NSAttributedString) {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 1
        self.textNode.isOpaque = false
        
        super.init()
        
        self.addSubnode(self.textNode)
        
        self.textNode.attributedText = text
    }
    
    func makeCopy() -> ASDisplayNode {
        let node = ASDisplayNode()
        let textNode = self.textNode.makeCopy()
        textNode.frame = self.textNode.frame
        node.addSubnode(textNode)
        node.frame = self.frame
        return node
    }
    
    public func animateOut(to: ChatTitleActivityNodeState, style: ChatTitleActivityAnimationStyle, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration, removeOnCompletion: false, completion: { _ in
            completion()
        })
        
        if case .slide = style {
            self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 14.0), duration: transitionDuration, additive: true)
        }
    }
        
    public func animateIn(from: ChatTitleActivityNodeState, style: ChatTitleActivityAnimationStyle) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: transitionDuration)
        
        if case .slide = style {
            self.layer.animatePosition(from: CGPoint(x: 0.0, y: -14.0), to: CGPoint(), duration: transitionDuration, additive: true)
        }
    }
    
    public func updateLayout(_ constrainedSize: CGSize, offset: CGFloat, alignment: NSTextAlignment) -> CGSize {
        let size = self.textNode.updateLayout(constrainedSize)
        self.textNode.bounds = CGRect(origin: CGPoint(), size: size)
        if case .center = alignment {
            self.textNode.position = CGPoint(x: 0.0, y: size.height / 2.0 + offset)
        } else {
            self.textNode.position = CGPoint(x: size.width / 2.0 + 3.0, y: size.height / 2.0 + offset)
        }
        return size
    }
}
