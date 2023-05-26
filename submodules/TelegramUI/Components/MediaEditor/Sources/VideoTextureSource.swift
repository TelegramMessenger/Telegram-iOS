import Foundation
import AVFoundation
import Metal
import MetalKit

final class VideoTextureSource: NSObject, TextureSource, AVPlayerItemOutputPullDelegate {
    private let player: AVPlayer
    private var playerItem: AVPlayerItem?
    private var playerItemOutput: AVPlayerItemVideoOutput?
    
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var playerItemObservation: NSKeyValueObservation?
    
    private var displayLink: CADisplayLink?
    
    private let device: MTLDevice?
    private var textureRotation: TextureRotation = .rotate0Degrees
        
    private var forceUpdate: Bool = false
    
    weak var output: TextureConsumer?
    var queue: DispatchQueue!
    var started: Bool = false
    
    init(player: AVPlayer, renderTarget: RenderTarget) {
        self.player = player
        self.device = renderTarget.mtlDevice!
                
        self.queue = DispatchQueue(
            label: "VideoTextureSource Queue",
            qos: .userInteractive,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil)
        
        super.init()
        
        self.playerItemObservation = self.player.observe(\.currentItem, options: [.initial, .new], changeHandler: { [weak self] (player, change) in
            guard let strongSelf = self, strongSelf.player == player else {
                return
            }
            strongSelf.updatePlayerItem(strongSelf.player.currentItem)
        })
    }
    
    deinit {
        self.playerItemObservation?.invalidate()
        self.playerItemStatusObservation?.invalidate()
    }
    
    private func updatePlayerItem(_ playerItem: AVPlayerItem?) {
        self.displayLink?.invalidate()
        self.displayLink = nil
        if let output = self.playerItemOutput, let item = self.playerItem {
            if item.outputs.contains(output) {
                item.remove(output)
            }
        }
        self.playerItemOutput = nil
        self.playerItemStatusObservation?.invalidate()
        self.playerItemStatusObservation = nil
        
        self.playerItem = playerItem
        self.playerItemStatusObservation = self.playerItem?.observe(\.status, options: [.initial, .new], changeHandler: { [weak self] item, change in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.playerItem == item, item.status == .readyToPlay {
                strongSelf.handleReadyToPlay()
            }
        })
    }
    
    private func handleReadyToPlay() {
        guard let playerItem = self.playerItem else {
            return
        }
        
        var hasVideoTrack: Bool = false
        for track in playerItem.asset.tracks {
            if track.mediaType == .video {
                hasVideoTrack = true
                
                let t = track.preferredTransform
                if t.a == -1.0 && t.d == -1.0 {
                    self.textureRotation = .rotate180Degrees
                } else if t.a == 1.0 && t.d == 1.0 {
                    self.textureRotation = .rotate0Degrees
                } else if t.b == -1.0 && t.c == 1.0 {
                    self.textureRotation = .rotate270Degrees
                }  else if t.a == -1.0 && t.d == 1.0 {
                    self.textureRotation = .rotate270Degrees
                } else if t.a == 1.0 && t.d == -1.0  {
                    self.textureRotation = .rotate180Degrees
                } else {
                    self.textureRotation = .rotate90Degrees
                }
            }
        }
        if !hasVideoTrack {
            assertionFailure("No video track found.")
            return
        }
        
        let colorProperties: [String: Any] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            AVVideoColorPropertiesKey: colorProperties
        ]
        
        let output = AVPlayerItemVideoOutput(outputSettings: outputSettings)
        output.suppressesPlayerRendering = true
        output.setDelegate(self, queue: self.queue)
        playerItem.add(output)
        self.playerItemOutput = output
        
