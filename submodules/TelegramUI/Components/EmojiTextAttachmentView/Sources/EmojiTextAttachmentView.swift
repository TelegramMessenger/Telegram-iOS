import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import AccountContext
import YuvConversion
import TelegramCore
import Postbox
import AnimationCache
import LottieAnimationCache
import VideoAnimationCache
import MultiAnimationRenderer
import ShimmerEffect
import TextFormat
import TelegramUIPreferences
import GenerateStickerPlaceholderImage
import UIKitRuntimeUtils
import ComponentFlow

public func generateTopicIcon(title: String, backgroundColors: [UIColor], strokeColors: [UIColor], size: CGSize) -> UIImage? {
    let realSize = size
    return generateImage(realSize, rotatedContext: { realSize, context in
        context.clear(CGRect(origin: .zero, size: realSize))

        context.saveGState()
        
        let size = CGSize(width: 32.0, height: 32.0)
        
        let scale: CGFloat = realSize.width / size.width
        context.scaleBy(x: scale, y: scale)
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.translateBy(x: -14.0 - UIScreenPixel, y: -14.0 - UIScreenPixel)
        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        context.clip()
        
        let colorsArray = backgroundColors.map { $0.cgColor } as NSArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        if let path = context.path {
            let strokePath = path.copy(strokingWithWidth: 1.0 + UIScreenPixel, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
            context.beginPath()
            context.addPath(strokePath)
            context.clip()
            
            let colorsArray = strokeColors.map { $0.cgColor } as NSArray
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        
        context.restoreGState()
        
        let fontSize = round(15.0 * scale)
        
        let attributedString = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font: Font.with(size: fontSize, design: .round, weight: .bold), NSAttributedString.Key.foregroundColor: UIColor.white])
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let lineBounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        
        let lineOffset = CGPoint(x: 1.0 - UIScreenPixel, y: floorToScreenPixels(realSize.height * 0.05))
        let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (realSize.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (realSize.height - lineBounds.size.height) / 2.0) + lineOffset.y)
        
        context.translateBy(x: realSize.width / 2.0, y: realSize.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -realSize.width / 2.0, y: -realSize.height / 2.0)
        
        context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
        CTLineDraw(line, context)
        context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    })
}

public enum AnimationCacheAnimationType: Equatable {
    case still
    case lottie
    case video(isVP9: Bool)
}

public extension AnimationCacheAnimationType {
    init(file: TelegramMediaFile) {
        if file.isVideoSticker || file.isVideoEmoji {
            self = .video(isVP9: true)
        } else if file.isAnimatedSticker {
            self = .lottie
        } else if file.isVideo {
            self = .video(isVP9: false)
        } else {
            self = .still
        }
    }
}

public func animationCacheFetchFile(context: AccountContext, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, resource: MediaResourceReference, type: AnimationCacheAnimationType, keyframeOnly: Bool, customColor: UIColor?) -> (AnimationCacheFetchOptions) -> Disposable {
    return animationCacheFetchFile(
        postbox: context.account.postbox,
        userLocation: userLocation,
        userContentType: userContentType,
        resource: resource,
        type: type,
        keyframeOnly: keyframeOnly,
        customColor: customColor
    )
}

public func animationCacheFetchFile(postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, resource: MediaResourceReference, type: AnimationCacheAnimationType, keyframeOnly: Bool, customColor: UIColor?) -> (AnimationCacheFetchOptions) -> Disposable {
    return { options in
        let source = AnimatedStickerResourceSource(postbox: postbox, resource: resource.resource, fitzModifier: nil, isVideo: false)
        
        let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
            guard let result = result else {
                return
            }
            
            switch type {
            case let .video(isVP9):
                cacheVideoAnimation(path: result, hintVP9: isVP9, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, firstFrameOnly: options.firstFrameOnly, customColor: customColor)
            case .lottie:
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                    options.writer.finish()
                    return
                }
                cacheLottieAnimation(data: data, width: Int(options.size.width), height: Int(options.size.height), keyframeOnly: keyframeOnly, writer: options.writer, firstFrameOnly: options.firstFrameOnly, customColor: customColor)
            case .still:
                cacheStillSticker(path: result, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, customColor: customColor)
            }
        })
        
        let fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: userLocation, userContentType: userContentType, reference: resource).start()
        
        return ActionDisposable {
            dataDisposable.dispose()
            fetchDisposable.dispose()
        }
    }
}

