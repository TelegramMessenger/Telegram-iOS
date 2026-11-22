import Foundation
import AVFoundation
import UIKit
import CoreImage
import Metal
import MetalKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox

public func mediaEditorGenerateGradientImage(size: CGSize, colors: [UIColor]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
    if let context = UIGraphicsGetCurrentContext() {
        let gradientColors = colors.map { $0.cgColor } as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    }
    
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return image
}

public func mediaEditorGetGradientColors(from image: UIImage) -> MediaEditor.GradientColors {
    let context = DrawingContext(size: CGSize(width: 5.0, height: 5.0), scale: 1.0, clear: false)!
    context.withFlippedContext({ context in
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 5.0, height: 5.0))
        }
    })
    return MediaEditor.GradientColors(
        top: context.colorAt(CGPoint(x: 2.0, y: 0.0)),
        bottom: context.colorAt(CGPoint(x: 2.0, y: 4.0))
    )
}

private func roundedCornersMaskCGImage(size: CGSize) -> CGImage? {
    return generateImage(size, opaque: true, scale: 1.0) { size, context in
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: size.width / 8.0, cornerHeight: size.height / 8.0, transform: nil))
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    }?.cgImage
}

private func rectangleMaskCGImage(size: CGSize) -> CGImage? {
    return generateImage(size, opaque: true, scale: 1.0) { size, context in
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
    }?.cgImage
}

public final class MediaEditorComposer {
    public enum Input {
        case texture(MTLTexture, CMTime, Bool, CGRect?, CGFloat, CGPoint)
        case videoBuffer(VideoPixelBuffer, CGRect?, CGFloat, CGPoint)
        case entityFrame(MediaEditorComposerEntityFrame, CMTime)
        
        var timestamp: CMTime {
            switch self {
            case let .texture(_, timestamp, _, _, _, _):
                return timestamp
            case let .videoBuffer(videoBuffer, _, _, _):
                return videoBuffer.timestamp
            case let .entityFrame(_, timestamp):
                return timestamp
            }
        }
        
        var rendererInput: MediaEditorRenderer.Input {
            switch self {
            case let .texture(texture, timestamp, hasTransparency, rect, scale, offset):
                return .texture(texture, timestamp, hasTransparency, rect, scale, offset)
            case let .videoBuffer(videoBuffer, rect, scale, offset):
                return .videoBuffer(videoBuffer, rect, scale, offset)
            case let .entityFrame(frame, timestamp):
                return .entityFrame(frame, timestamp)
            }
        }
    }
    
    let device: MTLDevice?
    let colorSpace: CGColorSpace
    
    public var values: MediaEditorValues {
        didSet {
            self.renderChain.update(values: self.values)
            self.renderer.videoFinishPass.update(values: self.values, videoDuration: nil, additionalVideoDuration: nil)
        }
    }
    private let dimensions: CGSize
    private let outputDimensions: CGSize
    private let textScale: CGFloat
    
    private let outputsYuvBuffers: Bool
    private let yuvPixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    private let yuvContext: CIContext?
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    let compositor: MediaEditorFrameCompositor?
    
    private let drawingTexture: MTLTexture?
    var entities: [MediaEditorComposerEntity]
    private var entityImageTextures: [Int: (image: CGImage, texture: MTLTexture)] = [:]
    private var entityMaskTextures: [Int: (image: CGImage, texture: MTLTexture)] = [:]
    
    private let maskTexture: MTLTexture?
    
    var debugCompositionTimeObserver: ((Double) -> Void)?
    
