import Foundation
import AVFoundation
import MetalKit
import SwiftSignalKit
import TelegramCore
import Postbox

enum ExportWriterStatus {
    case unknown
    case writing
    case completed
    case failed
    case cancelled
}

protocol MediaEditorVideoExportWriter {
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String)
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, preferredTransform: CGAffineTransform?, sourceFrameRate: Float)
    func setupAudioInput(configuration: MediaEditorVideoExport.Configuration)
    
    func startWriting() -> Bool
    func startSession(atSourceTime time: CMTime)
    
    func finishWriting(completion: @escaping () -> Void)
    func cancelWriting()
    
    func requestVideoDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void)
    func requestAudioDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void)
    
    var isReadyForMoreVideoData: Bool { get }
    func appendVideoBuffer(_ buffer: CMSampleBuffer) -> Bool
    func appendPixelBuffer(_ buffer: CVPixelBuffer, at time: CMTime) -> Bool
    func markVideoAsFinished()
    
    var pixelBufferPool: CVPixelBufferPool? { get }
    
    var isReadyForMoreAudioData: Bool { get }
    func appendAudioBuffer(_ buffer: CMSampleBuffer) -> Bool
    func markAudioAsFinished()
    
    var status: ExportWriterStatus { get }
    
    var error: Error? { get }
}

public final class MediaEditorVideoAVAssetWriter: MediaEditorVideoExportWriter {
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

public final class MediaEditorVideoExport {
    public enum Subject {
        case image(image: UIImage)
        case video(asset: AVAsset, isStory: Bool)
    }
    
    public struct Configuration {
        public var shouldOptimizeForNetworkUse: Bool = true
        public var videoSettings: [String: Any]
        public var audioSettings: [String: Any]
        public var values: MediaEditorValues
        public var frameRate: Float
        
        public init(
            videoSettings: [String: Any],
            audioSettings: [String: Any],
            values: MediaEditorValues,
            frameRate: Float
        ) {
            self.videoSettings = videoSettings
            self.audioSettings = audioSettings
            self.values = values
            self.frameRate = frameRate
        }
        
