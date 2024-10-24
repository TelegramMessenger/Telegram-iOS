import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import UIKit
import AnimatedAvatarSetNode
import ReactionImageComponent
import WebPBinding
import AnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import TextFormat
import AppBundle
import AnimatedTextComponent

private let tagImage: UIImage? = {
    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/ReactionTagBackground"), color: .white)?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 15)
}()

private final class StarsButtonEffectLayer: SimpleLayer {
    let emitterLayer = CAEmitterLayer()
    
    override init() {
        super.init()
        
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        let color = UIColor(rgb: 0xffbe27)
        
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 25.0
        emitter.lifetime = 2.0
        emitter.velocity = 12.0
        emitter.velocityRange = 3
        emitter.scale = 0.1
        emitter.scaleRange = 0.08
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        
        self.emitterLayer.emitterCells = [emitter]
    }
    
    func update(size: CGSize) {
        if self.emitterLayer.emitterCells == nil {
            self.setup()
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.7)
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}

public final class ReactionIconView: PortalSourceView {
    private var animationLayer: InlineStickerItemLayer?
    
    private var context: AccountContext?
    private var fileId: Int64?
    private var file: TelegramMediaFile?
    private var animationCache: AnimationCache?
    private var animationRenderer: MultiAnimationRenderer?
    private var contentTintColor: UIColor?
    private var placeholderColor: UIColor?
    private var size: CGSize?
    private var animateIdle: Bool?
    private var reaction: MessageReaction.Reaction?
    
    private var isPaused: Bool = false
    private var isAnimationHidden: Bool = false
    
    private var disposable: Disposable?
    
    public var iconFrame: CGRect? {
        if let animationLayer = self.animationLayer {
            return animationLayer.frame
        }
        return nil
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    public func update(
        size: CGSize,
        context: AccountContext,
        file: TelegramMediaFile?,
        fileId: Int64,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        tintColor: UIColor?,
        placeholderColor: UIColor,
        animateIdle: Bool,
        reaction: MessageReaction.Reaction,
        transition: ContainedViewLayoutTransition
    ) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.contentTintColor = tintColor
        self.placeholderColor = placeholderColor
        self.size = size
        self.animateIdle = animateIdle
        self.reaction = reaction
        
        if self.fileId != fileId {
            self.fileId = fileId
            self.file = file
            
            self.animationLayer?.removeFromSuperlayer()
            self.animationLayer = nil
            
            if let _ = file {
                self.disposable?.dispose()
                self.disposable = nil
                
                self.reloadFile()
            } else {
                self.disposable?.dispose()
                
                self.disposable = (context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                |> deliverOnMainQueue).start(next: { [weak self] files in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.file = files[fileId]
                    strongSelf.reloadFile()
                }).strict()
            }
        }
        
        if let animationLayer = self.animationLayer {
            let iconSize: CGSize
            switch reaction {
            case .builtin:
                iconSize = CGSize(width: floor(size.width * 2.0), height: floor(size.height * 2.0))
                animationLayer.masksToBounds = false
                animationLayer.cornerRadius = 0.0
            case .custom:
                iconSize = CGSize(width: floor(size.width * 1.25), height: floor(size.height * 1.25))
                animationLayer.masksToBounds = true
                animationLayer.cornerRadius = floor(size.width * 0.2)
            case .stars:
                iconSize = CGSize(width: floor(size.width * 1.25), height: floor(size.height * 1.25))
                animationLayer.masksToBounds = false
                animationLayer.cornerRadius = 0.0
            }
            
            transition.updateFrame(layer: animationLayer, frame: CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
        }
        
        self.updateTintColor()
    }
    
    public func updateIsAnimationHidden(isAnimationHidden: Bool, transition: ContainedViewLayoutTransition) {
        if self.isAnimationHidden != isAnimationHidden {
            self.isAnimationHidden = isAnimationHidden
            
            if let animationLayer = self.animationLayer {
                transition.updateAlpha(layer: animationLayer, alpha: isAnimationHidden ? 0.0 : 1.0)
            }
        }
    }
    
    func updateIsPaused(isPaused: Bool) {
        guard let context = self.context, let animateIdle = self.animateIdle, let animationLayer = self.animationLayer else {
            return
        }
        self.isPaused = isPaused
        
        let isVisibleForAnimations = !self.isPaused && animateIdle && context.sharedContext.energyUsageSettings.loopEmoji
        if isVisibleForAnimations != animationLayer.isVisibleForAnimations {
            if isPaused {
                animationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak animationLayer] _ in
                    animationLayer?.removeFromSuperlayer()
                })
                self.animationLayer = nil
                self.reloadFile()
                if let animationLayer = self.animationLayer {
                    animationLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                }
            } else {
                animationLayer.isVisibleForAnimations = !self.isPaused && animateIdle && context.sharedContext.energyUsageSettings.loopEmoji
            }
        }
    }
    
    private func reloadFile() {
        guard let context = self.context, let file = self.file, let animationCache = self.animationCache, let animationRenderer = self.animationRenderer, let placeholderColor = self.placeholderColor, let size = self.size, let animateIdle = self.animateIdle, let reaction = self.reaction else {
            return
        }
        
        self.animationLayer?.removeFromSuperlayer()
        self.animationLayer = nil
        
        let iconSize: CGSize
        switch reaction {
        case .builtin:
            iconSize = CGSize(width: floor(size.width * 2.0), height: floor(size.height * 2.0))
        case .custom:
            iconSize = CGSize(width: floor(size.width * 1.25), height: floor(size.height * 1.25))
        case .stars:
            iconSize = CGSize(width: floor(size.width * 1.25), height: floor(size.height * 1.25))
        }
        
        let animationLayer = InlineStickerItemLayer(
            context: .account(context),
            userLocation: .other,
            attemptSynchronousLoad: false,
            emoji: ChatTextInputTextCustomEmojiAttribute(
                interactivelySelectedFromPackId: nil,
                fileId: file.fileId.id,
                file: file
            ),
            file: file,
            cache: animationCache,
            renderer: animationRenderer,
            unique: true,
            placeholderColor: placeholderColor,
            pointSize: CGSize(width: iconSize.width * 2.0, height: iconSize.height * 2.0)
        )
        self.animationLayer = animationLayer
        self.layer.addSublayer(animationLayer)
        
        switch reaction {
        case .builtin:
            animationLayer.masksToBounds = false
            animationLayer.cornerRadius = 0.0
        case .custom:
            animationLayer.masksToBounds = true
            animationLayer.cornerRadius = floor(size.width * 0.3)
        case .stars:
            animationLayer.masksToBounds = false
            animationLayer.cornerRadius = 0.0
        }
        
        animationLayer.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
        
        animationLayer.isVisibleForAnimations = !self.isPaused && animateIdle && context.sharedContext.energyUsageSettings.loopEmoji
        self.updateTintColor()
    }
    
    private func updateTintColor() {
        guard let file = self.file, let animationLayer = self.animationLayer else {
            return
        }
        var accentTint = false
        if file.isCustomTemplateEmoji {
            accentTint = true
        }
        for attribute in file.attributes {
            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                switch packReference {
                case let .id(id, _):
                    if id == 773947703670341676 || id == 2964141614563343 {
                        accentTint = true
                    }
                default:
                    break
                }
            }
        }
        if accentTint, let tintColor = self.contentTintColor {
            animationLayer.contentTintColor = tintColor
            animationLayer.dynamicColor = tintColor
        } else {
            animationLayer.contentTintColor = nil
            animationLayer.dynamicColor = nil
        }
    }
    
    func reset() {
        if let animationLayer = self.animationLayer {
            self.animationLayer = nil
            
            animationLayer.removeFromSuperlayer()
        }
        if let disposable = self.disposable {
            self.disposable = nil
            disposable.dispose()
        }
        
        if !self.subviews.isEmpty {
            for subview in Array(self.subviews) {
                subview.removeFromSuperview()
            }
        }
        
        self.context = nil
        self.fileId = nil
        self.file = nil
        self.animationCache = nil
        self.animationRenderer = nil
        self.placeholderColor = nil
        self.size = nil
        self.animateIdle = nil
        self.reaction = nil
        
        self.isAnimationHidden = false
    }
}

