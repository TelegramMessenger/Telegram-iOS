import Foundation
import Metal
import simd

fileprivate struct VertexData {
    let pos: simd_float4
    let texCoord: simd_float2
}

enum TextureRotation: Int {
    case rotate0Degrees
    case rotate90Degrees
    case rotate180Degrees
    case rotate270Degrees
}

private func verticesDataForRotation(_ rotation: TextureRotation) -> [VertexData] {
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
    case .rotate270Degrees:
        topLeft = simd_float2(0.0, 0.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(1.0, 1.0)
    }
    
    return [
        VertexData(
            pos: simd_float4(x: -1, y: -1, z: 0, w: 1),
            texCoord: topLeft
        ),
        VertexData(
            pos: simd_float4(x: 1, y: -1, z: 0, w: 1),
            texCoord: topRight
        ),
        VertexData(
            pos: simd_float4(x: -1, y: 1, z: 0, w: 1),
            texCoord: bottomLeft
        ),
        VertexData(
            pos: simd_float4(x: 1, y: 1, z: 0, w: 1),
            texCoord: bottomRight
        ),
    ]
}

func textureDimensionsForRotation(texture: MTLTexture, rotation: TextureRotation) -> (width: Int, height: Int) {
    switch rotation {
    case .rotate90Degrees, .rotate270Degrees:
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
    
    func setupVerticesBuffer(device: MTLDevice, rotation: TextureRotation) {
        if self.verticesBuffer == nil || rotation != self.textureRotation {
            self.textureRotation = rotation
            let vertices = verticesDataForRotation(rotation)
            self.verticesBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<VertexData>.stride * vertices.count,
                options: [])
        }
    }
    
    func process(input: MTLTexture, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device, rotation: rotation)
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
    
    override func process(input: MTLTexture, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let renderTarget = self.renderTarget, let renderPassDescriptor = renderTarget.renderPassDescriptor else {
            return nil
        }
        self.setupVerticesBuffer(device: device, rotation: rotation)
        
        let drawableSize = renderTarget.drawableSize
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor)!
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0.0, originY: 0.0,
            width: Double(drawableSize.width), height: Double(drawableSize.height),
            znear: -1.0, zfar: 1.0))
        
        do {
            var texCoordScales = simd_float2(x: 1.0, y: 1.0)
            var scaleFactor = drawableSize.width / CGFloat(input.width)
            let textureFitHeight = CGFloat(input.height) * scaleFactor
            if textureFitHeight > drawableSize.height {
                scaleFactor = drawableSize.height / CGFloat(input.height)
                let textureFitWidth = CGFloat(input.width) * scaleFactor
                let texCoordsScaleX = textureFitWidth / drawableSize.width
                texCoordScales.x = Float(texCoordsScaleX)
            } else {
                let texCoordsScaleY = textureFitHeight / drawableSize.height
                texCoordScales.y = Float(texCoordsScaleY)
            }
            
            renderCommandEncoder.setFragmentBytes(&texCoordScales, length: MemoryLayout<simd_float2>.stride, index: 0)
            renderCommandEncoder.setFragmentTexture(input, index: 0)
        }
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        if let drawable = renderTarget.drawable {
            commandBuffer.present(drawable)
        }
        
        return nil
    }
}
