import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext

private func generateBackgroundImage(foreground: UIColor, diameter: CGFloat, sideInset: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + sideInset * 2.0, height: diameter + sideInset * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: sideInset, y: sideInset), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(sideInset + diameter / 2.0), topCapHeight: Int(sideInset + diameter / 2.0))
}

private func generateBubbleImage(foreground: UIColor, diameter: CGFloat, sideInset: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + sideInset * 2.0, height: diameter + sideInset * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: sideInset, y: sideInset), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + sideInset / 2.0), topCapHeight: Int(diameter / 2.0 + sideInset / 2.0))
}

private func generateBubbleShadowImage(shadow: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(shadow.cgColor)
        context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setShadow(offset: CGSize(), blur: 1.0, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(shadowBlur + diameter / 2.0), topCapHeight: Int(shadowBlur + diameter / 2.0))
}


final class ReactionContextBackgroundNode: ASDisplayNode {
    private let largeCircleSize: CGFloat
    private let smallCircleSize: CGFloat
    
    private let backgroundNode: NavigationBackgroundNode
    
    private let maskLayer: SimpleLayer
    private let backgroundClippingLayer: SimpleLayer
    private let backgroundMaskNode: ASDisplayNode
    private let backgroundShadowLayer: SimpleLayer
    private let largeCircleLayer: SimpleLayer
    private let largeCircleShadowLayer: SimpleLayer
    private let smallCircleLayer: SimpleLayer
    private let smallCircleShadowLayer: SimpleLayer
    
    private var theme: PresentationTheme?
    
    init(largeCircleSize: CGFloat, smallCircleSize: CGFloat, maskNode: ASDisplayNode) {
        self.largeCircleSize = largeCircleSize
        self.smallCircleSize = smallCircleSize
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: true)
        
        self.maskLayer = SimpleLayer()
        self.backgroundClippingLayer = SimpleLayer()
        self.backgroundClippingLayer.cornerRadius = 52.0
        self.backgroundClippingLayer.masksToBounds = true
        self.backgroundMaskNode = maskNode

        self.backgroundShadowLayer = SimpleLayer()
        self.largeCircleLayer = SimpleLayer()
        self.largeCircleShadowLayer = SimpleLayer()
        self.smallCircleLayer = SimpleLayer()
        self.smallCircleShadowLayer = SimpleLayer()
        
        self.largeCircleLayer.backgroundColor = UIColor.black.cgColor
        self.largeCircleLayer.masksToBounds = true
        self.largeCircleLayer.cornerRadius = largeCircleSize / 2.0
        
        self.smallCircleLayer.backgroundColor = UIColor.black.cgColor
        self.smallCircleLayer.masksToBounds = true
        self.smallCircleLayer.cornerRadius = smallCircleSize / 2.0
        