public func animationCacheLoadLocalFile(name: String, type: AnimationCacheAnimationType, keyframeOnly: Bool, customColor: UIColor?) -> (AnimationCacheFetchOptions) -> Disposable {
    return { options in
        let source = AnimatedStickerNodeLocalFileSource(name: name)
        let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
            guard let result = result else {
                return
            }
            
            switch type {
            case let .video(isVP9):
                cacheVideoAnimation(path: result, hintVP9: isVP9, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, firstFrameOnly: options.firstFrameOnly, customColor: customColor)
            case .lottie:
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                    options.writer.finish()
                    return
                }
                cacheLottieAnimation(data: data, width: Int(options.size.width), height: Int(options.size.height), keyframeOnly: keyframeOnly, writer: options.writer, firstFrameOnly: options.firstFrameOnly, customColor: customColor)
            case .still:
                cacheStillSticker(path: result, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, customColor: customColor)
            }
        })
                
        return ActionDisposable {
            dataDisposable.dispose()
        }
    }
}

private func generatePeerNameColorImage(nameColor: PeerNameColors.Colors, isDark: Bool, bounds: CGSize = CGSize(width: 40.0, height: 40.0), size: CGSize = CGSize(width: 40.0, height: 40.0)) -> UIImage? {
    return generateImage(bounds, rotatedContext: { contextSize, context in
        let bounds = CGRect(origin: CGPoint(), size: contextSize)
        context.clear(bounds)
        
        let circleBounds = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - size.width) / 2.0), y: floorToScreenPixels((bounds.height - size.height) / 2.0)), size: size)
        context.addEllipse(in: circleBounds)
        context.clip()
        
        if let secondColor = nameColor.secondary {
            var firstColor = nameColor.main
            var secondColor = secondColor
            if isDark, nameColor.tertiary == nil {
                firstColor = secondColor
                secondColor = nameColor.main
            }
            
            context.setFillColor(secondColor.cgColor)
            context.fill(circleBounds)
            
            if let thirdColor = nameColor.tertiary {
                context.move(to: CGPoint(x: contextSize.width, y: 0.0))
                context.addLine(to: CGPoint(x: contextSize.width, y: contextSize.height))
                context.addLine(to: CGPoint(x: 0.0, y: contextSize.height))
                context.closePath()
                context.setFillColor(firstColor.cgColor)
                context.fillPath()
                
                context.setFillColor(thirdColor.cgColor)
                context.translateBy(x: contextSize.width / 2.0, y: contextSize.height / 2.0)
                context.rotate(by: .pi / 4.0)
                
                let rectSide = size.width / 40.0 * 18.0
                let rectCornerRadius = round(size.width / 40.0 * 4.0)
                let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: -rectSide / 2.0, y: -rectSide / 2.0), size: CGSize(width: rectSide, height: rectSide)), cornerRadius: rectCornerRadius)
                context.addPath(path.cgPath)
                context.fillPath()
            } else {
                context.move(to: .zero)
                context.addLine(to: CGPoint(x: contextSize.width, y: 0.0))
                context.addLine(to: CGPoint(x: 0.0, y: contextSize.height))
                context.closePath()
                context.setFillColor(firstColor.cgColor)
                context.fillPath()
            }
        } else {
            context.setFillColor(nameColor.main.cgColor)
            context.fill(circleBounds)
        }
    })
}

public final class InlineStickerItemLayer: MultiAnimationRenderTarget {
    private final class Arguments {
        let context: InlineStickerItemLayer.Context
        let userLocation: MediaResourceUserLocation
        let emoji: ChatTextInputTextCustomEmojiAttribute
        let cache: AnimationCache
        let renderer: MultiAnimationRenderer
        let placeholderColor: UIColor
        let loopCount: Int?
        
        let pointSize: CGSize
        let pixelSize: CGSize
        
