import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GradientBackground
import TelegramPresentationData
import TelegramCore
import AccountContext
import SwiftSignalKit
import WallpaperResources
import StickerResources
import FastBlur
import Svg
import GZip
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import HierarchyTrackingLayer

private let motionAmount: CGFloat = 32.0

private func generateBlurredContents(image: UIImage, dimColor: UIColor?) -> UIImage? {
    let size = image.size.aspectFitted(CGSize(width: 64.0, height: 64.0))
    guard let context = DrawingContext(size: size, scale: 1.0, opaque: true, clear: false) else {
        return nil
    }
    context.withFlippedContext { c in
        c.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
    }

    telegramFastBlurMore(Int32(context.size.width), Int32(context.size.height), Int32(context.bytesPerRow), context.bytes)
    telegramFastBlurMore(Int32(context.size.width), Int32(context.size.height), Int32(context.bytesPerRow), context.bytes)

    adjustSaturationInContext(context: context, saturation: 1.7)
    
    if let dimColor {
        context.withFlippedContext { c in
            c.setFillColor(dimColor.cgColor)
            c.fill(CGRect(origin: CGPoint(), size: size))
        }
    }

    return context.generateImage()
}

public enum WallpaperBubbleType {
    case incoming
    case outgoing
    case free
}

public protocol WallpaperBubbleBackgroundNode: ASDisplayNode {
    var frame: CGRect { get set }
    
    var implicitContentUpdate: Bool { get set }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition)
    func update(rect: CGRect, within containerSize: CGSize, delay: Double, transition: ContainedViewLayoutTransition)
    func update(rect: CGRect, within containerSize: CGSize, transition: CombinedTransition)
    func update(rect: CGRect, within containerSize: CGSize, animator: ControlledTransitionAnimator)
    func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double)
    func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat)
    
    func reloadBindings()
}

public enum WallpaperDisplayMode {
    case aspectFill
    case aspectFit
    case halfAspectFill
    
    var argumentsDisplayMode: PatternWallpaperArguments.DisplayMode {
        switch self {
        case .aspectFill:
            return .aspectFill
        case .aspectFit:
            return .aspectFit
        case .halfAspectFill:
            return .halfAspectFill
        }
    }
}

public struct WallpaperEdgeEffectEdge: Equatable {
    public enum Edge {
        case top
        case bottom
    }
    
    public var edge: Edge
    public var size: CGFloat
    
    public init(edge: Edge, size: CGFloat) {
        self.edge = edge
        self.size = size
    }
}

public protocol WallpaperEdgeEffectNode: ASDisplayNode {
    func update(rect: CGRect, edge: WallpaperEdgeEffectEdge, containerSize: CGSize, transition: ContainedViewLayoutTransition)
}

public protocol WallpaperBackgroundNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    var rotation: CGFloat { get set }

    func update(wallpaper: TelegramWallpaper, animated: Bool)
    func update(wallpaper: TelegramWallpaper, starGift: StarGift?, animated: Bool)
    func _internalUpdateIsSettingUpWallpaper()
    func updateLayout(size: CGSize, displayMode: WallpaperDisplayMode, transition: ContainedViewLayoutTransition)
    func updateIsLooping(_ isLooping: Bool)
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool)
    func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners)
    func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool
    func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode?
    func makeFreeBackground() -> PortalView?
    
    func hasExtraBubbleBackground() -> Bool
    
    func makeDimmedNode() -> ASDisplayNode?
    
    func makeEdgeEffectNode() -> WallpaperEdgeEffectNode?
}

private final class EffectImageLayer: SimpleLayer, GradientBackgroundPatternOverlayLayer {
    final class CloneLayer: SimpleLayer {
        private weak var parentLayer: EffectImageLayer?
        private var index: SparseBag<Weak<CloneLayer>>.Index?

