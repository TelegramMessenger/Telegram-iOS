import Foundation
import AVFoundation
import MetalKit
import SwiftSignalKit
import TelegramCore
import Postbox
import ImageTransparency
import Photos

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

public final class MediaEditorVideoExport {
    public enum Subject {
        case image(image: UIImage)
        case video(asset: AVAsset, isStory: Bool)
        case sticker(file: TelegramMediaFile)
    }
    
    public struct Configuration {
        public var shouldOptimizeForNetworkUse: Bool = true
        public var videoSettings: [String: Any]
        public var audioSettings: [String: Any]
        public var values: MediaEditorValues
        public var frameRate: Float
        public var preferredDuration: Double?
        
        public init(
            videoSettings: [String: Any],
            audioSettings: [String: Any],
            values: MediaEditorValues,
            frameRate: Float,
            preferredDuration: Double? = nil
        ) {
            self.videoSettings = videoSettings
            self.audioSettings = audioSettings
            self.values = values
            self.frameRate = frameRate
            self.preferredDuration = preferredDuration
        }
        
        var isSticker: Bool {
            if let codec = self.videoSettings[AVVideoCodecKey] as? String, codec == "VP9" {
                return true
            } else {
                return false
            }
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
            return videoStartTime(trimRange: self.values.additionalVideoTrimRange, offset: self.values.additionalVideoOffset)
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
            if self.values.isStory || self.values.isSticker || self.values.isAvatar {
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
    
    private var mainVideoRect: CGRect?
    private var mainVideoScale: CGFloat = 1.0
    private var mainVideoOffset: CGPoint = .zero
    
    class VideoOutput {
        enum Output {
            case videoOutput(AVAssetReaderOutput)
            case image(UIImage)
        }
        let output: Output
        let rect: CGRect?
        let scale: CGFloat
        let offset: CGPoint
        let textureRotation: TextureRotation
        let duration: Double
        let frameRate: Float
        let startTime: CMTime
        
        init(
            output: Output,
            rect: CGRect?,
            scale: CGFloat,
            offset: CGPoint,
            textureRotation: TextureRotation,
            duration: Double,
            frameRate: Float,
            startTime: CMTime
        ) {
            self.output = output
            self.rect = rect
            self.scale = scale
            self.offset = offset
            self.textureRotation = textureRotation
            self.duration = duration
            self.frameRate = frameRate
            self.startTime = startTime
        }
        
        var skippingUpdate = false
        var initialized = false
    }
    private var additionalVideoOutput: [Int: VideoOutput] = [:]
    
    private var mainComposeFramerate: Float?
    
    private var audioOutput: AVAssetReaderOutput?
    
    private var stickerEntity: MediaEditorComposerStickerEntity?
    private let stickerSemaphore = DispatchSemaphore(value: 0)
    
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
    
    private let composerSemaphore = DispatchSemaphore(value: 0)
    
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
        case image(image: UIImage, rect: CGRect?, scale: CGFloat, offset: CGPoint)
        case video(asset: AVAsset, rect: CGRect?, scale: CGFloat, offset: CGPoint, rotation: TextureRotation, duration: Double, trimRange: Range<Double>?, trimOffset: Double?, volume: CGFloat?)
        case sticker(TelegramMediaFile)
        
        var isVideo: Bool {
            if case .video = self {
                return true
            }
            return false
        }
    }
    
    private func setup() {
        var mainAsset: AVAsset?
        
        var signals: [Signal<Input, NoError>] = []
        
        var mainRect: CGRect?
        var mainScale: CGFloat = 1.0
        var mainOffset: CGPoint = .zero
        var additionalAsset: AVAsset?
        if !self.configuration.values.collage.isEmpty {
            for item in self.configuration.values.collage {
                switch item.content {
                case .main:
                    mainRect = item.frame
                    mainScale = item.contentScale
                    mainOffset = item.contentOffset
                case let .imageFile(path):
                    if let image = UIImage(contentsOfFile: path) {
                        signals.append(.single(.image(image: image, rect: item.frame, scale: item.contentScale, offset: item.contentOffset)))
                    }
                case let .videoFile(path):
                    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                    signals.append(.single(.video(asset: asset, rect: item.frame, scale: item.contentScale, offset: item.contentOffset, rotation: textureRotatonForAVAsset(asset, mirror: false), duration: asset.duration.seconds, trimRange: item.videoTrimRange, trimOffset: item.videoOffset, volume: item.videoVolume)))
                case let .asset(localIdentifier, _):
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
                    if fetchResult.count != 0 {
                        let asset = fetchResult.object(at: 0)
                        
                        let signal: Signal<Input, NoError> = Signal { subscriber in
                            let options = PHVideoRequestOptions()
                            options.isNetworkAccessAllowed = true
                            options.deliveryMode = .highQualityFormat
            
                            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: { avAsset, _, _ in
                                guard let avAsset else {
                                    subscriber.putCompletion()
                                    return
                                }
                                subscriber.putNext(.video(asset: avAsset, rect: item.frame, scale: item.contentScale, offset: item.contentOffset, rotation: textureRotatonForAVAsset(avAsset, mirror: false), duration: avAsset.duration.seconds, trimRange: item.videoTrimRange, trimOffset: item.videoOffset, volume: item.videoVolume))
                                subscriber.putCompletion()
                            })
                            
                            return EmptyDisposable
                        }
                        
                        signals.append(signal)
                    }
                }
            }
        } else if let additionalPath = self.configuration.values.additionalVideoPath {
            let asset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
            additionalAsset = asset
            signals = [.single(.video(asset: asset, rect: nil, scale: 1.0, offset: .zero, rotation: textureRotatonForAVAsset(asset, mirror: true), duration: asset.duration.seconds, trimRange: nil, trimOffset: nil, volume: nil))]
        }

        var audioAsset: AVAsset?
        if let audioTrack = self.configuration.values.audioTrack {
            let audioPath = fullDraftPath(peerId: self.configuration.values.peerId, path: audioTrack.path)
            audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
        }

        var mainInput: Input
        var isStory = true
        switch self.subject {
        case let .video(asset, isStoryValue):
            mainAsset = asset
            mainInput = .video(asset: asset, rect: mainRect, scale: mainScale, offset: mainOffset, rotation: textureRotatonForAVAsset(asset), duration: asset.duration.seconds, trimRange: nil, trimOffset: nil, volume: nil)
            isStory = isStoryValue
        case let .image(image):
            mainInput = .image(image: image, rect: nil, scale: 1.0, offset: .zero)
        case let .sticker(file):
            mainInput = .sticker(file)
        }
        
        let duration: CMTime
        if self.configuration.isSticker {
            duration = CMTime(seconds: self.configuration.preferredDuration ?? 3.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        } else if let mainAsset {
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
        
        let _ = (combineLatest(signals)
        |> deliverOn(self.queue)).start(next: { [weak self] additionalInputs in
            guard let self else {
                return
            }
            self.setupWithInputs(main: mainInput, additional: additionalInputs, audio: audioAsset, isStory: isStory)
        })
    }
        
    private func setupComposer() {
        guard self.composer == nil else {
            return
        }
        
        var duration = self.durationValue?.seconds
        if case .image = self.subject {
            duration = nil
        }
        
        var additionalVideoDuration: Double?
        if self.configuration.values.collage.isEmpty, let output = self.additionalVideoOutput.values.first {
            additionalVideoDuration = output.duration
        }
        
        self.composer = MediaEditorComposer(
            postbox: self.postbox,
            values: self.configuration.values,
            dimensions: self.configuration.composerDimensions,
            outputDimensions: self.configuration.dimensions,
            textScale: self.textScale,
            videoDuration: duration,
            additionalVideoDuration: additionalVideoDuration
        )
    }
    
    private func setupWithInputs(main: Input, additional: [Input], audio: AVAsset?, isStory: Bool) {
        var hasVideoOrAudio = false
        if main.isVideo || audio != nil {
            hasVideoOrAudio = true
        }
        for input in additional {
            if input.isVideo {
                hasVideoOrAudio = true
            }
        }
                
        enum AdditionalTrack {
            case image(image: UIImage, rect: CGRect?, scale: CGFloat, offset: CGPoint)
            case video(track: AVMutableCompositionTrack, rect: CGRect?, scale: CGFloat, offset: CGPoint, rotation: TextureRotation, duration: Double, frameRate: Float, startTime: CMTime?)
        }
        
        func frameRate(for track: AVCompositionTrack) -> Float {
            if track.nominalFrameRate > 0.0 {
                return track.nominalFrameRate
            } else if track.minFrameDuration.seconds > 0.0 {
                return Float(1.0 / track.minFrameDuration.seconds)
            }
            return 30.0
        }
        
        var composition: AVMutableComposition?
        var mainVideoTrack: AVMutableCompositionTrack?
        var additionalTracks: [AdditionalTrack] = []
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
                    result = CMTimeRange(start: result.start, duration: maxDuration - trackStart)
                }
                return result
            }
            
            var readerRange = wholeRange
            if case let .video(asset, rect, scale, offset, rotation, _, _, _, _) = main {
                self.mainVideoRect = rect
                self.mainVideoScale = scale
                self.mainVideoOffset = offset
                self.textureRotation = rotation
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
                        
            if !self.configuration.values.collage.isEmpty {
                for input in additional {
                    switch input {
                    case let .image(image, rect, scale, offset):
                        additionalTracks.append(.image(image: image, rect: rect, scale: scale, offset: offset))
                    case let .video(asset, rect, scale, offset, rotation, duration, trimRange, trimOffset, volume):
                        let startTime = videoStartTime(trimRange: trimRange, offset: trimOffset)
                        let timeRange = clampedRange(trackDuration: asset.duration, trackTrimRange: videoTimeRange(trimRange: trimRange), trackStart: startTime, maxDuration: readerRange.end)
                        
                        if let videoAssetTrack = asset.tracks(withMediaType: .video).first {
                            if let compositionTrack = composition?.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                                additionalTracks.append(.video(track: compositionTrack, rect: rect, scale: scale, offset: offset, rotation: rotation, duration: duration, frameRate: frameRate(for: compositionTrack), startTime: startTime))
                                
                                compositionTrack.preferredTransform = videoAssetTrack.preferredTransform
                                
                                try? compositionTrack.insertTimeRange(timeRange, of: videoAssetTrack, at: startTime)
                            }
                        }
                        if let audioAssetTrack = asset.tracks(withMediaType: .audio).first, volume ?? 1.0 > 0.01 {
                            if let compositionTrack = composition?.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                                try? compositionTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: startTime)
                                
                                if let volume, volume != 1.0 {
                                    let trackParameters = AVMutableAudioMixInputParameters(track: compositionTrack)
                                    trackParameters.trackID = compositionTrack.trackID
                                    trackParameters.setVolume(Float(volume), at: .zero)
                                    audioMixParameters.append(trackParameters)
                                }
                            }
                        }
                    default:
                        break
                    }
                }
            } else if let additional = additional.first, case let .video(asset, _, _, _, rotation, duration, _, _, _) = additional {
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
                        additionalTracks.append(.video(track: compositionTrack, rect: nil, scale: 1.0, offset: .zero, rotation: rotation, duration: duration, frameRate: frameRate(for: compositionTrack), startTime: self.configuration.additionalVideoStartTime))
                        
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
                if mainVideoTrack == nil && additionalTracks.isEmpty {
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
                
        if self.configuration.isSticker {
            self.writer = MediaEditorVideoFFMpegWriter()
        } else {
            self.writer = MediaEditorVideoAVAssetWriter()
        }
        
        guard let writer = self.writer else {
            return
        }
        writer.setup(configuration: self.configuration, outputPath: self.outputPath)
        self.setupComposer()
        
        if case let .sticker(file) = main, let composer = self.composer {
            self.stickerEntity = MediaEditorComposerStickerEntity(postbox: self.postbox, content: .file(file), position: .zero, scale: 1.0, rotation: 0.0, baseSize: CGSize(width: 512.0, height: 512.0), mirrored: false, colorSpace: composer.colorSpace, tintColor: nil, isStatic: false, highRes: true)
        }
                
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
            
            var additionalIndex = 0
            for track in additionalTracks {
                switch track {
                case let .image(image, rect, scale, offset):
                    self.additionalVideoOutput[additionalIndex] = VideoOutput(
                        output: .image(image),
                        rect: rect,
                        scale: scale,
                        offset: offset,
                        textureRotation: .rotate0Degrees,
                        duration: 0.0,
                        frameRate: 0.0,
                        startTime: .zero
                    )
                case let .video(track, rect, scale, offset, rotation, duration, frameRate, startTime):
                    let videoOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
                    videoOutput.alwaysCopiesSampleData = true
                    if reader.canAdd(videoOutput) {
                        reader.add(videoOutput)
                    } else {
                        self.internalStatus = .finished
                        self.statusValue = .failed(.addVideoOutput)
                    }
                    
                    self.additionalVideoOutput[additionalIndex] = VideoOutput(
                        output: .videoOutput(videoOutput),
                        rect: rect,
                        scale: scale,
                        offset: offset,
                        textureRotation: rotation,
                        duration: duration,
                        frameRate: frameRate,
                        startTime: startTime ?? .zero
                    )
                }
                additionalIndex += 1
            }
        }
                
        if let mainVideoTrack {
            self.frameRate = frameRate(for: mainVideoTrack)
        }
        
        var additionalFrameRate: Float?
        if self.configuration.values.collage.isEmpty, let output = self.additionalVideoOutput.values.first {
            additionalFrameRate = output.frameRate
        }
        let sourceFrameRate: Float = (self.frameRate ?? additionalFrameRate) ?? 30.0
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
        
        self.start()
    }
            
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
            var additionalInput: [MediaEditorComposer.Input?] = []
            var mainTimestamp: CMTime?
            if let videoOutput = self.videoOutput {
                if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        mainTimestamp = timestamp
                        mainInput = .videoBuffer(
                            VideoPixelBuffer(
                                pixelBuffer: pixelBuffer,
                                rotation: self.textureRotation,
                                timestamp: timestamp
                            ),
                            self.mainVideoRect,
                            self.mainVideoScale,
                            self.mainVideoOffset
                        )
                                                
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
            
            for i in 0 ..< self.additionalVideoOutput.count {
                if let additionalVideoOutput = self.additionalVideoOutput[i] {
                    if let mainTimestamp, mainTimestamp < additionalVideoOutput.startTime {
                        if !self.configuration.values.collage.isEmpty && !additionalVideoOutput.initialized {
                            additionalVideoOutput.initialized = true
                            if case let .videoOutput(videoOutput) = additionalVideoOutput.output {
                                if let _ = videoOutput.copyNextSampleBuffer(), let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                                    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                        additionalInput.append(
                                            .videoBuffer(
                                                VideoPixelBuffer(
                                                    pixelBuffer: pixelBuffer,
                                                    rotation: additionalVideoOutput.textureRotation,
                                                    timestamp: .zero
                                                ),
                                                additionalVideoOutput.rect,
                                                additionalVideoOutput.scale,
                                                additionalVideoOutput.offset
                                            )
                                        )
                                    } else {
                                        additionalInput.append(nil)
                                    }
                                } else {
                                    additionalInput.append(nil)
                                }
                            } else {
                                additionalInput.append(nil)
                            }
                        } else {
                            additionalInput.append(nil)
                        }
                    } else {
                        if additionalVideoOutput.skippingUpdate {
                            additionalVideoOutput.skippingUpdate = false
                            additionalInput.append(nil)
                        } else {
                            switch additionalVideoOutput.output {
                            case let .image(image):
                                if let texture = self.composer?.textureForImage(index: i, image: image) {
                                    additionalInput.append(
                                        .texture(
                                            texture,
                                            .zero,
                                            false,
                                            additionalVideoOutput.rect,
                                            additionalVideoOutput.scale,
                                            additionalVideoOutput.offset
                                        )
                                    )
                                }
                            case let .videoOutput(videoOutput):
                                if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                                   if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                       let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                                       additionalInput.append(
                                            .videoBuffer(
                                                VideoPixelBuffer(
                                                    pixelBuffer: pixelBuffer,
                                                    rotation: additionalVideoOutput.textureRotation,
                                                    timestamp: timestamp
                                                ),
                                                additionalVideoOutput.rect,
                                                additionalVideoOutput.scale,
                                                additionalVideoOutput.offset
                                            )
                                       )
                                       
                                       if !updatedProgress, let duration = self.durationValue {
                                           let startTime = self.reader?.timeRange.start.seconds ?? 0.0
                                           let progress = (timestamp.seconds - startTime) / duration.seconds
                                           self.statusValue = .progress(Float(progress))
                                           updatedProgress = true
                                       }
                                   } else {
                                       additionalInput.append(nil)
                                   }
                                   if let mainComposeFramerate = self.mainComposeFramerate {
                                       let additionalFrameRate = round(additionalVideoOutput.frameRate / 30.0) * 30.0
                                       if Int(mainComposeFramerate) == Int(additionalFrameRate) * 2 {
                                           additionalVideoOutput.skippingUpdate = true
                                       }
                                   }
                                } else {
                                    additionalInput.append(nil)
                                }
                            }
                        }
                    }
                }
            }
            
            
            if case let .image(image) = self.subject, let texture = self.composer?.textureForImage(index: -1, image: image) {
                mainInput = .texture(texture, self.imageArguments?.position ?? .zero, imageHasTransparency(image), nil, 1.0, .zero)
                
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
                        timestamp = additionalInput.first??.timestamp
                    } else {
                        timestamp = mainInput?.timestamp
                    }
                }
                guard let timestamp else {
                    writer.markVideoAsFinished()
                    return false
                }
                
                if let stickerEntity = self.stickerEntity, let ciContext = composer.ciContext {
                    let imageArguments = self.imageArguments
                    stickerEntity.image(for: timestamp, frameRate: Float(imageArguments?.frameRate ?? 30.0), context: ciContext, completion: { image in
                        if let image {
                            mainInput = .ciImage(image, imageArguments?.position ?? .zero)
                        }
                        self.stickerSemaphore.signal()
                    })
                    self.stickerSemaphore.wait()
                    
                    if !updatedProgress, let imageArguments = self.imageArguments, let duration = self.durationValue {
                        let progress = imageArguments.position.seconds / duration.seconds
                        self.statusValue = .progress(Float(progress))
                        updatedProgress = true
                    }
                }
                
                composer.process(
                    main: mainInput!,
                    additional: additionalInput,
                    timestamp: timestamp,
                    pool: writer.pixelBufferPool,
                    completion: { pixelBuffer in
                        if let pixelBuffer {
                            if !writer.appendPixelBuffer(pixelBuffer, at: timestamp) {
                                writer.markVideoAsFinished()
                                appendFailed = true
                            }
                        } else {
                            appendFailed = true
                        }
                        self.composerSemaphore.signal()
                    }
                )
                self.composerSemaphore.wait()
                
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
    
    private func start() {
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
        
        if self.additionalVideoOutput.isEmpty {
            switch self.subject {
            case .image, .sticker:
                self.imageArguments = (Double(self.configuration.frameRate), CMTime(value: 0, timescale: Int32(self.configuration.frameRate)))
            default:
                break
            }
        }
        
        self.internalStatus = .exporting
        
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

private func videoStartTime(trimRange: Range<Double>?, offset: Double?) -> CMTime {
    let lowerBound = trimRange?.lowerBound ?? 0.0
    let offset = -min(0.0, offset ?? 0.0)
    if !lowerBound.isZero || !offset.isZero {
        return CMTime(seconds: offset + lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    } else {
        return .zero
    }
}

private func videoTimeRange(trimRange: Range<Double>?) -> CMTimeRange? {
    if let videoTrimRange = trimRange {
        return CMTimeRange(start: CMTime(seconds: videoTrimRange.lowerBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), end: CMTime(seconds: videoTrimRange.upperBound, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    } else {
        return nil
    }
}