    public init(
        postbox: Postbox?,
        values: MediaEditorValues,
        dimensions: CGSize,
        outputDimensions: CGSize,
        textScale: CGFloat,
        videoDuration: Double?,
        additionalVideoDuration: Double?,
        outputsYuvBuffers: Bool = false
    ) {
        self.values = values
        self.dimensions = dimensions
        self.outputDimensions = outputDimensions
        self.textScale = textScale
        self.outputsYuvBuffers = outputsYuvBuffers
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        self.colorSpace = colorSpace
        
        self.renderer.addRenderChain(self.renderChain)
                
        var entities: [MediaEditorComposerEntity] = []
        if let postbox {
            for entity in values.entities {
                entities.append(contentsOf: composerEntitiesForDrawingEntity(postbox: postbox, textScale: textScale, entity: entity.entity, colorSpace: colorSpace))
            }
        }
        self.entities = entities
        
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        if let device, outputsYuvBuffers {
            self.yuvContext = CIContext(mtlDevice: device, options: [.workingColorSpace : self.colorSpace])
        } else {
            self.yuvContext = nil
        }
        
        if let maskDrawing = values.maskDrawing, let device, let maskTexture = loadTexture(image: maskDrawing, device: device) {
            self.renderer.currentMainInputMask = maskTexture
        }
        
        var compositor: MediaEditorFrameCompositor?
        if let device {
            self.renderer.setupForStandaloneDevice(device: device)
            if !outputsYuvBuffers, let commandQueue = self.renderer.commandQueue {
                compositor = MediaEditorFrameCompositor(device: device, commandQueue: commandQueue)
            }
        }
        self.compositor = compositor
        self.renderer.frameCompositor = compositor
        self.renderer.waitsForOffscreenFrames = compositor == nil
        
        var maskImage: CGImage?
        if compositor != nil {
            if values.isSticker {
                maskImage = roundedCornersMaskCGImage(size: CGSize(width: floor(1080.0 * 0.97), height: floor(1080.0 * 0.97)))
            } else if values.isAvatar {
                maskImage = rectangleMaskCGImage(size: CGSize(width: 1080.0, height: 1080.0))
            }
        }
        self.maskTexture = maskImage.flatMap { compositor?.texture(for: $0) }
        
        if let compositor, let drawing = values.drawing?.cgImage {
            self.drawingTexture = compositor.texture(for: drawing.copy(colorSpace: colorSpace) ?? drawing)
        } else {
            self.drawingTexture = nil
        }
        
        self.renderChain.update(values: self.values)
        self.renderer.videoFinishPass.update(values: self.values, videoDuration: videoDuration, additionalVideoDuration: additionalVideoDuration)
    }
    
