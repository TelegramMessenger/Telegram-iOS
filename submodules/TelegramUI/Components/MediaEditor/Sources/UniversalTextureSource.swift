import Foundation
import AVFoundation
import Metal
import MetalKit

final class UniversalTextureSource: TextureSource {
    enum Input {
        case image(UIImage)
        case video(AVPlayerItem)
        
        fileprivate func createContext(renderTarget: RenderTarget, queue: DispatchQueue, additional: Bool) -> InputContext {
            switch self {
            case .image:
                return ImageInputContext(input: self, renderTarget: renderTarget, queue: queue)
            case .video:
                return VideoInputContext(input: self, renderTarget: renderTarget, queue: queue, additional: additional)
            }
        }
    }
    
    private weak var renderTarget: RenderTarget?
    private var displayLink: CADisplayLink?
    private let queue: DispatchQueue
    
    private var mainInputContext: InputContext?
    private var additionalInputContext: InputContext?
    
    var forceUpdates = false
    private var rate: Float = 1.0
    
    weak var output: MediaEditorRenderer?
    
    init(renderTarget: RenderTarget) {
        self.renderTarget = renderTarget
        
        self.queue = DispatchQueue(
            label: "UniversalTextureSource Queue",
            qos: .userInteractive,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil
        )
    }
    
    func setMainInput(_ input: Input) {
        guard let renderTarget = self.renderTarget else {
            return
        }
        self.mainInputContext = input.createContext(renderTarget: renderTarget, queue: self.queue, additional: false)
        self.update(forced: true)
    }
    
    func setAdditionalInput(_ input: Input?) {
        guard let renderTarget = self.renderTarget else {
            return
        }
        if let input {
            self.additionalInputContext = input.createContext(renderTarget: renderTarget, queue: self.queue, additional: true)
        } else {
            self.additionalInputContext = nil
        }
        self.update(forced: true)
    }
    

    func setRate(_ rate: Float) {
        self.rate = rate
    }
    
    private var previousAdditionalOutput: MediaEditorRenderer.Input?
    private func update(forced: Bool) {
        let time = CACurrentMediaTime()
        
        let needsDisplayLink = (self.mainInputContext?.needsDisplayLink ?? false) || (self.additionalInputContext?.needsDisplayLink ?? false)
        if needsDisplayLink {
            if self.displayLink == nil {
                let displayLink = CADisplayLink(target: DisplayLinkTarget({ [weak self] in
                    if let self {
                        self.update(forced: self.forceUpdates)
                    }
                }), selector: #selector(DisplayLinkTarget.handleDisplayLinkUpdate(sender:)))
                displayLink.preferredFramesPerSecond = 60
                displayLink.add(to: .main, forMode: .common)
                self.displayLink = displayLink
            }
        } else {
            if let displayLink = self.displayLink {
                self.displayLink = nil
                displayLink.invalidate()
            }
        }
        
        guard self.rate > 0.0 || forced else {
            return
        }
                
        let main = self.mainInputContext?.output(time: time)
        var additional = self.additionalInputContext?.output(time: time)
        if let additional {
            self.previousAdditionalOutput = additional
        } else if self.additionalInputContext != nil {
            additional = self.previousAdditionalOutput
        }
        
        guard let main else {
            return
        }
        
        self.output?.consume(main: main, additional: additional, render: true)
    }
    
    func connect(to consumer: MediaEditorRenderer) {
        self.output = consumer
        self.update(forced: true)
    }
    
    func invalidate() {
        self.mainInputContext?.invalidate()
        self.additionalInputContext?.invalidate()
    }
    
    private class DisplayLinkTarget {
        private let update: () -> Void
        init(_ update: @escaping () -> Void) {
            self.update = update
        }
        @objc func handleDisplayLinkUpdate(sender: CADisplayLink) {
            self.update()
        }
    }
//    
//    private func setupDisplayLink(frameRate: Int) {
//        self.displayLink?.invalidate()
//        self.displayLink = nil
//        
//        if self.playerItemOutput != nil {

//        }
//    }
}

private protocol InputContext {
    typealias Input = UniversalTextureSource.Input
    typealias Output = MediaEditorRenderer.Input
    
    var input: Input { get }
    func output(time: Double) -> Output?
    
    var needsDisplayLink: Bool { get }
    
    func invalidate()
}

private class ImageInputContext: InputContext {
    fileprivate var input: Input
    private var texture: MTLTexture?
    
    init(input: Input, renderTarget: RenderTarget, queue: DispatchQueue) {
        guard case let .image(image) = input else {
            fatalError()
        }
        self.input = input
        if let device = renderTarget.mtlDevice {
            self.texture = loadTexture(image: image, device: device)
        }
    }
    
    func output(time: Double) -> Output? {
        return self.texture.flatMap { .texture($0, .zero) }
    }
    
    func invalidate() {
        self.texture = nil
    }
    
    var needsDisplayLink: Bool {
        return false
    }
}

private class VideoInputContext: NSObject, InputContext, AVPlayerItemOutputPullDelegate {
    fileprivate var input: Input
    private var videoOutput: AVPlayerItemVideoOutput?
    private var textureRotation: TextureRotation = .rotate0Degrees
    
    var playerItem: AVPlayerItem {
        guard case let .video(playerItem) = self.input else {
            fatalError()
        }
        return playerItem
    }
    
    init(input: Input, renderTarget: RenderTarget, queue: DispatchQueue, additional: Bool) {
        guard case .video = input else {
            fatalError()
        }
        self.input = input
        super.init()
        
        //TODO: mirror if self.additionalPlayer == nil && self.mirror
        self.textureRotation = textureRotatonForAVAsset(self.playerItem.asset, mirror: additional)
        
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
        
        let videoOutput = AVPlayerItemVideoOutput(outputSettings: outputSettings)
        videoOutput.suppressesPlayerRendering = true
        videoOutput.setDelegate(self, queue: queue)
        self.playerItem.add(videoOutput)
        self.videoOutput = videoOutput
    }
    
    func output(time: Double) -> Output? {
        guard let videoOutput = self.videoOutput else {
            return nil
        }
        let requestTime = videoOutput.itemTime(forHostTime: time)
        if requestTime < .zero {
            return nil
        }
        var presentationTime: CMTime = .zero
        var videoPixelBuffer: VideoPixelBuffer?
        if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: requestTime, itemTimeForDisplay: &presentationTime) {
            videoPixelBuffer = VideoPixelBuffer(pixelBuffer: pixelBuffer, rotation: self.textureRotation, timestamp: presentationTime)
        }
        return videoPixelBuffer.flatMap { .videoBuffer($0) }
    }
    
    func invalidate() {
        if let videoOutput = self.videoOutput {
            self.videoOutput = nil
            self.playerItem.remove(videoOutput)
            videoOutput.setDelegate(nil, queue: nil)
        }
    }
    
    var needsDisplayLink: Bool {
        return true
    }
}
