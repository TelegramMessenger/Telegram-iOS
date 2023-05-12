import Foundation
import AVFoundation
import Metal
import MetalKit

final class ImageTextureSource: TextureSource {
    weak var output: TextureConsumer?
    
    var textureLoader: MTKTextureLoader?
    var texture: MTLTexture?
        
    init(image: UIImage, renderTarget: RenderTarget) {
        guard let device = renderTarget.mtlDevice, let cgImage = image.cgImage else {
            return
        }
        let textureLoader = MTKTextureLoader(device: device)
        self.textureLoader = textureLoader
        
        self.texture = try? textureLoader.newTexture(cgImage: cgImage, options: nil)
    }
    
    func start() {
        
    }
    
    func pause() {
        
    }
    
    func connect(to consumer: TextureConsumer) {
        self.output = consumer
        
        if let texture = self.texture {
            self.output?.consumeTexture(texture, rotation: .rotate0Degrees)
        }
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