        init(context: InlineStickerItemLayer.Context, userLocation: MediaResourceUserLocation, emoji: ChatTextInputTextCustomEmojiAttribute, cache: AnimationCache, renderer: MultiAnimationRenderer, placeholderColor: UIColor, loopCount: Int?, pointSize: CGSize, pixelSize: CGSize) {
            self.context = context
            self.userLocation = userLocation
            self.emoji = emoji
            self.cache = cache
            self.renderer = renderer
            self.placeholderColor = placeholderColor
            self.loopCount = loopCount
            self.pointSize = pointSize
            self.pixelSize = pixelSize
        }
    }
    
    public enum Context: Equatable {
        public final class Custom: Equatable {
            public let postbox: Postbox
            public let energyUsageSettings: () -> EnergyUsageSettings
            public let resolveInlineStickers: ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>
            
            public init(postbox: Postbox, energyUsageSettings: @escaping () -> EnergyUsageSettings, resolveInlineStickers: @escaping ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>) {
                self.postbox = postbox
                self.energyUsageSettings = energyUsageSettings
                self.resolveInlineStickers = resolveInlineStickers
            }
            
            public static func ==(lhs: Custom, rhs: Custom) -> Bool {
                if lhs.postbox !== rhs.postbox {
                    return false
                }
                return true
            }
        }
        
        case account(AccountContext)
        case custom(Custom)
        
        var postbox: Postbox {
            switch self {
            case let .account(account):
                return account.account.postbox
            case let .custom(custom):
                return custom.postbox
            }
        }
        
        var energyUsageSettings: EnergyUsageSettings {
            switch self {
            case let .account(account):
                return account.sharedContext.energyUsageSettings
            case let .custom(custom):
                return custom.energyUsageSettings()
            }
        }
        
        func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError> {
            switch self {
            case let .account(account):
                return account.engine.stickers.resolveInlineStickers(fileIds: fileIds)
            case let .custom(custom):
                return custom.resolveInlineStickers(fileIds)
            }
        }
        
