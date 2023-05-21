import Foundation
import AVFoundation
import MetalKit
import SwiftSignalKit
import TelegramCore

enum ExportWriterStatus {
    case unknown
    case writing
    case completed
    case failed
    case cancelled
}

protocol MediaEditorVideoExportWriter {
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String)
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, sourceFrameRate: Float)
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
}

public final class MediaEditorVideoAVAssetWriter: MediaEditorVideoExportWriter {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String) {
        let url = URL(fileURLWithPath: outputPath)
        self.writer = try? AVAssetWriter(url: url, fileType: .mp4)
        guard let writer = self.writer else {
            return
        }
        writer.shouldOptimizeForNetworkUse = configuration.shouldOptimizeForNetworkUse
    }
    
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, sourceFrameRate: Float) {
        guard let writer = self.writer else {
            return
        }
        
        var videoSettings = configuration.videoSettings
        if var compressionSettings = videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any] {
            compressionSettings[AVVideoExpectedSourceFrameRateKey] = sourceFrameRate
            videoSettings[AVVideoCompressionPropertiesKey] = compressionSettings
        }
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: UInt32(configuration.dimensions.width),
            kCVPixelBufferHeightKey as String: UInt32(configuration.dimensions.height)
        ]
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
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
}

public final class MediaEditorVideoExport {
    public enum Subject {
        case image(UIImage)
        case video(AVAsset)
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
                return CMTimeRange(start: CMTime(seconds: videoTrimRange.lowerBound, preferredTimescale: 1), end: CMTime(seconds: videoTrimRange.upperBound, preferredTimescale: 1))
            } else {
                return nil
            }
        }
        
        var composerDimensions: CGSize {
            return CGSize(width: 1080.0, height: 1920.0)
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
        case progress(Double)
        case completed
        case failed(ExportError)
    }
    
    public private(set) var internalStatus: Status = .idle
    
    private let account: Account
    private let subject: Subject
    private let configuration: Configuration
    private let outputPath: String
    
    private var previousSampleTime: CMTime = .zero
    private var processedPixelBuffer: CVPixelBuffer?
    
    private var reader: AVAssetReader?
    
    private var videoOutput: AVAssetReaderOutput?
    private var audioOutput: AVAssetReaderAudioMixOutput?
    private let queue = Queue()
    
    private var writer: MediaEditorVideoExportWriter?
    private var composer: MediaEditorComposer?
    
    private let duration = ValuePromise<CMTime>()
    
    private let pauseDispatchGroup = DispatchGroup()
    private var cancelled = false
    
    private var startTimestamp = CACurrentMediaTime()
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    public init(account: Account, subject: Subject, configuration: Configuration, outputPath: String) {
        self.account = account
        self.subject = subject
        self.configuration = configuration
        self.outputPath = outputPath
        
        self.setup()
    }
    
    private func setup() {
        if case let .video(asset) = self.subject {
            if let trimmedVideoDuration = self.configuration.timeRange?.duration {
                self.duration.set(trimmedVideoDuration)
            } else {
                asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) {
                    self.duration.set(asset.duration)
                }
            }
        } else {
            self.duration.set(CMTime(seconds: 5, preferredTimescale: 1))
        }
                
        switch self.subject {
        case let .video(asset):
            self.setupWithAsset(asset)
        case let .image(image):
            self.setupWithImage(image)
        }
    }
        
    private func setupComposer() {
        guard self.composer == nil else {
            return
        }
        self.composer = MediaEditorComposer(account: self.account, values: self.configuration.values, dimensions: self.configuration.composerDimensions, outputDimensions: self.configuration.dimensions)
    }
    
    private func setupWithAsset(_ asset: AVAsset) {
        self.reader = try? AVAssetReader(asset: asset)
        guard let reader = self.reader else {
            return
        }
        if let timeRange = self.configuration.timeRange {
            reader.timeRange = timeRange
        }
        
        self.writer = MediaEditorVideoAVAssetWriter()
        guard let writer = self.writer else {
            return
        }
        
        writer.setup(configuration: self.configuration, outputPath: self.outputPath)
                
        let videoTracks = asset.tracks(withMediaType: .video)
        if (videoTracks.count > 0) {
            let outputSettings: [String : Any]
            var sourceFrameRate: Float = 0.0
            if let videoTrack = videoTracks.first, videoTrack.preferredTransform.isIdentity && !self.configuration.values.requiresComposing {
                outputSettings = [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]]
            } else {
                outputSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                self.setupComposer()
            }
            let videoOutput = AVAssetReaderTrackOutput(track: videoTracks.first!, outputSettings: outputSettings)
            videoOutput.alwaysCopiesSampleData = false
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
            } else {
                self.internalStatus = .finished
                self.statusValue = .failed(.addVideoOutput)
            }
            self.videoOutput = videoOutput
            
            if let videoTrack = videoTracks.first {
                if videoTrack.nominalFrameRate > 0.0 {
                    sourceFrameRate = videoTrack.nominalFrameRate
                } else if videoTrack.minFrameDuration.seconds > 0.0 {
                    sourceFrameRate = Float(1.0 / videoTrack.minFrameDuration.seconds)
                } else {
                    sourceFrameRate = 30.0
                }
            } else {
                sourceFrameRate = 30.0
            }
            writer.setupVideoInput(configuration: self.configuration, sourceFrameRate: sourceFrameRate)
        } else {
            self.videoOutput = nil
        }
        
        let audioTracks = asset.tracks(withMediaType: .audio)
        if audioTracks.count > 0, !self.configuration.values.videoIsMuted {
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
            audioOutput.alwaysCopiesSampleData = false
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
            } else {
                self.internalStatus = .finished
                self.statusValue = .failed(.addAudioOutput)
            }
            self.audioOutput = audioOutput
            
            writer.setupAudioInput(configuration: self.configuration)
        } else {
            self.audioOutput = nil
        }
        
        if videoTracks.count == 0 && audioTracks.count == 0 {
            self.internalStatus = .finished
            self.statusValue = .failed(.noTracksFound)
        }
    }
    
    private func setupWithImage(_ image: UIImage) {
        self.setupComposer()
        
        self.writer = MediaEditorVideoAVAssetWriter()
        guard let writer = self.writer else {
            return
        }
        writer.setup(configuration: self.configuration, outputPath: self.outputPath)
        writer.setupVideoInput(configuration: self.configuration, sourceFrameRate: 30.0)
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
            try? FileManager().removeItem(at: outputUrl)
            self.internalStatus = .finished
            self.statusValue = .failed(.cancelled)
            return
        }
        
        if writer.status == .failed {
            try? FileManager().removeItem(at: outputUrl)
            self.internalStatus = .finished
            self.statusValue = .failed(.writing(nil))
        } else if let reader = self.reader, reader.status == .failed {
            try? FileManager().removeItem(at: outputUrl)
            writer.cancelWriting()
            self.internalStatus = .finished
            self.statusValue = .failed(.reading(reader.error))
        } else {
            writer.finishWriting {
                self.queue.async {
                    if writer.status == .failed {
                        try? FileManager().removeItem(at: outputUrl)
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
                                print("\(exportDuration / duration.seconds) speed")
                            }
                        })
                    }
                }
            }
        }
    }
    
    private func encodeImageVideo() -> Bool {
        guard let writer = self.writer, let composer = self.composer, case let .image(image) = self.subject else {
            return false
        }
        
        let duration: Double = 3.0
        let frameRate: Double = Double(self.configuration.frameRate)
        var position: CMTime = CMTime(value: 0, timescale: Int32(self.configuration.frameRate))
        
        var appendFailed = false
        while writer.isReadyForMoreVideoData {
            if appendFailed {
                return false
            }
            if writer.status != .writing {
                writer.markVideoAsFinished()
                return false
            }
            self.pauseDispatchGroup.wait()
            composer.processImage(inputImage: image, pool: writer.pixelBufferPool, time: position, completion: { pixelBuffer, timestamp in
                if let pixelBuffer {
                    if !writer.appendPixelBuffer(pixelBuffer, at: timestamp) {
                        writer.markVideoAsFinished()
                        appendFailed = true
                    }
                }
                Thread.sleep(forTimeInterval: 0.001)
                self.semaphore.signal()
            })
            self.semaphore.wait()
            
            position = position + CMTime(value: 1, timescale: Int32(frameRate))
            if position.seconds >= duration {
                writer.markVideoAsFinished()
                return false
            }
        }
        return true
    }
    
    private func encodeVideo() -> Bool {
        guard let reader = self.reader, let writer = self.writer, let output = self.videoOutput else {
            return false
        }
        
        var appendFailed = false
        while writer.isReadyForMoreVideoData {
            if appendFailed {
                return false
            }
            if reader.status != .reading || writer.status != .writing {
                writer.markVideoAsFinished()
                return false
            }
            self.pauseDispatchGroup.wait()
            if let buffer = output.copyNextSampleBuffer() {
                if let composer = self.composer {
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(buffer)
                    composer.processSampleBuffer(buffer, pool: writer.pixelBufferPool, completion: { pixelBuffer in
                        if let pixelBuffer {
                            if !writer.appendPixelBuffer(pixelBuffer, at: timestamp) {
                                writer.markVideoAsFinished()
                                appendFailed = true
                            }
                        } else {
                            if !writer.appendVideoBuffer(buffer) {
                                writer.markVideoAsFinished()
                                appendFailed = true
                            }
                        }
                        self.semaphore.signal()
                    })
                    self.semaphore.wait()
                } else {
                    if !writer.appendVideoBuffer(buffer) {
                        writer.markVideoAsFinished()
                        return false
                    }
                }
            } else {
                writer.markVideoAsFinished()
                return false
            }
        }
        return true
    }
    
    private func encodeAudio() -> Bool {
        guard let reader = self.reader, let writer = self.writer, let output = self.audioOutput else {
            return false
        }
        
        while writer.isReadyForMoreAudioData {
            if reader.status != .reading || writer.status != .writing {
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
    
    
    private func startImageVideoExport() {
        guard self.internalStatus == .idle, let writer = self.writer else {
            self.statusValue = .failed(.invalid)
            return
        }
        
        guard writer.startWriting() else {
            self.statusValue = .failed(.writing(nil))
            return
        }
        
        self.internalStatus = .exporting
        
        writer.startSession(atSourceTime: .zero)
        
        var exportForVideoOutput: MediaEditorVideoExport? = self
        writer.requestVideoDataWhenReady(on: self.queue.queue) {
            guard let export = exportForVideoOutput else { return }
            if !export.encodeImageVideo() {
                exportForVideoOutput = nil
                export.finish()
            }
        }
    }
    
    private func startVideoExport() {
        guard self.internalStatus == .idle, let writer = self.writer, let reader = self.reader else {
            self.statusValue = .failed(.invalid)
            return
        }
        
        guard writer.startWriting() else {
            self.statusValue = .failed(.writing(nil))
            return
        }
        guard reader.startReading() else {
            self.statusValue = .failed(.reading(nil))
            return
        }
        
        self.internalStatus = .exporting
        
        writer.startSession(atSourceTime: self.configuration.timeRange?.start ?? .zero)
        
        var videoCompleted = false
        var audioCompleted = false
        if let _ = self.videoOutput {
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
        } else {
            videoCompleted = true
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
    
    public func startExport() {
        switch self.subject {
        case .video:
            self.startVideoExport()
        case .image:
            self.startImageVideoExport()
        }
    }
}