private final class ReactionImageCache {
    static let shared = ReactionImageCache()
    
    private var images: [MessageReaction.Reaction: UIImage] = [:]
    
    init() {
    }
    
    func get(reaction: MessageReaction.Reaction) -> UIImage? {
        return self.images[reaction]
    }
    
    func put(reaction: MessageReaction.Reaction, image: UIImage) {
        self.images[reaction] = image
    }
}

public final class ReactionButtonAsyncNode: ContextControllerSourceView {
    fileprivate final class ContainerButtonNode: UIButton {
        struct Colors: Equatable {
            var background: UInt32
            var foreground: UInt32
            var extractedBackground: UInt32
            var extractedForeground: UInt32
            var extractedSelectedForeground: UInt32
            var isSelected: Bool
        }
        
        struct Counter: Equatable {
            var components: [CounterLayout.Component]
            var extractedComponents: [CounterLayout.Component]
        }
        
        struct Layout: Equatable {
            var colors: Colors
            var size: CGSize
            var extractedSize: CGSize
            var counter: Counter?
            var isTag: Bool
        }
        
        private struct AnimationState {
            var fromCounter: Counter?
            var fromExtracted: Bool
            var fromColors: Colors
            var startTime: Double
            var duration: Double
            var curve: ComponentTransition.Animation.Curve
        }
        
        private var isExtracted: Bool = false
        private var currentLayout: Layout?
        
        private var animationState: AnimationState?
        private var animator: ConstantDisplayLinkAnimator?
        
        override init(frame: CGRect) {
            super.init(frame: CGRect())
            
            self.layer.contentsScale = UIScreenScale
            self.layer.contentsGravity = .topLeft
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func reset() {
            self.layer.contents = nil
            self.currentLayout = nil
        }
        
        func update(layout: Layout) {
            if self.currentLayout != layout {
                if let currentLayout = self.currentLayout, (currentLayout.counter != layout.counter || currentLayout.colors.isSelected != layout.colors.isSelected) {
                    self.animationState = AnimationState(fromCounter: currentLayout.counter, fromExtracted: self.isExtracted, fromColors: currentLayout.colors, startTime: CACurrentMediaTime(), duration: 0.15 * UIView.animationDurationFactor(), curve: .linear)
                }
                
                self.currentLayout = layout
                
                self.updateBackgroundImage(animated: false)
                self.updateAnimation()
            }
        }
        
        private func updateAnimation() {
            if let animationState = self.animationState {
                let timestamp = CACurrentMediaTime()
                if timestamp >= animationState.startTime + animationState.duration {
                    self.animationState = nil
                }
            }
            
            if self.animationState != nil {
                if self.animator == nil {
                    let animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateBackgroundImage(animated: false)
                        strongSelf.updateAnimation()
                    })
                    self.animator = animator
                    animator.isPaused = false
                }
            } else if let animator = self.animator {
                animator.invalidate()
                self.animator = nil
                
                self.updateBackgroundImage(animated: false)
            }
        }
        
        func updateIsExtracted(isExtracted: Bool, animated: Bool) {
            if self.isExtracted != isExtracted {
                self.isExtracted = isExtracted
                
                if let currentLayout = self.currentLayout {
                    self.animationState = AnimationState(
                        fromCounter: currentLayout.counter,
                        fromExtracted: !isExtracted,
                        fromColors: currentLayout.colors,
                        startTime: CACurrentMediaTime(),
                        duration: 0.5 * UIView.animationDurationFactor(),
                        curve: .spring
                    )
                    self.updateBackgroundImage(animated: false)
                    updateAnimation()
                } else {
                    self.updateBackgroundImage(animated: true)
                }
            }
        }
        
