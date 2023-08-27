import Foundation
import Metal
import simd

final class SharpenRenderPass: RenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    var value: simd_float1 = 0.0
     
    func setup(device: MTLDevice, library: MTLLibrary) {
    
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return input
    }
}
