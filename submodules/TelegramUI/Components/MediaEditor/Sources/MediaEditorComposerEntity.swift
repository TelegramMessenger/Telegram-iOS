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
    
    return MediaEditorComposerStaticEntity(image: CIImage(image: newImage, options: [.colorSpace: colorSpace])!, position: position, scale: 1.0, rotation: 0.0, baseSize: nil, baseDrawingSize: CGSize(width: 1080, height: 1920), mirrored: false)
}

func composerEntitiesForDrawingEntity(account: Account, textScale: CGFloat, entity: DrawingEntity, colorSpace: CGColorSpace, tintColor: UIColor? = nil) -> [MediaEditorComposerEntity] {
    if let entity = entity as? DrawingStickerEntity {
        let content: MediaEditorComposerStickerEntity.Content
        switch entity.content {
        case let .file(file):
            content = .file(file)
        case let .image(image, _):
            content = .image(image)
        case let .video(file):
            content = .video(file)
        case .dualVideoReference:
            return []
        }
        return [MediaEditorComposerStickerEntity(account: account, content: content, position: entity.position, scale: entity.scale, rotation: entity.rotation, baseSize: entity.baseSize, mirrored: entity.mirrored, colorSpace: colorSpace, tintColor: tintColor, isStatic: entity.isExplicitlyStatic)]
    } else if let renderImage = entity.renderImage, let image = CIImage(image: renderImage, options: [.colorSpace: colorSpace]) {
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
                    entities.append(contentsOf: composerEntitiesForDrawingEntity(account: account, textScale: textScale, entity: subEntity, colorSpace: colorSpace, tintColor: entity.color.toUIColor()))
                }
            }
            return entities
        } else if let entity = entity as? DrawingLocationEntity {
            return [prerenderTextTransformations(entity: entity, image: renderImage, textScale: textScale, colorSpace: colorSpace)]
        }
    }
    return []
}

private class MediaEditorComposerStaticEntity: MediaEditorComposerEntity {
    let image: CIImage
    let position: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let baseSize: CGSize?
    let baseScale: CGFloat?
    let baseDrawingSize: CGSize?
    let mirrored: Bool
    
    init(
        image: CIImage,
        position: CGPoint,
        scale: CGFloat,
        rotation: CGFloat,
        baseSize: CGSize?,
        baseScale: CGFloat? = nil,
        baseDrawingSize: CGSize? = nil,
        mirrored: Bool
    ) {
        self.image = image
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.baseSize = baseSize
        self.baseScale = baseScale
        self.baseDrawingSize = baseDrawingSize
        self.mirrored = mirrored
    }
    
    func image(for time: CMTime, frameRate: Float, context: CIContext, completion: @escaping (CIImage?) -> Void) {
        completion(self.image)
    }
}

private class MediaEditorComposerStickerEntity: MediaEditorComposerEntity {
    public enum Content {
        case file(TelegramMediaFile)
        case video(TelegramMediaFile)
        case image(UIImage)
        
        var file: TelegramMediaFile? {
            if case let .file(file) = self {
                return file
            }
            return nil
        }
    }
    
    let account: Account
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
    
    var image: CIImage?
    var imagePixelBuffer: CVPixelBuffer?
    let imagePromise = Promise<UIImage>()
    
