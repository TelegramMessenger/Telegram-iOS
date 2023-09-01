import Foundation
import AVFoundation
import Metal
import MetalKit
import Display
import Accelerate

func loadTexture(image: UIImage, device: MTLDevice) -> MTLTexture? {
    func dataForImage(_ image: UIImage) -> UnsafeMutablePointer<UInt8> {
        let imageRef = image.cgImage
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        let bytePerPixel = 4
        let bytesPerRow = bytePerPixel * Int(width)
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue + CGImageAlphaInfo.premultipliedFirst.rawValue
        let context = CGContext.init(data: rawData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        context?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return rawData
    }
    
    let width = Int(image.size.width * image.scale)
    let height = Int(image.size.height * image.scale)
    let bytePerPixel = 4
    let bytesPerRow = bytePerPixel * width
    
    var texture : MTLTexture?
    let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    texture = device.makeTexture(descriptor: textureDescriptor)
    
    let data = dataForImage(image)
    texture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
    
    return texture
}

final class ImageTextureSource: TextureSource {
    weak var output: TextureConsumer?
    
    var texture: MTLTexture?
        
    init(image: UIImage, renderTarget: RenderTarget) {
        if let device = renderTarget.mtlDevice {
            self.texture = loadTexture(image: image, device: device)
        }
    }
    
    func connect(to consumer: TextureConsumer) {
        self.output = consumer
        if let texture = self.texture {
            self.output?.consumeTexture(texture, render: false)
        }
    }
    
    func invalidate() {
        self.texture = nil
    }
}

func pixelBufferToMTLTexture(pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache) -> MTLTexture? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    let format: MTLPixelFormat = .r8Unorm
    var textureRef : CVMetalTexture?
    let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, format, width, height, 0, &textureRef)
    if status == kCVReturnSuccess {
        return CVMetalTextureGetTexture(textureRef!)
    }

    return nil
}

func getTextureImage(device: MTLDevice, texture: MTLTexture, mirror: Bool = false) -> UIImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CIContext(mtlDevice: device, options: [:])
    guard var ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace]) else {
        return nil
    }
    let transform: CGAffineTransform
    if mirror {
        transform = CGAffineTransform(-1.0, 0.0, 0.0, -1.0, ciImage.extent.width, ciImage.extent.height)
    } else {
        transform = CGAffineTransform(1.0, 0.0, 0.0, -1.0, 0.0, ciImage.extent.height)
    }
    ciImage = ciImage.transformed(by: transform)
    guard let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: CGSize(width: ciImage.extent.width, height: ciImage.extent.height))) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}
