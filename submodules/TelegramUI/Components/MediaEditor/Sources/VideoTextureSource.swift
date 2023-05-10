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
    
    private var preferredVideoTransform: CGAffineTransform = .identity
    
    private var forceUpdate: Bool = false
    
    weak var output: TextureConsumer?
    var textureCache: CVMetalTextureCache!
    var queue: DispatchQueue!
    var started: Bool = false
    
    init(player: AVPlayer, renderTarget: RenderTarget) {
        self.player = player
        
        if let device = renderTarget.mtlDevice, CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache) != kCVReturnSuccess {
            print("error")
        }
        
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
        print()
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
        self.playerItemStatusObservation = self.playerItem?.observe(\.status, options: [.initial,.new], changeHandler: { [weak self] item, change in
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
                self.preferredVideoTransform = track.preferredTransform
                break
            }
        }
        if !hasVideoTrack {
            assertionFailure("No video track found.")
            return
        }
        
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as NSString as String: kCVPixelFormatType_32BGRA])
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
            displayLink.preferredFramesPerSecond = 30
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
            if let texture = self.pixelBufferToMTLTexture(pixelBuffer: pixelBuffer) {
                self.output?.consumeTexture(texture, rotation: .rotate90Degrees)
            }
//
//            self.handler(VideoFrame(preferredTrackTransform: self.preferredVideoTransform,
//                                    presentationTimestamp: presentationTime,
//                                    playerTimestamp: player.currentTime(),
//                                    pixelBuffer: pixelBuffer))
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
    
    func start() {

    }
    
    func pause() {

    }
    
    func connect(to consumer: TextureConsumer) {
        self.output = consumer
    }
    
    private func pixelBufferToMTLTexture(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format: MTLPixelFormat = .bgra8Unorm
        var textureRef : CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache, pixelBuffer, nil, format, width, height, 0, &textureRef)
        if status == kCVReturnSuccess {
            return CVMetalTextureGetTexture(textureRef!)
        }
        return nil
    }
    
    public func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        self.displayLink?.isPaused = false
        self.player.play()
    }
}
