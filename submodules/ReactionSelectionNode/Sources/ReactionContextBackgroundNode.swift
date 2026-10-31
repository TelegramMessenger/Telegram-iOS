import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import ComponentFlow
import GlassBackgroundComponent
import ReactionContextGeometry

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
    struct GlassParams {
        var isDark: Bool
        var isTinted: Bool
        /// The tail's two drops in glass too (the chat context menu in the bubble-free mode); other glass bars have none.
        var hasTail: Bool
        
        init(isDark: Bool, isTinted: Bool, hasTail: Bool = false) {
            self.isDark = isDark
            self.isTinted = isTinted
            self.hasTail = hasTail
        }
    }
    
    private let largeCircleSize: CGFloat
    private let smallCircleSize: CGFloat
    
    private let backgroundView: BlurredBackgroundView
    private let glassBackgroundView: (container: GlassBackgroundContainerView, view: GlassBackgroundView)?
    // The tail's drops; only with `hasTail`. The large one is in the bar's glass container so it merges with the bar where
    // they touch, the small one in a container of its own so it stays apart from the large one.
    private let glassTailViews: (largeCircle: GlassBackgroundView, smallCircle: (container: GlassBackgroundContainerView, view: GlassBackgroundView))?
    
    // The glass with the tail opens as the blurred picker does: the bar materialises as the circle at its source and
    // grows into place, and the drops spring out of their centres. It closes by dematerialising: a glass container faded by
    // alpha loses its material at once. Glass follows only geometry changed inside UIKit animations (`animateView`).
    private struct GlassTailLayout {
        var containerFrame: CGRect
        var barFrame: CGRect
        var largeCircleFrame: CGRect
        var smallCircleFrame: CGRect
        var isDark: Bool
        var tintColor: GlassBackgroundView.TintColor
        var displaysTail: Bool
    }
    private var glassTailLayout: GlassTailLayout?
    // While set, the bar waits at this frame to grow out of it.
    private var glassBarSourceFrame: CGRect?
    private var glassTailIsDismissed = false
    // While set, the drops wait at their centres to grow out of them.
    private var glassDropsAreGrowing = false
    
    private let backgroundTintView: UIView
    private let backgroundTintMaskOuterContainer: UIView
    let backgroundTintMaskContainer: UIView
    let vibrantExpandedContentContainer: UIView
    
    private let maskLayer: SimpleLayer
    private let backgroundClippingLayer: SimpleLayer
    private let backgroundMaskNode: ASDisplayNode
    private let backgroundShadowLayer: SimpleLayer
    private let largeCircleLayer: SimpleLayer
    private let largeCircleShadowLayer: SimpleLayer
    private let smallCircleLayer: SimpleLayer
    private let smallCircleShadowLayer: SimpleLayer
    
    private let glass: GlassParams?
    private var theme: PresentationTheme?
    
    init(glass: GlassParams?, largeCircleSize: CGFloat, smallCircleSize: CGFloat, maskNode: ASDisplayNode) {
        self.glass = glass
        self.largeCircleSize = largeCircleSize
        self.smallCircleSize = smallCircleSize
        
        self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
        if glass != nil {
            self.glassBackgroundView = (GlassBackgroundContainerView(), GlassBackgroundView())
        } else {
            self.glassBackgroundView = nil
        }
        if let glass, glass.hasTail {
            self.glassTailViews = (GlassBackgroundView(), (GlassBackgroundContainerView(), GlassBackgroundView()))
        } else {
            self.glassTailViews = nil
        }
        
        self.backgroundTintView = UIView()
        self.backgroundTintMaskContainer = UIView()
        self.backgroundTintMaskOuterContainer = UIView()
        
        self.maskLayer = SimpleLayer()
        self.backgroundClippingLayer = SimpleLayer()
        self.backgroundClippingLayer.cornerRadius = 47.0
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
            self.largeCircleLayer.cornerCurve = .circular
            self.smallCircleLayer.cornerCurve = .circular
        }
        
        self.vibrantExpandedContentContainer = UIView()
        self.backgroundTintMaskOuterContainer.addSubview(self.backgroundTintMaskContainer)
        self.backgroundTintMaskOuterContainer.addSubview(self.vibrantExpandedContentContainer)
        
        super.init()
        
        self.layer.addSublayer(self.backgroundShadowLayer)
        self.layer.addSublayer(self.smallCircleShadowLayer)
        self.layer.addSublayer(self.largeCircleShadowLayer)
        
        self.backgroundShadowLayer.opacity = 0.0
        self.largeCircleShadowLayer.opacity = 0.0
        self.smallCircleShadowLayer.opacity = 0.0
        
        self.backgroundTintMaskOuterContainer.backgroundColor = .white
        
        
        if let glassBackgroundView = self.glassBackgroundView {
            if let glassTailViews = self.glassTailViews {
                glassBackgroundView.container.contentView.addSubview(glassTailViews.largeCircle)
            }
            glassBackgroundView.container.contentView.addSubview(glassBackgroundView.view)
            self.view.addSubview(glassBackgroundView.container)
            if let glassTailViews = self.glassTailViews {
                glassTailViews.smallCircle.container.contentView.addSubview(glassTailViews.smallCircle.view)
                self.view.addSubview(glassTailViews.smallCircle.container)
            }
            //glassBackgroundView.addSubview(self.backgroundTintView)
            //glassBackgroundView.maskContentView.layer.addSublayer(self.maskLayer)
        } else {
            self.backgroundView.layer.mask = self.maskLayer
            self.view.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.backgroundTintView)
        }
        
        self.maskLayer.addSublayer(self.smallCircleLayer)
        self.maskLayer.addSublayer(self.largeCircleLayer)
        self.maskLayer.addSublayer(self.backgroundClippingLayer)
        
        self.backgroundClippingLayer.addSublayer(self.backgroundMaskNode.layer)
    }
    
    func updateIsIntersectingContent(isIntersectingContent: Bool, transition: ContainedViewLayoutTransition) {
        let shadowAlpha: CGFloat = isIntersectingContent ? 1.0 : 0.0
        transition.updateAlpha(layer: self.backgroundShadowLayer, alpha: shadowAlpha)
        transition.updateAlpha(layer: self.smallCircleShadowLayer, alpha: shadowAlpha)
        transition.updateAlpha(layer: self.largeCircleShadowLayer, alpha: shadowAlpha)
    }

    func update(
        theme: PresentationTheme,
        forceDark: Bool,
        size: CGSize,
        cloudSourcePoint: CGFloat,
        isLeftAligned: Bool,
        isMinimized: Bool,
        isCoveredByInput: Bool,
        displayTail: Bool,
        forceTailToRight: Bool,
        transition: ContainedViewLayoutTransition
    ) {
        let shadowInset: CGFloat = 15.0
        
        if self.theme !== theme {
            self.theme = theme
            
            if theme.overallDarkAppearance {
                if let invertFilter = CALayer.colorInvert(), let filter = CALayer.luminanceToAlpha() {
                    self.backgroundTintMaskOuterContainer.layer.filters = [invertFilter, filter]
                }
                self.backgroundTintView.mask = self.backgroundTintMaskOuterContainer
                
                self.backgroundView.updateColor(color: theme.contextMenu.backgroundColor, forceKeepBlur: true, transition: .immediate)
                self.backgroundTintView.backgroundColor = UIColor(white: 1.0, alpha: 0.5)
            } else {
                if let filter = CALayer.luminanceToAlpha() {
                    self.backgroundTintMaskOuterContainer.layer.filters = [filter]
                }
                self.backgroundTintView.mask = self.backgroundTintMaskOuterContainer
                
                self.backgroundView.updateColor(color: .clear, forceKeepBlur: true, transition: .immediate)
                self.backgroundTintView.backgroundColor = theme.contextMenu.backgroundColor
            }
            
            let shadowColor = UIColor(white: 0.0, alpha: 0.4)
            
            if let image = generateBubbleShadowImage(shadow: shadowColor, diameter: 46.0, shadowBlur: shadowInset) {
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
        
        transition.updateCornerRadius(layer: self.backgroundClippingLayer, cornerRadius: min(46.0 / 2.0, backgroundFrame.height / 2.0))
        
        let largeCircleFrame: CGRect
        let smallCircleFrame: CGRect
        if forceTailToRight {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: size.height - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.maxX - 3.0, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        } else if isLeftAligned {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: size.height - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.maxX - 3.0, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        } else {
            largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(largeCircleSize / 2.0), y: size.height - largeCircleSize / 2.0), size: CGSize(width: largeCircleSize, height: largeCircleSize))
            smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.minX + 3.0 - smallCircleSize, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: smallCircleSize, height: smallCircleSize))
        }
        
        let contentBounds = reactionContextBackgroundContentBounds(backgroundFrame: backgroundFrame, largeCircleFrame: largeCircleFrame, smallCircleFrame: smallCircleFrame, displayTail: displayTail)
        
        transition.updateFrame(node: self.backgroundMaskNode, frame: backgroundMaskNodeFrame, beginWithCurrentState: true)
        transition.updateFrame(layer: self.backgroundClippingLayer, frame: backgroundFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY), beginWithCurrentState: true)
        transition.updateFrame(layer: self.largeCircleLayer, frame: largeCircleFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY), beginWithCurrentState: true)
        transition.updateFrame(layer: self.smallCircleLayer, frame: smallCircleFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY), beginWithCurrentState: true)
        
        transition.updateFrame(layer: self.backgroundShadowLayer, frame: backgroundFrame.insetBy(dx: -shadowInset, dy: -shadowInset), beginWithCurrentState: true)
        transition.updateFrame(layer: self.largeCircleShadowLayer, frame: largeCircleFrame.insetBy(dx: -shadowInset, dy: -shadowInset), beginWithCurrentState: true)
        
        transition.updateAlpha(layer: self.largeCircleLayer, alpha: (isCoveredByInput || !displayTail) ? 0.0 : 1.0)
        transition.updateAlpha(layer: self.largeCircleShadowLayer, alpha: (isCoveredByInput || !displayTail) ? 0.0 : 1.0)
        transition.updateAlpha(layer: self.smallCircleLayer, alpha: (isCoveredByInput || !displayTail) ? 0.0 : 1.0)
        transition.updateAlpha(layer: self.smallCircleShadowLayer, alpha: (isCoveredByInput || !displayTail) ? 0.0 : 1.0)
        
        transition.updateFrame(layer: self.smallCircleShadowLayer, frame: smallCircleFrame.insetBy(dx: -shadowInset, dy: -shadowInset), beginWithCurrentState: true)
        
        transition.updateFrame(view: self.backgroundView, frame: contentBounds, beginWithCurrentState: true)
        self.backgroundView.update(size: contentBounds.size, transition: transition)
        
        if let glass = self.glass, let glassBackgroundView = self.glassBackgroundView {
            var glassBackgroundFrame = contentBounds.insetBy(dx: 10.0, dy: 10.0)
            glassBackgroundFrame.size.height -= 8.0
            transition.updateFrame(view: glassBackgroundView.container, frame: glassBackgroundFrame, beginWithCurrentState: true)
            transition.updateFrame(view: glassBackgroundView.view, frame: CGRect(origin: CGPoint(), size: glassBackgroundFrame.size), beginWithCurrentState: true)
            let glassTintColor: GlassBackgroundView.TintColor
            if let glass = self.glass, glass.isTinted {
                glassTintColor = .init(kind: .custom(style: .default, color: UIColor(rgb: 0x25272e, alpha: 0.72)))
            } else {
                glassTintColor = .init(kind: .panel)
            }
            if self.glassTailViews != nil {
                // The container spans the large drop as well; the bar sits in it where it would otherwise be.
                let glassContainerFrame = glassBackgroundFrame.union(largeCircleFrame)
                transition.updateFrame(view: glassBackgroundView.container, frame: glassContainerFrame, beginWithCurrentState: true)
                glassBackgroundView.container.update(size: glassContainerFrame.size, isDark: glass.isDark, transition: ComponentTransition(transition))
                let displaysTail = !isCoveredByInput && displayTail
                self.glassTailLayout = GlassTailLayout(containerFrame: glassContainerFrame, barFrame: glassBackgroundFrame, largeCircleFrame: largeCircleFrame, smallCircleFrame: smallCircleFrame, isDark: glass.isDark, tintColor: glassTintColor, displaysTail: displaysTail)
                self.updateGlassBar(frame: self.glassBarSourceFrame ?? glassBackgroundFrame, isVisible: !self.glassTailIsDismissed, transition: transition)
                if !self.glassDropsAreGrowing {
                    self.updateGlassDrops(largeCircleFrame: largeCircleFrame, smallCircleFrame: smallCircleFrame, isVisible: displaysTail && !self.glassTailIsDismissed, transition: transition)
                }
            } else {
                glassBackgroundView.container.update(size: glassBackgroundFrame.size, isDark: glass.isDark, transition: ComponentTransition(transition))
                glassBackgroundView.view.update(size: glassBackgroundFrame.size, cornerRadius: 23.0, isDark: true, tintColor: glassTintColor, transition: ComponentTransition(transition))
            }
            
            transition.updateFrame(view: self.backgroundTintView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentBounds.width, height: contentBounds.height)).insetBy(dx: -10.0, dy: -10.0))
        } else {
            transition.updateFrame(view: self.backgroundTintView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: contentBounds.width, height: contentBounds.height)))
        }
        transition.updateFrame(view: self.backgroundTintMaskOuterContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: contentBounds.size))
        transition.updateFrame(view: self.backgroundTintMaskContainer, frame: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: contentBounds.size))
        transition.updateFrame(view: self.vibrantExpandedContentContainer, frame: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: contentBounds.size))
    }
    
    /// The glass bar at `frame` (this node's coordinates) in the bar's container.
    private func updateGlassBar(frame: CGRect, isVisible: Bool, transition: ContainedViewLayoutTransition, componentTransition: ComponentTransition? = nil) {
        guard let layout = self.glassTailLayout, let glassBackgroundView = self.glassBackgroundView else {
            return
        }
        let localFrame = frame.offsetBy(dx: -layout.containerFrame.minX, dy: -layout.containerFrame.minY)
        let glassTransition = componentTransition ?? ComponentTransition(transition)
        if let componentTransition {
            componentTransition.animateView {
                glassBackgroundView.view.frame = localFrame
            }
        } else {
            transition.updateFrame(view: glassBackgroundView.view, frame: localFrame, beginWithCurrentState: true)
        }
        glassBackgroundView.view.update(size: frame.size, cornerRadius: min(23.0, frame.height * 0.5), isDark: layout.isDark, tintColor: layout.tintColor, isVisible: isVisible, transition: glassTransition)
    }
    
    /// The tail's drops at their frames (this node's coordinates): the large one in the bar's container, the small one in
    /// its own.
    private func updateGlassDrops(largeCircleFrame: CGRect, smallCircleFrame: CGRect, isVisible: Bool, transition: ContainedViewLayoutTransition, componentTransition: ComponentTransition? = nil) {
        guard let layout = self.glassTailLayout, let glassTailViews = self.glassTailViews else {
            return
        }
        let largeLocalFrame = largeCircleFrame.offsetBy(dx: -layout.containerFrame.minX, dy: -layout.containerFrame.minY)
        let smallLocalFrame = CGRect(origin: CGPoint(), size: smallCircleFrame.size)
        let glassTransition = componentTransition ?? ComponentTransition(transition)
        if let componentTransition {
            componentTransition.animateView {
                glassTailViews.largeCircle.frame = largeLocalFrame
                glassTailViews.smallCircle.container.frame = smallCircleFrame
                glassTailViews.smallCircle.view.frame = smallLocalFrame
            }
        } else {
            transition.updateFrame(view: glassTailViews.largeCircle, frame: largeLocalFrame, beginWithCurrentState: true)
            transition.updateFrame(view: glassTailViews.smallCircle.container, frame: smallCircleFrame, beginWithCurrentState: true)
            transition.updateFrame(view: glassTailViews.smallCircle.view, frame: smallLocalFrame, beginWithCurrentState: true)
        }
        glassTailViews.largeCircle.update(size: largeCircleFrame.size, cornerRadius: largeCircleFrame.height * 0.5, isDark: layout.isDark, tintColor: layout.tintColor, isVisible: isVisible, transition: glassTransition)
        glassTailViews.smallCircle.container.update(size: smallCircleFrame.size, isDark: layout.isDark, transition: glassTransition)
        glassTailViews.smallCircle.view.update(size: smallCircleFrame.size, cornerRadius: smallCircleFrame.height * 0.5, isDark: layout.isDark, tintColor: layout.tintColor, isVisible: isVisible, transition: glassTransition)
    }
    
    /// The blurred picker's opening in glass: the bar materialises as the circle at its source and, after the bar's delay,
    /// grows into place on the bar's spring; the drops grow out of their centres on the circles' spring.
    private func animateGlassTailIn(sourceBackgroundFrame: CGRect) {
        guard let layout = self.glassTailLayout else {
            return
        }
        func point(_ frame: CGRect) -> CGRect {
            return CGRect(x: frame.midX - 0.5, y: frame.midY - 0.5, width: 1.0, height: 1.0)
        }
        // As the blurred bar: the source gives the circle's horizontal centre and size, on the bar's own line (it was laid
        // out for the anchor before the message lifted).
        let sourceFrame = CGRect(x: sourceBackgroundFrame.midX - sourceBackgroundFrame.width * 0.5, y: layout.barFrame.minY, width: min(sourceBackgroundFrame.width, layout.barFrame.width), height: layout.barFrame.height)
        self.glassBarSourceFrame = sourceFrame
        self.glassDropsAreGrowing = true
        self.updateGlassBar(frame: sourceFrame, isVisible: false, transition: .immediate)
        self.updateGlassDrops(largeCircleFrame: point(layout.largeCircleFrame), smallCircleFrame: point(layout.smallCircleFrame), isVisible: layout.displaysTail, transition: .immediate)
        
        // A frame later: glass animates from the state it was last committed in, and the main queue can still be drained
        // inside the transaction that set the source state up.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0 / 60.0) { [weak self] in
            guard let self, !self.glassTailIsDismissed, let layout = self.glassTailLayout else {
                return
            }
            self.glassDropsAreGrowing = false
            if let sourceFrame = self.glassBarSourceFrame {
                self.updateGlassBar(frame: sourceFrame, isVisible: true, transition: .immediate, componentTransition: .easeInOut(duration: 0.2))
            }
            self.updateGlassDrops(largeCircleFrame: layout.largeCircleFrame, smallCircleFrame: layout.smallCircleFrame, isVisible: layout.displaysTail, transition: .immediate, componentTransition: ComponentTransition(animation: .curve(duration: 0.4, curve: .bounce(stiffness: 900.0, damping: 88.0))))
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.11 * UIView.animationDurationFactor(), execute: { [weak self] in
            guard let self, self.glassBarSourceFrame != nil, !self.glassTailIsDismissed, let layout = self.glassTailLayout else {
                return
            }
            self.glassBarSourceFrame = nil
            self.updateGlassBar(frame: layout.barFrame, isVisible: true, transition: .immediate, componentTransition: ComponentTransition(animation: .curve(duration: 0.5, curve: .bounce(stiffness: 900.0, damping: 104.0))))
        })
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
        
        if let glassBackgroundView = self.glassBackgroundView, self.glassTailViews == nil {
            glassBackgroundView.container.alpha = 0.0
            
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            transition.setAlpha(view: glassBackgroundView.container, alpha: 1.0)
        }
    }
    
    func animateInFromAnchorRect(size: CGSize, sourceBackgroundFrame: CGRect) {
        let springDuration: Double = 0.5
        let springDamping: CGFloat = 104.0
        let springScaleDelay: Double = 0.1
        let springDelay: Double = springScaleDelay + 0.01
        let shadowInset: CGFloat = 15.0
        
        let contentBounds = self.backgroundView.frame
        
        let visualSourceBackgroundFrame = sourceBackgroundFrame.offsetBy(dx: -contentBounds.minX, dy: -contentBounds.minY)
        let sourceShadowFrame = visualSourceBackgroundFrame.insetBy(dx: -shadowInset, dy: -shadowInset)
        
        self.backgroundClippingLayer.animateScale(from: 0.001, to: 1.0, duration: 0.2, delay: springScaleDelay, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        self.backgroundShadowLayer.animateScale(from: 0.001, to: 1.0, duration: 0.2, delay: springScaleDelay, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        
        self.backgroundClippingLayer.animateSpring(from: NSValue(cgPoint: CGPoint(x: visualSourceBackgroundFrame.midX - size.width / 2.0, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
        self.backgroundClippingLayer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: visualSourceBackgroundFrame.size)), to: NSValue(cgRect: self.backgroundClippingLayer.bounds), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        self.backgroundShadowLayer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceShadowFrame.midX - size.width / 2.0, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
        self.backgroundShadowLayer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceShadowFrame.size)), to: NSValue(cgRect: self.backgroundShadowLayer.bounds), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        
        if self.glassTailViews != nil {
            self.animateGlassTailIn(sourceBackgroundFrame: sourceBackgroundFrame)
        } else if let glassBackgroundView = self.glassBackgroundView {
            glassBackgroundView.container.alpha = 0.0
            
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            transition.setAlpha(view: glassBackgroundView.container, alpha: 1.0)
        }
    }
    
    func animateOut() {
        self.maskLayer.allowsGroupOpacity = true
        self.maskLayer.animateAlpha(from: CGFloat(self.backgroundClippingLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundShadowLayer.animateAlpha(from: CGFloat(self.backgroundShadowLayer.opacity), to: 0.0, duration: 0.1, removeOnCompletion: false)
        //self.largeCircleLayer.animateAlpha(from: CGFloat(self.largeCircleLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.largeCircleShadowLayer.animateAlpha(from: CGFloat(self.largeCircleShadowLayer.opacity), to: 0.0, duration: 0.1, removeOnCompletion: false)
        //self.smallCircleLayer.animateAlpha(from: CGFloat(self.smallCircleLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.smallCircleShadowLayer.animateAlpha(from: CGFloat(self.smallCircleShadowLayer.opacity), to: 0.0, duration: 0.1, removeOnCompletion: false)
        
        if self.glassTailViews != nil, let layout = self.glassTailLayout {
            self.glassTailIsDismissed = true
            let barFrame = self.glassBarSourceFrame ?? layout.barFrame
            self.glassBarSourceFrame = nil
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            self.updateGlassBar(frame: barFrame, isVisible: false, transition: .immediate, componentTransition: transition)
            self.updateGlassDrops(largeCircleFrame: layout.largeCircleFrame, smallCircleFrame: layout.smallCircleFrame, isVisible: false, transition: .immediate, componentTransition: transition)
        } else if let glassBackgroundView = self.glassBackgroundView {
            let transition: ComponentTransition = .easeInOut(duration: 0.2)
            transition.setAlpha(view: glassBackgroundView.container, alpha: 0.0)
        }
    }
}
