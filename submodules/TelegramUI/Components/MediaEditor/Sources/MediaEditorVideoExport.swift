import Foundation
import AVFoundation
import MetalKit
import SwiftSignalKit
import AccountContext

enum ExportWriterStatus {
    case unknown
    case writing
    case completed
    case failed
    case cancelled
}

protocol MediaEditorVideoExportWriter {
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String)
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, inputTransform: CGAffineTransform?)
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
    
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, inputTransform: CGAffineTransform?) {
        guard let writer = self.writer else {
            return
        }
        let videoInput: AVAssetWriterInput
        if let transform = inputTransform {
            let size = CGSize(width: configuration.videoSettings[AVVideoWidthKey] as! Int, height: configuration.videoSettings[AVVideoHeightKey] as! Int)
            let transformedSize = size.applying(transform.inverted())
            var videoSettings = configuration.videoSettings
            videoSettings[AVVideoWidthKey] = abs(transformedSize.width)
            videoSettings[AVVideoHeightKey] = abs(transformedSize.height)
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.transform = transform
        } else {
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: configuration.videoSettings)
        }
        videoInput.expectsMediaDataInRealTime = false
        
        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1080,
            kCVPixelBufferHeightKey as String: 1920
        ]
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        } else {
            //throw Error.cannotAddVideoInput
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
        
        public init(videoSettings: [String: Any], audioSettings: [String: Any], values: MediaEditorValues) {
            self.videoSettings = videoSettings
            self.audioSettings = audioSettings
            self.values = values
        }
        
        var timeRange: CMTimeRange? {
            if let videoTrimRange = self.values.videoTrimRange {
                return CMTimeRange(start: CMTime(seconds: videoTrimRange.lowerBound, preferredTimescale: 1), end: CMTime(seconds: videoTrimRange.upperBound, preferredTimescale: 1))
            } else {
                return nil
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
        case progress(Double)
        case completed
        case failed(ExportError)
    }
    
    public private(set) var internalStatus: Status = .idle
    
    private let context: AccountContext
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
    
    public init(context: AccountContext, subject: Subject, configuration: Configuration, outputPath: String) {
        self.context = context
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
            self.duration.set(CMTime(seconds: 3, preferredTimescale: 1))
        }
        
        if self.configuration.values.requiresComposing {
            self.composer = MediaEditorComposer(context: self.context, values: self.configuration.values, dimensions: self.configuration.dimensions)
        }
        self.setupVideoInput()
    }
        
    private func setupVideoInput() {
        guard case let .video(asset) = self.subject else {
            return
        }
        
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
            let videoOutput: AVAssetReaderOutput
            let inputTransform: CGAffineTransform?
            if self.composer == nil {
                videoOutput = AVAssetReaderTrackOutput(track: videoTracks.first!, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]])
                inputTransform = videoTracks.first!.preferredTransform
            } else {
                videoOutput = AVAssetReaderTrackOutput(track: videoTracks.first!, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
                inputTransform = nil
            }
            
            videoOutput.alwaysCopiesSampleData = false
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
            } else {
                self.internalStatus = .finished
                self.statusValue = .failed(.addVideoOutput)
            }
            self.videoOutput = videoOutput
            
            writer.setupVideoInput(configuration: self.configuration, inputTransform: inputTransform)
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
    
    private func finish() {
        assert(self.queue.isCurrent())
        
        guard let reader = self.reader, let writer = self.writer else {
            return
        }
        
        let outputUrl = URL(fileURLWithPath: self.outputPath)
        
        if reader.status == .cancelled || writer.status == .cancelled {
            if writer.status != .cancelled {
                writer.cancelWriting()
            }
            if reader.status != .cancelled {
                reader.cancelReading()
            }
            try? FileManager().removeItem(at: outputUrl)
            self.internalStatus = .finished
            self.statusValue = .failed(.cancelled)
            return
        }
        
        if writer.status == .failed {
            try? FileManager().removeItem(at: outputUrl)
            self.internalStatus = .finished
            self.statusValue = .failed(.writing(nil))
        } else if reader.status == .failed {
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
//                let progress = (CMSampleBufferGetPresentationTimeStamp(buffer) - self.configuration.timeRange.start).seconds/self.duration.seconds
//                if self.videoOutput === output {
//                    self.dispatchProgressCallback { $0.updateVideoEncodingProgress(fractionCompleted: progress) }
//                }
//                if self.audioOutput === output {
//                    self.dispatchProgressCallback { $0.updateAudioEncodingProgress(fractionCompleted: progress) }
//                }
 
            } else {
//                if self.videoOutput === output {
//                    self.dispatchProgressCallback { $0.updateVideoEncodingProgress(fractionCompleted: 1) }
//                }
//                if self.audioOutput === output {
//                    self.dispatchProgressCallback { $0.updateAudioEncodingProgress(fractionCompleted: 1) }
//                }
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
//                let progress = (CMSampleBufferGetPresentationTimeStamp(buffer) - self.configuration.timeRange.start).seconds/self.duration.seconds
//                if self.videoOutput === output {
//                    self.dispatchProgressCallback { $0.updateVideoEncodingProgress(fractionCompleted: progress) }
//                }
//                if self.audioOutput === output {
//                    self.dispatchProgressCallback { $0.updateAudioEncodingProgress(fractionCompleted: progress) }
//                }
                if !writer.appendVideoBuffer(buffer) {
                    writer.markAudioAsFinished()
                    return false
                }
            } else {
//                if self.videoOutput === output {
//                    self.dispatchProgressCallback { $0.updateVideoEncodingProgress(fractionCompleted: 1) }
//                }
//                if self.audioOutput === output {
//                    self.dispatchProgressCallback { $0.updateAudioEncodingProgress(fractionCompleted: 1) }
//                }
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
    
    public func startExport() {
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
            var sessionForVideoEncoder: MediaEditorVideoExport? = self
            writer.requestVideoDataWhenReady(on: self.queue.queue) {
                guard let session = sessionForVideoEncoder else { return }
                if !session.encodeVideo() {
                    videoCompleted = true
                    sessionForVideoEncoder = nil
                    if audioCompleted {
                        session.finish()
                    }
                }
            }
        } else {
            videoCompleted = true
        }
        
        if let _ = self.audioOutput {
            var sessionForAudioEncoder: MediaEditorVideoExport? = self
            writer.requestAudioDataWhenReady(on: self.queue.queue) {
                guard let session = sessionForAudioEncoder else { return }
                if !session.encodeAudio() {
                    audioCompleted = true
                    sessionForAudioEncoder = nil
                    if videoCompleted {
                        session.finish()
                    }
                }
            }
        } else {
            audioCompleted = true
        }
    }
}
