import AVFoundation
import Metal
import CoreVideo
import Display
import SwiftSignalKit
import Camera
import MetalEngine
import MediaEditor
import TelegramCore

final class CameraVideoSource: VideoSource {
    private var device: MTLDevice
    private var textureCache: CVMetalTextureCache?
        
    private(set) var cameraVideoOutput: CameraVideoOutput!
    
    public private(set) var currentOutput: Output?
    private var onUpdatedListeners = Bag<() -> Void>()
        
    public var sourceId: Int = 0
    public var sizeMultiplicator: CGPoint = CGPoint(x: 1.0, y: 1.0)
    
    public init() {
        self.device = MetalEngine.shared.device
                
        self.cameraVideoOutput = CameraVideoOutput(sink: { [weak self] buffer, mirror in
            self?.push(buffer, mirror: mirror)
        })

        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
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
    
    private func push(_ sampleBuffer: CMSampleBuffer, mirror: Bool) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
                  
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        var cvMetalTextureY: CVMetalTexture?
        var status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, buffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
        guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
            return
        }
        var cvMetalTextureUV: CVMetalTexture?
        status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, buffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
        guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
            return
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
            mirrorDirection: mirror ? [.vertical] : [],
            sourceId: self.sourceId
        )
        
        for onUpdated in self.onUpdatedListeners.copyItems() {
            onUpdated()
        }
    }
}

private let dimensions = CGSize(width: 1080.0, height: 1920.0)

final class LiveStreamMediaSource {
    private let queue = Queue()
    private let pool: CVPixelBufferPool?
    
    private(set) var mainVideoOutput: CameraVideoOutput!
    private(set) var additionalVideoOutput: CameraVideoOutput!
    private let composer: MediaEditorComposer
    
    private var additionalSampleBuffer: CMSampleBuffer?
    
    public private(set) var currentVideoOutput: CVPixelBuffer?
    private var onVideoUpdatedListeners = Bag<() -> Void>()
    
    private var values: MediaEditorValues
    private var cameraPosition: Camera.Position = .back
                