        self.setupDisplayLink()
    }
    
    private class DisplayLinkTarget {
        private let handler: () -> Void
        init(_ handler: @escaping () -> Void) {
            self.handler = handler
        }
        @objc func handleDisplayLinkUpdate(sender: CADisplayLink) {
            self.handler()
        }
    }
    
    private func setupDisplayLink() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        
        if self.playerItemOutput != nil {
            let displayLink = CADisplayLink(target: DisplayLinkTarget({ [weak self] in
                self?.handleUpdate()
            }), selector: #selector(DisplayLinkTarget.handleDisplayLinkUpdate(sender:)))
            displayLink.preferredFramesPerSecond = 60
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
    }
    
    private func handleUpdate() {
        if self.player.rate != 0 {
            self.forceUpdate = true
        }
        self.update(forced: self.forceUpdate)
        self.forceUpdate = false
    }
    
    private let advanceInterval: TimeInterval = 1.0 / 60.0
    private func update(forced: Bool) {
        guard let output = self.playerItemOutput else {
            return
        }
        
        let requestTime = output.itemTime(forHostTime: CACurrentMediaTime())
        if requestTime < .zero {
            return
        }
        
        if !forced && !output.hasNewPixelBuffer(forItemTime: requestTime) {
            self.displayLink?.isPaused = true
            output.requestNotificationOfMediaDataChange(withAdvanceInterval: self.advanceInterval)
            return
        }
        
        var presentationTime: CMTime = .zero
        if let pixelBuffer = output.copyPixelBuffer(forItemTime: requestTime, itemTimeForDisplay: &presentationTime) {
            self.output?.consumeVideoPixelBuffer(pixelBuffer, rotation: self.textureRotation)
        }
    }
        
    func setNeedsUpdate() {
        self.displayLink?.isPaused = false
        self.forceUpdate = true
    }
    
    func updateIfNeeded() {
        if self.forceUpdate {
            self.update(forced: true)
            self.forceUpdate = false
        }
    }
    
    func connect(to consumer: TextureConsumer) {
        self.output = consumer
    }
    
    public func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        self.displayLink?.isPaused = false
    }
}

final class VideoInputPass: DefaultRenderPass {
    private var cachedTexture: MTLTexture?
    
    override var fragmentShaderFunctionName: String {
        return "bt709ToRGBFragmentShader"
    }
    
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer, rotation: TextureRotation, textureCache: CVMetalTextureCache, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        func textureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, width: Int, height: Int, plane: Int) -> MTLTexture? {
            var textureRef : CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, plane, &textureRef)
            if status == kCVReturnSuccess, let textureRef {
                return CVMetalTextureGetTexture(textureRef)
            }
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let inputYTexture = textureFromPixelBuffer(pixelBuffer, pixelFormat: .r8Unorm, width: width, height: height, plane: 0),
              let inputCbCrTexture = textureFromPixelBuffer(pixelBuffer, pixelFormat: .rg8Unorm, width: width >> 1, height: height >> 1, plane: 1) else {
            return nil
        }
        return self.process(yTexture: inputYTexture, cbcrTexture: inputCbCrTexture, width: width, height: height, rotation: rotation, device: device, commandBuffer: commandBuffer)
    }
    
    func process(yTexture: MTLTexture, cbcrTexture: MTLTexture, width: Int, height: Int, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device, rotation: rotation)
        
        func textureDimensionsForRotation(width: Int, height: Int, rotation: TextureRotation) -> (width: Int, height: Int) {
            switch rotation {
            case .rotate90Degrees, .rotate270Degrees:
                return (height, width)
            default:
                return (width, height)
            }
        }
        
        let (outputWidth, outputHeight) = textureDimensionsForRotation(width: width, height: height, rotation: rotation)
//        let outputSize = CGSize(width: outputWidth, height: outputHeight).fitted(CGSize(width: 1920.0, height: 1920.0))
//        outputWidth = Int(outputSize.width)
//        outputHeight = Int(outputSize.height)
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = outputWidth
            textureDescriptor.height = outputHeight
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            if let texture = device.makeTexture(descriptor: textureDescriptor) {
                self.cachedTexture = texture
            }
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(outputWidth), height: Double(outputHeight),
            znear: -1.0, zfar: 1.0)
        )
        
        renderCommandEncoder.setFragmentTexture(yTexture, index: 0)
        renderCommandEncoder.setFragmentTexture(cbcrTexture, index: 1)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture
    }
}