        public static func ==(lhs: Context, rhs: Context) -> Bool {
            switch lhs {
            case let .account(lhsContext):
                if case let .account(rhsContext) = rhs, lhsContext === rhsContext {
                    return true
                } else {
                    return false
                }
            case let .custom(custom):
                if case .custom(custom) = rhs {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    public static let queue = Queue()
    
    public struct Key: Hashable {
        public var id: Int64
        public var index: Int
        
        public init(id: Int64, index: Int) {
            self.id = id
            self.index = index
        }
    }
    
    private let arguments: Arguments?
    
    private var isDisplayingPlaceholder: Bool = false
    private var didProcessTintColor: Bool = false
    
    public private(set) var file: TelegramMediaFile?
    private var localAnimationName: String?
    
    private var infoDisposable: Disposable?
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    private var loadDisposable: Disposable?
    
    private var _contentTintColor: UIColor?
    public var contentTintColor: UIColor? {
        get {
            return self._contentTintColor
        }
        set(value) {
            if self._contentTintColor != value {
                self._contentTintColor = value
                self.updateTintColor()
            }
        }
    }
    
    private var _dynamicColor: UIColor?
    public var dynamicColor: UIColor? {
        get {
            return self._dynamicColor
        }
        set(value) {
            if self._dynamicColor != value {
                self._dynamicColor = value
                self.updateTintColor()
            }
        }
    }
    
    private var overrideLoopCount: Int?
    private var currentLoopCount: Int = 0
    
    public var isUnique: Bool = false
    
    private var isInHierarchyValue: Bool = false
    public var isVisibleForAnimations: Bool = false {
        didSet {
            if self.isVisibleForAnimations != oldValue {
                self.updatePlayback()
            }
        }
    }
    
    public var enableAnimation: Bool = true
    
    public weak var mirrorLayer: CALayer? {
        didSet {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.contents = self.contents
                
                var customColor = self.contentTintColor
                if let file = self.file {
                    if file.isCustomTemplateEmoji {
                        customColor = self.dynamicColor
                    }
                }
                
                if customColor != nil {
                    if self.layerTintColor == nil {
                        setLayerContentsMaskMode(mirrorLayer, true)
                    }
                } else {
                    if self.layerTintColor != nil {
                        setLayerContentsMaskMode(mirrorLayer, false)
                    }
                }
                if let customColor {
                    ComponentTransition.immediate.setTintColor(layer: mirrorLayer, color: customColor)
                } else {
                    self.layerTintColor = nil
                }
            }
        }
    }
    
    override public var contents: Any? {
        get {
            return super.contents
        } set(value) {
            #if targetEnvironment(simulator)
            if let value, CFGetTypeID(value as CFTypeRef) == CVPixelBufferGetTypeID() {
                let pixelBuffer = value as! CVPixelBuffer
                super.contents = CVPixelBufferGetIOSurface(pixelBuffer)
            } else {
                super.contents = value
            }
            #else
            super.contents = value
            #endif
            
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.contents = self.contents
            }
        }
    }
    
    public convenience init(context: AccountContext, userLocation: MediaResourceUserLocation, attemptSynchronousLoad: Bool, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool = false, placeholderColor: UIColor, pointSize: CGSize, dynamicColor: UIColor? = nil, loopCount: Int? = nil) {
        self.init(
            context: .account(context),
            userLocation: userLocation,
            attemptSynchronousLoad: attemptSynchronousLoad,
            emoji: emoji,
            file: file,
            cache: cache,
            renderer: renderer,
            unique: unique,
            placeholderColor: placeholderColor,
            pointSize: pointSize,
            dynamicColor: dynamicColor,
            loopCount: loopCount
        )
    }
    
    public init(context: InlineStickerItemLayer.Context, userLocation: MediaResourceUserLocation, attemptSynchronousLoad: Bool, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool = false, placeholderColor: UIColor, pointSize: CGSize, dynamicColor: UIColor? = nil, loopCount: Int? = nil) {
        let scale = min(2.0, UIScreenScale)
        
        self.isUnique = unique
        
        self.arguments = Arguments(
            context: context,
            userLocation: userLocation,
            emoji: emoji,
            cache: cache,
            renderer: renderer,
            placeholderColor: placeholderColor,
            loopCount: loopCount,
            pointSize: pointSize,
            pixelSize: CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        )
        
        self._dynamicColor = dynamicColor
        
        super.init()
        
        if let custom = emoji.custom {
            switch custom {
            case let .topic(id, info):
                self.updateTopicInfo(topicInfo: (id, info))
            case let .nameColors(colors):
                self.updateNameColors(colors: colors)
            case let .stars(tinted):
                self.updateStars(tinted: tinted)
                if tinted {
                    self.updateTintColor()
                }
            case let .ton(tinted):
                self.updateTon(tinted: tinted)
                if tinted {
                    self.updateTintColor()
                }
            case let .animation(name):
                self.updateLocalAnimation(name: name, attemptSynchronousLoad: attemptSynchronousLoad)
            case .verification:
                self.updateVerification()
                self.updateTintColor()
            }
        } else if let file = file {
            self.updateFile(file: file, attemptSynchronousLoad: attemptSynchronousLoad)
        } else {
            self.infoDisposable = (context.resolveInlineStickers(fileIds: [emoji.fileId])
            |> deliverOnMainQueue).start(next: { [weak self] files in
                guard let strongSelf = self else {
                    return
                }
                if let file = files[emoji.fileId] {
                    strongSelf.updateFile(file: file, attemptSynchronousLoad: false)
                }
            })
        }
    }
    
    override public init(layer: Any) {
        self.arguments = nil
        
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.loadDisposable?.dispose()
        self.infoDisposable?.dispose()
        self.disposable?.dispose()
        self.fetchDisposable?.dispose()
    }
    
    override public func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchyValue = true
            self.updatePlayback()
        } else if event == kCAOnOrderOut {
            self.isInHierarchyValue = false
            self.updatePlayback()
        }
        return nullAction
    }
    
    public func updateTintColor(contentTintColor: UIColor?, dynamicColor: UIColor?, transition: ComponentTransition) {
        self._contentTintColor = contentTintColor
        self._dynamicColor = dynamicColor
        
        if !self.isDisplayingPlaceholder {
            var customColor = self.contentTintColor
            if let file = self.file {
                if file.isCustomTemplateEmoji {
                    customColor = self.dynamicColor
                }
            }
            
            if customColor != nil {
                if self.layerTintColor == nil {
                    setLayerContentsMaskMode(self, true)
                }
            } else {
                if self.layerTintColor != nil {
                    setLayerContentsMaskMode(self, false)
                }
            }
            if let customColor {
                transition.setTintColor(layer: self, color: customColor)
            } else {
                self.layerTintColor = nil
            }
        } else {
            if self.layerTintColor != nil {
                setLayerContentsMaskMode(self, false)
            }
            self.layerTintColor = nil
        }
    }
    