        var timeRange: CMTimeRange? {
            if let videoTrimRange = self.values.videoTrimRange {
                return CMTimeRange(start: CMTime(seconds: videoTrimRange.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), end: CMTime(seconds: videoTrimRange.upperBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
            } else {
                return nil
            }
        }
        
        var additionalVideoTimeRange: CMTimeRange? {
            if let videoTrimRange = self.values.additionalVideoTrimRange {
                return CMTimeRange(start: CMTime(seconds: videoTrimRange.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), end: CMTime(seconds: videoTrimRange.upperBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
            } else {
                return nil
            }
        }
        
        var additionalVideoStartTime: CMTime {
            let lowerBound = self.values.additionalVideoTrimRange?.lowerBound ?? 0.0
            let offset = -min(0.0, self.values.additionalVideoOffset ?? 0.0)
            if !lowerBound.isZero || !offset.isZero {
                return CMTime(seconds: offset + lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            } else {
                return .zero
            }
        }
        
        var audioTimeRange: CMTimeRange? {
            if let audioTrack = self.values.audioTrack {
                let offset = max(0.0, self.values.audioTrackOffset ?? 0.0)
                if let range = self.values.audioTrackTrimRange {
                    return CMTimeRange(
                        start: CMTime(seconds: offset + range.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                        end: CMTime(seconds: offset + range.upperBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                    )
                } else {
                    return CMTimeRange(
                        start: CMTime(seconds: offset, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                        end: CMTime(seconds: offset + min(15.0, audioTrack.duration), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                    )
                }
            } else {
                return nil
            }
        }
        
        var audioStartTime: CMTime {
            if let range = self.values.audioTrackTrimRange {
                let offset = -min(0.0, self.values.audioTrackOffset ?? 0.0)
                return CMTime(seconds: offset + range.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            } else {
                return .zero
            }
        }
        
        var composerDimensions: CGSize {
            if self.values.isStory {
                return CGSize(width: 1080.0, height: 1920.0)
            } else {
                let maxSize = CGSize(width: 1920.0, height: 1920.0)
                return targetSize(cropSize: self.values.originalDimensions.cgSize.aspectFitted(maxSize))
            }
        }
        
        var dimensions: CGSize {
            if let width = self.videoSettings[AVVideoWidthKey] as? Int, let height = self.videoSettings[AVVideoHeightKey] as? Int {
                return CGSize(width: width, height: height)
            } else {
                return CGSize(width: 1920.0, height: 1080.0)
            }
        }
    }
    
    public enum Status {
        case idle
        case paused
        case exporting
        case finished
    }
    
    public enum ExportError {
        case noTracksFound
        case addVideoOutput
        case addAudioOutput
        case writing(Error?)
        case reading(Error?)
        case invalid
        case cancelled
    }
    
    public enum ExportStatus {
        case unknown
        case progress(Float)
        case completed
        case failed(ExportError)
    }
    
    public private(set) var internalStatus: Status = .idle
    
    private let queue = Queue()
    private let postbox: Postbox
    private let subject: Subject
    private let configuration: Configuration
    private let textScale: CGFloat
    private let outputPath: String
        
    private var reader: AVAssetReader?
    private var videoOutput: AVAssetReaderOutput?
    private var textureRotation: TextureRotation = .rotate0Degrees
    private var frameRate: Float?
    
    private var additionalVideoOutput: AVAssetReaderOutput?
    private var additionalTextureRotation: TextureRotation = .rotate0Degrees
    private var additionalFrameRate: Float?
    private var additionalVideoDuration: Double?
    
    private var mainComposeFramerate: Float?
    
    private var audioOutput: AVAssetReaderOutput?
            
    private var writer: MediaEditorVideoExportWriter?
    private var composer: MediaEditorComposer?
    
    private let duration = ValuePromise<CMTime>()
    private var durationValue: CMTime? {
        didSet {
            if let durationValue = self.durationValue {
                self.duration.set(durationValue)
            }
        }
    }
    
    private var imageArguments: (frameRate: Double, position: CMTime)?
    
    private let pauseDispatchGroup = DispatchGroup()
    private var cancelled = false
    
    private var startTimestamp = CACurrentMediaTime()
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    public init(postbox: Postbox, subject: Subject, configuration: Configuration, outputPath: String, textScale: CGFloat = 1.0) {
        self.postbox = postbox
        self.subject = subject
        self.configuration = configuration
        self.outputPath = outputPath
        self.textScale = textScale
        
        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        self.setup()
        
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.resume()
        })
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.pause()
        })
    }
    
    enum Input {
        case image(UIImage)
        case video(AVAsset)
        
        var isVideo: Bool {
            if case .video = self {
                return true
            }
            return false
        }
    }
    
    private func setup() {
        var mainAsset: AVAsset?
        
        var additionalAsset: AVAsset?
        if let additionalPath = self.configuration.values.additionalVideoPath {
            additionalAsset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
        }

        var audioAsset: AVAsset?
        if let audioTrack = self.configuration.values.audioTrack {
            let audioPath = fullDraftPath(peerId: self.configuration.values.peerId, path: audioTrack.path)
            audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
        }

        var mainInput: Input
        let additionalInput: Input? = additionalAsset.flatMap { .video($0) }
        var isStory = true
        
        switch self.subject {
        case let .video(asset, isStoryValue):
            mainAsset = asset
            mainInput = .video(asset)
            isStory = isStoryValue
        case let .image(image):
            mainInput = .image(image)
        }
        
        let duration: CMTime
        if let mainAsset {
            if let trimmedDuration = self.configuration.timeRange?.duration {
                duration = trimmedDuration
            } else {
                if isStory && mainAsset.duration.seconds > 60.0 {
                    duration = CMTime(seconds: 60.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                } else {
                    duration = mainAsset.duration
                }
            }
        } else if let additionalAsset {
            if let trimmedDuration = self.configuration.additionalVideoTimeRange?.duration {
                duration = trimmedDuration
            } else {
                if additionalAsset.duration.seconds > 60.0 {
                    duration = CMTime(seconds: 60.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                } else {
                    duration = additionalAsset.duration
                }
            }
        } else {
            if let audioDuration = self.configuration.audioTimeRange?.duration {
                duration = audioDuration
            } else {
                duration = CMTime(seconds: 5.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            }
        }
        self.durationValue = duration
        
        self.setupWithInputs(main: mainInput, additional: additionalInput, audio: audioAsset, isStory: isStory)
    }
        
    private func setupComposer() {
        guard self.composer == nil else {
            return
        }
        
        var duration = self.durationValue?.seconds
        if case .image = self.subject {
            duration = nil
        }
        
        self.composer = MediaEditorComposer(
            postbox: self.postbox,
            values: self.configuration.values,
            dimensions: self.configuration.composerDimensions,
            outputDimensions: self.configuration.dimensions,
            textScale: self.textScale,
            videoDuration: duration,
            additionalVideoDuration: self.additionalVideoDuration
        )
    }
    
    private func setupWithInputs(main: Input, additional: Input?, audio: AVAsset?, isStory: Bool) {
        var hasVideoOrAudio = false
        if main.isVideo || additional?.isVideo == true || audio != nil {
            hasVideoOrAudio = true
        }
        
        var composition: AVMutableComposition?
        var mainVideoTrack: AVMutableCompositionTrack?
        var additionalVideoTrack: AVMutableCompositionTrack?
        var audioMix: AVMutableAudioMix?
        
        if hasVideoOrAudio, let duration = self.durationValue {
            composition = AVMutableComposition()
            var audioMixParameters: [AVMutableAudioMixInputParameters] = []
            
            let wholeRange: CMTimeRange = CMTimeRangeMake(start: .zero, duration: duration)
            func clampedRange(trackDuration: CMTime, trackTrimRange: CMTimeRange?, trackStart: CMTime, maxDuration: CMTime) -> CMTimeRange {
                var result = CMTimeRange(start: .zero, duration: trackDuration)
                if let trackTrimRange {
                    result = trackTrimRange
                }
                if trackStart + result.duration > maxDuration {
                    result = CMTimeRange(start: result.start, end: maxDuration - trackStart)
                }
                return result
            }
            
            var readerRange = wholeRange
            if case let .video(asset) = main {
                self.textureRotation = textureRotatonForAVAsset(asset)
                if let videoAssetTrack = asset.tracks(withMediaType: .video).first {
                    if let compositionTrack = composition?.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        mainVideoTrack = compositionTrack
                        compositionTrack.preferredTransform = videoAssetTrack.preferredTransform
                        
                        try? compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoAssetTrack, at: .zero)
                    }
                }
                if let audioAssetTrack = asset.tracks(withMediaType: .audio).first, !self.configuration.values.videoIsMuted {
                    if let compositionTrack = composition?.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try? compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioAssetTrack, at: .zero)
                        
                        if let volume = self.configuration.values.videoVolume, volume != 1.0 {
                            let trackParameters = AVMutableAudioMixInputParameters(track: compositionTrack)
                            trackParameters.trackID = compositionTrack.trackID
                            trackParameters.setVolume(Float(volume), at: .zero)
                            audioMixParameters.append(trackParameters)
                        }
                    }
                }
                if let timeRange = self.configuration.timeRange {
                    readerRange = timeRange
                }
            }
            if let additional, case let .video(asset) = additional {
                self.additionalTextureRotation = textureRotatonForAVAsset(asset, mirror: true)
                self.additionalVideoDuration = asset.duration.seconds
                
                let startTime: CMTime
                let timeRange: CMTimeRange
                if mainVideoTrack == nil {
                    startTime = .zero
                    timeRange = CMTimeRange(start: .zero, end: asset.duration)
                } else {
                    startTime = self.configuration.additionalVideoStartTime
                    timeRange = clampedRange(trackDuration: asset.duration, trackTrimRange: self.configuration.additionalVideoTimeRange, trackStart: startTime, maxDuration: readerRange.end)
                }
                
                if let videoAssetTrack = asset.tracks(withMediaType: .video).first {
                    if let compositionTrack = composition?.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        additionalVideoTrack = compositionTrack
                        compositionTrack.preferredTransform = videoAssetTrack.preferredTransform
                        
                        try? compositionTrack.insertTimeRange(timeRange, of: videoAssetTrack, at: startTime)
                    }
                }
                if let audioAssetTrack = asset.tracks(withMediaType: .audio).first, self.configuration.values.additionalVideoVolume ?? 1.0 > 0.01 {
                    if let compositionTrack = composition?.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try? compositionTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: startTime)
                        
                        if let volume = self.configuration.values.additionalVideoVolume, volume != 1.0 {
                            let trackParameters = AVMutableAudioMixInputParameters(track: compositionTrack)
                            trackParameters.trackID = compositionTrack.trackID
                            trackParameters.setVolume(Float(volume), at: .zero)
                            audioMixParameters.append(trackParameters)
                        }
                    }
                }
                if mainVideoTrack == nil, let timeRange = self.configuration.additionalVideoTimeRange {
                    readerRange = timeRange
                }
            }
            if let audio, let audioAssetTrack = audio.tracks(withMediaType: .audio).first {
                let startTime: CMTime
                if mainVideoTrack == nil && additionalVideoTrack == nil {
                    startTime = .zero
                } else {
                    startTime = self.configuration.audioStartTime
                }
                let timeRange = clampedRange(trackDuration: audio.duration, trackTrimRange: self.configuration.audioTimeRange, trackStart: startTime, maxDuration: readerRange.end)
                
                if let compositionTrack = composition?.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try? compositionTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: startTime)
                    
                    if let volume = self.configuration.values.audioTrackVolume, volume != 1.0 {
                        let trackParameters = AVMutableAudioMixInputParameters(track: compositionTrack)
                        trackParameters.trackID = compositionTrack.trackID
                        trackParameters.setVolume(Float(volume), at: .zero)
                        audioMixParameters.append(trackParameters)
                    }
                }
            }
            
            if !audioMixParameters.isEmpty {
                audioMix = AVMutableAudioMix()
                audioMix?.inputParameters = audioMixParameters
            }
            
            if let composition {
                self.reader = try? AVAssetReader(asset: composition)
                self.reader?.timeRange = readerRange
            }
        }
        
