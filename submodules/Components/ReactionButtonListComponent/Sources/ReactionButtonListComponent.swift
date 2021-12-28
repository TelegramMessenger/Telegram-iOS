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
import WebPBinding
import AnimatedAvatarSetNode

public final class ReactionButtonAsyncNode: ContextControllerSourceNode {
    fileprivate final class ContainerButtonNode: HighlightTrackingButtonNode {
        struct Colors: Equatable {
            var background: UInt32
            var foreground: UInt32
            var extractedBackground: UInt32
            var extractedForeground: UInt32
        }
        
        struct Counter: Equatable {
            var frame: CGRect
            var components: [CounterLayout.Component]
        }
        
        struct Layout: Equatable {
            var colors: Colors
            var baseSize: CGSize
            var counter: Counter?
        }
        
        private var isExtracted: Bool = false
        private var currentLayout: Layout?
        
        init() {
            super.init(pointerStyle: nil)
        }
        
        func update(layout: Layout) {
            if self.currentLayout != layout {
                self.currentLayout = layout
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
            
            let image = generateImage(layout.baseSize, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                let backgroundColor: UIColor
                let foregroundColor: UIColor
                if self.isExtracted {
                    backgroundColor = UIColor(argb: layout.colors.extractedBackground)
                    foregroundColor = UIColor(argb: layout.colors.extractedForeground)
                } else {
                    backgroundColor = UIColor(argb: layout.colors.background)
                    foregroundColor = UIColor(argb: layout.colors.foreground)
                }
                
                context.setBlendMode(.copy)
                
                context.setFillColor(backgroundColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - size.height, y: 0.0), size: CGSize(width: size.height, height: size.height)))
                context.fill(CGRect(origin: CGPoint(x: size.height / 2.0, y: 0.0), size: CGSize(width: size.width - size.height, height: size.height)))
                
                if let counter = layout.counter {
                    context.setBlendMode(foregroundColor.alpha < 1.0 ? .copy : .normal)
                    
                    var totalComponentWidth: CGFloat = 0.0
                    for component in counter.components {
                        totalComponentWidth += component.bounds.width
                    }
                    
                    var textOrigin: CGFloat = size.width - counter.frame.width - 8.0 + floorToScreenPixels((counter.frame.width - totalComponentWidth) / 2.0)
                    for component in counter.components {
                        let string = NSAttributedString(string: component.string, font: Font.medium(11.0), textColor: foregroundColor)
                        string.draw(at: component.bounds.origin.offsetBy(dx: textOrigin, dy: floorToScreenPixels(size.height - component.bounds.height) / 2.0))
                        textOrigin += component.bounds.width
                    }
                }
                
                UIGraphicsPopContext()
            })?.stretchableImage(withLeftCapWidth: Int(layout.baseSize.height / 2.0), topCapHeight: Int(layout.baseSize.height / 2.0))
            if let image = image {
                let previousContents = self.layer.contents
                
                ASDisplayNodeSetResizableContents(self.layer, image)
                
                if animated, let previousContents = previousContents {
                    self.layer.animate(from: previousContents as! CGImage, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
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
            for i in 0 ..< 9 {
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
                for component in spec.stringComponents {
                    let string = NSAttributedString(string: component, font: Font.medium(11.0), textColor: .black)
                    let boundingRect = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                    
                    resultComponents.append(Component(string: component, bounds: boundingRect))
                    
                    resultSize.width += CounterLayout.maxDigitWidth
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
        let clippingHeight: CGFloat
        let sideInsets: CGFloat
        
        let imageFrame: CGRect
        
        let counterLayout: CounterLayout?
        let counterFrame: CGRect?
        
        let backgroundLayout: ContainerButtonNode.Layout
        //let backgroundImage: UIImage
        //let extractedBackgroundImage: UIImage
        
        let size: CGSize
        
        init(
            spec: Spec,
            backgroundColor: UInt32,
            clippingHeight: CGFloat,
            sideInsets: CGFloat,
            imageFrame: CGRect,
            counterLayout: CounterLayout?,
            counterFrame: CGRect?,
            backgroundLayout: ContainerButtonNode.Layout,
            //backgroundImage: UIImage,
            //extractedBackgroundImage: UIImage,
            size: CGSize
        ) {
            self.spec = spec
            self.backgroundColor = backgroundColor
            self.clippingHeight = clippingHeight
            self.sideInsets = sideInsets
            self.imageFrame = imageFrame
            self.counterLayout = counterLayout
            self.counterFrame = counterFrame
            self.backgroundLayout = backgroundLayout
            //self.backgroundImage = backgroundImage
            //self.extractedBackgroundImage = extractedBackgroundImage
            self.size = size
        }
        
        static func calculate(spec: Spec, currentLayout: Layout?) -> Layout {
            let clippingHeight: CGFloat = 22.0
            let sideInsets: CGFloat = 8.0
            let height: CGFloat = 30.0
            let spacing: CGFloat = 4.0
            
            let defaultImageSize = CGSize(width: 22.0, height: 22.0)
            let imageSize: CGSize
            if let file = spec.component.reaction.iconFile {
                imageSize = file.dimensions?.cgSize.aspectFitted(defaultImageSize) ?? defaultImageSize
            } else {
                imageSize = defaultImageSize
            }
            
            var counterComponents: [String] = []
            for character in countString(Int64(spec.component.count)) {
                counterComponents.append(String(character))
            }
            
            let backgroundColor = spec.component.isSelected ? spec.component.colors.selectedBackground : spec.component.colors.deselectedBackground
            
            let imageFrame = CGRect(origin: CGPoint(x: sideInsets, y: floorToScreenPixels((height - imageSize.height) / 2.0)), size: imageSize)
            
            /*var previousDisplayCounter: String?
            if let currentLayout = currentLayout {
                if currentLayout.spec.component.avatarPeers.isEmpty {
                    previousDisplayCounter = countString(Int64(spec.component.count))
                }
            }
            var currentDisplayCounter: String?
            if spec.component.avatarPeers.isEmpty {
                currentDisplayCounter = countString(Int64(spec.component.count))
            }*/
            
            /*let backgroundImage: UIImage
            let extractedBackgroundImage: UIImage
            if let currentLayout = currentLayout, currentLayout.spec.component.isSelected == spec.component.isSelected, currentLayout.spec.component.colors == spec.component.colors, previousDisplayCounter == currentDisplayCounter {
                backgroundImage = currentLayout.backgroundImage
                extractedBackgroundImage = currentLayout.extractedBackgroundImage
            } else {
                backgroundImage = generateImage(CGSize(width: height + 18.0, height: height), rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    
                    context.setFillColor(UIColor(argb: backgroundColor).cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: height, height: height)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - height, y: 0.0), size: CGSize(width: height, height: size.height)))
                    context.fill(CGRect(origin: CGPoint(x: height / 2.0, y: 0.0), size: CGSize(width: size.width - height, height: size.height)))
                    
                    context.setBlendMode(.normal)
                    
                    if let currentDisplayCounter = currentDisplayCounter {
                        let textColor = UIColor(argb: spec.component.isSelected ? spec.component.colors.selectedForeground : spec.component.colors.deselectedForeground)
                        let string = NSAttributedString(string: currentDisplayCounter, font: Font.medium(11.0), textColor: textColor)
                        let boundingRect = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                        if textColor.alpha < 1.0 {
                            context.setBlendMode(.copy)
                        }
                        string.draw(at: CGPoint(x: size.width - sideInsets - boundingRect.width, y: (size.height - boundingRect.height) / 2.0))
                    }
                    
                    UIGraphicsPopContext()
                })!.stretchableImage(withLeftCapWidth: Int(height / 2.0), topCapHeight: Int(height / 2.0))
                extractedBackgroundImage = generateImage(CGSize(width: height + 18.0, height: height), rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    
                    context.setFillColor(UIColor(argb: spec.component.colors.extractedBackground).cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: height, height: height)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - height, y: 0.0), size: CGSize(width: height, height: size.height)))
                    context.fill(CGRect(origin: CGPoint(x: height / 2.0, y: 0.0), size: CGSize(width: size.width - height, height: size.height)))
                    
                    context.setBlendMode(.normal)
                    
                    if let currentDisplayCounter = currentDisplayCounter {
                        let textColor = UIColor(argb: spec.component.colors.extractedForeground)
                        let string = NSAttributedString(string: currentDisplayCounter, font: Font.medium(11.0), textColor: textColor)
                        let boundingRect = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                        if textColor.alpha < 1.0 {
                            context.setBlendMode(.copy)
                        }
                        string.draw(at: CGPoint(x: size.width - sideInsets - boundingRect.width, y: (size.height - boundingRect.height) / 2.0))
                    }
                    
                    UIGraphicsPopContext()
                })!.stretchableImage(withLeftCapWidth: Int(height / 2.0), topCapHeight: Int(height / 2.0))
            }*/
            
            var counterLayout: CounterLayout?
            var counterFrame: CGRect?
            
            var size = CGSize(width: imageSize.width + sideInsets * 2.0, height: height)
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
                counterFrame = CGRect(origin: CGPoint(x: size.width - sideInsets - counterValue.size.width, y: floorToScreenPixels((height - counterValue.size.height) / 2.0)), size: counterValue.size)
            }
            
            let backgroundColors = ReactionButtonAsyncNode.ContainerButtonNode.Colors(
                background: spec.component.isSelected ? spec.component.colors.selectedBackground : spec.component.colors.deselectedBackground,
                foreground: spec.component.isSelected ? spec.component.colors.selectedForeground : spec.component.colors.deselectedForeground,
                extractedBackground: spec.component.colors.extractedBackground,
                extractedForeground: spec.component.colors.extractedForeground
            )
            var backgroundCounter: ReactionButtonAsyncNode.ContainerButtonNode.Counter?
            if let counterLayout = counterLayout, let counterFrame = counterFrame {
                backgroundCounter = ReactionButtonAsyncNode.ContainerButtonNode.Counter(
                    frame: counterFrame,
                    components: counterLayout.components
                )
            }
            let backgroundLayout = ContainerButtonNode.Layout(
                colors: backgroundColors,
                baseSize: CGSize(width: height + 18.0, height: height),
                counter: backgroundCounter
            )
            
            return Layout(
                spec: spec,
                backgroundColor: backgroundColor,
                clippingHeight: clippingHeight,
                sideInsets: sideInsets,
                imageFrame: imageFrame,
                counterLayout: counterLayout,
                counterFrame: counterFrame,
                backgroundLayout: backgroundLayout,
                //backgroundImage: backgroundImage,
                //extractedBackgroundImage: extractedBackgroundImage,
                size: size
            )
        }
    }
    
    private var layout: Layout?
    
    public let containerNode: ContextExtractedContentContainingNode
    private let buttonNode: ContainerButtonNode
    public let iconView: UIImageView
    private var avatarsView: AnimatedAvatarSetView?
    
    private let iconImageDisposable = MetaDisposable()
    
    override init() {
        self.containerNode = ContextExtractedContentContainingNode()
        self.buttonNode = ContainerButtonNode()
        
        self.iconView = UIImageView()
        self.iconView.isUserInteractionEnabled = false
        
        super.init()
        
        self.targetNodeForActivationProgress = self.containerNode.contentNode
        
        self.addSubnode(self.containerNode)
        self.containerNode.contentNode.addSubnode(self.buttonNode)
        self.buttonNode.view.addSubview(self.iconView)
        
        self.buttonNode.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf
            if highlighted {
            } else {
            }
        }
        
        self.isGestureEnabled = true
        
        self.containerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.buttonNode.updateIsExtracted(isExtracted: isExtracted, animated: true)
            
            /*let backgroundImage = isExtracted ? layout.extractedBackgroundImage : layout.backgroundImage
            
            let previousContents = strongSelf.buttonNode.layer.contents
            
            ASDisplayNodeSetResizableContents(strongSelf.buttonNode.layer, backgroundImage)
            
            if let previousContents = previousContents {
                strongSelf.buttonNode.layer.animate(from: previousContents as! CGImage, to: backgroundImage.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
            }*/
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.iconImageDisposable.dispose()
    }
    
    @objc private func pressed() {
        guard let layout = self.layout else {
            return
        }
        layout.spec.component.action(layout.spec.component.reaction.value)
    }
    
    fileprivate func apply(layout: Layout, animation: ListViewItemUpdateAnimation) {
        self.containerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.containerNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.containerNode.contentRect = CGRect(origin: CGPoint(), size: layout.size)
        animation.animator.updateFrame(layer: self.buttonNode.layer, frame: CGRect(origin: CGPoint(), size: layout.size), completion: nil)
        
        //ASDisplayNodeSetResizableContents(self.buttonNode.layer, layout.backgroundImage)
        self.buttonNode.update(layout: layout.backgroundLayout)
        
        animation.animator.updateFrame(layer: self.iconView.layer, frame: layout.imageFrame, completion: nil)
        
        if self.layout?.spec.component.reaction != layout.spec.component.reaction {
            if let file = layout.spec.component.reaction.iconFile {
                self.iconImageDisposable.set((layout.spec.component.context.account.postbox.mediaBox.resourceData(file.resource)
                |> deliverOnMainQueue).start(next: { [weak self] data in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                        if let image = WebP.convert(fromWebP: dataValue) {
                            strongSelf.iconView.image = image
                        }
                    }
                }))
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
                self.buttonNode.view.addSubview(avatarsView)
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
            animation.animator.updateFrame(layer: avatarsView.layer, frame: CGRect(origin: CGPoint(x: layout.imageFrame.maxX + 4.0, y: floorToScreenPixels((layout.size.height - avatarsSize.height) / 2.0)), size: CGSize(width: avatarsSize.width, height: avatarsSize.height)), completion: nil)
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
    
    public static func asyncLayout(_ view: ReactionButtonAsyncNode?) -> (ReactionButtonComponent) -> (size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation) -> ReactionButtonAsyncNode) {
        let currentLayout = view?.layout
        
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
                let updatedView: ReactionButtonAsyncNode
                if let view = view {
                    updatedView = view
                } else {
                    updatedView = ReactionButtonAsyncNode()
                    animation = .None
                }
                
                updatedView.apply(layout: layout, animation: animation)
                
                return updatedView
            })
        }
    }
}

