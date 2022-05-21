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

private final class InlineStickerItemLayer: SimpleLayer {
    static let queue = Queue()
    
    private let file: TelegramMediaFile
    private let source: AnimatedStickerNodeSource
    private var frameSource: QueueLocalObject<AnimatedStickerDirectFrameSource>?
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    
    private var isInHierarchyValue: Bool = false
    var isVisibleForAnimations: Bool = false {
        didSet {
            self.updatePlayback()
        }
    }
    private var displayLink: ConstantDisplayLinkAnimator?
    
    init(context: AccountContext, file: TelegramMediaFile) {
        self.source = AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: nil, isVideo: false)
        self.file = file
        
        super.init()
        
        let pathPrefix = context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
        let width = Int(24 * UIScreenScale)
        let height = Int(24 * UIScreenScale)
        
        let directDataPath = Atomic<String?>(value: nil)
        let _ = (self.source.directDataPath(attemptSynchronously: true) |> take(1)).start(next: { result in
            let _ = directDataPath.swap(result)
        })
        
        if let directDataPath = directDataPath.with({ $0 }), let directData = try? Data(contentsOf: URL(fileURLWithPath: directDataPath), options: .alwaysMapped) {
            let syncFrameSource = AnimatedStickerDirectFrameSource(queue: .mainQueue(), data: directData, width: width, height: height, cachePathPrefix: pathPrefix, useMetalCache: false, fitzModifier: nil)!
            
            if let animationFrame = syncFrameSource.takeFrame(draw: true) {
                var image: UIImage?
                
                autoreleasepool {
                    image = generateImagePixel(CGSize(width: CGFloat(animationFrame.width), height: CGFloat(animationFrame.height)), scale: 1.0, pixelGenerator: { _, pixelData, contextBytesPerRow in
                        var data = animationFrame.data
                        data.withUnsafeMutableBytes { bytes -> Void in
                            guard let baseAddress = bytes.baseAddress else {
                                return
                            }
                            switch animationFrame.type {
                            case .argb:
                                memcpy(pixelData, baseAddress.assumingMemoryBound(to: UInt8.self), bytes.count)
                            case .yuva:
                                if animationFrame.bytesPerRow <= 0 || animationFrame.height <= 0 || animationFrame.width <= 0 || animationFrame.bytesPerRow * animationFrame.height > bytes.count {
                                    assert(false)
                                    return
                                }
                                decodeYUVAToRGBA(baseAddress.assumingMemoryBound(to: UInt8.self), pixelData, Int32(animationFrame.width), Int32(animationFrame.height), Int32(contextBytesPerRow))
                            default:
                                break
                            }
                        }
                    })
                }
                
                if let image = image {
                    self.contents = image.cgImage
                }
            }
        }
        
        self.disposable = (self.source.directDataPath(attemptSynchronously: false)
        |> filter { $0 != nil }
        |> take(1)
        |> deliverOn(InlineStickerItemLayer.queue)).start(next: { [weak self] path in
            guard let directData = try? Data(contentsOf: URL(fileURLWithPath: path!), options: [.mappedRead]) else {
                return
            }
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.frameSource = QueueLocalObject(queue: InlineStickerItemLayer.queue, generate: {
                    return AnimatedStickerDirectFrameSource(queue: InlineStickerItemLayer.queue, data: directData, width: width, height: height, cachePathPrefix: pathPrefix, useMetalCache: false, fitzModifier: nil)!
                })
                strongSelf.updatePlayback()
            }
        })
        
        self.fetchDisposable = freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file)).start()
    }
    
    override init(layer: Any) {
        guard let layer = layer as? InlineStickerItemLayer else {
            preconditionFailure()
        }
        self.source = layer.source
        self.file = layer.file
        
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
        self.fetchDisposable?.dispose()
    }
    
    override func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchyValue = true
        } else if event == kCAOnOrderOut {
            self.isInHierarchyValue = false
        }
        self.updatePlayback()
        return nullAction
    }
    
    private func updatePlayback() {
        let shouldBePlaying = self.isInHierarchyValue && self.isVisibleForAnimations && self.frameSource != nil
        if shouldBePlaying != (self.displayLink != nil) {
            if shouldBePlaying {
                self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.loadNextFrame()
                })
                self.displayLink?.isPaused = false
            } else {
                self.displayLink?.invalidate()
                self.displayLink = nil
            }
        }
    }
    
    private var didRequestFrame = false
    
    private func loadNextFrame() {
        guard let frameSource = self.frameSource else {
            return
        }
        self.didRequestFrame = true
        frameSource.with { [weak self] impl in
            if let animationFrame = impl.takeFrame(draw: true) {
                var image: UIImage?
                
                autoreleasepool {
                    image = generateImagePixel(CGSize(width: CGFloat(animationFrame.width), height: CGFloat(animationFrame.height)), scale: 1.0, pixelGenerator: { _, pixelData, contextBytesPerRow in
                        var data = animationFrame.data
                        data.withUnsafeMutableBytes { bytes -> Void in
                            guard let baseAddress = bytes.baseAddress else {
                                return
                            }
                            switch animationFrame.type {
                            case .argb:
                                memcpy(pixelData, baseAddress.assumingMemoryBound(to: UInt8.self), bytes.count)
                            case .yuva:
                                if animationFrame.bytesPerRow <= 0 || animationFrame.height <= 0 || animationFrame.width <= 0 || animationFrame.bytesPerRow * animationFrame.height > bytes.count {
                                    assert(false)
                                    return
                                }
                                decodeYUVAToRGBA(baseAddress.assumingMemoryBound(to: UInt8.self), pixelData, Int32(animationFrame.width), Int32(animationFrame.height), Int32(contextBytesPerRow))
                            default:
                                break
                            }
                        }
                    })
                }
                
                if let image = image {
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.contents = image.cgImage
                    }
                }
            }
        }
    }
}

public final class EmojiTextAttachmentView: UIView {
    private let contentLayer: InlineStickerItemLayer
    
    public init(context: AccountContext, file: TelegramMediaFile) {
        self.contentLayer = InlineStickerItemLayer(context: context, file: file)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.contentLayer)
        self.contentLayer.isVisibleForAnimations = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.contentLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -2.0), size: CGSize(width: self.bounds.width - 0.0, height: self.bounds.height + 9.0))
    }
}