        self.writer = MediaEditorVideoAVAssetWriter()
        guard let writer = self.writer else {
            return
        }
        writer.setup(configuration: self.configuration, outputPath: self.outputPath)
        self.setupComposer()
                
        if let reader {
            let colorProperties: [String: Any] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
            let outputSettings: [String: Any]  = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                AVVideoColorPropertiesKey: colorProperties
            ]
            if let mainVideoTrack {
                let videoOutput = AVAssetReaderTrackOutput(track: mainVideoTrack, outputSettings: outputSettings)
                videoOutput.alwaysCopiesSampleData = true
                if reader.canAdd(videoOutput) {
                    reader.add(videoOutput)
                } else {
                    self.internalStatus = .finished
                    self.statusValue = .failed(.addVideoOutput)
                }
                self.videoOutput = videoOutput
            }
            if let additionalVideoTrack {
                let videoOutput = AVAssetReaderTrackOutput(track: additionalVideoTrack, outputSettings: outputSettings)
                videoOutput.alwaysCopiesSampleData = true
                if reader.canAdd(videoOutput) {
                    reader.add(videoOutput)
                } else {
                    self.internalStatus = .finished
                    self.statusValue = .failed(.addVideoOutput)
                }
                self.additionalVideoOutput = videoOutput
            }
        }
        
