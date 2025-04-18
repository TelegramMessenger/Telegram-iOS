import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore
import Postbox
import SwiftSignalKit
import MultiAnimationRenderer
import AnimationCache
import AccountContext
import TelegramUIPreferences
import GenerateStickerPlaceholderImage
import EmojiTextAttachmentView
import LottieAnimationCache

public final class InlineFileIconLayer: MultiAnimationRenderTarget {
    private final class Arguments {
        let context: InlineFileIconLayer.Context
        let userLocation: MediaResourceUserLocation
        let file: TelegramMediaFile
        let cache: AnimationCache
        let renderer: MultiAnimationRenderer
        let unique: Bool
        let placeholderColor: UIColor
        
        let pointSize: CGSize
        let pixelSize: CGSize
        
        init(context: InlineFileIconLayer.Context, userLocation: MediaResourceUserLocation, file: TelegramMediaFile, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool, placeholderColor: UIColor, pointSize: CGSize, pixelSize: CGSize) {
            self.context = context
            self.userLocation = userLocation
            self.file = file
            self.cache = cache
            self.renderer = renderer
            self.unique = unique
            self.placeholderColor = placeholderColor
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
            }
        }
    }
    
    private var currentLoopCount: Int = 0
    
    private var isInHierarchyValue: Bool = false
    
    public convenience init(
        context: AccountContext,
        userLocation: MediaResourceUserLocation,
        attemptSynchronousLoad: Bool,
        file: TelegramMediaFile,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        unique: Bool = false,
        placeholderColor: UIColor,
        pointSize: CGSize,
        dynamicColor: UIColor? = nil
    ) {
        self.init(
            context: .account(context),
            userLocation: userLocation,
            attemptSynchronousLoad: attemptSynchronousLoad,
            file: file,
            cache: cache,
            renderer: renderer,
            unique: unique,
            placeholderColor: placeholderColor,
            pointSize: pointSize,
            dynamicColor: dynamicColor
        )
    }
    
    public init(
        context: InlineFileIconLayer.Context,
        userLocation: MediaResourceUserLocation,
        attemptSynchronousLoad: Bool,
        file: TelegramMediaFile,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        unique: Bool = false,
        placeholderColor: UIColor,
        pointSize: CGSize,
        dynamicColor: UIColor? = nil
    ) {
        let scale = min(2.0, UIScreenScale)
        
        self.arguments = Arguments(
            context: context,
            userLocation: userLocation,
            file: file,
            cache: cache,
            renderer: renderer,
            unique: unique,
            placeholderColor: placeholderColor,
            pointSize: pointSize,
            pixelSize: CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        )
        
        self._dynamicColor = dynamicColor
        
        super.init()
        
        self.updateFile(file: file, attemptSynchronousLoad: attemptSynchronousLoad)
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
        } else if event == kCAOnOrderOut {
            self.isInHierarchyValue = false
        }
        return nullAction
    }
    
    private func updateFile(file: TelegramMediaFile, attemptSynchronousLoad: Bool) {
        guard let arguments = self.arguments else {
            return
        }
        
        if self.file?.fileId == file.fileId {
            return
        }
        
        self.file = file
        
        if attemptSynchronousLoad {
            if !arguments.renderer.loadFirstFrameSynchronously(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, size: arguments.pixelSize) {
                if let image = generateStickerPlaceholderImage(data: file.immediateThumbnailData, size: arguments.pointSize, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: arguments.placeholderColor) {
                    self.contents = image.cgImage
                    self.isDisplayingPlaceholder = true
                }
            }
            
            self.loadAnimation()
        } else {
            let isTemplate = file.isCustomTemplateEmoji
            
            let pointSize = arguments.pointSize
            let placeholderColor = arguments.placeholderColor
            let isThumbnailCancelled = Atomic<Bool>(value: false)
            self.loadDisposable = arguments.renderer.loadFirstFrame(
                target: self,
                cache: arguments.cache,
                itemId: file.resource.id.stringRepresentation,
                size: arguments.pixelSize,
                fetch: animationCacheFetchFile(postbox: arguments.context.postbox, userLocation: arguments.userLocation, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: true, customColor: isTemplate ? .white : nil), completion: { [weak self] result, isFinal in
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
        /*guard let arguments = self.arguments else {
            return
        }
        
        guard let file = self.file else {
            return
        }
        
        let isTemplate = file.isCustomTemplateEmoji
        
        let context = arguments.context
        if file.isAnimatedSticker || file.isVideoSticker || file.isVideoEmoji {
            let keyframeOnly = arguments.pixelSize.width >= 120.0
            
            self.disposable = arguments.renderer.add(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, unique: arguments.unique, size: arguments.pixelSize, fetch: animationCacheFetchFile(postbox: arguments.context.postbox, userLocation: arguments.userLocation, userContentType: .sticker, resource: .media(media: .standalone(media: file), resource: file.resource), type: AnimationCacheAnimationType(file: file), keyframeOnly: keyframeOnly, customColor: isTemplate ? .white : nil))
        } else {
            self.disposable = arguments.renderer.add(target: self, cache: arguments.cache, itemId: file.resource.id.stringRepresentation, unique: arguments.unique, size: arguments.pixelSize, fetch: { options in
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
        }*/
    }
    
    override public func updateDisplayPlaceholder(displayPlaceholder: Bool) {
        if self.isDisplayingPlaceholder == displayPlaceholder {
            return
        }
        self.isDisplayingPlaceholder = displayPlaceholder
    }
    
    override public func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
        if self.isDisplayingPlaceholder {
            self.isDisplayingPlaceholder = false
            
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
    }
}
