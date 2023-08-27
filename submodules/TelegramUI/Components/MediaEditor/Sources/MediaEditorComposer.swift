import Foundation
import AVFoundation
import UIKit
import CoreImage
import Metal
import MetalKit
import Display
import SwiftSignalKit
import TelegramCore

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

public func mediaEditorGetGradientColors(from image: UIImage) -> (UIColor, UIColor) {
    let context = DrawingContext(size: CGSize(width: 5.0, height: 5.0), scale: 1.0, clear: false)!
    context.withFlippedContext({ context in
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 5.0, height: 5.0))
        }
    })
    return (context.colorAt(CGPoint(x: 2.0, y: 0.0)), context.colorAt(CGPoint(x: 2.0, y: 4.0)))
}

final class MediaEditorComposer {
    let device: MTLDevice?
    private let colorSpace: CGColorSpace
    
    private let values: MediaEditorValues
    private let dimensions: CGSize
    private let outputDimensions: CGSize
    private let textScale: CGFloat
    
    private let ciContext: CIContext?
    private var textureCache: CVMetalTextureCache?
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    
    private let gradientImage: CIImage
    private let drawingImage: CIImage?
    private var entities: [MediaEditorComposerEntity]
    
    init(account: Account, values: MediaEditorValues, dimensions: CGSize, outputDimensions: CGSize, textScale: CGFloat) {
        self.values = values
        self.dimensions = dimensions
        self.outputDimensions = outputDimensions
        self.textScale = textScale
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        self.colorSpace = colorSpace
        
        self.renderer.addRenderChain(self.renderChain)
        
        if let gradientColors = values.gradientColors, let image = mediaEditorGenerateGradientImage(size: dimensions, colors: gradientColors) {
            self.gradientImage = CIImage(image: image, options: [.colorSpace: self.colorSpace])!.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
        } else {
            self.gradientImage = CIImage(color: .black)
        }
        
        if let drawing = values.drawing, let drawingImage = CIImage(image: drawing, options: [.colorSpace: self.colorSpace]) {
            self.drawingImage = drawingImage.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
        } else {
            self.drawingImage = nil
        }
        
        var entities: [MediaEditorComposerEntity] = []
        for entity in values.entities {
            entities.append(contentsOf: composerEntitiesForDrawingEntity(account: account, textScale: textScale, entity: entity.entity, colorSpace: colorSpace))
        }
        self.entities = entities
        
        self.device = MTLCreateSystemDefaultDevice()
        if let device = self.device {
            self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace : self.colorSpace])
            
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &self.textureCache)
        } else {
            self.ciContext = nil
        }
                
        self.renderer.setupForComposer(composer: self)
        self.renderChain.update(values: self.values)
        self.renderer.videoFinishPass.update(values: self.values)
    }
    
    func processSampleBuffer(sampleBuffer: CMSampleBuffer, textureRotation: TextureRotation, additionalSampleBuffer: CMSampleBuffer?, additionalTextureRotation: TextureRotation, pool: CVPixelBufferPool?, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let pool = pool else {
            completion(nil)
            return
        }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        let mainPixelBuffer = VideoPixelBuffer(pixelBuffer: imageBuffer, rotation: textureRotation, timestamp: time)
        var additionalPixelBuffer: VideoPixelBuffer?
        if let additionalSampleBuffer, let additionalImageBuffer = CMSampleBufferGetImageBuffer(additionalSampleBuffer) {
            additionalPixelBuffer = VideoPixelBuffer(pixelBuffer: additionalImageBuffer, rotation: additionalTextureRotation, timestamp: time)
        }
        self.renderer.consumeVideoPixelBuffer(pixelBuffer: mainPixelBuffer, additionalPixelBuffer: additionalPixelBuffer, render: true)
        
        if let finalTexture = self.renderer.finalTexture, var ciImage = CIImage(mtlTexture: finalTexture, options: [.colorSpace: self.colorSpace]) {
            ciImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
            
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            
            if let pixelBuffer {
                processImage(inputImage: ciImage, time: time, completion: { compositedImage in
                    if var compositedImage {
                        let scale = self.outputDimensions.width / self.dimensions.width
                        compositedImage = compositedImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
 
                        self.ciContext?.render(compositedImage, to: pixelBuffer)
                        completion(pixelBuffer)
                    } else {
                        completion(nil)
                    }
                })
                return
            }
        }
        completion(nil)
    }
    
    private var filteredImage: CIImage?
    func processImage(inputImage: UIImage, pool: CVPixelBufferPool?, time: CMTime, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard let pool else {
            completion(nil)
            return
        }
        if self.filteredImage == nil, let device = self.device {
            if let texture = loadTexture(image: inputImage, device: device) {
                self.renderer.consumeTexture(texture, render: true)
                
                if let finalTexture = self.renderer.finalTexture, var ciImage = CIImage(mtlTexture: finalTexture, options: [.colorSpace: self.colorSpace]) {
                    ciImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
                    self.filteredImage = ciImage
                }
            }
        }
        
        if let image = self.filteredImage {
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            
            if let pixelBuffer, let context = self.ciContext {
                makeEditorImageFrameComposition(context: context, inputImage: image, gradientImage: self.gradientImage, drawingImage: self.drawingImage, dimensions: self.dimensions, outputDimensions: self.outputDimensions, values: self.values, entities: self.entities, time: time, completion: { compositedImage in
                    if var compositedImage {
                        let scale = self.outputDimensions.width / self.dimensions.width
                        compositedImage = compositedImage.samplingLinear().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        
                        self.ciContext?.render(compositedImage, to: pixelBuffer)
                        completion(pixelBuffer)
                    } else {
                        completion(nil)
                    }
                })
                return
            }
        }
        completion(nil)
    }
    
    func processImage(inputImage: CIImage, time: CMTime, completion: @escaping (CIImage?) -> Void) {
        guard let context = self.ciContext else {
            return
        }
        makeEditorImageFrameComposition(context: context, inputImage: inputImage, gradientImage: self.gradientImage, drawingImage: self.drawingImage, dimensions: self.dimensions, outputDimensions: self.outputDimensions, values: self.values, entities: self.entities, time: time, textScale: self.textScale, completion: completion)
    }
}

