import Foundation
import AVFoundation
import SwiftSignalKit
import TelegramCore

private extension CMSampleBuffer {
    var endTime: CMTime {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(self)
        let duration = CMSampleBufferGetDuration(self)
        return presentationTime + duration
    }
}

private final class VideoRecorderImpl {
    public enum RecorderError: LocalizedError {
        case generic
        case avError(Error)
       
        public var errorDescription: String? {
            switch self {
            case .generic:
                return "Error"
            case let .avError(error):
                return error.localizedDescription
            }
        }
    }
    
    private let queue = DispatchQueue(label: "VideoRecorder")
    
    private var assetWriter: AVAssetWriter
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private var pendingAudioSampleBuffers: [CMSampleBuffer] = []
    
    private var _duration: CMTime = .zero
    public var duration: CMTime {
        self.queue.sync { _duration }
    }
        
    private var lastVideoSampleTime: CMTime = .invalid
    private var recordingStartSampleTime: CMTime = .invalid
    private var recordingStopSampleTime: CMTime = .invalid
    
    private let configuration: VideoRecorder.Configuration
    private let videoTransform: CGAffineTransform
    private let url: URL
    fileprivate var completion: (Bool) -> Void = { _ in }
    
    private let error = Atomic<Error?>(value: nil)
    
    private var stopped = false
    private var hasAllVideoBuffers = false
    private var hasAllAudioBuffers = false
    
    public init?(configuration: VideoRecorder.Configuration, videoTransform: CGAffineTransform, fileUrl: URL) {
        self.configuration = configuration
        self.videoTransform = videoTransform
        self.url = fileUrl
        
        try? FileManager.default.removeItem(at: url)
        guard let assetWriter = try? AVAssetWriter(url: url, fileType: .mp4) else {
            return nil
        }
        self.assetWriter = assetWriter
        self.assetWriter.shouldOptimizeForNetworkUse = false
    }
    
    private func hasError() -> Error? {
        return self.error.with { $0 }
    }
    
    public func start() {
        self.queue.async {
            self.recordingStartSampleTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        }
    }
    
    public func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let _ = self.hasError() {
            return
        }
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        self.queue.async {
            guard !self.stopped && self.error.with({ $0 }) == nil else {
                return
            }
            
            var failed = false
            if self.videoInput == nil {
                let videoSettings = self.configuration.videoSettings
                if self.assetWriter.canApply(outputSettings: videoSettings, forMediaType: .video) {
                    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings, sourceFormatHint: formatDescription)
                    videoInput.expectsMediaDataInRealTime = true
                    videoInput.transform = self.videoTransform
                    if self.assetWriter.canAdd(videoInput) {
                        self.assetWriter.add(videoInput)
                        self.videoInput = videoInput
                    } else {
                        failed = true
                    }
                } else {
                    failed = true
                }
            }
            
            if failed {
                print("error")
                return
            }
                        
            if self.assetWriter.status == .unknown {
                if sampleBuffer.presentationTimestamp < self.recordingStartSampleTime {
                    return
                }
                if !self.assetWriter.startWriting() {
                    if let error = self.assetWriter.error {
                        self.transitionToFailedStatus(error: .avError(error))
                        return
                    }
                }
                
                self.assetWriter.startSession(atSourceTime: presentationTime)
                self.recordingStartSampleTime = presentationTime
                self.lastVideoSampleTime = presentationTime
            }
            
