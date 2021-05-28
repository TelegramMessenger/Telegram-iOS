import Foundation
import UIKit
import AsyncDisplayKit
import Display
import GradientBackground
import TelegramPresentationData
import SyncCore
import TelegramCore
import AccountContext
import SwiftSignalKit
import WallpaperResources
import Postbox

private let motionAmount: CGFloat = 32.0

public final class WallpaperBackgroundNode: ASDisplayNode {
    public final class BubbleBackgroundNode: ASDisplayNode {
        public enum BubbleType {
            case incoming
            case outgoing
        }

        private let bubbleType: BubbleType
        private let contentNode: ASImageNode

        private var cleanWallpaperNode: ASDisplayNode?
        private var gradientWallpaperNode: GradientBackgroundNode.CloneNode?
        private weak var backgroundNode: WallpaperBackgroundNode?
        private var index: SparseBag<BubbleBackgroundNode>.Index?

        init(backgroundNode: WallpaperBackgroundNode, bubbleType: BubbleType) {
            self.backgroundNode = backgroundNode
            self.bubbleType = bubbleType

            self.contentNode = ASImageNode()
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

            if let bubbleTheme = backgroundNode.bubbleTheme, let wallpaper = backgroundNode.wallpaper, let bubbleCorners = backgroundNode.bubbleCorners {
                let graphics = PresentationResourcesChat.principalGraphics(theme: bubbleTheme, wallpaper: wallpaper, bubbleCorners: bubbleCorners)
                var needsCleanBackground = false
                switch self.bubbleType {
                case .incoming:
                    self.contentNode.image = graphics.incomingBubbleGradientImage
                    if graphics.incomingBubbleGradientImage == nil {
                        self.contentNode.backgroundColor = bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill
                    } else {
                        self.contentNode.backgroundColor = nil
                    }
                    needsCleanBackground = bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill.alpha <= 0.99 || bubbleTheme.chat.message.incoming.bubble.withWallpaper.gradientFill.alpha <= 0.99
                case .outgoing:
                    self.contentNode.image = graphics.outgoingBubbleGradientImage
                    if graphics.outgoingBubbleGradientImage == nil {
                        self.contentNode.backgroundColor = bubbleTheme.chat.message.outgoing.bubble.withWallpaper.fill
                    } else {
                        self.contentNode.backgroundColor = nil
                    }
                    needsCleanBackground = bubbleTheme.chat.message.outgoing.bubble.withWallpaper.fill.alpha <= 0.99 || bubbleTheme.chat.message.outgoing.bubble.withWallpaper.gradientFill.alpha <= 0.99
                }

                var hasComplexGradient = false
                switch wallpaper {
                case let .file(_, _, _, _, isPattern, _, _, _, settings):
                    hasComplexGradient = settings.colors.count >= 3
                    if !isPattern {
                        needsCleanBackground = false
                    }
                case let .gradient(colors, _):
                    hasComplexGradient = colors.count >= 3
                default:
                    break
                }

                var needsGradientBackground = false
                var needsWallpaperBackground = false

                if needsCleanBackground {
                    if hasComplexGradient {
                        needsGradientBackground = backgroundNode.gradientBackgroundNode != nil
                    } else {
                        needsWallpaperBackground = true
                    }
                }

                if needsWallpaperBackground {
                    if self.cleanWallpaperNode == nil {
                        let cleanWallpaperNode = ASImageNode()
                        self.cleanWallpaperNode = cleanWallpaperNode
                        cleanWallpaperNode.frame = self.contentNode.frame
                        self.insertSubnode(cleanWallpaperNode, at: 0)
                    }
                    self.cleanWallpaperNode?.contents = backgroundNode.contentNode.contents
                    self.cleanWallpaperNode?.backgroundColor = backgroundNode.contentNode.backgroundColor
                } else {
                    if let cleanWallpaperNode = self.cleanWallpaperNode {
                        self.cleanWallpaperNode = nil
                        cleanWallpaperNode.removeFromSupernode()
                    }
                }

                if needsGradientBackground, let gradientBackgroundNode = backgroundNode.gradientBackgroundNode {
                    if self.gradientWallpaperNode == nil {
                        let gradientWallpaperNode = GradientBackgroundNode.CloneNode(parentNode: gradientBackgroundNode)
                        gradientWallpaperNode.frame = self.contentNode.frame
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
        }

        public func update(rect: CGRect, within containerSize: CGSize) {
            self.contentNode.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                cleanWallpaperNode.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                gradientWallpaperNode.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
            }
        }

        public func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
            let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: animationCurve)
            transition.animatePositionAdditive(node: self.contentNode, offset: CGPoint(x: -value.x, y: -value.y))
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                transition.animatePositionAdditive(node: cleanWallpaperNode, offset: CGPoint(x: -value.x, y: -value.y))
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                transition.animatePositionAdditive(node: gradientWallpaperNode, offset: CGPoint(x: -value.x, y: -value.y))
            }
        }