    var previousAdditionalInput: [Int: Input] = [:]
    public func process(main: Input, additional: [Input?], timestamp: CMTime, pool: CVPixelBufferPool?, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard let pool else {
            completion(nil)
            return
        }
        
        var index = 0
        var augmentedAdditionals: [Input?] = []
        for input in additional {
            if let input {
                self.previousAdditionalInput[index] = input
                augmentedAdditionals.append(input)
            } else {
                augmentedAdditionals.append(self.previousAdditionalInput[index])
            }
            index += 1
        }
        
        self.renderer.consume(main: main.rendererInput, additionals: augmentedAdditionals.compactMap { $0 }.map { $0.rendererInput }, render: true)
        let compositionStartTime = CACurrentMediaTime()
        
        var pixelBuffer: CVPixelBuffer?
        if self.renderer.resultTexture != nil {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        }
        guard let resultTexture = self.renderer.resultTexture, let pixelBuffer else {
            self.compositor?.releaseFrameTextures()
            completion(nil)
            return
        }
        
        if self.outputsYuvBuffers {
            guard let yuvContext = self.yuvContext, var ciImage = CIImage(mtlTexture: resultTexture, options: [.colorSpace: self.colorSpace]) else {
                completion(nil)
                return
            }
            ciImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
            let scale = self.outputDimensions.width / ciImage.extent.width
            ciImage = ciImage.samplingLinear().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            yuvContext.render(ciImage, to: pixelBuffer)
            self.debugCompositionTimeObserver?(CACurrentMediaTime() - compositionStartTime)
            completion(pixelBuffer)
        } else {
            guard let compositor = self.compositor else {
                completion(nil)
                return
            }
            let frameRate: Float = 30.0
            let entities = self.entities
            let entitiesCount = Atomic<Int>(value: 1)
            let entityFrames = Atomic<[(Int, MediaEditorComposerEntityFrame)]>(value: [])
            let maybeFinalize = {
                let count = entitiesCount.modify { current -> Int in
                    return current - 1
                }
                guard count == 0 else {
                    return
                }
                var entityLayers: [(entity: MediaEditorComposerEntity, layer: MediaEditorCompositionLayer)] = []
                for (index, frame) in entityFrames.with({ $0 }).sorted(by: { $0.0 < $1.0 }) {
                    if let layer = self.entityLayer(index: index, frame: frame, compositor: compositor) {
                        entityLayers.append((entities[index], layer))
                    }
                }
                let resultSize = mediaEditorCompositionResultSize(dimensions: self.dimensions, outputDimensions: nil, values: self.values)
                var scene = mediaEditorCompositionScene(
                    input: MediaEditorCompositionLayer(texture: resultTexture, origin: .topLeft, transform: .identity, alphaMask: nil),
                    drawing: self.drawingTexture.flatMap { MediaEditorCompositionLayer(texture: $0, origin: .topLeft, transform: .identity, alphaMask: nil) },
                    entities: entityLayers,
                    finalMask: self.maskTexture,
                    dimensions: self.dimensions,
                    outputDimensions: nil,
                    values: self.values,
                    entityScale: 1.0,
                    outputScale: 1.0
                )
                let intermediateSize = CGSize(width: max(1.0, resultSize.width), height: max(1.0, resultSize.height))
                scene.outputSize = intermediateSize
                let outputScale = self.outputDimensions.width / intermediateSize.width
                let bufferSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
                
                var rendered = false
                if outputScale == 1.0 && bufferSize == intermediateSize {
                    rendered = compositor.render(scene: scene, into: pixelBuffer)
                } else if let intermediate = self.intermediateTexture(size: intermediateSize), compositor.render(scene: scene, into: intermediate) {
                    let outputScene = MediaEditorCompositionScene(
                        outputSize: bufferSize,
                        background: nil,
                        backgroundRect: .zero,
                        layers: [MediaEditorCompositionLayer(texture: intermediate, origin: .topLeft, transform: CGAffineTransform(scaleX: outputScale, y: outputScale), alphaMask: nil)],
                        finalMask: nil
                    )
                    rendered = compositor.render(scene: outputScene, into: pixelBuffer)
                } else {
                    compositor.releaseFrameTextures()
                }
                if rendered {
                    self.debugCompositionTimeObserver?(CACurrentMediaTime() - compositionStartTime)
                    completion(pixelBuffer)
                } else {
                    completion(nil)
                }
            }
            for (index, entity) in entities.enumerated() {
                let _ = entitiesCount.modify { current -> Int in
                    return current + 1
                }
                entity.frame(for: timestamp, frameRate: frameRate, completion: { frame in
                    if let frame {
                        let _ = entityFrames.modify { current in
                            var updated = current
                            updated.append((index, frame))
                            return updated
                        }
                    }
                    maybeFinalize()
                })
            }
            maybeFinalize()
        }
    }
    
    private var intermediate: MTLTexture?
    private func intermediateTexture(size: CGSize) -> MTLTexture? {
        let width = Int(size.width)
        let height = Int(size.height)
        if let intermediate = self.intermediate, intermediate.width == width, intermediate.height == height {
            return intermediate
        }
        guard let device = self.device else {
            return nil
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        self.intermediate = device.makeTexture(descriptor: descriptor)
        return self.intermediate
    }
    
    private func entityLayer(index: Int, frame: MediaEditorComposerEntityFrame, compositor: MediaEditorFrameCompositor) -> MediaEditorCompositionLayer? {
        let texture: MTLTexture?
        switch frame.content {
        case let .pixelBuffer(pixelBuffer):
            texture = compositor.texture(for: pixelBuffer, convertingTo: self.colorSpace)
        case let .image(image):
            if let cached = self.entityImageTextures[index], cached.image === image {
                texture = cached.texture
            } else {
                texture = compositor.texture(for: image)
                if let texture {
                    self.entityImageTextures[index] = (image, texture)
                } else {
                    self.entityImageTextures.removeValue(forKey: index)
                }
            }
        }
        guard let texture else {
            return nil
        }
        var alphaMask: MTLTexture?
        if let mask = frame.alphaMask {
            if let cached = self.entityMaskTextures[index], cached.image === mask {
                alphaMask = cached.texture
            } else if let maskTexture = compositor.texture(for: mask) {
                self.entityMaskTextures[index] = (mask, maskTexture)
                alphaMask = maskTexture
            }
        }
        return MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: alphaMask)
    }
    
