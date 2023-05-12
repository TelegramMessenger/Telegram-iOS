import Foundation
import UIKit
import Metal
import MetalKit
import Photos
import SwiftSignalKit

protocol TextureConsumer: AnyObject {
    func consumeTexture(_ texture: MTLTexture, rotation: TextureRotation)
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
    func process(input: MTLTexture, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture?
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
    private var outputRenderPass = OutputRenderPass()
    private weak var renderTarget: RenderTarget? {
        didSet {
            self.outputRenderPass.renderTarget = self.renderTarget
        }
    }

    private var commandQueue: MTLCommandQueue?
    private var currentTexture: MTLTexture?
    private var currentRotation: TextureRotation = .rotate0Degrees
    private var library: MTLLibrary?
    
    var finalTexture: MTLTexture?
    
    var externalSemaphore: DispatchSemaphore?
    
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
        
        let mainBundle = Bundle(for: MediaEditorRenderer.self)
        guard let path = mainBundle.path(forResource: "MediaEditorBundle", ofType: "bundle") else {
            return
        }
        guard let bundle = Bundle(path: path) else {
            return
        }
        
        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: bundle) else {
            return
        }
        self.library = defaultLibrary
        
        self.commandQueue = device.makeCommandQueue()
        self.commandQueue?.label = "Media Editor Command Queue"
        self.renderPasses.forEach { $0.setup(device: device, library: defaultLibrary) }
        self.outputRenderPass.setup(device: device, library: defaultLibrary)
    }
    
    private var currentDevice: MTLDevice?
    func setupForComposer(composer: MediaEditorComposer) {
        guard let device = composer.device else {
            return
        }
        self.currentDevice = device
        
        let mainBundle = Bundle(for: MediaEditorRenderer.self)
        guard let path = mainBundle.path(forResource: "MediaEditorBundle", ofType: "bundle") else {
            return
        }
        guard let bundle = Bundle(path: path) else {
            return
        }
        
        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: bundle) else {
            return
        }
        self.library = defaultLibrary
        
        self.commandQueue = device.makeCommandQueue()
        self.commandQueue?.label = "Media Editor Command Queue"
        self.renderPasses.forEach { $0.setup(device: device, library: defaultLibrary) }
    }
    
    private var currentCommandBuffer: MTLCommandBuffer?
    func renderFrame() {
        let device: MTLDevice?
        if let renderTarget = self.renderTarget {
            device = renderTarget.mtlDevice
        } else if let currentDevice = self.currentDevice {
            device = currentDevice
        } else {
            device = nil
        }
        guard let device = device,
              let commandQueue = self.commandQueue,
              var texture = self.currentTexture else {
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        var rotation: TextureRotation = self.currentRotation
        for renderPass in self.renderPasses {
            if let nextTexture = renderPass.process(input: texture, rotation: rotation, device: device, commandBuffer: commandBuffer) {
                if nextTexture !== texture {
                    rotation = .rotate0Degrees
                }
                texture = nextTexture
            }
        }
        if self.renderTarget != nil {
            let _ = self.outputRenderPass.process(input: texture, rotation: rotation, device: device, commandBuffer: commandBuffer)
        }
        self.finalTexture = texture
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.semaphore.signal()
            self?.externalSemaphore?.signal()
        }
        
        if let _ = self.renderTarget {
            commandBuffer.commit()
            commandBuffer.waitUntilScheduled()
        } else {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
    
    func commit() {
        if let commandBuffer = self.currentCommandBuffer {
            commandBuffer.commit()
            self.currentCommandBuffer = nil
        }
    }
    
    func consumeTexture(_ texture: MTLTexture, rotation: TextureRotation) {
        self.semaphore.wait()
        
        self.currentTexture = texture
        self.currentRotation = rotation
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
        if let finalTexture = self.finalTexture {
            return getTextureImage(finalTexture)
        } else {
            return nil
        }
    }
    
    private func getTextureImage(_ texture: MTLTexture) -> UIImage? {
        guard let device = self.renderTarget?.mtlDevice else {
            return nil
        }
        let context = CIContext(mtlDevice: device)
        guard var ciImage = CIImage(mtlTexture: texture) else {
            return nil
        }
        let transform = CGAffineTransform(1.0, 0.0, 0.0, -1.0, 0.0, ciImage.extent.height)
        ciImage = ciImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: CGSize(width: ciImage.extent.width, height: ciImage.extent.height))) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
