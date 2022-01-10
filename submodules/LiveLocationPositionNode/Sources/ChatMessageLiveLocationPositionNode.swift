import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AvatarNode
import LocationResources
import AppBundle
import AccountContext
import CoreLocation

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

private let arrowImageSize = CGSize(width: 70.0, height: 70.0)
private func generateHeadingArrowImage() -> UIImage? {
    return generateImage(arrowImageSize, contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
    
        context.saveGState()
        let center = CGPoint(x: arrowImageSize.width / 2.0, y: arrowImageSize.height / 2.0)
        context.move(to: center)
        context.addArc(center: center, radius: arrowImageSize.width / 2.0, startAngle: CGFloat.pi / 2.0 + CGFloat.pi / 8.0, endAngle: CGFloat.pi / 2.0 - CGFloat.pi / 8.0, clockwise: true)
        context.clip()
        
        var locations: [CGFloat] = [0.0, 0.4, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0x007aff, alpha: 0.5).cgColor, UIColor(rgb: 0x007aff, alpha: 0.3).cgColor, UIColor(rgb: 0x007aff, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 5.0, endCenter: center, endRadius: arrowImageSize.width / 2.0, options: .drawsAfterEndLocation)
        
        context.restoreGState()
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(x: (arrowImageSize.width - 10.0) / 2.0, y: (arrowImageSize.height - 10.0) / 2.0, width: 10.0, height: 10.0))
    })
}

public final class ChatMessageLiveLocationPositionNode: ASDisplayNode {
    public enum Mode {
        case liveLocation(peer: EnginePeer, active: Bool, latitude: Double, longitude: Double, heading: Int32?)
        case location(TelegramMediaMap?)
    }
    
    private let backgroundNode: ASImageNode
    private let iconNode: TransformImageNode
    private let avatarNode: AvatarNode
    private let pulseNode: ASImageNode
    private let arrowNode: ASImageNode
    
    private var pulseImage: UIImage?
    private var arrowImage: UIImage?
    private var venueType: String?
    private var coordinate: (Double, Double)?
    
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
        
        self.arrowNode = ASImageNode()
        self.arrowNode.frame = CGRect(origin: CGPoint(), size: arrowImageSize)
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isHidden = true
        
        super.init()
        
        self.isLayerBacked = isLayerBacked
        
        self.addSubnode(self.pulseNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.avatarNode)
    }
    
    public func asyncLayout() -> (_ context: AccountContext, _ theme: PresentationTheme, _ mode: Mode) -> (CGSize, () -> Void) {
        let iconLayout = self.iconNode.asyncLayout()
        
        let currentPulseImage = self.pulseImage
        let currentArrowImage = self.arrowImage
        let currentVenueType = self.venueType
        
        let currentCoordinate = self.coordinate
        
        return { [weak self] context, theme, mode in
            var updatedVenueType: String?
            
            let backgroundImage: UIImage?
            var hasPulse = false
            var heading: Double?
            var coordinate: (Double, Double)?
            
            func degToRad(_ degrees: Double) -> Double {
                return degrees * Double.pi / 180.0
            }
            
            switch mode {
                case let .liveLocation(_, active, latitude, longitude, headingValue):
                    backgroundImage = avatarBackgroundImage
                    hasPulse = active
                    coordinate = (latitude, longitude)
                    heading = headingValue.flatMap { degToRad(Double($0)) }
                case let .location(location):
                    let venueType = location?.venue?.type ?? ""
                    let color = venueType.isEmpty ? theme.list.itemAccentColor : venueIconColor(type: venueType)
                    backgroundImage = chatBubbleMapPinImage(theme, color: color)
                    if currentVenueType != venueType {
                        updatedVenueType = venueType
                    }
            }
            
            if heading == nil, let currentCoordinate = currentCoordinate, let coordinate = coordinate {
                let lat1 = degToRad(currentCoordinate.0)
                let lon1 = degToRad(currentCoordinate.1)
                let lat2 = degToRad(coordinate.0)
                let lon2 = degToRad(coordinate.1)

                let dLat = lat2 - lat1
                let dLon = lon2 - lon1
                
                if dLat != 0 && dLon != 0 {
                    let y = sin(dLon) * cos(lat2)
                    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
                    heading = atan2(y, x)
                }
            }
            
            let pulseImage: UIImage?
            let arrowImage: UIImage?
            if hasPulse {
                pulseImage = currentPulseImage ?? generateFilledCircleImage(diameter: 120.0, color: UIColor(rgb: 0x007aff, alpha: 0.27))
            } else {
                pulseImage = nil
            }
            
            if let _ = heading {
                arrowImage = currentArrowImage ?? generateHeadingArrowImage()
            } else {
                arrowImage = nil
            }
            
            return (CGSize(width: 62.0, height: 74.0), {
                if let strongSelf = self {
                    strongSelf.coordinate = coordinate
                    
                    if strongSelf.backgroundNode.image !== backgroundImage {
                        strongSelf.backgroundNode.image = backgroundImage
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 74.0))
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 9.0), size: CGSize(width: 42.0, height: 42.0))
                    switch mode {
                        case let .liveLocation(peer, active, _, _, _):
                            strongSelf.avatarNode.setPeer(context: context, theme: theme, peer: peer)
                            strongSelf.avatarNode.isHidden = false
                            strongSelf.iconNode.isHidden = true
                            strongSelf.avatarNode.alpha = active ? 1.0 : 0.6
                        case .location:
                            strongSelf.iconNode.isHidden = false
                            strongSelf.avatarNode.isHidden = true
                    }
                    
                    if let updatedVenueType = updatedVenueType {
                        strongSelf.venueType = updatedVenueType
                        strongSelf.iconNode.setSignal(venueIcon(engine: context.engine, type: updatedVenueType, background: false))
                    }
                    
                    let arguments = VenueIconArguments(defaultBackgroundColor: theme.chat.inputPanel.actionControlFillColor, defaultForegroundColor: theme.chat.inputPanel.actionControlForegroundColor)
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
                    
                    strongSelf.arrowImage = arrowImage
                    strongSelf.arrowNode.image = arrowImage
                    strongSelf.arrowNode.isHidden = heading == nil || !hasPulse
                    strongSelf.arrowNode.position = CGPoint(x: 31.0, y: 64.0)
                    
                    strongSelf.arrowNode.transform = CATransform3DMakeRotation(CGFloat(heading ?? 0), 0.0, 0.0, 1.0)
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