    init(account: Account, content: Content, position: CGPoint, scale: CGFloat, rotation: CGFloat, baseSize: CGSize, mirrored: Bool, colorSpace: CGColorSpace, tintColor: UIColor?, isStatic: Bool) {
        self.account = account
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
                
                self.source = AnimatedStickerResourceSource(account: account, resource: file.resource, isVideo: isVideoSticker)
                let pathPrefix = account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                if let source = self.source {
                    let fitToSize: CGSize
                    if self.isStatic {
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
        case .video:
            self.isAnimated = true
        }
    }
    
    deinit {
        self.disposables.dispose()
    }
    
    private func setupVideoOutput() {
        if case let .video(file) = self.content {
            if let path = self.account.postbox.mediaBox.completedResourcePath(file.resource, pathExtension: "mp4") {
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
    private var maskFilter: CIFilter?
    func image(for time: CMTime, frameRate: Float, context: CIContext, completion: @escaping (CIImage?) -> Void) {
        let currentTime = CMTimeGetSeconds(time)
        
        if case .video = self.content {
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
                
                if frameAdvancement == 0, let image = self.image {
                    completion(image)
                    return
                } else {
                    var sampleBuffer = videoOutput.copyNextSampleBuffer()
                    if sampleBuffer == nil && self.assetReader?.status == .completed {
                        self.setupVideoOutput()
                        sampleBuffer = self.videoOutput?.copyNextSampleBuffer()
                    }
                    
                    if let sampleBuffer, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
                        
                        var circleMaskFilter: CIFilter?
                        if let current = self.maskFilter {
                            circleMaskFilter = current
                        } else {
                            let circleImage = generateImage(ciImage.extent.size, scale: 1.0, rotatedContext: { size, context in
                                context.clear(CGRect(origin: .zero, size: size))
                                context.setFillColor(UIColor.white.cgColor)
                                
                                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: floor(size.width * 0.03))
                                context.addPath(path.cgPath)
                                context.fillPath()
                            })!
                            let circleMask = CIImage(image: circleImage)
                            if let filter = CIFilter(name: "CIBlendWithAlphaMask") {
                                filter.setValue(circleMask, forKey: kCIInputMaskImageKey)
                                self.maskFilter = filter
                                circleMaskFilter = filter
                            }
                        }
                        
                        let _ = circleMaskFilter
                        if let circleMaskFilter {
                            circleMaskFilter.setValue(ciImage, forKey: kCIInputImageKey)
                            if let output = circleMaskFilter.outputImage {
                                ciImage = output
                            }
                        }
                        
                        self.image = ciImage
                        completion(ciImage)
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
                
                if frameAdvancement == 0, let image = strongSelf.image {
                    completion(image)
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
                            
                            imagePixelBuffer = pixelBuffer
                            strongSelf.imagePixelBuffer = pixelBuffer
                        }
                        
                        if let imagePixelBuffer {
                            let image = render(context: context, width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, pixelBuffer: imagePixelBuffer, tintColor: tintColor)
                            strongSelf.image = image
                        }
                        completion(strongSelf.image)
                    } else {
                        completion(nil)
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
    var baseScale: CGFloat? { get }
    var baseDrawingSize: CGSize? { get }
    var mirrored: Bool { get }
    
    func image(for time: CMTime, frameRate: Float, context: CIContext, completion: @escaping (CIImage?) -> Void)
}

extension CIImage {
    func tinted(with color: UIColor) -> CIImage? {
        guard let colorMatrix = CIFilter(name: "CIColorMatrix") else {
            return self
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        colorMatrix.setDefaults()
        colorMatrix.setValue(self, forKey: "inputImage")
        colorMatrix.setValue(CIVector(x: r, y: 0, z: 0, w: 0), forKey: "inputRVector")
        colorMatrix.setValue(CIVector(x: 0, y: g, z: 0, w: 0), forKey: "inputGVector")
        colorMatrix.setValue(CIVector(x: 0, y: 0, z: b, w: 0), forKey: "inputBVector")
        colorMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: a), forKey: "inputAVector")
        return colorMatrix.outputImage
    }
}

private func render(context: CIContext, width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, pixelBuffer: CVPixelBuffer, tintColor: UIColor?) -> CIImage? {
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
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    let image = CIImage(cvPixelBuffer: pixelBuffer, options: [.colorSpace: deviceColorSpace])
    if let tintColor {
        if let cgImage = context.createCGImage(image, from: CGRect(origin: .zero, size: image.extent.size)) {
            if let tintedImage = generateTintedImage(image: UIImage(cgImage: cgImage), color: tintColor) {
                return CIImage(image: tintedImage)
            }
        }
    }
    return image
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
