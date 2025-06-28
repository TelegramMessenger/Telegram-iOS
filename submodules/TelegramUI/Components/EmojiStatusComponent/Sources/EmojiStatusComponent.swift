import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import AccountContext
import TelegramCore
import Postbox
import EmojiTextAttachmentView
import AppBundle
import TextFormat
import Lottie
import GZip
import HierarchyTrackingLayer
import TelegramUIPreferences

public final class EmojiStatusComponent: Component {
    public typealias EnvironmentType = Empty
    
    public enum AnimationContent: Equatable {
        case file(file: TelegramMediaFile)
        case customEmoji(fileId: Int64)
        
        public var fileId: MediaId {
            switch self {
            case let .file(file):
                return file.fileId
            case let .customEmoji(fileId):
                return MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
            }
        }
    }
    
    public enum LoopMode: Equatable {
        case forever
        case count(Int)
    }
    
    public enum SizeType {
        case compact
        case large
    }
    
    public enum Content: Equatable {
        case none
        case premium(color: UIColor)
        case verified(fillColor: UIColor, foregroundColor: UIColor, sizeType: SizeType)
        case text(color: UIColor, string: String)
        case animation(content: AnimationContent, size: CGSize, placeholderColor: UIColor, themeColor: UIColor?, loopMode: LoopMode)
        case topic(title: String, color: Int32, size: CGSize)
        case image(image: UIImage?, tintColor: UIColor?)
    }
    
    public let postbox: Postbox
    public let energyUsageSettings: EnergyUsageSettings
    public let resolveInlineStickers: ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let content: Content
    public let particleColor: UIColor?
    public let size: CGSize?
    public let roundMask: Bool
    public let isVisibleForAnimations: Bool
    public let useSharedAnimation: Bool
    public let action: (() -> Void)?
    public let emojiFileUpdated: ((TelegramMediaFile?) -> Void)?
    public let tag: AnyObject?
    
