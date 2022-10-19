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
        
        if let file = file {
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
