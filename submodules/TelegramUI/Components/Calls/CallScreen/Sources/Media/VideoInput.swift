import AVFoundation
import Metal
import CoreVideo

class VideoInput {
    final class Output {
        let y: MTLTexture
        let uv: MTLTexture
        
        init(y: MTLTexture, uv: MTLTexture) {
            self.y = y
            self.uv = uv
        }
    }
    
    private let playerLooper: AVPlayerLooper
    private let queuePlayer: AVQueuePlayer
    
    private var videoOutput: AVPlayerItemVideoOutput
    private var device: MTLDevice
    private var textureCache: CVMetalTextureCache?
    
    private var targetItem: AVPlayerItem?
    
    private(set) var currentOutput: Output?
    var updated: (() -> Void)?
    
    private var displayLink: SharedDisplayLink.Subscription?
    
    init?(device: MTLDevice, url: URL) {
        self.device = device
        CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache)
        
        let playerItem = AVPlayerItem(url: url)
        self.queuePlayer = AVQueuePlayer(playerItem: playerItem)
        self.playerLooper = AVPlayerLooper(player: self.queuePlayer, templateItem: playerItem)
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        self.videoOutput = AVPlayerItemVideoOutput(outputSettings: outputSettings)
        
        self.queuePlayer.play()
        
        self.displayLink = SharedDisplayLink.shared.add(framesPerSecond: .fps(60.0), { [weak self] in
            guard let self else {
                return
            }
            if self.updateOutput() {
                self.updated?()
            }
        })
    }
    
    private func updateOutput() -> Bool {
        if self.targetItem !== self.queuePlayer.currentItem {
            self.targetItem?.remove(self.videoOutput)
            self.targetItem = self.queuePlayer.currentItem
            if let targetItem = self.targetItem {
                targetItem.add(self.videoOutput)
            }
        }
        
        guard let currentItem = self.targetItem else {
            return false
        }
        
        let currentTime = currentItem.currentTime()
        guard self.videoOutput.hasNewPixelBuffer(forItemTime: currentTime) else {
            return false
        }
        
        var pixelBuffer: CVPixelBuffer?
        pixelBuffer = self.videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil)
        
        guard let buffer = pixelBuffer else {
            return false
        }
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        var cvMetalTextureY: CVMetalTexture?
        var status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, buffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
        guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
            return false
        }
        var cvMetalTextureUV: CVMetalTexture?
        status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, buffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
        guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
            return false
        }
        
        self.currentOutput = Output(y: yTexture, uv: uvTexture)
        return true
    }
}

class ControlVideoInput {
    private let playerLooper: AVPlayerLooper
    private let queuePlayer: AVQueuePlayer
    
    private let playerLayer: AVPlayerLayer
    
    private var targetItem: AVPlayerItem?
    
    init(url: URL, playerLayer: AVPlayerLayer) {
        let playerItem = AVPlayerItem(url: url)
        self.queuePlayer = AVQueuePlayer(playerItem: playerItem)
        self.playerLooper = AVPlayerLooper(player: self.queuePlayer, templateItem: playerItem)
        
        self.playerLayer = playerLayer
        playerLayer.player = self.queuePlayer
        
        self.queuePlayer.play()
    }
}