    private var cachedTextures: [Int: MTLTexture] = [:]
    func textureForImage(index: Int, image: UIImage) -> MTLTexture? {
        if let cachedTexture = self.cachedTextures[index] {
            return cachedTexture
        }
        if let device = self.device, let texture = loadTexture(image: image, device: device) {
            self.cachedTextures[index] = texture
            return texture
        }
        return nil
    }
}

public enum MediaEditorCompositionInput {
    case editorResult(MTLTexture)
    case image(UIImage)
}

public func makeEditorImageComposition(postbox: Postbox?, input: MediaEditorCompositionInput, dimensions: CGSize, outputDimensions: CGSize? = nil, values: MediaEditorValues, time: CMTime, textScale: CGFloat, completion: @escaping (UIImage?) -> Void) {
    var maskImage: CGImage?
    var maskRect: CGRect?
    if values.isSticker {
        maskImage = roundedCornersMaskCGImage(size: CGSize(width: floor(1080.0 * 0.97), height: floor(1080.0 * 0.97)))
    } else if values.isAvatar {
        maskRect = mediaEditorRectangleMaskRect(size: CGSize(width: 1080.0, height: 1080.0))
    } else if let outputDimensions {
        maskRect = mediaEditorRectangleMaskRect(size: outputDimensions.aspectFitted(CGSize(width: 1080.0, height: 1920.0)))
    }
    
    mediaEditorComposePhoto(
        postbox: postbox,
        input: input,
        dimensions: dimensions,
        sceneOutputDimensions: outputDimensions,
        values: values,
        drawingTransform: .identity,
        entityScale: 1.0,
        time: time,
        textScale: textScale,
        maskImage: maskImage,
        maskRect: maskRect,
        outputSize: { compositeSize, _ in
            let finalWidth = (outputDimensions ?? dimensions).width
            let scale = finalWidth / compositeSize.width
            let size = mediaEditorCompositionRoundedSize(CGSize(width: compositeSize.width * scale, height: compositeSize.height * scale))
            return (scale, CGSize(width: max(1.0, size.width), height: max(1.0, size.height)))
        },
        completion: { image in
            Queue.mainQueue().async {
                completion(image)
            }
        }
    )
}

public func mediaEditorChatExportScale(values: MediaEditorValues, maxOutputSide: CGFloat) -> CGFloat {
    let originalDimensions = values.originalDimensions.cgSize
    let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: values.originalDimensions)
    guard originalDimensions.width > 0.0, canvas.width > 0.0 else {
        return 1.0
    }
    var cropRect = values.cropRect ?? .zero
    if cropRect.isEmpty {
        cropRect = CGRect(origin: .zero, size: originalDimensions)
    }
    let cropSourceSide = max(cropRect.width, cropRect.height)
    let cropCanvasSide = cropSourceSide * canvas.width / originalDimensions.width
    guard cropCanvasSide > 0.0 else {
        return 1.0
    }
    let maxScale = max(1.0, originalDimensions.width / canvas.width)
    let scale = min(maxOutputSide, cropSourceSide) / cropCanvasSide
    return min(maxScale, max(1.0, scale))
}