    private func updateTintColor() {
        if !self.isDisplayingPlaceholder {
            var customColor = self.contentTintColor
            if let file = self.file {
                if file.isCustomTemplateEmoji {
                    customColor = self.dynamicColor
                }
            } else if let emoji = self.arguments?.emoji, let custom = emoji.custom {
                switch custom {
                case .stars(true), .ton(true), .verification:
                    customColor = self.dynamicColor
                default:
                    break
                }
            }
            
            if customColor != nil {
                if self.layerTintColor == nil {
                    setLayerContentsMaskMode(self, true)
                }
            } else {
                if self.layerTintColor != nil {
                    setLayerContentsMaskMode(self, false)
                }
            }
            self.layerTintColor = customColor?.cgColor
        } else {
            if self.layerTintColor != nil {
                setLayerContentsMaskMode(self, false)
            }
            self.layerTintColor = nil
        }
    }
    
    private func updatePlayback() {
        guard let arguments = self.arguments else {
            return
        }
        
        var shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
        
        if shouldBePlaying {
            if let loopCount = self.overrideLoopCount ?? arguments.loopCount, self.currentLoopCount >= loopCount {
                shouldBePlaying = false
            }
        }
        
        if self.shouldBeAnimating != shouldBePlaying {
            self.shouldBeAnimating = shouldBePlaying
            
            if !shouldBePlaying {
                self.currentLoopCount = 0
                self.overrideLoopCount = nil
            }
        }
    }
    
    private func updateTopicInfo(topicInfo: (Int64, EngineMessageHistoryThread.Info)) {
        if topicInfo.0 == 1 {
            let image = generateImage(CGSize(width: 18.0, height: 18.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                if let cgImage = generateTintedImage(image: UIImage(bundleImageName: "Chat List/GeneralTopicIcon"), color: .white)?.cgImage {
                    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                }
            })
            self.contents = image?.cgImage
        } else {
            func generateTopicColors(_ color: Int32) -> ([UInt32], [UInt32]) {
                return ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7])
            }
            
