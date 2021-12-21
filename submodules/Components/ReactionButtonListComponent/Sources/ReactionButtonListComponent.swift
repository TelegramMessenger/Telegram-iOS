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

fileprivate final class CounterLayer: SimpleLayer {
    fileprivate final class Layout {
        struct Spec: Equatable {
            let clippingHeight: CGFloat
            var stringComponents: [String]
            var backgroundColor: UInt32
            var foregroundColor: UInt32
        }
        
        let spec: Spec
        let size: CGSize
        
        let image: UIImage
        
        init(
            spec: Spec,
            size: CGSize,
            image: UIImage
        ) {
            self.spec = spec
            self.size = size
            self.image = image
        }
        
        static func calculate(spec: Spec, previousLayout: Layout?) -> Layout {
            let image: UIImage
            if let previousLayout = previousLayout, previousLayout.spec == spec {
                image = previousLayout.image
            } else {
                let textColor = UIColor(argb: spec.foregroundColor)
                let string = NSAttributedString(string: spec.stringComponents.joined(separator: ""), font: Font.medium(11.0), textColor: textColor)
                let boundingRect = string.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                image = generateImage(CGSize(width: boundingRect.size.width, height: spec.clippingHeight), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    /*context.setFillColor(UIColor(argb: spec.backgroundColor).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    if textColor.alpha < 1.0 {
                        context.setBlendMode(.copy)
                    }*/
                    context.translateBy(x: 0.0, y: (size.height - boundingRect.size.height) / 2.0)
                    UIGraphicsPushContext(context)
                    string.draw(at: CGPoint())
                    UIGraphicsPopContext()
                })!
            }
            
            return Layout(
                spec: spec,
                size: image.size,
                image: image
            )
        }
    }
    
    var layout: Layout?
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override init() {
        super.init()
        
        self.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func apply(layout: Layout, animation: ListViewItemUpdateAnimation) {
        /*if animation.isAnimated, let previousContents = self.contents {
            self.animate(from: previousContents as! CGImage, to: layout.image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
        } else {*/
            self.contents = layout.image.cgImage
        //}
        
        self.layout = layout
    }
}

public final class ReactionButtonAsyncNode: ContextControllerSourceNode {
    fileprivate final class Layout {
        struct Spec: Equatable {
            var component: ReactionButtonComponent
        }
        
        let spec: Spec
        
        let backgroundColor: UInt32
        let clippingHeight: CGFloat
        let sideInsets: CGFloat
        
        let imageFrame: CGRect
        
        let counter: CounterLayer.Layout?
        let counterFrame: CGRect?
        
        let backgroundImage: UIImage
        let extractedBackgroundImage: UIImage
        
        let size: CGSize
        
        init(
            spec: Spec,
            backgroundColor: UInt32,
            clippingHeight: CGFloat,
            sideInsets: CGFloat,
            imageFrame: CGRect,
            counter: CounterLayer.Layout?,
            counterFrame: CGRect?,
            backgroundImage: UIImage,
            extractedBackgroundImage: UIImage,
            size: CGSize
        ) {
            self.spec = spec
            self.backgroundColor = backgroundColor
            self.clippingHeight = clippingHeight
            self.sideInsets = sideInsets
            self.imageFrame = imageFrame
            self.counter = counter
            self.counterFrame = counterFrame
            self.backgroundImage = backgroundImage
            self.extractedBackgroundImage = extractedBackgroundImage
            self.size = size
        }
        
        static func calculate(spec: Spec, currentLayout: Layout?, currentCounter: CounterLayer.Layout?) -> Layout {
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
            
            var previousDisplayCounter: String?
            if let currentLayout = currentLayout {
                if currentLayout.spec.component.avatarPeers.isEmpty {
                    previousDisplayCounter = countString(Int64(spec.component.count))
                }
            }
            var currentDisplayCounter: String?
            if spec.component.avatarPeers.isEmpty {
                currentDisplayCounter = countString(Int64(spec.component.count))
            }
            
            let backgroundImage: UIImage
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
            }
            
            var counter: CounterLayer.Layout?
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
                let counterSpec = CounterLayer.Layout.Spec(
                    clippingHeight: clippingHeight,
                    stringComponents: counterComponents,
                    backgroundColor: backgroundColor,
                    foregroundColor: spec.component.isSelected ? spec.component.colors.selectedForeground : spec.component.colors.deselectedForeground
                )
                let counterValue: CounterLayer.Layout
                if let currentCounter = currentCounter, currentCounter.spec == counterSpec {
                    counterValue = currentCounter
                } else {
                    counterValue = CounterLayer.Layout.calculate(
                        spec: counterSpec,
                        previousLayout: currentCounter
                    )
                }
                counter = counterValue
                size.width += spacing + counterValue.size.width
                counterFrame = CGRect(origin: CGPoint(x: sideInsets + imageSize.width + spacing, y: floorToScreenPixels((height - counterValue.size.height) / 2.0)), size: counterValue.size)
            }
            