    public init() {
        let width: Int32 = 720
        let height: Int32 = 1280
        
        let dimensions = CGSize(width: CGFloat(1080), height: CGFloat(1920))
        
        let bufferOptions: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3 as NSNumber
        ]
        let pixelBufferOptions: [String: Any] = [
            //kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as NSNumber,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as NSNumber,
            kCVPixelBufferWidthKey as String: UInt32(width),
            kCVPixelBufferHeightKey as String: UInt32(height)
        ]
        
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, bufferOptions as CFDictionary, pixelBufferOptions as CFDictionary, &pool)
        self.pool = pool
        
        self.values = MediaEditorValues(
            peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)),
            originalDimensions: PixelDimensions(dimensions),
            cropOffset: .zero,
            cropRect: CGRect(origin: .zero, size: dimensions),
            cropScale: 1.0,
            cropRotation: 0.0,
            cropMirroring: false,
            cropOrientation: nil,
            gradientColors: nil,
            videoTrimRange: nil,
            videoIsMuted: false,
            videoIsFullHd: false,
            videoIsMirrored: false,
            videoVolume: nil,
            additionalVideoPath: nil,
            additionalVideoIsDual: true,
            additionalVideoPosition: nil,
            additionalVideoScale: 1.625,
            additionalVideoRotation: 0.0,
            additionalVideoPositionChanges: [],
            additionalVideoTrimRange: nil,
            additionalVideoOffset: nil,
            additionalVideoVolume: nil,
            collage: [],
            nightTheme: false,
            drawing: nil,
            maskDrawing: nil,
            entities: [],
            toolValues: [:],
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: nil
        )
        
        self.composer = MediaEditorComposer(
            postbox: nil,
            values: self.values,
            dimensions: dimensions,
            outputDimensions: CGSize(width: 720.0, height: 1280.0),
            textScale: 1.0,
            videoDuration: nil,
            additionalVideoDuration: nil,
            outputsYuvBuffers: true
        )
        
        self.mainVideoOutput = CameraVideoOutput(sink: { [weak self] buffer, mirror in
            guard let self else {
                return
            }
            self.queue.async {
                self.push(mainSampleBuffer: buffer)
            }
        })
        
        self.additionalVideoOutput = CameraVideoOutput(sink: { [weak self] buffer, mirror in
            guard let self else {
                return
            }
            self.queue.async {
                self.additionalSampleBuffer = buffer
            }
        })
    }
    
    func setup(isDualCameraEnabled: Bool, dualCameraPosition: CameraScreenImpl.PIPPosition, position: Camera.Position) {
        var additionalVideoPositionChanges: [VideoPositionChange] = []
        if isDualCameraEnabled && position == .front {
            additionalVideoPositionChanges.append(VideoPositionChange(additional: true, timestamp: CACurrentMediaTime()))
        }
        var values = self.values
        values = values.withUpdatedAdditionalVideoPositionChanges(additionalVideoPositionChanges: additionalVideoPositionChanges)
        values = values.withUpdatedAdditionalVideo(position: self.getAdditionalVideoPosition(dualCameraPosition), scale: 1.625, rotation: 0.0)
        self.values = values
        self.cameraPosition = position
        self.composer.values = values
    }
    
    func markToggleCamera(position: Camera.Position) {
        let timestamp = self.additionalSampleBuffer?.presentationTimeStamp.seconds ?? CACurrentMediaTime()
        
        var values = self.values
        var additionalVideoPositionChanges = values.additionalVideoPositionChanges
        additionalVideoPositionChanges.append(VideoPositionChange(additional: position == .front, timestamp: timestamp))
        values = values.withUpdatedAdditionalVideoPositionChanges(additionalVideoPositionChanges: additionalVideoPositionChanges)
        self.values = values
        self.cameraPosition = position
        self.composer.values = self.values
    }
    
    func setDualCameraPosition(_ pipPosition: CameraScreenImpl.PIPPosition) {
        let timestamp = self.additionalSampleBuffer?.presentationTimeStamp.seconds ?? CACurrentMediaTime()
        
        var values = self.values
        var additionalVideoPositionChanges = values.additionalVideoPositionChanges
        additionalVideoPositionChanges.append(VideoPositionChange(additional: self.cameraPosition == .front, translationFrom: values.additionalVideoPosition ?? .zero, timestamp: timestamp))
        values = values.withUpdatedAdditionalVideoPositionChanges(additionalVideoPositionChanges: additionalVideoPositionChanges)
        values = values.withUpdatedAdditionalVideo(position: self.getAdditionalVideoPosition(pipPosition), scale: 1.625, rotation: 0.0)
        self.values = values
        self.composer.values = values
    }
    
    func getAdditionalVideoPosition(_ pipPosition: CameraScreenImpl.PIPPosition) -> CGPoint {
        let topOffset = CGPoint(x: 267.0, y: 438.0)
        let bottomOffset = CGPoint(x: 267.0, y: 438.0)
        
        let position: CGPoint
        switch pipPosition {
        case .topLeft:
            position = CGPoint(x: topOffset.x, y: topOffset.y)
        case .topRight:
            position = CGPoint(x: dimensions.width - topOffset.x, y: topOffset.y)
        case .bottomLeft:
            position = CGPoint(x: bottomOffset.x, y: dimensions.height - bottomOffset.y)
        case .bottomRight:
            position = CGPoint(x: dimensions.width - bottomOffset.x, y: dimensions.height - bottomOffset.y)
        }
        return position
    }
    
    func addOnVideoUpdated(_ f: @escaping () -> Void) -> Disposable {
        let index = self.onVideoUpdatedListeners.add(f)
        
        return ActionDisposable { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.onVideoUpdatedListeners.remove(index)
            }
        }
    }
    
    private func push(mainSampleBuffer: CMSampleBuffer) {
        let timestamp = mainSampleBuffer.presentationTimeStamp
        
        guard let mainPixelBuffer = CMSampleBufferGetImageBuffer(mainSampleBuffer) else {
            return
        }
        let main: MediaEditorComposer.Input = .videoBuffer(VideoPixelBuffer(pixelBuffer: mainPixelBuffer, rotation: .rotate90Degrees, timestamp: timestamp), nil, 1.0, .zero)
        var additional: [MediaEditorComposer.Input?] = []
        if let additionalPixelBuffer = self.additionalSampleBuffer.flatMap({ CMSampleBufferGetImageBuffer($0) }) {
            additional.append(
                .videoBuffer(VideoPixelBuffer(pixelBuffer: additionalPixelBuffer, rotation: .rotate90DegreesMirrored, timestamp: timestamp), nil, 1.0, .zero)
            )
        }
        self.composer.process(
            main: main,
            additional: additional,
            timestamp: timestamp,
            pool: self.pool,
            completion: { [weak self] pixelBuffer in
                guard let self else {
                    return
                }
                self.queue.async {
                    self.currentVideoOutput = pixelBuffer
                    for onUpdated in self.onVideoUpdatedListeners.copyItems() {
                        onUpdated()
                    }
                }
            }
        )
    }
}
