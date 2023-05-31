import Foundation
import UIKit
import Metal
import MetalKit
import Photos
import SwiftSignalKit

protocol TextureConsumer: AnyObject {
    func consumeTexture(_ texture: MTLTexture)
    func consumeVideoPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: TextureRotation)
}

final class RenderingContext {
    let device: MTLDevice
    let commandBuffer: MTLCommandBuffer
    
    init(
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) {
        self.device = device
        self.commandBuffer = commandBuffer
    }
}

protocol RenderPass: AnyObject {
    func setup(device: MTLDevice, library: MTLLibrary)
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

protocol TextureSource {
    func connect(to: TextureConsumer)
}

protocol RenderTarget: AnyObject {
    var mtlDevice: MTLDevice? { get }
    
    var drawableSize: CGSize { get }
    var colorPixelFormat: MTLPixelFormat { get }
    var drawable: MTLDrawable? { get }
    var renderPassDescriptor: MTLRenderPassDescriptor? { get }
    
    func scheduleFrame()
}

final class MediaEditorRenderer: TextureConsumer {
    var textureSource: TextureSource? {
        didSet {
            self.textureSource?.connect(to: self)
        }
    }
    
    var semaphore = DispatchSemaphore(value: 3)
    private var renderPasses: [RenderPass] = []
    
    private let videoInputPass = VideoInputPass()
    private let outputRenderPass = OutputRenderPass()
    private weak var renderTarget: RenderTarget? {
        didSet {
            self.outputRenderPass.renderTarget = self.renderTarget
        }
    }

    private var device: MTLDevice?
    private var library: MTLLibrary?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    
    private var currentTexture: MTLTexture?
    private var currentPixelBuffer: (CVPixelBuffer, TextureRotation)?
    
    public var onNextRender: (() -> Void)?
    
    var finalTexture: MTLTexture?
        
    public init() {
        
    }
    
    deinit {
        for _ in 0 ..< 3 {
            self.semaphore.signal()
        }
    }
    
    func addRenderPass(_ renderPass: RenderPass) {
        self.renderPasses.append(renderPass)
        if let device = self.renderTarget?.mtlDevice, let library = self.library {
            renderPass.setup(device: device, library: library)
        }
    }
    
    func addRenderChain(_ renderChain: MediaEditorRenderChain) {
        for renderPass in renderChain.renderPasses {
            self.addRenderPass(renderPass)
        }
    }
    
    private func setup() {
        guard let device = self.renderTarget?.mtlDevice else {
            return
        }
        
        CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache)
        
        let mainBundle = Bundle(for: MediaEditorRenderer.self)
        guard let path = mainBundle.path(forResource: "MediaEditorBundle", ofType: "bundle") else {
            return
        }
        guard let bundle = Bundle(path: path) else {
            return
        }
        
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            return
        }
        self.library = library
        
        self.commandQueue = device.makeCommandQueue()
        self.commandQueue?.label = "Media Editor Command Queue"
        self.videoInputPass.setup(device: device, library: library)
        self.renderPasses.forEach { $0.setup(device: device, library: library) }
        self.outputRenderPass.setup(device: device, library: library)
    }
    
    func setupForComposer(composer: MediaEditorComposer) {
        guard let device = composer.device else {
            return
        }
        self.device = device
        CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache)
        
        let mainBundle = Bundle(for: MediaEditorRenderer.self)
        guard let path = mainBundle.path(forResource: "MediaEditorBundle", ofType: "bundle") else {
            return
        }
        guard let bundle = Bundle(path: path) else {
            return
        }
        
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            return
        }
        self.library = library
        
        self.commandQueue = device.makeCommandQueue()
        self.commandQueue?.label = "Media Editor Command Queue"
        self.videoInputPass.setup(device: device, library: library)
        self.renderPasses.forEach { $0.setup(device: device, library: library) }
    }
    
    func renderFrame() {
        let device: MTLDevice?
        if let renderTarget = self.renderTarget {
            device = renderTarget.mtlDevice
        } else if let currentDevice = self.device {
            device = currentDevice
        } else {
            device = nil
        }
        guard let device = device,
              let commandQueue = self.commandQueue,
              let textureCache = self.textureCache else {
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        var texture: MTLTexture
        if let currentTexture = self.currentTexture {
            texture = currentTexture
        } else if let (currentPixelBuffer, textureRotation) = self.currentPixelBuffer, let videoTexture = self.videoInputPass.processPixelBuffer(currentPixelBuffer, rotation: textureRotation, textureCache: textureCache, device: device, commandBuffer: commandBuffer) {
            texture = videoTexture
        } else {
            return
        }
        
        for renderPass in self.renderPasses {
            if let nextTexture = renderPass.process(input: texture, device: device, commandBuffer: commandBuffer) {
                texture = nextTexture
            }
        }
        if self.renderTarget != nil {
            self.outputRenderPass.process(input: texture, device: device, commandBuffer: commandBuffer)
        }
        self.finalTexture = texture
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            if let self {
                self.semaphore.signal()
                
#if targetEnvironment(simulator)
                if let onNextRender = self.onNextRender {
                    self.onNextRender = nil
                    Queue.mainQueue().async {
                        onNextRender()
                    }
                }
#endif
            }
        }
        
#if targetEnvironment(simulator)
#else
        if let renderTarget = self.renderTarget, let drawable = renderTarget.drawable {
            drawable.addPresentedHandler { [weak self] _ in
                if let self, let onNextRender = self.onNextRender {
                    self.onNextRender = nil
                    Queue.mainQueue().async {
                        onNextRender()
                    }
                }
            }
        }
#endif
        
        if let _ = self.renderTarget {
            commandBuffer.commit()
            commandBuffer.waitUntilScheduled()
        } else {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
    
    func consumeTexture(_ texture: MTLTexture) {
        self.semaphore.wait()
        
        self.currentTexture = texture
        self.renderTarget?.scheduleFrame()
    }
    
    func consumeVideoPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: TextureRotation) {
        self.semaphore.wait()
        
        self.currentPixelBuffer = (pixelBuffer, rotation)
        self.renderTarget?.scheduleFrame()
    }
    
    func renderTargetDidChange(_ target: RenderTarget?) {
        self.renderTarget = target
        self.setup()
    }
    
    func renderTargetDrawableSizeDidChange(_ size: CGSize) {
        self.renderTarget?.scheduleFrame()
    }
    
    func finalRenderedImage() -> UIImage? {
        if let finalTexture = self.finalTexture, let device = self.renderTarget?.mtlDevice {
            return getTextureImage(device: device, texture: finalTexture)
        } else {
            return nil
        }
    }
}
