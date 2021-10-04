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

public final class WallpaperBackgroundNode: ASDisplayNode {
    public final class BubbleBackgroundNode: ASDisplayNode {
        public enum BubbleType {
            case incoming
            case outgoing
            case free
        }

        private let bubbleType: BubbleType
        private let contentNode: ASImageNode

        private var cleanWallpaperNode: ASDisplayNode?
        private var gradientWallpaperNode: GradientBackgroundNode.CloneNode?
        private weak var backgroundNode: WallpaperBackgroundNode?
        private var index: SparseBag<BubbleBackgroundNode>.Index?

        private var currentLayout: (rect: CGRect, containerSize: CGSize)?

        public override var frame: CGRect {
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

        init(backgroundNode: WallpaperBackgroundNode, bubbleType: BubbleType) {
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

        public func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
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

        public func update(rect: CGRect, within containerSize: CGSize, transition: CombinedTransition) {
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

        public func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
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

        public func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
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
        weak var node: BubbleBackgroundNode?

        init(node: BubbleBackgroundNode) {
            self.node = node
        }
    }

    private let context: AccountContext
    private let useSharedAnimationPhase: Bool
    
    private let contentNode: ASDisplayNode
    private var blurredBackgroundContents: UIImage?

    private var gradientBackgroundNode: GradientBackgroundNode?
    private var outgoingBubbleGradientBackgroundNode: GradientBackgroundNode?
    private let patternImageNode: ASImageNode
    private var isGeneratingPatternImage: Bool = false

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
    
    public init(context: AccountContext, useSharedAnimationPhase: Bool = false) {
        self.context = context
        self.useSharedAnimationPhase = useSharedAnimationPhase
        self.imageContentMode = .scaleAspectFill
        
        self.contentNode = ASDisplayNode()
        self.contentNode.contentMode = self.imageContentMode

        self.patternImageNode = ASImageNode()
        
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        self.addSubnode(self.contentNode)
        self.addSubnode(self.patternImageNode)
    }

    deinit {
        self.patternImageDisposable.dispose()
        self.wallpaperDisposable.dispose()
        self.imageDisposable.dispose()
    }

    public func update(wallpaper: TelegramWallpaper) {
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

        if gradientColors.count >= 3 {
            let mappedColors = gradientColors.map { color -> UIColor in
                return UIColor(rgb: color)
            }
            if self.gradientBackgroundNode == nil {
                let gradientBackgroundNode = createGradientBackgroundNode(colors: mappedColors, useSharedAnimationPhase: self.useSharedAnimationPhase)
                self.gradientBackgroundNode = gradientBackgroundNode
                self.insertSubnode(gradientBackgroundNode, aboveSubnode: self.contentNode)
                gradientBackgroundNode.addSubnode(self.patternImageNode)
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
                self.insertSubnode(self.patternImageNode, aboveSubnode: self.contentNode)
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
        }
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
                self.patternImageNode.alpha = 1.0
                self.patternImageNode.layer.compositingFilter = nil
            } else {
                self.patternImageNode.alpha = intensity
                if patternIsBlack {
                    self.patternImageNode.layer.compositingFilter = nil
                } else {
                    self.patternImageNode.layer.compositingFilter = "softLightBlendMode"
                }
            }
            self.patternImageNode.isHidden = false
            let invertPattern = intensity < 0
            if invertPattern {
                self.backgroundColor = .black
                let contentAlpha = abs(intensity)
                self.gradientBackgroundNode?.contentView.alpha = contentAlpha
                self.contentNode.alpha = contentAlpha
                if self.patternImageNode.image != nil {
                    self.patternImageNode.backgroundColor = nil
                } else {
                    self.patternImageNode.backgroundColor = .black
                }
            } else {
                self.backgroundColor = nil
                self.gradientBackgroundNode?.contentView.alpha = 1.0
                self.contentNode.alpha = 1.0
                self.patternImageNode.backgroundColor = nil
            }
        default:
            self.patternImageDisposable.set(nil)
            self.validPatternImage = nil
            self.patternImageNode.isHidden = true
            self.patternImageNode.backgroundColor = nil
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
            if let previousWallpaper = self.validPatternImage?.wallpaper {
                switch previousWallpaper {
                case let .file(previousFile):
                    if file.file.id == previousFile.file.id {
                        updated = false
                    }
                default:
                    break
                }
            }

            if updated {
                self.validPatternGeneratedImage = nil
                self.validPatternImage = nil

                if let cachedValidPatternImage = WallpaperBackgroundNode.cachedValidPatternImage, cachedValidPatternImage.generated.wallpaper == wallpaper {
                    self.validPatternImage = ValidPatternImage(wallpaper: cachedValidPatternImage.generated.wallpaper, generate: cachedValidPatternImage.generate)
                } else {
                    func reference(for resource: EngineMediaResource, media: EngineMedia) -> MediaResourceReference {
                        return .wallpaper(wallpaper: .slug(file.slug), resource: resource._asResource())
                    }

                    var convertedRepresentations: [ImageRepresentationWithReference] = []
                    for representation in file.file.previewRepresentations {
                        convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: EngineMediaResource(representation.resource), media: EngineMedia(file.file))))
                    }
                    let dimensions = file.file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil), reference: reference(for: EngineMediaResource(file.file.resource), media: EngineMedia(file.file))))

