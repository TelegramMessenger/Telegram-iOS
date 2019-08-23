import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import TelegramPresentationData
import AvatarNode

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 24.0)!
private let avatarBackgroundImage = UIImage(bundleImageName: "Chat/Message/LocationPin")?.precomposed()

private func addPulseAnimations(layer: CALayer) {
    let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
    scaleAnimation.values = [0.0 as NSNumber, 0.72 as NSNumber, 1.0 as NSNumber, 1.0 as NSNumber]
    scaleAnimation.keyTimes = [0.0 as NSNumber, 0.49 as NSNumber, 0.88 as NSNumber, 1.0 as NSNumber]
    scaleAnimation.duration = 3.0
    scaleAnimation.repeatCount = Float.infinity
    scaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
    scaleAnimation.beginTime = 1.0
    layer.add(scaleAnimation, forKey: "pulse-scale")
    
    let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
    opacityAnimation.values = [1.0 as NSNumber, 0.2 as NSNumber, 0.0 as NSNumber, 0.0 as NSNumber]
    opacityAnimation.keyTimes = [0.0 as NSNumber, 0.4 as NSNumber, 0.62 as NSNumber, 1.0 as NSNumber]
    opacityAnimation.duration = 3.0
    opacityAnimation.repeatCount = Float.infinity
    opacityAnimation.beginTime = 1.0
    layer.add(opacityAnimation, forKey: "pulse-opacity")
}

private func removePulseAnimations(layer: CALayer) {
    layer.removeAnimation(forKey: "pulse-scale")
    layer.removeAnimation(forKey: "pulse-opacity")
}

public final class ChatMessageLiveLocationPositionNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let avatarNode: AvatarNode
    private let pulseNode: ASImageNode
    
    private var pulseImage: UIImage?
    
    override public init() {
        let isLayerBacked = !smartInvertColorsEnabled()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = isLayerBacked
        
        self.pulseNode = ASImageNode()
        self.pulseNode.isLayerBacked = true
        self.pulseNode.displaysAsynchronously = false
        self.pulseNode.displayWithoutProcessing = true
        self.pulseNode.isHidden = true
        
        super.init()
        
        self.isLayerBacked = isLayerBacked
        
        self.addSubnode(self.pulseNode)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.avatarNode)
    }
    
    public func asyncLayout() -> (_ account: Account, _ theme: PresentationTheme, _ peer: Peer?, _ liveActive: Bool?) -> (CGSize, () -> Void) {
        let currentPulseImage = self.pulseImage
        
        return { [weak self] account, theme, peer, liveActive in
            let backgroundImage: UIImage?
            var hasPulse = false
            if let _ = peer {
                backgroundImage = avatarBackgroundImage
                
                if let liveActive = liveActive {
                    hasPulse = liveActive
                }
            } else {
                backgroundImage = PresentationResourcesChat.chatBubbleMapPinImage(theme)
            }
            
            let pulseImage: UIImage?
            if hasPulse {
                pulseImage = currentPulseImage ?? generateFilledCircleImage(diameter: 120.0, color: UIColor(rgb: 0x007aff, alpha: 0.27))
            } else {
                pulseImage = nil
            }
            
            return (CGSize(width: 62.0, height: 74.0), {
                if let strongSelf = self {
                    if strongSelf.backgroundNode.image !== backgroundImage {
                        strongSelf.backgroundNode.image = backgroundImage
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 74.0))
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 9.0), size: CGSize(width: 42.0, height: 42.0))
                    if let peer = peer {
                        strongSelf.avatarNode.setPeer(account: account, theme: theme, peer: peer)
                        strongSelf.avatarNode.isHidden = false
                        
                        if let liveActive = liveActive {
                            strongSelf.avatarNode.alpha = liveActive ? 1.0 : 0.6
                        } else {
                            strongSelf.avatarNode.alpha = 1.0
                        }
                    } else {
                        strongSelf.avatarNode.isHidden = true
                    }
                    
                    strongSelf.pulseImage = pulseImage
                    strongSelf.pulseNode.image = pulseImage
                    strongSelf.pulseNode.frame = CGRect(origin: CGPoint(x: floor((62.0 - 60.0) / 2.0), y: 34.0), size: CGSize(width: 60.0, height: 60.0))
                    if hasPulse {
                        if strongSelf.pulseNode.isHidden {
                            strongSelf.pulseNode.isHidden = false
                            if strongSelf.isInHierarchy {
                                addPulseAnimations(layer: strongSelf.pulseNode.layer)
                            }
                        }
                    } else if !strongSelf.pulseNode.isHidden {
                        strongSelf.pulseNode.isHidden = true
                        removePulseAnimations(layer: strongSelf.pulseNode.layer)
                    }
                }
            })
        }
    }
    
    override public func willEnterHierarchy() {
        super.willEnterHierarchy()
        if !self.pulseNode.isHidden {
            addPulseAnimations(layer: self.pulseNode.layer)
        }
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        if !self.pulseNode.isHidden {
            removePulseAnimations(layer: self.pulseNode.layer)
        }
    }
}
