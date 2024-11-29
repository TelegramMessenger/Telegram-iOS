import Foundation
import UIKit
import SwiftSignalKit
import MetalKit
import MetalPerformanceShaders
import Accelerate
import MetalEngine

public final class VideoSourceOutput {
    public struct MirrorDirection: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let horizontal = MirrorDirection(rawValue: 1 << 0)
        public static let vertical = MirrorDirection(rawValue: 1 << 1)
    }
    
    open class DataBuffer {
        open var pixelBuffer: CVPixelBuffer? {
            return nil
        }
        
        public init() {
        }
    }
    
    public final class BiPlanarTextureLayout {
        public let y: MTLTexture
        public let uv: MTLTexture
        
        public init(y: MTLTexture, uv: MTLTexture) {
            self.y = y
            self.uv = uv
        }
    }
    
    public final class TriPlanarTextureLayout {
        public let y: MTLTexture
        public let u: MTLTexture
        public let v: MTLTexture
        
        public init(y: MTLTexture, u: MTLTexture, v: MTLTexture) {
            self.y = y
            self.u = u
            self.v = v
        }
    }
    
    public enum TextureLayout {
        case biPlanar(BiPlanarTextureLayout)
        case triPlanar(TriPlanarTextureLayout)
    }
    
    public final class NativeDataBuffer: DataBuffer {
        private let pixelBufferValue: CVPixelBuffer
        override public var pixelBuffer: CVPixelBuffer? {
            return self.pixelBufferValue
        }
        
        public init(pixelBuffer: CVPixelBuffer) {
            self.pixelBufferValue = pixelBuffer
        }
    }
    
    public let resolution: CGSize
    public let textureLayout: TextureLayout
    public let dataBuffer: DataBuffer
    public let mirrorDirection: MirrorDirection
    public let sourceId: Int
    
    public init(resolution: CGSize, textureLayout: TextureLayout, dataBuffer: DataBuffer, mirrorDirection: MirrorDirection, sourceId: Int) {
        self.resolution = resolution
        self.textureLayout = textureLayout
        self.dataBuffer = dataBuffer
        self.mirrorDirection = mirrorDirection
        self.sourceId = sourceId
    }
}

public protocol VideoSource: AnyObject {
    typealias Output = VideoSourceOutput
    
    var currentOutput: Output? { get }
    
    func addOnUpdated(_ f: @escaping () -> Void) -> Disposable
}