public func makeEditorImageComposition(context: CIContext, account: Account, inputImage: UIImage, dimensions: CGSize, values: MediaEditorValues, time: CMTime, textScale: CGFloat, completion: @escaping (UIImage?) -> Void) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let inputImage = CIImage(image: inputImage, options: [.colorSpace: colorSpace])!
    let gradientImage: CIImage
    var drawingImage: CIImage?
    if let gradientColors = values.gradientColors, let image = mediaEditorGenerateGradientImage(size: dimensions, colors: gradientColors) {
        gradientImage = CIImage(image: image, options: [.colorSpace: colorSpace])!.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    } else {
        gradientImage = CIImage(color: .black)
    }
    
    if let drawing = values.drawing, let image = CIImage(image: drawing, options: [.colorSpace: colorSpace]) {
        drawingImage = image.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    }
    
    var entities: [MediaEditorComposerEntity] = []
    for entity in values.entities {
        entities.append(contentsOf: composerEntitiesForDrawingEntity(account: account, textScale: textScale, entity: entity.entity, colorSpace: colorSpace))
    }
    
    makeEditorImageFrameComposition(context: context, inputImage: inputImage, gradientImage: gradientImage, drawingImage: drawingImage, dimensions: dimensions, outputDimensions: dimensions, values: values, entities: entities, time: time, textScale: textScale, completion: { ciImage in
        if let ciImage {
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

private func makeEditorImageFrameComposition(context: CIContext, inputImage: CIImage, gradientImage: CIImage, drawingImage: CIImage?, dimensions: CGSize, outputDimensions: CGSize, values: MediaEditorValues, entities: [MediaEditorComposerEntity], time: CMTime, textScale: CGFloat = 1.0, completion: @escaping (CIImage?) -> Void) {
    var resultImage = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: dimensions)).transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    resultImage = gradientImage.composited(over: resultImage)
    
    var mediaImage = inputImage.samplingLinear().transformed(by: CGAffineTransform(translationX: -inputImage.extent.midX, y: -inputImage.extent.midY))
    
    var initialScale: CGFloat
    if mediaImage.extent.height > mediaImage.extent.width {
        initialScale = max(dimensions.width / mediaImage.extent.width, dimensions.height / mediaImage.extent.height)
    } else {
        initialScale = dimensions.width / mediaImage.extent.width
    }
    
    var cropTransform = CGAffineTransform(translationX: values.cropOffset.x, y: values.cropOffset.y * -1.0)
    cropTransform = cropTransform.rotated(by: -values.cropRotation)
    cropTransform = cropTransform.scaledBy(x: initialScale * values.cropScale, y: initialScale * values.cropScale)
    mediaImage = mediaImage.transformed(by: cropTransform)
    resultImage = mediaImage.composited(over: resultImage)
    
    if let drawingImage {
        resultImage = drawingImage.samplingLinear().composited(over: resultImage)
    }
    
    let frameRate: Float = 30.0
    
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
        entity.image(for: time, frameRate: frameRate, context: context, completion: { image in
            if var image = image?.samplingLinear() {
                let resetTransform = CGAffineTransform(translationX: -image.extent.width / 2.0, y: -image.extent.height / 2.0)
                image = image.transformed(by: resetTransform)
                
                var baseScale: CGFloat = 1.0
                if let scale = entity.baseScale {
                    baseScale = scale
                } else if let _ = entity.baseDrawingSize {
//                    baseScale = textScale
                } else if let baseSize = entity.baseSize {
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
