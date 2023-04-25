import Foundation
import Metal
import MetalKit

final class ShutterBlobView: MTKView, MTKViewDelegate {
    public func draw(in view: MTKView) {
        
    }
    
    private let commandQueue: MTLCommandQueue
    private let drawPassthroughPipelineState: MTLRenderPipelineState
    
    private var displayLink: CADisplayLink?
    
    private var viewportDimensions = CGSize(width: 1, height: 1)
    
    private var startTimestamp = CACurrentMediaTime()
    
    public init?(test: Bool) {
        let mainBundle = Bundle(for: ShutterBlobView.self)
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: mainBundle) else {
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
  
        super.init(frame: CGRect(), device: device)
        
        self.delegate = self

        self.isOpaque = false
        self.backgroundColor = .clear

        self.framebufferOnly = true
  
        class DisplayLinkProxy: NSObject {
            weak var target: ShutterBlobView?
            init(target: ShutterBlobView) {
                self.target = target
            }

            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }

        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        if #available(iOS 15.0, *) {
            let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
            self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: maxFps, preferred: maxFps)
        }
        self.displayLink?.add(to: .main, forMode: .common)
        self.displayLink?.isPaused = false
        
        self.isPaused = true
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.viewportDimensions = size
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    @objc private func displayLinkEvent() {
        self.draw()
    }

    override public func draw(_ rect: CGRect) {
        self.redraw(drawable: self.currentDrawable!)
    }

    private func redraw(drawable: MTLDrawable) {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }

        let renderPassDescriptor = self.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let viewportDimensions = self.viewportDimensions
        renderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: viewportDimensions.width, height: viewportDimensions.height, znear: -1.0, zfar: 1.0))
        
        renderEncoder.setRenderPipelineState(self.drawPassthroughPipelineState)

        let w = Float(1)
        let h = Float(1)
        
        var vertices: [Float] = [
             w,  -h,
            -w,  -h,
            -w,   h,
             w,  -h,
            -w,   h,
             w,   h
        ]
        renderEncoder.setVertexBytes(&vertices, length: 4 * vertices.count, index: 0)
                
        var resolution = simd_uint2(UInt32(viewportDimensions.width), UInt32(viewportDimensions.height))
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 0)
        
        var time = Float(CACurrentMediaTime() - self.startTimestamp) * 0.5
        renderEncoder.setFragmentBytes(&time, length: 4, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