        private func updateBackgroundImage(animated: Bool) {
            guard let layout = self.currentLayout else {
                return
            }
            
            var counterComponents: [CounterLayout.Component]?
            if let counter = layout.counter {
                if self.isExtracted {
                    counterComponents = counter.extractedComponents
                } else {
                    counterComponents = counter.components
                }
            }
            
            var totalComponentWidth: CGFloat = 0.0
            if let counterComponents {
                for component in counterComponents {
                    totalComponentWidth += component.bounds.width
                }
            }
            
            let isExtracted = self.isExtracted
            let animationState = self.animationState
            
            var animationFraction: CGFloat
            var fixedTransitionDirection: Bool?
            if let animationState, animationState.fromCounter != nil {
                animationFraction = max(0.0, min(1.0, (CACurrentMediaTime() - animationState.startTime) / animationState.duration))
                animationFraction = animationState.curve.solve(at: animationFraction)
                if animationState.fromExtracted != isExtracted {
                    fixedTransitionDirection = isExtracted ? true : false
                }
            } else {
                animationFraction = 1.0
            }
            
            let targetImageSize = isExtracted ? layout.extractedSize : layout.size
            var imageSize = targetImageSize
            if let animationState {
                let sourceImageSize = animationState.fromExtracted ? layout.extractedSize : layout.size
                imageSize = CGSize(
                    width: floor(sourceImageSize.width * (1.0 - animationFraction) + targetImageSize.width * animationFraction),
                    height: floor(sourceImageSize.height * (1.0 - animationFraction) + targetImageSize.height * animationFraction)
                )
            }
            
            DispatchQueue.global().async { [weak self] in
                let image = generateImage(imageSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    
                    func drawContents(colors: Colors) {
                        let backgroundColor: UIColor
                        let foregroundColor: UIColor
                        if isExtracted {
                            backgroundColor = UIColor(argb: colors.extractedBackground)
                            if layout.colors.isSelected {
                                foregroundColor = UIColor(argb: colors.extractedSelectedForeground)
                            } else {
                                foregroundColor = UIColor(argb: colors.extractedForeground)
                            }
                        } else {
                            backgroundColor = UIColor(argb: colors.background)
                            foregroundColor = UIColor(argb: colors.foreground)
                        }
                        
                        context.setBlendMode(.copy)
                        
                        if layout.isTag {
                            if let tagImage {
                                let rect = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
                                
                                context.setFillColor(UIColor(rgb: layout.colors.background).cgColor)
                                context.fill(rect)
                                
                                UIGraphicsPushContext(context)
                                tagImage.draw(in: rect, blendMode: .destinationIn, alpha: 1.0)
                                UIGraphicsPopContext()
                                
                                context.setBlendMode(.destinationIn)
                                context.setFillColor(UIColor(white: 1.0, alpha: 0.5).cgColor)
                                context.fillEllipse(in: CGRect(origin: CGPoint(x: rect.width - 6.0 - 6.0, y: floor((rect.height - 6.0) * 0.5)), size: CGSize(width: 6.0, height: 6.0)))
                                context.setBlendMode(.copy)
                            }
                        } else {
                            context.setFillColor(backgroundColor.cgColor)
                            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
                            context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                            context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))
                        }
                        
                        if let counterComponents {
                            let isForegroundTransparent = foregroundColor.alpha < 1.0
                            context.setBlendMode(isForegroundTransparent ? .copy : .normal)
                            
                            let textOrigin: CGFloat
                            if layout.isTag {
                                textOrigin = 32.0
                            } else {
                                textOrigin = 36.0
                            }
                            
                            var leftTextOrigin = textOrigin
                            
                            for i in 0 ..< counterComponents.count {
                                let component = counterComponents[i]
                                var componentAlpha: CGFloat = 1.0
                                var componentVerticalOffset: CGFloat = 0.0
                                
                                var componentAnimationFraction = animationFraction
                                
                                if let animationState = animationState, let fromCounter = animationState.fromCounter {
                                    let fromCounterComponents = animationState.fromExtracted ? fromCounter.extractedComponents : fromCounter.components
                                    
                                    let countNorm = max(counterComponents.count, fromCounterComponents.count)
                                    let countFraction = CGFloat(i + 1) / CGFloat(countNorm)
                                    
                                    let minDurationCompression = 0.25
                                    let maxDurationCompression = 1.0
                                    
                                    let durationCompression = minDurationCompression * (1.0 - countFraction) + maxDurationCompression * countFraction
                                    
                                    let adjustedDuration = animationState.duration * durationCompression
                                    
                                    componentAnimationFraction = max(0.0, min(1.0, (CACurrentMediaTime() - animationState.startTime) / adjustedDuration))
                                    componentAnimationFraction = animationState.curve.solve(at: componentAnimationFraction)
                                    
                                    if i < fromCounterComponents.count {
                                        let previousComponent = fromCounterComponents[i]
                                        
                                        if previousComponent != component {
                                            componentAlpha = componentAnimationFraction
                                            componentVerticalOffset = -(1.0 - componentAnimationFraction) * 12.0
                                            let previousComponentAlpha = 1.0 - componentAlpha
                                            var previousComponentVerticalOffset = componentAnimationFraction * 12.0
                                            
                                            if let fixedTransitionDirection {
                                                if !fixedTransitionDirection {
                                                    componentVerticalOffset = -componentVerticalOffset
                                                    previousComponentVerticalOffset = -previousComponentVerticalOffset
                                                }
                                            } else {
                                                if previousComponent.string < component.string {
                                                    componentVerticalOffset = -componentVerticalOffset
                                                    previousComponentVerticalOffset = -previousComponentVerticalOffset
                                                }
                                            }
                                            
                                            var componentOrigin = leftTextOrigin
                                            componentOrigin = max(componentOrigin, layout.size.height / 2.0 + UIScreenPixel)
                                            let previousColor: UIColor
                                            if isForegroundTransparent {
                                                previousColor = foregroundColor.mixedWith(backgroundColor, alpha: 1.0 - previousComponentAlpha)
                                            } else {
                                                previousColor = foregroundColor.withMultipliedAlpha(previousComponentAlpha)
                                            }
                                            let string = NSAttributedString(string: previousComponent.string, font: Font.medium(11.0), textColor: previousColor)
                                            string.draw(at: previousComponent.bounds.origin.offsetBy(dx: componentOrigin, dy: floorToScreenPixels(size.height - previousComponent.bounds.height) / 2.0 + previousComponentVerticalOffset))
                                        }
                                    } else {
                                        componentAlpha = componentAnimationFraction
                                        componentVerticalOffset = -(1.0 - componentAnimationFraction) * 12.0
                                        if let fixedTransitionDirection {
                                            if !fixedTransitionDirection {
                                                componentVerticalOffset = -componentVerticalOffset
                                            }
                                        }
                                    }
                                }
                                
                                let componentOrigin = leftTextOrigin
                                let currentColor: UIColor
                                if isForegroundTransparent {
                                    currentColor = foregroundColor.mixedWith(backgroundColor, alpha: 1.0 - componentAlpha)
                                } else {
                                    currentColor = foregroundColor.withMultipliedAlpha(componentAlpha)
                                }
                                let string = NSAttributedString(string: component.string, font: Font.medium(11.0), textColor: currentColor)
                                string.draw(at: component.bounds.origin.offsetBy(dx: componentOrigin, dy: floorToScreenPixels(size.height - component.bounds.height) / 2.0 + componentVerticalOffset))
                                
                                leftTextOrigin += component.bounds.width
                            }
                        }
                    }
                    
                    if layout.isTag {
                        drawContents(colors: layout.colors)
                    } else {
                        if let animationState = animationState, animationState.fromColors.isSelected != layout.colors.isSelected {
                            var animationFraction: CGFloat = max(0.0, min(1.0, (CACurrentMediaTime() - animationState.startTime) / animationState.duration))
                            if !layout.colors.isSelected {
                                animationFraction = 1.0 - animationFraction
                            }
                            animationFraction = animationState.curve.solve(at: animationFraction)
                            
                            let center = CGPoint(x: 21.0, y: size.height / 2.0)
                            let diameter = 0.0 * (1.0 - animationFraction) + (size.width - center.x) * 2.0 * animationFraction
                            
                            context.beginPath()
                            context.addEllipse(in: CGRect(origin: CGPoint(x: center.x - diameter / 2.0, y: center.y - diameter / 2.0), size: CGSize(width: diameter, height: diameter)))
                            context.clip(using: .evenOdd)
                            drawContents(colors: layout.colors.isSelected ? layout.colors : animationState.fromColors)
                            
                            context.resetClip()
                            
                            context.beginPath()
                            context.addRect(CGRect(origin: CGPoint(), size: size))
                            context.addEllipse(in: CGRect(origin: CGPoint(x: center.x - diameter / 2.0, y: center.y - diameter / 2.0), size: CGSize(width: diameter, height: diameter)))
                            context.clip(using: .evenOdd)
                            drawContents(colors: layout.colors.isSelected ? animationState.fromColors : layout.colors)
                        } else {
                            drawContents(colors: layout.colors)
                        }
                    }
                    
                    UIGraphicsPopContext()
                })
                
                DispatchQueue.main.async {
                    if let strongSelf = self, let image = image {
                        let previousContents = strongSelf.layer.contents
                        
                        //ASDisplayNodeSetResizableContents(strongSelf.layer, image)
                        strongSelf.layer.contents = image.cgImage
                        
                        if animated, let previousContents = previousContents {
                            strongSelf.layer.animate(from: previousContents as! CGImage, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
                        }
                    }
                }
            }
        }
    }
    
    fileprivate final class CounterLayout {
        struct Spec: Equatable {
            var stringComponents: [String]
        }
        
        struct Component: Equatable {
            var string: String
            var bounds: CGRect
        }
        
        private static let maxDigitWidth: CGFloat = {
            var maxWidth: CGFloat = 0.0
            for i in 0 ... 9 {
                let string = NSAttributedString(string: "\(i)", font: Font.medium(11.0), textColor: .black)
                let boundingRect = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                maxWidth = max(maxWidth, boundingRect.width)
            }
            return ceil(maxWidth)
        }()
        
        let spec: Spec
        let components: [Component]
        let size: CGSize
        
        init(
            spec: Spec,
            components: [Component],
            size: CGSize
        ) {
            self.spec = spec
            self.components = components
            self.size = size
        }
        
        static func calculate(spec: Spec, previousLayout: CounterLayout?) -> CounterLayout {
            let size: CGSize
            let components: [Component]
            if let previousLayout = previousLayout, previousLayout.spec == spec {
                size = previousLayout.size
                components = previousLayout.components
            } else {
                var resultSize = CGSize()
                var resultComponents: [Component] = []
                for i in 0 ..< spec.stringComponents.count {
                    let component = spec.stringComponents[i]
                    
                    let string = NSAttributedString(string: component, font: Font.medium(11.0), textColor: .black)
                    let boundingRect = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                    
                    resultComponents.append(Component(string: component, bounds: boundingRect))
                    
                    if i == spec.stringComponents.count - 1 && component[component.startIndex].isNumber {
                        resultSize.width += CounterLayout.maxDigitWidth
                    } else {
                        resultSize.width += boundingRect.width
                    }
                    resultSize.height = max(resultSize.height, boundingRect.height)
                }
                size = CGSize(width: ceil(resultSize.width), height: ceil(resultSize.height))
                components = resultComponents
            }
            
            return CounterLayout(
                spec: spec,
                components: components,
                size: size
            )
        }
    }
    
    fileprivate final class Layout {
        struct Spec: Equatable {
            var component: ReactionButtonComponent
        }
        
        let spec: Spec
        
        let backgroundColor: UInt32
        let sideInsets: CGFloat
        
        let imageFrame: CGRect
        let imageSize: CGSize
        
        let counterLayout: CounterLayout?
        let extractedCounterLayout: CounterLayout?
        
        let backgroundLayout: ContainerButtonNode.Layout
        
        let size: CGSize
        let extractedSize: CGSize
        
        init(
            spec: Spec,
            backgroundColor: UInt32,
            sideInsets: CGFloat,
            imageFrame: CGRect,
            imageSize: CGSize,
            counterLayout: CounterLayout?,
            extractedCounterLayout: CounterLayout?,
            backgroundLayout: ContainerButtonNode.Layout,
            size: CGSize,
            extractedSize: CGSize
        ) {
            self.spec = spec
            self.backgroundColor = backgroundColor
            self.sideInsets = sideInsets
            self.imageFrame = imageFrame
            self.imageSize = imageSize
            self.counterLayout = counterLayout
            self.extractedCounterLayout = extractedCounterLayout
            self.backgroundLayout = backgroundLayout
            self.size = size
            self.extractedSize = extractedSize
        }
        
        static func calculate(spec: Spec, currentLayout: Layout?) -> Layout {
            let sideInsets: CGFloat = 11.0
            let height: CGFloat = 30.0
            let spacing: CGFloat = 2.0
            
            let boundingImageSize = CGSize(width: 20.0, height: 20.0)
            let imageSize: CGSize = boundingImageSize
            
            var counterComponents: [String] = []
            var extractedCounterComponents: [String] = []
            var hasTitle = false
            if let title = spec.component.reaction.title, !title.isEmpty {
                hasTitle = true
                counterComponents.append(title)
                extractedCounterComponents.append(title)
            } else {
                #if DEBUG && false
                let compactString = "4K"
                #else
                let compactString = countString(Int64(spec.component.count))
                #endif
                
                for character in compactString {
                    counterComponents.append(String(character))
                }
                for character in "\(spec.component.count)" {
                    extractedCounterComponents.append(String(character))
                }
            }
            
            let backgroundColor = spec.component.chosenOrder != nil ? spec.component.colors.selectedBackground : spec.component.colors.deselectedBackground
            
            let imageFrame: CGRect
            if spec.component.isTag {
                imageFrame = CGRect(origin: CGPoint(x: 6.0 + floorToScreenPixels((boundingImageSize.width - imageSize.width) / 2.0), y: floorToScreenPixels((height - imageSize.height) / 2.0)), size: imageSize)
            } else {
                imageFrame = CGRect(origin: CGPoint(x: sideInsets + floorToScreenPixels((boundingImageSize.width - imageSize.width) / 2.0), y: floorToScreenPixels((height - imageSize.height) / 2.0)), size: imageSize)
            }
            
            var counterLayout: CounterLayout?
            var extractedCounterLayout: CounterLayout?
            
            var size = CGSize(width: boundingImageSize.width + sideInsets * 2.0, height: height)
            var extractedSize = size
            if !spec.component.avatarPeers.isEmpty {
                size.width += 4.0 + 24.0
                if spec.component.avatarPeers.count > 1 {
                    size.width += CGFloat(spec.component.avatarPeers.count - 1) * 12.0
                } else {
                    size.width -= 2.0
                }
                extractedSize = size
            } else if spec.component.isTag && !hasTitle {
                size.width += 1.0
                extractedSize = size
            } else {
                do {
                    let counterSpec = CounterLayout.Spec(
                        stringComponents: counterComponents
                    )
                    let counterValue: CounterLayout
                    if let currentCounter = currentLayout?.counterLayout, currentCounter.spec == counterSpec {
                        counterValue = currentCounter
                    } else {
                        counterValue = CounterLayout.calculate(
                            spec: counterSpec,
                            previousLayout: currentLayout?.counterLayout
                        )
                    }
                    counterLayout = counterValue
                    size.width += spacing + counterValue.size.width
                    if spec.component.isTag {
                        size.width += 5.0
                    }
                }
                do {
                    let extractedCounterSpec = CounterLayout.Spec(
                        stringComponents: extractedCounterComponents
                    )
                    let extractedCounterValue: CounterLayout
                    if let currentExtractedCounter = currentLayout?.extractedCounterLayout, currentExtractedCounter.spec == extractedCounterSpec {
                        extractedCounterValue = currentExtractedCounter
                    } else {
                        extractedCounterValue = CounterLayout.calculate(
                            spec: extractedCounterSpec,
                            previousLayout: currentLayout?.extractedCounterLayout
                        )
                    }
                    extractedCounterLayout = extractedCounterValue
                    extractedSize.width += spacing + extractedCounterValue.size.width
                    if spec.component.isTag {
                        extractedSize.width += 5.0
                    }
                }
            }
            
            let backgroundColors: ReactionButtonAsyncNode.ContainerButtonNode.Colors
            
            if case .stars = spec.component.reaction.value {
                backgroundColors = ReactionButtonAsyncNode.ContainerButtonNode.Colors(
                    background: spec.component.chosenOrder != nil ? spec.component.colors.selectedStarsBackground : spec.component.colors.deselectedStarsBackground,
                    foreground: spec.component.chosenOrder != nil ? spec.component.colors.selectedStarsForeground : spec.component.colors.deselectedStarsForeground,
                    extractedBackground: spec.component.chosenOrder != nil ? spec.component.colors.selectedStarsBackground : spec.component.colors.deselectedStarsBackground,
                    extractedForeground: spec.component.chosenOrder != nil ? spec.component.colors.selectedStarsForeground : spec.component.colors.deselectedStarsForeground,
                    extractedSelectedForeground: spec.component.colors.extractedSelectedForeground,
                    isSelected: spec.component.chosenOrder != nil
                )
            } else {
                backgroundColors = ReactionButtonAsyncNode.ContainerButtonNode.Colors(
                    background: spec.component.chosenOrder != nil ? spec.component.colors.selectedBackground : spec.component.colors.deselectedBackground,
                    foreground: spec.component.chosenOrder != nil ? spec.component.colors.selectedForeground : spec.component.colors.deselectedForeground,
                    extractedBackground: spec.component.colors.extractedBackground,
                    extractedForeground: spec.component.colors.extractedForeground,
                    extractedSelectedForeground: spec.component.colors.extractedSelectedForeground,
                    isSelected: spec.component.chosenOrder != nil
                )
            }
            var backgroundCounter: ReactionButtonAsyncNode.ContainerButtonNode.Counter?
            if let counterLayout, let extractedCounterLayout {
                backgroundCounter = ReactionButtonAsyncNode.ContainerButtonNode.Counter(
                    components: counterLayout.components,
                    extractedComponents: extractedCounterLayout.components
                )
            }
            let backgroundLayout = ContainerButtonNode.Layout(
                colors: backgroundColors,
                size: size,
                extractedSize: extractedSize,
                counter: backgroundCounter,
                isTag: spec.component.isTag
            )
            
            return Layout(
                spec: spec,
                backgroundColor: backgroundColor,
                sideInsets: sideInsets,
                imageFrame: imageFrame,
                imageSize: boundingImageSize,
                counterLayout: counterLayout,
                extractedCounterLayout: extractedCounterLayout,
                backgroundLayout: backgroundLayout,
                size: size,
                extractedSize: extractedSize
            )
        }
    }
    
    private var layout: Layout?
    
    public let containerView: ContextExtractedContentContainingView
    private let buttonNode: ContainerButtonNode
    private var starsEffectLayer: StarsButtonEffectLayer?
    public var iconView: ReactionIconView?
    private var avatarsView: AnimatedAvatarSetView?
    
    private let iconImageDisposable = MetaDisposable()
    
    private var ignoreButtonTap: Bool = false
    
    private var tapAnimationLink: SharedDisplayLinkDriver.Link?
    private var tapAnimationValue: CGFloat = 0.0
    private var previousTapAnimationTimestamp: Double = 0.0
    private var previousTapTimestamp: Double = 0.0
    private var tapCounterView: StarsReactionCounterView?
    
    public var activateAfterCompletion: Bool = false {
        didSet {
            if self.activateAfterCompletion {
                self.contextGesture?.activatedAfterCompletion = { [weak self] point, _ in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.buttonNode.bounds.contains(point) {
                        strongSelf.pressed()
                    }
                }
            } else {
                self.contextGesture?.activatedAfterCompletion = nil
            }
        }
    }
    
    override init(frame: CGRect) {
        self.containerView = ContextExtractedContentContainingView()
        
        self.containerView.isMultipleTouchEnabled = false
        self.containerView.isExclusiveTouch = true
        
        self.buttonNode = ContainerButtonNode()
        
        self.iconView = ReactionIconView()
        self.iconView?.isUserInteractionEnabled = false
        
        super.init(frame: frame)
        
        self.targetViewForActivationProgress = self.containerView.contentView
        
        self.addSubview(self.containerView)
        self.containerView.contentView.addSubview(self.buttonNode)
        if let iconView = self.iconView {
            self.buttonNode.addSubview(iconView)
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        
        self.isGestureEnabled = true
        self.beginDelay = 0.0
        
        self.containerView.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, _ in
            guard let self else {
                return
            }
            self.buttonNode.updateIsExtracted(isExtracted: isExtracted, animated: true)
            
            if let iconView = self.iconView {
                iconView.updateIsPaused(isPaused: isExtracted)
            }
        }
        
        if self.activateAfterCompletion {
            self.contextGesture?.activatedAfterCompletion = { [weak self] point, _ in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.buttonNode.bounds.contains(point) {
                    strongSelf.pressed()
                }
            }
        }
        
        self.contextGesture?.cancelGesturesOnActivation = { [weak self] in
            guard let self else {
                return
            }
            self.buttonNode.isUserInteractionEnabled = false
            self.buttonNode.cancelTracking(with: nil)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.buttonNode.isUserInteractionEnabled = true
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.iconImageDisposable.dispose()
    }
    
    func reset() {
        self.iconView?.reset()
        self.layout = nil
        
        self.buttonNode.reset()
    }
    
    @objc private func pressed() {
        guard let layout = self.layout else {
            return
        }
        if self.ignoreButtonTap {
            return
        }
        layout.spec.component.action(self, layout.spec.component.reaction.value, self.containerView)
        
        if case .stars = layout.spec.component.reaction.value {
            self.addStarsTap()
        }
    }
    
    private func addStarsTap() {
        let timestamp = CACurrentMediaTime()
        
        self.previousTapTimestamp = timestamp
        
        let deltaTime = timestamp - self.previousTapAnimationTimestamp
        if deltaTime < 0.4 || self.tapCounterView != nil {
            self.previousTapAnimationTimestamp = timestamp
            
            if let superview = self.superview {
                for subview in superview.subviews {
                    if subview !== self {
                        subview.layer.zPosition = 0.0
                    }
                }
            }
            self.layer.zPosition = 1.0
            
            if let tapCounterView = self.tapCounterView {
                tapCounterView.add()
            } else {
                let tapCounterView = StarsReactionCounterView(count: 2)
                self.tapCounterView = tapCounterView
                self.addSubview(tapCounterView)
                tapCounterView.animateIn()
                if let layout = self.layout {
                    tapCounterView.frame = CGRect(origin: CGPoint(x: layout.size.width * 0.5, y: -70.0), size: CGSize())
                }
            }
        }
        self.tapAnimationValue = min(1.0, self.tapAnimationValue)
        
        if self.tapAnimationLink == nil {
            self.previousTapAnimationTimestamp = timestamp
            self.updateTapAnimation()
            
            self.tapAnimationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                guard let self else {
                    return
                }
                self.updateTapAnimation()
            })
        }
    }
    
    private func updateTapAnimation() {
        let timestamp = CACurrentMediaTime()
        let deltaTime = min(timestamp - self.previousTapAnimationTimestamp, 1.0 / 60.0)
        self.previousTapAnimationTimestamp = timestamp
        
        let decelerationRate: CGFloat = 0.98
        let lastTapDeltaTime = max(0.0, timestamp - self.previousTapTimestamp)
        let tapAnimationTargetValue: CGFloat
        if self.tapCounterView != nil {
            tapAnimationTargetValue = 1.0 * CGFloat(pow(Double(decelerationRate), 1200.0 * lastTapDeltaTime))
        } else {
            tapAnimationTargetValue = 0.0
        }
        
        let advancementFraction = deltaTime * UIView.animationDurationFactor() * 120.0 / 60.0
        self.tapAnimationValue = self.tapAnimationValue * (1.0 - advancementFraction) + tapAnimationTargetValue * advancementFraction
        
        if self.tapAnimationValue <= 0.001 && self.previousTapTimestamp + 2.0 < timestamp {
            self.tapAnimationValue = 0.0
            self.tapAnimationLink?.invalidate()
            self.tapAnimationLink = nil
            
            if let tapCounterView = self.tapCounterView {
                self.tapCounterView = nil
                tapCounterView.alpha = 0.0
                tapCounterView.animateOut(completion: { [weak tapCounterView] in
                    tapCounterView?.removeFromSuperview()
                })
            }
        }
        
        let tapAnimationFactor = max(0.0, min(1.0, self.tapAnimationValue / 0.3))
        
        let scaleValue: CGFloat = 1.0 + tapAnimationFactor * 0.5
        self.buttonNode.layer.transform = CATransform3DMakeScale(scaleValue, scaleValue, 1.0)
    }
    
    fileprivate func apply(layout: Layout, animation: ListViewItemUpdateAnimation, arguments: ReactionButtonsAsyncLayoutContainer.Arguments) {
        self.containerView.frame = CGRect(origin: CGPoint(), size: layout.extractedSize)
        self.containerView.contentView.frame = CGRect(origin: CGPoint(), size: layout.extractedSize)
        self.containerView.contentRect = CGRect(origin: CGPoint(), size: layout.extractedSize)
        
        let buttonFrame = CGRect(origin: CGPoint(), size: layout.size)
        animation.animator.updatePosition(layer: self.buttonNode.layer, position: buttonFrame.center, completion: nil)
        animation.animator.updateBounds(layer: self.buttonNode.layer, bounds: CGRect(origin: CGPoint(), size: buttonFrame.size), completion: nil)
        
        if case .stars = layout.spec.component.reaction.value {
            let starsEffectLayer: StarsButtonEffectLayer
            if let current = self.starsEffectLayer {
                starsEffectLayer = current
            } else {
                starsEffectLayer = StarsButtonEffectLayer()
                self.starsEffectLayer = starsEffectLayer
                if let iconView = self.iconView {
                    self.buttonNode.layer.insertSublayer(starsEffectLayer, below: iconView.layer)
                } else {
                    self.buttonNode.layer.insertSublayer(starsEffectLayer, at: 0)
                }
            }
            let starsEffectLayerFrame = CGRect(origin: CGPoint(), size: layout.size)
            animation.animator.updateFrame(layer: starsEffectLayer, frame: starsEffectLayerFrame, completion: nil)
            starsEffectLayer.update(size: starsEffectLayerFrame.size)
        } else {
            if let starsEffectLayer = self.starsEffectLayer {
                self.starsEffectLayer = nil
                starsEffectLayer.removeFromSuperlayer()
            }
        }
        
        self.buttonNode.update(layout: layout.backgroundLayout)
        
        if let iconView = self.iconView {
            animation.animator.updateFrame(layer: iconView.layer, frame: layout.imageFrame, completion: nil)
            
            if let fileId = layout.spec.component.reaction.animationFileId ?? layout.spec.component.reaction.centerAnimation?.fileId.id {
                let animateIdle: Bool
                if layout.spec.component.isTag {
                    animateIdle = false
                } else if case .custom = layout.spec.component.reaction.value {
                    animateIdle = true
                } else {
                    animateIdle = false
                }
                
                let tintColor: UIColor
                if layout.backgroundLayout.colors.isSelected {
                    if layout.spec.component.colors.selectedForeground != 0 {
                        tintColor = UIColor(argb: layout.spec.component.colors.selectedForeground)
                    } else {
                        tintColor = .white
                    }
                } else {
                    tintColor = UIColor(argb: layout.spec.component.colors.deselectedForeground)
                }
                
                iconView.update(
                    size: layout.imageFrame.size,
                    context: layout.spec.component.context,
                    file: layout.spec.component.reaction.centerAnimation,
                    fileId: fileId,
                    animationCache: arguments.animationCache,
                    animationRenderer: arguments.animationRenderer,
                    tintColor: tintColor,
                    placeholderColor: layout.spec.component.chosenOrder != nil ? UIColor(argb: layout.spec.component.colors.selectedMediaPlaceholder) : UIColor(argb: layout.spec.component.colors.deselectedMediaPlaceholder),
                    animateIdle: animateIdle,
                    reaction: layout.spec.component.reaction.value,
                    transition: animation.transition
                )
            }
        }
        
        if !layout.spec.component.avatarPeers.isEmpty {
            let avatarsView: AnimatedAvatarSetView
            if let current = self.avatarsView {
                avatarsView = current
            } else {
                avatarsView = AnimatedAvatarSetView()
                avatarsView.isUserInteractionEnabled = false
                self.avatarsView = avatarsView
                self.buttonNode.addSubview(avatarsView)
            }
            let content = AnimatedAvatarSetContext().update(peers: layout.spec.component.avatarPeers, animated: false)
            let avatarsSize = avatarsView.update(
                context: layout.spec.component.context,
                content: content,
                itemSize: CGSize(width: 24.0, height: 24.0),
                customSpacing: 10.0,
                animation: animation,
                synchronousLoad: false
            )
            animation.animator.updateFrame(layer: avatarsView.layer, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(layout.imageFrame.midX + layout.imageSize.width / 2.0) + 4.0, y: floorToScreenPixels((layout.size.height - avatarsSize.height) / 2.0)), size: CGSize(width: avatarsSize.width, height: avatarsSize.height)), completion: nil)
        } else if let avatarsView = self.avatarsView {
            self.avatarsView = nil
            if animation.isAnimated {
                animation.animator.updateAlpha(layer: avatarsView.layer, alpha: 0.0, completion: { [weak avatarsView] _ in
                    avatarsView?.removeFromSuperview()
                })
                animation.animator.updateScale(layer: avatarsView.layer, scale: 0.01, completion: nil)
            } else {
                avatarsView.removeFromSuperview()
            }
        }
        
        self.layout = layout
    }
    
    public static func asyncLayout(_ item: ReactionNodePool.Item?) -> (ReactionButtonComponent) -> (size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation, _ arguments: ReactionButtonsAsyncLayoutContainer.Arguments) -> ReactionNodePool.Item) {
        let currentLayout = item?.view.layout
        
        return { component in
            let spec = Layout.Spec(component: component)
            
            let layout: Layout
            if let currentLayout = currentLayout, currentLayout.spec == spec {
                layout = currentLayout
            } else {
                layout = Layout.calculate(spec: spec, currentLayout: currentLayout)
            }
            
            return (size: layout.size, apply: { animation, arguments in
                var animation = animation
                let updatedItem: ReactionNodePool.Item
                if let item = item {
                    updatedItem = item
                } else {
                    updatedItem = ReactionNodePool.shared.take()
                    animation = .None
                }
                
                updatedItem.view.apply(layout: layout, animation: animation, arguments: arguments)
                
                return updatedItem
            })
        }
    }
}

