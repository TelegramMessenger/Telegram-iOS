import Foundation
import Display
import Metal
import MetalKit
import MetalEngine
import ComponentFlow
import TelegramPresentationData
import AnimatableProperty
import SwiftSignalKit

private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }
    
    let mainBundle = Bundle(for: DiamondLayer.self)
    guard let path = mainBundle.path(forResource: "PremiumDiamondComponentBundle", ofType: "bundle") else {
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

final class DiamondLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?
    
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
                
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "post_vertex_main"),
                  let fragmentFunction = library.makeFunction(name: "post_fragment_main") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    final class DiamondState: ComputeState {
        let computePipelineState: MTLComputePipelineState
        let cubemapTexture: MTLTexture?
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            
            guard let functionComputeMain = library.makeFunction(name: "compute_main") else {
                return nil
            }
            guard let computePipelineState = try? device.makeComputePipelineState(function: functionComputeMain) else {
                return nil
            }
            self.computePipelineState = computePipelineState
            
            self.cubemapTexture = loadCubemap(device: device)
        }
    }
    
    private var offscreenTexture: PooledTexture?
    
    private var rotationX = AnimatableProperty<CGFloat>(value: -15.0 * .pi / 180.0)
    private var rotationY = AnimatableProperty<CGFloat>(value: 0.0)
    private var rotationZ = AnimatableProperty<CGFloat>(value: 0.0 * .pi / 180.0)
    private var time = AnimatableProperty<CGFloat>(value: 0.0)
    
    private var startTime = CFAbsoluteTimeGetCurrent()
    private var interactionStartTme: Double?
    
    private var displayLinkSubscription: SharedDisplayLinkDriver.Link?
    private var hasActiveAnimations: Bool = false
    
    private var isExploding = false
    
    private var currentRenderSize: CGSize = .zero
    
    override init() {
        super.init()
        
        self.isOpaque = false
        
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                guard let self else {
                    return
                }
                self.updateAnimations()
                self.setNeedsUpdate()
            }
        }
        
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = nil
        }
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        
        if let layer = layer as? DiamondLayer {
            self.rotationX = layer.rotationX
            self.rotationY = layer.rotationY
            self.rotationZ = layer.rotationZ
            self.time = layer.time
            self.startTime = layer.startTime
            self.currentRenderSize = layer.currentRenderSize
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            self.interactionStartTme = CFAbsoluteTimeGetCurrent()
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            let yawPan = -Float(translation.x) * Float.pi / 180.0
            
            func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                let bandedOffset = offset - bandingStart
                let range: CGFloat = 75.0
                let coefficient: CGFloat = 0.4
                return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
            }
            
            var pitchTranslation = rubberBandingOffset(offset: abs(translation.y), bandingStart: 0.0)
            if translation.y < 0.0 {
                pitchTranslation *= -1.0
            }
            let pitchPan = Float(pitchTranslation) * Float.pi / 180.0
            
            self.rotationX.update(value: CGFloat(yawPan), transition: .immediate)
            self.rotationY.update(value: CGFloat(pitchPan), transition: .immediate)
            
        case .ended:
            let velocity = gesture.velocity(in: gesture.view)
            
            if let interactionStartTme = self.interactionStartTme {
                let delta = CFAbsoluteTimeGetCurrent() - interactionStartTme
                self.startTime += delta
                
                self.interactionStartTme = nil
            }