        public func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
            self.contentNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: value)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
            if let cleanWallpaperNode = self.cleanWallpaperNode {
                cleanWallpaperNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: value)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
            }
            if let gradientWallpaperNode = self.gradientWallpaperNode {
                gradientWallpaperNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: value)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: duration, initialVelocity: 0.0, damping: damping, additive: true)
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
    private var gradientBackgroundNode: GradientBackgroundNode?
    private let patternImageNode: TransformImageNode

    private var validLayout: CGSize?
    private var wallpaper: TelegramWallpaper?

    private let patternImageDisposable = MetaDisposable()

    private var bubbleTheme: PresentationTheme?
    private var bubbleCorners: PresentationChatBubbleCorners?
    private var bubbleBackgroundNodeReferences = SparseBag<BubbleBackgroundNodeReference>()
    
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
    
    public init(context: AccountContext, useSharedAnimationPhase: Bool = false) {
        self.context = context
        self.useSharedAnimationPhase = useSharedAnimationPhase
        self.imageContentMode = .scaleAspectFill
        
        self.contentNode = ASDisplayNode()
        self.contentNode.contentMode = self.imageContentMode

        self.patternImageNode = TransformImageNode()
        self.patternImageNode.layer.compositingFilter = "softLightBlendMode"
        
        super.init()
        
        self.clipsToBounds = true
        self.contentNode.frame = self.bounds
        self.addSubnode(self.contentNode)
        self.addSubnode(self.patternImageNode)
    }

    deinit {
        self.patternImageDisposable.dispose()
    }

    public func update(wallpaper: TelegramWallpaper) {
        let previousWallpaper = self.wallpaper
        if self.wallpaper == wallpaper {
            return
        }
        self.wallpaper = wallpaper

        var gradientColors: [UInt32] = []
        var gradientAngle: Int32 = 0

        if case let .color(color) = wallpaper {
            gradientColors = [color]
        } else if case let .gradient(colors, settings) = wallpaper {
            gradientColors = colors
            gradientAngle = settings.rotation ?? 0
        } else if case let .file(_, _, _, _, isPattern, _, _, _, settings) = wallpaper, isPattern {
            gradientColors = settings.colors
            gradientAngle = settings.rotation ?? 0
        }

        if gradientColors.count >= 3 {
            if self.gradientBackgroundNode == nil {
                let gradientBackgroundNode = createGradientBackgroundNode(useSharedAnimationPhase: self.useSharedAnimationPhase)
                self.gradientBackgroundNode = gradientBackgroundNode
                self.insertSubnode(gradientBackgroundNode, aboveSubnode: self.contentNode)
                gradientBackgroundNode.addSubnode(self.patternImageNode)
            }
            self.gradientBackgroundNode?.updateColors(colors: gradientColors.map { color -> UIColor in
                return UIColor(rgb: color)
            })

            self.contentNode.backgroundColor = nil
            self.contentNode.contents = nil
            self.motionEnabled = false
        } else {
            if let gradientBackgroundNode = self.gradientBackgroundNode {
                self.gradientBackgroundNode = nil
                gradientBackgroundNode.removeFromSupernode()
                self.insertSubnode(self.patternImageNode, aboveSubnode: self.contentNode)
            }

            self.motionEnabled = wallpaper.settings?.motion ?? false

            if gradientColors.count >= 2 {
                self.contentNode.backgroundColor = nil
                self.contentNode.contents = generateImage(CGSize(width: 100.0, height: 200.0), rotatedContext: { size, context in
                    let gradientColors = [UIColor(rgb: gradientColors[0]).cgColor, UIColor(rgb: gradientColors[1]).cgColor] as CFArray

                    var locations: [CGFloat] = [0.0, 1.0]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.rotate(by: CGFloat(gradientAngle) * CGFloat.pi / 180.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                })?.cgImage
            } else if gradientColors.count >= 1 {
                self.contentNode.backgroundColor = UIColor(rgb: gradientColors[0])
                self.contentNode.contents = nil
            } else {
                self.contentNode.backgroundColor = .white
                self.contentNode.contents = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: self.context.sharedContext.accountManager.mediaBox, knockoutMode: false)?.cgImage
                self.contentNode.isHidden = false
            }
        }

        switch wallpaper {
        case let .file(id, _, _, _, isPattern, _, _, file, settings) where isPattern:
            var updated = true
            if let previousWallpaper = previousWallpaper {
                switch previousWallpaper {
                case let .file(previousId, _, _, _, previousIsPattern, _, _, previousFile, _):
                    if id == previousId && isPattern == previousIsPattern && file.id == previousFile.id {
                        updated = false
                    }
                default:
                    break
                }
            }

            if updated {
                func reference(for resource: MediaResource, media: Media, message: Message?) -> MediaResourceReference {
                    if let message = message {
                        return .media(media: .message(message: MessageReference(message), media: media), resource: resource)
                    }
                    return .wallpaper(wallpaper: nil, resource: resource)
                }

                var convertedRepresentations: [ImageRepresentationWithReference] = []
                for representation in file.previewRepresentations {
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: reference(for: representation.resource, media: file, message: nil)))
                }
                let dimensions = file.dimensions ?? PixelDimensions(width: 2000, height: 4000)
                convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil), reference: reference(for: file.resource, media: file, message: nil)))

                let signal = patternWallpaperImage(account: self.context.account, accountManager: self.context.sharedContext.accountManager, representations: convertedRepresentations, mode: .screen, autoFetchFullSize: true)
                self.patternImageNode.setSignal(signal)
            }
            self.patternImageNode.alpha = CGFloat(settings.intensity ?? 50) / 100.0
            self.patternImageNode.isHidden = false
        default:
            self.patternImageNode.isHidden = true
        }

        self.updateBubbles()

        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
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

        let makeImageLayout = self.patternImageNode.asyncLayout()
        let applyImage = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), custom: PatternWallpaperArguments(colors: [.clear], rotation: nil, customPatternColor: .black, preview: false)))
        applyImage()
        transition.updateFrame(node: self.patternImageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if isFirstLayout && !self.frame.isEmpty {
            self.updateScale()
        }
    }

    public func animateEvent(transition: ContainedViewLayoutTransition) {
        self.gradientBackgroundNode?.animateEvent(transition: transition)
    }

    public func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        if self.bubbleTheme !== bubbleTheme || self.bubbleCorners != bubbleCorners {
            self.bubbleTheme = bubbleTheme
            self.bubbleCorners = bubbleCorners

            self.updateBubbles()
        }
    }

    private func updateBubbles() {
        for reference in self.bubbleBackgroundNodeReferences {
            reference.node?.updateContents()
        }
    }

    public func hasBubbleBackground(for type: WallpaperBackgroundNode.BubbleBackgroundNode.BubbleType) -> Bool {
        guard let bubbleTheme = self.bubbleTheme, let wallpaper = self.wallpaper, let bubbleCorners = self.bubbleCorners else {
            return false
        }

        var hasPlainWallpaper = false
        switch wallpaper {
        case .color:
            hasPlainWallpaper = true
        default:
            break
        }

        let graphics = PresentationResourcesChat.principalGraphics(theme: bubbleTheme, wallpaper: wallpaper, bubbleCorners: bubbleCorners)
        switch type {
        case .incoming:
            if graphics.incomingBubbleGradientImage != nil {
                return true
            }
            if bubbleTheme.chat.message.incoming.bubble.withWallpaper.fill.alpha <= 0.99 {
                return !hasPlainWallpaper
            }
        case .outgoing:
            if graphics.outgoingBubbleGradientImage != nil {
                return true
            }
            if bubbleTheme.chat.message.outgoing.bubble.withWallpaper.fill.alpha <= 0.99 {
                return !hasPlainWallpaper
            }
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