public final class ReactionButtonComponent: Equatable {
    public struct Reaction: Equatable {
        public var value: MessageReaction.Reaction
        public var centerAnimation: TelegramMediaFile?
        public var animationFileId: Int64?
        public var title: String?
        
        public init(value: MessageReaction.Reaction, centerAnimation: TelegramMediaFile?, animationFileId: Int64?, title: String?) {
            self.value = value
            self.centerAnimation = centerAnimation
            self.animationFileId = animationFileId
            self.title = title
        }
        
        public static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.centerAnimation?.fileId != rhs.centerAnimation?.fileId {
                return false
            }
            if lhs.animationFileId != rhs.animationFileId {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            return true
        }
    }
    
    public struct Colors: Equatable {
        public var deselectedBackground: UInt32
        public var selectedBackground: UInt32
        public var deselectedForeground: UInt32
        public var selectedForeground: UInt32
        public var deselectedStarsBackground: UInt32
        public var selectedStarsBackground: UInt32
        public var deselectedStarsForeground: UInt32
        public var selectedStarsForeground: UInt32
        public var extractedBackground: UInt32
        public var extractedForeground: UInt32
        public var extractedSelectedForeground: UInt32
        public var deselectedMediaPlaceholder: UInt32
        public var selectedMediaPlaceholder: UInt32
        