//
//            var smallAngle = false
//            let previousYaw = Float(self.rotationX.presentationValue)
//            if (previousYaw < .pi / 2 && previousYaw > -.pi / 2) && abs(velocity.x) < 200 {
//                smallAngle = true
//            }
            
            playAppearanceAnimation(velocity: velocity.x, smallAngle: true, explode: false) //, smallAngle: smallAngle, explode: !smallAngle && abs(velocity.x) > 600)
        default:
            break
        }
        
        self.setNeedsUpdate()
    }
    
    func playAppearanceAnimation(velocity: CGFloat?, smallAngle: Bool, explode: Bool) {
        if explode {
            self.isExploding = true
            self.time.update(value: 8.0, transition: .spring(duration: 2.0))
            
            Queue.mainQueue().after(1.2) {
                if self.isExploding {
                    self.isExploding = false
                    self.startTime = CFAbsoluteTimeGetCurrent() - 8.0
                }
            }
        } else if smallAngle {
            let transition = ComponentTransition.easeInOut(duration: 0.3)
            self.rotationX.update(value: 0.0, transition: transition)
            self.rotationY.update(value: 0.0, transition: transition)
        }
        
    }
    
    private func updateAnimations() {
        let properties = [
            self.rotationX,
            self.rotationY,
            self.rotationZ
        ]
        
        let timestamp = CACurrentMediaTime()
        var hasAnimations = false
        for property in properties {
            if property.tick(timestamp: timestamp) {
                hasAnimations = true
            }
        }
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        if self.time.tick(timestamp: timestamp) {
            hasAnimations = true
        }
        self.hasActiveAnimations = hasAnimations
        
        if !self.isExploding && self.interactionStartTme == nil {
            let elapsedTime = currentTime - self.startTime
            self.time.update(value: CGFloat(elapsedTime), transition: .immediate)
        }
    }
    
    func update(context: MetalEngineSubjectContext) {
        if self.bounds.isEmpty {
            return
        }
        
        let drawableSize = CGSize(width: self.bounds.width * UIScreen.main.scale, height: self.bounds.height * UIScreen.main.scale)
        
        let offscreenTextureSpec = TextureSpec(width: Int(drawableSize.width), height: Int(drawableSize.height), pixelFormat: .rgba8UnsignedNormalized)
        if self.offscreenTexture == nil || self.offscreenTexture?.spec != offscreenTextureSpec {
            self.offscreenTexture = MetalEngine.shared.pooledTexture(spec: offscreenTextureSpec)
        }
        
        guard let offscreenTexture = self.offscreenTexture?.get(context: context) else {
            return
        }
        
        let diamondTexture = context.compute(state: DiamondState.self, inputs: offscreenTexture.placeholer, commands: { commandBuffer, computeState, offscreenTexture -> MTLTexture? in
            guard let offscreenTexture, let cubemapTexture = computeState.cubemapTexture else {
                return nil
            }
            do {
                guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    return nil
                }
                
                let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadgroupCount = MTLSize(width: (offscreenTextureSpec.width + threadgroupSize.width - 1) / threadgroupSize.width, height: (offscreenTextureSpec.height + threadgroupSize.height - 1) / threadgroupSize.height, depth: 1)
                
                var iTime = Float(self.time.presentationValue)
                
                var iResolution = simd_float2(
                    Float(drawableSize.width),
                    Float(drawableSize.height)
                )
                
                var cameraRotation = SIMD3<Float>(
                    Float(180.0 * .pi / 180.0 + self.rotationX.presentationValue),
                    Float(18.0 * .pi / 180.0 + self.rotationY.presentationValue),
                    Float(0.0)
                )
                
                computeEncoder.setComputePipelineState(computeState.computePipelineState)
                computeEncoder.setBytes(&iTime, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&iResolution, length: MemoryLayout<simd_float2>.size, index: 1)
                computeEncoder.setBytes(&cameraRotation, length: MemoryLayout<simd_float3>.size, index: 2)
                computeEncoder.setTexture(offscreenTexture, index: 0)
                computeEncoder.setTexture(cubemapTexture, index: 1)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                
                computeEncoder.endEncoding()
            }
            
            return offscreenTexture
        })
        
                
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: Int(drawableSize.width), height: Int(drawableSize.height))), state: RenderState.self, layer: self, inputs: diamondTexture, commands: { encoder, placement, diamondTexture in
            guard let diamondTexture else {
                return
            }
            
            let effectiveRect = placement.effectiveRect
            
            var iTime = Float(self.time.presentationValue)
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            
            var iResolution = simd_float2(
                Float(drawableSize.width),
                Float(drawableSize.height)
            )
            encoder.setFragmentBytes(&iTime, length: MemoryLayout<Float>.size, index: 0)
            encoder.setFragmentBytes(&iResolution, length: MemoryLayout<simd_float2>.size, index: 1)
            encoder.setFragmentTexture(diamondTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        })
    }
}

private func loadCubemap(device: MTLDevice) -> MTLTexture? {
    let faceNames = ["right", "left", "top", "bottom", "front", "back"].map { "\($0).png" }
    
    guard let firstImage = UIImage(named: faceNames[0]) else {
        return nil
    }
    
    let width = Int(firstImage.size.width)
    let height = Int(firstImage.size.height)
    
    let textureDescriptor = MTLTextureDescriptor.textureCubeDescriptor(
        pixelFormat: .rgba8Unorm,
        size: width,
        mipmapped: true
    )
    textureDescriptor.usage = [.shaderRead]
    
    guard let cubemapTexture = device.makeTexture(descriptor: textureDescriptor) else {
        return nil
    }
    
    for (index, faceName) in faceNames.enumerated() {
        guard let image = UIImage(named: faceName),
              let cgImage = image.cgImage else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))
        
        cubemapTexture.replace(
            region: region,
            mipmapLevel: 0,
            slice: index,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow,
            bytesPerImage: 0
        )
    }
    
    if textureDescriptor.mipmapLevelCount > 1 {
        let commandQueue = device.makeCommandQueue()
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
        
        blitEncoder?.generateMipmaps(for: cubemapTexture)
        blitEncoder?.endEncoding()
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
    }
    
    return cubemapTexture
}