        if #available(iOS 13.0, *) {
//            self.backgroundLayer.cornerCurve = .circular
            self.largeCircleLayer.cornerCurve = .circular
            self.smallCircleLayer.cornerCurve = .circular
        }
        
        super.init()
        
        self.layer.addSublayer(self.backgroundShadowLayer)
        self.layer.addSublayer(self.smallCircleShadowLayer)
        self.layer.addSublayer(self.largeCircleShadowLayer)
        
        self.backgroundShadowLayer.opacity = 0.0
        self.largeCircleShadowLayer.opacity = 0.0
        self.smallCircleShadowLayer.opacity = 0.0
        
        self.addSubnode(self.backgroundNode)
        
        self.maskLayer.addSublayer(self.smallCircleLayer)
        self.maskLayer.addSublayer(self.largeCircleLayer)
        self.maskLayer.addSublayer(self.backgroundClippingLayer)
        
        self.backgroundClippingLayer.addSublayer(self.backgroundMaskNode.layer)
        
        self.backgroundNode.layer.mask = self.maskLayer
    }
    
    func updateIsIntersectingContent(isIntersectingContent: Bool, transition: ContainedViewLayoutTransition) {
        let shadowAlpha: CGFloat = isIntersectingContent ? 1.0 : 0.0
        transition.updateAlpha(layer: self.backgroundShadowLayer, alpha: shadowAlpha)
        transition.updateAlpha(layer: self.smallCircleShadowLayer, alpha: shadowAlpha)
        transition.updateAlpha(layer: self.largeCircleShadowLayer, alpha: shadowAlpha)
    }

    func update(
        theme: PresentationTheme,
        size: CGSize,
        cloudSourcePoint: CGFloat,
        isLeftAligned: Bool,
        isMinimized: Bool,
        transition: ContainedViewLayoutTransition
    ) {
        let shadowInset: CGFloat = 15.0
        
        if self.theme !== theme {
            self.theme = theme
            
            self.backgroundNode.updateColor(color: theme.contextMenu.backgroundColor, transition: .immediate)
            
            let shadowColor = UIColor(white: 0.0, alpha: 0.4)
            
            if let image = generateBubbleShadowImage(shadow: shadowColor, diameter: 52.0, shadowBlur: shadowInset) {
                ASDisplayNodeSetResizableContents(self.backgroundShadowLayer, image)
            }
            if let image = generateBubbleShadowImage(shadow: shadowColor, diameter: self.largeCircleSize, shadowBlur: shadowInset) {
                ASDisplayNodeSetResizableContents(self.largeCircleShadowLayer, image)
            }
            if let image = generateBubbleShadowImage(shadow: shadowColor, diameter: self.smallCircleSize, shadowBlur: shadowInset) {
                ASDisplayNodeSetResizableContents(self.smallCircleShadowLayer, image)
            }
        }
        
        var backgroundFrame = CGRect(origin: CGPoint(), size: size)
        var backgroundMaskNodeFrame = backgroundFrame
        if isMinimized {
            let updatedHeight = floor(size.height * 0.9)
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - updatedHeight), size: CGSize(width: size.width, height: updatedHeight))
            backgroundMaskNodeFrame = backgroundMaskNodeFrame.offsetBy(dx: 0.0, dy: (updatedHeight - backgroundMaskNodeFrame.height) * 0.5)
        }
        
        transition.updateCornerRadius(layer: self.backgroundClippingLayer, cornerRadius: backgroundFrame.height / 2.0)
        
        let largeCircleFrame: CGRect
        let smallCircleFrame: CGRect
        if isLeftAligned {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: size.height - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.maxX - 3.0, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        } else {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: size.height - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.minX + 3.0 - smallCircleSize, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        }
        
        let contentBounds = backgroundFrame.insetBy(dx: -10.0, dy: -10.0).union(largeCircleFrame).union(smallCircleFrame)
        
        transition.updateFrame(node: self.backgroundMaskNode, frame: backgroundMaskNodeFrame, beginWithCurrentState: true)
        transition.updateFrame(layer: self.backgroundClippingLayer, frame: backgroundFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY), beginWithCurrentState: true)
        transition.updateFrame(layer: self.largeCircleLayer, frame: largeCircleFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY), beginWithCurrentState: true)
        transition.updateFrame(layer: self.smallCircleLayer, frame: smallCircleFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY), beginWithCurrentState: true)
        
        transition.updateFrame(layer: self.backgroundShadowLayer, frame: backgroundFrame.insetBy(dx: -shadowInset, dy: -shadowInset), beginWithCurrentState: true)
        transition.updateFrame(layer: self.largeCircleShadowLayer, frame: largeCircleFrame.insetBy(dx: -shadowInset, dy: -shadowInset), beginWithCurrentState: true)
        transition.updateFrame(layer: self.smallCircleShadowLayer, frame: smallCircleFrame.insetBy(dx: -shadowInset, dy: -shadowInset), beginWithCurrentState: true)
        
        transition.updateFrame(node: self.backgroundNode, frame: contentBounds, beginWithCurrentState: true)
        self.backgroundNode.update(size: contentBounds.size, transition: transition)
    }
    
    func animateIn() {
        let smallCircleDuration: Double = 0.4
        let largeCircleDuration: Double = 0.4
        let largeCircleDelay: Double = 0.0
        let mainCircleDuration: Double = 0.3
        let mainCircleDelay: Double = 0.0
        
        self.smallCircleLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: smallCircleDuration, delay: 0.0)
        
        self.largeCircleLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.01, delay: largeCircleDelay)
        self.largeCircleLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: largeCircleDuration, delay: largeCircleDelay)
        self.largeCircleShadowLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: largeCircleDuration, delay: largeCircleDelay)
        
        self.backgroundClippingLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.01, delay: mainCircleDelay)
        self.backgroundClippingLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: mainCircleDuration, delay: mainCircleDelay)
        self.backgroundShadowLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: mainCircleDuration, delay: mainCircleDelay)
    }
    
    func animateInFromAnchorRect(size: CGSize, sourceBackgroundFrame: CGRect) {
        let springDuration: Double = 0.3
        let springDamping: CGFloat = 104.0
        let springDelay: Double = 0.05
        let shadowInset: CGFloat = 15.0
        
        let contentBounds = self.backgroundNode.frame
        
        let visualSourceBackgroundFrame = sourceBackgroundFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY)
        let sourceShadowFrame = visualSourceBackgroundFrame.insetBy(dx: -shadowInset, dy: -shadowInset)
        
        self.backgroundClippingLayer.animateSpring(from: NSValue(cgPoint: CGPoint(x: visualSourceBackgroundFrame.midX - size.width / 2.0, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
        self.backgroundClippingLayer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: visualSourceBackgroundFrame.size)), to: NSValue(cgRect: self.backgroundClippingLayer.bounds), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        self.backgroundShadowLayer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceShadowFrame.midX - size.width / 2.0, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
        self.backgroundShadowLayer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceShadowFrame.size)), to: NSValue(cgRect: self.backgroundShadowLayer.bounds), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
    }
    
    func animateOut() {
        self.backgroundClippingLayer.animateAlpha(from: CGFloat(self.backgroundClippingLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundShadowLayer.animateAlpha(from: CGFloat(self.backgroundShadowLayer.opacity), to: 0.0, duration: 0.1, removeOnCompletion: false)
        self.largeCircleLayer.animateAlpha(from: CGFloat(self.largeCircleLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.largeCircleShadowLayer.animateAlpha(from: CGFloat(self.largeCircleShadowLayer.opacity), to: 0.0, duration: 0.1, removeOnCompletion: false)
        self.smallCircleLayer.animateAlpha(from: CGFloat(self.smallCircleLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.smallCircleShadowLayer.animateAlpha(from: CGFloat(self.smallCircleShadowLayer.opacity), to: 0.0, duration: 0.1, removeOnCompletion: false)
    }
}
