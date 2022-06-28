import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import UIKit
import AnimatedAvatarSetNode
import ReactionImageComponent
import WebPBinding

public final class ReactionIconView: PortalSourceView {
    public let imageView: UIImageView
    
    override public init(frame: CGRect) {
        self.imageView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.imageView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.imageView, frame: CGRect(origin: CGPoint(), size: size))
    }
}

private final class ReactionImageCache {
    static let shared = ReactionImageCache()
    
    private var images: [String: UIImage] = [:]
    
    init() {
    }
    
    func get(reaction: String) -> UIImage? {
        return self.images[reaction]
    }
    
    func put(reaction: String, image: UIImage) {
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
            var isSelected: Bool
        }
        
        struct Counter: Equatable {
            var components: [CounterLayout.Component]
        }
        
        struct Layout: Equatable {
            var colors: Colors
            var size: CGSize
            var counter: Counter?
        }
        
        private struct AnimationState {
            var fromCounter: Counter?
            var fromColors: Colors
            var startTime: Double
            var duration: Double
        }
        
        private var isExtracted: Bool = false
        private var currentLayout: Layout?
        
        private var animationState: AnimationState?
        private var animator: ConstantDisplayLinkAnimator?
        
        override init(frame: CGRect) {
            super.init(frame: CGRect())
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
                    self.animationState = AnimationState(fromCounter: currentLayout.counter, fromColors: currentLayout.colors, startTime: CACurrentMediaTime(), duration: 0.15 * UIView.animationDurationFactor())
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
                self.updateBackgroundImage(animated: animated)
            }
        }
        
        private func updateBackgroundImage(animated: Bool) {
            guard let layout = self.currentLayout else {
                return
            }
            
            var totalComponentWidth: CGFloat = 0.0
            if let counter = layout.counter {
                for component in counter.components {
                    totalComponentWidth += component.bounds.width
                }
            }
            
            let isExtracted = self.isExtracted
            let animationState = self.animationState
            
            DispatchQueue.global().async { [weak self] in
                var image: UIImage?
                
                if true {
                    image = generateImage(layout.size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        UIGraphicsPushContext(context)
                        
                        func drawContents(colors: Colors) {
                            let backgroundColor: UIColor
                            let foregroundColor: UIColor
                            if isExtracted {
                                backgroundColor = UIColor(argb: colors.extractedBackground)
                                foregroundColor = UIColor(argb: colors.extractedForeground)
                            } else {
                                backgroundColor = UIColor(argb: colors.background)
                                foregroundColor = UIColor(argb: colors.foreground)
                            }
                            
                            context.setBlendMode(.copy)
                            
                            context.setFillColor(backgroundColor.cgColor)
                            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
                            context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                            context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))
                            
                            if let counter = layout.counter {
                                let isForegroundTransparent = foregroundColor.alpha < 1.0
                                context.setBlendMode(isForegroundTransparent ? .copy : .normal)
                                
                                let textOrigin: CGFloat = 36.0
                                
                                var rightTextOrigin = textOrigin + totalComponentWidth
                                
                                let animationFraction: CGFloat
                                if let animationState = animationState, animationState.fromCounter != nil {
                                    animationFraction = max(0.0, min(1.0, (CACurrentMediaTime() - animationState.startTime) / animationState.duration))
                                } else {
                                    animationFraction = 1.0
                                }
                                
                                for i in (0 ..< counter.components.count).reversed() {
                                    let component = counter.components[i]
                                    var componentAlpha: CGFloat = 1.0
                                    var componentVerticalOffset: CGFloat = 0.0
                                    
                                    if let animationState = animationState, let fromCounter = animationState.fromCounter {
                                        let reverseIndex = counter.components.count - 1 - i
                                        if reverseIndex < fromCounter.components.count {
                                            let previousComponent = fromCounter.components[fromCounter.components.count - 1 - reverseIndex]
                                            
                                            if previousComponent != component {
                                                componentAlpha = animationFraction
                                                componentVerticalOffset = -(1.0 - animationFraction) * 8.0
                                                if previousComponent.string < component.string {
                                                    componentVerticalOffset = -componentVerticalOffset
                                                }
                                                
                                                let previousComponentAlpha = 1.0 - componentAlpha
                                                var previousComponentVerticalOffset = animationFraction * 8.0
                                                if previousComponent.string < component.string {
                                                    previousComponentVerticalOffset = -previousComponentVerticalOffset
                                                }
                                                
                                                var componentOrigin = rightTextOrigin - previousComponent.bounds.width
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
                                        }
                                    }
                                    
                                    let componentOrigin = rightTextOrigin - component.bounds.width
                                    let currentColor: UIColor
                                    if isForegroundTransparent {
                                        currentColor = foregroundColor.mixedWith(backgroundColor, alpha: 1.0 - componentAlpha)
                                    } else {
                                        currentColor = foregroundColor.withMultipliedAlpha(componentAlpha)
                                    }
                                    let string = NSAttributedString(string: component.string, font: Font.medium(11.0), textColor: currentColor)
                                    string.draw(at: component.bounds.origin.offsetBy(dx: componentOrigin, dy: floorToScreenPixels(size.height - component.bounds.height) / 2.0 + componentVerticalOffset))
                                    
                                    rightTextOrigin -= component.bounds.width
                                }
                            }
                        }
                        
                        if let animationState = animationState, animationState.fromColors.isSelected != layout.colors.isSelected {
                            var animationFraction: CGFloat = max(0.0, min(1.0, (CACurrentMediaTime() - animationState.startTime) / animationState.duration))
                            if !layout.colors.isSelected {
                                animationFraction = 1.0 - animationFraction
                            }
                            
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
                        
                        UIGraphicsPopContext()
                    })
                }
                
                DispatchQueue.main.async {
                    if let strongSelf = self, let image = image {
                        let previousContents = strongSelf.layer.contents
                        
                        ASDisplayNodeSetResizableContents(strongSelf.layer, image)
                        
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
        
        let backgroundLayout: ContainerButtonNode.Layout
        
        let size: CGSize
        
        init(
            spec: Spec,
            backgroundColor: UInt32,
            sideInsets: CGFloat,
            imageFrame: CGRect,
            imageSize: CGSize,
            counterLayout: CounterLayout?,
            backgroundLayout: ContainerButtonNode.Layout,
            size: CGSize
        ) {
            self.spec = spec
            self.backgroundColor = backgroundColor
            self.sideInsets = sideInsets
            self.imageFrame = imageFrame
            self.imageSize = imageSize
            self.counterLayout = counterLayout
            self.backgroundLayout = backgroundLayout
            self.size = size
        }
        
        static func calculate(spec: Spec, currentLayout: Layout?) -> Layout {
            let sideInsets: CGFloat = 11.0
            let height: CGFloat = 30.0
            let spacing: CGFloat = 2.0
            
            let boundingImageSize = CGSize(width: 20.0, height: 20.0)
            let imageSize: CGSize
            if let file = spec.component.reaction.centerAnimation {
                let defaultImageSize = CGSize(width: boundingImageSize.width + floor(boundingImageSize.width * 0.5 * 2.0), height: boundingImageSize.height + floor(boundingImageSize.height * 0.5 * 2.0))
                imageSize = file.dimensions?.cgSize.aspectFitted(defaultImageSize) ?? defaultImageSize
            } else if let file = spec.component.reaction.legacyIcon {
                imageSize = file.dimensions?.cgSize.aspectFitted(boundingImageSize) ?? boundingImageSize
            } else {
                imageSize = boundingImageSize
            }
            
            var counterComponents: [String] = []
            for character in countString(Int64(spec.component.count)) {
                counterComponents.append(String(character))
            }
            
            /*#if DEBUG
            if spec.component.count % 2 == 0 {
                counterComponents.removeAll()
                for character in "123.5K" {
                    counterComponents.append(String(character))
                }
            }
            #endif*/
            
            let backgroundColor = spec.component.isSelected ? spec.component.colors.selectedBackground : spec.component.colors.deselectedBackground
            
            let imageFrame = CGRect(origin: CGPoint(x: sideInsets + floorToScreenPixels((boundingImageSize.width - imageSize.width) / 2.0), y: floorToScreenPixels((height - imageSize.height) / 2.0)), size: imageSize)
            
            var counterLayout: CounterLayout?
            
            var size = CGSize(width: boundingImageSize.width + sideInsets * 2.0, height: height)
            if !spec.component.avatarPeers.isEmpty {
                size.width += 4.0 + 24.0
                if spec.component.avatarPeers.count > 1 {
                    size.width += CGFloat(spec.component.avatarPeers.count - 1) * 12.0
                } else {
                    size.width -= 2.0
                }
            } else {
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
            }
            
            let backgroundColors = ReactionButtonAsyncNode.ContainerButtonNode.Colors(
                background: spec.component.isSelected ? spec.component.colors.selectedBackground : spec.component.colors.deselectedBackground,
                foreground: spec.component.isSelected ? spec.component.colors.selectedForeground : spec.component.colors.deselectedForeground,
                extractedBackground: spec.component.colors.extractedBackground,
                extractedForeground: spec.component.colors.extractedForeground,
                isSelected: spec.component.isSelected
            )
            var backgroundCounter: ReactionButtonAsyncNode.ContainerButtonNode.Counter?
            if let counterLayout = counterLayout {
                backgroundCounter = ReactionButtonAsyncNode.ContainerButtonNode.Counter(
                    components: counterLayout.components
                )
            }
            let backgroundLayout = ContainerButtonNode.Layout(
                colors: backgroundColors,
                size: size,
                counter: backgroundCounter
            )
            
            return Layout(
                spec: spec,
                backgroundColor: backgroundColor,
                sideInsets: sideInsets,
                imageFrame: imageFrame,
                imageSize: boundingImageSize,
                counterLayout: counterLayout,
                backgroundLayout: backgroundLayout,
                size: size
            )
        }
    }
    
    private var layout: Layout?
    
    public let containerView: ContextExtractedContentContainingView
    private let buttonNode: ContainerButtonNode
    public var iconView: ReactionIconView?
    private var avatarsView: AnimatedAvatarSetView?
    
    private let iconImageDisposable = MetaDisposable()
    
    public var activateAfterCompletion: Bool = false {
        didSet {
            if self.activateAfterCompletion {
                self.contextGesture?.activatedAfterCompletion = { [weak self] in
                    self?.pressed()
                }
            } else {
                self.contextGesture?.activatedAfterCompletion = nil
            }
        }
    }
    
    override init(frame: CGRect) {
        self.containerView = ContextExtractedContentContainingView()
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
            guard let strongSelf = self else {
                return
            }
            strongSelf.buttonNode.updateIsExtracted(isExtracted: isExtracted, animated: true)
        }
        
        if self.activateAfterCompletion {
            self.contextGesture?.activatedAfterCompletion = { [weak self] in
                self?.pressed()
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
        self.iconView?.imageView.image = nil
        self.layout = nil
        
        self.buttonNode.reset()
    }
    
    @objc private func pressed() {
        guard let layout = self.layout else {
            return
        }
        layout.spec.component.action(layout.spec.component.reaction.value)
    }
    
    fileprivate func apply(layout: Layout, animation: ListViewItemUpdateAnimation) {
        self.containerView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.containerView.contentView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.containerView.contentRect = CGRect(origin: CGPoint(), size: layout.size)
        animation.animator.updateFrame(layer: self.buttonNode.layer, frame: CGRect(origin: CGPoint(), size: layout.size), completion: nil)
        
        self.buttonNode.update(layout: layout.backgroundLayout)
        
        if let iconView = self.iconView {
            animation.animator.updateFrame(layer: iconView.layer, frame: layout.imageFrame, completion: nil)
            iconView.update(size: layout.imageFrame.size, transition: animation.transition)
            
            if self.layout?.spec.component.reaction != layout.spec.component.reaction {
                if let file = layout.spec.component.reaction.centerAnimation {
                    if let image = ReactionImageCache.shared.get(reaction: layout.spec.component.reaction.value) {
                        iconView.imageView.image = image
                    } else {
                        self.iconImageDisposable.set((reactionStaticImage(context: layout.spec.component.context, animation: file, pixelSize: CGSize(width: 32.0 * UIScreenScale, height: 32.0 * UIScreenScale))
                        |> filter { data in
                            return data.isComplete
                        }
                        |> take(1)
                        |> map { data -> UIImage? in
                            if data.isComplete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                if let image = UIImage(data: dataValue) {
                                    return image.precomposed()
                                } else {
                                    print("Could not decode image")
                                }
                            } else {
                                print("Incomplete data")
                            }
                            return nil
                        }
                        |> deliverOnMainQueue).start(next: { [weak self] image in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let image = image {
                                strongSelf.iconView?.imageView.image = image
                                ReactionImageCache.shared.put(reaction: layout.spec.component.reaction.value, image: image)
                            }
                        }))
                    }
                } else if let legacyIcon = layout.spec.component.reaction.legacyIcon {
                    self.iconImageDisposable.set((layout.spec.component.context.account.postbox.mediaBox.resourceData(legacyIcon.resource)
                    |> deliverOn(Queue.concurrentDefaultQueue())
                    |> map { data -> UIImage? in
                        if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            if let image = WebP.convert(fromWebP: dataValue) {
                                if #available(iOS 15.0, iOSApplicationExtension 15.0, *) {
                                    return image.preparingForDisplay()
                                } else {
                                    return image.precomposed()
                                }
                            }
                        }
                        return nil
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] image in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.iconView?.imageView.image = image
                    }))
                }
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
    
    public static func asyncLayout(_ item: ReactionNodePool.Item?) -> (ReactionButtonComponent) -> (size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation) -> ReactionNodePool.Item) {
        let currentLayout = item?.view.layout
        
        return { component in
            let spec = Layout.Spec(component: component)
            
            let layout: Layout
            if let currentLayout = currentLayout, currentLayout.spec == spec {
                layout = currentLayout
            } else {
                layout = Layout.calculate(spec: spec, currentLayout: currentLayout)
            }
            
            return (size: layout.size, apply: { animation in
                var animation = animation
                let updatedItem: ReactionNodePool.Item
                if let item = item {
                    updatedItem = item
                } else {
                    updatedItem = ReactionNodePool.shared.take()
                    animation = .None
                }
                
                updatedItem.view.apply(layout: layout, animation: animation)
                
                return updatedItem
            })
        }
    }
}