        init(parentLayer: EffectImageLayer) {
            self.parentLayer = parentLayer

            super.init()
            
            self.index = parentLayer.cloneLayers.add(Weak(self))

            self.backgroundColor = parentLayer.backgroundColor
            self.contents = parentLayer.contents
            self.compositingFilter = parentLayer.compositingFilter
            self.opacity = parentLayer.opacity
            self.isOpaque = parentLayer.isOpaque
        }
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            if let parentLayer = self.parentLayer, let index = self.index {
                parentLayer.cloneLayers.remove(index)
            }
        }
    }
    
    enum SoftlightMode {
        case whileAnimating
        case always
        case never
    }
    
    var fillWithColorUntilLoaded: UIColor? {
        didSet {
            if self.fillWithColorUntilLoaded != oldValue {
                if let fillWithColorUntilLoaded = self.fillWithColorUntilLoaded {
                    if self.currentContents == nil {
                        self.backgroundColor = fillWithColorUntilLoaded.cgColor
                    } else {
                        self.backgroundColor = nil
                    }
                } else {
                    self.backgroundColor = nil
                }
                
                for cloneLayer in self.cloneLayers {
                    if let value = cloneLayer.value {
                        value.backgroundColor = self.backgroundColor
                    }
                }
            }
        }
    }
    
    var patternContentImage: UIImage? {
        didSet {
            if self.patternContentImage !== oldValue {
                self.updateComposedImage()
                self.updateContents()
            }
        }
    }
    
    var composedContentImage: UIImage? {
        didSet {
            if self.composedContentImage !== oldValue {
                self.updateContents()
            }
        }
    }
    
    var softlightMode: SoftlightMode = .whileAnimating {
        didSet {
            if self.softlightMode != oldValue {
                self.updateFilters()
            }
        }
    }
    
    var isAnimating: Bool = false {
        didSet {
            if self.isAnimating != oldValue {
                self.updateFilters()
            }
        }
    }
    
    private var isUsingSoftlight: Bool = false
    private var useFilter: Bool = false
    
    var suspendCompositionUpdates: Bool = false
    private var needsCompositionUpdate: Bool = false
    
    fileprivate let cloneLayers = SparseBag<Weak<CloneLayer>>()
    
    private func updateFilters() {
        let useSoftlight: Bool
        let useFilter: Bool
        switch self.softlightMode {
        case .whileAnimating:
            useSoftlight = self.isAnimating
            useFilter = useSoftlight
        case .always:
            useSoftlight = true
            useFilter = useSoftlight
        case .never:
            useSoftlight = true
            useFilter = false
        }
        if self.isUsingSoftlight != useSoftlight || self.useFilter != useFilter {
            self.isUsingSoftlight = useSoftlight
            self.useFilter = useFilter
            
            if self.isUsingSoftlight && self.useFilter {
                self.compositingFilter = "softLightBlendMode"
            } else {
                self.compositingFilter = nil
            }
            
            for cloneLayer in self.cloneLayers {
                if let value = cloneLayer.value {
                    value.compositingFilter = self.compositingFilter
                }
            }
            
            self.updateContents()
            self.updateOpacity()
        }
    }
    
    private var allowSettingContents: Bool = false
    private var currentContents: UIImage?
    
    override var contents: Any? {
        get {
            return super.contents
        } set(value) {
            if self.allowSettingContents {
                super.contents = value
            } else {
                assert(false)
            }
        }
    }
    
    private var allowSettingOpacity: Bool = false
    var compositionOpacity: Float = 1.0 {
        didSet {
            if self.compositionOpacity != oldValue {
                self.updateOpacity()
                self.updateComposedImage()
            }
        }
    }
    
    override var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if self.allowSettingOpacity {
                super.opacity = value
            } else {
                assert(false)
            }
        }
    }
    
    private var compositionData: (size: CGSize, backgroundImage: UIImage, backgroundImageHash: String)?
    
    func updateCompositionData(size: CGSize, backgroundImage: UIImage, backgroundImageHash: String) {
        if self.compositionData?.size == size && self.compositionData?.backgroundImage === backgroundImage {
            return
        }
        self.compositionData = (size, backgroundImage, backgroundImageHash)
        
        self.updateComposedImage()
    }
    
    func updateCompositionIfNeeded() {
        if self.needsCompositionUpdate {
            self.needsCompositionUpdate = false
            self.updateComposedImage()
        }
    }
    
    private static var cachedComposedImage: (size: CGSize, patternContentImage: UIImage, backgroundImageHash: String, image: UIImage)?
    
    private func updateComposedImage() {
        switch self.softlightMode {
        case .always, .never:
            return
        default:
            break
        }
        
        if self.suspendCompositionUpdates {
            self.needsCompositionUpdate = true
            return
        }
        
        guard let (size, backgroundImage, backgroundImageHash) = self.compositionData, let patternContentImage = self.patternContentImage else {
            return
        }
        
        if let cachedComposedImage = EffectImageLayer.cachedComposedImage, cachedComposedImage.size == size, cachedComposedImage.backgroundImageHash == backgroundImageHash, cachedComposedImage.patternContentImage === patternContentImage {
            self.composedContentImage = cachedComposedImage.image
            return
        }
        
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif
        
        let composedContentImage = generateImage(size, contextGenerator: { size, context in
            context.draw(backgroundImage.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            context.setBlendMode(.softLight)
            context.setAlpha(CGFloat(self.compositionOpacity))
            context.draw(patternContentImage.cgImage!, in: CGRect(origin: CGPoint(), size: size))
        }, opaque: true, scale: min(UIScreenScale, patternContentImage.scale))
        self.composedContentImage = composedContentImage
        
        #if DEBUG
        print("Wallpaper composed image updated in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        #endif
        
        if self.softlightMode == .whileAnimating, let composedContentImage = composedContentImage {
            EffectImageLayer.cachedComposedImage = (size, patternContentImage, backgroundImageHash, composedContentImage)
        }
    }
    
    private func updateContents() {
        var contents: UIImage?
        
        if self.isUsingSoftlight {
            contents = self.patternContentImage
        } else {
            contents = self.composedContentImage
        }
        
        if self.currentContents !== contents {
            self.currentContents = contents
            
            self.allowSettingContents = true
            self.contents = contents?.cgImage
            self.allowSettingContents = false
            
            self.backgroundColor = nil
            
            for cloneLayer in self.cloneLayers {
                if let value = cloneLayer.value {
                    value.contents = self.contents
                    value.backgroundColor = self.backgroundColor
                }
            }
        }
    }
    
    private func updateOpacity() {
        if self.isUsingSoftlight {
            self.allowSettingOpacity = true
            self.opacity = self.compositionOpacity
            self.allowSettingOpacity = false
            self.isOpaque = false
        } else {
            self.allowSettingOpacity = true
            self.opacity = 1.0
            self.allowSettingOpacity = false
            self.isOpaque = true
        }
        
        for cloneLayer in self.cloneLayers {
            if let value = cloneLayer.value {
                value.opacity = self.opacity
                value.isOpaque = self.isOpaque
            }
        }
    }
}

public final class WallpaperBackgroundNodeImpl: ASDisplayNode, WallpaperBackgroundNode {
    final class BubbleBackgroundNodeImpl: ASDisplayNode, WallpaperBubbleBackgroundNode {
        var implicitContentUpdate: Bool = true
        
        private let bubbleType: WallpaperBubbleType
        private let contentNode: ASImageNode

        private var cleanWallpaperNode: ASDisplayNode?
        private var gradientWallpaperNode: GradientBackgroundNode.CloneNode?
        private var overlayNode: ASDisplayNode?
        private weak var backgroundNode: WallpaperBackgroundNodeImpl?
        private var index: SparseBag<BubbleBackgroundNodeImpl>.Index?

        private var currentLayout: (rect: CGRect, containerSize: CGSize)?

        override var frame: CGRect {
            didSet {
                if oldValue.size != self.bounds.size {
                    if self.implicitContentUpdate  {
                        self.contentNode.frame = self.bounds
                        if let cleanWallpaperNode = self.cleanWallpaperNode {
                            cleanWallpaperNode.frame = self.bounds
                        }
                        if let gradientWallpaperNode = self.gradientWallpaperNode {
                            gradientWallpaperNode.frame = self.bounds
                        }
                    }
                }
            }
        }

        init(backgroundNode: WallpaperBackgroundNodeImpl, bubbleType: WallpaperBubbleType) {
            self.backgroundNode = backgroundNode
            self.bubbleType = bubbleType

            self.contentNode = ASImageNode()
            self.contentNode.displaysAsynchronously = false
            self.contentNode.isUserInteractionEnabled = false

            super.init()

            self.addSubnode(self.contentNode)

            self.index = backgroundNode.bubbleBackgroundNodeReferences.add(BubbleBackgroundNodeReference(node: self))
        }

        deinit {
            if let index = self.index, let backgroundNode = self.backgroundNode {
                backgroundNode.bubbleBackgroundNodeReferences.remove(index)
            }
        }

        func updateContents() {
            guard let backgroundNode = self.backgroundNode else {
                return
            }
            
            var overlayColor: UIColor?

            if let bubbleTheme = backgroundNode.bubbleTheme, let bubbleCorners = backgroundNode.bubbleCorners {
                let wallpaper = backgroundNode.wallpaper ?? bubbleTheme.chat.defaultWallpaper

                let graphics = PresentationResourcesChat.principalGraphics(theme: bubbleTheme, wallpaper: wallpaper, bubbleCorners: bubbleCorners)
                
                var needsCleanBackground = false
                switch self.bubbleType {
                case .incoming:
                    self.contentNode.image = graphics.incomingBubbleGradientImage
                    if graphics.incomingBubbleGradientImage == nil {
                        self.contentNode.backgroundColor = bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill[0]
                    } else {
                        self.contentNode.backgroundColor = nil
                    }
                    needsCleanBackground = bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill.contains(where: { $0.alpha <= 0.99 })
                case .outgoing:
                    if backgroundNode.outgoingBubbleGradientBackgroundNode != nil {
                        self.contentNode.image = nil
                        self.contentNode.backgroundColor = nil
                    } else {
                        self.contentNode.image = graphics.outgoingBubbleGradientImage
                        if graphics.outgoingBubbleGradientImage == nil {
                            self.contentNode.backgroundColor = bubbleTheme.chat.message.outgoing.bubble.withWallpaper.fill[0]
                        } else {
                            self.contentNode.backgroundColor = nil
                        }
                        needsCleanBackground = bubbleTheme.chat.message.outgoing.bubble.withWallpaper.fill.contains(where: { $0.alpha <= 0.99 })
                    }
                case .free:
                    self.contentNode.image = nil
                    self.contentNode.backgroundColor = nil
                    needsCleanBackground = true
                    
                    //if wallpaper.isBuiltin {
                        overlayColor = selectDateFillStaticColor(theme: bubbleTheme, wallpaper: wallpaper)
                    //}
                }

                var isInvertedGradient = false
                var hasComplexGradient = false
                switch wallpaper {
                case let .file(file):
                    hasComplexGradient = file.settings.colors.count >= 3
                    if let intensity = file.settings.intensity, intensity < 0 {
                        isInvertedGradient = true
                    }
                case let .gradient(gradient):
                    hasComplexGradient = gradient.colors.count >= 3
                default:
                    break
                }

                var needsGradientBackground = false
                var needsWallpaperBackground = false

                if isInvertedGradient {
                    switch self.bubbleType {
                    case .free:
                        self.contentNode.backgroundColor = bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill[0]
//                        needsCleanBackground = false
                    case .incoming, .outgoing:
                        break
                    }
                }

                if needsCleanBackground {
                    if hasComplexGradient {
                        needsGradientBackground = backgroundNode.gradientBackgroundNode != nil
                    } else {
                        needsWallpaperBackground = true
                    }
                }

                var gradientBackgroundSource: GradientBackgroundNode? = backgroundNode.gradientBackgroundNode

                if case .outgoing = self.bubbleType {
                    if let outgoingBubbleGradientBackgroundNode = backgroundNode.outgoingBubbleGradientBackgroundNode {
                        gradientBackgroundSource = outgoingBubbleGradientBackgroundNode
                        needsWallpaperBackground = false
                        needsGradientBackground = true
                    }
                }

                if needsWallpaperBackground {
                    if self.cleanWallpaperNode == nil {
                        let cleanWallpaperNode = ASImageNode()
                        cleanWallpaperNode.displaysAsynchronously = false
                        self.cleanWallpaperNode = cleanWallpaperNode
                        cleanWallpaperNode.frame = self.bounds
                        self.insertSubnode(cleanWallpaperNode, at: 0)
                    }
                    if let blurredBackgroundContents = backgroundNode.blurredBackgroundContents {
                        self.cleanWallpaperNode?.contents = blurredBackgroundContents.cgImage
                        self.cleanWallpaperNode?.backgroundColor = backgroundNode.contentNode.backgroundColor
                    } else {
                        self.cleanWallpaperNode?.contents = backgroundNode.contentNode.contents
                        self.cleanWallpaperNode?.backgroundColor = backgroundNode.contentNode.backgroundColor
                    }
                } else {
                    if let cleanWallpaperNode = self.cleanWallpaperNode {
                        self.cleanWallpaperNode = nil
                        cleanWallpaperNode.removeFromSupernode()
                    }
                }

                if needsGradientBackground, let gradientBackgroundNode = gradientBackgroundSource {
                    if self.gradientWallpaperNode == nil {
                        let gradientWallpaperNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode, isDimmed: true)
                        gradientWallpaperNode.frame = self.bounds
                        self.gradientWallpaperNode = gradientWallpaperNode
                        self.insertSubnode(gradientWallpaperNode, at: 0)
                    }
                } else {
                    if let gradientWallpaperNode = self.gradientWallpaperNode {
                        self.gradientWallpaperNode = nil
                        gradientWallpaperNode.removeFromSupernode()
                    }
                }
            } else {
                self.contentNode.image = nil
                if let cleanWallpaperNode = self.cleanWallpaperNode {
                    self.cleanWallpaperNode = nil
                    cleanWallpaperNode.removeFromSupernode()
                }
            }
            
            if let overlayColor {
                let overlayNode: ASDisplayNode
                if let current = self.overlayNode {
                    overlayNode = current
                } else {
                    overlayNode = ASDisplayNode()
                    overlayNode.frame = self.bounds
                    self.overlayNode = overlayNode
                    self.addSubnode(overlayNode)
                }
                overlayNode.backgroundColor = overlayColor
            } else if let overlayNode = self.overlayNode {
                self.overlayNode = nil
                overlayNode.removeFromSupernode()
            }

            if let (rect, containerSize) = self.currentLayout {
                self.update(rect: rect, within: containerSize)
            }
        }
        
        func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
            self.update(rect: rect, within: containerSize, delay: 0.0, transition: transition)
        }

        func update(rect: CGRect, within containerSize: CGSize, delay: Double = 0.0, transition: ContainedViewLayoutTransition = .immediate) {
            self.currentLayout = (rect, containerSize)

            let shiftedContentsRect = CGRect(origin: CGPoint(x: rect.minX / containerSize.width, y: rect.minY / containerSize.height), size: CGSize(width: rect.width / containerSize.width, height: rect.height / containerSize.height))

            transition.updateFrame(layer: self.contentNode.layer, frame: self.bounds, delay: delay)
            transition.animateView(delay: delay) {
                self.contentNode.layer.contentsRect = shiftedContentsRect
            }
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                transition.updateFrame(layer: cleanWallpaperNode.layer, frame: self.bounds, delay: delay)
                transition.animateView(delay: delay) {
                    cleanWallpaperNode.layer.contentsRect = shiftedContentsRect
                }
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                transition.updateFrame(layer: gradientWallpaperNode.layer, frame: self.bounds, delay: delay)
                transition.animateView(delay: delay) {
                    gradientWallpaperNode.layer.contentsRect = shiftedContentsRect
                }
            }
            if let overlayNode = self.overlayNode {
                transition.updateFrame(layer: overlayNode.layer, frame: self.bounds, delay: delay)
            }
        }
        
        func update(rect: CGRect, within containerSize: CGSize, animator: ControlledTransitionAnimator) {
            self.currentLayout = (rect, containerSize)

            let shiftedContentsRect = CGRect(origin: CGPoint(x: rect.minX / containerSize.width, y: rect.minY / containerSize.height), size: CGSize(width: rect.width / containerSize.width, height: rect.height / containerSize.height))

            animator.updateFrame(layer: self.contentNode.layer, frame: self.bounds, completion: nil)
            animator.updateContentsRect(layer: self.contentNode.layer, contentsRect: shiftedContentsRect, completion: nil)
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                animator.updateFrame(layer: cleanWallpaperNode.layer, frame: self.bounds, completion: nil)
                animator.updateContentsRect(layer: cleanWallpaperNode.layer, contentsRect: shiftedContentsRect, completion: nil)
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                animator.updateFrame(layer: gradientWallpaperNode.layer, frame: self.bounds, completion: nil)
                animator.updateContentsRect(layer: gradientWallpaperNode.layer, contentsRect: shiftedContentsRect, completion: nil)
            }
            if let overlayNode = self.overlayNode {
                animator.updateFrame(layer: overlayNode.layer, frame: self.bounds, completion: nil)
            }
        }

        func update(rect: CGRect, within containerSize: CGSize, transition: CombinedTransition) {
            self.currentLayout = (rect, containerSize)

            let shiftedContentsRect = CGRect(origin: CGPoint(x: rect.minX / containerSize.width, y: rect.minY / containerSize.height), size: CGSize(width: rect.width / containerSize.width, height: rect.height / containerSize.height))

            transition.updateFrame(layer: self.contentNode.layer, frame: self.bounds)
            self.contentNode.layer.contentsRect = shiftedContentsRect
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                transition.updateFrame(layer: cleanWallpaperNode.layer, frame: self.bounds)
                cleanWallpaperNode.layer.contentsRect = shiftedContentsRect
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                transition.updateFrame(layer: gradientWallpaperNode.layer, frame: self.bounds)
                gradientWallpaperNode.layer.contentsRect = shiftedContentsRect
            }
            if let overlayNode = self.overlayNode {
                transition.updateFrame(layer: overlayNode.layer, frame: self.bounds)
            }
        }

        func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
            guard let (_, containerSize) = self.currentLayout else {
                return
            }
            let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: animationCurve)

            let scaledOffset = CGPoint(x: value.x / containerSize.width, y: value.y / containerSize.height)
            transition.animateContentsRectPositionAdditive(layer: self.contentNode.layer, offset: scaledOffset)

            if let cleanWallpaperNode = self.cleanWallpaperNode {
                transition.animateContentsRectPositionAdditive(layer: cleanWallpaperNode.layer, offset: scaledOffset)
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                transition.animateContentsRectPositionAdditive(layer: gradientWallpaperNode.layer, offset: scaledOffset)
            }
        }

        func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
            guard let (_, containerSize) = self.currentLayout else {
                return
            }

            let scaledOffset = CGPoint(x: 0.0, y: -value / containerSize.height)

            self.contentNode.layer.animateSpring(from: NSValue(cgPoint: scaledOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "contentsRect.position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                cleanWallpaperNode.layer.animateSpring(from: NSValue(cgPoint: scaledOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "contentsRect.position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                gradientWallpaperNode.layer.animateSpring(from: NSValue(cgPoint: scaledOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "contentsRect.position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
            }
        }
        
        func reloadBindings() {
        }
    }
    
    final class BubbleBackgroundPortalNodeImpl: ASDisplayNode, WallpaperBubbleBackgroundNode {
        private let portalView: PortalView
        
        var implicitContentUpdate: Bool = true
        
        init(portalView: PortalView) {
            self.portalView = portalView
            
            super.init()
            
            self.view.addSubview(portalView.view)
            self.clipsToBounds = true
        }

        deinit {
        }
        
        func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
            if self.portalView.view.bounds.size != rect.size {
                transition.updateFrame(view: self.portalView.view, frame: CGRect(origin: CGPoint(), size: rect.size))
            }
        }

        func update(rect: CGRect, within containerSize: CGSize, delay: Double = 0.0, transition: ContainedViewLayoutTransition = .immediate) {
            if self.portalView.view.bounds.size != rect.size {
                transition.updateFrame(view: self.portalView.view, frame: CGRect(origin: CGPoint(), size: rect.size), delay: delay)
            }
        }
        
        func update(rect: CGRect, within containerSize: CGSize, animator: ControlledTransitionAnimator) {
            if self.portalView.view.bounds.size != rect.size {
                animator.updateFrame(layer: self.portalView.view.layer, frame: CGRect(origin: CGPoint(), size: rect.size), completion: nil)
            }
        }

        func update(rect: CGRect, within containerSize: CGSize, transition: CombinedTransition) {
            if self.portalView.view.bounds.size != rect.size {
                transition.updateFrame(layer: self.portalView.view.layer, frame: CGRect(origin: CGPoint(), size: rect.size))
            }
        }

        func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        }

        func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        }
        
        func reloadBindings() {
            self.portalView.reloadPortal()
        }
    }

    private final class BubbleBackgroundNodeReference {
        weak var node: BubbleBackgroundNodeImpl?

        init(node: BubbleBackgroundNodeImpl) {
            self.node = node
        }
    }

    private let context: AccountContext
    private let useSharedAnimationPhase: Bool
    
    private let contentNode: ASDisplayNode
    
    fileprivate let edgeEffectNodes = SparseBag<Weak<WallpaperEdgeEffectNodeImpl>>()
    
    private var blurredBackgroundContents: UIImage?
    
    private var freeBackgroundPortalSourceView: PortalSourceView?
    private var freeBackgroundNode: WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl? {
        didSet {
            if self.freeBackgroundNode !== oldValue {
                if let oldValue {
                    oldValue.view.removeFromSuperview()
                }
                if let freeBackgroundNode = self.freeBackgroundNode, let freeBackgroundPortalSourceView = self.freeBackgroundPortalSourceView {
                    freeBackgroundPortalSourceView.addSubview(freeBackgroundNode.view)
                    freeBackgroundNode.frame = CGRect(origin: CGPoint(), size: freeBackgroundPortalSourceView.bounds.size)
                }
            }
        }
    }
    
    private var incomingBackgroundPortalSourceView: PortalSourceView?
    private var incomingBackgroundNode: WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl? {
        didSet {
            if self.incomingBackgroundNode !== oldValue {
                if let oldValue {
                    oldValue.view.removeFromSuperview()
                }
                if let incomingBackgroundNode = self.incomingBackgroundNode, let incomingBackgroundPortalSourceView = self.incomingBackgroundPortalSourceView {
                    incomingBackgroundPortalSourceView.addSubview(incomingBackgroundNode.view)
                    incomingBackgroundNode.frame = CGRect(origin: CGPoint(), size: incomingBackgroundPortalSourceView.bounds.size)
                }
            }
        }
    }
    
    private var outgoingBackgroundPortalSourceView: PortalSourceView?
    private var outgoingBackgroundNode: WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl? {
        didSet {
            if self.outgoingBackgroundNode !== oldValue {
                if let oldValue {
                    oldValue.view.removeFromSuperview()
                }
                if let outgoingBackgroundNode = self.outgoingBackgroundNode, let outgoingBackgroundPortalSourceView = self.outgoingBackgroundPortalSourceView {
                    outgoingBackgroundPortalSourceView.addSubview(outgoingBackgroundNode.view)
                    outgoingBackgroundNode.frame = CGRect(origin: CGPoint(), size: outgoingBackgroundPortalSourceView.bounds.size)
                }
            }
        }
    }

    fileprivate var gradientBackgroundNode: GradientBackgroundNode?
    private var outgoingBubbleGradientBackgroundNode: GradientBackgroundNode?
    fileprivate let patternImageLayer: EffectImageLayer
    private let dimLayer: SimpleLayer
    private var isGeneratingPatternImage: Bool = false

    private var validLayout: (CGSize, WallpaperDisplayMode)?
    private var wallpaper: TelegramWallpaper?
    private var starGift: StarGift?
    private var modelRectIndex: Int32?
    
    private var modelStickerNode: DefaultAnimatedStickerNodeImpl?
    
    private var isSettingUpWallpaper: Bool = false

    private struct CachedValidPatternImage {
        let generate: (TransformImageArguments) -> DrawingContext?
        let generated: ValidPatternGeneratedImage
        let rects: [WallpaperGiftPatternRect]
        let starGift: StarGift?
        let symbolImage: UIImage?
        let modelRectIndex: Int32?
        let image: UIImage
    }

    private static var cachedValidPatternImage: CachedValidPatternImage?

    private struct ValidPatternImage {
        let wallpaper: TelegramWallpaper
        let invertPattern: Bool
        let rects: [WallpaperGiftPatternRect]
        let starGift: StarGift?
        let symbolImage: UIImage?
        let modelRectIndex: Int32?
        let generate: (TransformImageArguments) -> DrawingContext?
    }
    private var validPatternImage: ValidPatternImage?

    private struct ValidPatternGeneratedImage: Equatable {
        let wallpaper: TelegramWallpaper
        let size: CGSize
        let patternColor: UInt32
        let backgroundColor: UInt32
        let invertPattern: Bool
        let starGift: StarGift?
        let modelRectIndex: Int32?
        
        public static func ==(lhs: ValidPatternGeneratedImage, rhs: ValidPatternGeneratedImage) -> Bool {
            if lhs.wallpaper != rhs.wallpaper {
                return false
            }
            if lhs.size != rhs.size {
                return false
            }
            if lhs.patternColor != rhs.patternColor {
                return false
            }
            if lhs.backgroundColor != rhs.backgroundColor {
                return false
            }
            if lhs.invertPattern != rhs.invertPattern {
                return false
            }
            if lhs.starGift?.slug != rhs.starGift?.slug {
                return false
            }
            if lhs.modelRectIndex != rhs.modelRectIndex {
                return false
            }
            return true
        }
    }
    private var validPatternGeneratedImage: ValidPatternGeneratedImage?

    private let patternImageDisposable = MetaDisposable()
    private let symbolImageDisposable = MetaDisposable()

    private var bubbleTheme: PresentationTheme?
    private var bubbleCorners: PresentationChatBubbleCorners?
    private var bubbleBackgroundNodeReferences = SparseBag<BubbleBackgroundNodeReference>()

    private let wallpaperDisposable = MetaDisposable()

    private let imageDisposable = MetaDisposable()
    
    private var motionEnabled: Bool = false {
        didSet {
            if oldValue != self.motionEnabled {
                if self.motionEnabled {
                    let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
                    horizontal.minimumRelativeValue = motionAmount
                    horizontal.maximumRelativeValue = -motionAmount
                    
                    let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
                    vertical.minimumRelativeValue = motionAmount
                    vertical.maximumRelativeValue = -motionAmount
                    
                    let group = UIMotionEffectGroup()
                    group.motionEffects = [horizontal, vertical]
                    self.contentNode.view.addMotionEffect(group)
                } else {
                    for effect in self.contentNode.view.motionEffects {
                        self.contentNode.view.removeMotionEffect(effect)
                    }
                }
                if !self.frame.isEmpty {
                    self.updateScale()
                }
            }
        }
    }
    
    public var rotation: CGFloat = 0.0 {
        didSet {
            var fromValue: CGFloat = 0.0
            if let value = (self.layer.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.floatValue {
                fromValue = CGFloat(value)
            }
            self.contentNode.layer.transform = CATransform3DMakeRotation(self.rotation, 0.0, 0.0, 1.0)
            self.contentNode.layer.animateRotation(from: fromValue, to: self.rotation, duration: 0.3)
        }
    }
    
    private var imageContentMode: UIView.ContentMode {
        didSet {
            self.contentNode.contentMode = self.imageContentMode
        }
    }
    
    private func updateScale() {
        if self.motionEnabled {
            let scale = (self.frame.width + motionAmount * 2.0) / self.frame.width
            self.contentNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
        } else {
            self.contentNode.transform = CATransform3DIdentity
        }
    }

    private struct PatternKey: Equatable {
        var mediaId: EngineMedia.Id
        var isLight: Bool
    }
    private static var cachedSharedPattern: (PatternKey, UIImage)?
    
    private let _isReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isReady: Signal<Bool, NoError> {
        return self._isReady.get()
    }
        
    init(context: AccountContext, useSharedAnimationPhase: Bool) {
        self.context = context
        self.useSharedAnimationPhase = useSharedAnimationPhase
        self.imageContentMode = .scaleAspectFill
        
        self.contentNode = ASDisplayNode()
        self.contentNode.contentMode = self.imageContentMode

        self.patternImageLayer = EffectImageLayer()

        self.dimLayer = SimpleLayer()
        self.dimLayer.opacity = 0.0
        self.dimLayer.backgroundColor = UIColor.black.cgColor
        
        super.init()
        
        if #available(iOS 12.0, *) {
            let freeBackgroundPortalSourceView = PortalSourceView()
            self.freeBackgroundPortalSourceView = freeBackgroundPortalSourceView
            freeBackgroundPortalSourceView.alpha = 0.0
            self.view.addSubview(freeBackgroundPortalSourceView)
            
            let incomingBackgroundPortalSourceView = PortalSourceView()
            self.incomingBackgroundPortalSourceView = incomingBackgroundPortalSourceView
            incomingBackgroundPortalSourceView.alpha = 0.0
            self.view.addSubview(incomingBackgroundPortalSourceView)
            
            let outgoingBackgroundPortalSourceView = PortalSourceView()
            self.outgoingBackgroundPortalSourceView = outgoingBackgroundPortalSourceView
            outgoingBackgroundPortalSourceView.alpha = 0.0
            self.view.addSubview(outgoingBackgroundPortalSourceView)
        }
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        self.addSubnode(self.contentNode)
        self.layer.addSublayer(self.patternImageLayer)
        
        self.layer.addSublayer(self.dimLayer)
    }

    deinit {
        self.patternImageDisposable.dispose()
        self.wallpaperDisposable.dispose()
        self.imageDisposable.dispose()
    }
    
    private func updateDimming() {
        guard let wallpaper = self.wallpaper, let theme = self.bubbleTheme else {
            return
        }
        var dimAlpha: Float = 0.0
        if theme.overallDarkAppearance == true {
            var intensity: Int32?
            switch wallpaper {
            case let .image(_, settings):
                intensity = settings.intensity
            case let .file(file):
                if !file.isPattern {
                    intensity = file.settings.intensity
                }
            default:
                break
            }
            if let intensity, intensity > 0 {
                dimAlpha = max(0.0, min(1.0, Float(intensity) / 100.0))
            }
        }
        self.dimLayer.opacity = dimAlpha
    }

    public func update(wallpaper: TelegramWallpaper, animated: Bool) {
        self.update(wallpaper: wallpaper, starGift: nil, animated: animated)
    }
    
    public func update(wallpaper: TelegramWallpaper, starGift: StarGift?, animated: Bool) {
        if self.wallpaper == wallpaper && self.starGift == starGift {
            return
        }
        let previousWallpaper = self.wallpaper
        let previousStarGift = self.starGift
        
        self.wallpaper = wallpaper
        self.starGift = starGift
                
        if previousWallpaper != wallpaper || previousStarGift?.slug != starGift?.slug {
            if let _ = starGift {
                self.modelRectIndex = Int32.random(in: 0 ..< 10)
            } else {
                self.modelRectIndex = nil
            }
        }
        
        if let _ = previousWallpaper, animated {
            if let snapshotView = self.view.snapshotView(afterScreenUpdates: false) {
                self.view.addSubview(snapshotView)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
            }
        }
        
        var gradientColors: [UInt32] = []
        var gradientAngle: Int32 = 0
        
        let wallpaperDimColor: UIColor? = nil

        if case let .color(color) = wallpaper {
            gradientColors = [color]
            self._isReady.set(true)
        } else if case let .gradient(gradient) = wallpaper {
            gradientColors = gradient.colors
            gradientAngle = gradient.settings.rotation ?? 0
            self._isReady.set(true)
        } else if case let .file(file) = wallpaper, file.isPattern {
            gradientColors = file.settings.colors
            gradientAngle = file.settings.rotation ?? 0
        }
        
        var scheduleLoopingEvent = false
        if gradientColors.count >= 3 {
            let mappedColors = gradientColors.map { color -> UIColor in
                return UIColor(rgb: color)
            }
            if self.gradientBackgroundNode == nil {
                let gradientBackgroundNode = createGradientBackgroundNode(colors: mappedColors, useSharedAnimationPhase: self.useSharedAnimationPhase)
                self.gradientBackgroundNode = gradientBackgroundNode
                self.insertSubnode(gradientBackgroundNode, aboveSubnode: self.contentNode)
                gradientBackgroundNode.setPatternOverlay(layer: self.patternImageLayer)
                
                if self.isLooping {
                    scheduleLoopingEvent = true
                }
                
                for edgeEffectNode in self.edgeEffectNodes {
                    if let edgeEffectNode = edgeEffectNode.value {
                        edgeEffectNode.updateGradientNode()
                    }
                }
            }
            self.gradientBackgroundNode?.updateColors(colors: mappedColors)

            self.contentNode.backgroundColor = nil
            self.contentNode.contents = nil
            self.blurredBackgroundContents = nil
            self.motionEnabled = false
            self.wallpaperDisposable.set(nil)
        } else {
            if let gradientBackgroundNode = self.gradientBackgroundNode {
                self.gradientBackgroundNode = nil
                gradientBackgroundNode.removeFromSupernode()
                gradientBackgroundNode.setPatternOverlay(layer: nil)
                self.layer.insertSublayer(self.patternImageLayer, above: self.contentNode.layer)
            }

            self.motionEnabled = wallpaper.settings?.motion ?? false

            if gradientColors.count >= 2 {
                self.contentNode.backgroundColor = nil
                let image = generateImage(CGSize(width: 100.0, height: 200.0), rotatedContext: { size, context in
                    let gradientColors = [UIColor(rgb: gradientColors[0]).cgColor, UIColor(rgb: gradientColors[1]).cgColor] as CFArray

                    var locations: [CGFloat] = [0.0, 1.0]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.rotate(by: CGFloat(gradientAngle) * CGFloat.pi / 180.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                })
                self.contentNode.contents = image?.cgImage
                self.blurredBackgroundContents = image
                self.wallpaperDisposable.set(nil)
            } else if gradientColors.count >= 1 {
                self.contentNode.backgroundColor = UIColor(rgb: gradientColors[0])
                self.contentNode.contents = nil
                self.blurredBackgroundContents = nil
                self.wallpaperDisposable.set(nil)
            } else {
                self.contentNode.backgroundColor = .white
                if let image = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: self.context.sharedContext.accountManager.mediaBox, knockoutMode: false) {
                    self.contentNode.contents = image.cgImage
                    self.blurredBackgroundContents = generateBlurredContents(image: image, dimColor: wallpaperDimColor)
                    self.wallpaperDisposable.set(nil)
                    Queue.mainQueue().justDispatch {
                        self._isReady.set(true)
                    }
                } else if let image = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: self.context.account.postbox.mediaBox, knockoutMode: false) {
                    self.contentNode.contents = image.cgImage
                    self.blurredBackgroundContents = generateBlurredContents(image: image, dimColor: wallpaperDimColor)
                    self.wallpaperDisposable.set(nil)
                    Queue.mainQueue().justDispatch {
                        self._isReady.set(true)
                    }
                } else {
                    self.wallpaperDisposable.set((chatControllerBackgroundImageSignal(wallpaper: wallpaper, mediaBox: self.context.sharedContext.accountManager.mediaBox, accountMediaBox: self.context.account.postbox.mediaBox)
                    |> deliverOnMainQueue).start(next: { [weak self] image in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.contentNode.contents = image?.0?.cgImage
                        if let image = image?.0 {
                            strongSelf.blurredBackgroundContents = generateBlurredContents(image: image, dimColor: wallpaperDimColor)
                        } else {
                            strongSelf.blurredBackgroundContents = nil
                        }
                        strongSelf.updateBubbles()
                        strongSelf._isReady.set(true)
                    }))
                }
                self.contentNode.isHidden = false
            }
        }
        
        if self.hasBubbleBackground(for: .free) {
            self.freeBackgroundNode = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: .free)
        } else {
            self.freeBackgroundNode = nil
        }
        
        if self.hasBubbleBackground(for: .incoming) {
            self.incomingBackgroundNode = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: .incoming)
        } else {
            self.incomingBackgroundNode = nil
        }
        
        if self.hasBubbleBackground(for: .outgoing) {
            self.outgoingBackgroundNode = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: .outgoing)
        } else {
            self.outgoingBackgroundNode = nil
        }

        if let (size, displayMode) = self.validLayout {
            self.updateLayout(size: size, displayMode: displayMode, transition: .immediate)
            
            if scheduleLoopingEvent {
                self.animateEvent(transition: .animated(duration: 0.7, curve: .linear), extendAnimation: false)
            }
        }
        self.updateBubbles()
        
        self.updateDimming()
    }

    public func _internalUpdateIsSettingUpWallpaper() {
        self.isSettingUpWallpaper = true
    }

    private func updatePatternPresentation() {
        guard let wallpaper = self.wallpaper else {
            return
        }

        switch wallpaper {
        case let .file(file) where file.isPattern:
            let brightness = UIColor.average(of: file.settings.colors.map(UIColor.init(rgb:))).hsb.b
            let patternIsBlack = brightness <= 0.01

            let intensity = CGFloat(file.settings.intensity ?? 50) / 100.0
            if intensity < 0 {
                self.patternImageLayer.compositionOpacity = 1.0
                self.patternImageLayer.softlightMode = .never
            } else {
                self.patternImageLayer.compositionOpacity = Float(intensity)
                if patternIsBlack {
                    self.patternImageLayer.softlightMode = .never
                } else {
                    if self.useSharedAnimationPhase && file.settings.colors.count > 2 {
                        self.patternImageLayer.softlightMode = .whileAnimating
                    } else {
                        self.patternImageLayer.softlightMode = .always
                    }
                }
            }
            
            self.patternImageLayer.isHidden = false
            let invertPattern = intensity < 0
            
            self.patternImageLayer.fillWithColorUntilLoaded = invertPattern ? .black : nil
            
            if invertPattern {
                self.backgroundColor = .black
                let contentAlpha = abs(intensity)
                self.gradientBackgroundNode?.contentView.alpha = contentAlpha
                self.contentNode.alpha = contentAlpha
            } else {
                self.backgroundColor = nil
                self.gradientBackgroundNode?.contentView.alpha = 1.0
                self.contentNode.alpha = 1.0
                self.patternImageLayer.backgroundColor = nil
            }
            
            for edgeEffectNode in self.edgeEffectNodes {
                if let edgeEffectNode = edgeEffectNode.value {
                    edgeEffectNode.updatePattern(isInverted: invertPattern)
                }
            }
        default:
            self.patternImageDisposable.set(nil)
            self.symbolImageDisposable.set(nil)
            self.validPatternImage = nil
            self.patternImageLayer.isHidden = true
            self.patternImageLayer.fillWithColorUntilLoaded = nil
            self.patternImageLayer.backgroundColor = nil
            self.backgroundColor = nil
            self.gradientBackgroundNode?.contentView.alpha = 1.0
            self.contentNode.alpha = 1.0
            
            for edgeEffectNode in self.edgeEffectNodes {
                if let edgeEffectNode = edgeEffectNode.value {
                    edgeEffectNode.updatePattern(isInverted: false)
                }
            }
        }
    }

    private func loadPatternForSizeIfNeeded(size: CGSize, displayMode: WallpaperDisplayMode, transition: ContainedViewLayoutTransition) {
        guard let wallpaper = self.wallpaper else {
            return
        }
        
        let starGift = self.starGift
        let modelRectIndex = self.modelRectIndex

        var invertPattern: Bool = false
        var patternIsLight: Bool = false

        switch wallpaper {
        case let .file(file) where file.isPattern:
            var updated = true
            let brightness = UIColor.average(of: file.settings.colors.map(UIColor.init(rgb:))).hsb.b
            patternIsLight = brightness > 0.3
            
            let intensity = CGFloat(file.settings.intensity ?? 50) / 100.0
            invertPattern = intensity < 0
            
            if let previousWallpaper = self.validPatternImage?.wallpaper {
                switch previousWallpaper {
                case let .file(previousFile):
                    if file.file.id == previousFile.file.id && self.validPatternImage?.invertPattern == invertPattern {
                        updated = false
                    }
                default:
                    break
                }
            }
            
            if let previousStarGift = self.validPatternImage?.starGift, !updated {
                updated = true
                if previousStarGift.slug == starGift?.slug {
                    updated = false
                }
            }

            if updated {
                self.validPatternGeneratedImage = nil
                self.validPatternImage = nil

                if let cachedValidPatternImage = WallpaperBackgroundNodeImpl.cachedValidPatternImage, cachedValidPatternImage.generated.wallpaper == wallpaper && cachedValidPatternImage.generated.invertPattern == invertPattern && cachedValidPatternImage.starGift == starGift && cachedValidPatternImage.modelRectIndex == modelRectIndex {
                    self.validPatternImage = ValidPatternImage(wallpaper: cachedValidPatternImage.generated.wallpaper, invertPattern: invertPattern, rects: cachedValidPatternImage.rects, starGift: cachedValidPatternImage.starGift, symbolImage: cachedValidPatternImage.symbolImage, modelRectIndex: cachedValidPatternImage.modelRectIndex, generate: cachedValidPatternImage.generate)
                } else {
                    func reference(for resource: EngineMediaResource, media: EngineMedia) -> MediaResourceReference {
                        return .wallpaper(wallpaper: .slug(file.slug), resource: resource._asResource())
                    }

                    var convertedRepresentations: [ImageRepresentationWithReference] = []
                    for representation in file.file.previewRepresentations {
                        convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: EngineMediaResource(representation.resource), media: EngineMedia(file.file))))
                    }
                    let dimensions = file.file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false), reference: reference(for: EngineMediaResource(file.file.resource), media: EngineMedia(file.file))))

                    let signal = patternWallpaperImage(account: self.context.account, accountManager: self.context.sharedContext.accountManager, representations: convertedRepresentations, mode: .screen, autoFetchFullSize: true)
                    var symbolImage: Signal<UIImage?, NoError> = .single(nil)
                    if let starGift = self.starGift, case let .unique(uniqueGift) = starGift {
                        for attribute in uniqueGift.attributes {
                            if case let .pattern(_, file, _) = attribute, let dimensions = file.dimensions {
                                let size = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                                symbolImage = chatMessageAnimatedSticker(postbox: self.context.account.postbox, userLocation: .other, file: file, small: false, size: size)
                                |> map { generator -> UIImage? in
                                    return generator(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: .zero))?.generateImage()
                                }
                                break
                            }
                        }
                    }
                    self.patternImageDisposable.set(combineLatest(queue: Queue.mainQueue(), signal, symbolImage).start(next: { [weak self] generator, symbolImage in
                        guard let self else {
                            return
                        }
                        if let (generator, rects) = generator {
                            self.validPatternImage = ValidPatternImage(wallpaper: wallpaper, invertPattern: invertPattern, rects: rects, starGift: starGift, symbolImage: symbolImage, modelRectIndex: modelRectIndex, generate: generator)
                            self.validPatternGeneratedImage = nil
                            if let (size, displayMode) = self.validLayout {
                                self.loadPatternForSizeIfNeeded(size: size, displayMode: displayMode, transition: .immediate)
                            } else {
                                self._isReady.set(true)
                            }
                        } else {
                            self._isReady.set(true)
                        }
                    }))
                }
            }
        default:
            self.updatePatternPresentation()
        }

        if let validPatternImage = self.validPatternImage {
            let patternBackgroundColor: UIColor
            let patternColor: UIColor
            if invertPattern {
                patternColor = .clear
                patternBackgroundColor = .clear
            } else {
                if patternIsLight {
                    patternColor = .black
                } else {
                    patternColor = .white
                }
                patternBackgroundColor = .clear
                self.patternImageLayer.backgroundColor = nil
            }

            let updatedGeneratedImage = ValidPatternGeneratedImage(wallpaper: validPatternImage.wallpaper, size: size, patternColor: patternColor.rgb, backgroundColor: patternBackgroundColor.rgb, invertPattern: invertPattern, starGift: starGift, modelRectIndex: modelRectIndex)
            
            if self.validPatternGeneratedImage != updatedGeneratedImage {
                self.validPatternGeneratedImage = updatedGeneratedImage

                if let cachedValidPatternImage = WallpaperBackgroundNodeImpl.cachedValidPatternImage, cachedValidPatternImage.generated == updatedGeneratedImage {
                    self.patternImageLayer.suspendCompositionUpdates = true
                    self.updatePatternPresentation()
                    self.patternImageLayer.patternContentImage = cachedValidPatternImage.image
                    self.patternImageLayer.suspendCompositionUpdates = false
                    self.patternImageLayer.updateCompositionIfNeeded()
                } else {
                    let patternArguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: PatternWallpaperArguments(colors: [patternBackgroundColor], rotation: nil, customPatternColor: patternColor, preview: false, displayMode: displayMode.argumentsDisplayMode, symbolImage: generateTintedImage(image: validPatternImage.symbolImage, color: .white), modelRectIndex: self.modelRectIndex), scale: min(2.0, UIScreenScale))
                    if self.useSharedAnimationPhase || self.patternImageLayer.contents == nil {
                        if let drawingContext = validPatternImage.generate(patternArguments) {
                            if let image = drawingContext.generateImage() {
                                self.patternImageLayer.suspendCompositionUpdates = true
                                self.updatePatternPresentation()
                                self.patternImageLayer.patternContentImage = image
                                self.patternImageLayer.suspendCompositionUpdates = false
                                self.patternImageLayer.updateCompositionIfNeeded()

                                if self.useSharedAnimationPhase {
                                    WallpaperBackgroundNodeImpl.cachedValidPatternImage = CachedValidPatternImage(generate: validPatternImage.generate, generated: updatedGeneratedImage, rects: validPatternImage.rects, starGift: validPatternImage.starGift, symbolImage: validPatternImage.symbolImage, modelRectIndex: validPatternImage.modelRectIndex, image: image)
                                }
                            } else {
                                self.updatePatternPresentation()
                            }
                        } else {
                            self.updatePatternPresentation()
                        }
                    } else {
                        self.isGeneratingPatternImage = true
                        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                            let image = validPatternImage.generate(patternArguments)?.generateImage()
                            Queue.mainQueue().async {
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.isGeneratingPatternImage = false
                                strongSelf.patternImageLayer.patternContentImage = image
                                strongSelf.updatePatternPresentation()

                                if let image = image, strongSelf.useSharedAnimationPhase {
                                    WallpaperBackgroundNodeImpl.cachedValidPatternImage = CachedValidPatternImage(generate: validPatternImage.generate, generated: updatedGeneratedImage, rects: validPatternImage.rects, starGift: validPatternImage.starGift, symbolImage: validPatternImage.symbolImage, modelRectIndex: validPatternImage.modelRectIndex, image: image)
                                }
                            }
                        }
                    }
                }

                self._isReady.set(true)
            } else {
                if !self.isGeneratingPatternImage {
                    self.updatePatternPresentation()
                }
            }
        } else {
            if !self.isGeneratingPatternImage {
                self.updatePatternPresentation()
            }
        }
        
        var modelFile: TelegramMediaFile?
        if let validPatternImage = self.validPatternImage, !validPatternImage.rects.isEmpty, let starGift = validPatternImage.starGift {
            if case let .unique(uniqueGift) = starGift {
                for attribute in uniqueGift.attributes {
                    if case let .model(_, file, _) = attribute {
                        modelFile = file
                    }
                }
            }
        }
        if let validPatternImage = self.validPatternImage, !validPatternImage.rects.isEmpty, var modelRectIndex = self.modelRectIndex, let modelFile {
            let filteredRects = validPatternImage.rects.filter { $0.center.y > $0.containerSize.height * 0.1 && $0.center.y < $0.containerSize.height * 0.9 }
            modelRectIndex = modelRectIndex % Int32(filteredRects.count);
            
            let rect = filteredRects[Int(modelRectIndex)]
            
            let modelStickerNode: DefaultAnimatedStickerNodeImpl
            if let current = self.modelStickerNode {
                modelStickerNode = current
            } else {
                modelStickerNode = DefaultAnimatedStickerNodeImpl()
                modelStickerNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: modelFile.resource, isVideo: false), width: 96, height: 96, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                modelStickerNode.visibility = true
                self.modelStickerNode = modelStickerNode
                self.addSubnode(modelStickerNode)
            }
            
            let targetSize: CGSize = self.bounds.size
            let containerSize: CGSize = rect.containerSize
            
            let isAspectFit: Bool = (displayMode == .aspectFit || displayMode == .halfAspectFill)
            
            let renderScale: CGFloat = isAspectFit
            ? min(targetSize.width / containerSize.width, targetSize.height / containerSize.height)
            : max(targetSize.width / containerSize.width, targetSize.height / containerSize.height)
            
            let drawingSize = CGSize(width: containerSize.width * renderScale, height: containerSize.height * renderScale)
            
            let offsetX: CGFloat
            let offsetY: CGFloat
            if isAspectFit {
                offsetX = 0.0
                offsetY = (targetSize.height - drawingSize.height) * 0.5
            } else {
                offsetX = (targetSize.width  - drawingSize.width)  * 0.5
                offsetY = (targetSize.height - drawingSize.height) * 0.5
            }
            
            let onScreenCenter = CGPoint(x: offsetX + rect.center.x * renderScale, y: offsetY + rect.center.y * renderScale)
            
            let side = rect.side * rect.scale * renderScale
            modelStickerNode.bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
            modelStickerNode.position = onScreenCenter
            modelStickerNode.updateLayout(size: modelStickerNode.bounds.size)
            modelStickerNode.alpha = 0.5
            
            modelStickerNode.layer.transform = CATransform3DMakeRotation(rect.rotation, 0, 0, 1)
        } else {
            if let modelStickerNode = self.modelStickerNode {
                self.modelStickerNode = nil
                if transition.isAnimated {
                    modelStickerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak modelStickerNode] _ in
                        modelStickerNode?.removeFromSupernode()
                    })
                } else {
                    modelStickerNode.removeFromSupernode()
                }
            }
        }

        transition.updateFrame(layer: self.patternImageLayer, frame: CGRect(origin: CGPoint(), size: size))
    }
    
    public func updateLayout(size: CGSize, displayMode: WallpaperDisplayMode, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (size, displayMode)
        
        if let freeBackgroundPortalSourceView = self.freeBackgroundPortalSourceView {
            transition.updateFrame(view: freeBackgroundPortalSourceView, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        if let incomingBackgroundPortalSourceView = self.incomingBackgroundPortalSourceView {
            transition.updateFrame(view: incomingBackgroundPortalSourceView, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        if let outgoingBackgroundPortalSourceView = self.outgoingBackgroundPortalSourceView {
            transition.updateFrame(view: outgoingBackgroundPortalSourceView, frame: CGRect(origin: CGPoint(), size: size))
        }

        transition.updatePosition(node: self.contentNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateBounds(node: self.contentNode, bounds: CGRect(origin: CGPoint(), size: size))

        if let gradientBackgroundNode = self.gradientBackgroundNode {
            transition.updateFrame(node: gradientBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            gradientBackgroundNode.updateLayout(size: size, transition: transition, extendAnimation: false, backwards: false, completion: {})
        }

        if let outgoingBubbleGradientBackgroundNode = self.outgoingBubbleGradientBackgroundNode {
            transition.updateFrame(node: outgoingBubbleGradientBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            outgoingBubbleGradientBackgroundNode.updateLayout(size: size, transition: transition, extendAnimation: false, backwards: false, completion: {})
        }
        
        if let freeBackgroundNode = self.freeBackgroundNode {
            transition.updateFrame(node: freeBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            freeBackgroundNode.update(rect: CGRect(origin: CGPoint(), size: size), within: size, transition: transition)
        }
        
        if let incomingBackgroundNode = self.incomingBackgroundNode {
            transition.updateFrame(node: incomingBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            incomingBackgroundNode.update(rect: CGRect(origin: CGPoint(), size: size), within: size, transition: transition)
        }
        
        if let outgoingBackgroundNode = self.outgoingBackgroundNode {
            transition.updateFrame(node: outgoingBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            outgoingBackgroundNode.update(rect: CGRect(origin: CGPoint(), size: size), within: size, transition: transition)
        }
        
        transition.updateFrame(layer: self.dimLayer, frame: CGRect(origin: CGPoint(), size: size))

        self.loadPatternForSizeIfNeeded(size: size, displayMode: displayMode, transition: transition)
                
        if isFirstLayout && !self.frame.isEmpty {
            self.updateScale()
        }
    }

    private var isAnimating = false
    private var isLooping = false
    
    public func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {
        guard !(self.isLooping && self.isAnimating) else {
            return
        }
        self.isAnimating = true
        self.gradientBackgroundNode?.animateEvent(transition: transition, extendAnimation: extendAnimation, backwards: false, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.isAnimating = false
                if strongSelf.isLooping && strongSelf.validLayout != nil {
                    strongSelf.animateEvent(transition: transition, extendAnimation: extendAnimation)
                }
            }
        })
        self.outgoingBubbleGradientBackgroundNode?.animateEvent(transition: transition, extendAnimation: extendAnimation, backwards: false, completion: {})
    }

    public func updateIsLooping(_ isLooping: Bool) {
        let wasLooping = self.isLooping
        self.isLooping = isLooping
        
        if isLooping && !wasLooping {
            self.animateEvent(transition: .animated(duration: 0.7, curve: .linear), extendAnimation: false)
        }
    }
    
    public func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        if self.bubbleTheme !== bubbleTheme || self.bubbleCorners != bubbleCorners {
            self.bubbleTheme = bubbleTheme
            self.bubbleCorners = bubbleCorners

            if bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill.count >= 3 && bubbleTheme.chat.animateMessageColors {
                if self.outgoingBubbleGradientBackgroundNode == nil {
                    let outgoingBubbleGradientBackgroundNode = GradientBackgroundNode(adjustSaturation: false)
                    if let (size, _) = self.validLayout {
                        outgoingBubbleGradientBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                        outgoingBubbleGradientBackgroundNode.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
                    }
                    self.outgoingBubbleGradientBackgroundNode = outgoingBubbleGradientBackgroundNode
                }
                self.outgoingBubbleGradientBackgroundNode?.updateColors(colors: bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill)
            } else if let _ = self.outgoingBubbleGradientBackgroundNode {
                self.outgoingBubbleGradientBackgroundNode = nil
            }
            
            if self.hasBubbleBackground(for: .free) {
                self.freeBackgroundNode = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: .free)
            } else {
                self.freeBackgroundNode = nil
            }
            
            if self.hasBubbleBackground(for: .incoming) {
                self.incomingBackgroundNode = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: .incoming)
            } else {
                self.incomingBackgroundNode = nil
            }
            
            if self.hasBubbleBackground(for: .outgoing) {
                self.outgoingBackgroundNode = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: .outgoing)
            } else {
                self.outgoingBackgroundNode = nil
            }

            self.updateBubbles()
            self.updateDimming()
        }
    }

    private func updateBubbles() {
        for reference in self.bubbleBackgroundNodeReferences {
            reference.node?.updateContents()
        }
    }

    public func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool {
        guard let bubbleTheme = self.bubbleTheme, let bubbleCorners = self.bubbleCorners else {
            return false
        }
        if self.wallpaper == nil && !self.isSettingUpWallpaper {
            return false
        }

        var hasPlainWallpaper = false
        let graphicsWallpaper: TelegramWallpaper
        if let wallpaper = self.wallpaper {
            switch wallpaper {
            case .color:
                hasPlainWallpaper = true
            default:
                break
            }
            graphicsWallpaper = wallpaper
        } else {
            graphicsWallpaper = bubbleTheme.chat.defaultWallpaper
        }

        let graphics = PresentationResourcesChat.principalGraphics(theme: bubbleTheme, wallpaper: graphicsWallpaper, bubbleCorners: bubbleCorners)
        switch type {
        case .incoming:
            if graphics.incomingBubbleGradientImage != nil {
                return true
            }
            if bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill.contains(where: { $0.alpha <= 0.99 }) {
                return !hasPlainWallpaper
            }
        case .outgoing:
            if graphics.outgoingBubbleGradientImage != nil {
                return true
            }
            if bubbleTheme.chat.message.outgoing.bubble.withWallpaper.fill.contains(where: { $0.alpha <= 0.99 }) {
                return !hasPlainWallpaper
            }
        case .free:
            return true
        }

        return false
    }
    
    public func makeLegacyBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? {
        let node = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: type)
        node.updateContents()
        return node
    }

    public func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? {
        if !self.hasBubbleBackground(for: type) {
            return nil
        }
        
        var sourceView: PortalSourceView?
        switch type {
        case .free:
            sourceView = self.freeBackgroundPortalSourceView
        case .incoming:
            sourceView = self.incomingBackgroundPortalSourceView
        case .outgoing:
            sourceView = self.outgoingBackgroundPortalSourceView
        }
        
        if let sourceView, let portalView = PortalView(matchPosition: true) {
            sourceView.addPortal(view: portalView)
            let node = WallpaperBackgroundNodeImpl.BubbleBackgroundPortalNodeImpl(portalView: portalView)
            return node
        } else {
            let node = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: type)
            return node
        }
    }
    
    public func makeFreeBackground() -> PortalView? {
        if !self.hasBubbleBackground(for: .free) {
            return nil
        }
        
        if let sourceView = self.freeBackgroundPortalSourceView, let portalView = PortalView(matchPosition: true) {
            sourceView.addPortal(view: portalView)
            return portalView
        } else {
            return nil
        }
    }
    
    public func hasExtraBubbleBackground() -> Bool {
        var isInvertedGradient = false
        switch self.wallpaper {
        case let .file(file):
            if let intensity = file.settings.intensity, intensity < 0 {
                isInvertedGradient = true
            }
        default:
            break
        }
        return isInvertedGradient
    }
    
    public func makeDimmedNode() -> ASDisplayNode? {
        if let gradientBackgroundNode = self.gradientBackgroundNode {
            return GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode, isDimmed: true)
        } else {
            return nil
        }
    }
    
    public func makeEdgeEffectNode() -> WallpaperEdgeEffectNode? {
        let node = WallpaperEdgeEffectNodeImpl(parentNode: self)
        return node
    }
}

