import Foundation
import Metal
import simd
import CoreImage

final class StickerOutlineRenderPass: RenderPass {
    var value: simd_float1 = 0.0
    
    var context: CIContext?
    var maskFilter: CIFilter?
    
    private var outputTexture: MTLTexture?
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        self.context = CIContext(mtlDevice: device, options: [.workingColorSpace : CGColorSpaceCreateDeviceRGB()])
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard self.value > 0.005, let context = self.context else {
            return input
        }

        if self.maskFilter == nil {
            self.maskFilter = CIFilter(name: "CIMorphologyMaximum")
        }
        if self.outputTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = input.width
            textureDescriptor.height = input.height
            textureDescriptor.pixelFormat = input.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return nil
            }
            self.outputTexture = texture
            texture.label = "outlineOutputTexture"
        }
        guard let maskFilter = self.maskFilter, let image = CIImage(mtlTexture: input) else {
            return input
        }
        
        maskFilter.setValue(self.value * 30, forKey: kCIInputRadiusKey)
        maskFilter.setValue(image, forKey: kCIInputImageKey)
        
        guard let eroded = maskFilter.outputImage, let outputTexture = self.outputTexture else {
            return input
        }

        if #available(iOS 13.0, *) {
            let colorized = CIBlendKernel.sourceAtop.apply(foreground: .white, background: eroded)!.cropped(to: eroded.extent)
            let resultImage = image.composited(over: colorized)
            
            let renderDestination = CIRenderDestination(mtlTexture: outputTexture, commandBuffer: commandBuffer)
            _ = try? context.startTask(toRender: resultImage, to: renderDestination)
            return outputTexture
        } else {
            return input
        }
    }
}
