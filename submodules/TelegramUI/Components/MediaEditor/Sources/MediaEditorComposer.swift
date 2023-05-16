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

final class MediaEditorComposer {
    let device: MTLDevice?
    
    private let values: MediaEditorValues
    private let dimensions: CGSize
    
    private let ciContext: CIContext?
    private var textureCache: CVMetalTextureCache?
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    
    private let gradientImage: CIImage
    private let drawingImage: CIImage?
    private var entities: [MediaEditorComposerEntity]
    
    init(account: Account, values: MediaEditorValues, dimensions: CGSize) {
        self.values = values
        self.dimensions = dimensions
        
        self.renderer.addRenderChain(self.renderChain)
        self.renderer.addRenderPass(ComposerRenderPass())
        
        if let gradientColors = values.gradientColors {
            let image = generateGradientImage(size: dimensions, scale: 1.0, colors: gradientColors, locations: [0.0, 1.0])!
            self.gradientImage = CIImage(image: image)!.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
        } else {
            self.gradientImage = CIImage(color: .black)
        }
        
        if let drawing = values.drawing, let drawingImage = CIImage(image: drawing) {
            self.drawingImage = drawingImage.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
        } else {
            self.drawingImage = nil
        }
        
        self.entities = values.entities.map { $0.entity } .compactMap { composerEntityForDrawingEntity(account: account, entity: $0) }
        
        self.device = MTLCreateSystemDefaultDevice()
        if let device = self.device {
            self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace : NSNull()])
            
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &self.textureCache)
        } else {
            self.ciContext = nil
        }
                
        self.renderer.setupForComposer(composer: self)
        self.renderChain.update(values: self.values)
    }
    
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, pool: CVPixelBufferPool?, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard let textureCache = self.textureCache, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let pool = pool else {
            completion(nil)
            return
        }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let format: MTLPixelFormat = .bgra8Unorm
        var textureRef : CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, imageBuffer, nil, format, width, height, 0, &textureRef)
        var texture: MTLTexture?
        if status == kCVReturnSuccess {
            texture = CVMetalTextureGetTexture(textureRef!)
        }
        if let texture {
            self.renderer.consumeTexture(texture, rotation: .rotate90Degrees)
            self.renderer.renderFrame()
            
            if let finalTexture = self.renderer.finalTexture, var ciImage = CIImage(mtlTexture: finalTexture) {
                ciImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
                
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
                
                if let pixelBuffer {
                    processImage(inputImage: ciImage, time: time, completion: { compositedImage in
                        if let compositedImage {
                            self.ciContext?.render(compositedImage, to: pixelBuffer)
                            completion(pixelBuffer)
                        } else {
                            completion(nil)
                        }
                    })
                    return
                }
            }
        }
        completion(nil)
    }
    
    private var filteredImage: CIImage?
    func processImage(inputImage: UIImage, pool: CVPixelBufferPool?, time: CMTime, completion: @escaping (CVPixelBuffer?, CMTime) -> Void) {
        guard let pool else {
            completion(nil, time)
            return
        }
        if self.filteredImage == nil, let device = self.device, let cgImage = inputImage.cgImage {
            let textureLoader = MTKTextureLoader(device: device)
            if let texture = try? textureLoader.newTexture(cgImage: cgImage) {
                self.renderer.consumeTexture(texture, rotation: .rotate0Degrees)
                self.renderer.renderFrame()
                
                if let finalTexture = self.renderer.finalTexture, var ciImage = CIImage(mtlTexture: finalTexture) {
                    ciImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
                    self.filteredImage = ciImage
                }
            }
        }
        
        if let image = self.filteredImage {
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            
            if let pixelBuffer {
                makeEditorImageFrameComposition(inputImage: image, gradientImage: self.gradientImage, drawingImage: self.drawingImage, dimensions: self.dimensions, values: self.values, entities: self.entities, time: time, completion: { compositedImage in
                    if let compositedImage {
                        self.ciContext?.render(compositedImage, to: pixelBuffer)
                        completion(pixelBuffer, time)
                    } else {
                        completion(nil, time)
                    }
                })
                return
            }
        }
        completion(nil, time)
    }
    
    func processImage(inputImage: CIImage, time: CMTime, completion: @escaping (CIImage?) -> Void) {
        makeEditorImageFrameComposition(inputImage: inputImage, gradientImage: self.gradientImage, drawingImage: self.drawingImage, dimensions: self.dimensions, values: self.values, entities: self.entities, time: time, completion: completion)
    }
}

