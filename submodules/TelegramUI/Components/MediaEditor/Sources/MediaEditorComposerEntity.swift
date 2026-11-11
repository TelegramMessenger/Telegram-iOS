import Foundation
import AVFoundation
import UIKit
import Metal
import MetalKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import YuvConversion
import StickerResources

private func prerenderTextTransformations(entity: DrawingEntity, image: UIImage, textScale: CGFloat, colorSpace: CGColorSpace) -> MediaEditorComposerStaticEntity {
    let imageSize = image.size
    
    let angle: CGFloat
    var scale: CGFloat
    let position: CGPoint
    
    if let entity = entity as? DrawingTextEntity {
        angle = -entity.rotation
        scale = entity.scale
        position = entity.position
    } else if let entity = entity as? DrawingLocationEntity {
        angle = -entity.rotation
        scale = entity.scale
        position = entity.position
    } else if let entity = entity as? DrawingWeatherEntity {
        angle = -entity.rotation
        scale = entity.scale
        position = entity.position
    } else if let entity = entity as? DrawingLinkEntity {
        angle = -entity.rotation
        scale = entity.scale
        position = entity.position
    } else {
        fatalError()
    }
    scale *= 0.5 * textScale
    
    let rotatedSize = CGSize(
        width: abs(imageSize.width * cos(angle)) + abs(imageSize.height * sin(angle)),
        height: abs(imageSize.width * sin(angle)) + abs(imageSize.height * cos(angle))
    )
    let newSize = CGSize(width: rotatedSize.width * scale, height: rotatedSize.height * scale)

    let newImage = generateImage(newSize, contextGenerator: { size, context in
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        context.clear(CGRect(origin: .zero, size: size))
        context.translateBy(x: newSize.width * 0.5, y: newSize.height * 0.5)
        context.rotate(by: angle)
        context.scaleBy(x: scale, y: scale)
        let drawRect = CGRect(
            x: -imageSize.width * 0.5,
            y: -imageSize.height * 0.5,
            width: imageSize.width,
            height: imageSize.height
        )
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: drawRect)
        }
    }, scale: 1.0)!
    
    return MediaEditorComposerStaticEntity(image: composerEntityImage(newImage, colorSpace: colorSpace)!, position: position, scale: 1.0, rotation: 0.0, baseSize: nil, baseDrawingSize: CGSize(width: 1080, height: 1920), mirrored: false)
}

