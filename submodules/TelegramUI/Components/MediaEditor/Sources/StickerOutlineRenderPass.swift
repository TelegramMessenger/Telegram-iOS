import Foundation
import UIKit
import Display
import Metal
import simd
import CoreImage

private let maxBorderWidth: Float = 40.0

final class StickerOutlineRenderPass: RenderPass {
    var value: simd_float1 = 0.0
    
    private var context: CIContext?
    
    private var edgeMaskFilter: CIFilter?
    private var edgeMaskImage: (CIImage, simd_float1)?
    
    private var maskFilter: CIFilter?
    private var alphaFilter: CIFilter?
    private var blendFilter: CIFilter?
    private var sourceAtopFilter: CIFilter?
    private var whiteImage: CIImage?
    
    private var outputTexture: MTLTexture?
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        self.context = CIContext(mtlDevice: device, options: [.workingColorSpace : CGColorSpaceCreateDeviceRGB()])
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard self.value > 0.005, let context = self.context else {
            return input
        }
        
        let width = self.value * maxBorderWidth
        
        if self.maskFilter == nil {
            self.edgeMaskFilter = CIFilter(name: "CIBlendWithMask")
            self.edgeMaskFilter?.setValue(CIImage(color: .clear), forKey: kCIInputBackgroundImageKey)
            
            self.maskFilter = CIFilter(name: "CIMorphologyMaximum")
           
            self.alphaFilter = CIFilter(name: "CIColorMatrix")
            self.alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
            self.alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
            self.alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
            self.alphaFilter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            self.blendFilter = CIFilter(name: "CIBlendWithMask")
            self.sourceAtopFilter = CIFilter(name: "CISourceAtopCompositing")
            self.whiteImage = CIImage(color: .white)
        }
        
        if self.edgeMaskImage == nil || self.edgeMaskImage?.1 != width {
            self.edgeMaskImage = (roundedCornersMaskImage(outlineWidth: CGFloat(width)), width)
        }
        
        self.edgeMaskFilter?.setValue(CIImage(mtlTexture: input), forKey: kCIInputImageKey)
        self.edgeMaskFilter?.setValue(self.edgeMaskImage?.0, forKey: kCIInputMaskImageKey)
        
        guard let image = self.edgeMaskFilter?.outputImage else {
            return input
        }
        
        guard let maskFilter = self.maskFilter else {
            return input
        }
        
        maskFilter.setValue(width, forKey: kCIInputRadiusKey)
        maskFilter.setValue(image, forKey: kCIInputImageKey)
        
        guard let eroded = maskFilter.outputImage else {
            return input
        }
        
        self.sourceAtopFilter?.setValue(self.whiteImage, forKey: kCIInputImageKey)
        self.sourceAtopFilter?.setValue(eroded, forKey: kCIInputBackgroundImageKey)
        
        guard let colorizedImage = self.sourceAtopFilter?.outputImage?.cropped(to: eroded.extent) else {
            return input
        }
        
        self.alphaFilter?.setValue(image, forKey: kCIInputImageKey)

        guard let alphaOnlyImage = self.alphaFilter?.outputImage, let whiteImage = self.whiteImage else {
            return input
        }
        
        let blendMask = alphaOnlyImage.composited(over: whiteImage).cropped(to: alphaOnlyImage.extent)
        
        self.blendFilter?.setValue(colorizedImage, forKey: kCIInputImageKey)
        self.blendFilter?.setValue(blendMask, forKey: kCIInputMaskImageKey)
        self.blendFilter?.setValue(CIImage(color: .clear), forKey: kCIInputBackgroundImageKey)
        
        guard let outline = self.blendFilter?.outputImage else {
            return input
        }
        
        var resultImage = outline.composited(over: image)
        resultImage = outline.composited(over: resultImage)
        
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
        
        guard let outputTexture = self.outputTexture else {
            return input
        }
        
        let renderDestination = CIRenderDestination(mtlTexture: outputTexture, commandBuffer: commandBuffer)
        _ = try? context.startTask(toRender: resultImage, to: renderDestination)
        return outputTexture
    }
}

private func roundedCornersMaskImage(outlineWidth: CGFloat) -> CIImage {
    let rectSize = CGSize(width: floor(1080.0 * 0.97) - outlineWidth * 2.0, height: floor(1080.0 * 0.97) - outlineWidth * 2.0)
    let cornerRadius = floor(1080.0 * 0.97) / 8.0 - outlineWidth
    let image = generateImage(CGSize(width: 1080.0, height: 1920.0), opaque: true, scale: 1.0) { size, context in
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.addPath(CGPath(roundedRect: CGRect(origin: CGPoint(x: floor((1080.0 - rectSize.width) / 2.0), y: floor((1920.0 - rectSize.width) / 2.0)), size: rectSize), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
    }?.cgImage
    return CIImage(cgImage: image!)
}
