import Foundation
import UIKit
import Display
import MetalEngine
import MetalKit

#if DEBUG
import os
#endif

#if DEBUG
class Signposter {
    func emitEvent(_ string: StaticString) {
    }
}

@available(iOS 15.0, *)
final class SignposterImpl: Signposter {
    private let signposter = OSSignposter()
    private let signpostId: OSSignpostID
    
    override init() {
        self.signpostId = self.signposter.makeSignpostID()
    }
    
    override func emitEvent(_ string: StaticString) {
        self.signposter.emitEvent("Fetch complete.", id: self.signpostId)
    }
}

let signposter: Signposter = {
    if #available(iOS 15.0, *) {
        return SignposterImpl()
    } else {
        return Signposter()
    }
}()

#endif

private final class BundleMarker: NSObject {
}

private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }
    
    let mainBundle = Bundle(for: BundleMarker.self)
    guard let path = mainBundle.path(forResource: "DustEffectMetalSourcesBundle", ofType: "bundle") else {
        return nil
    }
    guard let bundle = Bundle(path: path) else {
        return nil
    }
    guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }
    
    metalLibraryValue = library
    return library
}

public final class DustEffectLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    public var internalData: MetalEngineSubjectInternalData?
    
    private final class Item {
        let frame: CGRect
        let texture: MTLTexture
        
        var phase: Float = 0
        var duration: Double = 0
        var particleBufferIsInitialized: Bool = false
        var particleBuffer: SharedBuffer?
        
        init?(frame: CGRect, image: UIImage) {
            self.frame = frame
            
            guard let cgImage = image.cgImage, let texture = try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: cgImage, options: [.SRGB: false as NSNumber]) else {
                return nil
            }
            self.texture = texture
        }
    }
    
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "dustEffectVertex"), let fragmentFunction = library.makeFunction(name: "dustEffectFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    final class DustComputeState: ComputeState {
        let computePipelineStateInitializeParticle: MTLComputePipelineState
        let computePipelineStateUpdateParticle: MTLComputePipelineState
        let fluidPipelines: DustFluidSimulation.Pipelines
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            
            guard let functionDustEffectInitializeParticle = library.makeFunction(name: "dustEffectInitializeParticle") else {
                return nil
            }
            guard let computePipelineStateInitializeParticle = MetalEngine.shared.pipelineCache.makeComputePipelineState(function: functionDustEffectInitializeParticle) else {
                return nil
            }
            self.computePipelineStateInitializeParticle = computePipelineStateInitializeParticle
            
            guard let functionDustEffectUpdateParticle = library.makeFunction(name: "dustEffectUpdateParticle") else {
                return nil
            }
            guard let computePipelineStateUpdateParticle = MetalEngine.shared.pipelineCache.makeComputePipelineState(function: functionDustEffectUpdateParticle) else {
                return nil
            }
            
            self.computePipelineStateUpdateParticle = computePipelineStateUpdateParticle
            
            guard let fluidPipelines = DustFluidSimulation.Pipelines(library: library, makePipelineState: { function in
                return MetalEngine.shared.pipelineCache.makeComputePipelineState(function: function)
            }) else {
                return nil
            }
            self.fluidPipelines = fluidPipelines
        }
    }
    
    // Matches ParticleFluidParams in DustEffectShaders.metal.
    private struct ParticleFluidParams {
        var itemOrigin: SIMD2<Float>
        var itemSize: SIMD2<Float>
        var cellSize: Float
        var isEnabled: Float
    }
    
    private var updateLink: SharedDisplayLinkDriver.Link?
    private var items: [Item] = []
    private var lastTimeStep: Double = 0.0
    
    private var fluid: DustFluidSimulation?
    private var pendingFluidSplats: [DustFluidSimulation.Splat] = []
    private var randomGenerator = SystemRandomNumberGenerator()
    
    public var animationSpeed: Float = 1.0
    public var playsBackwards: Bool = false
    public var animateDown: Bool = false
    
    public var becameEmpty: (() -> Void)?
    
    override public init() {
        super.init()
        
        self.isOpaque = false
        self.backgroundColor = nil
        
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updateNeedsAnimation()
        }
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updateNeedsAnimation()
        }
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var lastUpdateTimestamp: Double?
    
    private func updateItems(deltaTime: Double) {
        let timestamp = CACurrentMediaTime()
        let localDeltaTime: Double
        if let lastUpdateTimestamp = self.lastUpdateTimestamp {
            localDeltaTime = timestamp - lastUpdateTimestamp
        } else {
            localDeltaTime = 0.0
        }
        self.lastUpdateTimestamp = timestamp
        
        let deltaTimeValue: Double
        if localDeltaTime <= 0.001 || localDeltaTime >= 0.2 {
            deltaTimeValue = deltaTime
        } else {
            deltaTimeValue = localDeltaTime
        }
        
        self.lastTimeStep = deltaTimeValue
        
        let containerHeight = Float(self.bounds.height)
        let verticalDirection: Float = self.animateDown ? -1.0 : 1.0
        
        var didRemoveItems = false
        for i in (0 ..< self.items.count).reversed() {
            let item = self.items[i]
            let previousPhase = item.phase
            item.phase += Float(deltaTimeValue) * self.animationSpeed / Float(UIView.animationDurationFactor())
            item.duration += deltaTimeValue / UIView.animationDurationFactor()
            
            // The last grains come loose when the sweep ends, at phase 0.8, and then live for up to 2.1 seconds (4.1 in
            // their simulation time, which runs twice as fast; see dustEffectInitializeParticle) whatever the speed.
            if item.phase >= 4.0 && item.duration >= 0.8 / Double(self.animationSpeed) + 2.1 {
                self.items.remove(at: i)
                didRemoveItems = true
            } else {
                let itemOrigin = SIMD2<Float>(Float(item.frame.minX), containerHeight - Float(item.frame.maxY))
                let itemSize = SIMD2<Float>(Float(item.frame.width), Float(item.frame.height))
                let splats = DustFluidSimulation.dissolveSplats(itemOrigin: itemOrigin, itemSize: itemSize, previousPhase: previousPhase, phase: item.phase, verticalDirection: verticalDirection, generator: &self.randomGenerator)
                self.pendingFluidSplats.append(contentsOf: splats)
            }
        }
        self.updateNeedsAnimation()
        
        if didRemoveItems && self.items.isEmpty {
            self.fluid = nil
            self.pendingFluidSplats.removeAll()
            self.becameEmpty?()
        }
    }
    
    private func updateNeedsAnimation() {
        if !self.items.isEmpty && self.isInHierarchy {
            if self.updateLink == nil {
                self.updateLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                    guard let self else {
                        return
                    }
                    self.updateItems(deltaTime: deltaTime)
                    self.setNeedsUpdate()
                })
            }
        } else {
            if self.updateLink != nil {
                self.updateLink = nil
            }
        }
    }
    
    public func addItem(frame: CGRect, image: UIImage) {
        if let item = Item(frame: frame, image: image) {
            self.items.append(item)
            self.updateNeedsAnimation()
            self.setNeedsUpdate()
        }
    }
    
    public func update(context: MetalEngineSubjectContext) {
        if self.bounds.isEmpty {
            return
        }
        
        let containerSize = self.bounds.size
        
        for item in self.items {
            var itemFrame = item.frame
            itemFrame.origin.y = containerSize.height - itemFrame.maxY
            
            let particleColumnCount = Int(itemFrame.width)
            let particleRowCount = Int(itemFrame.height)
            let particleCount = particleColumnCount * particleRowCount
            
            if item.particleBuffer == nil {
                // Particle in DustEffectShaders.metal: offset, velocity, lifetime, age, displacement.
                if let particleBuffer = MetalEngine.shared.sharedBuffer(spec: BufferSpec(length: particleCount * 4 * (2 + 2 + 1 + 1 + 2))) {
                    item.particleBuffer = particleBuffer
                }
            }
        }
        
        let fluidSize = SIMD2<Float>(Float(containerSize.width), Float(containerSize.height))
        if !self.items.isEmpty && self.fluid?.size != fluidSize {
            self.fluid = DustFluidSimulation(device: MetalEngine.shared.device, size: fluidSize)
        }
        
        let lastTimeStep = self.lastTimeStep
        self.lastTimeStep = 0.0
        
        #if DEBUG
        if lastTimeStep * 1000.0 >= 20.0 {
            print("Animation Lag: \(lastTimeStep * 1000.0) ms")
            signposter.emitEvent("AnimationLag")
        }
        #endif
        
        let _ = context.compute(state: DustComputeState.self, commands: { [weak self] commandBuffer, state in
            guard let self else {
                return
            }
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            
            var verticalDirection: Float = self.animateDown ? -1.0 : 1.0
            
            let fluid = self.fluid
            if let fluid, lastTimeStep != 0.0 {
                var timeStep: Float = Float(lastTimeStep) / Float(UIView.animationDurationFactor())
                timeStep *= 2.0
                fluid.encode(encoder: computeEncoder, pipelines: state.fluidPipelines, timeStep: timeStep, splats: self.pendingFluidSplats)
                self.pendingFluidSplats.removeAll()
            }
            
            for item in self.items {
                guard let particleBuffer = item.particleBuffer else {
                    continue
                }
                
                let itemFrame = item.frame
                let particleColumnCount = Int(itemFrame.width)
                let particleRowCount = Int(itemFrame.height)
                var particleCount = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
                
                let threadgroupSize = MTLSize(width: 32, height: 1, depth: 1)
                let threadgroupCount = MTLSize(width: (particleRowCount * particleColumnCount + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
                
                computeEncoder.setBuffer(particleBuffer.buffer, offset: 0, index: 0)
                
                if !item.particleBufferIsInitialized {
                    item.particleBufferIsInitialized = true
                    computeEncoder.setComputePipelineState(state.computePipelineStateInitializeParticle)
                    computeEncoder.setBytes(&verticalDirection, length: 4, index: 1)
                    computeEncoder.setBytes(&particleCount, length: 4 * 2, index: 2)
                    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                }
                
                if lastTimeStep != 0.0 {
                    computeEncoder.setComputePipelineState(state.computePipelineStateUpdateParticle)
                    computeEncoder.setBytes(&particleCount, length: 4 * 2, index: 1)
                    var phase = item.phase
                    computeEncoder.setBytes(&phase, length: 4, index: 2)
                    var timeStep: Float = Float(lastTimeStep) / Float(UIView.animationDurationFactor())
                    timeStep *= 2.0
                    computeEncoder.setBytes(&timeStep, length: 4, index: 3)
                    computeEncoder.setBytes(&verticalDirection, length: 4, index: 4)
                    
                    var fluidParams = ParticleFluidParams(
                        itemOrigin: SIMD2<Float>(Float(itemFrame.minX), Float(containerSize.height - itemFrame.maxY)),
                        itemSize: SIMD2<Float>(Float(itemFrame.width), Float(itemFrame.height)),
                        cellSize: fluid?.cellSize ?? 1.0,
                        isEnabled: fluid != nil ? 1.0 : 0.0
                    )
                    computeEncoder.setBytes(&fluidParams, length: MemoryLayout<ParticleFluidParams>.stride, index: 5)
                    // Without a fluid the kernel does not read the texture, but one must still be bound.
                    computeEncoder.setTexture(fluid?.streamFunctionTexture ?? item.texture, index: 0)
                    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                }
            }
            
            computeEncoder.endEncoding()
        })
        
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: Int(self.bounds.width * 3.0), height: Int(self.bounds.height * 3.0))), state: RenderState.self, layer: self, commands: { [weak self] encoder, placement in
            guard let self else {
                return
            }
            
            for item in self.items {
                guard let particleBuffer = item.particleBuffer else {
                    continue
                }
                
                var itemFrame = item.frame
                itemFrame.origin.y = containerSize.height - itemFrame.maxY
                
                let particleColumnCount = Int(itemFrame.width)
                let particleRowCount = Int(itemFrame.height)
                let particleCount = particleColumnCount * particleRowCount
                
                var effectiveRect = placement.effectiveRect
                effectiveRect.origin.x += itemFrame.minX / containerSize.width * effectiveRect.width
                effectiveRect.origin.y += itemFrame.minY / containerSize.height * effectiveRect.height
                effectiveRect.size.width = itemFrame.width / containerSize.width * effectiveRect.width
                effectiveRect.size.height = itemFrame.height / containerSize.height * effectiveRect.height
                
                var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
                encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
                
                var size = SIMD2<Float>(Float(itemFrame.width), Float(itemFrame.height))
                encoder.setVertexBytes(&size, length: 4 * 2, index: 1)
                
                var particleResolution = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
                encoder.setVertexBytes(&particleResolution, length: 4 * 2, index: 2)
                
                encoder.setVertexBuffer(particleBuffer.buffer, offset: 0, index: 3)
                
                encoder.setFragmentTexture(item.texture, index: 0)
                
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: particleCount)
            }
        })
    }
}
