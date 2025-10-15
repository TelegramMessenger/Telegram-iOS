import Foundation
import AVFoundation
import UIKit
import CoreImage
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
    
    private let ciContext: CIContext
    fileprivate var transitionImage: UIImage?
    private var savedTransitionImage = false
    
    private var pendingAudioSampleBuffers: [CMSampleBuffer] = []
    
    private var _duration = Atomic<CMTime>(value: .zero)
    public var duration: CMTime {
        return self._duration.with { $0 }
    }
        
    private var startedSession = false
    private var lastVideoSampleTime: CMTime = .invalid
    private var recordingStartSampleTime: CMTime = .invalid
    private var recordingStopSampleTime: CMTime = .invalid
    
    private var positionChangeTimestamps: [(Camera.Position, CMTime)] = []
    
    private let configuration: VideoRecorder.Configuration
    private let orientation: AVCaptureVideoOrientation
    private let videoTransform: CGAffineTransform
    private let url: URL
    fileprivate var completion: (Bool, UIImage?, [(Camera.Position, CMTime)]?) -> Void = { _, _, _ in }
    
    private let error = Atomic<Error?>(value: nil)
    
    private var _stopped = Atomic<Bool>(value: false)
    private var stopped: Bool {
        return self._stopped.with { $0 }
    }
    
    private var hasAllVideoBuffers = false
    private var hasAllAudioBuffers = false
    
    public init?(configuration: VideoRecorder.Configuration, ciContext: CIContext, orientation: AVCaptureVideoOrientation, fileUrl: URL) {
        self.configuration = configuration
        self.ciContext = ciContext
        
        var transform: CGAffineTransform = CGAffineTransform(rotationAngle: .pi / 2.0)
        if orientation == .landscapeLeft {
            transform = CGAffineTransform(rotationAngle: .pi)
        } else if orientation == .landscapeRight {
            transform = CGAffineTransform(rotationAngle: 0.0)
        } else if orientation == .portraitUpsideDown {
            transform = CGAffineTransform(rotationAngle: -.pi / 2.0)
        }
        
        self.orientation = orientation
        self.videoTransform = transform
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
    
    public func markPositionChange(position: Camera.Position, time: CMTime? = nil) {
        self.queue.async {
            guard self.recordingStartSampleTime.isValid || time != nil else {
                return
            }
            if let time {
                self.positionChangeTimestamps.append((position, time))
            } else {
                let currentTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                let delta = currentTime - self.recordingStartSampleTime
                self.positionChangeTimestamps.append((position, delta))
            }
        }
    }
    
    
    private var previousPresentationTime: Double?
    private var previousAppendTime: Double?
    
    public func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        #if compiler(>=6.0) // Xcode 16
        nonisolated(unsafe) let sampleBuffer = sampleBuffer
        #endif
        
        self.queue.async {
            guard self.hasError() == nil && !self.stopped else {
                return
            }
            
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video else {
                return
            }
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            var failed = false
            if self.videoInput == nil {
                Logger.shared.log("VideoRecorder", "Try adding video input")
                
                let videoSettings = self.configuration.videoSettings
                if self.assetWriter.canApply(outputSettings: videoSettings, forMediaType: .video) {
                    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings, sourceFormatHint: formatDescription)
                    videoInput.expectsMediaDataInRealTime = true
                    videoInput.transform = self.videoTransform
                    if self.assetWriter.canAdd(videoInput) {
                        self.assetWriter.add(videoInput)
                        self.videoInput = videoInput
                        
                        Logger.shared.log("VideoRecorder", "Successfully added video input")
                    } else {
                        failed = true
                    }
                } else {
                    failed = true
                }
            }
            
            if failed {
                Logger.shared.log("VideoRecorder", "Failed to append video buffer")
                return
            }
            
            if self.assetWriter.status == .unknown {
                if sampleBuffer.presentationTimestamp < self.recordingStartSampleTime {
                    return
                }
                if self.videoInput != nil && (self.audioInput != nil || !self.configuration.hasAudio) {
                    print("startWriting")
                    let start = CACurrentMediaTime()
                    if !self.assetWriter.startWriting() {
                        if let error = self.assetWriter.error {
                            self.transitionToFailedStatus(error: .avError(error))
                        }
                    }
                    print("started In \(CACurrentMediaTime() - start)")
                    return
                }
            } else if self.assetWriter.status == .writing && !self.startedSession {
                print("Started session at \(presentationTime)")
                self.assetWriter.startSession(atSourceTime: presentationTime)
                self.recordingStartSampleTime = presentationTime
                self.lastVideoSampleTime = presentationTime
                self.startedSession = true
            }
            
            if self.recordingStartSampleTime == .invalid || sampleBuffer.presentationTimestamp < self.recordingStartSampleTime {
                return
            }
           
            if self.assetWriter.status == .writing && self.startedSession {
                if self.recordingStopSampleTime != .invalid && sampleBuffer.presentationTimestamp > self.recordingStopSampleTime {
                    self.hasAllVideoBuffers = true
                    self.maybeFinish()
                    return
                }

                if let videoInput = self.videoInput {
                    while (!videoInput.isReadyForMoreMediaData)
                    {
                        let maxDate = Date(timeIntervalSinceNow: 0.05)
                        RunLoop.current.run(until: maxDate)
                    }
                }

                if let videoInput = self.videoInput {
                    let time = CACurrentMediaTime()
//                    if let previousPresentationTime = self.previousPresentationTime, let previousAppendTime = self.previousAppendTime {
//                        print("appending \(presentationTime.seconds) (\(presentationTime.seconds - previousPresentationTime) ) on \(time) (\(time - previousAppendTime)")
//                    }
                    self.previousPresentationTime = presentationTime.seconds
                    self.previousAppendTime = time
                    
                    if videoInput.append(sampleBuffer) {
                        self.lastVideoSampleTime = presentationTime
                        let startTime = self.recordingStartSampleTime
                        let duration = presentationTime - startTime
                        let _ = self._duration.modify { _ in return duration }
                    }
                    
                    if !self.savedTransitionImage, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        self.savedTransitionImage = true
                        Queue.concurrentBackgroundQueue().async {
                            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                            if let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                                var orientation: UIImage.Orientation = .right
                                if self.orientation == .landscapeLeft {
                                    orientation = .down
                                } else if self.orientation == .landscapeRight {
                                    orientation = .up
                                } else if self.orientation == .portraitUpsideDown {
                                    orientation = .left
                                }
                                self.transitionImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                            } else {
                                self.savedTransitionImage = false
                            }
                        }
                    }
                    
                    if !self.tryAppendingPendingAudioBuffers() {
                        self.transitionToFailedStatus(error: .generic)
                    }
                }
            }
        }
    }
    
    public func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        #if compiler(>=6.0) // Xcode 16
        nonisolated(unsafe) let sampleBuffer = sampleBuffer
        #endif
        
        self.queue.async {
            guard self.hasError() == nil && !self.stopped else {
                return
            }
            
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio else {
                return
            }
            
            var failed = false
            if self.audioInput == nil {
                Logger.shared.log("VideoRecorder", "Try adding audio input")
                
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
                        
                        Logger.shared.log("VideoRecorder", "Successfully added audio input")
                    } else {
                        failed = true
                    }
                } else {
                    failed = true
                }
            }

            if failed {
                Logger.shared.log("VideoRecorder", "Failed to append audio buffer")
                return
            }
                                    
            if self.recordingStartSampleTime != .invalid {
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
            let _ = self._stopped.modify { _ in return true }
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
        return !self.stopped
    }
    
    public func stopRecording() {
        self.queue.async {
            var stopTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            if self.recordingStartSampleTime.isValid {
                if (stopTime - self.recordingStartSampleTime).seconds < 1.5 {
                    stopTime = self.recordingStartSampleTime + CMTime(seconds: 1.5, preferredTimescale: self.recordingStartSampleTime.timescale)
                }
            }
            
            self.recordingStopSampleTime = stopTime
        }
    }
    
    private func maybeFinish() {
        dispatchPrecondition(condition: .onQueue(self.queue))
        guard self.hasAllVideoBuffers && self.hasAllVideoBuffers && !self.stopped else {
            return
        }
        let _ = self._stopped.modify { _ in return true }
        self.finish()
    }
    
    private func finish() {
        dispatchPrecondition(condition: .onQueue(self.queue))
        let completion = self.completion
        if self.recordingStopSampleTime == .invalid {
            DispatchQueue.main.async {
                completion(false, nil, nil)
            }
            return
        }
        
        if let _ = self.error.with({ $0 }) {
            DispatchQueue.main.async {
                completion(false, nil, nil)
            }
            return
        }
        
        if !self.tryAppendingPendingAudioBuffers() {
            DispatchQueue.main.async {
                completion(false, nil, nil)
            }
            return
        }
        
        if self.assetWriter.status == .writing {
            self.assetWriter.finishWriting {
                if let _ = self.assetWriter.error {
                    DispatchQueue.main.async {
                        completion(false, nil, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(true, self.transitionImage, self.positionChangeTimestamps)
                    }
                }
            }
        } else if let _ = self.assetWriter.error {
            DispatchQueue.main.async {
                completion(false, nil, nil)
            }
        } else {
            DispatchQueue.main.async {
                completion(false, nil, nil)
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
        if self.startedSession, let audioInput = self.audioInput {
            while (!audioInput.isReadyForMoreMediaData)
            {
                let maxDate = Date(timeIntervalSinceNow: 0.05)
                RunLoop.current.run(until: maxDate)
            }
            
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
        
        case success(UIImage?, Double, [(Camera.Position, Double)])
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
    fileprivate let fileUrl: URL
    private let completion: (Result) -> Void
    
    public var isRecording: Bool {
        return self.impl.isRecording
    }
    
    init?(configuration: Configuration, ciContext: CIContext, orientation: AVCaptureVideoOrientation, fileUrl: URL, completion: @escaping (Result) -> Void) {
        self.configuration = configuration
        self.fileUrl = fileUrl
        self.completion = completion
        
        guard let impl = VideoRecorderImpl(configuration: configuration, ciContext: ciContext, orientation: orientation, fileUrl: fileUrl) else {
            completion(.initError(.generic))
            return nil
        }
        self.impl = impl
        impl.completion = { [weak self] result, transitionImage, positionChangeTimestamps in
            if let self {
                let duration = self.duration ?? 0.0
                if result {
                    var timestamps: [(Camera.Position, Double)] = []
                    if let positionChangeTimestamps {
                        for (position, time) in positionChangeTimestamps {
                            timestamps.append((position, time.seconds))
                        }
                    }
                    self.completion(.success(transitionImage, duration, timestamps))
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
        
    func markPositionChange(position: Camera.Position, time: CMTime? = nil) {
        self.impl.markPositionChange(position: position, time: time)
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
    
    var transitionImage: UIImage? {
        return self.impl.transitionImage
    }
}