public final class ReactionButtonComponent: Equatable {
    public struct Reaction: Equatable {
        public var value: String
        public var centerAnimation: TelegramMediaFile?
        public var legacyIcon: TelegramMediaFile?
        
        public init(value: String, centerAnimation: TelegramMediaFile?, legacyIcon: TelegramMediaFile?) {
            self.value = value
            self.centerAnimation = centerAnimation
            self.legacyIcon = legacyIcon
        }
        
        public static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.centerAnimation?.fileId != rhs.centerAnimation?.fileId {
                return false
            }
            if lhs.legacyIcon?.fileId != rhs.legacyIcon?.fileId {
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
        public var extractedBackground: UInt32
        public var extractedForeground: UInt32
        
        public init(
            deselectedBackground: UInt32,
            selectedBackground: UInt32,
            deselectedForeground: UInt32,
            selectedForeground: UInt32,
            extractedBackground: UInt32,
            extractedForeground: UInt32
        ) {
            self.deselectedBackground = deselectedBackground
            self.selectedBackground = selectedBackground
            self.deselectedForeground = deselectedForeground
            self.selectedForeground = selectedForeground
            self.extractedBackground = extractedBackground
            self.extractedForeground = extractedForeground
        }
    }
    
    public let context: AccountContext
    public let colors: Colors
    public let reaction: Reaction
    public let avatarPeers: [EnginePeer]
    public let count: Int
    public let isSelected: Bool
    public let action: (String) -> Void

