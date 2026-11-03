import Foundation
import AVFoundation
import TelegramCore
import FFMpegBinding

final class MediaEditorVideoAVAssetWriter: MediaEditorVideoExportWriter {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String) {        
        Logger.shared.log("VideoExport", "Will setup asset writer")
        
        let url = URL(fileURLWithPath: outputPath)
        self.writer = try? AVAssetWriter(url: url, fileType: .mp4)
        guard let writer = self.writer else {
            return
        }
        writer.shouldOptimizeForNetworkUse = configuration.shouldOptimizeForNetworkUse
        
        Logger.shared.log("VideoExport", "Did setup asset writer")
    }
    
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, preferredTransform: CGAffineTransform?, sourceFrameRate: Float) {
        guard let writer = self.writer else {
            return
        }
        
        Logger.shared.log("VideoExport", "Will setup video input")
        
        var dimensions = configuration.dimensions
        var videoSettings = configuration.videoSettings
        if var compressionSettings = videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any] {
            compressionSettings[AVVideoExpectedSourceFrameRateKey] = sourceFrameRate
            videoSettings[AVVideoCompressionPropertiesKey] = compressionSettings
        }
        if let preferredTransform {
            if (preferredTransform.b == -1 && preferredTransform.c == 1) || (preferredTransform.b == 1 && preferredTransform.c == -1) {
                dimensions = CGSize(width: dimensions.height, height: dimensions.width)
            }
            videoSettings[AVVideoWidthKey] = Int(dimensions.width)
            videoSettings[AVVideoHeightKey] = Int(dimensions.height)
        }
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        if let preferredTransform {
            videoInput.transform = preferredTransform
           
        }
        videoInput.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: UInt32(dimensions.width),
            kCVPixelBufferHeightKey as String: UInt32(dimensions.height)
        ]
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        } else {
            Logger.shared.log("VideoExport", "Failed to add video input")
        }
        self.videoInput = videoInput
    }
    
    func setupAudioInput(configuration: MediaEditorVideoExport.Configuration) {
        guard let writer = self.writer else {
            return
        }
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.audioSettings)
        audioInput.expectsMediaDataInRealTime = false
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }
        self.audioInput = audioInput
    }
    
    func startWriting() -> Bool {
        return self.writer?.startWriting() ?? false
    }
    
    func startSession(atSourceTime time: CMTime) {
        self.writer?.startSession(atSourceTime: time)
    }
    
    func finishWriting(completion: @escaping () -> Void) {
        self.writer?.finishWriting(completionHandler: completion)
    }
    
    func cancelWriting() {
        self.writer?.cancelWriting()
    }
    
    func requestVideoDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        self.videoInput?.requestMediaDataWhenReady(on: queue, using: block)
    }
    
    func requestAudioDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        self.audioInput?.requestMediaDataWhenReady(on: queue, using: block)
    }
    
    var isReadyForMoreVideoData: Bool {
        return self.videoInput?.isReadyForMoreMediaData ?? false
    }
    
    func appendVideoBuffer(_ buffer: CMSampleBuffer) -> Bool {
        return self.videoInput?.append(buffer) ?? false
    }
    
    func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, at time: CMTime) -> Bool {
        return self.adaptor.append(pixelBuffer, withPresentationTime: time)
    }
    
    var pixelBufferPool: CVPixelBufferPool? {
        return self.adaptor.pixelBufferPool
    }
    
    func markVideoAsFinished() {
        self.videoInput?.markAsFinished()
    }
    
    var isReadyForMoreAudioData: Bool {
        return self.audioInput?.isReadyForMoreMediaData ?? false
    }
    
    func appendAudioBuffer(_ buffer: CMSampleBuffer) -> Bool {
        return self.audioInput?.append(buffer) ?? false
    }
    
    func markAudioAsFinished() {
        self.audioInput?.markAsFinished()
    }
    
    var status: ExportWriterStatus {
        if let writer = self.writer {
            switch writer.status {
            case .unknown:
                return .unknown
            case .writing:
                return .writing
            case .completed:
                return .completed
            case .failed:
                return .failed
            case .cancelled:
                return .cancelled
            @unknown default:
                fatalError()
            }
        } else {
            return .unknown
        }
    }
    
    var error: Error? {
        return self.writer?.error
    }
}