            let topicColors: [Int32: ([UInt32], [UInt32])] = [
                0x6FB9F0: ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7]),
                0xFFD67E: ([0xFFD67E, 0xFC8601], [0xDA9400, 0xFA5F00]),
                0xCB86DB: ([0xCB86DB, 0x9338AF], [0x812E98, 0x6F2B87]),
                0x8EEE98: ([0x8EEE98, 0x02B504], [0x02A01B, 0x009716]),
                0xFF93B2: ([0xFF93B2, 0xE23264], [0xFC447A, 0xC80C46]),
                0xFB6F5F: ([0xFB6F5F, 0xD72615], [0xDC1908, 0xB61506])
            ]
            let colors = topicColors[topicInfo.1.iconColor] ?? generateTopicColors(topicInfo.1.iconColor)
            
            if let image = generateTopicIcon(title: String(topicInfo.1.title.prefix(1)), backgroundColors: colors.0.map(UIColor.init(rgb:)), strokeColors: colors.1.map(UIColor.init(rgb:)), size: CGSize(width: 32.0, height: 32.0)) {
                self.contents = image.cgImage
            }
        }
    }
    
    private func updateNameColors(colors: [UInt32]) {
        if colors.isEmpty {
            return
        }
        let main = UIColor(rgb: colors[0])
        var secondary: UIColor?
        if colors.count >= 2 {
            secondary = UIColor(rgb: colors[1])
        }
        var tertiary: UIColor?
        if colors.count >= 3 {
            tertiary = UIColor(rgb: colors[2])
        }
        let mappedColor = PeerNameColors.Colors(main: main, secondary: secondary, tertiary: tertiary)
        
        let image = generateImage(CGSize(width: 18.0, height: 18.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            if let cgImage = generatePeerNameColorImage(nameColor: mappedColor, isDark: false, bounds: CGSize(width: 18.0, height: 18.0), size: CGSize(width: 16.0, height: 16.0))?.cgImage {
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
        })
        self.contents = image?.cgImage
    }
    
    private func updateStars(tinted: Bool) {
        self.contents = tinted ? tintedStarImage?.cgImage : starImage?.cgImage
    }
    
    private func updateTon(tinted: Bool) {
        self.contents = tinted ? tintedTonImage?.cgImage : tonImage?.cgImage
    }
    
    private func updateVerification() {
        self.contents = verificationImage?.cgImage
    }
    
    private func updateLocalAnimation(name: String, attemptSynchronousLoad: Bool) {
        guard let arguments = self.arguments else {
            return
        }
        
        self.localAnimationName = name
        
        if attemptSynchronousLoad {
            if !arguments.renderer.loadFirstFrameSynchronously(target: self, cache: arguments.cache, itemId: name, size: arguments.pixelSize) {
            }
            
            self.loadAnimation()
        } else {
            self.loadDisposable = arguments.renderer.loadFirstFrame(target: self, cache: arguments.cache, itemId: name, size: arguments.pixelSize, fetch: animationCacheLoadLocalFile(name: name, type: .lottie, keyframeOnly: true, customColor: nil), completion: { [weak self] result, isFinal in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.loadAnimation()
            })
        }
    }
    
    private func loadLocalAnimation() {
        guard let arguments = self.arguments else {
            return
        }
        
        guard let name = self.localAnimationName else {
            return
        }
                
        let keyframeOnly = arguments.pixelSize.width >= 120.0
        self.disposable = arguments.renderer.add(target: self, cache: arguments.cache, itemId: name, unique: self.isUnique, size: arguments.pixelSize, fetch: animationCacheLoadLocalFile(name: name, type: .lottie, keyframeOnly: keyframeOnly, customColor: nil))
    }
    
    private func updateFile(file: TelegramMediaFile, attemptSynchronousLoad: Bool) {
        if self.file?.fileId == file.fileId {
            return
        }
        
        self.file = file
        self.updateFile(attemptSynchronousLoad: attemptSynchronousLoad)
    }
    
    private func updateFile(attemptSynchronousLoad: Bool) {
        guard let arguments = self.arguments else {
            return
        }
        guard let file = self.file else {
            return
        }
        
        self.loadDisposable?.dispose()
        
        if attemptSynchronousLoad {
            if !arguments.renderer.loadFirstFrameSynchronously(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, size: arguments.pixelSize) {
                if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: arguments.pointSize, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: arguments.placeholderColor) {
                    self.contents = image.cgImage
                    self.isDisplayingPlaceholder = true
                    self.updateTintColor()
                }
            } else {
                self.updateTintColor()
            }
            
            self.loadAnimation()
        } else {
            let isTemplate = file.isCustomTemplateEmoji
            self.updateTintColor()
            
            let pointSize = arguments.pointSize
            let placeholderColor = arguments.placeholderColor
            let isThumbnailCancelled = Atomic<Bool>(value: false)
            self.loadDisposable = arguments.renderer.loadFirstFrame(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, size: arguments.pixelSize, fetch: animationCacheFetchFile(postbox: arguments.context.postbox, userLocation: arguments.userLocation, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: true, customColor: isTemplate ? .white : nil), completion: { [weak self] result, isFinal in
                if !result {
                    MultiAnimationRendererImpl.firstFrameQueue.async {
                        let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: pointSize, scale: min(2.0, UIScreenScale), imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: placeholderColor)
                        
                        DispatchQueue.main.async {
                            guard let strongSelf = self, !isThumbnailCancelled.with({ $0 }) else {
                                return
                            }
                            if let image = image {
                                strongSelf.contents = image.cgImage
                                strongSelf.isDisplayingPlaceholder = true
                                strongSelf.updateTintColor()
                            }
                            
                            if isFinal {
                                strongSelf.loadAnimation()
                            }
                        }
                    }
                } else {
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = isThumbnailCancelled.swap(true)
                    strongSelf.loadAnimation()
                }
            })
        }
    }
    
    public func playOnce() {
        self.currentLoopCount = 0
        self.overrideLoopCount = 1
        self.updatePlayback()
    }
    
    public func reloadAnimation() {
        self.updateFile(attemptSynchronousLoad: false)
    }
    
    private func loadAnimation() {
        guard let arguments = self.arguments else {
            return
        }
        
        guard let file = self.file else {
            return
        }
        
        let isTemplate = file.isCustomTemplateEmoji
        
        self.disposable?.dispose()
        
        let context = arguments.context
        if file.isAnimatedSticker || file.isVideoSticker || file.isVideoEmoji {
            let keyframeOnly = arguments.pixelSize.width >= 120.0
            
            self.disposable = arguments.renderer.add(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, unique: self.isUnique, size: arguments.pixelSize, fetch: animationCacheFetchFile(postbox: arguments.context.postbox, userLocation: arguments.userLocation, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: keyframeOnly, customColor: isTemplate ? .white : nil))
        } else {
            self.disposable = arguments.renderer.add(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, unique: self.isUnique, size: arguments.pixelSize, fetch: { options in
                let dataDisposable = context.postbox.mediaBox.resourceData(file.resource).start(next: { result in
                    guard result.complete else {
                        return
                    }
                    
                    cacheStillSticker(path: result.path, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, customColor: isTemplate ? .white : nil)
                })
                
                let fetchDisposable = freeMediaFileResourceInteractiveFetched(postbox: context.postbox, userLocation: arguments.userLocation, fileReference: .customEmoji(media: file), resource: file.resource).start()
                
                return ActionDisposable {
                    dataDisposable.dispose()
                    fetchDisposable.dispose()
                }
            })
        }
    }
    
    override public func updateDisplayPlaceholder(displayPlaceholder: Bool) {
        if self.isDisplayingPlaceholder == displayPlaceholder {
            return
        }
        self.isDisplayingPlaceholder = displayPlaceholder
        self.updateTintColor()
    }
    
    override public func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
        guard let arguments = self.arguments else {
            return
        }
        
        if self.isDisplayingPlaceholder {
            self.isDisplayingPlaceholder = false
            self.updateTintColor()
            
            if let current = self.contents {
                let previousLayer = SimpleLayer()
                previousLayer.contents = current
                previousLayer.frame = self.frame
                self.superlayer?.insertSublayer(previousLayer, below: self)
                previousLayer.opacity = 0.0
                previousLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak previousLayer] _ in
                    previousLayer?.removeFromSuperlayer()
                })
                
                self.contents = contents
                self.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
            } else {
                self.contents = contents
                self.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else {
            if !self.didProcessTintColor {
                //self.didProcessTintColor = true
                self.updateTintColor()
            }
            self.contents = contents
        }
        
        if didLoop {
            self.currentLoopCount += 1
            self.overrideLoopCount = nil
            if let loopCount = arguments.loopCount, self.currentLoopCount >= loopCount {
                self.updatePlayback()
            }
        }
    }
}

