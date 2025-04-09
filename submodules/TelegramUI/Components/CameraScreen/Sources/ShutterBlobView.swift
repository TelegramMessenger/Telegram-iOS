import Foundation
import Metal
import MetalKit
import ComponentFlow
import Display
import MetalImageView
import AnimatableProperty

private class ShutterBlobLayer: MetalImageLayer {
    override public init() {
        super.init()
        
        self.renderer.imageUpdated = { [weak self] image in
            self?.contents = image
        }
    }
    
    override public init(layer: Any) {
        super.init()
        
        if let layer = layer as? ShutterBlobLayer {
            self.contents = layer.contents
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ShutterBlobView: UIView {
    enum BlobState {
        case generic
        case video
        case transientToLock
        case lock
        case transientToFlip
        case stopVideo
        
        var primarySize: CGFloat {
            switch self {
            case .generic, .video, .transientToFlip:
                return 0.63
            case .transientToLock, .lock, .stopVideo:
                return 0.275
            }
        }
        
        func primaryRedness(tintColor: UIColor) -> CGFloat {
            switch self {
            case .generic:
                if tintColor.rgb == 0x000000 {
                    return -1.0
                } else {
                    return 0.0
                }
            default:
                return 1.0
            }
        }
        
        var primaryCornerRadius: CGFloat {
            switch self {
            case .generic, .video, .transientToFlip:
                return 0.63
            case .transientToLock, .lock, .stopVideo:
                return 0.185
            }
        }
        
        var secondarySize: CGFloat {
            switch self {
            case .generic, .video, .transientToFlip, .transientToLock:
                return 0.335
            case .lock:
                return 0.5
            case .stopVideo:
                return 0.0
            }
        }
        
        var secondaryRedness: CGFloat {
            switch self {
            case .generic, .lock, .transientToLock, .transientToFlip:
                return 0.0
            default:
                return 1.0
            }
        }
    }
    
    private let commandQueue: MTLCommandQueue
    private let drawPassthroughPipelineState: MTLRenderPipelineState
    
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    private var primarySize = AnimatableProperty<CGFloat>(value: 0.63)
    private var primaryOffsetX = AnimatableProperty<CGFloat>(value: 0.0)
    private var primaryOffsetY = AnimatableProperty<CGFloat>(value: 0.0)
    private var primaryRedness = AnimatableProperty<CGFloat>(value: 0.0)
    private var primaryCornerRadius = AnimatableProperty<CGFloat>(value: 0.63)
    
    private var secondarySize = AnimatableProperty<CGFloat>(value: 0.34)
    private var secondaryOffsetX = AnimatableProperty<CGFloat>(value: 0.0)
    private var secondaryOffsetY = AnimatableProperty<CGFloat>(value: 0.0)
    private var secondaryRedness = AnimatableProperty<CGFloat>(value: 0.0)
    
    private(set) var state: BlobState = .generic

    static override var layerClass: AnyClass {
        return ShutterBlobLayer.self
    }
    
    public init?(test: Bool) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let library = metalLibrary(device: device) else {
            return nil
        }

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        guard let loadedVertexProgram = library.makeFunction(name: "cameraBlobVertex") else {
            return nil
        }

        guard let loadedFragmentProgram = library.makeFunction(name: "cameraBlobFragment") else {
            return nil
        }
                
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = loadedVertexProgram
        pipelineStateDescriptor.fragmentFunction = loadedFragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        self.drawPassthroughPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
  
        super.init(frame: CGRect())
        
        (self.layer as! ShutterBlobLayer).renderer.device = device
        
        self.isOpaque = false
        self.backgroundColor = .clear
        
        self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
            self?.tick()
        }
        self.displayLink?.isPaused = true
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }
    
    func updateState(_ state: BlobState, tintColor: UIColor, transition: ComponentTransition = .immediate) {
        guard self.state != state else {
            return
        }
        self.state = state
        
        self.primarySize.update(value: state.primarySize, transition: transition)
        self.primaryRedness.update(value: state.primaryRedness(tintColor: tintColor), transition: transition)
        self.primaryCornerRadius.update(value: state.primaryCornerRadius, transition: transition)
        self.secondarySize.update(value: state.secondarySize, transition: transition)
        self.secondaryRedness.update(value: state.secondaryRedness, transition: transition)
        
        self.tick()
    }
    
    func updatePrimaryOffsetX(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.height * 2.0
        self.primaryOffsetX.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    func updatePrimaryOffsetY(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.width * 2.0
        self.primaryOffsetY.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    func updateSecondaryOffsetX(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.height * 2.0
        self.secondaryOffsetX.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    func updateSecondaryOffsetY(_ offset: CGFloat, transition: ComponentTransition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.width * 2.0
        self.secondaryOffsetY.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    private func updateAnimations() {
        let properties = [
            self.primarySize,
            self.primaryOffsetX,
            self.primaryOffsetY,
            self.primaryRedness,
            self.primaryCornerRadius,
            self.secondarySize,
            self.secondaryOffsetX,
            self.secondaryOffsetY,
            self.secondaryRedness
        ]
        
        let timestamp = CACurrentMediaTime()
        var hasAnimations = false
        for property in properties {
            if property.tick(timestamp: timestamp) {
                hasAnimations = true
            }
        }
        self.displayLink?.isPaused = !hasAnimations
    }

    private func tick() {
        self.updateAnimations()
        self.draw()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.tick()
    }
    
    private func getNextDrawable(layer: MetalImageLayer, drawableSize: CGSize) -> MetalImageLayer.Drawable? {
        layer.renderer.drawableSize = drawableSize
        return layer.renderer.nextDrawable()
    }
    
    func draw() {
        guard let layer = self.layer as? MetalImageLayer else {
            return
        }
        self.updateAnimations()
        
        let drawableSize = CGSize(width: self.bounds.width * UIScreen.main.scale, height: self.bounds.height * UIScreen.main.scale)
        
        guard let drawable = self.getNextDrawable(layer: layer, drawableSize: drawableSize) else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: drawableSize.width, height: drawableSize.height, znear: -1.0, zfar: 1.0))
        renderEncoder.setRenderPipelineState(self.drawPassthroughPipelineState)
        
        var vertices: [Float] = [
             1,  -1,
            -1,  -1,
            -1,   1,
             1,  -1,
            -1,   1,
             1,   1
        ]
        renderEncoder.setVertexBytes(&vertices, length: 4 * vertices.count, index: 0)
        
        var resolution = simd_uint2(UInt32(drawableSize.width), UInt32(drawableSize.height))
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 0)
        
        var primaryParameters = simd_float3(
            Float(self.primarySize.presentationValue),
            Float(self.primaryRedness.presentationValue),
            Float(self.primaryCornerRadius.presentationValue)
        )
        renderEncoder.setFragmentBytes(&primaryParameters, length: MemoryLayout<simd_float3>.size, index: 1)

        var primaryOffset = simd_float2(
            Float(self.primaryOffsetX.presentationValue),
            Float(self.primaryOffsetY.presentationValue)
        )
        renderEncoder.setFragmentBytes(&primaryOffset, length: MemoryLayout<simd_float2>.size, index: 2)
        
        var secondaryParameters = simd_float2(
            Float(self.secondarySize.presentationValue),
            Float(self.secondaryRedness.presentationValue)
        )
        renderEncoder.setFragmentBytes(&secondaryParameters, length: MemoryLayout<simd_float4>.size, index: 3)
        
        var secondaryOffset = simd_float2(
            Float(self.secondaryOffsetX.presentationValue),
            Float(self.secondaryOffsetY.presentationValue)
        )
        renderEncoder.setFragmentBytes(&secondaryOffset, length: MemoryLayout<simd_float2>.size, index: 4)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        renderEncoder.endEncoding()

        var storedDrawable: MetalImageLayer.Drawable? = drawable
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                autoreleasepool {
                    storedDrawable?.present(completion: {})
                    storedDrawable = nil
                }
            }
        }
        
        commandBuffer.commit()
    }
}