                    let signal = patternWallpaperImage(account: self.context.account, accountManager: self.context.sharedContext.accountManager, representations: convertedRepresentations, mode: .screen, autoFetchFullSize: true)
                    self.patternImageDisposable.set((signal
                    |> deliverOnMainQueue).start(next: { [weak self] generator in
                        guard let strongSelf = self else {
                            return
                        }
                        if let generator = generator {
                            strongSelf.validPatternImage = ValidPatternImage(wallpaper: wallpaper, generate: generator)
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
            let intensity = CGFloat(file.settings.intensity ?? 50) / 100.0
            invertPattern = intensity < 0
        default:
            self.updatePatternPresentation()
        }

        if let validPatternImage = self.validPatternImage {
            let patternBackgroundColor: UIColor
            let patternColor: UIColor
            if invertPattern {
                patternColor = .clear
                patternBackgroundColor = .clear
                if self.patternImageNode.image == nil {
                    self.patternImageNode.backgroundColor = .black
                } else {
                    self.patternImageNode.backgroundColor = nil
                }
            } else {
                if patternIsLight {
                    patternColor = .black
                } else {
                    patternColor = .white
                }
                patternBackgroundColor = .clear
                self.patternImageNode.backgroundColor = nil
            }

            let updatedGeneratedImage = ValidPatternGeneratedImage(wallpaper: validPatternImage.wallpaper, size: size, patternColor: patternColor.rgb, backgroundColor: patternBackgroundColor.rgb, invertPattern: invertPattern)

            if self.validPatternGeneratedImage != updatedGeneratedImage {
                self.validPatternGeneratedImage = updatedGeneratedImage

                if let cachedValidPatternImage = WallpaperBackgroundNode.cachedValidPatternImage, cachedValidPatternImage.generated == updatedGeneratedImage {
                    self.patternImageNode.image = cachedValidPatternImage.image
                    self.updatePatternPresentation()
                } else {
                    let patternArguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: PatternWallpaperArguments(colors: [patternBackgroundColor], rotation: nil, customPatternColor: patternColor, preview: false), scale: min(2.0, UIScreenScale))
                    if self.useSharedAnimationPhase || self.patternImageNode.image == nil {
                        if let drawingContext = validPatternImage.generate(patternArguments) {
                            if let image = drawingContext.generateImage() {
                                self.patternImageNode.image = image
                                self.updatePatternPresentation()

                                if self.useSharedAnimationPhase {
                                    WallpaperBackgroundNode.cachedValidPatternImage = CachedValidPatternImage(generate: validPatternImage.generate, generated: updatedGeneratedImage, image: image)
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
                                strongSelf.patternImageNode.image = image
                                strongSelf.updatePatternPresentation()

                                if let image = image, strongSelf.useSharedAnimationPhase {
                                    WallpaperBackgroundNode.cachedValidPatternImage = CachedValidPatternImage(generate: validPatternImage.generate, generated: updatedGeneratedImage, image: image)
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

        transition.updateFrame(node: self.patternImageNode, frame: CGRect(origin: CGPoint(), size: size))
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = size

        transition.updatePosition(node: self.contentNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateBounds(node: self.contentNode, bounds: CGRect(origin: CGPoint(), size: size))

        if let gradientBackgroundNode = self.gradientBackgroundNode {
            transition.updateFrame(node: gradientBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            gradientBackgroundNode.updateLayout(size: size, transition: transition)
        }

        if let outgoingBubbleGradientBackgroundNode = self.outgoingBubbleGradientBackgroundNode {
            transition.updateFrame(node: outgoingBubbleGradientBackgroundNode, frame: CGRect(origin: CGPoint(), size: size))
            outgoingBubbleGradientBackgroundNode.updateLayout(size: size, transition: transition)
        }

        self.loadPatternForSizeIfNeeded(size: size, transition: transition)
        
        if isFirstLayout && !self.frame.isEmpty {
            self.updateScale()
        }
    }

    public func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool = false) {
        self.gradientBackgroundNode?.animateEvent(transition: transition, extendAnimation: extendAnimation)
        self.outgoingBubbleGradientBackgroundNode?.animateEvent(transition: transition, extendAnimation: extendAnimation)
    }

    public func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        if self.bubbleTheme !== bubbleTheme || self.bubbleCorners != bubbleCorners {
            self.bubbleTheme = bubbleTheme
            self.bubbleCorners = bubbleCorners

            if bubbleTheme.chat.message.outgoing.bubble.withoutWallpaper.fill.count >= 3 && bubbleTheme.chat.animateMessageColors {
                if self.outgoingBubbleGradientBackgroundNode == nil {
                    let outgoingBubbleGradientBackgroundNode = GradientBackgroundNode(adjustSaturation: false)
                    if let size = self.validLayout {
                        outgoingBubbleGradientBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                        outgoingBubbleGradientBackgroundNode.updateLayout(size: size, transition: .immediate)
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

    public func hasBubbleBackground(for type: WallpaperBackgroundNode.BubbleBackgroundNode.BubbleType) -> Bool {
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

    public func makeBubbleBackground(for type: WallpaperBackgroundNode.BubbleBackgroundNode.BubbleType) -> WallpaperBackgroundNode.BubbleBackgroundNode? {
        if !self.hasBubbleBackground(for: type) {
            return nil
        }
        let node = WallpaperBackgroundNode.BubbleBackgroundNode(backgroundNode: self, bubbleType: type)
        node.updateContents()
        return node
    }
}
