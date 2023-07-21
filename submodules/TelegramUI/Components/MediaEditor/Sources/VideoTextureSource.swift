import Foundation
import AVFoundation
import Metal
import MetalKit

func textureRotatonForAVAsset(_ asset: AVAsset, mirror: Bool = false) -> TextureRotation {
    for track in asset.tracks {
        if track.mediaType == .video {            
            let t = track.preferredTransform
            if t.a == -1.0 && t.d == -1.0 {
                return .rotate180Degrees
            } else if t.a == 1.0 && t.d == 1.0 {
                return .rotate0Degrees
            } else if t.b == -1.0 && t.c == 1.0 {
                return .rotate270Degrees
            }  else if t.a == -1.0 && t.d == 1.0 {
                return .rotate270Degrees
            } else if t.a == 1.0 && t.d == -1.0  {
                return .rotate180Degrees
            } else {
                return mirror ? .rotate90DegreesMirrored : .rotate90Degrees
            }
        }
    }
    return .rotate0Degrees
}

final class VideoTextureSource: NSObject, TextureSource, AVPlayerItemOutputPullDelegate {
    private weak var player: AVPlayer?
    private weak var additionalPlayer: AVPlayer?
    private weak var playerItem: AVPlayerItem?
    private weak var additionalPlayerItem: AVPlayerItem?
    
    private let mirror: Bool
    
    private var playerItemOutput: AVPlayerItemVideoOutput?
    private var additionalPlayerItemOutput: AVPlayerItemVideoOutput?
        
    private var displayLink: CADisplayLink?
    
    private let device: MTLDevice?
    private var textureRotation: TextureRotation = .rotate0Degrees
    private var additionalTextureRotation: TextureRotation = .rotate0Degrees
        
    private var forceUpdate: Bool = false
    
