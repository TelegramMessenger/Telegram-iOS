import Foundation
import UIKit
import Metal
import MetalKit
import Vision
import Photos
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import FastBlur
import AccountContext

public struct MediaEditorPlayerState {
    public let generationTimestamp: Double
    public let duration: Double
    public let timeRange: Range<Double>?
    public let position: Double
    public let isPlaying: Bool
    public let frames: [UIImage]
    public let framesCount: Int
    public let framesUpdateTimestamp: Double
    public let hasAudio: Bool
    public let isAudioPlayerOnly: Bool
}

public final class MediaEditor {
    public enum Subject {
        case image(UIImage, PixelDimensions)
        case video(String, UIImage?, Bool, String?, PixelDimensions, Double)
        case asset(PHAsset)
        case draft(MediaEditorDraft)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions), let .video(_, _, _, _, dimensions, _):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            case let .draft(draft):
                return draft.dimensions
            }
        }
    }

    private let context: AccountContext
    private let subject: Subject
    
    private let clock = CMClockGetHostTimeClock()
    private var player: AVPlayer?
    private var additionalPlayer: AVPlayer?
    private var audioPlayer: AVPlayer?
    
    private var timeObserver: Any?
    private weak var timeObserverPlayer: AVPlayer?
    
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    
    private weak var previewView: MediaEditorPreviewView?

    public var values: MediaEditorValues {
        didSet {
            if !self.skipRendering {
                self.updateRenderChain()
            }
            self.valuesPromise.set(.single(self.values))
            self.valuesUpdated(self.values)
        }
    }
    public var valuesUpdated: (MediaEditorValues) -> Void = { _ in }
    private var valuesPromise = Promise<MediaEditorValues>()
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    private let histogramCalculationPass = HistogramCalculationPass()
    
    private var textureSourceDisposable: Disposable?
    
    private let gradientColorsPromise = Promise<(UIColor, UIColor)?>()
    public var gradientColors: Signal<(UIColor, UIColor)?, NoError> {
        return self.gradientColorsPromise.get()
    }
    private var gradientColorsValue: (UIColor, UIColor)? {
        didSet {
            self.gradientColorsPromise.set(.single(self.gradientColorsValue))
        }
    }
    
    private let histogramPromise = Promise<Data>()
    public var histogram: Signal<Data, NoError> {
        return self.histogramPromise.get()
    }
    public var isHistogramEnabled: Bool {
        get {
            return self.histogramCalculationPass.isEnabled
        }
        set {
            self.histogramCalculationPass.isEnabled = newValue
            if newValue {
                Queue.mainQueue().justDispatch {
                    self.updateRenderChain()
                }
            }
        }
    }
    
    private var textureCache: CVMetalTextureCache!
    
    public var hasPortraitMask: Bool {
        return self.renderChain.blurPass.maskTexture != nil
    }
    
    public var sourceIsVideo: Bool {
        self.player != nil
    }
    
    public var resultIsVideo: Bool {
        return self.player != nil || self.audioPlayer != nil || self.values.entities.contains(where: { $0.entity.isAnimated })
    }
    
    public var resultImage: UIImage? {
        return self.renderer.finalRenderedImage()
    }
    
    public func getResultImage(mirror: Bool) -> UIImage? {
        return self.renderer.finalRenderedImage(mirror: mirror)
    }
        
    private let playerPromise = Promise<AVPlayer?>()
    private var playerPlaybackState: (Double, Double, Bool, Bool, Bool) = (0.0, 0.0, false, false, false) {
        didSet {
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        }
    }
    private let playerPlaybackStatePromise = Promise<(Double, Double, Bool, Bool, Bool)>((0.0, 0.0, false, false, false))
    
    public var position: Signal<Double, NoError> {
        return self.playerPlaybackStatePromise.get()
        |> map { _, position, _, _, _ -> Double in
            return position
        }
    }
   
    public var duration: Double? {
        if let _ = self.player {
            if let trimRange = self.values.videoTrimRange {
                return trimRange.upperBound - trimRange.lowerBound
            } else {
                return min(60.0, self.playerPlaybackState.0)
            }
        } else {
            return nil
        }
    }
    
    public var originalDuration: Double? {
        if let _ = self.player {
            return min(60.0, self.playerPlaybackState.0)
        } else {
            return nil
        }
    }
    
    public var onFirstDisplay: () -> Void = {}
    
    public func playerState(framesCount: Int) -> Signal<MediaEditorPlayerState?, NoError> {
        return self.playerPromise.get()
        |> mapToSignal { [weak self] player in
            if let self, player != nil {
                if player === self.player, let asset = player?.currentItem?.asset {
                    return combineLatest(self.valuesPromise.get(), self.playerPlaybackStatePromise.get(), self.videoFrames(asset: asset, count: framesCount))
                    |> map { values, durationAndPosition, framesAndUpdateTimestamp in
                        let (duration, position, isPlaying, hasAudio, isAudioPlayerOnly) = durationAndPosition
                        let (frames, framesUpdateTimestamp) = framesAndUpdateTimestamp
                        return MediaEditorPlayerState(
                            generationTimestamp: CACurrentMediaTime(),
                            duration: duration,
                            timeRange: values.videoTrimRange,
                            position: position,
                            isPlaying: isPlaying,
                            frames: frames,
                            framesCount: framesCount,
                            framesUpdateTimestamp: framesUpdateTimestamp,
                            hasAudio: hasAudio,
                            isAudioPlayerOnly: isAudioPlayerOnly
                        )
                    }
                } else if player === self.audioPlayer {
                    return combineLatest(self.valuesPromise.get(), self.playerPlaybackStatePromise.get())
                    |> map { values, durationAndPosition in
                        let (duration, position, isPlaying, _, _) = durationAndPosition
                        return MediaEditorPlayerState(
                            generationTimestamp: CACurrentMediaTime(),
                            duration: duration,
                            timeRange: values.audioTrackTrimRange,
                            position: position,
                            isPlaying: isPlaying,
                            frames: [],
                            framesCount: 0,
                            framesUpdateTimestamp: 0,
                            hasAudio: false,
                            isAudioPlayerOnly: true
                        )
                    }
                } else {
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
        }
    }
    
    public func videoFrames(asset: AVAsset, count: Int) -> Signal<([UIImage], Double), NoError> {
        func blurredImage(_ image: UIImage) -> UIImage? {
            guard let image = image.cgImage else {
                return nil
            }
            
            let thumbnailSize = CGSize(width: image.width, height: image.height)
            let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
            if let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0) {
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                if let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0) {
                    thumbnailContext2.withFlippedContext { c in
                        c.interpolationQuality = .none
                        if let image = thumbnailContext.generateImage()?.cgImage {
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                        }
                    }
                    imageFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                    return thumbnailContext2.generateImage()
                }
            }
            return nil
        }

        guard count > 0 else {
            return .complete()
        }
        let scale = UIScreen.main.scale
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.maximumSize = CGSize(width: 48.0 * scale, height: 36.0 * scale)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
                
        var firstFrame: UIImage
        if let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil) {
            firstFrame = UIImage(cgImage: cgImage)
            if let blurred = blurredImage(firstFrame) {
                firstFrame = blurred
            }
        } else {
            firstFrame = generateSingleColorImage(size: CGSize(width: 24.0, height: 36.0), color: .black)!
        }
        return Signal { subscriber in
            subscriber.putNext((Array(repeating: firstFrame, count: count), CACurrentMediaTime()))
            
            var timestamps: [NSValue] = []
            let duration = asset.duration.seconds
            let interval = duration / Double(count)
            for i in 0 ..< count {
                timestamps.append(NSValue(time: CMTime(seconds: Double(i) * interval, preferredTimescale: CMTimeScale(1000))))
            }
            
            var updatedFrames: [UIImage] = []
            imageGenerator.generateCGImagesAsynchronously(forTimes: timestamps) { _, image, _, _, _ in
                if let image {
                    updatedFrames.append(UIImage(cgImage: image))
                    if updatedFrames.count == count {
                        subscriber.putNext((updatedFrames, CACurrentMediaTime()))
                        subscriber.putCompletion()
                    } else {
                        var tempFrames = updatedFrames
                        for _ in 0 ..< count - updatedFrames.count {
                            tempFrames.append(firstFrame)
                        }
                        subscriber.putNext((tempFrames, CACurrentMediaTime()))
                    }
                }
            }
            
            return ActionDisposable {
                imageGenerator.cancelAllCGImageGeneration()
            }
        }
    }
    
    public init(context: AccountContext, subject: Subject, values: MediaEditorValues? = nil, hasHistogram: Bool = false) {
        self.context = context
        self.subject = subject
        if let values {
            self.values = values
            self.updateRenderChain()
        } else {
            self.values = MediaEditorValues(
                peerId: context.account.peerId,
                originalDimensions: subject.dimensions,
                cropOffset: .zero,
                cropRect: nil,
                cropScale: 1.0,
                cropRotation: 0.0,
                cropMirroring: false,
                cropOrientation: nil,
                gradientColors: nil,
                videoTrimRange: nil,
                videoIsMuted: false,
                videoIsFullHd: false,
                videoIsMirrored: false,
                additionalVideoPath: nil,
                additionalVideoPosition: nil,
                additionalVideoScale: nil,
                additionalVideoRotation: nil,
                additionalVideoPositionChanges: [],
                drawing: nil,
                entities: [],
                toolValues: [:],
                audioTrack: nil,
                audioTrackTrimRange: nil,
                audioTrackOffset: nil,
                audioTrackVolume: nil,
                audioTrackSamples: nil,
                qualityPreset: nil
            )
        }
        self.valuesPromise.set(.single(self.values))

        self.renderer.addRenderChain(self.renderChain)
        if hasHistogram {
            self.renderer.addRenderPass(self.histogramCalculationPass)
        }
        
        self.histogramCalculationPass.updated = { [weak self] data in
            if let self {
                self.histogramPromise.set(.single(data))
            }
        }
        
        if case let .asset(asset) = subject {
            self.playerPlaybackState = (asset.duration, 0.0, false, false, false)
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        } else if case let .video(_, _, _, _, _, duration) = subject {
            self.playerPlaybackState = (duration, 0.0, false, true, false)
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        }
    }
    
    deinit {
        self.textureSourceDisposable?.dispose()
        self.destroyTimeObservers()
    }
    
    private func destroyTimeObservers() {
        if let timeObserver = self.timeObserver {
            self.timeObserverPlayer?.removeTimeObserver(timeObserver)
            
            self.timeObserver = nil
            self.timeObserverPlayer = nil
        }
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
            self.didPlayToEndTimeObserver = nil
        }
        
        self.audioDelayTimer?.invalidate()
        self.audioDelayTimer = nil
    }
    
    public func replaceSource(_ image: UIImage, additionalImage: UIImage?, time: CMTime) {
        guard let renderTarget = self.previewView, let device = renderTarget.mtlDevice, let texture = loadTexture(image: image, device: device) else {
            return
        }
        let additionalTexture = additionalImage.flatMap { loadTexture(image: $0, device: device) }
        self.renderer.consumeTexture(texture, additionalTexture: additionalTexture, time: time, render: true)
    }
    
    private var volumeFade: SwiftSignalKit.Timer?
    private func setupSource() {
        guard let renderTarget = self.previewView else {
            return
        }
        
        if let device = renderTarget.mtlDevice, CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache) != kCVReturnSuccess {
            print("error")
        }
                
        let context = self.context
        let clock = self.clock
        let textureSource: Signal<(TextureSource, UIImage?, AVPlayer?, AVPlayer?, UIColor, UIColor), NoError>
        switch subject {
        case let .image(image, _):
            let colors = mediaEditorGetGradientColors(from: image)
            textureSource = .single((ImageTextureSource(image: image, renderTarget: renderTarget), image, nil, nil, colors.0, colors.1))
        case let .draft(draft):
            if draft.isVideo {
                textureSource = Signal { subscriber in
                    let url = URL(fileURLWithPath: draft.fullPath(engine: context.engine))
                    let asset = AVURLAsset(url: url)
                    
                    let playerItem = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: playerItem)
                    if #available(iOS 15.0, *) {
                        player.sourceClock = clock
                    } else {
                        player.masterClock = clock
                    }
                    player.automaticallyWaitsToMinimizeStalling = false
   
                    if let gradientColors = draft.values.gradientColors {
                        let colors = (gradientColors.first!, gradientColors.last!)
                        subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: nil, mirror: false, renderTarget: renderTarget), nil, player, nil, colors.0, colors.1))
                        subscriber.putCompletion()
                        
                        return EmptyDisposable
                    } else {
                        let imageGenerator = AVAssetImageGenerator(asset: asset)
                        imageGenerator.appliesPreferredTrackTransform = true
                        imageGenerator.maximumSize = CGSize(width: 72, height: 128)
                        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0, preferredTimescale: CMTimeScale(30.0)))]) { _, image, _, _, _ in
                            if let image {
                                let colors = mediaEditorGetGradientColors(from: UIImage(cgImage: image))
                                subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: nil, mirror: false, renderTarget: renderTarget), nil, player, nil, colors.0, colors.1))
                            } else {
                                subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: nil, mirror: false, renderTarget: renderTarget), nil, player, nil, .black, .black))
                            }
                            subscriber.putCompletion()
                        }
                        return ActionDisposable {
                            imageGenerator.cancelAllCGImageGeneration()
                        }
                    }
                }
            } else {
                guard let image = UIImage(contentsOfFile: draft.fullPath(engine: context.engine)) else {
                    return
                }
                let colors: (UIColor, UIColor)
                if let gradientColors = draft.values.gradientColors {
                    colors = (gradientColors.first!, gradientColors.last!)
                } else {
                    colors = mediaEditorGetGradientColors(from: image)
                }
                textureSource = .single((ImageTextureSource(image: image, renderTarget: renderTarget), image, nil, nil, colors.0, colors.1))
            }
        case let .video(path, transitionImage, mirror, additionalPath, _, _):
            textureSource = Signal { subscriber in
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                if #available(iOS 15.0, *) {
                    player.sourceClock = clock
                } else {
                    player.masterClock = clock
                }
                player.automaticallyWaitsToMinimizeStalling = false
                
                var additionalPlayer: AVPlayer?
                if let additionalPath {
                    let additionalAsset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
                    additionalPlayer = AVPlayer(playerItem: AVPlayerItem(asset: additionalAsset))
                    if #available(iOS 15.0, *) {
                        additionalPlayer?.sourceClock = clock
                    } else {
                        additionalPlayer?.masterClock = clock
                    }
                    additionalPlayer?.automaticallyWaitsToMinimizeStalling = false
                }
                
                if let transitionImage {
                    let colors = mediaEditorGetGradientColors(from: transitionImage)
                    subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: additionalPlayer, mirror: mirror, renderTarget: renderTarget), nil, player, additionalPlayer, colors.0, colors.1))
                    subscriber.putCompletion()
                    
                    return EmptyDisposable
                } else {
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    imageGenerator.maximumSize = CGSize(width: 72, height: 128)
                    imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0, preferredTimescale: CMTimeScale(30.0)))]) { _, image, _, _, _ in
                        if let image {
                            let colors = mediaEditorGetGradientColors(from: UIImage(cgImage: image))
                            subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: additionalPlayer, mirror: mirror, renderTarget: renderTarget), nil, player, additionalPlayer, colors.0, colors.1))
                        } else {
                            subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: additionalPlayer, mirror: mirror, renderTarget: renderTarget), nil, player, additionalPlayer, .black, .black))
                        }
                        subscriber.putCompletion()
                    }
                    return ActionDisposable {
                        imageGenerator.cancelAllCGImageGeneration()
                    }
                }
            }
        case let .asset(asset):
            textureSource = Signal { subscriber in
                if asset.mediaType == .video {
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .fastFormat
                    options.isNetworkAccessAllowed = true
                    let requestId = PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 128.0, height: 128.0), contentMode: .aspectFit, options: options, resultHandler: { image, info in
                        if let image {
                            if let info {
                                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                    return
                                }
                            }
                            let colors = mediaEditorGetGradientColors(from: image)
                            PHImageManager.default().requestAVAsset(forVideo: asset, options: nil, resultHandler: { asset, _, _ in
                                if let asset {
                                    let playerItem = AVPlayerItem(asset: asset)
                                    let player = AVPlayer(playerItem: playerItem)
                                    player.automaticallyWaitsToMinimizeStalling = false
                                    subscriber.putNext((VideoTextureSource(player: player, additionalPlayer: nil, mirror: false, renderTarget: renderTarget), nil, player, nil, colors.0, colors.1))
                                    subscriber.putCompletion()
                                }
                            })
                        }
                    })
                    return ActionDisposable {
                        PHImageManager.default().cancelImageRequest(requestId)
                    }
                } else {
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    let requestId = PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1920.0, height: 1920.0), contentMode: .aspectFit, options: options, resultHandler: { image, info in
                        if let image {
                            var degraded = false
                            if let info {
                                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                    return
                                }
                                if let degradedValue = info[PHImageResultIsDegradedKey] as? Bool, degradedValue {
                                    degraded = true
                                }
                            }
                            if !degraded {
                                let colors = mediaEditorGetGradientColors(from: image)
                                subscriber.putNext((ImageTextureSource(image: image, renderTarget: renderTarget), image, nil, nil, colors.0, colors.1))
                                subscriber.putCompletion()
                            }
                        }
                    })
                    return ActionDisposable {
                        PHImageManager.default().cancelImageRequest(requestId)
                    }
                }
            }
        }
        
        self.textureSourceDisposable = (textureSource
        |> deliverOnMainQueue).start(next: { [weak self] sourceAndColors in
            if let self {
                let (source, image, player, additionalPlayer, topColor, bottomColor) = sourceAndColors
                self.renderer.onNextRender = { [weak self] in
                    self?.onFirstDisplay()
                }
                self.renderer.textureSource = source
                self.player = player
                self.additionalPlayer = additionalPlayer
                                
                self.playerPromise.set(.single(player))
                self.gradientColorsValue = (topColor, bottomColor)
                self.setGradientColors([topColor, bottomColor])
                
                if player == nil {
                    self.updateRenderChain()
                    let _ = image
//                    self.maybeGeneratePersonSegmentation(image)
                }
                
                if let _ = self.values.audioTrack {
                    self.setupAudioPlayback()
                    self.updateAudioPlaybackRange()
                }
                
                if let player {
                    player.isMuted = self.values.videoIsMuted
                    if let trimRange = self.values.videoTrimRange {
                        self.player?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
                        self.additionalPlayer?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
                    }

                    if let initialSeekPosition = self.initialSeekPosition {
                        self.initialSeekPosition = nil
                        player.seek(to: CMTime(seconds: initialSeekPosition, preferredTimescale: CMTimeScale(1000)), toleranceBefore: .zero, toleranceAfter: .zero)
                    } else if let trimRange = self.values.videoTrimRange {
                        player.seek(to: CMTime(seconds: trimRange.lowerBound, preferredTimescale: CMTimeScale(1000)), toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                 
                    self.setupTimeObservers()
                    Queue.mainQueue().justDispatch {
                        let startPlayback = {
                            player.playImmediately(atRate: 1.0)
                            additionalPlayer?.playImmediately(atRate: 1.0)
                            self.audioPlayer?.playImmediately(atRate: 1.0)
                            self.onPlaybackAction(.play)
                            self.volumeFade = self.player?.fadeVolume(from: 0.0, to: 1.0, duration: 0.4)
                        }
                        if let audioPlayer = self.audioPlayer, audioPlayer.status != .readyToPlay {
                            Queue.mainQueue().after(0.1) {
                                startPlayback()
                            }
                        } else {
                            startPlayback()
                        }
                    }
                } else if let audioPlayer = self.audioPlayer {
                    let offset = self.values.audioTrackOffset ?? 0.0
                    let lowerBound = self.values.audioTrackTrimRange?.lowerBound ?? 0.0
                    
                    let audioTime = CMTime(seconds: offset + lowerBound, preferredTimescale: CMTimeScale(1000))
                    audioPlayer.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    if audioPlayer.status != .readyToPlay {
                        Queue.mainQueue().after(0.1) {
                            audioPlayer.play()
                        }
                    } else {
                        audioPlayer.play()
                    }
                }
            }
        })
    }
    
    private func setupTimeObservers() {
        var observedPlayer = self.player
        var isAudioPlayerOnly = false
        if observedPlayer == nil {
            observedPlayer = self.audioPlayer
            if observedPlayer != nil {
                isAudioPlayerOnly = true
            }
        }
        guard let observedPlayer else {
            return
        }
        
        if self.timeObserver == nil {
            self.timeObserverPlayer = observedPlayer
            self.timeObserver = observedPlayer.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 10), queue: DispatchQueue.main) { [weak self, weak observedPlayer] time in
                guard let self, let observedPlayer, let duration = observedPlayer.currentItem?.duration.seconds else {
                    return
                }
                var hasAudio = false
                if let audioTracks = observedPlayer.currentItem?.asset.tracks(withMediaType: .audio) {
                    hasAudio = !audioTracks.isEmpty
                }
                if time.seconds > 20000 {
                    
                } else {
                    self.playerPlaybackState = (duration, time.seconds, observedPlayer.rate > 0.0, hasAudio, isAudioPlayerOnly)
                }
            }
        }

        if self.didPlayToEndTimeObserver == nil {
            self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: observedPlayer.currentItem, queue: nil, using: { [weak self] notification in
                if let self {
                    var start: Double
                    if self.sourceIsVideo {
                        start = self.values.videoTrimRange?.lowerBound ?? 0.0
                    } else {
                        start = (self.values.audioTrackOffset ?? 0.0) + (self.values.audioTrackTrimRange?.lowerBound ?? 0.0)
                    }
                    let targetTime = CMTime(seconds: start, preferredTimescale: CMTimeScale(1000))
                    self.player?.seek(to: targetTime)
                    self.additionalPlayer?.seek(to: targetTime)
                    self.onPlaybackAction(.seek(start))
                    
                    self.player?.play()
                    self.additionalPlayer?.play()
                    
                    if self.sourceIsVideo {
                        let audioTime = self.audioTime(for: targetTime)
                        if let audioDelay = self.audioDelay(for: targetTime) {
                            self.audioPlayer?.pause()
                            self.audioDelayTimer = SwiftSignalKit.Timer(timeout: audioDelay, repeat: false, completion: { [weak self] in
                                self?.audioPlayer?.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                self?.audioPlayer?.play()
                            }, queue: Queue.mainQueue())
                            self.audioDelayTimer?.start()
                        } else {
                            self.audioPlayer?.seek(to: audioTime)
                            self.audioPlayer?.play()
                        }
                    } else {
                        self.audioPlayer?.seek(to: targetTime)
                        self.audioPlayer?.play()
                    }
                    
                    Queue.mainQueue().justDispatch {
                        self.onPlaybackAction(.play)
                    }
                }
            })
        }
    }
    
    private func setupDidPlayToEndObserver() {
       
    }
    
    public func attachPreviewView(_ previewView: MediaEditorPreviewView) {
        self.previewView?.renderer = nil
        
        self.previewView = previewView
        previewView.renderer = self.renderer
        
        self.setupSource()
    }
    
    private var skipRendering = false
    private var forceRendering = false
    
    private enum UpdateMode {
        case generic
        case skipRendering
        case forceRendering
    }
    private func updateValues(mode: UpdateMode = .generic, _ f: (MediaEditorValues) -> MediaEditorValues) {
        if case .skipRendering = mode {
            self.skipRendering = true
        } else if case .forceRendering = mode {
            self.forceRendering = true
        }
        let updatedValues = f(self.values)
        if self.values != updatedValues {
            self.values = updatedValues
        }
        if case .skipRendering = mode {
            self.skipRendering = false
        } else if case .forceRendering = mode {
            self.forceRendering = false
        }
    }
    
    public func setCrop(offset: CGPoint, scale: CGFloat, rotation: CGFloat, mirroring: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedCrop(offset: offset, scale: scale, rotation: rotation, mirroring: mirroring)
        }
    }
    
    public func getToolValue(_ key: EditorToolKey) -> Any? {
        return self.values.toolValues[key]
    }
    
    private var previewUnedited = false
    public func setPreviewUnedited(_ preview: Bool) {
        self.previewUnedited = preview
        self.updateRenderChain()
    }
    
    public func setToolValue(_ key: EditorToolKey, value: Any) {
        self.updateValues { values in
            var updatedToolValues = values.toolValues
            updatedToolValues[key] = value
            return values.withUpdatedToolValues(updatedToolValues)
        }
    }
    
    public func setVideoIsMuted(_ videoIsMuted: Bool) {
        self.player?.isMuted = videoIsMuted
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedVideoIsMuted(videoIsMuted)
        }
    }
    
    public func setVideoIsMirrored(_ videoIsMirrored: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedVideoIsMirrored(videoIsMirrored)
        }
    }
    
    public func setVideoIsFullHd(_ videoIsFullHd: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedVideoIsFullHd(videoIsFullHd)
        }
    }
    
    public enum PlaybackAction {
        case play
        case pause
        case seek(Double)
    }
    
    public var onPlaybackAction: (PlaybackAction) -> Void = { _ in }
    
    private var initialSeekPosition: Double?
    private var targetTimePosition: (CMTime, Bool)?
    private var updatingTimePosition = false
    public func seek(_ position: Double, andPlay play: Bool) {
        if self.player == nil && self.audioPlayer == nil {
            self.initialSeekPosition = position
            return
        }
        if !play {
            self.player?.pause()
            self.additionalPlayer?.pause()
            self.audioPlayer?.pause()
            self.onPlaybackAction(.pause)
        }
        let targetPosition = CMTime(seconds: position, preferredTimescale: CMTimeScale(1000.0))
        if self.targetTimePosition?.0 != targetPosition {
            self.targetTimePosition = (targetPosition, play)
            if !self.updatingTimePosition {
                self.updateVideoTimePosition()
            }
        }
        if play {
            self.player?.play()
            self.additionalPlayer?.play()
            
            if self.sourceIsVideo {
                let audioTime = self.audioTime(for: targetPosition)
                if let audioDelay = self.audioDelay(for: targetPosition) {
                    self.audioDelayTimer = SwiftSignalKit.Timer(timeout: audioDelay, repeat: false, completion: { [weak self] in
                        self?.audioPlayer?.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        self?.audioPlayer?.play()
                    }, queue: Queue.mainQueue())
                    self.audioDelayTimer?.start()
                } else {
                    self.audioPlayer?.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    self.audioPlayer?.play()
                }
            } else {
                self.audioPlayer?.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero)
                self.audioPlayer?.play()
            }
            
            self.onPlaybackAction(.play)
        }
    }
    
    public func seek(_ position: Double, completion: @escaping () -> Void) {
        guard let player = self.player else {
            completion()
            return
        }
        player.pause()
        self.additionalPlayer?.pause()
        self.audioPlayer?.pause()
        
        let targetPosition = CMTime(seconds: position, preferredTimescale: CMTimeScale(1000.0))
        player.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: {  _ in
            Queue.mainQueue().async {
                completion()
            }
        })
                
        self.additionalPlayer?.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero)
        
        if let _ = self.audioDelay(for: targetPosition) {
            
        } else {
            self.audioPlayer?.seek(to: self.audioTime(for: targetPosition), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
        
    private var audioDelayTimer: SwiftSignalKit.Timer?
    private func audioDelay(for time: CMTime) -> Double? {
        var time = time
        if time == .invalid {
            time = .zero
        }
        let videoStart = self.values.videoTrimRange?.lowerBound ?? 0.0
        var audioStart = self.values.audioTrackTrimRange?.lowerBound ?? 0.0
        if let offset = self.values.audioTrackOffset, offset < 0.0 {
            audioStart -= offset
        }
        if audioStart - videoStart > 0.0 {
            let delay = audioStart - time.seconds
            if delay > 0 {
                return delay
            }
        }
        return nil
    }
    
    private func audioTime(for time: CMTime) -> CMTime {
        var time = time
        if time == .invalid {
            time = .zero
        }
        let seconds = time.seconds
        
        let offset = self.values.audioTrackOffset ?? 0.0
        let audioOffset = max(0.0, offset)
        let audioStart = self.values.audioTrackTrimRange?.lowerBound ?? 0.0
        if seconds < audioStart - min(0.0, offset) {
            return CMTime(seconds: audioOffset + audioStart, preferredTimescale: CMTimeScale(1000.0))
        } else {
            return CMTime(seconds: audioOffset + seconds + min(0.0, offset), preferredTimescale: CMTimeScale(1000.0))
        }
    }
    
    public var isPlaying: Bool {
        let effectivePlayer = self.player ?? self.audioPlayer
        return (effectivePlayer?.rate ?? 0.0) > 0.0
    }
    
    public func togglePlayback() {
        if self.isPlaying {
            self.stop()
        } else {
            self.play()
        }
    }
    
    public func play() {
        self.setRate(1.0)
    }
    
    public func stop() {
        self.setRate(0.0)
    }
    
    private func setRate(_ rate: Float) {
        let hostTime: UInt64 = mach_absolute_time()
        let time: TimeInterval = 0
        let cmHostTime = CMClockMakeHostTimeFromSystemUnits(hostTime)
        let cmVTime = CMTimeMakeWithSeconds(time, preferredTimescale: 1000000)
        let futureTime = CMTimeAdd(cmHostTime, cmVTime)
        
        if self.player == nil, let audioPlayer = self.audioPlayer {
            let itemTime = audioPlayer.currentItem?.currentTime() ?? .invalid
            if audioPlayer.status == .readyToPlay {
                audioPlayer.setRate(rate, time: itemTime, atHostTime: futureTime)
            } else {
                audioPlayer.seek(to: itemTime, toleranceBefore: .zero, toleranceAfter: .zero)
                if rate > 0.0 {
                    audioPlayer.play()
                } else {
                    audioPlayer.pause()
                }
            }
        } else {
            let itemTime = self.player?.currentItem?.currentTime() ?? .invalid
            let audioTime = self.audioTime(for: itemTime)
        
            self.player?.setRate(rate, time: itemTime, atHostTime: futureTime)
            self.additionalPlayer?.setRate(rate, time: itemTime, atHostTime: futureTime)
            
            if let audioPlayer = self.audioPlayer {
                if rate > 0.0, let audioDelay = self.audioDelay(for: itemTime) {
                    self.audioDelayTimer = SwiftSignalKit.Timer(timeout: audioDelay, repeat: false, completion: { [weak self] in
                        self?.audioPlayer?.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        self?.audioPlayer?.play()
                    }, queue: Queue.mainQueue())
                    self.audioDelayTimer?.start()
                } else {
                    if audioPlayer.status == .readyToPlay {
                        audioPlayer.setRate(rate, time: audioTime, atHostTime: futureTime)
                        if rate > 0.0 {
//                            audioPlayer.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                            audioPlayer.play()
                        }
                    } else {
                        audioPlayer.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        if rate > 0.0 {
                            audioPlayer.play()
                        } else {
                            audioPlayer.pause()
                        }
                    }
                }
            }
        }
        
        if rate > 0.0 {
            self.onPlaybackAction(.play)
        } else {
            self.onPlaybackAction(.pause)
            
            self.audioDelayTimer?.invalidate()
            self.audioDelayTimer = nil
        }
    }
    
    public func invalidate() {
        self.player?.pause()
        self.additionalPlayer?.pause()
        self.audioPlayer?.pause()
        self.onPlaybackAction(.pause)
        self.renderer.textureSource?.invalidate()
        
        self.audioDelayTimer?.invalidate()
        self.audioDelayTimer = nil
    }
    
    private func updateVideoTimePosition() {
        guard let (targetPosition, _) = self.targetTimePosition else {
            return
        }
        self.updatingTimePosition = true
        
        if self.player == nil, let audioPlayer = self.audioPlayer {
            audioPlayer.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] _ in
                if let self {
                    if let (currentTargetPosition, _) = self.targetTimePosition, currentTargetPosition == targetPosition {
                        self.updatingTimePosition = false
                        self.targetTimePosition = nil
                    } else {
                        self.updateVideoTimePosition()
                    }
                }
            })
        } else {
            self.player?.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] _ in
                if let self {
                    if let (currentTargetPosition, _) = self.targetTimePosition, currentTargetPosition == targetPosition {
                        self.updatingTimePosition = false
                        self.targetTimePosition = nil
                    } else {
                        self.updateVideoTimePosition()
                    }
                }
            })
            
            self.additionalPlayer?.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero)
            
            if let _ = self.audioDelay(for: targetPosition) {
            } else {
                self.audioPlayer?.seek(to: self.audioTime(for: targetPosition), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        self.onPlaybackAction(.seek(targetPosition.seconds))
    }
    
    public func setVideoTrimRange(_ trimRange: Range<Double>, apply: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedVideoTrimRange(trimRange)
        }
        
        if apply {
            self.player?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
            self.additionalPlayer?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
        }
    }
    
    public func setAdditionalVideo(_ path: String, positionChanges: [VideoPositionChange]) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedAdditionalVideo(path: path, positionChanges: positionChanges)
        }
    }
    
    public func setAdditionalVideoPosition(_ position: CGPoint, scale: CGFloat, rotation: CGFloat) {
        self.updateValues(mode: .forceRendering) { values in
            return values.withUpdatedAdditionalVideo(position: position, scale: scale, rotation: rotation)
        }
    }
    
    public func setDrawingAndEntities(data: Data?, image: UIImage?, entities: [CodableDrawingEntity]) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedDrawingAndEntities(drawing: image, entities: entities)
        }
    }
    
    public func setGradientColors(_ gradientColors: [UIColor]) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedGradientColors(gradientColors: gradientColors)
        }
    }
    
    public func setAudioTrack(_ audioTrack: MediaAudioTrack?, trimRange: Range<Double>? = nil, offset: Double? = nil) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedAudioTrack(audioTrack).withUpdatedAudioTrackSamples(nil).withUpdatedAudioTrackTrimRange(trimRange).withUpdatedAudioTrackVolume(nil).withUpdatedAudioTrackOffset(offset)
        }
        
        if let audioPlayer = self.audioPlayer {
            audioPlayer.pause()
            
            if self.sourceIsVideo {
                self.audioDelayTimer?.invalidate()
                self.audioDelayTimer = nil
            } else {
                self.destroyTimeObservers()
            }
            self.audioPlayer = nil
             
            if !self.sourceIsVideo {
                self.playerPromise.set(.single(nil))
            }
        }
        
        self.setupAudioPlayback()
        self.updateAudioPlaybackRange()
    }
    
    private func setupAudioPlayback() {
        if let audioTrack = self.values.audioTrack {
            let path = fullDraftPath(peerId: self.context.account.peerId, path: audioTrack.path)
            let audioAsset = AVURLAsset(url: URL(fileURLWithPath: path))
            let playerItem = AVPlayerItem(asset: audioAsset)
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = false
            self.audioPlayer = player
            self.maybeGenerateAudioSamples(asset: audioAsset)
            
            if let volume = self.values.audioTrackVolume {
                self.audioPlayer?.volume = Float(volume)
            }
            
            self.setupTimeObservers()
            
            if !self.sourceIsVideo {
                self.playerPromise.set(.single(player))
            }
        }
    }
    
    public func setAudioTrackTrimRange(_ trimRange: Range<Double>?, apply: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedAudioTrackTrimRange(trimRange)
        }
        
        if apply, let _ = trimRange {
            self.updateAudioPlaybackRange()
        }
    }
    
    public func setAudioTrackOffset(_ offset: Double?, apply: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedAudioTrackOffset(offset)
        }
        
        if apply {
            self.updateAudioPlaybackRange()
        }
    }
    
    private func updateAudioPlaybackRange() {
        if let upperBound = self.values.audioTrackTrimRange?.upperBound {
            let offset = max(0.0, self.values.audioTrackOffset ?? 0.0)
            self.audioPlayer?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: offset + upperBound, preferredTimescale: CMTimeScale(1000))
        } else {
            self.audioPlayer?.currentItem?.forwardPlaybackEndTime = .invalid
        }
    }
    
    public func setAudioTrackVolume(_ volume: CGFloat?) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedAudioTrackVolume(volume)
        }
        
        self.audioPlayer?.volume = Float(volume ?? 1.0)
    }
    
    private var previousUpdateTime: Double?
    private var scheduledUpdate = false
    private func updateRenderChain() {
        self.renderer.renderPassedEnabled = !self.previewUnedited
        self.renderChain.update(values: self.values)
        self.renderer.videoFinishPass.update(values: self.values)
        
        if let player = self.player, player.rate > 0.0 && !self.forceRendering {
        } else {
            let currentTime = CACurrentMediaTime()
            if !self.scheduledUpdate {
                let delay = self.forceRendering ? 0.0 : 0.03333
                if let previousUpdateTime = self.previousUpdateTime, delay > 0.0, currentTime - previousUpdateTime < delay {
                    self.scheduledUpdate = true
                    Queue.mainQueue().after(delay - (currentTime - previousUpdateTime)) {
                        self.scheduledUpdate = false
                        self.previousUpdateTime = CACurrentMediaTime()
                        self.renderer.willRenderFrame()
                        self.renderer.renderFrame()
                    }
                } else {
                    self.previousUpdateTime = currentTime
                    self.renderer.willRenderFrame()
                    self.renderer.renderFrame()
                }
            }
        }
    }
    
    public func requestRenderFrame() {
        self.renderer.willRenderFrame()
        self.renderer.renderFrame()
    }
    
    private func maybeGeneratePersonSegmentation(_ image: UIImage?) {
        if #available(iOS 15.0, *), let cgImage = image?.cgImage {
            let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, _ in
                guard let _ = request.results?.first as? VNFaceObservation else { return }
                
                let personRequest = VNGeneratePersonSegmentationRequest(completionHandler: { [weak self] request, error in
                    if let self, let result = (request as? VNGeneratePersonSegmentationRequest)?.results?.first {
                        Queue.mainQueue().async {
                            self.renderChain.blurPass.maskTexture = pixelBufferToMTLTexture(pixelBuffer: result.pixelBuffer, textureCache: self.textureCache)
                        }
                    }
                })
                personRequest.qualityLevel = .accurate
                personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([personRequest])
                } catch {
                    print(error)
                }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([faceRequest])
            } catch {
                print(error)
            }
        }
    }
    
    private func maybeGenerateAudioSamples(asset: AVAsset) {
        Queue.concurrentDefaultQueue().async {
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                return
            }
            
            do {
                let assetReader = try AVAssetReader(asset: asset)
                
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                
                let assetReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: settings)
                
                assetReader.add(assetReaderOutput)
                
                assetReader.startReading()
                
                var samplesData = Data()
                var peak: Int32 = 0
                
                while let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() {
                    if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                        let length = CMBlockBufferGetDataLength(dataBuffer)
                        let bytes = UnsafeMutablePointer<Int32>.allocate(capacity: length)
                        CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: length, destination: bytes)
                                                               
                        let samples = Array(UnsafeBufferPointer(start: bytes, count: length / MemoryLayout<Int32>.size))
                        if var maxSample = samples.max() {
                            if maxSample > peak {
                                peak = maxSample
                            }
                            samplesData.append(Data(bytesNoCopy: &maxSample, count: 4, deallocator: .none))
                        }
                    
                        bytes.deallocate()
                    }
                }
                Queue.mainQueue().async {
                    self.updateValues(mode: .skipRendering) { values in
                        return values.withUpdatedAudioTrackSamples(MediaAudioTrackSamples(samples: samplesData, peak: peak))
                    }
                }
            } catch {
            }
        }
    }
}