public func makeChatEditorImageComposition(postbox: Postbox?, input: MediaEditorCompositionInput, values: MediaEditorValues, time: CMTime, maxOutputSide: CGFloat, completion: @escaping (UIImage?) -> Void) {
    let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: values.originalDimensions)
    let exportScale = mediaEditorChatExportScale(values: values, maxOutputSide: maxOutputSide)
    let dimensions = CGSize(width: canvas.width * exportScale, height: canvas.height * exportScale)
    let values = mediaEditorChatPixelAlignedValues(values, dimensions: dimensions)
    
    mediaEditorComposePhoto(
        postbox: postbox,
        input: input,
        dimensions: dimensions,
        sceneOutputDimensions: nil,
        values: values,
        drawingTransform: CGAffineTransform(scaleX: exportScale, y: exportScale),
        entityScale: exportScale,
        time: time,
        textScale: 2.0,
        maskImage: nil,
        maskRect: nil,
        outputSize: { _, clipRect in
            return (1.0, mediaEditorChatOutputRect(extent: clipRect).size)
        },
        completion: { image in
            Queue.mainQueue().async {
                completion(image)
            }
        }
    )
}

private func mediaEditorRotatedContentSize(_ size: CGSize, rotation: CGFloat) -> CGSize {
    var transform = CGAffineTransform(translationX: size.width / 2.0, y: size.height / 2.0)
    transform = transform.rotated(by: rotation)
    transform = transform.translatedBy(x: -size.width / 2.0, y: -size.height / 2.0)
    return CGRect(origin: .zero, size: size).applying(transform).size
}

func mediaEditorChatOutputRect(extent: CGRect) -> CGRect {
    return CGRect(x: extent.minX, y: extent.minY, width: floor(extent.width + 0.01), height: floor(extent.height + 0.01))
}

func mediaEditorOrientationTransform(_ orientation: MediaCropOrientation, size: CGSize) -> CGAffineTransform {
    switch orientation {
    case .up:
        return .identity
    case .left:
        return CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0, tx: size.height, ty: 0.0)
    case .right:
        return CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0, tx: 0.0, ty: size.width)
    case .down:
        return CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0, tx: size.width, ty: size.height)
    }
}

func mediaEditorNonStoryMediaRect(originalDimensions: CGSize, dimensions: CGSize) -> CGRect {
    guard originalDimensions.width > 0.0 else {
        return CGRect(origin: .zero, size: dimensions)
    }
    let height = originalDimensions.height * dimensions.width / originalDimensions.width
    return CGRect(x: 0.0, y: (dimensions.height - height) / 2.0, width: dimensions.width, height: height)
}

func mediaEditorChatPixelAlignedValues(_ values: MediaEditorValues, dimensions: CGSize) -> MediaEditorValues {
    let originalDimensions = values.originalDimensions.cgSize
    guard originalDimensions.width > 0.0, dimensions.width > 0.0 else {
        return values
    }
    let scale = dimensions.width / originalDimensions.width
    let scaled = mediaEditorNonStoryScaledCropRect(values: values, dimensions: dimensions)
    let epsilon: CGFloat = 0.001
    let snappedMinX = ceil(scaled.minX - epsilon)
    let snappedMinY = ceil(scaled.minY - epsilon)
    let snappedMaxX = floor(scaled.maxX + epsilon)
    let snappedMaxY = floor(scaled.maxY + epsilon)
    guard snappedMaxX - snappedMinX >= 1.0, snappedMaxY - snappedMinY >= 1.0 else {
        return values
    }
    if snappedMinX == scaled.minX && snappedMinY == scaled.minY && snappedMaxX == scaled.maxX && snappedMaxY == scaled.maxY {
        return values
    }
    var cropRect = values.cropRect ?? .zero
    if cropRect.isEmpty {
        cropRect = CGRect(origin: .zero, size: originalDimensions)
    }
    let minX = cropRect.minX + (snappedMinX - scaled.minX) / scale
    let maxX = cropRect.maxX + (snappedMaxX - scaled.maxX) / scale
    let maxY = cropRect.maxY - (snappedMinY - scaled.minY) / scale
    let minY = cropRect.minY - (snappedMaxY - scaled.maxY) / scale
    return values.withUpdatedCrop(rect: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY), rotation: values.cropRotation, orientation: values.cropOrientation, mirroring: values.cropMirroring, perspective: values.cropPerspective)
}

