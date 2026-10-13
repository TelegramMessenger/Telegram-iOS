import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import Camera

private extension CMSampleBuffer {
    var presentationTime: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }

    var endTime: CMTime {
        let duration = CMSampleBufferGetDuration(self)
        if duration.isValid && duration.isNumeric {
            return self.presentationTime + duration
        } else {
            return self.presentationTime
        }
    }
}

private struct PendingVideoFrame {
    let source: VideoFrameSource
    let rawPresentationTime: CMTime
    let presentationTime: CMTime
}

private struct PendingAudioSample {
    let sampleBuffer: CMSampleBuffer
    let timelinePresentationTime: CMTime
    let timelineEndTime: CMTime
}

private struct VideoTransition {
    let from: Camera.Position
    let to: Camera.Position
    var startTime: CMTime?
}

private struct SingleCameraSwitchRetiming {
    let generation: Int
    let to: Camera.Position
    let canMeasureAudioGap: Bool
    var isCommitted = false
    var isResolved = false
    var accumulatedAudioGap: CMTime = .zero
    var heldFrame: PendingVideoFrame?
}

final class VideoRecorder {
    enum Result {
        case success(
            url: URL,
            thumbnail: UIImage?,
            duration: Double,
            positionChangeTimestamps: [(Camera.Position, Double)]
        )
        case failed
    }

    private enum State: Equatable {
        case arming
        case writing
        case stopping
        case finishing
        case finished
        case failed
    }

    private static let minimumDuration: Double = 1.5
    private static let maximumPendingAudioDuration: Double = 1.0
    private static let transitionDuration: Double = 0.2
    private static let singleCameraRetimingTimeout: Double = 0.5

    private let mediaQueue: DispatchQueue
    private let processor: RoundVideoFrameProcessor
    private let url: URL
    private let hasAudio: Bool
    private let durationUpdated: (Double) -> Void
    private let transitionImageUpdated: (UIImage?) -> Void
    private let runtimeFailure: (CameraRecordingError) -> Void
    private let completion: (Result) -> Void

    private var state: State = .arming
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var audioFormatDescription: CMFormatDescription?

    private var pendingFirstVideoFrame: PendingVideoFrame?
    private var pendingAudioBuffers: [PendingAudioSample] = []

    private var recordingStartTime: CMTime?
    private var lastVideoTime: CMTime?
    private var videoTimelineOffset: CMTime = .zero
    private var lastReceivedAudioTime: CMTime?
    private var lastReceivedAudioEndTime: CMTime?
    private var lastAudioEndTime: CMTime?
    private var lastAudioTimelineEndTime: CMTime?
    private var stopTargetTime: CMTime?
    private var stopRequested = false
    private var videoReachedStopTarget = false
    private var audioReachedStopTarget: Bool

    private var activePosition: Camera.Position
    private var transition: VideoTransition?
    private var latestBackFrame: VideoFrameSource?
    private var latestFrontFrame: VideoFrameSource?
    private var positionChangeTimestamps: [(Camera.Position, Double)] = []
    private var singleCameraSwitch: SingleCameraSwitchRetiming?

    private var thumbnail: UIImage?
    private var hasGeneratedThumbnail = false

    init(
        mediaQueue: DispatchQueue,
        processor: RoundVideoFrameProcessor,
        url: URL,
        hasAudio: Bool,
        initialPosition: Camera.Position,
        durationUpdated: @escaping (Double) -> Void,
        transitionImageUpdated: @escaping (UIImage?) -> Void,
        runtimeFailure: @escaping (CameraRecordingError) -> Void,
        completion: @escaping (Result) -> Void
    ) {
        self.mediaQueue = mediaQueue
        self.processor = processor
        self.url = url
        self.hasAudio = hasAudio
        self.activePosition = initialPosition
        self.durationUpdated = durationUpdated
        self.transitionImageUpdated = transitionImageUpdated
        self.runtimeFailure = runtimeFailure
        self.completion = completion
        self.audioReachedStopTarget = !hasAudio
    }

    func beginSingleCameraSwitch(generation: Int, from: Camera.Position, to: Camera.Position) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard !self.isTerminal, from != to else {
            return
        }

        var carriedAudioGap: CMTime = .zero
        if let current = self.singleCameraSwitch {
            if !current.isResolved {
                carriedAudioGap = current.accumulatedAudioGap
            }
        }

