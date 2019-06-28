import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Metal

#if false//!targetEnvironment(simulator)

final class MetalAnimationRenderer: ASDisplayNode, AnimationRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let commandQueue: MTLCommandQueue
    private let vertexBuffer: MTLBuffer
    private let colorTexture: MTLTexture
    private let alphaTexture: MTLTexture
    private let samplerColor: MTLSamplerState
    private let samplerAlpha: MTLSamplerState
    
    private var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }
    
    override init() {
        let device = MTLCreateSystemDefaultDevice()!
        
        self.device = device
        
        do {
            let library = try device.makeLibrary(source:
                """
using namespace metal;

struct VertexIn {
  packed_float3 position;
  packed_float2 texCoord;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

vertex VertexOut basic_vertex(
    const device VertexIn* vertex_array [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
  VertexIn VertexIn = vertex_array[vid];
  
  VertexOut VertexOut;
  VertexOut.position = float4(VertexIn.position, 1.0);
  VertexOut.texCoord = VertexIn.texCoord;
  
  return VertexOut;
}

fragment float4 basic_fragment(
    VertexOut interpolated [[stage_in]],
    texture2d<float> texColor [[ texture(0) ]],
    sampler samplerColor [[ sampler(0) ]]//,
    //texture2d<float> texA [[ texture(1) ]],
    //sampler samplerA [[ sampler(1) ]]
) {
    float4 color = texColor.sample(samplerColor, interpolated.texCoord);
    float4 alpha = 1.0;//texA.sample(samplerA, interpolated.texCoord);
    return float4(color.r * alpha.a, color.g * alpha.a, color.b * alpha.a, alpha.a);
}
""", options: nil)
            
            let fragmentProgram = library.makeFunction(name: "basic_fragment")
            let vertexProgram = library.makeFunction(name: "basic_vertex")
            
            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = vertexProgram
            pipelineStateDescriptor.fragmentFunction = fragmentProgram
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            
            self.commandQueue = device.makeCommandQueue()!
            
            let vertexData: [Float] = [
                -1.0, -1.0, 0.0, 0.0, 1.0,
                -1.0, 1.0, 0.0, 0.0, 0.0,
                1.0, -1.0, 0.0, 1.0, 1.0,
                1.0, -1.0, 0.0, 1.0, 1.0,
                -1.0, 1.0, 0.0, 0.0, 0.0,
                1.0, 1.0, 0.0, 1.0, 0.0
            ]
            
            let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
            self.vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!
            
            let colorTextureDesc: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .pvrtc_rgb_4bpp, width: 512, height: 512, mipmapped: false)
            colorTextureDesc.sampleCount = 1
            if #available(iOS 9.0, *) {
                colorTextureDesc.storageMode = .private
                colorTextureDesc.usage = .shaderRead
            }
            colorTextureDesc.textureType = .type2D
            
            self.colorTexture = device.makeTexture(descriptor: colorTextureDesc)!
            
            let alphaTextureDesc: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .a8Unorm, width: 320, height: 320, mipmapped: false)
            alphaTextureDesc.sampleCount = 1
            if #available(iOS 9.0, *) {
                alphaTextureDesc.storageMode = .private
                alphaTextureDesc.usage = .shaderRead
            }
            alphaTextureDesc.textureType = .type2D
            
            self.alphaTexture = device.makeTexture(descriptor: alphaTextureDesc)!
            
            let sampler = MTLSamplerDescriptor()
            sampler.minFilter = MTLSamplerMinMagFilter.nearest
            sampler.magFilter = MTLSamplerMinMagFilter.nearest
            sampler.mipFilter = MTLSamplerMipFilter.nearest
            sampler.maxAnisotropy = 1
            sampler.sAddressMode = MTLSamplerAddressMode.clampToEdge
            sampler.tAddressMode = MTLSamplerAddressMode.clampToEdge
            sampler.rAddressMode = MTLSamplerAddressMode.clampToEdge
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp = 0.0
            sampler.lodMaxClamp = .greatestFiniteMagnitude
            self.samplerColor = device.makeSamplerState(descriptor: sampler)!
            self.samplerAlpha = device.makeSamplerState(descriptor: sampler)!
        } catch let e {
            print(e)
            preconditionFailure()
        }
        
        super.init()
        
        self.setLayerBlock { () -> CALayer in
            return CAMetalLayer()
        }
        
        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = true
        self.metalLayer.isOpaque = false
        self.metalLayer.contentsScale = 2.0
    }
    
    func render(queue: Queue, width: Int, height: Int, bytes: UnsafeRawPointer, length: Int, completion: @escaping () -> Void) {
        if self.metalLayer.bounds.width.isZero {
            return
        }
        
        let bgrgLength = width * 2 * height
        //let alphaLength = width * height
        
        self.colorTexture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes.assumingMemoryBound(to: UInt8.self), bytesPerRow: width / 2)
        //self.alphaTexture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes.assumingMemoryBound(to: UInt8.self).advanced(by: bgrgLength), bytesPerRow: width)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let drawable = self.metalLayer.nextDrawable()!
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(self.pipelineState)
        renderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(self.colorTexture, index: 0)
        renderEncoder.setFragmentSamplerState(self.samplerColor, index: 0)
        renderEncoder.setFragmentTexture(self.alphaTexture, index: 1)
        renderEncoder.setFragmentSamplerState(self.samplerAlpha, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

#endif