func mediaEditorNonStoryScaledCropRect(values: MediaEditorValues, dimensions: CGSize) -> CGRect {
    let originalDimensions = values.originalDimensions.cgSize
    var cropRect = values.cropRect ?? .zero
    if cropRect.isEmpty {
        cropRect = CGRect(origin: .zero, size: originalDimensions)
    }
    if !values.cropRotation.isZero {
        let rotatedContentSize = mediaEditorRotatedContentSize(originalDimensions, rotation: values.cropRotation)
        cropRect = cropRect.offsetBy(dx: -(rotatedContentSize.width - originalDimensions.width) / 2.0, dy: -(rotatedContentSize.height - originalDimensions.height) / 2.0)
    }
    let scale = dimensions.width / originalDimensions.width
    let mediaRect = mediaEditorNonStoryMediaRect(originalDimensions: originalDimensions, dimensions: dimensions)
    return CGRect(origin: CGPoint(x: mediaRect.minX + cropRect.minX * scale, y: mediaRect.maxY - cropRect.maxY * scale), size: CGSize(width: cropRect.width * scale, height: cropRect.height * scale))
}

private func mediaEditorRectangleMaskRect(size: CGSize) -> CGRect {
    return CGRect(x: 0.0, y: 0.0, width: floor(max(1.0, size.width)), height: floor(max(1.0, size.height)))
}

private func mediaEditorPhotoInputImage(_ image: UIImage, colorSpace: CGColorSpace, device: MTLDevice) -> CGImage? {
    guard let cgImage = image.cgImage else {
        return nil
    }
    let tagged = cgImage.copy(colorSpace: colorSpace) ?? cgImage
    let maxTextureSide = mediaEditorComposeMaxTextureSide(device: device)
    let maxSide = CGFloat(maxTextureSide)
    let size = CGSize(width: tagged.width, height: tagged.height)
    guard size.width > maxSide || size.height > maxSide else {
        return tagged
    }
    let fitted = size.aspectFitted(CGSize(width: maxSide, height: maxSide))
    let width = min(maxTextureSide, max(1, Int(fitted.width.rounded())))
    let height = min(maxTextureSide, max(1, Int(fitted.height.rounded())))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
        return nil
    }
    context.interpolationQuality = .high
    context.setBlendMode(.copy)
    context.draw(tagged, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
    return context.makeImage()
}

