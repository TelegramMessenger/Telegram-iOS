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
import FastBlur
import Svg
import GZip
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import HierarchyTrackingLayer

private let motionAmount: CGFloat = 32.0

private func generateBlurredContents(image: UIImage) -> UIImage? {
    let size = image.size.aspectFitted(CGSize(width: 64.0, height: 64.0))
    let context = DrawingContext(size: size, scale: 1.0, opaque: true, clear: false)
    context.withFlippedContext { c in
        c.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
    }

    telegramFastBlurMore(Int32(context.size.width), Int32(context.size.height), Int32(context.bytesPerRow), context.bytes)
    telegramFastBlurMore(Int32(context.size.width), Int32(context.size.height), Int32(context.bytesPerRow), context.bytes)

    adjustSaturationInContext(context: context, saturation: 1.7)

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
}

public protocol WallpaperBackgroundNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    var rotation: CGFloat { get set }

    func update(wallpaper: TelegramWallpaper)
    func _internalUpdateIsSettingUpWallpaper()
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    func updateIsLooping(_ isLooping: Bool)
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool)
    func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners)
    func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool
    func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode?
    
    func hasExtraBubbleBackground() -> Bool
    
    func makeDimmedNode() -> ASDisplayNode?
}

private final class EffectImageLayer: SimpleLayer, GradientBackgroundPatternOverlayLayer {
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
    
    var suspendCompositionUpdates: Bool = false
    private var needsCompositionUpdate: Bool = false
    
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
        if self.isUsingSoftlight != useSoftlight {
            self.isUsingSoftlight = useSoftlight
            
            if self.isUsingSoftlight && useFilter {
                self.compositingFilter = "softLightBlendMode"
            } else {
                self.compositingFilter = nil
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
    }
}

final class WallpaperBackgroundNodeImpl: ASDisplayNode, WallpaperBackgroundNode {
    final class BubbleBackgroundNodeImpl: ASDisplayNode, WallpaperBubbleBackgroundNode {
        var implicitContentUpdate: Bool = true
        
        private let bubbleType: WallpaperBubbleType
        private let contentNode: ASImageNode

        private var cleanWallpaperNode: ASDisplayNode?
        private var gradientWallpaperNode: GradientBackgroundNode.CloneNode?
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
                        let gradientWallpaperNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode)
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
    private var blurredBackgroundContents: UIImage?

    private var gradientBackgroundNode: GradientBackgroundNode?
    private var outgoingBubbleGradientBackgroundNode: GradientBackgroundNode?
    private let patternImageLayer: EffectImageLayer
    private var isGeneratingPatternImage: Bool = false

    private let bakedBackgroundView: UIImageView

    private var validLayout: CGSize?
    private var wallpaper: TelegramWallpaper?
    private var isSettingUpWallpaper: Bool = false

    private struct CachedValidPatternImage {
        let generate: (TransformImageArguments) -> DrawingContext?
        let generated: ValidPatternGeneratedImage
        let image: UIImage
    }

    private static var cachedValidPatternImage: CachedValidPatternImage?

    private struct ValidPatternImage {
        let wallpaper: TelegramWallpaper
        let invertPattern: Bool
        let generate: (TransformImageArguments) -> DrawingContext?
    }
    private var validPatternImage: ValidPatternImage?

    private struct ValidPatternGeneratedImage: Equatable {
        let wallpaper: TelegramWallpaper
        let size: CGSize
        let patternColor: UInt32
        let backgroundColor: UInt32
        let invertPattern: Bool
    }
    private var validPatternGeneratedImage: ValidPatternGeneratedImage?

    private let patternImageDisposable = MetaDisposable()

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
    
