import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class VoiceChatIndicatorNode: ASDisplayNode {
    private let leftLine: ASDisplayNode
    private let centerLine: ASDisplayNode
    private let rightLine: ASDisplayNode
    
    private var isCurrentlyInHierarchy = true
    
    public var color: UIColor = UIColor(rgb: 0xffffff) {
        didSet {
            self.leftLine.backgroundColor = self.color
            self.centerLine.backgroundColor = self.color
            self.rightLine.backgroundColor = self.color
        }
    }
    
    override public init() {
        self.leftLine = ASDisplayNode()
        self.leftLine.clipsToBounds = true
        self.leftLine.isLayerBacked = true
        self.leftLine.cornerRadius = 1.0
        self.leftLine.frame = CGRect(x: 6.0, y: 6.0, width: 2.0, height: 10.0)
        
        self.centerLine = ASDisplayNode()
        self.centerLine.clipsToBounds = true
        self.centerLine.isLayerBacked = true
        self.centerLine.cornerRadius = 1.0
        self.centerLine.frame = CGRect(x: 10.0, y: 5.0, width: 2.0, height: 12.0)
        
        self.rightLine = ASDisplayNode()
        self.rightLine.clipsToBounds = true
        self.rightLine.isLayerBacked = true
        self.rightLine.cornerRadius = 1.0
        self.rightLine.frame = CGRect(x: 14.0, y: 6.0, width: 2.0, height: 10.0)
        
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.leftLine)
        self.addSubnode(self.centerLine)
        self.addSubnode(self.rightLine)
        
        if Thread.isMainThread {
            self.updateAnimation()
        }
    }
    
    override public func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        if self.isCurrentlyInHierarchy {
            if let _ = self.leftLine.layer.animation(forKey: "animation") {
            } else {
                let timingFunctions: [CAMediaTimingFunction] = (0 ..< 5).map { _ in CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut) }
                
                let leftAnimation = CAKeyframeAnimation(keyPath: "bounds.size.height")
                leftAnimation.timingFunctions = timingFunctions
                leftAnimation.values = [NSNumber(value: 10.0), NSNumber(value: 4.0), NSNumber(value: 8.0), NSNumber(value: 4.0), NSNumber(value: 10.0)]
                leftAnimation.repeatCount = Float.infinity
                leftAnimation.duration = 2.2
                leftAnimation.beginTime = 1.0
                self.leftLine.layer.add(leftAnimation, forKey: "animation")

                let centerAnimation = CAKeyframeAnimation(keyPath: "bounds.size.height")
                centerAnimation.timingFunctions = timingFunctions
                centerAnimation.values = [NSNumber(value: 6.0), NSNumber(value: 10.0), NSNumber(value: 4.0), NSNumber(value: 12.0), NSNumber(value: 6.0)]
                centerAnimation.repeatCount = Float.infinity
                centerAnimation.duration = 2.2
                centerAnimation.beginTime = 1.0
                self.centerLine.layer.add(centerAnimation, forKey: "animation")
                
                let rightAnimation = CAKeyframeAnimation(keyPath: "bounds.size.height")
                rightAnimation.timingFunctions = timingFunctions
                rightAnimation.values = [NSNumber(value: 10.0), NSNumber(value: 4.0), NSNumber(value: 8.0), NSNumber(value: 4.0), NSNumber(value: 10.0)]
                rightAnimation.repeatCount = Float.infinity
                rightAnimation.duration = 2.2
                rightAnimation.beginTime = 1.0
                self.rightLine.layer.add(rightAnimation, forKey: "animation")
            }
        } else {
            self.leftLine.layer.removeAnimation(forKey: "animation")
            self.centerLine.layer.removeAnimation(forKey: "animation")
            self.rightLine.layer.removeAnimation(forKey: "animation")
        }
    }
}

public final class PeerOnlineMarkerNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private var animationNode: VoiceChatIndicatorNode?
    
    private var color: UIColor = UIColor(rgb: 0xffffff) {
        didSet {
            self.animationNode?.color = self.color
        }
    }
    
    override public init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isHidden = true
    
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.iconNode)
    }
    
    public func setImage(_ image: UIImage?, color: UIColor?, transition: ContainedViewLayoutTransition) {
        if case let .animated(duration, curve) = transition, !self.iconNode.isHidden {
            let snapshotLayer = CALayer()
            snapshotLayer.contents = self.iconNode.layer.contents
            snapshotLayer.frame = self.iconNode.bounds
            self.iconNode.layer.insertSublayer(snapshotLayer, at: 0)
            snapshotLayer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                snapshotLayer?.removeFromSuperlayer()
            })
        }
        self.iconNode.image = image
        if let color = color {
            self.color = color
        }
    }
    
    public func asyncLayout() -> (Bool, Bool) -> (CGSize, (Bool) -> Void) {
        return { [weak self] online, isVoiceChat in
            let size: CGFloat = isVoiceChat ? 22.0 : 14.0
            return (CGSize(width: size, height: size), { animated in
                if let strongSelf = self {
                    strongSelf.iconNode.frame = CGRect(x: 0.0, y: 0.0, width: size, height: size)

                    if online && isVoiceChat {
                        if let _ = strongSelf.animationNode {
                        } else {
                            let animationNode = VoiceChatIndicatorNode()
                            animationNode.color = strongSelf.color
                            animationNode.frame = strongSelf.iconNode.bounds
                            strongSelf.animationNode = animationNode
                            strongSelf.iconNode.addSubnode(animationNode)
                        }
                    }
                    
                    if animated {
                        let initialScale: CGFloat = strongSelf.iconNode.isHidden ? 0.0 : CGFloat((strongSelf.iconNode.value(forKeyPath: "layer.presentationLayer.transform.scale.x") as? NSNumber)?.floatValue ?? 1.0)
                        let targetScale: CGFloat = online ? 1.0 : 0.0
                        if initialScale != targetScale {
                            strongSelf.iconNode.isHidden = false
                            strongSelf.iconNode.layer.animateScale(from: initialScale, to: targetScale, duration: 0.2, removeOnCompletion: false, completion: { [weak self] finished in
                                if let strongSelf = self, finished {
                                    strongSelf.iconNode.isHidden = !online
                                    
                                    if let animationNode = strongSelf.animationNode, !online {
                                        strongSelf.animationNode = nil
                                        animationNode.removeFromSupernode()
                                    }
                                }
                            })
                        }
                    } else {
                        strongSelf.iconNode.isHidden = !online
                        
                        if let animationNode = strongSelf.animationNode, !online {
                            strongSelf.animationNode = nil
                            animationNode.removeFromSupernode()
                        }
                    }
                }
            })
        }
    }
}