public final class EmojiTextAttachmentView: UIView {
    public let contentLayer: InlineStickerItemLayer
    
    public var isUnique: Bool = false {
        didSet {
            if self.isActive != oldValue {
                self.contentLayer.isUnique = self.isUnique
            }
        }
    }
    public var isActive: Bool = true {
        didSet {
            if self.isActive != oldValue {
                self.contentLayer.isVisibleForAnimations = self.isActive
            }
        }
    }
    
    public convenience init(context: AccountContext, userLocation: MediaResourceUserLocation, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, placeholderColor: UIColor, pointSize: CGSize) {
        self.init(
            context: .account(context),
            userLocation: userLocation,
            emoji: emoji,
            file: file,
            cache: cache,
            renderer: renderer,
            placeholderColor: placeholderColor,
            pointSize: pointSize
        )
    }
    
    public init(context: InlineStickerItemLayer.Context, userLocation: MediaResourceUserLocation, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool = false, placeholderColor: UIColor, pointSize: CGSize) {
        self.contentLayer = InlineStickerItemLayer(context: context, userLocation: userLocation, attemptSynchronousLoad: true, emoji: emoji, file: file, cache: cache, renderer: renderer, unique: unique, placeholderColor: placeholderColor, pointSize: pointSize)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.contentLayer.isVisibleForAnimations = context.energyUsageSettings.loopEmoji
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateTextColor(_ textColor: UIColor) {
        self.contentLayer.dynamicColor = textColor
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.contentLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.width, height: self.bounds.height))
    }
    
    public func resetToFirstFrame() {
        self.contentLayer.reloadAnimation()
    }
}

