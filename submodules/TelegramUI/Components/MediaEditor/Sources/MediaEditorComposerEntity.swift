import Foundation
import AVFoundation
import UIKit
import CoreImage
import Metal
import MetalKit
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import YuvConversion
import StickerResources

func composerEntityForDrawingEntity(account: Account, entity: DrawingEntity, colorSpace: CGColorSpace) -> MediaEditorComposerEntity? {
    if let entity = entity as? DrawingStickerEntity {
        let content: MediaEditorComposerStickerEntity.Content
        switch entity.content {
        case let .file(file):
            content = .file(file)
        case let .image(image):
            content = .image(image)
        }
        return MediaEditorComposerStickerEntity(account: account, content: content, position: entity.position, scale: entity.scale, rotation: entity.rotation, baseSize: entity.baseSize, mirrored: entity.mirrored, colorSpace: colorSpace)
    } else if let renderImage = entity.renderImage, let image = CIImage(image: renderImage, options: [.colorSpace: colorSpace]) {
        if let entity = entity as? DrawingBubbleEntity {
            return MediaEditorComposerStaticEntity(image: image, position: entity.position, scale: 1.0, rotation: entity.rotation, baseSize: entity.size, mirrored: false)
        } else if let entity = entity as? DrawingSimpleShapeEntity {
            return MediaEditorComposerStaticEntity(image: image, position: entity.position, scale: 1.0, rotation: entity.rotation, baseSize: entity.size, mirrored: false)
        } else if let entity = entity as? DrawingVectorEntity {
            return MediaEditorComposerStaticEntity(image: image, position: CGPoint(x: entity.drawingSize.width * 0.5, y: entity.drawingSize.height * 0.5), scale: 1.0, rotation: 0.0, baseSize: entity.drawingSize, mirrored: false)
        } else if let entity = entity as? DrawingTextEntity {
            return MediaEditorComposerStaticEntity(image: image, position: entity.position, scale: entity.scale, rotation: entity.rotation, baseSize: nil, mirrored: false)
        }
    }
    return nil
}

private class MediaEditorComposerStaticEntity: MediaEditorComposerEntity {
    let image: CIImage
    let position: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let baseSize: CGSize?
    let mirrored: Bool
    
    init(image: CIImage, position: CGPoint, scale: CGFloat, rotation: CGFloat, baseSize: CGSize?, mirrored: Bool) {
        self.image = image
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.baseSize = baseSize
        self.mirrored = mirrored
    }
    
    func image(for time: CMTime, frameRate: Float, completion: @escaping (CIImage?) -> Void) {
        completion(self.image)
    }
}

private class MediaEditorComposerStickerEntity: MediaEditorComposerEntity {
    public enum Content {
        case file(TelegramMediaFile)
        case image(UIImage)
        
        var file: TelegramMediaFile? {
            if case let .file(file) = self {
                return file
            }
            return nil
        }
    }
    
    let content: Content
    let position: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let baseSize: CGSize?
    let mirrored: Bool
    let colorSpace: CGColorSpace
    
    var isAnimated: Bool
    var source: AnimatedStickerNodeSource?
    var frameSource = Promise<QueueLocalObject<AnimatedStickerDirectFrameSource>?>()
    var videoFrameSource = Promise<QueueLocalObject<VideoStickerDirectFrameSource>?>()
    var isVideo = false
    
    var frameCount: Int?
    var frameRate: Int?
    var currentFrameIndex: Int?
    var totalDuration: Double?
    let durationPromise = Promise<Double>()
    
    let queue = Queue()
    let disposables = DisposableSet()
    
    var image: CIImage?
    var imagePixelBuffer: CVPixelBuffer?
    let imagePromise = Promise<UIImage>()
    