private final class WallpaperEdgeEffectNodeImpl: ASDisplayNode, WallpaperEdgeEffectNode {
    private struct Params: Equatable {
        let rect: CGRect
        let edge: WallpaperEdgeEffectEdge
        let containerSize: CGSize
        
        init(rect: CGRect, edge: WallpaperEdgeEffectEdge, containerSize: CGSize) {
            self.rect = rect
            self.edge = edge
            self.containerSize = containerSize
        }
    }
    
    private var gradientNode: GradientBackgroundNode.CloneNode?
    private let patternImageLayer: EffectImageLayer.CloneLayer
    
    private let containerNode: ASDisplayNode
    private let containerMaskingNode: ASDisplayNode
    private let overlayNode: ASDisplayNode
    private let maskView: UIImageView
    
    private weak var parentNode: WallpaperBackgroundNodeImpl?
    private var index: Int?
    private var params: Params?
    
    private var isInverted: Bool = false
    
    init(parentNode: WallpaperBackgroundNodeImpl) {
        self.parentNode = parentNode
        
        if let gradientBackgroundNode = parentNode.gradientBackgroundNode {
            self.gradientNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode, isDimmed: false)
        } else {
            self.gradientNode = nil
        }
        
        self.patternImageLayer = EffectImageLayer.CloneLayer(parentLayer: parentNode.patternImageLayer)
        