        public init(
            deselectedBackground: UInt32,
            selectedBackground: UInt32,
            deselectedForeground: UInt32,
            selectedForeground: UInt32,
            deselectedStarsBackground: UInt32,
            selectedStarsBackground: UInt32,
            deselectedStarsForeground: UInt32,
            selectedStarsForeground: UInt32,
            extractedBackground: UInt32,
            extractedForeground: UInt32,
            extractedSelectedForeground: UInt32,
            deselectedMediaPlaceholder: UInt32,
            selectedMediaPlaceholder: UInt32
        ) {
            self.deselectedBackground = deselectedBackground
            self.selectedBackground = selectedBackground
            self.deselectedForeground = deselectedForeground
            self.selectedForeground = selectedForeground
            self.deselectedStarsBackground = deselectedStarsBackground
            self.selectedStarsBackground = selectedStarsBackground
            self.deselectedStarsForeground = deselectedStarsForeground
            self.selectedStarsForeground = selectedStarsForeground
            self.extractedBackground = extractedBackground
            self.extractedForeground = extractedForeground
            self.extractedSelectedForeground = extractedSelectedForeground
            self.deselectedMediaPlaceholder = deselectedMediaPlaceholder
            self.selectedMediaPlaceholder = selectedMediaPlaceholder
        }
    }
    
