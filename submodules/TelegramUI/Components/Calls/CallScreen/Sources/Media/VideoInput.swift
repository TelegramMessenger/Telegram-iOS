import AVFoundation
import Metal
import CoreVideo
import Display
import SwiftSignalKit

public final class VideoSourceOutput {
    public struct MirrorDirection: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let horizontal = MirrorDirection(rawValue: 1 << 0)
        public static let vertical = MirrorDirection(rawValue: 1 << 1)
    }
    
    open class DataBuffer {
        open var pixelBuffer: CVPixelBuffer? {
            return nil
        }
        
        public init() {
        }
    }
    
    public final class BiPlanarTextureLayout {
        public let y: MTLTexture
        public let uv: MTLTexture
        
        public init(y: MTLTexture, uv: MTLTexture) {
            self.y = y
            self.uv = uv
        }
    }
    
    public final class TriPlanarTextureLayout {
        public let y: MTLTexture
        public let u: MTLTexture
        public let v: MTLTexture
        
        public init(y: MTLTexture, u: MTLTexture, v: MTLTexture) {
            self.y = y
            self.u = u
            self.v = v
        }
    }
    
    public enum TextureLayout {
        case biPlanar(BiPlanarTextureLayout)
        case triPlanar(TriPlanarTextureLayout)
    }
    
    public final class NativeDataBuffer: DataBuffer {
        private let pixelBufferValue: CVPixelBuffer
        override public var pixelBuffer: CVPixelBuffer? {
            return self.pixelBufferValue
        }
        
        public init(pixelBuffer: CVPixelBuffer) {
            self.pixelBufferValue = pixelBuffer
        }
    }
    
    public let resolution: CGSize
    public let textureLayout: TextureLayout
    public let dataBuffer: DataBuffer
    public let rotationAngle: Float
    public let followsDeviceOrientation: Bool
    public let mirrorDirection: MirrorDirection
    public let sourceId: Int
    
    public init(resolution: CGSize, textureLayout: TextureLayout, dataBuffer: DataBuffer, rotationAngle: Float, followsDeviceOrientation: Bool, mirrorDirection: MirrorDirection, sourceId: Int) {
        self.resolution = resolution
        self.textureLayout = textureLayout
        self.dataBuffer = dataBuffer
        self.rotationAngle = rotationAngle
        self.followsDeviceOrientation = followsDeviceOrientation
        self.mirrorDirection = mirrorDirection
        self.sourceId = sourceId
    }
}

public protocol VideoSource: AnyObject {
    typealias Output = VideoSourceOutput
    
    var currentOutput: Output? { get }
    
    func addOnUpdated(_ f: @escaping () -> Void) -> Disposable
}

public final class FileVideoSource: VideoSource {
    private let playerLooper: AVPlayerLooper
    private let queuePlayer: AVQueuePlayer
    
    private var videoOutput: AVPlayerItemVideoOutput
    private var device: MTLDevice
    private var textureCache: CVMetalTextureCache?
    
    private var targetItem: AVPlayerItem?
    
    public private(set) var currentOutput: Output?
    private var onUpdatedListeners = Bag<() -> Void>()
    
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    public var sourceId: Int = 0
    public var fixedRotationAngle: Float?
    public var sizeMultiplicator: CGPoint = CGPoint(x: 1.0, y: 1.0)
    
    public init?(device: MTLDevice, url: URL, fixedRotationAngle: Float? = nil) {
        self.fixedRotationAngle = fixedRotationAngle
        
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
                for onUpdated in self.onUpdatedListeners.copyItems() {
                    onUpdated()
                }
            }
        })
    }
    
    public func addOnUpdated(_ f: @escaping () -> Void) -> Disposable {
        let index = self.onUpdatedListeners.add(f)
        
        return ActionDisposable { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.onUpdatedListeners.remove(index)
            }
        }
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
        
        if let fixedRotationAngle = self.fixedRotationAngle {
            rotationAngle = fixedRotationAngle
        }
        
        var resolution = CGSize(width: CGFloat(yTexture.width), height: CGFloat(yTexture.height))
        resolution.width = floor(resolution.width * self.sizeMultiplicator.x)
        resolution.height = floor(resolution.height * self.sizeMultiplicator.y)
        
        self.currentOutput = Output(
            resolution: resolution,
            textureLayout: .biPlanar(Output.BiPlanarTextureLayout(
                y: yTexture,
                uv: uvTexture
            )),
            dataBuffer: Output.NativeDataBuffer(pixelBuffer: buffer),
            rotationAngle: rotationAngle,
            followsDeviceOrientation: false,
            mirrorDirection: [],
            sourceId: self.sourceId
        )
        return true
    }
}
