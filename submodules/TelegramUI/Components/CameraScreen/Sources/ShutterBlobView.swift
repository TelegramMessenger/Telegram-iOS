import Foundation
import Metal
import MetalKit
import ComponentFlow
import Display
import MetalImageView

private final class PropertyAnimation<T: Interpolatable> {
    let from: T
    let to: T
    let animation: Transition.Animation
    let startTimestamp: Double
    private let interpolator: (Interpolatable, Interpolatable, CGFloat) -> Interpolatable
    
    init(fromValue: T, toValue: T, animation: Transition.Animation, startTimestamp: Double) {
        self.from = fromValue
        self.to = toValue
        self.animation = animation
        self.startTimestamp = startTimestamp
        self.interpolator = T.interpolator()
    }
    
    func valueAt(_ t: CGFloat) -> Interpolatable {
        if t <= 0.0 {
            return self.from
        } else if t >= 1.0 {
            return self.to
        } else {
            return self.interpolator(self.from, self.to, t)
        }
    }
}

private final class AnimatableProperty<T: Interpolatable> {
    var presentationValue: T
    var value: T
    private var animation: PropertyAnimation<T>?
    
    init(value: T) {
        self.value = value
        self.presentationValue = value
    }
    
    func update(value: T, transition: Transition = .immediate) {
        let currentTimestamp = CACurrentMediaTime()
        if case .none = transition.animation {
            if let animation = self.animation, case let .curve(duration, curve) = animation.animation {
                self.value = value
                let elapsed = duration - (currentTimestamp - animation.startTimestamp)
                if let presentationValue = self.presentationValue as? CGFloat, let newValue = value as? CGFloat, abs(presentationValue - newValue) > 0.56 {
                    self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: .curve(duration: elapsed * 0.8, curve: curve), startTimestamp: currentTimestamp)
                } else {
                    self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: .curve(duration: elapsed, curve: curve), startTimestamp: currentTimestamp)
                }
            } else {
                self.value = value
                self.presentationValue = value
                self.animation = nil
            }
        } else {
            self.value = value
            self.animation = PropertyAnimation(fromValue: self.presentationValue, toValue: value, animation: transition.animation, startTimestamp: currentTimestamp)
        }
    }
    
    func tick(timestamp: Double) -> Bool {
        
        guard let animation = self.animation, case let .curve(duration, curve) = animation.animation else {
            return false
        }
        
        let timeFromStart = timestamp - animation.startTimestamp
        var t = max(0.0, timeFromStart / duration)
        switch curve {
        case .easeInOut:
            t = listViewAnimationCurveEaseInOut(t)
        case .spring:
            t = lookupSpringValue(t)
        case let .custom(x1, y1, x2, y2):
            t = bezierPoint(CGFloat(x1), CGFloat(y1), CGFloat(x2), CGFloat(y2), t)
        }
        self.presentationValue = animation.valueAt(t) as! T
    
        if timeFromStart <= duration {
            return true
        }
        self.animation = nil
        return false
    }
}

private func lookupSpringValue(_ t: CGFloat) -> CGFloat {
    let table: [(CGFloat, CGFloat)] = [
        (0.0, 0.0),
        (0.0625, 0.1123005598783493),
        (0.125, 0.31598418951034546),
        (0.1875, 0.5103585720062256),
        (0.25, 0.6650152802467346),
        (0.3125, 0.777747631072998),
        (0.375, 0.8557760119438171),
        (0.4375, 0.9079672694206238),
        (0.5, 0.942038357257843),
        (0.5625, 0.9638798832893372),
        (0.625, 0.9776856303215027),
        (0.6875, 0.9863143563270569),
        (0.75, 0.991658091545105),
        (0.8125, 0.9949421286582947),
        (0.875, 0.9969474077224731),
        (0.9375, 0.9981651306152344),
        (1.0, 1.0)
    ]
    
    for i in 0 ..< table.count - 2 {
        let lhs = table[i]
        let rhs = table[i + 1]
        
        if t >= lhs.0 && t <= rhs.0 {
            let fraction = (t - lhs.0) / (rhs.0 - lhs.0)
            let value = lhs.1 + fraction * (rhs.1 - lhs.1)
            return value
        }
    }
    return 1.0
}

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
        
        var primaryRedness: CGFloat {
            switch self {
            case .generic:
                return 0.0
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
        let mainBundle = Bundle(for: ShutterBlobView.self)
        
        guard let path = mainBundle.path(forResource: "CameraScreenBundle", ofType: "bundle") else {
            return nil
        }
        guard let bundle = Bundle(path: path) else {
            return nil
        }
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: bundle) else {
            return nil
        }

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        guard let loadedVertexProgram = defaultLibrary.makeFunction(name: "cameraBlobVertex") else {
            return nil
        }

        guard let loadedFragmentProgram = defaultLibrary.makeFunction(name: "cameraBlobFragment") else {
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
        
        self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] in
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
    
    func updateState(_ state: BlobState, transition: Transition = .immediate) {
        guard self.state != state else {
            return
        }
        self.state = state

        self.primarySize.update(value: state.primarySize, transition: transition)
        self.primaryRedness.update(value: state.primaryRedness, transition: transition)
        self.primaryCornerRadius.update(value: state.primaryCornerRadius, transition: transition)
        self.secondarySize.update(value: state.secondarySize, transition: transition)
        self.secondaryRedness.update(value: state.secondaryRedness, transition: transition)
        
        self.tick()
    }
    
    func updatePrimaryOffsetX(_ offset: CGFloat, transition: Transition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.height * 2.0
        self.primaryOffsetX.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    func updatePrimaryOffsetY(_ offset: CGFloat, transition: Transition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.width * 2.0
        self.primaryOffsetY.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    func updateSecondaryOffsetX(_ offset: CGFloat, transition: Transition = .immediate) {
        guard self.frame.height > 0.0 else {
            return
        }
        let mappedOffset = offset / self.frame.height * 2.0
        self.secondaryOffsetX.update(value: mappedOffset, transition: transition)
        
        self.tick()
    }
    
    func updateSecondaryOffsetY(_ offset: CGFloat, transition: Transition = .immediate) {
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