    public convenience init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        content: Content,
        particleColor: UIColor? = nil,
        size: CGSize? = nil,
        roundMask: Bool = false,
        isVisibleForAnimations: Bool,
        useSharedAnimation: Bool = false,
        action: (() -> Void)?,
        emojiFileUpdated: ((TelegramMediaFile?) -> Void)? = nil,
        tag: AnyObject? = nil
    ) {
        self.init(
            postbox: context.account.postbox,
            energyUsageSettings: context.sharedContext.energyUsageSettings,
            resolveInlineStickers: { fileIds in
                return context.engine.stickers.resolveInlineStickers(fileIds: fileIds)
            },
            animationCache: animationCache,
            animationRenderer: animationRenderer,
            content: content,
            particleColor: particleColor,
            size: size,
            roundMask: roundMask,
            isVisibleForAnimations: isVisibleForAnimations,
            useSharedAnimation: useSharedAnimation,
            action: action,
            emojiFileUpdated: emojiFileUpdated,
            tag: tag
        )
    }
    
    public init(
        postbox: Postbox,
        energyUsageSettings: EnergyUsageSettings,
        resolveInlineStickers: @escaping ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        content: Content,
        particleColor: UIColor? = nil,
        size: CGSize? = nil,
        roundMask: Bool = false,
        isVisibleForAnimations: Bool,
        useSharedAnimation: Bool = false,
        action: (() -> Void)?,
        emojiFileUpdated: ((TelegramMediaFile?) -> Void)? = nil,
        tag: AnyObject? = nil
    ) {
        self.postbox = postbox
        self.energyUsageSettings = energyUsageSettings
        self.resolveInlineStickers = resolveInlineStickers
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.content = content
        self.particleColor = particleColor
        self.size = size
        self.roundMask = roundMask
        self.isVisibleForAnimations = isVisibleForAnimations
        self.useSharedAnimation = useSharedAnimation
        self.action = action
        self.emojiFileUpdated = emojiFileUpdated
        self.tag = tag
    }
    
    public func withVisibleForAnimations(_ isVisibleForAnimations: Bool) -> EmojiStatusComponent {
        return EmojiStatusComponent(
            postbox: self.postbox,
            energyUsageSettings: self.energyUsageSettings,
            resolveInlineStickers: self.resolveInlineStickers,
            animationCache: self.animationCache,
            animationRenderer: self.animationRenderer,
            content: self.content,
            particleColor: self.particleColor,
            size: self.size,
            roundMask: self.roundMask,
            isVisibleForAnimations: isVisibleForAnimations,
            useSharedAnimation: self.useSharedAnimation,
            action: self.action,
            emojiFileUpdated: self.emojiFileUpdated,
            tag: self.tag
        )
    }
    
    public static func ==(lhs: EmojiStatusComponent, rhs: EmojiStatusComponent) -> Bool {
        if lhs.postbox !== rhs.postbox {
            return false
        }
        if lhs.energyUsageSettings != rhs.energyUsageSettings {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.particleColor != rhs.particleColor {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.roundMask != rhs.roundMask {
            return false
        }
        if lhs.isVisibleForAnimations != rhs.isVisibleForAnimations {
            return false
        }
        if lhs.useSharedAnimation != rhs.useSharedAnimation {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }

    public final class View: UIView, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private final class AnimationFileProperties {
            let path: String
            let coloredComposition: Animation?
            
            init(path: String, coloredComposition: Animation?) {
                self.path = path
                self.coloredComposition = coloredComposition
            }
            
            static func load(from path: String) -> AnimationFileProperties {
                guard let size = fileSize(path), size < 1024 * 1024 else {
                    return AnimationFileProperties(path: path, coloredComposition: nil)
                }
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                    return AnimationFileProperties(path: path, coloredComposition: nil)
                }
                guard let unzippedData = TGGUnzipData(data, 1024 * 1024) else {
                    return AnimationFileProperties(path: path, coloredComposition: nil)
                }
                
                var coloredComposition: Animation?
                if let composition = try? Animation.from(data: unzippedData) {
                    coloredComposition = composition
                }
                
                return AnimationFileProperties(path: path, coloredComposition: coloredComposition)
            }
        }
        
        private weak var state: EmptyComponentState?
        private var component: EmojiStatusComponent?
        private var starsLayer: StarsEffectLayer?
        
        private var iconLayer: SimpleLayer?
        private var iconLayerImage: UIImage?
        
        private var animationLayer: InlineStickerItemLayer?
        private var lottieAnimationView: AnimationView?
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
        private var emojiFile: TelegramMediaFile?
        private var emojiFileDataProperties: AnimationFileProperties?
        private var emojiFileDisposable: Disposable?
        private var emojiFileDataPathDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let lottieAnimationView = strongSelf.lottieAnimationView {
                    lottieAnimationView.play()
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.emojiFileDisposable?.dispose()
            self.emojiFileDataPathDisposable?.dispose()
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action?()
            }
        }
        
        public func playOnce() {
            self.animationLayer?.playOnce()
        }
        
        func update(component: EmojiStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let availableSize = component.size ?? availableSize
            
            self.state = state
            
            var iconImage: UIImage?
            var emojiFileId: Int64?
            var emojiPlaceholderColor: UIColor?
            var emojiThemeColor: UIColor?
            var emojiLoopMode: LoopMode?
            var emojiSize = CGSize()
            
            var iconTintColor: UIColor?
            
            self.isUserInteractionEnabled = component.action != nil
            
            if let particleColor = component.particleColor {
                let starsLayer: StarsEffectLayer
                if let current = self.starsLayer {
                    starsLayer = current
                } else {
                    starsLayer = StarsEffectLayer()
                    self.layer.insertSublayer(starsLayer, at: 0)
                    self.starsLayer = starsLayer
                }
                let side = floor(availableSize.width * 1.25)
                let starsFrame = CGSize(width: side, height: side).centered(in: CGRect(origin: .zero, size: availableSize))
                starsLayer.frame = starsFrame
                starsLayer.update(color: particleColor, size: starsFrame.size)
            } else if let starsLayer = self.starsLayer {
                self.starsLayer = nil
                starsLayer.removeFromSuperlayer()
            }
            
            //let previousContent = self.component?.content
            if self.component?.content != component.content {
                switch component.content {
                case .none:
                    iconImage = nil
                case let .premium(color):
                    iconTintColor = color
                    
                    if case .premium = self.component?.content, let image = self.iconLayerImage {
                        iconImage = image
                    } else {
                        if let sourceImage = UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon") {
                            iconImage = generateImage(sourceImage.size, contextGenerator: { size, context in
                                if let cgImage = sourceImage.cgImage {
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    let imageSize = CGSize(width: sourceImage.size.width - 8.0, height: sourceImage.size.height - 8.0)
                                    context.clip(to: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize), mask: cgImage)
                                    
                                    context.setFillColor(UIColor.white.cgColor)
                                    context.fill(CGRect(origin: CGPoint(), size: size))
                                }
                            }, opaque: false)?.withRenderingMode(.alwaysTemplate)
                        } else {
                            iconImage = nil
                        }
                    }
                case let .topic(title, color, realSize):
                    let colors = topicIconColors(for: color)
                    if let image = generateTopicIcon(title: title, backgroundColors: colors.0.map(UIColor.init(rgb:)), strokeColors: colors.1.map(UIColor.init(rgb:)), size: realSize) {
                        iconImage = image
                    } else {
                        iconImage = nil
                    }
                case let .image(image, tintColor):
                    iconImage = image
                    iconTintColor = tintColor
                case let .verified(fillColor, foregroundColor, sizeType):
                    let imageNamePrefix: String
                    switch sizeType {
                    case .compact:
                        imageNamePrefix = "Chat List/PeerVerifiedIcon"
                    case .large:
                        imageNamePrefix = "Peer Info/VerifiedIcon"
                    }
                    
                    if let backgroundImage = UIImage(bundleImageName: "\(imageNamePrefix)Background"), let foregroundImage = UIImage(bundleImageName: "\(imageNamePrefix)Foreground") {
                        iconImage = generateImage(backgroundImage.size, contextGenerator: { size, context in
                            if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                context.saveGState()
                                context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)

                                context.setFillColor(fillColor.cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                                context.restoreGState()
                                
                                context.setBlendMode(.copy)
                                context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                                context.setFillColor(foregroundColor.cgColor)
                                context.fill(CGRect(origin: CGPoint(), size: size))
                            }
                        }, opaque: false)
                    } else {
                        iconImage = nil
                    }
                case let .text(color, string):
                    let titleString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: color, paragraphAlignment: .center)
                    let stringRect = titleString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    
                    iconImage = generateImage(CGSize(width: floor(stringRect.width) + 11.0, height: 16.0), contextGenerator: { size, context in
                        let bounds = CGRect(origin: CGPoint(), size: size)
                        context.clear(bounds)
                        
                        context.setFillColor(color.cgColor)
                        context.setStrokeColor(color.cgColor)
                        context.setLineWidth(1.0)
                        
                        context.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2.0).cgPath)
                        context.strokePath()
                        
                        let titlePath = CGMutablePath()
                        titlePath.addRect(bounds.offsetBy(dx: 0.0, dy: -2.0 + UIScreenPixel))
                        let titleFramesetter = CTFramesetterCreateWithAttributedString(titleString as CFAttributedString)
                        let titleFrame = CTFramesetterCreateFrame(titleFramesetter, CFRangeMake(0, titleString.length), titlePath, nil)
                        CTFrameDraw(titleFrame, context)
                    })
                case let .animation(animationContent, size, placeholderColor, themeColor, loopMode):
                    iconImage = nil
                    emojiFileId = animationContent.fileId.id
                    emojiPlaceholderColor = placeholderColor
                    emojiThemeColor = themeColor
                    emojiSize = size
                    emojiLoopMode = loopMode
                    
                    if case let .animation(previousAnimationContent, _, _, _, _) = self.component?.content {
                        if previousAnimationContent.fileId != animationContent.fileId {
                            self.emojiFileDisposable?.dispose()
                            self.emojiFileDisposable = nil
                            self.emojiFileDataPathDisposable?.dispose()
                            self.emojiFileDataPathDisposable = nil
                            
                            self.emojiFile = nil
                            self.emojiFileDataProperties = nil
                            
                            if let animationLayer = self.animationLayer {
                                self.animationLayer = nil
                                
                                if !transition.animation.isImmediate {
                                    animationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak animationLayer] _ in
                                        animationLayer?.removeFromSuperlayer()
                                    })
                                    animationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                                } else {
                                    animationLayer.removeFromSuperlayer()
                                }
                            }
                            if let lottieAnimationView = self.lottieAnimationView {
                                self.lottieAnimationView = nil
                                
                                if !transition.animation.isImmediate {
                                    lottieAnimationView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak lottieAnimationView] _ in
                                        lottieAnimationView?.removeFromSuperview()
                                    })
                                    lottieAnimationView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                                } else {
                                    lottieAnimationView.removeFromSuperview()
                                }
                            }
                        }
                    }
                    
                    switch animationContent {
                    case let .file(file):
                        self.emojiFile = file
                    case .customEmoji:
                        break
                    }
                }
            } else {
                iconImage = self.iconLayerImage
                if case let .animation(animationContent, size, placeholderColor, themeColor, loopMode) = component.content {
                    emojiFileId = animationContent.fileId.id
                    emojiPlaceholderColor = placeholderColor
                    emojiThemeColor = themeColor
                    emojiLoopMode = loopMode
                    emojiSize = size
                } else if case let .premium(color) = component.content {
                    iconTintColor = color
                }
            }
            
            self.component = component
            
            var size = CGSize()
            
            if let iconImage = iconImage {
                let iconLayer: SimpleLayer
                if let current = self.iconLayer {
                    iconLayer = current
                } else {
                    iconLayer = SimpleLayer()
                    self.iconLayer = iconLayer
                    self.layer.addSublayer(iconLayer)
                    
                    if !transition.animation.isImmediate {
                        iconLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        iconLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                    }
                }
                if self.iconLayerImage !== iconImage {
                    self.iconLayerImage = iconImage
                    iconLayer.contents = iconImage.cgImage
                }
                
                if let iconTintColor {
                    transition.setTintColor(layer: iconLayer, color: iconTintColor)
                } else {
                    iconLayer.layerTintColor = nil
                }
                
                var useFit = false
                switch component.content {
                case .text:
                    useFit = true
                case .verified(_, _, sizeType: .compact):
                    useFit = true
                default:
                    break
                }
                if useFit {
                    size = CGSize(width: iconImage.size.width, height: availableSize.height)
                    iconLayer.frame = CGRect(origin: CGPoint(x: floor((size.width - iconImage.size.width) / 2.0), y: floor((size.height - iconImage.size.height) / 2.0)), size: iconImage.size)
                } else {
                    size = iconImage.size.aspectFilled(availableSize)
                    iconLayer.frame = CGRect(origin: CGPoint(), size: size)
                }
            } else {
                if let iconLayer = self.iconLayer {
                    self.iconLayer = nil
                    
                    if !transition.animation.isImmediate {
                        iconLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak iconLayer] _ in
                            iconLayer?.removeFromSuperlayer()
                        })
                        iconLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    } else {
                        iconLayer.removeFromSuperlayer()
                    }
                }
                self.iconLayerImage = nil
            }
            
            let emojiFileUpdated = component.emojiFileUpdated
            if let emojiFileId = emojiFileId, let emojiPlaceholderColor = emojiPlaceholderColor, let emojiLoopMode = emojiLoopMode {
                size = availableSize
                
                if let emojiFile = self.emojiFile {
                    self.emojiFileDisposable?.dispose()
                    self.emojiFileDisposable = nil
                    self.emojiFileDataPathDisposable?.dispose()
                    self.emojiFileDataPathDisposable = nil
                    
                    let animationLayer: InlineStickerItemLayer
                    if let current = self.animationLayer {
                        animationLayer = current
                    } else {
                        let loopCount: Int?
                        switch emojiLoopMode {
                        case .forever:
                            loopCount = nil
                        case let .count(value):
                            loopCount = value
                        }
                        animationLayer = InlineStickerItemLayer(
                            context: .custom(InlineStickerItemLayer.Context.Custom(
                                postbox: component.postbox,
                                energyUsageSettings: {
                                    return component.energyUsageSettings
                                },
                                resolveInlineStickers: { fileIds in
                                    return component.resolveInlineStickers(fileIds)
                                }
                            )),
                            userLocation: .other,
                            attemptSynchronousLoad: false,
                            emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiFile.fileId.id, file: emojiFile),
                            file: emojiFile,
                            cache: component.animationCache,
                            renderer: component.animationRenderer,
                            unique: !component.useSharedAnimation,
                            placeholderColor: emojiPlaceholderColor,
                            pointSize: emojiSize,
                            loopCount: loopCount
                        )
                        self.animationLayer = animationLayer
                        self.layer.addSublayer(animationLayer)
                        
                        if !transition.animation.isImmediate {
                            animationLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            animationLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                        }
                    }
                    
                    var accentTint = false
                    if let _ = emojiThemeColor {
                        if emojiFile.isCustomTemplateEmoji {
                            accentTint = true
                        }
                        for attribute in emojiFile.attributes {
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
                    }
                    
                    if accentTint {
                        animationLayer.updateTintColor(contentTintColor: emojiThemeColor, dynamicColor: emojiThemeColor, transition: transition)
                    } else {
                        animationLayer.updateTintColor(contentTintColor: nil, dynamicColor: nil, transition: transition)
                    }
                    
                    animationLayer.frame = CGRect(origin: CGPoint(), size: size)
                    animationLayer.isVisibleForAnimations = component.isVisibleForAnimations
                } else {
                    if self.emojiFileDisposable == nil {
                        self.emojiFileDisposable = (component.resolveInlineStickers([emojiFileId])
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.emojiFile = result[emojiFileId]
                            strongSelf.emojiFileDataProperties = nil
                            strongSelf.state?.updated(transition: transition)
                            
                            emojiFileUpdated?(result[emojiFileId])
                        })
                    }
                }
            } else {
                if let _ = self.emojiFile {
                    self.emojiFile = nil
                    self.emojiFileDataProperties = nil
                    emojiFileUpdated?(nil)
                }
                
                self.emojiFileDisposable?.dispose()
                self.emojiFileDisposable = nil
                self.emojiFileDataPathDisposable?.dispose()
                self.emojiFileDataPathDisposable = nil
                
                if let animationLayer = self.animationLayer {
                    self.animationLayer = nil
                    
                    if !transition.animation.isImmediate {
                        animationLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak animationLayer] _ in
                            animationLayer?.removeFromSuperlayer()
                        })
                        animationLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    } else {
                        animationLayer.removeFromSuperlayer()
                    }
                }
                if let lottieAnimationView = self.lottieAnimationView {
                    self.lottieAnimationView = nil
                    
                    if !transition.animation.isImmediate {
                        lottieAnimationView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak lottieAnimationView] _ in
                            lottieAnimationView?.removeFromSuperview()
                        })
                        lottieAnimationView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    } else {
                        lottieAnimationView.removeFromSuperview()
                    }
                }
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public func topicIconColors(for color: Int32) -> ([UInt32], [UInt32]) {
    let topicColors: [Int32: ([UInt32], [UInt32])] = [
        0x6FB9F0: ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7]),
        0xFFD67E: ([0xFFD67E, 0xFC8601], [0xDA9400, 0xFA5F00]),
        0xCB86DB: ([0xCB86DB, 0x9338AF], [0x812E98, 0x6F2B87]),
        0x8EEE98: ([0x8EEE98, 0x02B504], [0x02A01B, 0x009716]),
        0xFF93B2: ([0xFF93B2, 0xE23264], [0xFC447A, 0xC80C46]),
        0xFB6F5F: ([0xFB6F5F, 0xD72615], [0xDC1908, 0xB61506])
    ]
    
    return topicColors[color] ?? ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7])
}

public final class StarsEffectLayer: SimpleLayer {
    private let emitterLayer = CAEmitterLayer()
    
    public override init() {
        super.init()
        
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(color: UIColor, size: CGSize) {
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 8.0
        emitter.lifetime = 2.0
        emitter.velocity = 0.1
        emitter.scale = (size.width / 32.0) * 0.12
        emitter.scaleRange = 0.02
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.withAlphaComponent(0.58).cgColor,
            color.withAlphaComponent(0.58).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        self.emitterLayer.emitterCells = [emitter]
    }
    
    public func update(color: UIColor, size: CGSize) {
        if self.emitterLayer.emitterCells == nil {
            self.setup(color: color, size: size)
        }
        self.emitterLayer.seed = UInt32.random(in: .min ..< .max)
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = size
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