        func frameRate(for track: AVCompositionTrack) -> Float {
            if track.nominalFrameRate > 0.0 {
                return track.nominalFrameRate
            } else if track.minFrameDuration.seconds > 0.0 {
                return Float(1.0 / track.minFrameDuration.seconds)
            }
            return 30.0
        }
        
        if let mainVideoTrack {
            self.frameRate = frameRate(for: mainVideoTrack)
        }
        if let additionalVideoTrack {
            self.additionalFrameRate = frameRate(for: additionalVideoTrack)
        }
        let sourceFrameRate: Float = (self.frameRate ?? self.additionalFrameRate) ?? 30.0
        self.mainComposeFramerate = round(sourceFrameRate / 30.0) * 30.0
        writer.setupVideoInput(configuration: self.configuration, preferredTransform: nil, sourceFrameRate: sourceFrameRate)
     
        if let reader {
            let audioTracks = composition?.tracks(withMediaType: .audio) ?? []
            if audioTracks.count > 0 {
                let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
                audioOutput.audioMix = audioMix
                audioOutput.alwaysCopiesSampleData = false
                if reader.canAdd(audioOutput) {
                    reader.add(audioOutput)
                } else {
                    self.internalStatus = .finished
                    self.statusValue = .failed(.addAudioOutput)
                }
                self.audioOutput = audioOutput
                
                writer.setupAudioInput(configuration: self.configuration)
            }
        }
    }
    