    var rotation: CGFloat = 0.0 {
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
    
    //private var inlineAnimationNodes: [(AnimatedStickerNode, CGPoint)] = []
    //private let hierarchyTrackingLayer = HierarchyTrackingLayer()
    //private var activateInlineAnimationTimer: SwiftSignalKit.Timer?

    private let _isReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    var isReady: Signal<Bool, NoError> {
        return self._isReady.get()
    }
        
    init(context: AccountContext, useSharedAnimationPhase: Bool) {
        self.context = context
        self.useSharedAnimationPhase = useSharedAnimationPhase
        self.imageContentMode = .scaleAspectFill
        
        self.contentNode = ASDisplayNode()
        self.contentNode.contentMode = self.imageContentMode

        self.patternImageLayer = EffectImageLayer()

        self.bakedBackgroundView = UIImageView()
        self.bakedBackgroundView.isHidden = true
        
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        self.addSubnode(self.contentNode)
        self.layer.addSublayer(self.patternImageLayer)
    }

    deinit {
        self.patternImageDisposable.dispose()
        self.wallpaperDisposable.dispose()
        self.imageDisposable.dispose()
    }

    func update(wallpaper: TelegramWallpaper) {
        if self.wallpaper == wallpaper {
            return
        }
        self.wallpaper = wallpaper

        var gradientColors: [UInt32] = []
        var gradientAngle: Int32 = 0

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
                    self.blurredBackgroundContents = generateBlurredContents(image: image)
                    self.wallpaperDisposable.set(nil)
                    Queue.mainQueue().justDispatch {
                        self._isReady.set(true)
                    }
                } else if let image = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: self.context.account.postbox.mediaBox, knockoutMode: false) {
                    self.contentNode.contents = image.cgImage
                    self.blurredBackgroundContents = generateBlurredContents(image: image)
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
                            strongSelf.blurredBackgroundContents = generateBlurredContents(image: image)
                        } else {
                            strongSelf.blurredBackgroundContents = nil
                        }
                        strongSelf._isReady.set(true)
                    }))
                }
                self.contentNode.isHidden = false
            }
        }

        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
            self.updateBubbles()
            
            if scheduleLoopingEvent {
                self.animateEvent(transition: .animated(duration: 0.7, curve: .linear), extendAnimation: false)
            }
        }
    }

    func _internalUpdateIsSettingUpWallpaper() {
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
                    if self.useSharedAnimationPhase {
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
        default:
            self.patternImageDisposable.set(nil)
            self.validPatternImage = nil
            self.patternImageLayer.isHidden = true
            self.patternImageLayer.fillWithColorUntilLoaded = nil
            self.patternImageLayer.backgroundColor = nil
            self.backgroundColor = nil
            self.gradientBackgroundNode?.contentView.alpha = 1.0
            self.contentNode.alpha = 1.0
        }
    }

    private func loadPatternForSizeIfNeeded(size: CGSize, transition: ContainedViewLayoutTransition) {
        guard let wallpaper = self.wallpaper else {
            return
        }

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

            if updated {
                self.validPatternGeneratedImage = nil
                self.validPatternImage = nil

                if let cachedValidPatternImage = WallpaperBackgroundNodeImpl.cachedValidPatternImage, cachedValidPatternImage.generated.wallpaper == wallpaper && cachedValidPatternImage.generated.invertPattern == invertPattern {
                    self.validPatternImage = ValidPatternImage(wallpaper: cachedValidPatternImage.generated.wallpaper, invertPattern: invertPattern, generate: cachedValidPatternImage.generate)
                } else {
                    func reference(for resource: EngineMediaResource, media: EngineMedia) -> MediaResourceReference {
                        return .wallpaper(wallpaper: .slug(file.slug), resource: resource._asResource())
                    }

                    var convertedRepresentations: [ImageRepresentationWithReference] = []
                    for representation in file.file.previewRepresentations {
                        convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: EngineMediaResource(representation.resource), media: EngineMedia(file.file))))
                    }
                    let dimensions = file.file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false), reference: reference(for: EngineMediaResource(file.file.resource), media: EngineMedia(file.file))))

                    let signal = patternWallpaperImage(account: self.context.account, accountManager: self.context.sharedContext.accountManager, representations: convertedRepresentations, mode: .screen, autoFetchFullSize: true)
                    self.patternImageDisposable.set((signal
                    |> deliverOnMainQueue).start(next: { [weak self] generator in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if let generator = generator {
                            /*generator = { arguments in
                                let scale = arguments.scale ?? UIScreenScale
                                let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)
                                
                                context.withFlippedContext { c in
                                    if let path = getAppBundle().path(forResource: "PATTERN_static", ofType: "svg"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                        if let image = drawSvgImage(data, CGSize(width: arguments.drawingSize.width * scale, height: arguments.drawingSize.height * scale), .clear, .black, false) {
                                            c.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: arguments.drawingSize))
                                        }
                                    }
                                }
                                
                                return context
                            }*/
                            
                            strongSelf.validPatternImage = ValidPatternImage(wallpaper: wallpaper, invertPattern: invertPattern, generate: generator)
                            strongSelf.validPatternGeneratedImage = nil
                            if let size = strongSelf.validLayout {
                                strongSelf.loadPatternForSizeIfNeeded(size: size, transition: .immediate)
                            } else {
                                strongSelf._isReady.set(true)
                            }
                        } else {
                            strongSelf._isReady.set(true)
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

            let updatedGeneratedImage = ValidPatternGeneratedImage(wallpaper: validPatternImage.wallpaper, size: size, patternColor: patternColor.rgb, backgroundColor: patternBackgroundColor.rgb, invertPattern: invertPattern)

            if self.validPatternGeneratedImage != updatedGeneratedImage {
                self.validPatternGeneratedImage = updatedGeneratedImage

                if let cachedValidPatternImage = WallpaperBackgroundNodeImpl.cachedValidPatternImage, cachedValidPatternImage.generated == updatedGeneratedImage {
                    self.patternImageLayer.suspendCompositionUpdates = true
                    self.updatePatternPresentation()
                    self.patternImageLayer.patternContentImage = cachedValidPatternImage.image
                    self.patternImageLayer.suspendCompositionUpdates = false
                    self.patternImageLayer.updateCompositionIfNeeded()
                } else {
                    let patternArguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: PatternWallpaperArguments(colors: [patternBackgroundColor], rotation: nil, customPatternColor: patternColor, preview: false), scale: min(2.0, UIScreenScale))
                    if self.useSharedAnimationPhase || self.patternImageLayer.contents == nil {
                        if let drawingContext = validPatternImage.generate(patternArguments) {
                            if let image = drawingContext.generateImage() {
                                self.patternImageLayer.suspendCompositionUpdates = true
                                self.updatePatternPresentation()
                                self.patternImageLayer.patternContentImage = image
                                self.patternImageLayer.suspendCompositionUpdates = false
                                self.patternImageLayer.updateCompositionIfNeeded()

                                if self.useSharedAnimationPhase {
                                    WallpaperBackgroundNodeImpl.cachedValidPatternImage = CachedValidPatternImage(generate: validPatternImage.generate, generated: updatedGeneratedImage, image: image)
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
                                    WallpaperBackgroundNodeImpl.cachedValidPatternImage = CachedValidPatternImage(generate: validPatternImage.generate, generated: updatedGeneratedImage, image: image)
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

        transition.updateFrame(layer: self.patternImageLayer, frame: CGRect(origin: CGPoint(), size: size))
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = size

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

        self.loadPatternForSizeIfNeeded(size: size, transition: transition)
        
        /*for (animationNode, relativePosition) in self.inlineAnimationNodes {
            let sizeNorm = CGSize(width: 1440, height: 2960)
            let animationSize = CGSize(width: 512.0 / sizeNorm.width * size.width, height: 512.0 / sizeNorm.height * size.height)
            animationNode.frame = CGRect(origin: CGPoint(x: relativePosition.x / sizeNorm.width * size.width, y: relativePosition.y / sizeNorm.height * size.height), size: animationSize)
            animationNode.updateLayout(size: animationNode.frame.size)
        }*/
                
        if isFirstLayout && !self.frame.isEmpty {
            self.updateScale()
        }
    }

    private var isAnimating = false
    private var isLooping = false
    
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {
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

    func updateIsLooping(_ isLooping: Bool) {
        let wasLooping = self.isLooping
        self.isLooping = isLooping
        
        if isLooping && !wasLooping {
            self.animateEvent(transition: .animated(duration: 0.7, curve: .linear), extendAnimation: false)
        }
    }
    
    func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        if self.bubbleTheme !== bubbleTheme || self.bubbleCorners != bubbleCorners {
            self.bubbleTheme = bubbleTheme
            self.bubbleCorners = bubbleCorners

            if bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill.count >= 3 && bubbleTheme.chat.animateMessageColors {
                if self.outgoingBubbleGradientBackgroundNode == nil {
                    let outgoingBubbleGradientBackgroundNode = GradientBackgroundNode(adjustSaturation: false)
                    if let size = self.validLayout {
                        outgoingBubbleGradientBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                        outgoingBubbleGradientBackgroundNode.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
                    }
                    self.outgoingBubbleGradientBackgroundNode = outgoingBubbleGradientBackgroundNode
                }
                self.outgoingBubbleGradientBackgroundNode?.updateColors(colors: bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill)
            } else if let _ = self.outgoingBubbleGradientBackgroundNode {
                self.outgoingBubbleGradientBackgroundNode = nil
            }

            self.updateBubbles()
        }
    }

    private func updateBubbles() {
        for reference in self.bubbleBackgroundNodeReferences {
            reference.node?.updateContents()
        }
    }

    func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool {
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

    func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? {
        if !self.hasBubbleBackground(for: type) {
            return nil
        }
        let node = WallpaperBackgroundNodeImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: type)
        node.updateContents()
        return node
    }
    
    func hasExtraBubbleBackground() -> Bool {
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
    
    func makeDimmedNode() -> ASDisplayNode? {
        if let gradientBackgroundNode = self.gradientBackgroundNode {
            return GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode)
        } else {
            return nil
        }
    }
}

private protocol WallpaperComponentView: AnyObject {
    var view: UIView { get }

    func update(size: CGSize, transition: ContainedViewLayoutTransition)
}

final class WallpaperBackgroundNodeMergedImpl: ASDisplayNode, WallpaperBackgroundNode {
    final class SharedStorage {
    }

    final class BubbleBackgroundNodeImpl: ASDisplayNode, WallpaperBubbleBackgroundNode {
        var implicitContentUpdate = true
        
        private let bubbleType: WallpaperBubbleType
        private let contentNode: ASImageNode

        private var cleanWallpaperNode: ASDisplayNode?
        private var gradientWallpaperNode: GradientBackgroundNode.CloneNode?
        private weak var backgroundNode: WallpaperBackgroundNodeMergedImpl?
        private var index: SparseBag<BubbleBackgroundNodeImpl>.Index?

        private var currentLayout: (rect: CGRect, containerSize: CGSize)?

        override var frame: CGRect {
            didSet {
                if oldValue.size != self.bounds.size {
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

        init(backgroundNode: WallpaperBackgroundNodeMergedImpl, bubbleType: WallpaperBubbleType) {
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
                        needsCleanBackground = false
                    case .incoming, .outgoing:
                        break
                    }
                }

                if needsCleanBackground {
                    if hasComplexGradient {
                        needsGradientBackground = backgroundNode.gradient != nil
                    } else {
                        needsWallpaperBackground = true
                    }
                }

                var gradientBackgroundSource: GradientBackgroundNode? = backgroundNode.gradient?.gradientBackground

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
                        self.cleanWallpaperNode?.backgroundColor = backgroundNode.backgroundColor
                    } else {
                        self.cleanWallpaperNode?.contents = nil
                        self.cleanWallpaperNode?.backgroundColor = backgroundNode.backgroundColor
                    }
                } else {
                    if let cleanWallpaperNode = self.cleanWallpaperNode {
                        self.cleanWallpaperNode = nil
                        cleanWallpaperNode.removeFromSupernode()
                    }
                }

                if needsGradientBackground, let gradientBackgroundNode = gradientBackgroundSource {
                    if self.gradientWallpaperNode == nil {
                        let gradientWallpaperNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode)
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

            if let (rect, containerSize) = self.currentLayout {
                self.update(rect: rect, within: containerSize)
            }
        }

        func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
            self.update(rect: rect, within: containerSize, delay: 0.0, transition: transition)
        }
        
        func update(rect: CGRect, within containerSize: CGSize, delay: Double, transition: ContainedViewLayoutTransition = .immediate) {
            self.currentLayout = (rect, containerSize)

            let shiftedContentsRect = CGRect(origin: CGPoint(x: rect.minX / containerSize.width, y: rect.minY / containerSize.height), size: CGSize(width: rect.width / containerSize.width, height: rect.height / containerSize.height))

            transition.updateFrame(layer: self.contentNode.layer, frame: self.bounds)
            transition.animateView {
                self.contentNode.layer.contentsRect = shiftedContentsRect
            }
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                transition.updateFrame(layer: cleanWallpaperNode.layer, frame: self.bounds)
                transition.animateView {
                    cleanWallpaperNode.layer.contentsRect = shiftedContentsRect
                }
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                transition.updateFrame(layer: gradientWallpaperNode.layer, frame: self.bounds)
                transition.animateView {
                    gradientWallpaperNode.layer.contentsRect = shiftedContentsRect
                }
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
    }

    private final class BubbleBackgroundNodeReference {
        weak var node: BubbleBackgroundNodeImpl?

        init(node: BubbleBackgroundNodeImpl) {
            self.node = node
        }
    }

    private final class WallpaperGradiendComponentView: WallpaperComponentView {
        struct Spec: Equatable {
            var colors: [UInt32]
        }

        let spec: Spec
        let gradientBackground: GradientBackgroundNode

        var view: UIView {
            return self.gradientBackground.view
        }

        init(spec: Spec, updated: @escaping () -> Void) {
            self.spec = spec

            self.gradientBackground = GradientBackgroundNode(colors: spec.colors.map(UIColor.init(rgb:)), useSharedAnimationPhase: true, adjustSaturation: false)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(size: CGSize, transition: ContainedViewLayoutTransition) {
            self.gradientBackground.frame = CGRect(origin: CGPoint(), size: size)
            self.gradientBackground.updateLayout(size: size, transition: transition, extendAnimation: false, backwards: false, completion: {})
        }
    }

    private final class WallpaperColorComponentView: WallpaperComponentView {
        struct Spec: Equatable {
            var color: UInt32
        }

        let spec: Spec
        let backgroundView: UIView

        var view: UIView {
            return self.backgroundView
        }

        init(spec: Spec, updated: @escaping () -> Void) {
            self.spec = spec

            self.backgroundView = UIView()
            self.backgroundView.backgroundColor = UIColor(rgb: spec.color)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(size: CGSize, transition: ContainedViewLayoutTransition) {
            self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        }
    }

    private final class WallpaperImageComponentView: WallpaperComponentView {
        enum Spec: Equatable {
            case image(
                representation: TelegramMediaImageRepresentation,
                isPattern: Bool,
                intensity: CGFloat
            )
            case builtin
        }

        let spec: Spec
        let updated: () -> Void
        let imageView: UIImageView
        var fetchDisposable: Disposable?
        var dataDisposable: Disposable?

        var imageData: Data?

        private var validSize: CGSize?

        var view: UIView {
            return self.imageView
        }

        init(context: AccountContext, spec: Spec, updated: @escaping () -> Void) {
            self.spec = spec
            self.updated = updated

            self.imageView = UIImageView()
            self.imageView.contentMode = .scaleAspectFill

            switch spec {
            case let .image(representation, _, _):
                self.fetchDisposable = (fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: representation.resource))
                |> deliverOnMainQueue).start()
                self.dataDisposable = (context.account.postbox.mediaBox.resourceData(representation.resource)
                |> deliverOnMainQueue).start(next: { [weak self] dataValue in
                    guard let strongSelf = self else {
                        return
                    }

                    if dataValue.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: dataValue.path)) {
                        strongSelf.imageData = data
                        if let size = strongSelf.validSize {
                            strongSelf.updateImage(size: size, data: data)
                        }
                    }
                })
            case .builtin:
                if let filePath = getAppBundle().path(forResource: "ChatWallpaperBuiltin0", ofType: "jpg"), let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                    self.imageData = data
                    if let size = self.validSize {
                        self.updateImage(size: size, data: data)
                    }
                }
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.fetchDisposable?.dispose()
            self.dataDisposable?.dispose()
        }

        func update(size: CGSize, transition: ContainedViewLayoutTransition) {
            let sizeUpdated = self.validSize != size
            self.validSize = size

            self.imageView.frame = CGRect(origin: CGPoint(), size: size)

            if sizeUpdated || self.imageView.image == nil {
                if let imageData = self.imageData {
                    self.updateImage(size: size, data: imageData)
                }
            }
        }

        private func updateImage(size: CGSize, data: Data) {
            let scale: CGFloat
            if UIScreenScale >= 2.9 {
                scale = 2.5
            } else {
                scale = UIScreenScale
            }

            switch self.spec {
            case let .image(_, isPattern, intensity):
                if isPattern {
                    let patternBackgroundColor: UIColor
                    let patternForegroundColor: UIColor
                    if intensity < 0.0 {
                        patternBackgroundColor = .clear
                        patternForegroundColor = .black
                    } else {
                        patternBackgroundColor = .clear
                        patternForegroundColor = .black
                    }

                    if let unpackedData = TGGUnzipData(data, 2 * 1024 * 1024), let patternImage = drawSvgImage(unpackedData, CGSize(width: floor(size.width * scale), height: floor(size.height * scale)), patternBackgroundColor, patternForegroundColor, false) {
                        if intensity < 0.0 {
                            self.imageView.image = generateImage(patternImage.size, scale: patternImage.scale, rotatedContext: { size, context in
                                context.setFillColor(UIColor.black.cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))

                                if let cgImage = patternImage.cgImage {
                                    context.setBlendMode(.destinationOut)
                                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                                    context.scaleBy(x: 1.0, y: -1.0)
                                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                                    context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                                }
                            })
                            self.imageView.alpha = 1.0
                            self.imageView.layer.compositingFilter = nil
                            self.imageView.backgroundColor = UIColor(white: 0.0, alpha: 1.0 - abs(intensity))
                        } else {
                            self.imageView.image = patternImage
                            self.imageView.alpha = abs(intensity)
                            self.imageView.layer.compositingFilter = "softLightBlendMode"
                            self.imageView.backgroundColor = nil
                        }
                    }

                    self.updated()
                } else if let image = UIImage(data: data) {
                    self.imageView.image = image
                    self.imageView.layer.compositingFilter = nil
                    self.imageView.alpha = 1.0

                    self.updated()
                }
            case .builtin:
                if let image = UIImage(data: data) {
                    self.imageView.image = image
                    self.imageView.layer.compositingFilter = nil
                    self.imageView.alpha = 1.0

                    self.updated()
                }
            }
        }
    }

    private let context: AccountContext
    private let storage: SharedStorage

    private let staticView: UIImageView
    private let dynamicView: UIView
    private var color: WallpaperColorComponentView?
    private var gradient: WallpaperGradiendComponentView?
    private var image: WallpaperImageComponentView?

    private var blurredBackgroundContents: UIImage?

    private var isSettingUpWallpaper: Bool = false

    private var wallpaper: TelegramWallpaper?
    private var validLayout: CGSize?

    private let _isReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    var isReady: Signal<Bool, NoError> {
        return self._isReady.get()
    }

    var rotation: CGFloat = 0.0 {
        didSet {
        }
    }

    private var isAnimating: Bool = false

    private var bubbleTheme: PresentationTheme?
    private var bubbleCorners: PresentationChatBubbleCorners?
    private var bubbleBackgroundNodeReferences = SparseBag<BubbleBackgroundNodeReference>()
    private var outgoingBubbleGradientBackgroundNode: GradientBackgroundNode?

    init(context: AccountContext, storage: SharedStorage?) {
        self.context = context
        self.storage = storage ?? SharedStorage()

        self.staticView = UIImageView()
        self.dynamicView = UIView()

        super.init()

        self.view.addSubview(self.staticView)
    }

    func update(wallpaper: TelegramWallpaper) {
        self.wallpaper = wallpaper

        var colorSpec: WallpaperColorComponentView.Spec?
        var gradientSpec: WallpaperGradiendComponentView.Spec?
        var imageSpec: WallpaperImageComponentView.Spec?

        switch wallpaper {
        case .builtin:
            imageSpec = WallpaperImageComponentView.Spec.builtin
        case let .color(color):
            colorSpec = WallpaperColorComponentView.Spec(color: color)
        case let .gradient(gradient):
            if gradient.colors.count >= 3 {
                gradientSpec = WallpaperGradiendComponentView.Spec(colors: gradient.colors)
            }
        case let .image(representations, settings):
            if let representation = representations.last {
                imageSpec = WallpaperImageComponentView.Spec.image(representation: representation, isPattern: false, intensity: 1.0)
            }
            let _ = settings
        case let .file(file):
            if file.settings.colors.count >= 3 {
                gradientSpec = WallpaperGradiendComponentView.Spec(colors: file.settings.colors)
            }
            if let dimensions = file.file.dimensions {
                let representation = TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: file.file.immediateThumbnailData, hasVideo: false)
                imageSpec = WallpaperImageComponentView.Spec.image(representation: representation, isPattern: file.isPattern, intensity: CGFloat(file.settings.intensity ?? 100) / 100.0)
            }
        }

        if self.color?.spec != colorSpec {
            if let color = self.color {
                self.color = nil
                color.view.removeFromSuperview()
            }
            if let colorSpec = colorSpec {
                let color = WallpaperColorComponentView(spec: colorSpec, updated: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.componentsUpdated()
                })
                self.color = color
                if let size = self.validLayout {
                    color.update(size: size, transition: .immediate)
                }
                self.dynamicView.insertSubview(color.view, at: 0)

                self.componentsUpdated()
            }
        }

        if self.gradient?.spec != gradientSpec {
            if let gradient = self.gradient {
                self.gradient = nil
                gradient.view.removeFromSuperview()
            }
            if let gradientSpec = gradientSpec {
                let gradient = WallpaperGradiendComponentView(spec: gradientSpec, updated: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.componentsUpdated()
                })
                self.gradient = gradient
                if let size = self.validLayout {
                    gradient.update(size: size, transition: .immediate)
                }
                self.dynamicView.insertSubview(gradient.view, at: 0)
            }
        }

        if self.image?.spec != imageSpec {
            if let image = self.image {
                self.image = nil
                image.view.removeFromSuperview()
            }
            if let imageSpec = imageSpec {
                let image = WallpaperImageComponentView(context: self.context, spec: imageSpec, updated: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.componentsUpdated()
                })
                self.image = image
                if let size = self.validLayout {
                    image.update(size: size, transition: .immediate)
                }
                if let gradient = self.gradient {
                    self.dynamicView.insertSubview(image.view, aboveSubview: gradient.view)
                } else {
                    self.dynamicView.insertSubview(image.view, at: 0)
                }
            }
        }
    }

    private func componentsUpdated() {
        if self.isAnimating {
            if self.dynamicView.superview == nil {
                self.view.addSubview(self.dynamicView)
                self.staticView.isHidden = true
            }
            self._isReady.set(true)
        } else {
            self.staticView.isHidden = false
            self.dynamicView.removeFromSuperview()

            if let size = self.validLayout {
                if let color = self.color {
                    self.staticView.image = nil
                    self.staticView.backgroundColor = color.backgroundView.backgroundColor
                } else {
                    let gradientImage = self.gradient?.gradientBackground.contentView.image
                    let gradientFrame = self.gradient?.gradientBackground.frame

                    let imageImage = self.image?.imageView.image
                    let imageBackgroundColor = self.image?.imageView.backgroundColor
                    let imageFrame = self.image?.imageView.frame
                    let imageAlpha = self.image?.imageView.alpha
                    let imageFilter = self.image?.imageView.layer.compositingFilter as? String

                    self.staticView.image = generateImage(size, opaque: true, scale: nil, rotatedContext: { size, context in
                        UIGraphicsPushContext(context)

                        if let gradientImage = gradientImage, let gradientFrame = gradientFrame {
                            gradientImage.draw(in: gradientFrame)
                        }

                        if let imageImage = imageImage, let imageFrame = imageFrame, let imageAlpha = imageAlpha {
                            if imageFilter == "softLightBlendMode" {
                                context.setBlendMode(.softLight)
                            }

                            if let imageBackgroundColor = imageBackgroundColor {
                                context.setFillColor(imageBackgroundColor.cgColor)
                                context.fill(imageFrame)
                            }

                            context.setAlpha(imageAlpha)

                            context.translateBy(x: imageFrame.midX, y: imageFrame.midY)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -imageFrame.midX, y: -imageFrame.midY)
                            if let cgImage = imageImage.cgImage {
                                let drawingSize = imageImage.size.aspectFilled(imageFrame.size)
                                context.draw(cgImage, in: CGRect(origin: CGPoint(x: imageFrame.minX + (imageFrame.width - drawingSize.width) / 2.0, y: imageFrame.minX + (imageFrame.height - drawingSize.height) / 2.0), size: drawingSize))
                            }
                            context.translateBy(x: imageFrame.midX, y: imageFrame.midY)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -imageFrame.midX, y: -imageFrame.midY)

                            context.setBlendMode(.normal)
                            context.setAlpha(1.0)
                        }

                        UIGraphicsPopContext()
                    })
                }

                self._isReady.set(true)
            }
        }
    }

    func _internalUpdateIsSettingUpWallpaper() {
        self.isSettingUpWallpaper = true
    }

    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size

        self.staticView.frame = CGRect(origin: CGPoint(), size: size)

        if let gradient = self.gradient {
            gradient.update(size: size, transition: transition)
        }
        if let image = self.image {
            image.update(size: size, transition: transition)
        }
    }

    private var isLooping = false
    func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {
        if let gradient = self.gradient {
            guard !(self.isLooping && self.isAnimating) else {
                return
            }
            self.isAnimating = true
            self.componentsUpdated()
            gradient.gradientBackground.animateEvent(transition: transition, extendAnimation: extendAnimation, backwards: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isAnimating = false
                if strongSelf.isLooping {
                    strongSelf.animateEvent(transition: transition, extendAnimation: extendAnimation)
                } else {
                    strongSelf.componentsUpdated()
                }
            })
        } else {
            self.isAnimating = false
        }
    }
    
    func updateIsLooping(_ isLooping: Bool) {
        let wasLooping = self.isLooping
        self.isLooping = isLooping
        
        if isLooping && !wasLooping {
            self.animateEvent(transition: .animated(duration: 0.4, curve: .linear), extendAnimation: false)
        }
    }

    func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        if self.bubbleTheme !== bubbleTheme || self.bubbleCorners != bubbleCorners {
            self.bubbleTheme = bubbleTheme
            self.bubbleCorners = bubbleCorners

            if bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill.count >= 3 && bubbleTheme.chat.animateMessageColors {
                if self.outgoingBubbleGradientBackgroundNode == nil {
                    let outgoingBubbleGradientBackgroundNode = GradientBackgroundNode(adjustSaturation: false)
                    if let size = self.validLayout {
                        outgoingBubbleGradientBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                        outgoingBubbleGradientBackgroundNode.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
                    }
                    self.outgoingBubbleGradientBackgroundNode = outgoingBubbleGradientBackgroundNode
                }
                self.outgoingBubbleGradientBackgroundNode?.updateColors(colors: bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill)
            } else if let _ = self.outgoingBubbleGradientBackgroundNode {
                self.outgoingBubbleGradientBackgroundNode = nil
            }

            self.updateBubbles()
        }
    }

    private func updateBubbles() {
        for reference in self.bubbleBackgroundNodeReferences {
            reference.node?.updateContents()
        }
    }

    func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool {
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

    func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? {
        if !self.hasBubbleBackground(for: type) {
            return nil
        }
        let node = WallpaperBackgroundNodeMergedImpl.BubbleBackgroundNodeImpl(backgroundNode: self, bubbleType: type)
        node.updateContents()
        return node
    }
    
    func hasExtraBubbleBackground() -> Bool {
        return false
    }

    func makeDimmedNode() -> ASDisplayNode? {
        return nil
    }
}

private let sharedStorage = WallpaperBackgroundNodeMergedImpl.SharedStorage()

public func createWallpaperBackgroundNode(context: AccountContext, forChatDisplay: Bool, useSharedAnimationPhase: Bool = false, useExperimentalImplementation: Bool = false) -> WallpaperBackgroundNode {
    if forChatDisplay && useExperimentalImplementation {
        #if DEBUG
        if #available(iOS 13.0, iOSApplicationExtension 13.0, *) {
            return MetalWallpaperBackgroundNode()
        }
        #else
        return WallpaperBackgroundNodeMergedImpl(context: context, storage: useSharedAnimationPhase ? sharedStorage : nil)
        #endif
    }

    return WallpaperBackgroundNodeImpl(context: context, useSharedAnimationPhase: useSharedAnimationPhase)
}
