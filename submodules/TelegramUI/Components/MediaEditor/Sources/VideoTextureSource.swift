import Foundation
import AVFoundation
import Metal
import MetalKit

final class VideoTextureSource: NSObject, TextureSource, AVPlayerItemOutputPullDelegate {
    private let device: MTLDevice?
    private var displayLink: CADisplayLink?
    
    private let mirror: Bool
    
    private weak var player: AVPlayer?
    private weak var playerItem: AVPlayerItem?
    private var playerItemOutput: AVPlayerItemVideoOutput?
    private var textureRotation: TextureRotation = .rotate0Degrees
    
    private weak var additionalPlayer: AVPlayer?
    private weak var additionalPlayerItem: AVPlayerItem?
    private var additionalPlayerItemOutput: AVPlayerItemVideoOutput?
    private var additionalTextureRotation: TextureRotation = .rotate0Degrees
    
    weak var output: MediaEditorRenderer?
    var queue: DispatchQueue!
    var started: Bool = false

    private var forceUpdate: Bool = false
    
    init(player: AVPlayer, additionalPlayer: AVPlayer?, mirror: Bool, renderTarget: RenderTarget) {
        self.player = player
        self.additionalPlayer = additionalPlayer
        self.mirror = mirror
        self.device = renderTarget.mtlDevice!
                
        self.queue = DispatchQueue(
            label: "VideoTextureSource Queue",
            qos: .userInteractive,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil
        )
        
        super.init()
        
        self.playerItem = player.currentItem
        self.additionalPlayerItem = additionalPlayer?.currentItem
        
        guard let playerItem = self.playerItem else {
            return
        }
        
        var frameRate: Int = 30
        var hasVideoTrack: Bool = false
        for track in playerItem.asset.tracks {
            if track.mediaType == .video {
                if track.nominalFrameRate > 0.0 {
                    frameRate = Int(ceil(track.nominalFrameRate))
                }
                hasVideoTrack = true
                break
            }
        }

        if !hasVideoTrack {
            return
        }
        
        self.textureRotation = textureRotatonForAVAsset(playerItem.asset, mirror: self.additionalPlayer == nil && self.mirror)
        self.playerItemOutput = self.setupPlayerVideoOutput(playerItem: playerItem)
        if let additionalPlayerItem = self.additionalPlayerItem {
            self.additionalTextureRotation = textureRotatonForAVAsset(additionalPlayerItem.asset, mirror: true)
            self.additionalPlayerItemOutput = self.setupPlayerVideoOutput(playerItem: additionalPlayerItem)
        }
        
        self.setupDisplayLink(frameRate: min(60, frameRate))
    }
        
    func invalidate() {
        self.playerItemOutput?.setDelegate(nil, queue: nil)
        self.playerItemOutput = nil
        self.additionalPlayerItemOutput?.setDelegate(nil, queue: nil)
        self.additionalPlayerItemOutput = nil
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    func setAdditionalPlayer(_ additionalPlayer: AVPlayer?) {
        self.additionalPlayer = additionalPlayer
        self.additionalPlayerItem = additionalPlayer?.currentItem
        
        if let additionalPlayerItem = self.additionalPlayerItem {
            self.additionalTextureRotation = textureRotatonForAVAsset(additionalPlayerItem.asset, mirror: true)
            self.additionalPlayerItemOutput = self.setupPlayerVideoOutput(playerItem: additionalPlayerItem)
        } else if let additionalPlayerItemOutput = self.additionalPlayerItemOutput {
            self.additionalPlayerItemOutput = nil
            additionalPlayerItemOutput.setDelegate(nil, queue: nil)

            if let additionalPlayerItem = self.additionalPlayerItem {
                self.additionalPlayerItem = nil
                additionalPlayerItem.remove(additionalPlayerItemOutput)
            }
        }
    }
    
    private func setupPlayerVideoOutput(playerItem: AVPlayerItem) -> AVPlayerItemVideoOutput {
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
        return output
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
    
    private func setupDisplayLink(frameRate: Int) {
        self.displayLink?.invalidate()
        self.displayLink = nil
        
        if self.playerItemOutput != nil {
            let displayLink = CADisplayLink(target: DisplayLinkTarget({ [weak self] in
                self?.handleUpdate()
            }), selector: #selector(DisplayLinkTarget.handleDisplayLinkUpdate(sender:)))
            displayLink.preferredFramesPerSecond = frameRate
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
    }
    
    private func handleUpdate() {
        guard let player = self.player else {
            return
        }
        if player.rate != 0 {
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
        
        let time = CACurrentMediaTime()
        let requestTime = output.itemTime(forHostTime: time)
        if requestTime < .zero {
            return
        }
        
        if !forced && !output.hasNewPixelBuffer(forItemTime: requestTime) {
            self.displayLink?.isPaused = true
            output.requestNotificationOfMediaDataChange(withAdvanceInterval: self.advanceInterval)
            return
        }
        
        var presentationTime: CMTime = .zero
        var mainPixelBuffer: VideoPixelBuffer?
        if let pixelBuffer = output.copyPixelBuffer(forItemTime: requestTime, itemTimeForDisplay: &presentationTime) {
            mainPixelBuffer = VideoPixelBuffer(pixelBuffer: pixelBuffer, rotation: self.textureRotation, timestamp: presentationTime)
        }
        
        let additionalRequestTime = self.additionalPlayerItemOutput?.itemTime(forHostTime: time)
        var additionalPixelBuffer: VideoPixelBuffer?
        if let additionalRequestTime, let pixelBuffer = self.additionalPlayerItemOutput?.copyPixelBuffer(forItemTime: additionalRequestTime, itemTimeForDisplay: &presentationTime) {
            additionalPixelBuffer = VideoPixelBuffer(pixelBuffer: pixelBuffer, rotation: self.additionalTextureRotation, timestamp: presentationTime)
        }
        
        if let mainPixelBuffer {
            self.output?.consume(main: .videoBuffer(mainPixelBuffer), additional: additionalPixelBuffer.flatMap { .videoBuffer($0) }, render: true)
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
    
    func connect(to consumer: MediaEditorRenderer) {
        self.output = consumer
    }
    
    public func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        self.displayLink?.isPaused = false
    }
}