    private var skippingAdditionalCopyUpdate = false
        
    private func encodeVideo() -> Bool {
        guard let writer = self.writer else {
            return false
        }
        
        var appendFailed = false
        while writer.isReadyForMoreVideoData {
            if appendFailed {
                return false
            }
            
            if let reader = self.reader, reader.status != .reading {
                writer.markVideoAsFinished()
                return false
            }
            if writer.status != .writing {
                writer.markVideoAsFinished()
                return false
            }
            self.pauseDispatchGroup.wait()
            
            var updatedProgress = false
            
            var mainInput: MediaEditorComposer.Input?
            var additionalInput: MediaEditorComposer.Input?
            var mainTimestamp: CMTime?
            if let videoOutput = self.videoOutput {
                if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        mainTimestamp = timestamp
                        mainInput = .videoBuffer(VideoPixelBuffer(
                            pixelBuffer: pixelBuffer,
                            rotation: self.textureRotation,
                            timestamp: timestamp
                        ))
                                                
                        if let duration = self.durationValue {
                            let startTime = self.reader?.timeRange.start.seconds ?? 0.0
                            let progress = (timestamp.seconds - startTime) / duration.seconds
                            self.statusValue = .progress(Float(progress))
                            updatedProgress = true
                        }
                    }
                } else {
                    writer.markVideoAsFinished()
                    return false
                }
            }
            if let additionalVideoOutput = self.additionalVideoOutput {
                if let mainTimestamp, mainTimestamp < self.configuration.additionalVideoStartTime {

                } else {
                    if self.skippingAdditionalCopyUpdate {
                        self.skippingAdditionalCopyUpdate = false
                    } else if let sampleBuffer = additionalVideoOutput.copyNextSampleBuffer() {
                        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            additionalInput = .videoBuffer(VideoPixelBuffer(
                                pixelBuffer: pixelBuffer,
                                rotation: self.additionalTextureRotation,
                                timestamp: timestamp
                            ))
                            
                            if !updatedProgress, let duration = self.durationValue {
                                let startTime = self.reader?.timeRange.start.seconds ?? 0.0
                                let progress = (timestamp.seconds - startTime) / duration.seconds
                                self.statusValue = .progress(Float(progress))
                                updatedProgress = true
                            }
                        }
                        if let additionalFrameRate = self.additionalFrameRate, let mainComposeFramerate = self.mainComposeFramerate {
                            let additionalFrameRate = round(additionalFrameRate / 30.0) * 30.0
                            if Int(mainComposeFramerate) == Int(additionalFrameRate) * 2 {
                                self.skippingAdditionalCopyUpdate = true
                            }
                        }
                    }
                }
            }
            if case let .image(image) = self.subject, let texture = self.composer?.textureForImage(image) {
                mainInput = .texture(texture, self.imageArguments?.position ?? .zero)
                
                if !updatedProgress, let imageArguments = self.imageArguments, let duration = self.durationValue {
                    let progress = imageArguments.position.seconds / duration.seconds
                    self.statusValue = .progress(Float(progress))
                    updatedProgress = true
                }
            }
            
            if let composer = self.composer {
                let timestamp: CMTime?
                if let imageArguments = self.imageArguments {
                    timestamp = imageArguments.position
                } else {
                    if case .image = self.subject {
                        timestamp = additionalInput?.timestamp
                    } else {
                        timestamp = mainInput?.timestamp
                    }
                }
                guard let timestamp else {
                    writer.markVideoAsFinished()
                    return false
                }
                composer.process(
                    main: mainInput!,
                    additional: additionalInput,
                    pool: writer.pixelBufferPool,
                    completion: { pixelBuffer in
                        if let pixelBuffer {
                            if !writer.appendPixelBuffer(pixelBuffer, at: timestamp) {
                                writer.markVideoAsFinished()
                                appendFailed = true
                            }
                        } else {
//                            if !writer.appendVideoBuffer(sampleBuffer) {
//                                writer.markVideoAsFinished()
//                                appendFailed = true
//                            }
                            appendFailed = true
                        }
                        self.semaphore.signal()
                    }
                )
                self.semaphore.wait()
                
                if let imageArguments = self.imageArguments, let duration = self.durationValue {
                    let position = imageArguments.position + CMTime(value: 1, timescale: Int32(imageArguments.frameRate))
                    self.imageArguments = (imageArguments.frameRate, position)
                    
                    if position.seconds >= duration.seconds {
                        Logger.shared.log("VideoExport", "Video finished")
                        writer.markVideoAsFinished()
                        return false
                    }
                }
            } else {
//                if !writer.appendVideoBuffer(sampleBuffer) {
//                    writer.markVideoAsFinished()
//                    return false
//                }
            }
        }
        return true
    }
    
    private func encodeAudio() -> Bool {
        guard let writer = self.writer, let output = self.audioOutput else {
            return false
        }
        
        while writer.isReadyForMoreAudioData {
            if writer.status != .writing {
                writer.markAudioAsFinished()
                return false
            }
            self.pauseDispatchGroup.wait()
            if let buffer = output.copyNextSampleBuffer() {
                if !writer.appendAudioBuffer(buffer) {
                    writer.markAudioAsFinished()
                    return false
                }
            } else {
                writer.markAudioAsFinished()
                return false
            }
        }
        return true
    }
    
    public func start() {
        guard self.internalStatus == .idle, let writer = self.writer else {
            self.statusValue = .failed(.invalid)
            return
        }
        
        guard writer.startWriting() else {
            self.statusValue = .failed(.writing(nil))
            return
        }
        
        if let reader = self.reader, !reader.startReading() {
            self.statusValue = .failed(.reading(nil))
            return
        }
        
        if case .image = self.subject, self.additionalVideoOutput == nil {
            self.imageArguments = (Double(self.configuration.frameRate), CMTime(value: 0, timescale: Int32(self.configuration.frameRate)))
        }
        
        self.internalStatus = .exporting
        
        if let timeRange = self.reader?.timeRange {
            print("reader timerange: \(timeRange)")
        }
        writer.startSession(atSourceTime: self.reader?.timeRange.start ?? .zero)
        
        var videoCompleted = false
        var audioCompleted = false
        var exportForVideoOutput: MediaEditorVideoExport? = self
        writer.requestVideoDataWhenReady(on: self.queue.queue) {
            guard let export = exportForVideoOutput else { return }
            if !export.encodeVideo() {
                videoCompleted = true
                exportForVideoOutput = nil
                if audioCompleted {
                    export.finish()
                }
            }
        }
        
        if let _ = self.audioOutput {
            var exportForAudioOutput: MediaEditorVideoExport? = self
            writer.requestAudioDataWhenReady(on: self.queue.queue) {
                guard let export = exportForAudioOutput else { return }
                if !export.encodeAudio() {
                    audioCompleted = true
                    exportForAudioOutput = nil
                    if videoCompleted {
                        export.finish()
                    }
                }
            }
        } else {
            audioCompleted = true
        }
    }
    
    private func finish() {
        assert(self.queue.isCurrent())
        
        guard let writer = self.writer else {
            return
        }
        
        let outputUrl = URL(fileURLWithPath: self.outputPath)
        
        var cancelled = false
        if let reader = self.reader, reader.status == .cancelled {
            if writer.status != .cancelled {
                writer.cancelWriting()
            }
            cancelled = true
        }
        
        if writer.status == .cancelled {
            if let reader = self.reader, reader.status != .cancelled {
                reader.cancelReading()
            }
            cancelled = true
        }
        
        if cancelled {
            try? FileManager.default.removeItem(at: outputUrl)
            self.internalStatus = .finished
            self.statusValue = .failed(.cancelled)
            return
        }
        
        if writer.status == .failed {
            if let error = writer.error {
                Logger.shared.log("VideoExport", "Failed with writer error \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(at: outputUrl)
            self.internalStatus = .finished
            self.statusValue = .failed(.writing(nil))
        } else if let reader = self.reader, reader.status == .failed {
            if let error = reader.error {
                Logger.shared.log("VideoExport", "Failed with reader error \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(at: outputUrl)
            writer.cancelWriting()
            self.internalStatus = .finished
            self.statusValue = .failed(.reading(reader.error))
        } else {
            writer.finishWriting {
                self.queue.async {
                    if writer.status == .failed {
                        if let error = writer.error {
                            Logger.shared.log("VideoExport", "Failed after finishWriting with writer error \(error.localizedDescription)")
                        }
                        try? FileManager.default.removeItem(at: outputUrl)
                        self.internalStatus = .finished
                        self.statusValue = .failed(.writing(nil))
                    } else {
                        self.internalStatus = .finished
                        self.statusValue = .completed
                        
                        let end = CACurrentMediaTime()
                        let _ = (self.duration.get()
                        |> take(1)).start(next: { duration in
                            let exportDuration = end - self.startTimestamp
                            print("video processing took \(exportDuration)s")
                            if duration.seconds > 0 {
                                Logger.shared.log("VideoExport", "Video processing took \(exportDuration / duration.seconds)")
                            }
                        })
                    }
                }
            }
        }
    }
    
    func pause() {
        guard self.internalStatus == .exporting && self.cancelled == false else {
            return
        }
        self.internalStatus = .paused
        self.pauseDispatchGroup.enter()
    }
    
    func resume() {
        guard self.internalStatus == .paused && self.cancelled == false else {
            return
        }
        self.internalStatus = .exporting
        self.pauseDispatchGroup.leave()
    }
        
    public func cancel() {
        if case .paused = self.internalStatus {
            self.resume()
        }
        self.cancelled = true
        
        self.queue.async {
            if let reader = self.reader, reader.status == .reading {
                reader.cancelReading()
            }
        }
    }
    
    private let statusPromise = Promise<ExportStatus>(.unknown)
    private var statusValue: ExportStatus = .unknown {
        didSet {
            self.statusPromise.set(.single(self.statusValue))
        }
    }
    public var status: Signal<ExportStatus, NoError> {
        return self.statusPromise.get()
    }
}
