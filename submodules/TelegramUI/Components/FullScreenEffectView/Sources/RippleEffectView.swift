import Foundation
import Metal
import MetalKit
import simd
import ComponentFlow

public final class RippleEffectView: MTKView {
    private let centerLocation: CGPoint
    private let completion: () -> Void
    
    private let textureLoader: MTKTextureLoader
    private let commandQueue: MTLCommandQueue
    private let drawPassthroughPipelineState: MTLRenderPipelineState
    private var texture: MTLTexture?
    
    private var viewportDimensions = CGSize(width: 1, height: 1)
    
    private var startTime: Double?
    
    private var lastUpdateTimestamp: Double?
    
    public weak var sourceView: UIView? {
        didSet {
            self.updateImageFromSourceView()
        }
    }
    
    public init?(centerLocation: CGPoint, completion: @escaping () -> Void) {
        self.centerLocation = centerLocation
        self.completion = completion
        
        let mainBundle = Bundle(for: RippleEffectView.self)
        
        guard let path = mainBundle.path(forResource: "FullScreenEffectViewBundle", ofType: "bundle") else {
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

        guard let loadedVertexProgram = defaultLibrary.makeFunction(name: "rippleVertex") else {
            return nil
        }

        guard let loadedFragmentProgram = defaultLibrary.makeFunction(name: "rippleFragment") else {
            return nil
        }
        
        self.textureLoader = MTKTextureLoader(device: device)
        
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
        
        super.init(frame: CGRect(), device: device)

        self.isOpaque = false
        self.backgroundColor = nil

        self.framebufferOnly = true
        
        self.isPaused = false
        
        self.isUserInteractionEnabled = false
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportDimensions = size
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    override public func draw(_ rect: CGRect) {
        self.redraw(drawable: self.currentDrawable!)
    }
    
    private func updateImageFromSourceView() {
        guard let sourceView = self.sourceView else {
            return
        }
        
        let unscaledSize = sourceView.bounds.size
        
        UIGraphicsBeginImageContextWithOptions(sourceView.bounds.size, true, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        UIGraphicsPushContext(context)

        var unhideSelf = false
        if self.isDescendant(of: sourceView) {
            self.isHidden = true
            unhideSelf = true
        }
        
        sourceView.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: false)
        
        if unhideSelf {
            self.isHidden = false
        }
        
        UIGraphicsPopContext()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let image {
            self.updateImage(image: image)
        }
        
        self.lastUpdateTimestamp = CACurrentMediaTime()
    }
    
    private func updateImage(image: UIImage) {
        guard let cgImage = image.cgImage else {
            return
        }
        self.texture = try? self.textureLoader.newTexture(cgImage: cgImage)
    }

    private func redraw(drawable: MTLDrawable) {
        /*if let lastUpdateTimestamp = self.lastUpdateTimestamp {
            if lastUpdateTimestamp + 1.0 < CACurrentMediaTime() {
                self.updateImageFromSourceView()
            }
        } else {
            self.updateImageFromSourceView()
        }*/
        
        let relativeTime: Double
        let timestamp = CACurrentMediaTime()
        if let startTime = self.startTime {
            relativeTime = (timestamp - startTime) * (1.0 / UIView.animationDurationFactor)
        } else {
            self.startTime = timestamp
            relativeTime = 0.0
        }
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }

        let renderPassDescriptor = self.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let viewportDimensions = CGSize(width: self.bounds.size.width * self.contentScaleFactor, height: self.bounds.size.height * self.contentScaleFactor)
        
        renderEncoder.setRenderPipelineState(self.drawPassthroughPipelineState)
        
        let gridSize = 1000
        var time: Float = Float(min(relativeTime, 0.7))
        
        var gridResolution = simd_uint2(UInt32(gridSize), UInt32(gridSize))
        var resolution = simd_uint2(UInt32(viewportDimensions.width), UInt32(viewportDimensions.height))
        
        var center = simd_uint2(UInt32(self.centerLocation.x * self.contentScaleFactor), UInt32(self.centerLocation.y * self.contentScaleFactor));
        
        if let texture = self.texture {
            var contentScale: Float = Float(self.contentScaleFactor)
            renderEncoder.setVertexBytes(&center, length: MemoryLayout<simd_uint2>.size, index: 0)
            renderEncoder.setVertexBytes(&gridResolution, length: MemoryLayout<simd_uint2>.size, index: 1)
            renderEncoder.setVertexBytes(&resolution, length: MemoryLayout<simd_uint2>.size, index: 2)
            renderEncoder.setVertexBytes(&time, length: MemoryLayout<Float>.size, index: 3)
            renderEncoder.setVertexBytes(&contentScale, length: MemoryLayout<Float>.size, index: 4)
            
            renderEncoder.setFragmentTexture(texture, index: 0)
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6 * gridSize * gridSize, instanceCount: 1)
        }
        
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        if relativeTime >= 0.7 {
            //self.startTime = nil
            self.isPaused = true
            self.completion()
        }
    }
}