func mediaEditorAnimatedStickerDurations(postbox: Postbox, entities: [DrawingEntity]) -> Signal<[Double], NoError> {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    return mediaEditorAnimatedStickerDurations(entities: entities, fileDuration: { file in
        return Signal { subscriber in
            let composerEntity = MediaEditorComposerStickerEntity(postbox: postbox, content: .file(file), position: .zero, scale: 1.0, rotation: 0.0, baseSize: CGSize(width: 512.0, height: 512.0), mirrored: false, colorSpace: colorSpace, tintColor: nil, isStatic: false)
            let disposable = (composerEntity.durationPromise.get()
            |> take(1)).start(next: { duration in
                subscriber.putNext(duration)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposable.dispose()
                let _ = composerEntity
            }
        }
        |> timeout(10.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
    })
}

func mediaEditorAnimatedStickerDurations(entities: [DrawingEntity], fileDuration: @escaping (TelegramMediaFile) -> Signal<Double?, NoError>) -> Signal<[Double], NoError> {
    var stickerEntities: [DrawingStickerEntity] = []
    for entity in entities {
        if let sticker = entity as? DrawingStickerEntity {
            stickerEntities.append(sticker)
        } else if let text = entity as? DrawingTextEntity, let renderSubEntities = text.renderSubEntities {
            stickerEntities.append(contentsOf: renderSubEntities.compactMap { $0 as? DrawingStickerEntity })
        }
    }
    var signals: [Signal<Double?, NoError>] = []
    for sticker in stickerEntities where sticker.isAnimated {
        switch sticker.content {
        case let .file(file, _):
            signals.append(fileDuration(file.media))
        case let .animatedImage(data, _):
            signals.append(Signal { subscriber in
                subscriber.putNext(UIImage.animatedImageFromData(data: data)?.duration)
                subscriber.putCompletion()
                return EmptyDisposable
            })
        default:
            break
        }
    }
    return combineLatest(signals)
    |> map { durations -> [Double] in
        return durations.compactMap { $0 }
    }
}

func composerEntitiesForDrawingEntity(postbox: Postbox, textScale: CGFloat, entity: DrawingEntity, colorSpace: CGColorSpace, tintColor: UIColor? = nil) -> [MediaEditorComposerEntity] {
    if entity is DrawingWeatherEntity {
        return []
    } else if let entity = entity as? DrawingStickerEntity {
        if case let .file(_, type) = entity.content, case .reaction = type {
            return []
        } else {
            let content: MediaEditorComposerStickerEntity.Content
            var scale = entity.scale
            switch entity.content {
            case let .file(file, _):
                content = .file(file.media)
            case let .image(image, _):
                content = .image(image)
            case let .animatedImage(data, _):
                if let animatedImage = UIImage.animatedImageFromData(data: data) {
                    content = .animatedImage(animatedImage.images, animatedImage.duration)
                    scale *= 1.0
                } else {
                    return []
                }
            case let .video(file):
                content = .video(file)
            case .dualVideoReference:
                return []
            case .message, .gift:
                if let renderImage = entity.renderImage, let image = composerEntityImage(renderImage, colorSpace: colorSpace) {
                    var entities: [MediaEditorComposerEntity] = []
                    entities.append(MediaEditorComposerStaticEntity(image: image, position: entity.position, scale: entity.scale, rotation: entity.rotation, baseSize: entity.baseSize, mirrored: false))
                    if let renderSubEntities = entity.renderSubEntities {
                        for subEntity in renderSubEntities {
                            entities.append(contentsOf: composerEntitiesForDrawingEntity(postbox: postbox, textScale: textScale, entity: subEntity, colorSpace: colorSpace))
                        }
                    }
                    return entities
                } else {
                    return []
                }
            }
            return [MediaEditorComposerStickerEntity(postbox: postbox, content: content, position: entity.position, scale: scale, rotation: entity.rotation, baseSize: entity.baseSize, mirrored: entity.mirrored, colorSpace: colorSpace, tintColor: tintColor, isStatic: entity.isExplicitlyStatic)]
        }
    } else if let renderImage = entity.renderImage, let image = composerEntityImage(renderImage, colorSpace: colorSpace) {
        if let entity = entity as? DrawingBubbleEntity {
            return [MediaEditorComposerStaticEntity(image: image, position: entity.position, scale: 1.0, rotation: entity.rotation, baseSize: entity.size, mirrored: false)]
        } else if let entity = entity as? DrawingSimpleShapeEntity {
            return [MediaEditorComposerStaticEntity(image: image, position: entity.position, scale: 1.0, rotation: entity.rotation, baseSize: entity.size, mirrored: false)]
        } else if let entity = entity as? DrawingVectorEntity {
            return [MediaEditorComposerStaticEntity(image: image, position: CGPoint(x: entity.drawingSize.width * 0.5, y: entity.drawingSize.height * 0.5), scale: 1.0, rotation: 0.0, baseSize: entity.drawingSize, mirrored: false)]
        } else if let entity = entity as? DrawingTextEntity {
            var entities: [MediaEditorComposerEntity] = []
            entities.append(prerenderTextTransformations(entity: entity, image: renderImage, textScale: textScale, colorSpace: colorSpace))
            if let renderSubEntities = entity.renderSubEntities {
                for subEntity in renderSubEntities {
                    entities.append(contentsOf: composerEntitiesForDrawingEntity(postbox: postbox, textScale: textScale, entity: subEntity, colorSpace: colorSpace, tintColor: entity.color.toUIColor()))
                }
            }
            return entities
        } else if let entity = entity as? DrawingLocationEntity {
            return [prerenderTextTransformations(entity: entity, image: renderImage, textScale: textScale, colorSpace: colorSpace)]
        } else if let entity = entity as? DrawingLinkEntity {
            return [prerenderTextTransformations(entity: entity, image: renderImage, textScale: textScale, colorSpace: colorSpace)]
        } else if let entity = entity as? DrawingWeatherEntity {
            return [prerenderTextTransformations(entity: entity, image: renderImage, textScale: textScale, colorSpace: colorSpace)]
        }
    }
    return []
}

private func composerEntityImage(_ image: UIImage, colorSpace: CGColorSpace) -> CGImage? {
    guard let cgImage = image.cgImage else {
        return nil
    }
    return cgImage.copy(colorSpace: colorSpace) ?? cgImage
}

private class MediaEditorComposerStaticEntity: MediaEditorComposerEntity {
    let frame: MediaEditorComposerEntityFrame
    let position: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let baseSize: CGSize?
    let baseScale: CGFloat?
    let baseDrawingSize: CGSize?
    let mirrored: Bool
    
    init(
        image: CGImage,
        position: CGPoint,
        scale: CGFloat,
        rotation: CGFloat,
        baseSize: CGSize?,
        baseScale: CGFloat? = nil,
        baseDrawingSize: CGSize? = nil,
        mirrored: Bool
    ) {
        self.frame = MediaEditorComposerEntityFrame(content: .image(image), alphaMask: nil)
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.baseSize = baseSize
        self.baseScale = baseScale
        self.baseDrawingSize = baseDrawingSize
        self.mirrored = mirrored
    }
    
    func frame(for time: CMTime, frameRate: Float, completion: @escaping (MediaEditorComposerEntityFrame?) -> Void) {
        completion(self.frame)
    }
}

final class MediaEditorComposerStickerEntity: MediaEditorComposerEntity {
    public enum Content {
        case file(TelegramMediaFile)
        case video(TelegramMediaFile)
        case image(UIImage)
        case animatedImage([UIImage], Double)
        
        var file: TelegramMediaFile? {
            if case let .file(file) = self {
                return file
            }
            return nil
        }
    }
    
    let postbox: Postbox
    let content: Content
    let position: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let baseSize: CGSize?
    let baseScale: CGFloat? = nil
    let baseDrawingSize: CGSize? = nil
    let mirrored: Bool
    let colorSpace: CGColorSpace
    let tintColor: UIColor?
    let isStatic: Bool
    
    var isAnimated: Bool
    var source: AnimatedStickerNodeSource?
    var frameSource = Promise<QueueLocalObject<AnimatedStickerDirectFrameSource>?>()
    var videoFrameSource = Promise<QueueLocalObject<VideoStickerDirectFrameSource>?>()
    var isVideoSticker = false
    
    var assetReader: AVAssetReader?
    var videoOutput: AVAssetReaderTrackOutput?
    
    var frameCount: Int?
    var frameRate: Int?
    var currentFrameIndex: Int?
    var totalDuration: Double?
    let durationPromise = Promise<Double>()
    
    let queue = Queue()
    let disposables = DisposableSet()
    
    var frame: MediaEditorComposerEntityFrame?
    var imagePixelBuffer: CVPixelBuffer?
    let imagePromise = Promise<UIImage>()
    
    init(postbox: Postbox, content: Content, position: CGPoint, scale: CGFloat, rotation: CGFloat, baseSize: CGSize, mirrored: Bool, colorSpace: CGColorSpace, tintColor: UIColor?, isStatic: Bool, highRes: Bool = false) {
        self.postbox = postbox
        self.content = content
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.baseSize = baseSize
        self.mirrored = mirrored
        self.colorSpace = colorSpace
        self.tintColor = tintColor
        self.isStatic = isStatic
        
        switch content {
        case let .file(file):
            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
            if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                self.isAnimated = true
                self.isVideoSticker = file.isVideoSticker || file.mimeType == "video/webm"
                
                self.source = AnimatedStickerResourceSource(postbox: postbox, resource: file.resource, isVideo: isVideoSticker)
                let pathPrefix = postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                if let source = self.source {
                    let fitToSize: CGSize
                    if highRes {
                        fitToSize = CGSize(width: 512, height: 512)
                    } else if self.isStatic {
                        fitToSize = CGSize(width: 768, height: 768)
                    } else {
                        fitToSize = CGSize(width: 384, height: 384)
                    }
                    let fittedDimensions = dimensions.cgSize.aspectFitted(fitToSize)
                    self.disposables.add((source.directDataPath(attemptSynchronously: true)
                    |> deliverOn(self.queue)).start(next: { [weak self] path in
                        if let strongSelf = self, let path {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                let queue = strongSelf.queue
                                
                                if strongSelf.isVideoSticker {
                                    let frameSource = QueueLocalObject<VideoStickerDirectFrameSource>(queue: queue, generate: {
                                        return VideoStickerDirectFrameSource(queue: queue, path: path, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), cachePathPrefix: pathPrefix, unpremultiplyAlpha: false)!
                                    })
                                    frameSource.syncWith { frameSource in
                                        strongSelf.frameCount = frameSource.frameCount
                                        strongSelf.frameRate = frameSource.frameRate
                                            
                                        let duration: Double
                                        if frameSource.frameCount > 0 {
                                            duration = Double(frameSource.frameCount) / Double(frameSource.frameRate)
                                        } else {
                                            duration = frameSource.duration
                                        }
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
                self.disposables.add((chatMessageSticker(postbox: postbox, userLocation: .other, file: file, small: false, fetched: true, onlyFullSize: true, thumbnail: false, synchronousLoad: false, colorSpace: self.colorSpace)
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
        case let .animatedImage(images, duration):
            self.isAnimated = true
            self.videoFrameRate = Float(images.count) / Float(duration)
            self.totalDuration = duration
            self.durationPromise.set(.single(duration))
        case .video:
            self.isAnimated = true
        }
    }
    
    deinit {
        self.disposables.dispose()
    }
    
    private func setupVideoOutput() {
        if case let .video(file) = self.content {
            if let path = self.postbox.mediaBox.completedResourcePath(file.resource, pathExtension: "mp4") {
                let url = URL(fileURLWithPath: path)
                let asset = AVURLAsset(url: url)
                
                if let assetReader = try? AVAssetReader(asset: asset), let videoTrack = asset.tracks(withMediaType: .video).first {
                    self.videoFrameRate = videoTrack.nominalFrameRate
                    let outputSettings: [String: Any]  = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                        kCVPixelBufferMetalCompatibilityKey as String: true
                    ]
                    let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
                    videoOutput.alwaysCopiesSampleData = true
                    if assetReader.canAdd(videoOutput) {
                        assetReader.add(videoOutput)
                    }
                    
                    assetReader.startReading()
                    self.assetReader = assetReader
                    self.videoOutput = videoOutput
                }
            }
        }
    }
    
    private var videoFrameRate: Float?
    private var videoAlphaMask: CGImage?
    func frame(for time: CMTime, frameRate: Float, completion: @escaping (MediaEditorComposerEntityFrame?) -> Void) {
        let currentTime = CMTimeGetSeconds(time)
        
        if case let .animatedImage(images, _) = self.content {
            var frameAdvancement: Int = 0
            if let frameRate = self.videoFrameRate, frameRate > 0 {
                let frameTime = 1.0 / Double(frameRate)
                let frameIndex = Int(floor(currentTime / frameTime))
                
                let currentFrameIndex = self.currentFrameIndex
                if currentFrameIndex != frameIndex {
                    let previousFrameIndex = currentFrameIndex
                    self.currentFrameIndex = frameIndex
                    
                    var delta = 1
                    if let previousFrameIndex = previousFrameIndex {
                        delta = max(1, frameIndex - previousFrameIndex)
                    }
                    frameAdvancement = delta
                }
            }
            if frameAdvancement == 0, let frame = self.frame {
                completion(frame)
                return
            } else if let currentFrameIndex = self.currentFrameIndex {
                let index = currentFrameIndex % images.count
                var image = images[index]
                image = generateScaledImage(image: images[index], size: image.size.aspectFitted(CGSize(width: 384, height: 384)), opaque: false, scale: 1.0)!
                let frame = image.cgImage.flatMap { MediaEditorComposerEntityFrame(content: .image($0), alphaMask: nil) }
                self.frame = frame
                completion(frame)
                return
            }
            // Neither branch applied — no frame rate has been resolved yet and nothing is cached.
            // The caller counts completions to finish the frame, so it has to hear about this.
            completion(self.frame)
            return
        } else if case .video = self.content {
            if self.videoOutput == nil {
                self.setupVideoOutput()
            }
            if let videoOutput = self.videoOutput {
                var frameAdvancement: Int = 0
                if let frameRate = self.videoFrameRate, frameRate > 0 {
                    let frameTime = 1.0 / Double(frameRate)
                    let frameIndex = Int(floor(currentTime / frameTime))
                    
                    let currentFrameIndex = self.currentFrameIndex
                    if currentFrameIndex != frameIndex {
                        let previousFrameIndex = currentFrameIndex
                        self.currentFrameIndex = frameIndex
                        
                        var delta = 1
                        if let previousFrameIndex = previousFrameIndex {
                            delta = max(1, frameIndex - previousFrameIndex)
                        }
                        frameAdvancement = delta
                    }
                }
                
                if frameAdvancement == 0, let frame = self.frame {
                    completion(frame)
                    return
                } else {
                    var sampleBuffer = videoOutput.copyNextSampleBuffer()
                    if sampleBuffer == nil && self.assetReader?.status == .completed {
                        self.setupVideoOutput()
                        sampleBuffer = self.videoOutput?.copyNextSampleBuffer()
                    }
                    
                    if let sampleBuffer, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        if self.videoAlphaMask == nil {
                            let size = CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
                            let circleImage = generateImage(size, scale: 1.0, rotatedContext: { size, context in
                                context.clear(CGRect(origin: .zero, size: size))
                                context.setFillColor(UIColor.white.cgColor)
                                
                                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: floor(size.width * 0.03))
                                context.addPath(path.cgPath)
                                context.fillPath()
                            })!
                            self.videoAlphaMask = circleImage.cgImage
                        }
                        
                        let frame = MediaEditorComposerEntityFrame(content: .pixelBuffer(imageBuffer), alphaMask: self.videoAlphaMask)
                        self.frame = frame
                        completion(frame)
                    } else {
                        // Reader produced nothing and is not simply at its end. Reuse the last
                        // frame rather than dropping the entity, matching `processFrame` below.
                        completion(self.frame)
                    }
                }
            } else {
                completion(nil)
            }
        } else if self.isAnimated {
            var tintColor: UIColor?
            if let file = self.content.file, file.isCustomTemplateEmoji {
                tintColor = self.tintColor ?? UIColor(rgb: 0xffffff)
            }
            
            let processFrame: (Double?, Int?, Int?, (Int) -> AnimatedStickerFrame?) -> Void = { [weak self] duration, frameCount, frameRate, takeFrame in
                guard let strongSelf = self else {
                    completion(nil)
                    return
                }
                var frameAdvancement: Int = 0
                if let duration, let frameCount, frameCount > 0 {
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
                        frameAdvancement = delta
                    }
                } else if let frameRate, frameRate > 0 {
                    let frameTime = 1.0 / Double(frameRate)
                    let frameIndex = Int(floor(currentTime / frameTime))
                    
                    let currentFrameIndex = strongSelf.currentFrameIndex
                    if currentFrameIndex != frameIndex {
                        let previousFrameIndex = currentFrameIndex
                        strongSelf.currentFrameIndex = frameIndex
                        
                        var delta = 1
                        if let previousFrameIndex = previousFrameIndex {
                            delta = max(1, frameIndex - previousFrameIndex)
                        }
                        frameAdvancement = delta
                    }
                }
                
                if frameAdvancement == 0, let frame = strongSelf.frame {
                    completion(frame)
                } else {
                    if let frame = takeFrame(max(1, frameAdvancement)) {
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
                            
                            if let pixelBuffer {
                                CVBufferSetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, deviceColorSpace, .shouldPropagate)
                            }
                            imagePixelBuffer = pixelBuffer
                            strongSelf.imagePixelBuffer = pixelBuffer
                        }
                        
                        if let imagePixelBuffer {
                            strongSelf.frame = render(width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, pixelBuffer: imagePixelBuffer, tintColor: tintColor)
                        }
                        completion(strongSelf.frame)
                    } else {
                        completion(strongSelf.frame)
                    }
                }
            }
            
            if self.isVideoSticker {
                self.disposables.add((self.videoFrameSource.get()
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] frameSource in
                    guard let strongSelf = self else {
                        completion(nil)
                        return
                    }
                    
                    guard let frameSource else {
                        completion(nil)
                        return
                    }
                    
                    processFrame(strongSelf.totalDuration, strongSelf.frameCount, strongSelf.frameRate, { delta in
                        var frame: AnimatedStickerFrame?
                        frameSource.syncWith { frameSource in
                            for i in 0 ..< delta {
                                frame = frameSource.takeFrame(draw: i == delta - 1)
                            }
                        }
                        return frame
                    })
                }))
            } else {
                self.disposables.add((self.frameSource.get()
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] frameSource in
                    guard let strongSelf = self else {
                        completion(nil)
                        return
                    }
                    
                    guard let frameSource else {
                        completion(nil)
                        return
                    }
                    
                    processFrame(strongSelf.totalDuration, strongSelf.frameCount, strongSelf.frameRate, { delta in
                        var frame: AnimatedStickerFrame?
                        frameSource.syncWith { frameSource in
                            for i in 0 ..< delta {
                                frame = frameSource.takeFrame(draw: i == delta - 1)
                            }
                        }
                        return frame
                    })
                }))
            }
        } else {
            if let frame = self.frame {
                completion(frame)
            } else {
                let _ = (self.imagePromise.get()
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] image in
                    guard let self else {
                        completion(nil)
                        return
                    }
                    self.frame = composerEntityImage(image, colorSpace: self.colorSpace).flatMap { MediaEditorComposerEntityFrame(content: .image($0), alphaMask: nil) }
                    completion(self.frame)
                })
            }
        }
    }
}