public final class ReactionButtonComponent: Component {
    public struct ViewTag: Equatable {
        public var value: String
        
        public init(value: String) {
            self.value = value
        }
    }
    
    public struct Reaction: Equatable {
        public var value: String
        public var iconFile: TelegramMediaFile?
        
        public init(value: String, iconFile: TelegramMediaFile?) {
            self.value = value
            self.iconFile = iconFile
        }
        
        public static func ==(lhs: Reaction, rhs: Reaction) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.iconFile?.fileId != rhs.iconFile?.fileId {
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

    public final class View: UIButton, ComponentTaggedView {
        public let iconView: UIImageView
        private let textView: ComponentHostView<Empty>
        private let measureTextView: ComponentHostView<Empty>
        
        private var currentComponent: ReactionButtonComponent?
        
        private let iconImageDisposable = MetaDisposable()
        
        init() {
            self.iconView = UIImageView()
            self.iconView.isUserInteractionEnabled = false
            
            self.textView = ComponentHostView<Empty>()
            self.textView.isUserInteractionEnabled = false
            
            self.measureTextView = ComponentHostView<Empty>()
            self.measureTextView.isUserInteractionEnabled = false
            
            super.init(frame: CGRect())
            
            self.addSubview(self.iconView)
            self.addSubview(self.textView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.iconImageDisposable.dispose()
        }
        
        @objc private func pressed() {
            guard let currentComponent = self.currentComponent else {
                return
            }
            currentComponent.action(currentComponent.reaction.value)
        }
        
        public func matches(tag: Any) -> Bool {
            guard let tag = tag as? ViewTag else {
                return false
            }
            guard let currentComponent = self.currentComponent else {
                return false
            }
            if currentComponent.reaction.value == tag.value {
                return true
            }
            return false
        }

        func update(component: ReactionButtonComponent, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let sideInsets: CGFloat = 8.0
            let height: CGFloat = 30.0
            let spacing: CGFloat = 4.0
            
            let defaultImageSize = CGSize(width: 22.0, height: 22.0)
            
            let imageSize: CGSize
            if self.currentComponent?.reaction != component.reaction {
                if let file = component.reaction.iconFile {
                    self.iconImageDisposable.set((component.context.account.postbox.mediaBox.resourceData(file.resource)
                    |> deliverOnMainQueue).start(next: { [weak self] data in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            if let image = WebP.convert(fromWebP: dataValue) {
                                strongSelf.iconView.image = image
                            }
                        }
                    }))
                    imageSize = file.dimensions?.cgSize.aspectFitted(defaultImageSize) ?? defaultImageSize
                } else {
                    imageSize = defaultImageSize
                }
            } else {
                imageSize = self.iconView.bounds.size
            }
            
            self.iconView.frame = CGRect(origin: CGPoint(x: sideInsets, y: floorToScreenPixels((height - imageSize.height) / 2.0)), size: imageSize)
            
            let text = countString(Int64(component.count))
            var measureText = ""
            for _ in 0 ..< text.count {
                measureText.append("0")
            }
            
            let minTextWidth = self.measureTextView.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: measureText,
                    font: Font.regular(11.0),
                    color: .black
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            ).width + 2.0
            
            let actualTextSize: CGSize
            if self.currentComponent?.count != component.count || self.currentComponent?.colors != component.colors || self.currentComponent?.isSelected != component.isSelected {
                actualTextSize = self.textView.update(
                    transition: .immediate,
                    component: AnyComponent(Text(
                        text: text,
                        font: Font.medium(11.0),
                        color: UIColor(argb: component.isSelected ? component.colors.selectedForeground : component.colors.deselectedForeground)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else {
                actualTextSize = self.textView.bounds.size
            }
            let layoutTextSize = CGSize(width: max(actualTextSize.width, minTextWidth), height: actualTextSize.height)
            
            if self.currentComponent?.colors != component.colors || self.currentComponent?.isSelected != component.isSelected {
                if component.isSelected {
                    self.backgroundColor = UIColor(argb: component.colors.selectedBackground)
                } else {
                    self.backgroundColor = UIColor(argb: component.colors.deselectedBackground)
                }
            }
            
            self.layer.cornerRadius = height / 2.0
            
            self.textView.frame = CGRect(origin: CGPoint(x: sideInsets + imageSize.width + spacing, y: floorToScreenPixels((height - actualTextSize.height) / 2.0)), size: actualTextSize)
            
            self.currentComponent = component
            
            return CGSize(width: imageSize.width + spacing + layoutTextSize.width + sideInsets * 2.0, height: height)
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
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
            public var node: ReactionButtonAsyncNode
            public var size: CGSize
        }
        
        public var items: [Item]
        public var removedNodes: [ReactionButtonAsyncNode]
    }
    
    public private(set) var buttons: [String: ReactionButtonAsyncNode] = [:]
    
    public init() {
    }
    
    public func update(
        context: AccountContext,
        action: @escaping (String) -> Void,
        reactions: [ReactionButtonsAsyncLayoutContainer.Reaction],
        colors: ReactionButtonComponent.Colors,
        constrainedWidth: CGFloat
    ) -> Result {
        var items: [Result.Item] = []
        var applyItems: [(key: String, size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation) -> ReactionButtonAsyncNode)] = []
        
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
        var removedNodes: [ReactionButtonAsyncNode] = []
        for id in removeIds {
            if let node = self.buttons.removeValue(forKey: id) {
                removedNodes.append(node)
            }
        }
        
        return Result(
            items: items,
            apply: { animation in
                var items: [ApplyResult.Item] = []
                for (key, size, apply) in applyItems {
                    let node = apply(animation)
                    items.append(ApplyResult.Item(value: key, node: node, size: size))
                    
                    if let current = self.buttons[key] {
                        assert(current === node)
                    } else {
                        self.buttons[key] = node
                    }
                }
                
                return ApplyResult(items: items, removedNodes: removedNodes)
            }
        )
    }
}
