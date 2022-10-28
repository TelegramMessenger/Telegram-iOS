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
        let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        
        let lineOffset = CGPoint(x: title == "B" ? 1.0 : 0.0, y: floorToScreenPixels(realSize.height * 0.05))
        let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (realSize.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floorToScreenPixels(-lineBounds.origin.y + (realSize.height - lineBounds.size.height) / 2.0) + lineOffset.y)
        
        context.translateBy(x: realSize.width / 2.0, y: realSize.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -realSize.width / 2.0, y: -realSize.height / 2.0)
        
        context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
        CTLineDraw(line, context)
        context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    })
}

public enum AnimationCacheAnimationType {
    case still
    case lottie
    case video
}

public extension AnimationCacheAnimationType {
    init(file: TelegramMediaFile) {
        if file.isVideoSticker || file.isVideoEmoji {
            self = .video
        } else if file.isAnimatedSticker {
            self = .lottie
        } else {
            self = .still
        }
    }
}

public func animationCacheFetchFile(context: AccountContext, resource: MediaResourceReference, type: AnimationCacheAnimationType, keyframeOnly: Bool) -> (AnimationCacheFetchOptions) -> Disposable {
    return { options in
        let source = AnimatedStickerResourceSource(account: context.account, resource: resource.resource, fitzModifier: nil, isVideo: false)
        
        let dataDisposable = source.directDataPath(attemptSynchronously: false).start(next: { result in
            guard let result = result else {
                return
            }
            
            switch type {
            case .video:
                cacheVideoAnimation(path: result, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, firstFrameOnly: options.firstFrameOnly)
            case .lottie:
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: result)) else {
                    options.writer.finish()
                    return
                }
                cacheLottieAnimation(data: data, width: Int(options.size.width), height: Int(options.size.height), keyframeOnly: keyframeOnly, writer: options.writer, firstFrameOnly: options.firstFrameOnly)
            case .still:
                cacheStillSticker(path: result, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer)
            }
        })
        
        let fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: resource).start()
        
        return ActionDisposable {
            dataDisposable.dispose()
            fetchDisposable.dispose()
        }
    }
}

public final class InlineStickerItemLayer: MultiAnimationRenderTarget {
    public static let queue = Queue()
    
    public struct Key: Hashable {
        public var id: Int64
        public var index: Int
        
        public init(id: Int64, index: Int) {
            self.id = id
            self.index = index
        }
    }
    
    private let context: AccountContext
    private let emoji: ChatTextInputTextCustomEmojiAttribute
    private let cache: AnimationCache
    private let renderer: MultiAnimationRenderer
    private let unique: Bool
    private let placeholderColor: UIColor
    private let loopCount: Int?
    
    private let pointSize: CGSize
    private let pixelSize: CGSize
    
    private var isDisplayingPlaceholder: Bool = false
    
    public private(set) var file: TelegramMediaFile?
    private var infoDisposable: Disposable?
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    private var loadDisposable: Disposable?
    
    public var contentTintColor: UIColor? {
        didSet {
            if self.contentTintColor != oldValue {
                self.updateTintColor()
            }
        }
    }
    
    private var currentLoopCount: Int = 0
    
    private var isInHierarchyValue: Bool = false
    public var isVisibleForAnimations: Bool = false {
        didSet {
            if self.isVisibleForAnimations != oldValue {
                self.updatePlayback()
            }
        }
    }
    