public struct MediaEditorComposerEntityFrame {
    public enum Content {
        case pixelBuffer(CVPixelBuffer)
        case image(CGImage)
    }
    
    public let content: Content
    public let alphaMask: CGImage?
    
    init(content: Content, alphaMask: CGImage?) {
        self.content = content
        self.alphaMask = alphaMask
    }
}

protocol MediaEditorComposerEntity {
    var position: CGPoint { get }
    var scale: CGFloat { get }
    var rotation: CGFloat { get }
    var baseSize: CGSize? { get }
    var baseScale: CGFloat? { get }
    var baseDrawingSize: CGSize? { get }
    var mirrored: Bool { get }
    
    func frame(for time: CMTime, frameRate: Float, completion: @escaping (MediaEditorComposerEntityFrame?) -> Void)
}

private func render(width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, pixelBuffer: CVPixelBuffer, tintColor: UIColor?) -> MediaEditorComposerEntityFrame? {
    let calculatedBytesPerRow = (4 * Int(width) + 31) & (~31)
    //assert(bytesPerRow == calculatedBytesPerRow)
    
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let dest = CVPixelBufferGetBaseAddress(pixelBuffer)
    
    switch type {
        case .yuva:
            data.withUnsafeBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                decodeYUVAToRGBA(bytes, dest, Int32(width), Int32(height), Int32(calculatedBytesPerRow))
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
    
    var tintedImage: CGImage?
    if let tintColor, let dest, let context = CGContext(data: dest, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: deviceColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue), let image = context.makeImage() {
        tintedImage = generateTintedImage(image: UIImage(cgImage: image), color: tintColor)?.cgImage
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    if let tintedImage {
        return MediaEditorComposerEntityFrame(content: .image(tintedImage), alphaMask: nil)
    }
    return MediaEditorComposerEntityFrame(content: .pixelBuffer(pixelBuffer), alphaMask: nil)
}

private extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
            case .up: return 1
            case .down: return 3
            case .left: return 8
            case .right: return 6
            case .upMirrored: return 2
            case .downMirrored: return 4
            case .leftMirrored: return 5
            case .rightMirrored: return 7
        @unknown default:
            return 0
        }
    }
}