private func mediaEditorComposePhoto(
    postbox: Postbox?,
    input: MediaEditorCompositionInput,
    dimensions: CGSize,
    sceneOutputDimensions: CGSize?,
    values: MediaEditorValues,
    drawingTransform: CGAffineTransform,
    entityScale: CGFloat,
    time: CMTime,
    textScale: CGFloat,
    maskImage: CGImage?,
    maskRect: CGRect?,
    outputSize: @escaping (CGSize, CGRect) -> (scale: CGFloat, size: CGSize),
    completion: @escaping (UIImage?) -> Void
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let device: MTLDevice?
    switch input {
    case let .editorResult(texture):
        device = texture.device
    case .image:
        device = MTLCreateSystemDefaultDevice()
    }
    var inputImage: CGImage?
    var inputSize: CGSize?
    if case let .image(image) = input, let device {
        inputImage = mediaEditorPhotoInputImage(image, colorSpace: colorSpace, device: device)
        inputSize = image.cgImage.flatMap { CGSize(width: $0.width, height: $0.height) }
    }
    guard let device, let commandQueue = device.makeCommandQueue(), let compositor = MediaEditorFrameCompositor(device: device, commandQueue: commandQueue) else {
        completion(nil)
        return
    }
    
    var entities: [MediaEditorComposerEntity] = []
    if let postbox {
        for entity in values.entities {
            entities.append(contentsOf: composerEntitiesForDrawingEntity(postbox: postbox, textScale: textScale, entity: entity.entity, colorSpace: colorSpace))
        }
    }
    
    let render: ([(Int, MediaEditorComposerEntityFrame)]) -> UIImage? = { entityFrames in
        let inputLayer: MediaEditorCompositionLayer
        switch input {
        case let .editorResult(texture):
            inputLayer = MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: nil)
        case .image:
            guard let inputImage, let inputSize, let texture = compositor.texture(for: inputImage) else {
                return nil
            }
            var transform = CGAffineTransform.identity
            let width = CGFloat(texture.width)
            let height = CGFloat(texture.height)
            let downscale = inputSize.width / width
            if downscale != 1.0 && (values.isStory || values.isSticker || values.isAvatar || values.isCover) {
                transform = CGAffineTransform(translationX: -width / 2.0, y: -height / 2.0).concatenating(CGAffineTransform(scaleX: inputSize.width / width, y: inputSize.height / height)).concatenating(CGAffineTransform(translationX: width / 2.0, y: height / 2.0))
            }
            inputLayer = MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: transform, alphaMask: nil)
        }
        
        var drawingLayer: MediaEditorCompositionLayer?
        if let drawing = values.drawing?.cgImage, let texture = compositor.texture(for: drawing.copy(colorSpace: colorSpace) ?? drawing) {
            drawingLayer = MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: drawingTransform, alphaMask: nil)
        }
        
        var entityLayers: [(entity: MediaEditorComposerEntity, layer: MediaEditorCompositionLayer)] = []
        for (index, frame) in entityFrames.sorted(by: { $0.0 < $1.0 }) {
            let texture: MTLTexture?
            switch frame.content {
            case let .pixelBuffer(pixelBuffer):
                texture = compositor.texture(for: pixelBuffer, convertingTo: colorSpace)
            case let .image(image):
                texture = compositor.texture(for: image)
            }
            guard let texture else {
                continue
            }
            let alphaMask = frame.alphaMask.flatMap { compositor.texture(for: $0) }
            entityLayers.append((entities[index], MediaEditorCompositionLayer(texture: texture, origin: .topLeft, transform: .identity, alphaMask: alphaMask)))
        }
        
        var scene = mediaEditorCompositionScene(
            input: inputLayer,
            drawing: drawingLayer,
            entities: entityLayers,
            finalMask: maskImage.flatMap { compositor.texture(for: $0) },
            dimensions: dimensions,
            outputDimensions: sceneOutputDimensions,
            values: values,
            entityScale: entityScale,
            outputScale: 1.0
        )
        if let maskRect {
            scene.clipRect = (scene.clipRect ?? CGRect(origin: .zero, size: scene.outputSize)).intersection(maskRect)
        }
        let compositeSize = scene.outputSize
        let (scale, size) = outputSize(compositeSize, scene.clipRect ?? CGRect(origin: .zero, size: compositeSize))
        guard size.width >= 1.0, size.height >= 1.0, compositeSize.width >= 1.0, compositeSize.height >= 1.0 else {
            compositor.releaseFrameTextures()
            return nil
        }
        if scale == 1.0 {
            scene.outputSize = size
            return compositor.renderImage(scene: scene)
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(compositeSize.width), height: Int(compositeSize.height), mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        guard let intermediate = device.makeTexture(descriptor: descriptor), compositor.render(scene: scene, into: intermediate) else {
            compositor.releaseFrameTextures()
            return nil
        }
        let outputScene = MediaEditorCompositionScene(
            outputSize: size,
            background: nil,
            backgroundRect: .zero,
            layers: [MediaEditorCompositionLayer(texture: intermediate, origin: .topLeft, transform: CGAffineTransform(scaleX: scale, y: scale), alphaMask: nil)],
            finalMask: nil
        )
        return compositor.renderImage(scene: outputScene)
    }
    
    let frameRate: Float = 30.0
    let entitiesCount = Atomic<Int>(value: 1)
    let entityFrames = Atomic<[(Int, MediaEditorComposerEntityFrame)]>(value: [])
    let maybeFinalize = {
        let count = entitiesCount.modify { current -> Int in
            return current - 1
        }
        if count == 0 {
            completion(render(entityFrames.with { $0 }))
        }
    }
    for (index, entity) in entities.enumerated() {
        let _ = entitiesCount.modify { current -> Int in
            return current + 1
        }
        entity.frame(for: time, frameRate: frameRate, completion: { frame in
            if let frame {
                let _ = entityFrames.modify { current in
                    var updated = current
                    updated.append((index, frame))
                    return updated
                }
            }
            maybeFinalize()
        })
    }
    maybeFinalize()
}