public final class CustomEmojiContainerView: UIView {
    private let emojiViewProvider: (ChatTextInputTextCustomEmojiAttribute) -> UIView?
    
    public private(set) var emojiLayers: [InlineStickerItemLayer.Key: UIView] = [:]
    
    public init(emojiViewProvider: @escaping (ChatTextInputTextCustomEmojiAttribute) -> UIView?) {
        self.emojiViewProvider = emojiViewProvider
        
        super.init(frame: CGRect())
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    public func update(fontSize: CGFloat, textColor: UIColor, emojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute, CGFloat)]) {
        var nextIndexById: [Int64: Int] = [:]
        
        var validKeys = Set<InlineStickerItemLayer.Key>()
        for (rect, emoji, fontSize) in emojiRects {
            let index: Int
            if let nextIndex = nextIndexById[emoji.fileId] {
                index = nextIndex
            } else {
                index = 0
            }
            nextIndexById[emoji.fileId] = index + 1
            
            let key = InlineStickerItemLayer.Key(id: emoji.fileId, index: index)
            
            let view: UIView
            if let current = self.emojiLayers[key] {
                view = current
            } else if let newView = self.emojiViewProvider(emoji) {
                view = newView
                self.addSubview(newView)
                self.emojiLayers[key] = view
            } else {
                continue
            }
            
            if let view = view as? EmojiTextAttachmentView {
                view.updateTextColor(textColor)
            }
            
            let itemSize: CGFloat = floor(24.0 * fontSize / 17.0)
            let size = CGSize(width: itemSize, height: itemSize)
            
            view.frame = CGRect(origin: CGPoint(x: floor(rect.midX - size.width / 2.0), y: floor(rect.midY - size.height / 2.0) + 1.0), size: size)
            
            validKeys.insert(key)
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, view) in self.emojiLayers {
            if !validKeys.contains(key) {
                removeKeys.append(key)
                view.removeFromSuperview()
            }
        }
        for key in removeKeys {
            self.emojiLayers.removeValue(forKey: key)
        }
    }
}

private let tintedStarImage: UIImage? = {
    generateImage(CGSize(width: 32.0, height: 32.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size).insetBy(dx: 4.0, dy: 4.0), byTiling: false)
        }
    })?.withRenderingMode(.alwaysTemplate)
}()

private let starImage: UIImage? = {
    generateImage(CGSize(width: 32.0, height: 32.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        if let image = UIImage(bundleImageName: "Premium/Stars/StarLarge"), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size).insetBy(dx: 1.0, dy: 1.0), byTiling: false)
        }
    })?.withRenderingMode(.alwaysTemplate)
}()

private let tonImage: UIImage? = {
    generateImage(CGSize(width: 32.0, height: 32.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonBig"), color: UIColor(rgb: 0x007aff)), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size).insetBy(dx: 4.0, dy: 4.0), byTiling: false)
        }
    })?.withRenderingMode(.alwaysTemplate)
}()

private let tintedTonImage: UIImage? = {
    generateImage(CGSize(width: 32.0, height: 32.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonBig"), color: .white), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size).insetBy(dx: 4.0, dy: 4.0), byTiling: false)
        }
    })?.withRenderingMode(.alwaysTemplate)
}()

private let verificationImage: UIImage? = {
    if let backgroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconBackground"), let foregroundImage = UIImage(bundleImageName: "Peer Info/VerifiedIconForeground") {
        return generateImage(backgroundImage.size, contextGenerator: { size, context in
            let fittedRect = CGRect(origin: .zero, size: size).insetBy(dx: 2.0 + UIScreenPixel, dy: 2.0 + UIScreenPixel)
            if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                context.clear(CGRect(origin: CGPoint(), size: size))
             
                context.saveGState()
                context.clip(to: fittedRect, mask: backgroundCgImage)

                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                context.restoreGState()
                
                context.clip(to: fittedRect, mask: foregroundCgImage)
                context.setBlendMode(.clear)
                context.setFillColor(UIColor.clear.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
            }
        }, opaque: false)?.withRenderingMode(.alwaysTemplate)
    } else {
        return nil
    }
}()