public func makeEditorImageComposition(account: Account, inputImage: UIImage, dimensions: CGSize, values: MediaEditorValues, time: CMTime, completion: @escaping (UIImage?) -> Void) {
    let inputImage = CIImage(image: inputImage)!
    let gradientImage: CIImage
    var drawingImage: CIImage?
    if let gradientColors = values.gradientColors {
        let image = generateGradientImage(size: dimensions, scale: 1.0, colors: gradientColors, locations: [0.0, 1.0])!
        gradientImage = CIImage(image: image)!.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    } else {
        gradientImage = CIImage(color: .black)
    }
    
    if let drawing = values.drawing, let image = CIImage(image: drawing) {
        drawingImage = image.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    }
    
    let entities: [MediaEditorComposerEntity] = values.entities.map { $0.entity }.compactMap { composerEntityForDrawingEntity(account: account, entity: $0) }
    makeEditorImageFrameComposition(inputImage: inputImage, gradientImage: gradientImage, drawingImage: drawingImage, dimensions: dimensions, values: values, entities: entities, time: time, completion: { ciImage in
        if let ciImage {
            let context = CIContext(options: [.workingColorSpace : NSNull()])
            if let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: ciImage.extent.size)) {
                Queue.mainQueue().async {
                    completion(UIImage(cgImage: cgImage))
                }
                return
            }
        }
        completion(nil)
    })
}

private func makeEditorImageFrameComposition(inputImage: CIImage, gradientImage: CIImage, drawingImage: CIImage?, dimensions: CGSize, values: MediaEditorValues, entities: [MediaEditorComposerEntity], time: CMTime, completion: @escaping (CIImage?) -> Void) {
    var resultImage = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: dimensions)).transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    resultImage = gradientImage.composited(over: resultImage)
    
    var mediaImage = inputImage.transformed(by: CGAffineTransform(translationX: -inputImage.extent.midX, y: -inputImage.extent.midY))
    
    var initialScale: CGFloat
    if mediaImage.extent.height > mediaImage.extent.width {
        initialScale = dimensions.height / mediaImage.extent.height
    } else {
        initialScale = dimensions.width / mediaImage.extent.width
    }
    
    var cropTransform = CGAffineTransform(translationX: values.cropOffset.x, y: values.cropOffset.y * -1.0)
    cropTransform = cropTransform.rotated(by: -values.cropRotation)
    cropTransform = cropTransform.scaledBy(x: initialScale * values.cropScale, y: initialScale * values.cropScale)
    mediaImage = mediaImage.transformed(by: cropTransform)
    resultImage = mediaImage.composited(over: resultImage)
    
    if let drawingImage {
        resultImage = drawingImage.composited(over: resultImage)
    }
    
    let frameRate: Float = 60.0
    
    let entitiesCount = Atomic<Int>(value: 1)
    let entitiesImages = Atomic<[(CIImage, Int)]>(value: [])
    let maybeFinalize = {
        let count = entitiesCount.modify { current -> Int in
            return current - 1
        }
        if count == 0 {
            let sortedImages = entitiesImages.with({ $0 }).sorted(by: { $0.1 < $1.1 }).map({ $0.0 })
            for image in sortedImages {
                resultImage = image.composited(over: resultImage)
            }
            
            resultImage = resultImage.transformed(by: CGAffineTransform(translationX: dimensions.width / 2.0, y: dimensions.height / 2.0))
            resultImage = resultImage.cropped(to: CGRect(origin: .zero, size: dimensions))
            completion(resultImage)
        }
    }
    var i = 0
    for entity in entities {
        let _ = entitiesCount.modify { current -> Int in
            return current + 1
        }
        let index = i
        entity.image(for: time, frameRate: frameRate, completion: { image in
            if var image = image {
                let resetTransform = CGAffineTransform(translationX: -image.extent.width / 2.0, y: -image.extent.height / 2.0)
                image = image.transformed(by: resetTransform)
                
                var baseScale: CGFloat = 1.0
                if let baseSize = entity.baseSize {
                    baseScale = baseSize.width / image.extent.width
                }
                
                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: -dimensions.width / 2.0 + entity.position.x, y: dimensions.height / 2.0 + entity.position.y * -1.0)
                transform = transform.rotated(by: -entity.rotation)
                transform = transform.scaledBy(x: entity.scale * baseScale, y: entity.scale * baseScale)
                if entity.mirrored {
                    transform = transform.scaledBy(x: -1.0, y: 1.0)
                }
                                                            
                image = image.transformed(by: transform)
                let _ = entitiesImages.modify { current in
                    var updated = current
                    updated.append((image, index))
                    return updated
                }
            }
            maybeFinalize()
        })
        i += 1
    }
    maybeFinalize()
}

