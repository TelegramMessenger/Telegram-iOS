import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import AvatarNode
import LocationResources
import AppBundle
import AccountContext

private let avatarFont = avatarPlaceholderFont(size: 24.0)
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

private func chatBubbleMapPinImage(_ theme: PresentationTheme, color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 62.0, height: 74.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let shadowImage = UIImage(bundleImageName: "Chat/Message/LocationPinShadow"), let cgImage = shadowImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(), size: shadowImage.size))
        }
        if let backgroundImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/LocationPinBackground"), color: color), let cgImage = backgroundImage.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(), size: backgroundImage.size))
        }
    })
}

public final class ChatMessageLiveLocationPositionNode: ASDisplayNode {
    public enum Mode {
        case liveLocation(Peer, Bool)
        case location(TelegramMediaMap?)
    }
    
    private let backgroundNode: ASImageNode
    private let iconNode: TransformImageNode
    private let avatarNode: AvatarNode
    private let pulseNode: ASImageNode
    
    private var pulseImage: UIImage?
    private var venueType: String?
    
    override public init() {
        let isLayerBacked = !smartInvertColorsEnabled()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.iconNode = TransformImageNode()
        self.iconNode.isLayerBacked = true
        
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
        self.addSubnode(self.iconNode)
        self.addSubnode(self.avatarNode)
    }
    
    public func asyncLayout() -> (_ context: AccountContext, _ theme: PresentationTheme, _ mode: Mode) -> (CGSize, () -> Void) {
        let iconLayout = self.iconNode.asyncLayout()
        
        let currentPulseImage = self.pulseImage
        let currentVenueType = self.venueType
        
        return { [weak self] context, theme, mode in
            var updatedVenueType: String?
            
            let backgroundImage: UIImage?
            var hasPulse = false
            switch mode {
                case let .liveLocation(_, active):
                    backgroundImage = avatarBackgroundImage
                    hasPulse = active
                case let .location(location):
                    let venueType = location?.venue?.type ?? ""
                    let color = venueType.isEmpty ? theme.list.itemAccentColor : venueIconColor(type: venueType)
                    backgroundImage = chatBubbleMapPinImage(theme, color: color)
                    if currentVenueType != venueType {
                        updatedVenueType = venueType
                    }
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
                    switch mode {
                        case let .liveLocation(peer, active):
                            strongSelf.avatarNode.setPeer(context: context, theme: theme, peer: peer)
                            strongSelf.avatarNode.isHidden = false
                            strongSelf.iconNode.isHidden = true
                            strongSelf.avatarNode.alpha = active ? 1.0 : 0.6
                        case let .location(location):
                            strongSelf.iconNode.isHidden = false
                            strongSelf.avatarNode.isHidden = true
                    }
                    
                    if let updatedVenueType = updatedVenueType {
                        strongSelf.venueType = updatedVenueType
                        strongSelf.iconNode.setSignal(venueIcon(postbox: context.account.postbox, type: updatedVenueType, background: false))
                    }

                    
                    let arguments = VenueIconArguments(defaultForegroundColor: theme.chat.inputPanel.actionControlForegroundColor)
                    let iconSize = CGSize(width: 44.0, height: 44.0)
                    let apply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), custom: arguments))
                    apply()
                    
                    strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 14.0), size: iconSize)
                    
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