        self.containerNode = ASDisplayNode()
        self.containerNode.anchorPoint = CGPoint()
        self.containerNode.clipsToBounds = true
        
        self.containerMaskingNode = ASDisplayNode()
        self.containerMaskingNode.addSubnode(self.containerNode)
        
        self.overlayNode = ASDisplayNode()
        
        self.maskView = UIImageView()
        
        super.init()
        
        if let gradientNode = self.gradientNode {
            self.containerNode.addSubnode(gradientNode)
        }
        //self.layer.addSublayer(self.patternImageLayer)
        
        self.addSubnode(self.containerMaskingNode)
        self.containerMaskingNode.view.mask = self.maskView
        
        self.containerNode.addSubnode(self.overlayNode)
        
        self.index = parentNode.edgeEffectNodes.add(Weak(self))
    }
    
    deinit {
        if let index = self.index, let parentNode = self.parentNode {
            parentNode.edgeEffectNodes.remove(index)
        }
    }
    
    func updateGradientNode() {
        if let gradientBackgroundNode = self.parentNode?.gradientBackgroundNode {
            if self.gradientNode == nil {
                let gradientNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode, isDimmed: false)
                self.gradientNode = gradientNode
                self.containerNode.insertSubnode(gradientNode, at: 0)
                
                if let params = self.params {
                    self.updateImpl(rect: params.rect, edge: params.edge, containerSize: params.containerSize, transition: .immediate)
                }
            }
        } else {
            if let gradientNode = self.gradientNode {
                self.gradientNode = nil
                gradientNode.removeFromSupernode()
            }
        }
    }
    
    func updatePattern(isInverted: Bool) {
        if self.isInverted != isInverted {
            self.isInverted = isInverted
            
            self.overlayNode.backgroundColor = isInverted ? .black : .clear
        }
    }
    
    func update(rect: CGRect, edge: WallpaperEdgeEffectEdge, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let params = Params(rect: rect, edge: edge, containerSize: containerSize)
        if self.params != params {
            self.params = params
            self.updateImpl(rect: params.rect, edge: params.edge, containerSize: params.containerSize, transition: transition)
        }
    }
    
    private func updateImpl(rect: CGRect, edge: WallpaperEdgeEffectEdge, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerMaskingNode, frame: CGRect(origin: CGPoint(), size: rect.size))
        transition.updateBounds(node: self.containerNode, bounds: CGRect(origin: CGPoint(x: rect.minX, y: rect.minY), size: rect.size))
        
        if self.maskView.image?.size.height != edge.size {
            let baseGradientAlpha: CGFloat = 0.75
            let numSteps = 8
            let firstStep = 1
            let firstLocation = 0.0
            let colors: [UIColor] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return UIColor(white: 1.0, alpha: 1.0)
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    let value: CGFloat = bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                    return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                }
            }
            let locations: [CGFloat] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return 0.0
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    return (firstLocation + (1.0 - firstLocation) * step)
                }
            }
            
            self.maskView.image = generateGradientImage(
                size: CGSize(width: 8.0, height: edge.size),
                colors: colors,
                locations: locations
            )?.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(edge.size))
        }
        
        transition.updateFrame(view: self.maskView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: rect.size))
        
        transition.updateFrame(node: self.overlayNode, frame: CGRect(origin: CGPoint(), size: containerSize))
        
        if let gradientNode = self.gradientNode {
            transition.updateFrame(node: gradientNode, frame: CGRect(origin: CGPoint(), size: containerSize))
        }
        transition.updateFrame(layer: self.patternImageLayer, frame: CGRect(origin: CGPoint(), size: containerSize))
    }
}

private protocol WallpaperComponentView: AnyObject {
    var view: UIView { get }

    func update(size: CGSize, transition: ContainedViewLayoutTransition)
}

public func createWallpaperBackgroundNode(context: AccountContext, forChatDisplay: Bool, useSharedAnimationPhase: Bool = false) -> WallpaperBackgroundNode {
    return WallpaperBackgroundNodeImpl(context: context, useSharedAnimationPhase: useSharedAnimationPhase)
}

private extension StarGift {
    var slug: String? {
        switch self {
        case let .unique(uniqueGift):
            return uniqueGift.slug
        default:
            return nil
        }
    }
}
