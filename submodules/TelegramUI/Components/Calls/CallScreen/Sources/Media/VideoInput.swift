import AVFoundation
import Metal
import CoreVideo
import Display

public final class VideoSourceOutput {
    public let y: MTLTexture
    public let uv: MTLTexture
    public let rotationAngle: Float
    public let sourceId: Int
    
    public init(y: MTLTexture, uv: MTLTexture, rotationAngle: Float, sourceId: Int) {
        self.y = y
        self.uv = uv
        self.rotationAngle = rotationAngle
        self.sourceId = sourceId
    }
}

public protocol VideoSource: AnyObject {
    typealias Output = VideoSourceOutput
    
    var updated: (() -> Void)? { get set }
    var currentOutput: Output? { get }
}

public final class FileVideoSource: VideoSource {
    private let playerLooper: AVPlayerLooper
    private let queuePlayer: AVQueuePlayer
    
    private var videoOutput: AVPlayerItemVideoOutput
    private var device: MTLDevice
    private var textureCache: CVMetalTextureCache?
    
    private var targetItem: AVPlayerItem?
    
    public private(set) var currentOutput: Output?
    public var updated: (() -> Void)?
    
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    public var sourceId: Int = 0
    
    public init?(device: MTLDevice, url: URL) {
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
        
        self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
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
        
        var rotationAngle: Float = 0.0
        if currentTime.seconds <= currentItem.duration.seconds * 0.25 {
            rotationAngle = 0.0
        } else if currentTime.seconds <= currentItem.duration.seconds * 0.5 {
            rotationAngle = Float.pi * 0.5
        } else if currentTime.seconds <= currentItem.duration.seconds * 0.75 {
            rotationAngle = Float.pi
        } else {
            rotationAngle = Float.pi * 3.0 / 2.0
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
        
        rotationAngle = Float.pi * 0.5
        
        self.currentOutput = Output(y: yTexture, uv: uvTexture, rotationAngle: rotationAngle, sourceId: self.sourceId)
        return true
    }
}