        self.singleCameraSwitch = SingleCameraSwitchRetiming(
            generation: generation,
            to: to,
            canMeasureAudioGap: self.hasAudio && self.lastReceivedAudioEndTime != nil && self.lastVideoTime != nil,
            accumulatedAudioGap: carriedAudioGap
        )
    }

    func noteSingleCameraSwitchCommitted(generation: Int) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard var retiming = self.singleCameraSwitch,
              retiming.generation == generation,
              !retiming.isCommitted else {
            return
        }
        retiming.isCommitted = true
        self.singleCameraSwitch = retiming

        if !retiming.canMeasureAudioGap {
            self.resolveSingleCameraSwitch(generation: generation, applyAccumulatedAudioGap: true, checkFinish: true)
            return
        }

        self.mediaQueue.asyncAfter(deadline: .now() + Self.singleCameraRetimingTimeout) { [weak self] in
            self?.resolveSingleCameraSwitch(
                generation: generation,
                applyAccumulatedAudioGap: false,
                checkFinish: true
            )
        }
    }

    private func resolveSingleCameraSwitch(generation: Int, applyAccumulatedAudioGap: Bool, checkFinish: Bool = false) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard var retiming = self.singleCameraSwitch,
              retiming.generation == generation,
              retiming.isCommitted,
              !retiming.isResolved else {
            return
        }

        let appliedAudioGap = applyAccumulatedAudioGap ? retiming.accumulatedAudioGap : .zero
        if appliedAudioGap.isValid && appliedAudioGap.isNumeric && appliedAudioGap > .zero {
            self.videoTimelineOffset = self.videoTimelineOffset + appliedAudioGap
        }
        retiming.isResolved = true

        let heldFrame = retiming.heldFrame
        retiming.heldFrame = nil
        self.singleCameraSwitch = retiming

        if let heldFrame {
            self.submitVideoFrame(self.retimedVideoFrame(heldFrame), allowPastStopBoundary: true)
            self.singleCameraSwitch = nil
        }
        if checkFinish && heldFrame == nil {
            self.maybeFinish()
        }
    }

    private func retimedVideoFrame(_ frame: PendingVideoFrame) -> PendingVideoFrame {
        return PendingVideoFrame(
            source: frame.source,
            rawPresentationTime: frame.rawPresentationTime,
            presentationTime: frame.rawPresentationTime - self.videoTimelineOffset
        )
    }

    private func consumeFirstSingleCameraSwitchVideoFrameIfNeeded(_ frame: PendingVideoFrame) -> Bool {
        guard let retiming = self.singleCameraSwitch,
              retiming.isResolved,
              retiming.to == frame.source.position else {
            return false
        }
        self.singleCameraSwitch = nil
        return true
    }

    private func discardSingleCameraSwitch() {
        self.singleCameraSwitch = nil
    }

    func beginPositionChange(to position: Camera.Position) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard position != self.activePosition else {
            return
        }
        self.transition = VideoTransition(from: self.activePosition, to: position, startTime: nil)
        self.activePosition = position
    }

    func appendVideoSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        position: Camera.Position,
        orientation: AVCaptureVideoOrientation
    ) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard !self.isTerminal, self.state != .finishing else {
            return
        }

        guard CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }
        let rawPresentationTime = sampleBuffer.presentationTime
        guard rawPresentationTime.isValid && rawPresentationTime.isNumeric else {
            return
        }

        let source = VideoFrameSource(
            pixelBuffer: pixelBuffer,
            formatDescription: formatDescription,
            position: position,
            orientation: orientation
        )
        self.setLatestFrame(source, for: position)

        guard position == self.activePosition else {
            return
        }

        let frame = PendingVideoFrame(
            source: source,
            rawPresentationTime: rawPresentationTime,
            presentationTime: rawPresentationTime - self.videoTimelineOffset
        )
        if var retiming = self.singleCameraSwitch,
           retiming.isCommitted,
           !retiming.isResolved,
           retiming.to == position {
            if retiming.heldFrame == nil {
                retiming.heldFrame = frame
            }
            self.singleCameraSwitch = retiming
            return
        }

        let isFirstSwitchFrame = self.consumeFirstSingleCameraSwitchVideoFrameIfNeeded(frame)
        self.submitVideoFrame(frame, allowPastStopBoundary: isFirstSwitchFrame)
    }

    private func submitVideoFrame(_ frame: PendingVideoFrame, allowPastStopBoundary: Bool = false) {
        if let lastVideoTime = self.lastVideoTime, frame.presentationTime <= lastVideoTime {
            return
        }
        if self.stopRequested && self.videoReachedStopTarget && !allowPastStopBoundary {
            return
        }

        if self.assetWriter == nil {
            if self.pendingFirstVideoFrame == nil {
                self.pendingFirstVideoFrame = frame
            }
            self.prepareWriterIfNeeded(firstVideoFrame: frame)
            self.tryStartWriting()
            return
        }

        guard self.state == .writing || self.state == .stopping else {
            return
        }
        self.appendPreparedVideoFrame(frame)
    }

    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard self.hasAudio, !self.isTerminal, self.state != .finishing, CMSampleBufferDataIsReady(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio else {
            return
        }

        let rawPresentationTime = sampleBuffer.presentationTime
        let rawEndTime = sampleBuffer.endTime
        guard rawPresentationTime.isValid && rawPresentationTime.isNumeric,
              rawEndTime.isValid && rawEndTime.isNumeric else {
            return
        }
        if let lastReceivedAudioTime = self.lastReceivedAudioTime, rawPresentationTime <= lastReceivedAudioTime {
            return
        }
        let previousAudioEndTime = self.lastReceivedAudioEndTime
        self.lastReceivedAudioTime = rawPresentationTime
        self.lastReceivedAudioEndTime = rawEndTime

        var shouldResolveSingleCameraSwitch = false
        var resolvingGeneration = 0
        if var retiming = self.singleCameraSwitch, !retiming.isResolved {
            if let previousAudioEndTime {
                let gap = rawPresentationTime - previousAudioEndTime
                if gap.isValid && gap.isNumeric && gap > .zero {
                    retiming.accumulatedAudioGap = retiming.accumulatedAudioGap + gap
                }
            }
            if retiming.isCommitted {
                shouldResolveSingleCameraSwitch = true
                resolvingGeneration = retiming.generation
            }
            self.singleCameraSwitch = retiming
        }

        if shouldResolveSingleCameraSwitch {
            self.resolveSingleCameraSwitch(generation: resolvingGeneration, applyAccumulatedAudioGap: true)
        }

        let timelinePresentationTime = rawPresentationTime - self.videoTimelineOffset
        let timelineEndTime = rawEndTime - self.videoTimelineOffset
        if self.stopRequested && self.audioReachedStopTarget {
            return
        }

        if self.audioFormatDescription == nil {
            self.audioFormatDescription = formatDescription
            if self.assetWriter != nil {
                self.addAudioInputIfPossible(formatDescription: formatDescription)
            }
        }

        self.pendingAudioBuffers.append(PendingAudioSample(
            sampleBuffer: sampleBuffer,
            timelinePresentationTime: timelinePresentationTime,
            timelineEndTime: timelineEndTime
        ))
        if self.recordingStartTime == nil {
            self.trimPendingAudioBeforeVideoStart()
        } else if !self.validatePendingAudioDuration() {
            self.fail(.audioInitializationError)
            return
        }

        self.tryStartWriting()
        if self.state == .writing || self.state == .stopping {
            self.drainPendingAudioBuffers()
            self.updateAudioStopState(with: timelineEndTime)
            self.maybeFinish()
        }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard !self.isTerminal, self.state != .finishing, !self.stopRequested else {
            return
        }

        self.stopRequested = true
        if self.state == .writing {
            self.state = .stopping
        }
        self.updateStopTargetIfPossible()
        self.updateStopStateFromLastSamples()

        let currentDuration: Double
        if let startTime = self.recordingStartTime, let lastVideoTime = self.lastVideoTime {
            currentDuration = max(0.0, (lastVideoTime - startTime).seconds)
        } else {
            currentDuration = 0.0
        }
        let deadlineDelay = max(0.0, Self.minimumDuration - currentDuration) + 1.0
        self.mediaQueue.asyncAfter(deadline: .now() + deadlineDelay) { [weak self] in
            self?.finishAtDeadline()
        }
        self.maybeFinish()
    }

    func cancel() {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard !self.isTerminal else {
            return
        }
        self.state = .failed
        self.assetWriter?.cancelWriting()
        self.discardSingleCameraSwitch()
        self.pendingAudioBuffers.removeAll()
        self.pendingFirstVideoFrame = nil
        self.latestBackFrame = nil
        self.latestFrontFrame = nil
        try? FileManager.default.removeItem(at: self.url)
        self.complete(.failed)
    }

    func failInitialization(_ error: CameraRecordingError) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        self.fail(error)
    }

    private var isTerminal: Bool {
        switch self.state {
        case .finished, .failed:
            return true
        default:
            return false
        }
    }

    private func prepareWriterIfNeeded(firstVideoFrame: PendingVideoFrame) {
        guard self.assetWriter == nil else {
            return
        }
        try? FileManager.default.removeItem(at: self.url)

        let assetWriter: AVAssetWriter
        do {
            assetWriter = try AVAssetWriter(url: self.url, fileType: .mp4)
        } catch {
            self.fail()
            return
        }
        assetWriter.shouldOptimizeForNetworkUse = false

        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: 1_200_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: RoundVideoFrameProcessor.outputWidth,
            AVVideoHeightKey: RoundVideoFrameProcessor.outputHeight,
            AVVideoCompressionPropertiesKey: compressionProperties,
            AVVideoColorPropertiesKey: RoundVideoFrameProcessor.videoColorProperties(from: firstVideoFrame.source)
        ]
        guard assetWriter.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            self.fail()
            return
        }

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        guard assetWriter.canAdd(videoInput) else {
            self.fail()
            return
        }
        assetWriter.add(videoInput)

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: RoundVideoFrameProcessor.outputWidth,
            kCVPixelBufferHeightKey as String: RoundVideoFrameProcessor.outputHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
        ]

        self.assetWriter = assetWriter
        self.videoInput = videoInput
        self.videoAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        if let audioFormatDescription = self.audioFormatDescription {
            self.addAudioInputIfPossible(formatDescription: audioFormatDescription)
        }
    }

    private func addAudioInputIfPossible(formatDescription: CMFormatDescription) {
        guard self.hasAudio, self.audioInput == nil, let assetWriter = self.assetWriter, assetWriter.status == .unknown else {
            return
        }

        var audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: 64_000
        ]
        if let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
            audioSettings[AVSampleRateKey] = streamDescription.pointee.mSampleRate
            audioSettings[AVNumberOfChannelsKey] = streamDescription.pointee.mChannelsPerFrame
        }

        var channelLayoutSize = 0
        if let channelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, sizeOut: &channelLayoutSize), channelLayoutSize > 0 {
            audioSettings[AVChannelLayoutKey] = Data(bytes: channelLayout, count: channelLayoutSize)
        }

        guard assetWriter.canApply(outputSettings: audioSettings, forMediaType: .audio) else {
            self.fail(.audioInitializationError)
            return
        }
        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings,
            sourceFormatHint: formatDescription
        )
        audioInput.expectsMediaDataInRealTime = true
        guard assetWriter.canAdd(audioInput) else {
            self.fail(.audioInitializationError)
            return
        }
        assetWriter.add(audioInput)
        self.audioInput = audioInput
    }

    private func tryStartWriting() {
        guard self.state == .arming,
              let assetWriter = self.assetWriter,
              let pendingFirstVideoFrame = self.pendingFirstVideoFrame,
              !self.hasAudio || self.audioInput != nil else {
            return
        }

        guard assetWriter.startWriting() else {
            self.fail()
            return
        }
        assetWriter.startSession(atSourceTime: pendingFirstVideoFrame.presentationTime)
        self.state = self.stopRequested ? .stopping : .writing
        self.pendingFirstVideoFrame = nil

        self.appendPreparedVideoFrame(pendingFirstVideoFrame)
        self.drainPendingAudioBuffers()
    }

    private func appendPreparedVideoFrame(_ frame: PendingVideoFrame) {
        guard self.state == .writing || self.state == .stopping,
              let videoInput = self.videoInput else {
            return
        }
        guard videoInput.isReadyForMoreMediaData else {
            return
        }

        let renderInputs = self.renderInputs(for: frame)
        let animationTime: Double
        if let recordingStartTime = self.recordingStartTime {
            animationTime = max(0.0, (frame.presentationTime - recordingStartTime).seconds)
        } else {
            animationTime = 0.0
        }
        self.processor.render(
            primary: renderInputs.primary,
            secondary: renderInputs.secondary,
            mixFactor: renderInputs.mixFactor,
            animationTime: animationTime,
            completion: { [weak self] processedFrame in
                guard let self else {
                    return
                }
                guard self.state == .writing || self.state == .stopping else {
                    return
                }
                guard let processedFrame else {
                    return
                }
                self.appendProcessedVideoFrame(
                    processedFrame,
                    sourceFrame: frame,
                    transitionCompleted: renderInputs.transitionCompleted
                )
            }
        )
    }

    private func appendProcessedVideoFrame(
        _ processedFrame: ProcessedVideoFrame,
        sourceFrame frame: PendingVideoFrame,
        transitionCompleted: Bool
    ) {
        guard self.state == .writing || self.state == .stopping,
              let videoInput = self.videoInput,
              let videoAdaptor = self.videoAdaptor else {
            return
        }
        guard videoInput.isReadyForMoreMediaData else {
            return
        }

        guard videoAdaptor.append(processedFrame.pixelBuffer, withPresentationTime: frame.presentationTime) else {
            if self.assetWriter?.error != nil {
                self.fail()
            }
            return
        }

        if self.recordingStartTime == nil {
            self.recordingStartTime = frame.presentationTime
            self.updateStopTargetIfPossible()
        }
        self.lastVideoTime = frame.presentationTime
        if let recordingStartTime = self.recordingStartTime {
            let duration = max(0.0, (frame.presentationTime - recordingStartTime).seconds)
            self.durationUpdated(duration)
        }

        if !self.hasGeneratedThumbnail {
            self.hasGeneratedThumbnail = true
            var cgImage: CGImage?
            if VTCreateCGImageFromCVPixelBuffer(processedFrame.pixelBuffer, options: nil, imageOut: &cgImage) == noErr, let cgImage {
                let image = UIImage(cgImage: cgImage)
                self.thumbnail = image
                self.transitionImageUpdated(image)
            }
        }

        if transitionCompleted {
            self.transition = nil
        }
        self.updateVideoStopState(with: frame.presentationTime)
        self.drainPendingAudioBuffers()
        self.maybeFinish()
    }

    private func renderInputs(for frame: PendingVideoFrame) -> (
        primary: VideoFrameSource,
        secondary: VideoFrameSource?,
        mixFactor: Float,
        transitionCompleted: Bool
    ) {
        guard var transition = self.transition, transition.to == frame.source.position else {
            return (frame.source, nil, 0.0, false)
        }

        if transition.startTime == nil {
            transition.startTime = frame.presentationTime
            self.transition = transition
            if let recordingStartTime = self.recordingStartTime {
                self.positionChangeTimestamps.append((
                    transition.to,
                    max(0.0, (frame.presentationTime - recordingStartTime).seconds)
                ))
            }
        }

        guard let startTime = transition.startTime, let previousFrame = self.latestFrame(for: transition.from) else {
            return (frame.source, nil, 0.0, true)
        }
        let progress = max(0.0, min(1.0, (frame.presentationTime - startTime).seconds / Self.transitionDuration))
        return (previousFrame, frame.source, Float(progress), progress >= 1.0)
    }

    private func drainPendingAudioBuffers() {
        guard self.state == .writing || self.state == .stopping,
              let audioInput = self.audioInput,
              let recordingStartTime = self.recordingStartTime else {
            return
        }

        while !self.pendingAudioBuffers.isEmpty && audioInput.isReadyForMoreMediaData {
            let sample = self.pendingAudioBuffers[0]
            if sample.timelinePresentationTime < recordingStartTime {
                self.pendingAudioBuffers.removeFirst()
                continue
            }
            if let stopTargetTime = self.stopTargetTime, sample.timelinePresentationTime >= stopTargetTime {
                self.audioReachedStopTarget = true
                self.pendingAudioBuffers.removeFirst()
                continue
            }
            guard audioInput.append(sample.sampleBuffer) else {
                self.fail(.audioInitializationError)
                return
            }
            self.lastAudioEndTime = sample.sampleBuffer.endTime
            self.lastAudioTimelineEndTime = sample.timelineEndTime
            if let stopTargetTime = self.stopTargetTime, sample.timelineEndTime >= stopTargetTime {
                self.audioReachedStopTarget = true
            }
            self.pendingAudioBuffers.removeFirst()
        }
    }

    private func validatePendingAudioDuration() -> Bool {
        return self.pendingAudioDuration <= Self.maximumPendingAudioDuration
    }

    private func trimPendingAudioBeforeVideoStart() {
        while self.pendingAudioDuration > Self.maximumPendingAudioDuration && !self.pendingAudioBuffers.isEmpty {
            self.pendingAudioBuffers.removeFirst()
        }
    }

    private var pendingAudioDuration: Double {
        guard let first = self.pendingAudioBuffers.first, let last = self.pendingAudioBuffers.last else {
            return 0.0
        }
        return max(0.0, (last.sampleBuffer.endTime - first.sampleBuffer.presentationTime).seconds)
    }

    private func updateStopTargetIfPossible() {
        guard self.stopRequested, self.stopTargetTime == nil, let recordingStartTime = self.recordingStartTime else {
            return
        }
        let minimumStopTime = recordingStartTime + CMTime(seconds: Self.minimumDuration, preferredTimescale: 600)
        let currentStopTime = self.lastVideoTime ?? recordingStartTime
        self.stopTargetTime = currentStopTime > minimumStopTime ? currentStopTime : minimumStopTime
    }

    private func updateStopStateFromLastSamples() {
        guard let stopTargetTime = self.stopTargetTime else {
            return
        }
        if let lastVideoTime = self.lastVideoTime, lastVideoTime >= stopTargetTime {
            self.videoReachedStopTarget = true
        }
        if !self.hasAudio || (self.lastAudioTimelineEndTime.map { $0 >= stopTargetTime } ?? false) {
            self.audioReachedStopTarget = true
        }
    }

    private func updateVideoStopState(with presentationTime: CMTime) {
        guard let stopTargetTime = self.stopTargetTime, presentationTime >= stopTargetTime else {
            return
        }
        self.videoReachedStopTarget = true
    }

    private func updateAudioStopState(with timelineEndTime: CMTime) {
        guard let stopTargetTime = self.stopTargetTime, timelineEndTime >= stopTargetTime else {
            return
        }
        self.audioReachedStopTarget = true
    }

    private func maybeFinish() {
        guard self.stopRequested,
              self.videoReachedStopTarget,
              self.audioReachedStopTarget,
              self.pendingAudioBuffers.isEmpty,
              !(self.singleCameraSwitch.map { $0.isCommitted && !$0.isResolved } ?? false) else {
            return
        }
        self.finishWriting()
    }

    private func finishAtDeadline() {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))
        guard !self.isTerminal, self.state != .finishing else {
            return
        }
        guard self.assetWriter?.status == .writing, self.lastVideoTime != nil else {
            self.fail()
            return
        }
        self.pendingAudioBuffers.removeAll()
        self.finishWriting()
    }

    private func finishWriting() {
        guard self.state == .writing || self.state == .stopping,
              let assetWriter = self.assetWriter,
              let videoInput = self.videoInput,
              let lastVideoTime = self.lastVideoTime else {
            self.fail()
            return
        }

        self.state = .finishing
        let lastAudioEndTime = self.lastAudioEndTime ?? lastVideoTime
        let endTime = lastAudioEndTime > lastVideoTime ? lastAudioEndTime : lastVideoTime
        assetWriter.endSession(atSourceTime: endTime)
        videoInput.markAsFinished()
        self.audioInput?.markAsFinished()
        assetWriter.finishWriting { [weak self] in
            guard let self else {
                return
            }
            self.mediaQueue.async {
                if assetWriter.status == .completed, let recordingStartTime = self.recordingStartTime {
                    self.state = .finished
                    let duration = max(0.0, (lastVideoTime - recordingStartTime).seconds)
                    let timestamps = self.positionChangeTimestamps.map { ($0.0, $0.1) }
                    self.discardSingleCameraSwitch()
                    self.complete(.success(
                        url: self.url,
                        thumbnail: self.thumbnail,
                        duration: duration,
                        positionChangeTimestamps: timestamps
                    ))
                } else {
                    self.fail()
                }
            }
        }
    }

    private func fail(_ error: CameraRecordingError = .videoRecorderInitializationError) {
        guard !self.isTerminal else {
            return
        }
        self.state = .failed
        self.assetWriter?.cancelWriting()
        self.discardSingleCameraSwitch()
        self.pendingAudioBuffers.removeAll()
        self.pendingFirstVideoFrame = nil
        try? FileManager.default.removeItem(at: self.url)
        self.runtimeFailure(error)
        self.complete(.failed)
    }

    private func complete(_ result: Result) {
        self.latestBackFrame = nil
        self.latestFrontFrame = nil
        self.completion(result)
    }

    private func setLatestFrame(_ frame: VideoFrameSource, for position: Camera.Position) {
        if position == .front {
            self.latestFrontFrame = frame
        } else {
            self.latestBackFrame = frame
        }
    }

    private func latestFrame(for position: Camera.Position) -> VideoFrameSource? {
        if position == .front {
            return self.latestFrontFrame
        } else {
            return self.latestBackFrame
        }
    }
}