    init(account: Account, content: Content, position: CGPoint, scale: CGFloat, rotation: CGFloat, baseSize: CGSize, mirrored: Bool, colorSpace: CGColorSpace) {
        self.content = content
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.baseSize = baseSize
        self.mirrored = mirrored
        self.colorSpace = colorSpace
        
        switch content {
        case let .file(file):
            if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                self.isAnimated = true
                self.isVideo = file.isVideoSticker || file.mimeType == "video/webm"
                
                self.source = AnimatedStickerResourceSource(account: account, resource: file.resource, isVideo: isVideo)
                let pathPrefix = account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                if let source = self.source {
                    let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384, height: 384))
                    self.disposables.add((source.directDataPath(attemptSynchronously: true)
                    |> deliverOn(self.queue)).start(next: { [weak self] path in
                        if let strongSelf = self, let path {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                let queue = strongSelf.queue
                                
                                if strongSelf.isVideo {
                                    let frameSource = QueueLocalObject<VideoStickerDirectFrameSource>(queue: queue, generate: {
                                        return VideoStickerDirectFrameSource(queue: queue, path: path, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), cachePathPrefix: pathPrefix, unpremultiplyAlpha: false)!
                                    })
                                    frameSource.syncWith { frameSource in
                                        strongSelf.frameCount = frameSource.frameCount
                                        strongSelf.frameRate = frameSource.frameRate
                                        
                                        let duration = Double(frameSource.frameCount) / Double(frameSource.frameRate)
                                        strongSelf.totalDuration = duration
                                        strongSelf.durationPromise.set(.single(duration))
                                    }
                                    
                                    strongSelf.videoFrameSource.set(.single(frameSource))
                                } else {
                                    let frameSource = QueueLocalObject<AnimatedStickerDirectFrameSource>(queue: queue, generate: {
                                        return AnimatedStickerDirectFrameSource(queue: queue, data: data, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), cachePathPrefix: pathPrefix, useMetalCache: false, fitzModifier: nil)!
                                    })
                                    frameSource.syncWith { frameSource in
                                        strongSelf.frameCount = frameSource.frameCount
                                        strongSelf.frameRate = frameSource.frameRate
                                        
                                        let duration = Double(frameSource.frameCount) / Double(frameSource.frameRate)
                                        strongSelf.totalDuration = duration
                                        strongSelf.durationPromise.set(.single(duration))
                                    }
                                    
                                    strongSelf.frameSource.set(.single(frameSource))
                                }
                            }
                        }
                    }))
                }
            } else {
                self.isAnimated = false
                self.disposables.add((chatMessageSticker(account: account, userLocation: .other, file: file, small: false, fetched: true, onlyFullSize: true, thumbnail: false, synchronousLoad: false, colorSpace: self.colorSpace)
                |> deliverOn(self.queue)).start(next: { [weak self] generator in
                    if let self {
                        let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: baseSize, boundingSize: baseSize, intrinsicInsets: UIEdgeInsets()))
                        let image = context?.generateImage(colorSpace: self.colorSpace)
                        if let image {
                            self.imagePromise.set(.single(image))
                        }
                    }
                }))
            }
        case let .image(image):
            self.isAnimated = false
            self.imagePromise.set(.single(image))
        }
    }
    
    deinit {
        self.disposables.dispose()
    }
    
    var tested = false
    func image(for time: CMTime, frameRate: Float, completion: @escaping (CIImage?) -> Void) {
        if self.isAnimated {
            let currentTime = CMTimeGetSeconds(time)
            
            var tintColor: UIColor?
            if let file = self.content.file, file.isCustomTemplateEmoji {
                tintColor = .white
            }
            
            self.disposables.add((self.frameSource.get()
            |> take(1)
            |> deliverOn(self.queue)).start(next: { [weak self] frameSource in
                guard let strongSelf = self else {
                    completion(nil)
                    return
                }
                
                guard let frameSource, let duration = strongSelf.totalDuration, let frameCount = strongSelf.frameCount else {
                    completion(nil)
                    return
                }
                                                
                let relativeTime = currentTime - floor(currentTime / duration) * duration
                var t = relativeTime / duration
                t = max(0.0, t)
                t = min(1.0, t)
                
                let startFrame: Double = 0
                let endFrame = Double(frameCount)
                
                let frameOffset = Int(Double(startFrame) * (1.0 - t) + Double(endFrame - 1) * t)
                let lowerBound: Int = 0
                let upperBound = frameCount - 1
                let frameIndex = max(lowerBound, min(upperBound, frameOffset))
                
                let currentFrameIndex = strongSelf.currentFrameIndex
                if currentFrameIndex != frameIndex {
                    let previousFrameIndex = currentFrameIndex
                    strongSelf.currentFrameIndex = frameIndex
                    
                    var delta = 1
                    if let previousFrameIndex = previousFrameIndex {
                        delta = max(1, frameIndex - previousFrameIndex)
                    }
                    
                    var frame: AnimatedStickerFrame?
                    frameSource.syncWith { frameSource in
                        for i in 0 ..< delta {
                            frame = frameSource.takeFrame(draw: i == delta - 1)
                        }
                    }
                    if let frame {
                        var imagePixelBuffer: CVPixelBuffer?
                        if let pixelBuffer = strongSelf.imagePixelBuffer {
                            imagePixelBuffer = pixelBuffer
                        } else {
                            let ioSurfaceProperties = NSMutableDictionary()
                            let options = NSMutableDictionary()
                            options.setObject(ioSurfaceProperties, forKey: kCVPixelBufferIOSurfacePropertiesKey as NSString)
                            
                            var pixelBuffer: CVPixelBuffer?
                            CVPixelBufferCreate(
                                kCFAllocatorDefault,
                                frame.width,
                                frame.height,
                                kCVPixelFormatType_32BGRA,
                                options,
                                &pixelBuffer
                            )
                            
                            imagePixelBuffer = pixelBuffer
                            strongSelf.imagePixelBuffer = pixelBuffer
                        }
                        
                        if let imagePixelBuffer {
                            let image = render(width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, pixelBuffer: imagePixelBuffer, colorSpace: strongSelf.colorSpace, tintColor: tintColor)
                            strongSelf.image = image
                        }
                        completion(strongSelf.image)
                    } else {
                        completion(nil)
                    }
                } else {
                    completion(strongSelf.image)
                }
            }))
        } else {
            var image: CIImage?
            if let cachedImage = self.image {
                image = cachedImage
                completion(image)
            } else {
                let _ = (self.imagePromise.get()
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] image in
                    if let self {
                        self.image = CIImage(image: image, options: [.colorSpace: self.colorSpace])
                        completion(self.image)
                    }
                })
            }
        }
    }
}

protocol MediaEditorComposerEntity {
    var position: CGPoint { get }
    var scale: CGFloat { get }
    var rotation: CGFloat { get }
    var baseSize: CGSize? { get }
    var mirrored: Bool { get }
    
    func image(for time: CMTime, frameRate: Float, completion: @escaping (CIImage?) -> Void)
}

private func render(width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, pixelBuffer: CVPixelBuffer, colorSpace: CGColorSpace, tintColor: UIColor?) -> CIImage? {
    //let calculatedBytesPerRow = (4 * Int(width) + 31) & (~31)
    //assert(bytesPerRow == calculatedBytesPerRow)
    
    
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let dest = CVPixelBufferGetBaseAddress(pixelBuffer)
    
    switch type {
        case .yuva:
            data.withUnsafeBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                decodeYUVAToRGBA(bytes, dest, Int32(width), Int32(height), Int32(width * 4))
            }
        case .argb:
            data.withUnsafeBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                memcpy(dest, bytes, data.count)
            }
        case .dct:
            break
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    return CIImage(cvPixelBuffer: pixelBuffer, options: [.colorSpace: colorSpace])
}