    public init(
        context: AccountContext,
        colors: Colors,
        reaction: Reaction,
        avatarPeers: [EnginePeer],
        count: Int,
        isSelected: Bool,
        action: @escaping (String) -> Void
    ) {
        self.context = context
        self.colors = colors
        self.reaction = reaction
        self.avatarPeers = avatarPeers
        self.count = count
        self.isSelected = isSelected
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
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
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
    public struct Reaction {
        public var reaction: ReactionButtonComponent.Reaction
        public var count: Int
        public var peers: [EnginePeer]
        public var isSelected: Bool
        
        public init(
            reaction: ReactionButtonComponent.Reaction,
            count: Int,
            peers: [EnginePeer],
            isSelected: Bool
        ) {
            self.reaction = reaction
            self.count = count
            self.peers = peers
            self.isSelected = isSelected
        }
    }
    
    public struct Result {
        public struct Item {
            public var size: CGSize
        }
        
        public var items: [Item]
        public var apply: (ListViewItemUpdateAnimation) -> ApplyResult
    }
    
    public struct ApplyResult {
        public struct Item {
            public var value: String
            public var node: ReactionNodePool.Item
            public var size: CGSize
        }
        
        public var items: [Item]
        public var removedNodes: [ReactionNodePool.Item]
    }
    
    public private(set) var buttons: [String: ReactionNodePool.Item] = [:]
    
    public init() {
    }
    
    deinit {
        for (_, button) in self.buttons {
            button.view.removeFromSuperview()
        }
    }
    
    public func update(
        context: AccountContext,
        action: @escaping (String) -> Void,
        reactions: [ReactionButtonsAsyncLayoutContainer.Reaction],
        colors: ReactionButtonComponent.Colors,
        constrainedWidth: CGFloat
    ) -> Result {
        var items: [Result.Item] = []
        var applyItems: [(key: String, size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation) -> ReactionNodePool.Item)] = []
        
        var validIds = Set<String>()
        for reaction in reactions.sorted(by: { lhs, rhs in
            var lhsCount = lhs.count
            if lhs.isSelected {
                lhsCount -= 1
            }
            var rhsCount = rhs.count
            if rhs.isSelected {
                rhsCount -= 1
            }
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return lhs.reaction.value < rhs.reaction.value
        }) {
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
                avatarPeers: avatarPeers,
                count: reaction.count,
                isSelected: reaction.isSelected,
                action: action
            ))
            
            items.append(Result.Item(
                size: size
            ))
            applyItems.append((reaction.reaction.value, size, apply))
        }
        
        var removeIds: [String] = []
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
            apply: { animation in
                var items: [ApplyResult.Item] = []
                for (key, size, apply) in applyItems {
                    let nodeItem = apply(animation)
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
