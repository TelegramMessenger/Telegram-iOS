import Foundation
import UIKit
import Metal
import MetalKit
import Photos
import SwiftSignalKit

final class VideoPixelBuffer {
    let pixelBuffer: CVPixelBuffer
    let rotation: TextureRotation
    let timestamp: CMTime
    
    init(
        pixelBuffer: CVPixelBuffer,
        rotation: TextureRotation,
        timestamp: CMTime
    ) {
        self.pixelBuffer = pixelBuffer
        self.rotation = rotation
        self.timestamp = timestamp
    }
}

protocol TextureConsumer: AnyObject {
    func consumeTexture(_ texture: MTLTexture, render: Bool)
    func consumeVideoPixelBuffer(pixelBuffer: VideoPixelBuffer, additionalPixelBuffer: VideoPixelBuffer?, render: Bool)
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
    func invalidate()
}

protocol RenderTarget: AnyObject {
    var mtlDevice: MTLDevice? { get }
    
    var drawableSize: CGSize { get }
    var colorPixelFormat: MTLPixelFormat { get }
    var drawable: MTLDrawable? { get }
    var renderPassDescriptor: MTLRenderPassDescriptor? { get }
    
    func redraw()
}

final class MediaEditorRenderer: TextureConsumer {
    var textureSource: TextureSource? {
        didSet {
            self.textureSource?.connect(to: self)
        }
    }
    
    private var semaphore = DispatchSemaphore(value: 3)
    private var renderPasses: [RenderPass] = []
    
    private let videoInputPass = VideoInputPass()
    private let additionalVideoInputPass = VideoInputPass()
    let videoFinishPass = VideoInputScalePass()
    
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
    private var currentAdditionalTexture: MTLTexture?
    private var currentTime: CMTime = .zero
    
