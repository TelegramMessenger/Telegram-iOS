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
    func connect(to renderer: MediaEditorRenderer)
    func invalidate()
    
    func setRate(_ rate: Float)
}

protocol RenderTarget: AnyObject {
    var mtlDevice: MTLDevice? { get }
    
    var drawableSize: CGSize { get }
    var colorPixelFormat: MTLPixelFormat { get }
    var drawable: MTLDrawable? { get }
    var renderPassDescriptor: MTLRenderPassDescriptor? { get }
    
    func redraw()
}

final class MediaEditorRenderer {
    enum Input {
        case texture(MTLTexture, CMTime, Bool, CGRect?)
        case videoBuffer(VideoPixelBuffer, CGRect?)
        case ciImage(CIImage, CMTime)
        
        var timestamp: CMTime {
            switch self {
            case let .texture(_, timestamp, _, _):
                return timestamp
            case let .videoBuffer(videoBuffer, _):
                return videoBuffer.timestamp
            case let .ciImage(_, timestamp):
                return timestamp
            }
        }
    }
    
    private var device: MTLDevice?
    private var library: MTLLibrary?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    private var semaphore = DispatchSemaphore(value: 3)
    
    private var renderPasses: [RenderPass] = []
    
    private let ciInputPass = CIInputPass()
    private let mainVideoInputPass = VideoInputPass()
    private var additionalVideoInputPass: [Int : VideoInputPass] = [:]
    let videoFinishPass = VideoFinishPass()
    
    private let outputRenderPass = OutputRenderPass()
    private weak var renderTarget: RenderTarget? {
        didSet {
            self.outputRenderPass.renderTarget = self.renderTarget
        }
    }

    var textureSource: TextureSource? {
        didSet {
            self.textureSource?.connect(to: self)
        }
    }
    
    private var currentMainInput: Input?
    var currentMainInputMask: MTLTexture?
    private var currentAdditionalInputs: [Input] = []
    private(set) var resultTexture: MTLTexture?
    
    var displayEnabled = true
    var skipEditingPasses = false
    var needsDisplay = false
    
    var onNextRender: (() -> Void)?
    var onNextAdditionalRender: (() -> Void)?
    
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
    
    private func commonSetup(device: MTLDevice) {
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
        self.ciInputPass.setup(device: device, library: library)
        self.mainVideoInputPass.setup(device: device, library: library)
        self.videoFinishPass.setup(device: device, library: library)
        self.renderPasses.forEach { $0.setup(device: device, library: library) }
    }
    
    private func setup() {
        guard let device = self.renderTarget?.mtlDevice else {
            return
        }
        
        self.commonSetup(device: device)
        guard let library = self.library else {
            return
        }
        self.outputRenderPass.setup(device: device, library: library)
    }
    
    func setupForComposer(composer: MediaEditorComposer) {
        guard let device = composer.device else {
            return
        }
        self.device = device
        self.commonSetup(device: device)
    }
    
    func setRate(_ rate: Float) {
        self.textureSource?.setRate(rate)
    }
        
    private func combinedTextureFromCurrentInputs(device: MTLDevice, commandBuffer: MTLCommandBuffer, textureCache: CVMetalTextureCache) -> MTLTexture? {
        guard let library = self.library else {
            return nil
        }
        var passMainInput: VideoFinishPass.Input?
        var passAdditionalInputs: [VideoFinishPass.Input] = []
        
        func textureFromInput(_ input: MediaEditorRenderer.Input, videoInputPass: VideoInputPass) -> VideoFinishPass.Input? {
            switch input {
            case let .texture(texture, _, hasTransparency, rect):
                return VideoFinishPass.Input(texture: texture, hasTransparency: hasTransparency, rect: rect)
            case let .videoBuffer(videoBuffer, rect):
                if let texture = videoInputPass.processPixelBuffer(videoBuffer, textureCache: textureCache, device: device, commandBuffer: commandBuffer) {
                    return VideoFinishPass.Input(texture: texture, hasTransparency: false, rect: rect)
                } else {
                    return nil
                }
            case let .ciImage(image, _):
                if let texture = self.ciInputPass.processCIImage(image, device: device, commandBuffer: commandBuffer) {
                    return VideoFinishPass.Input(texture: texture, hasTransparency: true, rect: nil)
                } else {
                    return nil
                }
            }
        }
        
        guard let mainInput = self.currentMainInput else {
            return nil
        }
        
        if let input = textureFromInput(mainInput, videoInputPass: self.mainVideoInputPass) {
            passMainInput = input
        }
        var index = 0
        for additionalInput in self.currentAdditionalInputs {
            let videoInputPass: VideoInputPass
            if let current = self.additionalVideoInputPass[index] {
                videoInputPass = current
            } else {
                videoInputPass = VideoInputPass()
                videoInputPass.setup(device: device, library: library)
                self.additionalVideoInputPass[index] = videoInputPass
            }
            if let input = textureFromInput(additionalInput, videoInputPass: videoInputPass) {
                passAdditionalInputs.append(input)
            }
            index += 1
        }
        if let passMainInput {
            return self.videoFinishPass.process(input: passMainInput, inputMask: self.currentMainInputMask, hasTransparency: passMainInput.hasTransparency, secondInput: passAdditionalInputs, timestamp: mainInput.timestamp, device: device, commandBuffer: commandBuffer)
        } else {
            return nil
        }
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
              let textureCache = self.textureCache,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              var texture = self.combinedTextureFromCurrentInputs(device: device, commandBuffer: commandBuffer, textureCache: textureCache)
        else {
            self.didRenderFrame()
            return
        }

        if !self.skipEditingPasses {
            for renderPass in self.renderPasses {
                if let nextTexture = renderPass.process(input: texture, device: device, commandBuffer: commandBuffer) {
                    texture = nextTexture
                }
            }
        }
        self.resultTexture = texture
        
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
              let texture = self.resultTexture
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
                
                if let onNextAdditionalRender = self.onNextAdditionalRender {
                    if !self.currentAdditionalInputs.isEmpty {
                        self.onNextAdditionalRender = nil
                        Queue.mainQueue().after(0.016) {
                            onNextAdditionalRender()
                        }
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
    
    func consume(
        main: MediaEditorRenderer.Input,
        additionals: [MediaEditorRenderer.Input],
        render: Bool,
        displayEnabled: Bool = true
    ) {
        self.displayEnabled = displayEnabled
        
        if render {
            self.willRenderFrame()
        }
        
        self.currentMainInput = main
        self.currentAdditionalInputs = additionals
        
        if render {
            self.renderFrame()
        }
    }
    
    func renderTargetDidChange(_ target: RenderTarget?) {
        self.renderTarget = target
        self.setup()
    }
    
    func renderTargetDrawableSizeDidChange(_ size: CGSize) {
        self.renderTarget?.redraw()
    }
    
    func finalRenderedImage(mirror: Bool = false) -> UIImage? {
        if let finalTexture = self.resultTexture, let device = self.renderTarget?.mtlDevice {
            return getTextureImage(device: device, texture: finalTexture, mirror: mirror)
        } else {
            return nil
        }
    }
}
