import Foundation
import UIKit
import Metal
import ComponentFlow
import Display
import MetalEngine
import AnimatableProperty

private final class ShutterBlobLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    struct Parameters: Equatable {
        var primaryParameters: SIMD4<Float>
        var primaryOffset: SIMD2<Float>
        var primaryColor: SIMD4<Float>
        var secondaryParameters: SIMD4<Float>
        var secondaryOffset: SIMD2<Float>
    }
    
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "cameraBlobVertex"), let fragmentFunction = library.makeFunction(name: "cameraBlobFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            
            guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    var internalData: MetalEngineSubjectInternalData?
    
    var parameters: Parameters? {
        didSet {
            if self.parameters != oldValue {
                self.setNeedsUpdate()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = false
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var bounds: CGRect {
        didSet {
            if self.bounds.size != oldValue.size {
                self.setNeedsUpdate()
            }
        }
    }
    
    func update(context: MetalEngineSubjectContext) {
        guard let parameters = self.parameters else {
            return
        }
        let scale = UIScreen.main.scale
        let renderSize = RenderSize(width: Int(self.bounds.width * scale), height: Int(self.bounds.height * scale))
        if renderSize.width <= 0 || renderSize.height <= 0 {
            return
        }
        
        context.renderToLayer(spec: RenderLayerSpec(size: renderSize, prefersDedicatedSurface: true), state: RenderState.self, layer: self, commands: { encoder, placement in
            let effectiveRect = placement.effectiveRect
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
            
            var resolution = SIMD2<Float>(Float(renderSize.width), Float(renderSize.height))
            encoder.setVertexBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
            encoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
            
            var primaryParameters = parameters.primaryParameters
            encoder.setFragmentBytes(&primaryParameters, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
            var primaryOffset = parameters.primaryOffset
            encoder.setFragmentBytes(&primaryOffset, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
            var primaryColor = parameters.primaryColor
            encoder.setFragmentBytes(&primaryColor, length: MemoryLayout<SIMD4<Float>>.size, index: 3)
            var secondaryParameters = parameters.secondaryParameters
            encoder.setFragmentBytes(&secondaryParameters, length: MemoryLayout<SIMD4<Float>>.size, index: 4)
            var secondaryOffset = parameters.secondaryOffset
            encoder.setFragmentBytes(&secondaryOffset, length: MemoryLayout<SIMD2<Float>>.size, index: 5)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        })
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
        case live
        
        var primarySize: CGSize {
            switch self {
            case .generic, .video, .transientToFlip:
                return CGSize(width: 0.63, height: 0.63)
            case .live:
                return CGSize(width: 3.1, height: 0.55)
            case .transientToLock, .lock, .stopVideo:
                return CGSize(width: 0.275, height: 0.275)
            }
        }
        
        func primaryColor(tintColor: UIColor) -> CGRect {
            var color: UIColor
            switch self {
            case .generic:
                if tintColor.rgb == 0x000000 {
                    color = UIColor(rgb: 0x000000)
                } else {
                    color = UIColor(rgb: 0xffffff)
                }
            case .live:
                color = UIColor(rgb: 0xfa325a)
            default:
                color = UIColor(rgb: 0xff0b18)
            }
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            if color.getRed(&r, green: &g, blue: &b, alpha: nil) {
                return CGRect(x: r, y: g, width: b, height: 1.0)
            }
            return CGRect(x: 0, y: 0, width: 0, height: 1.0)
        }
        
        var primaryCornerRadius: CGFloat {
            switch self {
            case .generic, .video, .transientToFlip:
                return 0.63
            case .live:
                return 0.55
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
            case .stopVideo, .live:
                return 0.0
            }
        }
        
        var secondaryRedness: CGFloat {
            switch self {
            case .generic, .lock, .transientToLock, .transientToFlip, .live:
                return 0.0
            default:
                return 1.0
            }
        }
    }
    
    private let blobLayer: ShutterBlobLayer
    
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    private var primaryWidth = AnimatableProperty<CGFloat>(value: 0.63)
    private var primaryHeight = AnimatableProperty<CGFloat>(value: 0.63)
    private var primaryOffsetX = AnimatableProperty<CGFloat>(value: 0.0)
    private var primaryOffsetY = AnimatableProperty<CGFloat>(value: 0.0)
    private var primaryColor = AnimatableProperty<CGRect>(value: CGRect(x: 1.0, y: 1.0, width: 1.0, height: 1.0))
    private var primaryCornerRadius = AnimatableProperty<CGFloat>(value: 0.63)
    
    private var secondarySize = AnimatableProperty<CGFloat>(value: 0.34)
    private var secondaryOffsetX = AnimatableProperty<CGFloat>(value: 0.0)
    private var secondaryOffsetY = AnimatableProperty<CGFloat>(value: 0.0)
    private var secondaryRedness = AnimatableProperty<CGFloat>(value: 0.0)
    
    private(set) var state: BlobState = .generic

    init() {
        self.blobLayer = ShutterBlobLayer()
        
        super.init(frame: CGRect())
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.layer.addSublayer(self.blobLayer)
        
        self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max) { [weak self] _ in
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
        
        self.primaryWidth.update(value: state.primarySize.width, transition: transition)
        self.primaryHeight.update(value: state.primarySize.height, transition: transition)
        self.primaryColor.update(value: state.primaryColor(tintColor: tintColor), transition: transition)
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
            self.primaryWidth,
            self.primaryHeight,
            self.primaryOffsetX,
            self.primaryOffsetY,
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
        if self.primaryColor.tick(timestamp: timestamp) {
            hasAnimations = true
        }
        self.displayLink?.isPaused = !hasAnimations
    }

    private func tick() {
        self.updateAnimations()
        self.updateLayerParameters()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.blobLayer.frame = self.bounds
        self.tick()
    }
    
    private func updateLayerParameters() {
        let primaryColor = self.primaryColor.presentationValue
        self.blobLayer.parameters = ShutterBlobLayer.Parameters(
            primaryParameters: SIMD4<Float>(
                Float(self.primaryWidth.presentationValue),
                Float(self.primaryHeight.presentationValue),
                0.0,
                Float(self.primaryCornerRadius.presentationValue)
            ),
            primaryOffset: SIMD2<Float>(
                Float(self.primaryOffsetX.presentationValue),
                Float(self.primaryOffsetY.presentationValue)
            ),
            primaryColor: SIMD4<Float>(Float(primaryColor.minX), Float(primaryColor.minY), Float(primaryColor.width), 1.0),
            secondaryParameters: SIMD4<Float>(
                Float(self.secondarySize.presentationValue),
                Float(self.secondaryRedness.presentationValue),
                0.0,
                0.0
            ),
            secondaryOffset: SIMD2<Float>(
                Float(self.secondaryOffsetX.presentationValue),
                Float(self.secondaryOffsetY.presentationValue)
            )
        )
    }
}
