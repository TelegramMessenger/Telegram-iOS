import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreImage

final class VideoInputPass: DefaultRenderPass {
    private var cachedTexture: MTLTexture?
    
    override var fragmentShaderFunctionName: String {
        return "bt709ToRGBFragmentShader"
    }
    
    override func setup(device: MTLDevice, library: MTLLibrary) {
        super.setup(device: device, library: library)
    }
    
    func processPixelBuffer(_ pixelBuffer: VideoPixelBuffer, textureCache: CVMetalTextureCache, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        func textureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, width: Int, height: Int, plane: Int) -> MTLTexture? {
            var textureRef : CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, plane, &textureRef)
            if status == kCVReturnSuccess, let textureRef {
                return CVMetalTextureGetTexture(textureRef)
            }
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer.pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer.pixelBuffer)
        guard let inputYTexture = textureFromPixelBuffer(pixelBuffer.pixelBuffer, pixelFormat: .r8Unorm, width: width, height: height, plane: 0),
              let inputCbCrTexture = textureFromPixelBuffer(pixelBuffer.pixelBuffer, pixelFormat: .rg8Unorm, width: width >> 1, height: height >> 1, plane: 1) else {
            return nil
        }
        return self.process(yTexture: inputYTexture, cbcrTexture: inputCbCrTexture, width: width, height: height, rotation: pixelBuffer.rotation, device: device, commandBuffer: commandBuffer)
    }
    
    func process(yTexture: MTLTexture, cbcrTexture: MTLTexture, width: Int, height: Int, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device, rotation: rotation)
        
        func textureDimensionsForRotation(width: Int, height: Int, rotation: TextureRotation) -> (width: Int, height: Int) {
            switch rotation {
            case .rotate90Degrees, .rotate270Degrees, .rotate90DegreesMirrored:
                return (height, width)
            default:
                return (width, height)
            }
        }
        
        let (outputWidth, outputHeight) = textureDimensionsForRotation(width: width, height: height, rotation: rotation)
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = outputWidth
            textureDescriptor.height = outputHeight
            textureDescriptor.pixelFormat = self.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            if let texture = device.makeTexture(descriptor: textureDescriptor) {
                self.cachedTexture = texture
            }
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(outputWidth), height: Double(outputHeight),
            znear: -1.0, zfar: 1.0)
        )
        
        renderCommandEncoder.setFragmentTexture(yTexture, index: 0)
        renderCommandEncoder.setFragmentTexture(cbcrTexture, index: 1)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture
    }
}

final class CIInputPass: RenderPass {
    private var context: CIContext?
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        self.context = CIContext(mtlDevice: device, options: [.workingColorSpace : CGColorSpaceCreateDeviceRGB()])
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return nil
    }
    
    private var outputTexture: MTLTexture?
    
    func processCIImage(_ ciImage: CIImage, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        if self.outputTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = Int(ciImage.extent.width)
            textureDescriptor.height = Int(ciImage.extent.height)
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return nil
            }
            self.outputTexture = texture
            texture.label = "outlineOutputTexture"
        }
        
        guard let outputTexture = self.outputTexture, let context = self.context else {
            return nil
        }
        
        let transformedImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
        let renderDestination = CIRenderDestination(mtlTexture: outputTexture, commandBuffer: commandBuffer)
        _ = try? context.startTask(toRender: transformedImage, to: renderDestination)
        
        return outputTexture
    }
}