private func composerEntityForDrawingEntity(account: Account, entity: DrawingEntity) -> MediaEditorComposerEntity? {
    if let entity = entity as? DrawingStickerEntity {
        let content: MediaEditorComposerStickerEntity.Content
        switch entity.content {
        case let .file(file):
            content = .file(file)
        case let .image(image):
            content = .image(image)
        }
        return MediaEditorComposerStickerEntity(account: account, content: content, position: entity.position, scale: entity.scale, rotation: entity.rotation, baseSize: entity.baseSize, mirrored: entity.mirrored)
    } else if let renderImage = entity.renderImage, let image = CIImage(image: renderImage) {
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
    
    var isAnimated: Bool
    var source: AnimatedStickerNodeSource?
    var frameSource = Promise<QueueLocalObject<AnimatedStickerDirectFrameSource>?>()
    
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
    
    init(account: Account, content: Content, position: CGPoint, scale: CGFloat, rotation: CGFloat, baseSize: CGSize, mirrored: Bool) {
        self.content = content
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.baseSize = baseSize
        self.mirrored = mirrored
        
        switch content {
        case let .file(file):
            if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                self.isAnimated = true
                self.source = AnimatedStickerResourceSource(account: account, resource: file.resource, isVideo: file.isVideoSticker || file.mimeType == "video/webm")
                let pathPrefix = account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                if let source = self.source {
                    let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 384, height: 384))
                    self.disposables.add((source.directDataPath(attemptSynchronously: true)
                    |> deliverOn(self.queue)).start(next: { [weak self] path in
                        if let strongSelf = self, let path {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                let queue = strongSelf.queue
                                let frameSource = QueueLocalObject<AnimatedStickerDirectFrameSource>(queue: queue, generate: {
                                    return AnimatedStickerDirectFrameSource(queue: queue, data: data, width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), cachePathPrefix: pathPrefix, useMetalCache: false, fitzModifier: nil)!
                                    //return AnimatedStickerCachedFrameSource(queue: queue, data: data, complete: complete, notifyUpdated: {})!
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
                    }))
                }
            } else {
                self.isAnimated = false
                self.disposables.add((chatMessageSticker(account: account, userLocation: .other, file: file, small: false, fetched: true, onlyFullSize: true, thumbnail: false, synchronousLoad: false)
                |> deliverOn(self.queue)).start(next: { [weak self] generator in
                    if let strongSelf = self {
                        let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: baseSize, boundingSize: baseSize, intrinsicInsets: UIEdgeInsets()))
                        let image = context?.generateImage()
                        if let image = image {
                            strongSelf.imagePromise.set(.single(image))
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
                            let image = render(width: frame.width, height: frame.height, bytesPerRow: frame.bytesPerRow, data: frame.data, type: frame.type, pixelBuffer: imagePixelBuffer, tintColor: tintColor)
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
                    if let strongSelf = self {
                        strongSelf.image = CIImage(image: image)
                        completion(strongSelf.image)
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

private func render(width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, pixelBuffer: CVPixelBuffer, tintColor: UIColor?) -> CIImage? {
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
    
    return CIImage(cvPixelBuffer: pixelBuffer)
}

final class ComposerRenderPass: DefaultRenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    override func process(input: MTLTexture, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device, rotation: rotation)
        
        let (width, height) = textureDimensionsForRotation(texture: input, rotation: rotation)
        
        if self.cachedTexture == nil || self.cachedTexture?.width != width || self.cachedTexture?.height != height {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = width
            textureDescriptor.height = height
            textureDescriptor.pixelFormat = input.pixelFormat
            textureDescriptor.storageMode = .shared
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return input
            }
            self.cachedTexture = texture
            texture.label = "composerTexture"
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(width), height: Double(height),
            znear: -1.0, zfar: 1.0)
        )
        
        renderCommandEncoder.setFragmentTexture(input, index: 0)
        
        var texCoordScales = simd_float2(x: 1.0, y: 1.0)
        renderCommandEncoder.setFragmentBytes(&texCoordScales, length: MemoryLayout<simd_float2>.stride, index: 0)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
}