            return Layout(
                spec: spec,
                backgroundColor: backgroundColor,
                clippingHeight: clippingHeight,
                sideInsets: sideInsets,
                imageFrame: imageFrame,
                counter: counter,
                counterFrame: counterFrame,
                backgroundImage: backgroundImage,
                extractedBackgroundImage: extractedBackgroundImage,
                size: size
            )
        }
    }
    
    private var layout: Layout?
    
    public let containerNode: ContextExtractedContentContainingNode
    private let buttonNode: HighlightTrackingButtonNode
    public let iconView: UIImageView
    private var counterLayer: CounterLayer?
    private var avatarsView: AnimatedAvatarSetView?
    
    private let iconImageDisposable = MetaDisposable()
    
    override init() {
        self.containerNode = ContextExtractedContentContainingNode()
        self.buttonNode = HighlightTrackingButtonNode()
        
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
            guard let strongSelf = self, let layout = strongSelf.layout else {
                return
            }
            
            let backgroundImage = isExtracted ? layout.extractedBackgroundImage : layout.backgroundImage
            
            let previousContents = strongSelf.buttonNode.layer.contents
            
            let backgroundCapInsets = backgroundImage.capInsets
            if backgroundCapInsets.left.isZero && backgroundCapInsets.top.isZero {
                strongSelf.buttonNode.layer.contentsScale = backgroundImage.scale
                strongSelf.buttonNode.layer.contents = backgroundImage.cgImage
            } else {
                ASDisplayNodeSetResizableContents(strongSelf.buttonNode.layer, backgroundImage)
            }
            
            if let previousContents = previousContents {
                strongSelf.buttonNode.layer.animate(from: previousContents as! CGImage, to: backgroundImage.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
            }
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
        
        let backgroundCapInsets = layout.backgroundImage.capInsets
        if backgroundCapInsets.left.isZero && backgroundCapInsets.top.isZero {
            self.buttonNode.layer.contentsScale = layout.backgroundImage.scale
            self.buttonNode.layer.contents = layout.backgroundImage.cgImage
        } else {
            ASDisplayNodeSetResizableContents(self.buttonNode.layer, layout.backgroundImage)
        }
        
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
        
        if let counter = layout.counter, let counterFrame = layout.counterFrame {
            let counterLayer: CounterLayer
            var counterAnimation = animation
            if let current = self.counterLayer {
                counterLayer = current
            } else {
                counterAnimation = .None
                counterLayer = CounterLayer()
                self.counterLayer = counterLayer
                //self.layer.addSublayer(counterLayer)
                if animation.isAnimated {
                    counterLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            counterAnimation.animator.updateFrame(layer: counterLayer, frame: counterFrame, completion: nil)
            counterLayer.apply(layout: counter, animation: counterAnimation)
        } else if let counterLayer = self.counterLayer {
            self.counterLayer = nil
            if animation.isAnimated {
                animation.animator.updateAlpha(layer: counterLayer, alpha: 0.0, completion: { [weak counterLayer] _ in
                    counterLayer?.removeFromSuperlayer()
                })
            } else {
                counterLayer.removeFromSuperlayer()
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
                layout = Layout.calculate(spec: spec, currentLayout: currentLayout, currentCounter: currentLayout?.counter)
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