    public let context: AccountContext
    public let colors: Colors
    public let reaction: Reaction
    public let avatarPeers: [EnginePeer]
    public let isTag: Bool
    public let count: Int
    public let chosenOrder: Int?
    public let action: (ReactionButtonAsyncNode, MessageReaction.Reaction, ContextExtractedContentContainingView?) -> Void

    public init(
        context: AccountContext,
        colors: Colors,
        reaction: Reaction,
        avatarPeers: [EnginePeer],
        isTag: Bool,
        count: Int,
        chosenOrder: Int?,
        action: @escaping (ReactionButtonAsyncNode, MessageReaction.Reaction, ContextExtractedContentContainingView?) -> Void
    ) {
        self.context = context
        self.colors = colors
        self.reaction = reaction
        self.avatarPeers = avatarPeers
        self.isTag = isTag
        self.count = count
        self.chosenOrder = chosenOrder
        self.action = action
    }

    public static func ==(lhs: ReactionButtonComponent, rhs: ReactionButtonComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.reaction != rhs.reaction {
            return false
        }
        if lhs.avatarPeers != rhs.avatarPeers {
            return false
        }
        if lhs.isTag != rhs.isTag {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.chosenOrder != rhs.chosenOrder {
            return false
        }
        return true
    }
}

public final class ReactionNodePool {
    static let shared = ReactionNodePool()
    