    private var currentPixelBuffer: VideoPixelBuffer?
    private var currentAdditionalPixelBuffer: VideoPixelBuffer?
    
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
        self.additionalVideoInputPass.setup(device: device, library: library)
        self.videoFinishPass.setup(device: device, library: library)
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
        self.additionalVideoInputPass.setup(device: device, library: library)
        self.videoFinishPass.setup(device: device, library: library)
        self.renderPasses.forEach { $0.setup(device: device, library: library) }
    }
    
    public var displayEnabled = true
    var renderPassedEnabled = true
    var needsDisplay = false
    
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
            self.didRenderFrame()
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            self.didRenderFrame()
            return
        }
        
        var texture: MTLTexture
        if let currentAdditionalTexture = self.currentAdditionalTexture, let currentTexture = self.currentTexture {
            self.videoFinishPass.mainTextureRotation = .rotate0Degrees
            self.videoFinishPass.additionalTextureRotation = .rotate0DegreesMirrored
            if let result = self.videoFinishPass.process(input: currentTexture, secondInput: currentAdditionalTexture, timestamp: self.currentTime, device: device, commandBuffer: commandBuffer) {
                texture = result
            } else {
                texture = currentTexture
            }
        } else if let currentTexture = self.currentTexture {
            texture = currentTexture
        } else if let currentPixelBuffer = self.currentPixelBuffer, let currentAdditionalPixelBuffer = self.currentAdditionalPixelBuffer, let videoTexture = self.videoInputPass.processPixelBuffer(currentPixelBuffer, textureCache: textureCache, device: device, commandBuffer: commandBuffer), let additionalVideoTexture = self.additionalVideoInputPass.processPixelBuffer(currentAdditionalPixelBuffer, textureCache: textureCache, device: device, commandBuffer: commandBuffer) {
            if let result = self.videoFinishPass.process(input: videoTexture, secondInput: additionalVideoTexture, timestamp: currentPixelBuffer.timestamp, device: device, commandBuffer: commandBuffer) {
                texture = result
            } else {
                texture = videoTexture
            }
        } else if let currentPixelBuffer = self.currentPixelBuffer, let videoTexture = self.videoInputPass.processPixelBuffer(currentPixelBuffer, textureCache: textureCache, device: device, commandBuffer: commandBuffer) {
            if let result = self.videoFinishPass.process(input: videoTexture, secondInput: nil, timestamp: currentPixelBuffer.timestamp, device: device, commandBuffer: commandBuffer) {
                texture = result
            } else {
                texture = videoTexture
            }
        } else {
            self.didRenderFrame()
            return
        }
        
        if self.renderPassedEnabled {
            for renderPass in self.renderPasses {
                if let nextTexture = renderPass.process(input: texture, device: device, commandBuffer: commandBuffer) {
                    texture = nextTexture
                }
            }
        }
        self.finalTexture = texture
        
        if self.renderTarget == nil {
            commandBuffer.addCompletedHandler { [weak self] _ in
                if let self {
                    self.didRenderFrame()
                }
            }
        }
        commandBuffer.commit()
        
        if let renderTarget = self.renderTarget, self.displayEnabled {
            if self.needsDisplay {
                self.didRenderFrame()
            } else {
                self.needsDisplay = true
                renderTarget.redraw()
            }
        } else {
            commandBuffer.waitUntilCompleted()
        }
    }
    
    func displayFrame() {
        guard let renderTarget = self.renderTarget,
              let device = renderTarget.mtlDevice,
              let commandQueue = self.commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let texture = self.finalTexture
        else {
            self.needsDisplay = false
            self.didRenderFrame()
            return
        }
        commandBuffer.addCompletedHandler { [weak self] _ in
            if let self {
                self.didRenderFrame()
                
                if let onNextRender = self.onNextRender {
                    self.onNextRender = nil
                    Queue.mainQueue().after(0.016) {
                        onNextRender()
                    }
                }
            }
        }
        
        self.outputRenderPass.process(input: texture, device: device, commandBuffer: commandBuffer)
        
        commandBuffer.commit()
        self.needsDisplay = false
    }
    
    func willRenderFrame() {
        let timeout = self.renderTarget != nil ? DispatchTime.now() + 0.1 : .distantFuture
        let _ = self.semaphore.wait(timeout: timeout)
    }
    
    func didRenderFrame() {
        self.semaphore.signal()
    }
    
    func consumeTexture(_ texture: MTLTexture, render: Bool) {
        if render {
            self.willRenderFrame()
        }
        
        self.currentTexture = texture
        if render {
            self.renderFrame()
        }
    }
    
    func consumeTexture(_ texture: MTLTexture, additionalTexture: MTLTexture?, time: CMTime, render: Bool) {
        self.displayEnabled = false
        
        if render {
            self.willRenderFrame()
        }
        
        self.currentTexture = texture
        self.currentAdditionalTexture = additionalTexture
        self.currentTime = time
        if render {
            self.renderFrame()
        }
    }
    
    var previousPresentationTimestamp: CMTime?
    func consumeVideoPixelBuffer(pixelBuffer: VideoPixelBuffer, additionalPixelBuffer: VideoPixelBuffer?, render: Bool) {
        self.willRenderFrame()
        
        self.currentPixelBuffer = pixelBuffer
        if additionalPixelBuffer == nil && self.currentAdditionalPixelBuffer != nil {
        } else {
            self.currentAdditionalPixelBuffer = additionalPixelBuffer
        }
        if render {
            if self.previousPresentationTimestamp == pixelBuffer.timestamp {
                self.didRenderFrame()
            } else {
                self.renderFrame()
            }
        }
        self.previousPresentationTimestamp = pixelBuffer.timestamp
    }
    
    func renderTargetDidChange(_ target: RenderTarget?) {
        self.renderTarget = target
        self.setup()
    }
    
    func renderTargetDrawableSizeDidChange(_ size: CGSize) {
        self.renderTarget?.redraw()
    }
    
    func finalRenderedImage(mirror: Bool = false) -> UIImage? {
        if let finalTexture = self.finalTexture, let device = self.renderTarget?.mtlDevice {
            return getTextureImage(device: device, texture: finalTexture, mirror: mirror)
        } else {
            return nil
        }
    }
}