    public init(context: AccountContext, attemptSynchronousLoad: Bool, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool = false, placeholderColor: UIColor, pointSize: CGSize, loopCount: Int? = nil) {
        self.context = context
        self.emoji = emoji
        self.cache = cache
        self.renderer = renderer
        self.unique = unique
        self.placeholderColor = placeholderColor
        self.loopCount = loopCount
        
        let scale = min(2.0, UIScreenScale)
        self.pointSize = pointSize
        self.pixelSize = CGSize(width: self.pointSize.width * scale, height: self.pointSize.height * scale)
        
        super.init()
        
        if let topicInfo = emoji.topicInfo {
            self.updateTopicInfo(topicInfo: topicInfo)
        } else if let file = file {
            self.updateFile(file: file, attemptSynchronousLoad: attemptSynchronousLoad)
        } else {
            self.infoDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: [emoji.fileId])
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
        preconditionFailure()
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
    
    private func updateTintColor() {
        if !self.isDisplayingPlaceholder {
            self.layerTintColor = self.contentTintColor?.cgColor
        } else {
            self.layerTintColor = nil
        }
    }
    
    private func updatePlayback() {
        var shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations
        
        if shouldBePlaying, let loopCount = self.loopCount, self.currentLoopCount >= loopCount {
            shouldBePlaying = false
        }
        
        if self.shouldBeAnimating != shouldBePlaying {
            self.shouldBeAnimating = shouldBePlaying
            
            if !shouldBePlaying {
                self.currentLoopCount = 0
            }
        }
    }
    
    private func updateTopicInfo(topicInfo: EngineMessageHistoryThread.Info) {
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
        let colors = topicColors[topicInfo.iconColor] ?? generateTopicColors(topicInfo.iconColor)
        
        if let image = generateTopicIcon(title: String(topicInfo.title.prefix(1)), backgroundColors: colors.0.map(UIColor.init(rgb:)), strokeColors: colors.1.map(UIColor.init(rgb:)), size: CGSize(width: 32.0, height: 32.0)) {
            self.contents = image.cgImage
        }
    }
    
    private func updateFile(file: TelegramMediaFile, attemptSynchronousLoad: Bool) {
        if self.file?.fileId == file.fileId {
            return
        }
        
        self.file = file
        
        if attemptSynchronousLoad {
            if !self.renderer.loadFirstFrameSynchronously(target: self, cache: self.cache, itemId: file.resource.id.stringRepresentation, size: self.pixelSize) {
                if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: self.pointSize, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: self.placeholderColor) {
                    self.contents = image.cgImage
                    self.isDisplayingPlaceholder = true
                    self.updateTintColor()
                }
            } else {
                self.updateTintColor()
            }
            
            self.loadAnimation()
        } else {
            let pointSize = self.pointSize
            let placeholderColor = self.placeholderColor
            let isThumbnailCancelled = Atomic<Bool>(value: false)
            self.loadDisposable = self.renderer.loadFirstFrame(target: self, cache: self.cache, itemId: file.resource.id.stringRepresentation, size: self.pixelSize, fetch: animationCacheFetchFile(context: self.context, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: true), completion: { [weak self] result, isFinal in
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
    
    private func loadAnimation() {
        guard let file = self.file else {
            return
        }
        
        let context = self.context
        if file.isAnimatedSticker || file.isVideoEmoji {
            let keyframeOnly = self.pixelSize.width >= 120.0
            
            self.disposable = renderer.add(target: self, cache: self.cache, itemId: file.resource.id.stringRepresentation, unique: self.unique, size: self.pixelSize, fetch: animationCacheFetchFile(context: context, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: keyframeOnly))
        } else {
            self.disposable = renderer.add(target: self, cache: self.cache, itemId: file.resource.id.stringRepresentation, unique: self.unique, size: self.pixelSize, fetch: { options in
                let dataDisposable = context.account.postbox.mediaBox.resourceData(file.resource).start(next: { result in
                    guard result.complete else {
                        return
                    }
                    
                    cacheStillSticker(path: result.path, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer)
                })
                
                let fetchDisposable = freeMediaFileResourceInteractiveFetched(account: context.account, fileReference: .customEmoji(media: file), resource: file.resource).start()
                
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
            self.contents = contents
        }
        
        if didLoop {
            self.currentLoopCount += 1
            if let loopCount = self.loopCount, self.currentLoopCount >= loopCount {
                self.updatePlayback()
            }
        }
    }
}

public final class EmojiTextAttachmentView: UIView {
    private let contentLayer: InlineStickerItemLayer
    
    public init(context: AccountContext, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, placeholderColor: UIColor, pointSize: CGSize) {
        self.contentLayer = InlineStickerItemLayer(context: context, attemptSynchronousLoad: true, emoji: emoji, file: file, cache: cache, renderer: renderer, placeholderColor: placeholderColor, pointSize: pointSize)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.contentLayer.isVisibleForAnimations = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.contentLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.width, height: self.bounds.height))
    }
}