            if self.assetWriter.status == .writing {
                if self.recordingStopSampleTime != .invalid && sampleBuffer.presentationTimestamp > self.recordingStopSampleTime {
                    self.hasAllVideoBuffers = true
                    self.maybeFinish()
                    return
                }
                
                if let videoInput = self.videoInput, videoInput.isReadyForMoreMediaData {
                    if videoInput.append(sampleBuffer) {
                        self.lastVideoSampleTime = presentationTime
                        let startTime = self.recordingStartSampleTime
                        let duration = presentationTime - startTime
                        self._duration = duration
                    } else {
                        print("error")
                    }
                    if !self.tryAppendingPendingAudioBuffers() {
                        self.transitionToFailedStatus(error: .generic)
                    }
                }
            }
        }
    }
    
    public func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let _ = self.hasError() {
            return
        }
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio else {
            return
        }
        
        self.queue.async {
            guard !self.stopped && self.error.with({ $0 }) == nil else {
                return
            }
            
            var failed = false
            if self.audioInput == nil {
                var audioSettings = self.configuration.audioSettings
                if let currentAudioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                    audioSettings[AVSampleRateKey] = currentAudioStreamBasicDescription.pointee.mSampleRate
                    audioSettings[AVNumberOfChannelsKey] = currentAudioStreamBasicDescription.pointee.mChannelsPerFrame
                }
                
                var audioChannelLayoutSize: Int = 0
                let currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, sizeOut: &audioChannelLayoutSize)
                let currentChannelLayoutData: Data
                if let currentChannelLayout = currentChannelLayout, audioChannelLayoutSize > 0 {
                    currentChannelLayoutData = Data(bytes: currentChannelLayout, count: audioChannelLayoutSize)
                } else {
                    currentChannelLayoutData = Data()
                }
                audioSettings[AVChannelLayoutKey] = currentChannelLayoutData
                
                if self.assetWriter.canApply(outputSettings: audioSettings, forMediaType: .audio) {
                    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings, sourceFormatHint: formatDescription)
                    audioInput.expectsMediaDataInRealTime = true
                    if self.assetWriter.canAdd(audioInput) {
                        self.assetWriter.add(audioInput)
                        self.audioInput = audioInput
                    } else {
                        failed = true
                    }
                } else {
                    failed = true
                }
            }

            if failed {
                print("error")
                return
            }
                                    
            if self.assetWriter.status == .writing {
                if sampleBuffer.presentationTimestamp < self.recordingStartSampleTime {
                    return
                }
                if self.recordingStopSampleTime != .invalid && sampleBuffer.presentationTimestamp > self.recordingStopSampleTime {
                    self.hasAllAudioBuffers = true
                    self.maybeFinish()
                    return
                }
                var result = false
                if self.tryAppendingPendingAudioBuffers() {
                    if self.tryAppendingAudioSampleBuffer(sampleBuffer) {
                        result = true
                    }
                }
                if !result {
                    self.transitionToFailedStatus(error: .generic)
                }
            }
        }
    }
    
    public func cancelRecording(completion: @escaping () -> Void) {
        self.queue.async {
            if self.stopped {
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            self.stopped = true
            self.pendingAudioSampleBuffers = []
            if self.assetWriter.status == .writing {
                self.assetWriter.cancelWriting()
            }
            let fileManager = FileManager()
            try? fileManager.removeItem(at: self.url)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    public var isRecording: Bool {
        self.queue.sync { !(self.hasAllVideoBuffers && self.hasAllAudioBuffers) }
    }
    
    public func stopRecording() {
        self.queue.async {
            self.recordingStopSampleTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        }
    }
    
    public func maybeFinish() {
        self.queue.async {
            guard self.hasAllVideoBuffers && self.hasAllVideoBuffers else {
                return
            }
            self.stopped = true
            self.finish()
        }
    }
    
    public func finish() {
        self.queue.async {
            let completion = self.completion
            if self.recordingStopSampleTime == .invalid {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
                        
            if let _ = self.error.with({ $0 }) {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if !self.tryAppendingPendingAudioBuffers() {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if self.assetWriter.status == .writing {
                self.assetWriter.finishWriting {
                    if let _ = self.assetWriter.error {
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                }
            } else if let _ = self.assetWriter.error {
                DispatchQueue.main.async {
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }
    
    private func tryAppendingPendingAudioBuffers() -> Bool {
        dispatchPrecondition(condition: .onQueue(self.queue))
        guard self.pendingAudioSampleBuffers.count > 0 else {
            return true
        }
        
        var result = true
        let (sampleBuffersToAppend, pendingSampleBuffers) = self.pendingAudioSampleBuffers.stableGroup(using: { $0.endTime <= self.lastVideoSampleTime })
        for sampleBuffer in sampleBuffersToAppend {
            if !self.internalAppendAudioSampleBuffer(sampleBuffer) {
                result = false
                break
            }
        }
        self.pendingAudioSampleBuffers = pendingSampleBuffers
        return result
    }
    
    private func tryAppendingAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        dispatchPrecondition(condition: .onQueue(self.queue))
        
        var result = true
        if sampleBuffer.endTime > self.lastVideoSampleTime {
            self.pendingAudioSampleBuffers.append(sampleBuffer)
        } else {
            result = self.internalAppendAudioSampleBuffer(sampleBuffer)
        }
        return result
    }
    
    private func internalAppendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        if let audioInput = self.audioInput, audioInput.isReadyForMoreMediaData {
            if !audioInput.append(sampleBuffer) {
                if let _ = self.assetWriter.error {
                    return false
                }
            }
        } else {
            
        }
        return true
    }
    
    private func transitionToFailedStatus(error: RecorderError) {
        let _ = self.error.modify({ _ in return error })
    }
}

private extension Sequence {
    func stableGroup(using predicate: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var trueGroup: [Element] = []
        var falseGroup: [Element] = []
        for element in self {
            if try predicate(element) {
                trueGroup.append(element)
            } else {
                falseGroup.append(element)
            }
        }
        return (trueGroup, falseGroup)
    }
}

public final class VideoRecorder {
    var duration: Double? {
        return self.impl.duration.seconds
    }
    
    enum Result {
        enum Error {
            case generic
        }
        
        case success
        case initError(Error)
        case writeError(Error)
        case finishError(Error)
    }
    
    struct Configuration {
        var videoSettings: [String: Any]
        var audioSettings: [String: Any]

        init(videoSettings: [String: Any], audioSettings: [String: Any]) {
            self.videoSettings = videoSettings
            self.audioSettings = audioSettings
        }

        var hasAudio: Bool {
            return !self.audioSettings.isEmpty
        }
    }
    
    private let impl: VideoRecorderImpl
    fileprivate let configuration: Configuration
    fileprivate let videoTransform: CGAffineTransform
    fileprivate let fileUrl: URL
    private let completion: (Result) -> Void
    
    public var isRecording: Bool {
        return self.impl.isRecording
    }
    
    init?(configuration: Configuration, videoTransform: CGAffineTransform, fileUrl: URL, completion: @escaping (Result) -> Void) {
        self.configuration = configuration
        self.videoTransform = videoTransform
        self.fileUrl = fileUrl
        self.completion = completion
        
        guard let impl = VideoRecorderImpl(configuration: configuration, videoTransform: videoTransform, fileUrl: fileUrl) else {
            completion(.initError(.generic))
            return nil
        }
        self.impl = impl
        impl.completion = { [weak self] success in
            if let self {
                if success {
                    self.completion(.success)
                } else {
                    self.completion(.finishError(.generic))
                }
            }
        }
    }
    
    func start() {
        self.impl.start()
    }
    
    func stop() {
        self.impl.stopRecording()
    }
    
    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDescriptor = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }
        let type = CMFormatDescriptionGetMediaType(formatDescriptor)
        if type == kCMMediaType_Video {
            self.impl.appendVideoSampleBuffer(sampleBuffer)
        } else if type == kCMMediaType_Audio {
            if self.configuration.hasAudio {
                self.impl.appendAudioSampleBuffer(sampleBuffer)
            }
        }
    }
}