    public final class Item {
        public let view: ReactionButtonAsyncNode
        private weak var pool: ReactionNodePool?
        
        init(view: ReactionButtonAsyncNode, pool: ReactionNodePool) {
            self.view = view
            self.pool = pool
        }
        
        deinit {
            self.pool?.putBack(view: self.view)
        }
    }
    
    private var views: [ReactionButtonAsyncNode] = []
    
    func putBack(view: ReactionButtonAsyncNode) {
        assert(view.superview == nil)
        assert(view.layer.superlayer == nil)
        
        if self.views.count < 64 {
            view.reset()
            self.views.append(view)
        }
    }
    
    func take() -> Item {
        if !self.views.isEmpty {
            let view = self.views.removeLast()
            view.layer.removeAllAnimations()
            view.alpha = 1.0
            view.isHidden = false
            view.transform = .identity
            return Item(view: view, pool: self)
        } else {
            return Item(view: ReactionButtonAsyncNode(), pool: self)
        }
    }
}

public final class ReactionButtonsAsyncLayoutContainer {
    public final class Arguments {
        public let animationCache: AnimationCache
        public let animationRenderer: MultiAnimationRenderer
        
        public init(
            animationCache: AnimationCache,
            animationRenderer: MultiAnimationRenderer
        ) {
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
        }
    }
    