    weak var output: TextureConsumer?
    var queue: DispatchQueue!
    var started: Bool = false
    
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
            target: nil)
        
        super.init()
        
        self.playerItem = player.currentItem
        self.additionalPlayerItem = additionalPlayer?.currentItem
        self.handleReadyToPlay()
    }
        
    func invalidate() {
        self.playerItemOutput?.setDelegate(nil, queue: nil)
        self.playerItemOutput = nil
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
        
    private func handleReadyToPlay() {
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
        self.textureRotation = textureRotatonForAVAsset(playerItem.asset, mirror: additionalPlayer == nil && mirror)
        if !hasVideoTrack {
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
        
        if let additionalPlayerItem = self.additionalPlayerItem {
            self.additionalTextureRotation = textureRotatonForAVAsset(additionalPlayerItem.asset, mirror: true)
            
            let output = AVPlayerItemVideoOutput(outputSettings: outputSettings)
            output.suppressesPlayerRendering = true
            output.setDelegate(self, queue: self.queue)
            additionalPlayerItem.add(output)
            self.additionalPlayerItemOutput = output
        }
        
        self.setupDisplayLink(frameRate: min(60, frameRate))
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
            self.output?.consumeVideoPixelBuffer(pixelBuffer: mainPixelBuffer, additionalPixelBuffer: additionalPixelBuffer, render: true)
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
    
    override func setup(device: MTLDevice, library: MTLLibrary) {
        super.setup(device: device, library: library)
    }
    
    func processPixelBuffer(_ pixelBuffer: VideoPixelBuffer, textureCache: CVMetalTextureCache, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        func textureFromPixelBuffer(_ pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, width: Int, height: Int, plane: Int) -> MTLTexture? {
            var textureRef : CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, plane, &textureRef)
            if status == kCVReturnSuccess, let textureRef {
                return CVMetalTextureGetTexture(textureRef)
            }
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer.pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer.pixelBuffer)
        guard let inputYTexture = textureFromPixelBuffer(pixelBuffer.pixelBuffer, pixelFormat: .r8Unorm, width: width, height: height, plane: 0),
              let inputCbCrTexture = textureFromPixelBuffer(pixelBuffer.pixelBuffer, pixelFormat: .rg8Unorm, width: width >> 1, height: height >> 1, plane: 1) else {
            return nil
        }
        return self.process(yTexture: inputYTexture, cbcrTexture: inputCbCrTexture, width: width, height: height, rotation: pixelBuffer.rotation, device: device, commandBuffer: commandBuffer)
    }
    
    func process(yTexture: MTLTexture, cbcrTexture: MTLTexture, width: Int, height: Int, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device, rotation: rotation)
        
        func textureDimensionsForRotation(width: Int, height: Int, rotation: TextureRotation) -> (width: Int, height: Int) {
            switch rotation {
            case .rotate90Degrees, .rotate270Degrees, .rotate90DegreesMirrored:
                return (height, width)
            default:
                return (width, height)
            }
        }
        
        let (outputWidth, outputHeight) = textureDimensionsForRotation(width: width, height: height, rotation: rotation)
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = outputWidth
            textureDescriptor.height = outputHeight
            textureDescriptor.pixelFormat = self.pixelFormat
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

private func verticesData(
    textureRotation: TextureRotation,
    containerSize: CGSize,
    position: CGPoint,
    size: CGSize,
    rotation: CGFloat,
    z: Float = 0.0
) -> [VertexData] {
    let topLeft: simd_float2
    let topRight: simd_float2
    let bottomLeft: simd_float2
    let bottomRight: simd_float2
    
    switch textureRotation {
    case .rotate0Degrees:
        topLeft = simd_float2(0.0, 1.0)
        topRight = simd_float2(1.0, 1.0)
        bottomLeft = simd_float2(0.0, 0.0)
        bottomRight = simd_float2(1.0, 0.0)
    case .rotate0DegreesMirrored:
        topLeft = simd_float2(1.0, 1.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(0.0, 0.0)
    case .rotate180Degrees:
        topLeft = simd_float2(1.0, 0.0)
        topRight = simd_float2(0.0, 0.0)
        bottomLeft = simd_float2(1.0, 1.0)
        bottomRight = simd_float2(0.0, 1.0)
    case .rotate90Degrees:
        topLeft = simd_float2(1.0, 1.0)
        topRight = simd_float2(1.0, 0.0)
        bottomLeft = simd_float2(0.0, 1.0)
        bottomRight = simd_float2(0.0, 0.0)
    case .rotate90DegreesMirrored:
        topLeft = simd_float2(1.0, 0.0)
        topRight = simd_float2(1.0, 1.0)
        bottomLeft = simd_float2(0.0, 0.0)
        bottomRight = simd_float2(0.0, 1.0)
    case .rotate270Degrees:
        topLeft = simd_float2(0.0, 0.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(1.0, 1.0)
    }
    
    let angle = Float(.pi - rotation)
    let cosAngle = cos(angle)
    let sinAngle = sin(angle)

    let centerX = Float(position.x)
    let centerY = Float(position.y)

    let halfWidth = Float(size.width / 2.0)
    let halfHeight = Float(size.height / 2.0)
    
    return [
        VertexData(
            pos: simd_float4(
                x: (centerX + (halfWidth * cosAngle) - (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY + (halfWidth * sinAngle) + (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: topLeft,
            localPos: simd_float2(0.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX - (halfWidth * cosAngle) - (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY - (halfWidth * sinAngle) + (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: topRight,
            localPos: simd_float2(1.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX + (halfWidth * cosAngle) + (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY + (halfWidth * sinAngle) - (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: bottomLeft,
            localPos: simd_float2(0.0, 1.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX - (halfWidth * cosAngle) + (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY - (halfWidth * sinAngle) - (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: bottomRight,
            localPos: simd_float2(1.0, 1.0)
        )
    ]
}

private func lookupSpringValue(_ t: CGFloat) -> CGFloat {
    let table: [(CGFloat, CGFloat)] = [
        (0.0, 0.0),
        (0.0625, 0.1123005598783493),
        (0.125, 0.31598418951034546),
        (0.1875, 0.5103585720062256),
        (0.25, 0.6650152802467346),
        (0.3125, 0.777747631072998),
        (0.375, 0.8557760119438171),
        (0.4375, 0.9079672694206238),
        (0.5, 0.942038357257843),
        (0.5625, 0.9638798832893372),
        (0.625, 0.9776856303215027),
        (0.6875, 0.9863143563270569),
        (0.75, 0.991658091545105),
        (0.8125, 0.9949421286582947),
        (0.875, 0.9969474077224731),
        (0.9375, 0.9981651306152344),
        (1.0, 1.0)
    ]
    
    for i in 0 ..< table.count - 2 {
        let lhs = table[i]
        let rhs = table[i + 1]
        
        if t >= lhs.0 && t <= rhs.0 {
            let fraction = (t - lhs.0) / (rhs.0 - lhs.0)
            let value = lhs.1 + fraction * (rhs.1 - lhs.1)
            return value
        }
    }
    return 1.0
}

final class VideoInputScalePass: RenderPass {
    private var cachedTexture: MTLTexture?
    
    var mainPipelineState: MTLRenderPipelineState?
    var mainVerticesBuffer: MTLBuffer?
    var mainTextureRotation: TextureRotation = .rotate0Degrees
    
    var additionalVerticesBuffer: MTLBuffer?
    var additionalTextureRotation: TextureRotation = .rotate0Degrees
    
    var pixelFormat: MTLPixelFormat  {
        return .bgra8Unorm
    }
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "defaultVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "dualFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = self.pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.mainPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func encodeVideo(
        using encoder: MTLRenderCommandEncoder,
        containerSize: CGSize,
        texture: MTLTexture,
        textureRotation: TextureRotation,
        position: VideoPosition,
        roundness: Float,
        alpha: Float,
        zPosition: Float,
        device: MTLDevice
    ) {
        encoder.setFragmentTexture(texture, index: 0)
        
        let center = CGPoint(
            x: position.position.x - containerSize.width / 2.0,
            y: containerSize.height - position.position.y - containerSize.height / 2.0
        )
        
        let size = CGSize(
            width: position.size.width * position.scale,
            height: position.size.height * position.scale
        )
        
        let vertices = verticesData(textureRotation: textureRotation, containerSize: containerSize, position: center, size: size, rotation: position.rotation, z: zPosition)
        let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VertexData>.stride * vertices.count,
            options: [])
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        
        var resolution = simd_uint2(UInt32(size.width), UInt32(size.height))
        encoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 0)
        
        var roundness = roundness
        encoder.setFragmentBytes(&roundness, length: MemoryLayout<simd_float1>.size, index: 1)
        
        var alpha = alpha
        encoder.setFragmentBytes(&alpha, length: MemoryLayout<simd_float1>.size, index: 2)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    func update(values: MediaEditorValues) {
        if let position = values.additionalVideoPosition, let scale = values.additionalVideoScale, let rotation = values.additionalVideoRotation {
            self.additionalPosition = VideoInputScalePass.VideoPosition(position: position, size: CGSize(width: 1080.0 / 4.0, height: 1440.0 / 4.0), scale: scale, rotation: rotation)
        }
        if !values.additionalVideoPositionChanges.isEmpty {
            self.videoPositionChanges = values.additionalVideoPositionChanges
        }
    }
    
    private var mainPosition = VideoPosition(
        position: CGPoint(x: 1080 / 2.0, y: 1920.0 / 2.0),
        size: CGSize(width: 1080.0, height: 1920.0),
        scale: 1.0,
        rotation: 0.0
    )
    
    private var additionalPosition = VideoPosition(
        position: CGPoint(x: 1080 / 2.0, y: 1920.0 / 2.0),
        size: CGSize(width: 1440.0, height: 1920.0),
        scale: 0.5,
        rotation: 0.0
    )
    
    private var transitionDuration = 0.5
    private var videoPositionChanges: [VideoPositionChange] = []
    
    enum VideoType {
        case main
        case additional
        case transition
    }
    
    struct VideoPosition {
        let position: CGPoint
        let size: CGSize
        let scale: CGFloat
        let rotation: CGFloat
        
        func mixed(with other: VideoPosition, fraction: CGFloat) -> VideoPosition {
            let position = CGPoint(
                x: self.position.x + (other.position.x - self.position.x) * fraction,
                y: self.position.y + (other.position.y - self.position.y) * fraction
            )
            let size = CGSize(
                width: self.size.width + (other.size.width - self.size.width) * fraction,
                height: self.size.height + (other.size.height - self.size.height) * fraction
            )
            let scale = self.scale + (other.scale - self.scale) * fraction
            let rotation = self.rotation + (other.rotation - self.rotation) * fraction
            
            return VideoPosition(
                position: position,
                size: size,
                scale: scale,
                rotation: rotation
            )
        }
    }
    
    struct VideoState {
        let texture: MTLTexture
        let textureRotation: TextureRotation
        let position: VideoPosition
        let roundness: Float
        let alpha: Float
    }
    
    func transitionState(for time: CMTime, mainInput: MTLTexture, additionalInput: MTLTexture?) -> (VideoState, VideoState?, VideoState?) {
        let timestamp = time.seconds
        
        var backgroundTexture = mainInput
        var backgroundTextureRotation = self.mainTextureRotation
        
        var foregroundTexture = additionalInput
        var foregroundTextureRotation = self.additionalTextureRotation
        
        var mainPosition = self.mainPosition
        var additionalPosition = self.additionalPosition
        var disappearingPosition = self.mainPosition
        
        var transitionFraction = 1.0
        if let additionalInput {
            var previousChange: VideoPositionChange?
            for change in self.videoPositionChanges {
                if timestamp >= change.timestamp {
                    previousChange = change
                }
                if timestamp < change.timestamp {
                    break
                }
            }
            
            if let previousChange {
                if previousChange.additional {
                    backgroundTexture = additionalInput
                    backgroundTextureRotation = self.additionalTextureRotation
                    
                    mainPosition = VideoPosition(position: mainPosition.position, size: CGSize(width: 1440.0, height: 1920.0), scale: mainPosition.scale, rotation: mainPosition.rotation)
                    additionalPosition = VideoPosition(position: additionalPosition.position, size: CGSize(width: 1080.0 / 4.0, height: 1920.0 / 4.0), scale: additionalPosition.scale, rotation: additionalPosition.rotation)
                    
                    foregroundTexture = mainInput
                    foregroundTextureRotation = self.mainTextureRotation
                } else {
                    disappearingPosition = VideoPosition(position: mainPosition.position, size: CGSize(width: 1440.0, height: 1920.0), scale: mainPosition.scale, rotation: mainPosition.rotation)
                }
                if previousChange.timestamp > 0.0 && timestamp < previousChange.timestamp + transitionDuration {
                    transitionFraction = (timestamp - previousChange.timestamp) / transitionDuration
                }
            }
        }
        
        var backgroundVideoState = VideoState(texture: backgroundTexture, textureRotation: backgroundTextureRotation, position: mainPosition, roundness: 0.0, alpha: 1.0)
        var foregroundVideoState: VideoState?
        var disappearingVideoState: VideoState?
        
        if let foregroundTexture {
            var foregroundPosition = additionalPosition
            var foregroundAlpha: Float = 1.0
            if transitionFraction < 1.0 {
                let springFraction = lookupSpringValue(transitionFraction)
                
                let appearingPosition = VideoPosition(position: additionalPosition.position, size: additionalPosition.size, scale: 0.01, rotation: self.additionalPosition.rotation)
                let backgroundInitialPosition = VideoPosition(position: additionalPosition.position, size: CGSize(width: mainPosition.size.width / 4.0, height: mainPosition.size.height / 4.0), scale: additionalPosition.scale, rotation: additionalPosition.rotation)
                
                foregroundPosition = appearingPosition.mixed(with: additionalPosition, fraction: springFraction)
                
                disappearingVideoState = VideoState(texture: foregroundTexture, textureRotation: foregroundTextureRotation, position: disappearingPosition, roundness: 0.0, alpha: 1.0)
                backgroundVideoState = VideoState(texture: backgroundTexture, textureRotation: backgroundTextureRotation, position: backgroundInitialPosition.mixed(with: mainPosition, fraction: springFraction), roundness: Float(1.0 - springFraction), alpha: 1.0)
                
                foregroundAlpha = min(1.0, max(0.0, Float(transitionFraction) * 2.5))
            }
            foregroundVideoState = VideoState(texture: foregroundTexture, textureRotation: foregroundTextureRotation, position: foregroundPosition, roundness: 1.0, alpha: foregroundAlpha)
        }
        
        return (backgroundVideoState, foregroundVideoState, disappearingVideoState)
    }
    
    func process(input: MTLTexture, secondInput: MTLTexture?, timestamp: CMTime, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard max(input.width, input.height) > 1920 || secondInput != nil else {
            return input
        }
        
        let scaledSize = CGSize(width: input.width, height: input.height).fitted(CGSize(width: 1920.0, height: 1920.0))
        let width: Int
        let height: Int
        
        if secondInput != nil {
            width = 1080
            height = 1920
        } else {
            width = Int(scaledSize.width)
            height = Int(scaledSize.height)
        }
        self.mainPosition = VideoPosition(position: CGPoint(x: width / 2, y: height / 2), size: CGSize(width: width, height: height), scale: 1.0, rotation: 0.0)
        
        let containerSize = CGSize(width: width, height: height)
        
        if self.cachedTexture == nil || self.cachedTexture?.width != width || self.cachedTexture?.height != height {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = width
            textureDescriptor.height = height
            textureDescriptor.pixelFormat = input.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return input
            }
            self.cachedTexture = texture
            texture.label = "scaledVideoTexture"
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(width), height: Double(height),
            znear: -1.0, zfar: 1.0)
        )
        
        renderCommandEncoder.setRenderPipelineState(self.mainPipelineState!)
        
        let (mainVideoState, additionalVideoState, transitionVideoState) = self.transitionState(for: timestamp, mainInput: input, additionalInput: secondInput)
        
        if let transitionVideoState {
            self.encodeVideo(
                using: renderCommandEncoder,
                containerSize: containerSize,
                texture: transitionVideoState.texture,
                textureRotation: transitionVideoState.textureRotation,
                position: transitionVideoState.position,
                roundness: transitionVideoState.roundness,
                alpha: transitionVideoState.alpha,
                zPosition: 0.75,
                device: device
            )
        }
        
        self.encodeVideo(
            using: renderCommandEncoder,
            containerSize: containerSize,
            texture: mainVideoState.texture,
            textureRotation: mainVideoState.textureRotation,
            position: mainVideoState.position,
            roundness: mainVideoState.roundness,
            alpha: mainVideoState.alpha,
            zPosition: 0.0,
            device: device
        )
        
        if let additionalVideoState {
            self.encodeVideo(
                using: renderCommandEncoder,
                containerSize: containerSize,
                texture: additionalVideoState.texture,
                textureRotation: additionalVideoState.textureRotation,
                position: additionalVideoState.position,
                roundness: additionalVideoState.roundness,
                alpha: additionalVideoState.alpha,
                zPosition: 0.5,
                device: device
            )
        }
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return nil
    }
}
