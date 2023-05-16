import Foundation
import Metal
import simd

struct MediaEditorAdjustments {
    var dimensions: simd_float2
    var aspectRatio: simd_float1
    var shadows: simd_float1
    var highlights: simd_float1
    var contrast: simd_float1
    var fade: simd_float1
    var saturation: simd_float1
    var shadowsTintIntensity: simd_float1
    var shadowsTintColor: simd_float3
    var highlightsTintIntensity: simd_float1
    var highlightsTintColor: simd_float3
    var exposure: simd_float1
    var warmth: simd_float1
    var grain: simd_float1
    var vignette: simd_float1
}

final class AdjustmentsRenderPass: DefaultRenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    var adjustments = MediaEditorAdjustments(
        dimensions: simd_float2(1.0, 1.0),
        aspectRatio: 0.0,
        shadows: 0.0,
        highlights: 0.0,
        contrast: 0.0,
        fade: 0.0,
        saturation: 0.0,
        shadowsTintIntensity: 0.0,
        shadowsTintColor: simd_float3(0.0, 0.0, 0.0),
        highlightsTintIntensity: 0.0,
        highlightsTintColor: simd_float3(0.0, 0.0, 0.0),
        exposure: 0.0,
        warmth: 0.0,
        grain: 0.0,
        vignette: 0.0
    )
    
    var allCurve: [Float] = Array(repeating: 0, count: 200)
    var redCurve: [Float] = Array(repeating: 0, count: 200)
    var greenCurve: [Float] = Array(repeating: 0, count: 200)
    var blueCurve: [Float] = Array(repeating: 0, count: 200)
    
    override var fragmentShaderFunctionName: String {
        return "adjustmentsFragmentShader"
    }
        
    override func process(input: MTLTexture, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device, rotation: rotation)
        
        let (width, height) = textureDimensionsForRotation(texture: input, rotation: rotation)
        
        if self.cachedTexture == nil || self.cachedTexture?.width != width || self.cachedTexture?.height != height {
            self.adjustments.dimensions = simd_float2(Float(width), Float(height))
            self.adjustments.aspectRatio = Float(width) / Float(height)
            
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = width
            textureDescriptor.height = height
            textureDescriptor.pixelFormat = input.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return input
            }
            self.cachedTexture = texture
            texture.label = "adjustmentsTexture"
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
        renderCommandEncoder.setFragmentBytes(&self.adjustments, length: MemoryLayout<MediaEditorAdjustments>.size, index: 0)
        
        let allCurve = self.allCurve
        let redCurve = self.redCurve
        let greenCurve = self.greenCurve
        let blueCurve = self.blueCurve
        
        renderCommandEncoder.setFragmentBytes(allCurve, length: MemoryLayout<Float>.size * 200, index: 1)
        renderCommandEncoder.setFragmentBytes(redCurve, length: MemoryLayout<Float>.size * 200, index: 2)
        renderCommandEncoder.setFragmentBytes(greenCurve, length: MemoryLayout<Float>.size * 200, index: 3)
        renderCommandEncoder.setFragmentBytes(blueCurve, length: MemoryLayout<Float>.size * 200, index: 4)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
}