    public struct Reaction {
        public var reaction: ReactionButtonComponent.Reaction
        public var count: Int
        public var peers: [EnginePeer]
        public var chosenOrder: Int?
        
        public init(
            reaction: ReactionButtonComponent.Reaction,
            count: Int,
            peers: [EnginePeer],
            chosenOrder: Int?
        ) {
            self.reaction = reaction
            self.count = count
            self.peers = peers
            self.chosenOrder = chosenOrder
        }
    }
    
    public struct Result {
        public struct Item {
            public var size: CGSize
        }
        
        public var items: [Item]
        public var apply: (ListViewItemUpdateAnimation, Arguments) -> ApplyResult
    }
    
    public struct ApplyResult {
        public struct Item {
            public var value: MessageReaction.Reaction
            public var node: ReactionNodePool.Item
            public var size: CGSize
        }
        
        public var items: [Item]
        public var removedNodes: [ReactionNodePool.Item]
    }
    
    public private(set) var buttons: [MessageReaction.Reaction: ReactionNodePool.Item] = [:]
    
    public init() {
    }
    
    deinit {
        for (_, button) in self.buttons {
            button.view.removeFromSuperview()
        }
    }
    
    public func update(
        context: AccountContext,
        action: @escaping (ReactionButtonAsyncNode, MessageReaction.Reaction, ContextExtractedContentContainingView?) -> Void,
        reactions: [ReactionButtonsAsyncLayoutContainer.Reaction],
        colors: ReactionButtonComponent.Colors,
        isTag: Bool,
        constrainedWidth: CGFloat
    ) -> Result {
        var items: [Result.Item] = []
        var applyItems: [(key: MessageReaction.Reaction, size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation, _ arguments: Arguments) -> ReactionNodePool.Item)] = []
        
        var reactions = reactions.sorted(by: { lhs, rhs in
            var lhsCount = lhs.count
            if lhs.chosenOrder != nil {
                lhsCount -= 1
            }
            var rhsCount = rhs.count
            if rhs.chosenOrder != nil {
                rhsCount -= 1
            }
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            
            if (lhs.chosenOrder != nil) != (rhs.chosenOrder != nil) {
                if lhs.chosenOrder != nil {
                    return true
                } else {
                    return false
                }
            } else if let lhsIndex = lhs.chosenOrder, let rhsIndex = rhs.chosenOrder {
                return lhsIndex < rhsIndex
            }
            
            return false
        })
        
        if let index = reactions.firstIndex(where: {
            if case .stars = $0.reaction.value {
                return true
            } else {
                return false
            }
        }) {
            let value = reactions[index]
            reactions.remove(at: index)
            reactions.insert(value, at: 0)
        }
        
        var validIds = Set<MessageReaction.Reaction>()
        for reaction in reactions {
            validIds.insert(reaction.reaction.value)
            
            var avatarPeers = reaction.peers
            for i in 0 ..< avatarPeers.count {
                if avatarPeers[i].id == context.account.peerId {
                    let peer = avatarPeers[i]
                    avatarPeers.remove(at: i)
                    avatarPeers.insert(peer, at: 0)
                    break
                }
            }
            
            let viewLayout = ReactionButtonAsyncNode.asyncLayout(self.buttons[reaction.reaction.value])
            let (size, apply) = viewLayout(ReactionButtonComponent(
                context: context,
                colors: colors,
                reaction: reaction.reaction,
                avatarPeers: isTag ? [] : avatarPeers,
                isTag: isTag,
                count: isTag ? 0 : reaction.count,
                chosenOrder: reaction.chosenOrder,
                action: action
            ))
            
            items.append(Result.Item(
                size: size
            ))
            applyItems.append((reaction.reaction.value, size, apply))
        }
        
        var removeIds: [MessageReaction.Reaction] = []
        for (id, _) in self.buttons {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        var removedNodes: [ReactionNodePool.Item] = []
        for id in removeIds {
            if let item = self.buttons.removeValue(forKey: id) {
                removedNodes.append(item)
            }
        }
        
        return Result(
            items: items,
            apply: { animation, arguments in
                var items: [ApplyResult.Item] = []
                for (key, size, apply) in applyItems {
                    let nodeItem = apply(animation, arguments)
                    items.append(ApplyResult.Item(value: key, node: nodeItem, size: size))
                    
                    if let current = self.buttons[key] {
                        assert(current === nodeItem)
                    } else {
                        self.buttons[key] = nodeItem
                    }
                }
                
                return ApplyResult(items: items, removedNodes: removedNodes)
            }
        )
    }
}

private final class StarsReactionCounterView: UIView {
    private let portalSource: PortalSourceView
    private let label = ComponentView<Empty>()
    
    private var count: Int
    
    init(count: Int) {
        self.count = count
        
        let portalSource = PortalSourceView()
        portalSource.needsGlobalPortal = true
        self.portalSource = portalSource
        
        super.init(frame: CGRect())
        
        self.addSubview(portalSource)
        
        portalSource.frame = CGRect(origin: CGPoint(x: -200.0, y: -200.0), size: CGSize(width: 400.0, height: 400.0))
        
        self.update(transition: .immediate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateIn() {
        if let labelView = self.label.view {
            labelView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.15)
            labelView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        if let labelView = self.label.view {
            labelView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.15, removeOnCompletion: false)
            labelView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                completion()
            })
        } else {
            completion()
        }
    }
    
    func add() {
        self.count += 1
        self.update(transition: .easeInOut(duration: 0.15))
    }
    
    func update(transition: ComponentTransition) {
        var items: [AnimatedTextComponent.Item] = []
        items.append(AnimatedTextComponent.Item(id: AnyHashable(0), content: .text("+")))
        items.append(AnimatedTextComponent.Item(id: AnyHashable(1), content: .number(self.count, minDigits: 1)))
        
        let labelSize = self.label.update(
            transition: transition,
            component: AnyComponent(AnimatedTextComponent(
                font: Font.with(size: 40.0, design: .round, weight: .bold),
                color: .white,
                items: items
            )),
            environment: {},
            containerSize: CGSize(width: 200.0, height: 200.0)
        )
        let labelFrame = CGRect(origin: CGPoint(x: floor((self.portalSource.bounds.width - labelSize.width) * 0.5), y: floor((self.portalSource.bounds.height - labelSize.height) * 0.5)), size: labelSize)
        
        if let labelView = self.label.view {
            if labelView.superview == nil {
                self.portalSource.addSubview(labelView)
                labelView.layer.shadowColor = UIColor.black.cgColor
                labelView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
                labelView.layer.shadowOpacity = 0.45
                labelView.layer.shadowRadius = 9.0
            }
            
            transition.setFrame(view: labelView, frame: labelFrame)
        }
    }
}
