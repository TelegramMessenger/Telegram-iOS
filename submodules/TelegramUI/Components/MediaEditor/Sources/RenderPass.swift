import Foundation
import QuartzCore
import Metal
import simd

struct VertexData {
    let pos: simd_float4
    let texCoord: simd_float2
    let localPos: simd_float2
}

enum TextureRotation: Int {
    case rotate0Degrees
    case rotate0DegreesMirrored
    case rotate90Degrees
    case rotate180Degrees
    case rotate270Degrees
    case rotate90DegreesMirrored
}

func verticesDataForRotation(_ rotation: TextureRotation, rect: CGRect = CGRect(x: -0.5, y: -0.5, width: 1.0, height: 1.0), z: Float = 0.0) -> [VertexData] {
    let topLeft: simd_float2
    let topRight: simd_float2
    let bottomLeft: simd_float2
    let bottomRight: simd_float2
    
    switch rotation {
    case .rotate0Degrees:
        topLeft = simd_float2(0.0, 1.0)
        topRight = simd_float2(1.0, 1.0)
        bottomLeft = simd_float2(0.0, 0.0)
        bottomRight = simd_float2(1.0, 0.0)
    case .rotate0DegreesMirrored:
        topLeft = simd_float2(1.0, 1.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(0.0, 0.0)
    case .rotate180Degrees:
        topLeft = simd_float2(1.0, 0.0)
        topRight = simd_float2(0.0, 0.0)
        bottomLeft = simd_float2(1.0, 1.0)
        bottomRight = simd_float2(0.0, 1.0)
    case .rotate90Degrees:
        topLeft = simd_float2(1.0, 1.0)
        topRight = simd_float2(1.0, 0.0)
        bottomLeft = simd_float2(0.0, 1.0)
        bottomRight = simd_float2(0.0, 0.0)
    case .rotate90DegreesMirrored:
        topLeft = simd_float2(1.0, 0.0)
        topRight = simd_float2(1.0, 1.0)
        bottomLeft = simd_float2(0.0, 0.0)
        bottomRight = simd_float2(0.0, 1.0)
    case .rotate270Degrees:
        topLeft = simd_float2(0.0, 0.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(1.0, 1.0)
    }
    
    return [
        VertexData(
            pos: simd_float4(x: Float(rect.minX) * 2.0, y: Float(rect.minY) * 2.0, z: z, w: 1),
            texCoord: topLeft,
            localPos: simd_float2(0.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(x: Float(rect.maxX) * 2.0, y: Float(rect.minY) * 2.0, z: z, w: 1),
            texCoord: topRight,
            localPos: simd_float2(1.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(x: Float(rect.minX) * 2.0, y: Float(rect.maxY) * 2.0, z: z, w: 1),
            texCoord: bottomLeft,
            localPos: simd_float2(0.0, 1.0)
        ),
        VertexData(
            pos: simd_float4(x: Float(rect.maxX) * 2.0, y: Float(rect.maxY) * 2.0, z: z, w: 1),
            texCoord: bottomRight,
            localPos: simd_float2(1.0, 1.0)
        ),
    ]
}

func textureDimensionsForRotation(texture: MTLTexture, rotation: TextureRotation) -> (width: Int, height: Int) {
    switch rotation {
    case .rotate90Degrees, .rotate90DegreesMirrored, .rotate270Degrees:
        return (texture.height, texture.width)
    default:
        return (texture.width, texture.height)
    }
}

class DefaultRenderPass: RenderPass {
    fileprivate var pipelineState: MTLRenderPipelineState?
    fileprivate var verticesBuffer: MTLBuffer?
    fileprivate var textureRotation: TextureRotation = .rotate0Degrees
    
    var vertexShaderFunctionName: String {
        return "defaultVertexShader"
    }
    
    var fragmentShaderFunctionName: String {
        return "defaultFragmentShader"
    }
    
    var pixelFormat: MTLPixelFormat  {
        return .bgra8Unorm
    }
    
    func setup(device: MTLDevice, library: MTLLibrary) {        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: self.vertexShaderFunctionName)
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: self.fragmentShaderFunctionName)
        pipelineDescriptor.colorAttachments[0].pixelFormat = self.pixelFormat
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func setupVerticesBuffer(device: MTLDevice, rotation: TextureRotation = .rotate0Degrees) {
        if self.verticesBuffer == nil || rotation != self.textureRotation {
            self.textureRotation = rotation
            let vertices = verticesDataForRotation(rotation)
            self.verticesBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<VertexData>.stride * vertices.count,
                options: [])
        }
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device)
        return nil
    }
    
    func encodeDefaultCommands(using encoder: MTLRenderCommandEncoder) {
        guard let pipelineState = self.pipelineState, let verticesBuffer = self.verticesBuffer else {
            return
        }
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(verticesBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}

final class OutputRenderPass: DefaultRenderPass {
    weak var renderTarget: RenderTarget?
    
    @discardableResult
    override func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let renderTarget = self.renderTarget else {
            return nil
        }
        self.setupVerticesBuffer(device: device)
        
        autoreleasepool {
            guard let drawable = renderTarget.drawable else {
                return
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = (drawable as? CAMetalDrawable)?.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            
            let drawableSize = renderTarget.drawableSize
            
            let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)!
            
            renderCommandEncoder.setViewport(MTLViewport(
                originX: 0.0, originY: 0.0,
                width: Double(drawableSize.width), height: Double(drawableSize.height),
                znear: -1.0, zfar: 1.0))
            
            
            renderCommandEncoder.setFragmentTexture(input, index: 0)
            
            self.encodeDefaultCommands(using: renderCommandEncoder)
            
            renderCommandEncoder.endEncoding()
            
            commandBuffer.present(drawable)
        }
        
        return nil
    }
}