final class CameraVideoLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    public var internalData: MetalEngineSubjectInternalData?
    
    public let blurredLayer: MetalEngineSubjectLayer
    
    final class BlurState: ComputeState {
        let computePipelineStateYUVBiPlanarToRGBA: MTLComputePipelineState
        let computePipelineStateYUVTriPlanarToRGBA: MTLComputePipelineState
        let computePipelineStateHorizontal: MTLComputePipelineState
        let computePipelineStateVertical: MTLComputePipelineState
        let downscaleKernel: MPSImageBilinearScale
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            
            guard let functionVideoBiPlanarToRGBA = library.makeFunction(name: "videoBiPlanarToRGBA") else {
                return nil
            }
            guard let computePipelineStateYUVBiPlanarToRGBA = try? device.makeComputePipelineState(function: functionVideoBiPlanarToRGBA) else {
                return nil
            }
            self.computePipelineStateYUVBiPlanarToRGBA = computePipelineStateYUVBiPlanarToRGBA
            
            guard let functionVideoTriPlanarToRGBA = library.makeFunction(name: "videoTriPlanarToRGBA") else {
                return nil
            }
            guard let computePipelineStateYUVTriPlanarToRGBA = try? device.makeComputePipelineState(function: functionVideoTriPlanarToRGBA) else {
                return nil
            }
            self.computePipelineStateYUVTriPlanarToRGBA = computePipelineStateYUVTriPlanarToRGBA
            
            guard let gaussianBlurHorizontal = library.makeFunction(name: "gaussianBlurHorizontal"), let gaussianBlurVertical = library.makeFunction(name: "gaussianBlurVertical") else {
                return nil
            }
            guard let computePipelineStateHorizontal = try? device.makeComputePipelineState(function: gaussianBlurHorizontal) else {
                return nil
            }
            self.computePipelineStateHorizontal = computePipelineStateHorizontal
            
            guard let computePipelineStateVertical = try? device.makeComputePipelineState(function: gaussianBlurVertical) else {
                return nil
            }
            self.computePipelineStateVertical = computePipelineStateVertical
            
            self.downscaleKernel = MPSImageBilinearScale(device: device)
        }
    }
    
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "mainVideoVertex"), let fragmentFunction = library.makeFunction(name: "mainVideoFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    public var video: VideoSource.Output? {
        didSet {
            self.setNeedsUpdate()
        }
    }
    
    public var renderSpec: RenderLayerSpec?
    
    private var rgbaTexture: PooledTexture?
    private var downscaledTexture: PooledTexture?
    private var blurredHorizontalTexture: PooledTexture?
    private var blurredVerticalTexture: PooledTexture?
    
    override public init() {
        self.blurredLayer = MetalEngineSubjectLayer()
        
        super.init()
    }
    
    override public init(layer: Any) {
        self.blurredLayer = MetalEngineSubjectLayer()
        
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(context: MetalEngineSubjectContext) {
        if self.isHidden {
            return
        }
        guard let renderSpec = self.renderSpec else {
            return
        }
        guard let videoTextures = self.video else {
            return
        }
        
        let rgbaTextureSpec = TextureSpec(width: Int(videoTextures.resolution.width), height: Int(videoTextures.resolution.height), pixelFormat: .rgba8UnsignedNormalized)
        if self.rgbaTexture == nil || self.rgbaTexture?.spec != rgbaTextureSpec {
            self.rgbaTexture = MetalEngine.shared.pooledTexture(spec: rgbaTextureSpec)
        }
        if self.downscaledTexture == nil {
            self.downscaledTexture = MetalEngine.shared.pooledTexture(spec: TextureSpec(width: 256, height: 256, pixelFormat: .rgba8UnsignedNormalized))
        }
        if self.blurredHorizontalTexture == nil {
            self.blurredHorizontalTexture = MetalEngine.shared.pooledTexture(spec: TextureSpec(width: 256, height: 256, pixelFormat: .rgba8UnsignedNormalized))
        }
        if self.blurredVerticalTexture == nil {
            self.blurredVerticalTexture = MetalEngine.shared.pooledTexture(spec: TextureSpec(width: 256, height: 256, pixelFormat: .rgba8UnsignedNormalized))
        }
        
        guard let rgbaTexture = self.rgbaTexture?.get(context: context) else {
            return
        }
        
        let _ = context.compute(state: BlurState.self, inputs: rgbaTexture.placeholer, commands: { commandBuffer, blurState, rgbaTexture in
            guard let rgbaTexture else {
                return
            }
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            
            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroupCount = MTLSize(width: (rgbaTexture.width + threadgroupSize.width - 1) / threadgroupSize.width, height: (rgbaTexture.height + threadgroupSize.height - 1) / threadgroupSize.height, depth: 1)
            
            switch videoTextures.textureLayout {
            case let .biPlanar(biPlanar):
                computeEncoder.setComputePipelineState(blurState.computePipelineStateYUVBiPlanarToRGBA)
                computeEncoder.setTexture(biPlanar.y, index: 0)
                computeEncoder.setTexture(biPlanar.uv, index: 1)
                computeEncoder.setTexture(rgbaTexture, index: 2)
            case let .triPlanar(triPlanar):
                computeEncoder.setComputePipelineState(blurState.computePipelineStateYUVTriPlanarToRGBA)
                computeEncoder.setTexture(triPlanar.y, index: 0)
                computeEncoder.setTexture(triPlanar.u, index: 1)
                computeEncoder.setTexture(triPlanar.u, index: 2)
                computeEncoder.setTexture(rgbaTexture, index: 3)
            }
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            
            computeEncoder.endEncoding()
        })
        
        guard let downscaledTexture = self.downscaledTexture?.get(context: context), let blurredHorizontalTexture = self.blurredHorizontalTexture?.get(context: context), let blurredVerticalTexture = self.blurredVerticalTexture?.get(context: context) else {
            return
        }
        
        let blurredTexture = context.compute(state: BlurState.self, inputs: rgbaTexture.placeholer, downscaledTexture.placeholer, blurredHorizontalTexture.placeholer, blurredVerticalTexture.placeholer, commands: { commandBuffer, blurState, rgbaTexture, downscaledTexture, blurredHorizontalTexture, blurredVerticalTexture -> MTLTexture? in
            guard let rgbaTexture, let downscaledTexture, let blurredHorizontalTexture, let blurredVerticalTexture else {
                return nil
            }
            
            blurState.downscaleKernel.encode(commandBuffer: commandBuffer, sourceTexture: rgbaTexture, destinationTexture: downscaledTexture)
            
            do {
                guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    return nil
                }
                
                let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadgroupCount = MTLSize(width: (downscaledTexture.width + threadgroupSize.width - 1) / threadgroupSize.width, height: (downscaledTexture.height + threadgroupSize.height - 1) / threadgroupSize.height, depth: 1)
                
                computeEncoder.setComputePipelineState(blurState.computePipelineStateHorizontal)
                computeEncoder.setTexture(downscaledTexture, index: 0)
                computeEncoder.setTexture(blurredHorizontalTexture, index: 1)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                
                computeEncoder.setComputePipelineState(blurState.computePipelineStateVertical)
                computeEncoder.setTexture(blurredHorizontalTexture, index: 0)
                computeEncoder.setTexture(blurredVerticalTexture, index: 1)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                
                computeEncoder.endEncoding()
            }
            
            return blurredVerticalTexture
        })
        
        context.renderToLayer(spec: renderSpec, state: RenderState.self, layer: self.blurredLayer, inputs: blurredTexture, commands: { encoder, placement, blurredTexture in
            guard let blurredTexture else {
                return
            }
            let effectiveRect = placement.effectiveRect
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            
            var mirror = SIMD2<UInt32>(
                videoTextures.mirrorDirection.contains(.horizontal) ? 1 : 0,
                videoTextures.mirrorDirection.contains(.vertical) ? 1 : 0
            )
            encoder.setVertexBytes(&mirror, length: 2 * 4, index: 1)
            
            encoder.setFragmentTexture(blurredTexture, index: 0)
            
            var brightness: Float = 0.95
            var saturation: Float = 1.3
            var overlay: SIMD4<Float> = SIMD4<Float>()
            encoder.setFragmentBytes(&brightness, length: 4, index: 0)
            encoder.setFragmentBytes(&saturation, length: 4, index: 1)
            encoder.setFragmentBytes(&overlay, length: 4 * 4, index: 2)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        })
    }
}
