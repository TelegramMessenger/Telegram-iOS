import Foundation
import AVFoundation
import UIKit
import CoreImage
import Metal
import Display

final class MediaEditorComposer {
    let device: MTLDevice?
    
    private let values: MediaEditorValues
    private let dimensions: CGSize
    
    private let ciContext: CIContext?
    private var textureCache: CVMetalTextureCache?
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    
    private var gradientImage: CIImage
        
    let semaphore = DispatchSemaphore(value: 1)
    
    init(values: MediaEditorValues, dimensions: CGSize) {
        self.values = values
        self.dimensions = dimensions
        
        self.renderer.externalSemaphore = self.semaphore
        self.renderer.addRenderChain(self.renderChain)
        self.renderer.addRenderPass(ComposerRenderPass())
        
        if let gradientColors = values.gradientColors {
            let image = generateGradientImage(size: dimensions, scale: 1.0, colors: gradientColors, locations: [0.0, 1.0])!
            self.gradientImage = CIImage(image: image)!.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
        } else {
            self.gradientImage = CIImage(color: .black)
        }
        
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
    
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let textureCache = self.textureCache, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let pool = pool else {
            return nil
        }
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
                
                if let composition = processImage(inputImage: ciImage), let pixelBuffer {
                    self.ciContext?.render(composition, to: pixelBuffer)
                    
                    return pixelBuffer
                } else {
                    return nil
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func processImage(inputImage: CIImage) -> CIImage? {
        return makeEditorImageFrameComposition(inputImage: inputImage, gradientImage: self.gradientImage, dimensions: self.dimensions, values: self.values)
    }
}

public func makeEditorImageComposition(inputImage: UIImage, dimensions: CGSize, values: MediaEditorValues) -> UIImage? {
    let inputImage = CIImage(image: inputImage)!
    let gradientImage: CIImage
    if let gradientColors = values.gradientColors {
        let image = generateGradientImage(size: dimensions, scale: 1.0, colors: gradientColors, locations: [0.0, 1.0])!
        gradientImage = CIImage(image: image)!.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    } else {
        gradientImage = CIImage(color: .black)
    }
    if let ciImage = makeEditorImageFrameComposition(inputImage: inputImage, gradientImage: gradientImage, dimensions: dimensions, values: values) {
        let context = CIContext(options: [.workingColorSpace : NSNull()])
        if let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: ciImage.extent.size)) {
            return UIImage(cgImage: cgImage)
        }
    }
    return nil
}

private func makeEditorImageFrameComposition(inputImage: CIImage, gradientImage: CIImage, dimensions: CGSize, values: MediaEditorValues) -> CIImage? {
    var resultImage = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: dimensions)).transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    resultImage = gradientImage.composited(over: resultImage)
    
    var mediaImage = inputImage.transformed(by: CGAffineTransform(translationX: -inputImage.extent.midX, y: -inputImage.extent.midY))
    
    var cropTransform = CGAffineTransform(translationX: values.cropOffset.x, y: values.cropOffset.y * -1.0)
    cropTransform = cropTransform.rotated(by: -values.cropRotation)
    cropTransform = cropTransform.scaledBy(x: values.cropScale, y: values.cropScale)
    mediaImage = mediaImage.transformed(by: cropTransform)

    resultImage = mediaImage.composited(over: resultImage)
                    
    return resultImage.transformed(by: CGAffineTransform(translationX: dimensions.width / 2.0, y: dimensions.height / 2.0))
}

extension CMSampleBuffer {
    func newSampleBufferWithReplacedImageBuffer(_ imageBuffer: CVImageBuffer) -> CMSampleBuffer? {
        guard let _ = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        var timingInfo = CMSampleTimingInfo()
        guard CMSampleBufferGetSampleTimingInfo(self, at: 0, timingInfoOut: &timingInfo) == 0 else {
            return nil
        }
        var outputSampleBuffer: CMSampleBuffer?
        var newFormatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: imageBuffer, formatDescriptionOut: &newFormatDescription)
        guard let formatDescription = newFormatDescription else {
            return nil
        }
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: imageBuffer, formatDescription: formatDescription, sampleTiming: &timingInfo, sampleBufferOut: &outputSampleBuffer)
        return outputSampleBuffer
    }
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
