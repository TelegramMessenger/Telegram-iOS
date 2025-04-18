import Foundation
import UIKit
import Metal
import MetalKit
import Vision
import Photos
import SwiftSignalKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import FastBlur
import AccountContext
import ImageTransparency
import ImageObjectSeparation

public struct MediaEditorPlayerState: Equatable {
    public struct Track: Equatable {
        public enum Content: Equatable {
            case video(frames: [UIImage], framesUpdateTimestamp: Double)
            case audio(artist: String?, title: String?, samples: Data?, peak: Int32)
            
            public static func ==(lhs: Content, rhs: Content) -> Bool {
                switch lhs {
                case let .video(_, framesUpdateTimestamp):
                    if case .video(_, framesUpdateTimestamp) = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .audio(lhsArtist, lhsTitle, lhsSamples, lhsPeak):
                    if case let .audio(rhsArtist, rhsTitle, rhsSamples, rhsPeak) = rhs {
                        return lhsArtist == rhsArtist && lhsTitle == rhsTitle && lhsSamples == rhsSamples && lhsPeak == rhsPeak
                    } else {
                        return false
                    }
                }
            }
        }
        
        public let id: Int32
        public let content: Content
        public let duration: Double
        public let trimRange: Range<Double>?
        public let offset: Double?
        public let isMain: Bool
        public let visibleInTimeline: Bool
    }
    
    public let generationTimestamp: Double
    public let tracks: [Track]
    public let position: Double
    public let isPlaying: Bool
    public let collageSamples: (samples: Data, peak: Int32)?
    
    public var isAudioOnly: Bool {
        var hasVideoTrack = false
        var hasAudioTrack = false
        for track in tracks {
            switch track.content {
            case .video:
                hasVideoTrack = true
            case .audio:
                hasAudioTrack = true
            }
        }
        return !hasVideoTrack && hasAudioTrack
    }
    
    public var hasAudio: Bool {
        return true
    }
    
    public static func == (lhs: MediaEditorPlayerState, rhs: MediaEditorPlayerState) -> Bool {
        if lhs.generationTimestamp != rhs.generationTimestamp {
            return false
        }
        if lhs.tracks != rhs.tracks {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if lhs.isPlaying != rhs.isPlaying {
            return false
        }
        if lhs.collageSamples?.samples != rhs.collageSamples?.samples || lhs.collageSamples?.peak != rhs.collageSamples?.peak {
            return false
        }
        return true
    }
}

public final class MediaEditor {
    public struct GradientColors {
        public let top: UIColor
        public let bottom: UIColor
        
        public init(colors: [UIColor]) {
            if colors.count == 2 || colors.count == 1 {
                self.top = colors.first!
                self.bottom = colors.last!
            } else {
                self.top = .black
                self.bottom = .black
            }
        }
        
        public init(top: UIColor, bottom: UIColor) {
            self.top = top
            self.bottom = bottom
        }
        
        public var array: [UIColor] {
            return [self.top, self.bottom]
        }
    }
    
    public enum Mode {
        case `default`
        case sticker
        case avatar
    }
    
    public enum Subject {
        public struct VideoCollageItem {
            public enum Content: Equatable {
                case image(UIImage)
                case video(String, Double)
                case asset(PHAsset)
            }
            public let content: Content
            public let frame: CGRect
            public let contentScale: CGFloat
            public let contentOffset: CGPoint
            
            var isVideo: Bool {
                return self.duration > 0.0
            }
            
            var duration: Double {
                switch self.content {
                case .image:
                    return 0.0
                case let .video(_, duration):
                    return duration
                case let .asset(asset):
                    return asset.duration
                }
            }
            
            public init(
                content: Content,
                frame: CGRect,
                contentScale: CGFloat,
                contentOffset: CGPoint
            ) {
                self.content = content
                self.frame = frame
                self.contentScale = contentScale
                self.contentOffset = contentOffset
            }
        }
        
        case image(UIImage, PixelDimensions)
        case video(String, UIImage?, Bool, String?, PixelDimensions, Double)
        case videoCollage([VideoCollageItem])
        case asset(PHAsset)
        case draft(MediaEditorDraft)
        case message(MessageId)
        case gift(StarGift.UniqueGift)
        case sticker(TelegramMediaFile)
        
        var dimensions: PixelDimensions {
            switch self {
            case let .image(_, dimensions), let .video(_, _, _, _, dimensions, _):
                return dimensions
            case let .asset(asset):
                return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
            case let .draft(draft):
                return draft.dimensions
            case .message, .gift, .sticker, .videoCollage:
                return PixelDimensions(width: 1080, height: 1920)
            }
        }
    }

    private let context: AccountContext
    private let mode: Mode
    private let subject: Subject
    
    private let clock = CMClockGetHostTimeClock()
        
    private var stickerEntity: MediaEditorComposerStickerEntity?
    
    private var player: AVPlayer?
    private let playerPromise = Promise<AVPlayer?>()
    private var playerAudioMix: AVMutableAudioMix?
    
    private var additionalPlayers: [AVPlayer] = []
    private let additionalPlayersPromise = Promise<[AVPlayer]>([])
    private var additionalPlayerAudioMixes: [AVMutableAudioMix] = []
    
    private var audioPlayer: AVPlayer?
    private let audioPlayerPromise = Promise<AVPlayer?>(nil)
    private var audioPlayerAudioMix: AVMutableAudioMix?
    
    private var volumeFadeIn: SwiftSignalKit.Timer?
    
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
    
    private let gradientColorsPromise = Promise<GradientColors?>()
    public var gradientColors: Signal<GradientColors?, NoError> {
        return self.gradientColorsPromise.get()
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
    
    public enum CutoutStatus: Equatable {
        public enum Availability: Equatable {
            case available
            case preparing(progress: Float)
            case unavailable
        }
        case unknown
        case known(canCutout: Bool, availability: Availability, hasTransparency: Bool)
    }
        
    private let cutoutDisposable = MetaDisposable()
    private var cutoutStatusValue: CutoutStatus = .unknown {
        didSet {
            self.cutoutStatusPromise.set(self.cutoutStatusValue)
        }
    }
    private let cutoutStatusPromise = ValuePromise<CutoutStatus>(.unknown)
    public var cutoutStatus: Signal<CutoutStatus, NoError> {
        return self.cutoutStatusPromise.get()
    }
    
    public var maskUpdated: (UIImage, Bool) -> Void = { _, _ in }
    
    public var classificationUpdated: ([(String, Float)]) -> Void = { _ in }
    
    private var textureCache: CVMetalTextureCache!
    
    public var hasPortraitMask: Bool {
        return self.renderChain.blurPass.maskTexture != nil
    }
    
    public var sourceIsVideo: Bool {
        self.player != nil
    }
    
    public var resultIsVideo: Bool {
        if self.values.entities.contains(where: { $0.entity.isAnimated }) {
            return true
        }
        if case let .sticker(file) = self.subject {
            return file.isAnimatedSticker || file.isVideoSticker
        } else {
            return self.player != nil || self.audioPlayer != nil || !self.additionalPlayers.isEmpty
        }
    }
    
    public var resultImage: UIImage? {
        return self.renderer.finalRenderedImage()
    }
    
    public func getResultImage(mirror: Bool) -> UIImage? {
        return self.renderer.finalRenderedImage(mirror: mirror)
    }
            
    private var wallpapersValue: ((day: UIImage, night: UIImage?))? {
        didSet {
            self.wallpapersPromise.set(.single(self.wallpapersValue))
        }
    }
    private let wallpapersPromise = Promise<(day: UIImage, night: UIImage?)?>()
    public var wallpapers: Signal<((day: UIImage, night: UIImage?))?, NoError> {
        return self.wallpapersPromise.get()
    }
    
    private struct PlaybackState: Equatable {
        let duration: Double
        let position: Double
        let isPlaying: Bool
        let hasAudio: Bool
        
        init() {
            self.duration = 0.0
            self.position = 0.0
            self.isPlaying = false
            self.hasAudio = false
        }
        
        init(duration: Double, position: Double, isPlaying: Bool, hasAudio: Bool) {
            self.duration = duration
            self.position = position
            self.isPlaying = isPlaying
            self.hasAudio = hasAudio
        }
    }
    
    private var playerPlaybackState: PlaybackState = PlaybackState() {
        didSet {
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        }
    }
    private let playerPlaybackStatePromise = Promise<PlaybackState>(PlaybackState())
    
    public var position: Signal<Double, NoError> {
        return self.playerPlaybackStatePromise.get()
        |> map { state -> Double in
            return state.position
        }
    }
   
    public var duration: Double? {
        if let stickerEntity = self.stickerEntity {
            return stickerEntity.totalDuration
        } else if let _ = self.player {
            if let trimRange = self.values.videoTrimRange {
                return trimRange.upperBound - trimRange.lowerBound
            } else {
                return min(60.0, self.playerPlaybackState.duration)
            }
        } else {
            return nil
        }
    }
    
    public var mainVideoDuration: Double? {
        if self.player != nil {
            return min(60.0, self.playerPlaybackState.duration)
        } else {
            return nil
        }
    }
    
    public var additionalVideoDuration: Double? {
        if let additionalPlayer = self.additionalPlayers.first {
            return min(60.0, additionalPlayer.currentItem?.asset.duration.seconds ?? 0.0)
        } else {
            return nil
        }
    }
    
    public var originalDuration: Double? {
        if self.player != nil || !self.additionalPlayers.isEmpty {
            return min(60.0, self.playerPlaybackState.duration)
        } else {
            return nil
        }
    }
    
    public var onFirstDisplay: () -> Void = {}
    
    public func playerState(framesCount: Int) -> Signal<MediaEditorPlayerState?, NoError> {
        func artistAndTitleForTrack(_ audioTrack: MediaAudioTrack) -> (artist: String?, title: String?) {
            let artist = audioTrack.artist
            var title = audioTrack.title
            if artist == nil && title == nil {
                if let underscoreIndex = audioTrack.path.firstIndex(of: "_"), let dotIndex = audioTrack.path.lastIndex(of: ".") {
                    title = String(audioTrack.path[audioTrack.path.index(after: underscoreIndex)..<dotIndex])
                } else {
                    title = audioTrack.path
                }
            }
            return (artist: artist, title: title)
        }
        
        func playerAndThumbnails(_ signal: Signal<AVPlayer?, NoError>, mirror: Bool = false) -> Signal<(AVPlayer, [UIImage], Double)?, NoError> {
            return signal
            |> mapToSignal { player -> Signal<(AVPlayer, [UIImage], Double)?, NoError> in
                if let player, let asset = player.currentItem?.asset {
                    return videoFrames(asset: asset, count: framesCount, mirror: mirror)
                    |> map { framesAndUpdateTimestamp in
                        return (player, framesAndUpdateTimestamp.0, framesAndUpdateTimestamp.1)
                    }
                } else {
                    return .single(nil)
                }
            }
        }
        
        return combineLatest(
            playerAndThumbnails(self.playerPromise.get()),
            self.additionalPlayersPromise.get()
            |> mapToSignal { players in
                return combineLatest(players.compactMap { playerAndThumbnails(.single($0), mirror: true) })
            },
            self.audioPlayerPromise.get(),
            self.valuesPromise.get(),
            self.playerPlaybackStatePromise.get()
        ) |> map { [weak self] mainPlayerAndThumbnails, additionalPlayerAndThumbnails, audioPlayer, values, playbackState in
            let isCollage = !values.collage.isEmpty
            
            var tracks: [MediaEditorPlayerState.Track] = []
            if let (player, frames, updateTimestamp) = mainPlayerAndThumbnails {
                let duration: Double
                if !playbackState.duration.isNaN {
                    duration = playbackState.duration
                } else {
                    duration = player.currentItem?.asset.duration.seconds ?? 0.0
                }
                tracks.append(MediaEditorPlayerState.Track(
                    id: 0,
                    content: .video(
                        frames: frames,
                        framesUpdateTimestamp: updateTimestamp
                    ),
                    duration: duration,
                    trimRange: values.videoTrimRange,
                    offset: nil,
                    isMain: tracks.isEmpty,
                    visibleInTimeline: true
                ))
            }
            
            var index: Int32 = 1
            for maybeValues in additionalPlayerAndThumbnails {
                if let (player, frames, updateTimestamp) = maybeValues {
                    let duration: Double
                    if !playbackState.duration.isNaN && mainPlayerAndThumbnails == nil {
                        duration = playbackState.duration
                    } else {
                        duration = player.currentItem?.asset.duration.seconds ?? 0.0
                    }
                    
                    var trimRange: Range<Double>?
                    var offset: Double?
                    if isCollage {
                        if let collageIndex = self?.collageItemIndexForTrackId(index) {
                            trimRange = values.collage[collageIndex].videoTrimRange
                            offset = values.collage[collageIndex].videoOffset
                        }
                    } else {
                        trimRange = values.additionalVideoTrimRange
                        offset = values.additionalVideoOffset
                    }
                    
                    tracks.append(MediaEditorPlayerState.Track(
                        id: index,
                        content: .video(
                            frames: frames,
                            framesUpdateTimestamp: updateTimestamp
                        ),
                        duration: duration,
                        trimRange: trimRange,
                        offset: offset,
                        isMain: tracks.isEmpty,
                        visibleInTimeline: !values.additionalVideoIsDual
                    ))
                    index += 1
                }
            }
            
            if let audioTrack = values.audioTrack {
                let (artist, title) = artistAndTitleForTrack(audioTrack)
                tracks.append(MediaEditorPlayerState.Track(
                    id: 1000,
                    content: .audio(
                        artist: artist,
                        title: title,
                        samples: values.audioTrackSamples?.samples,
                        peak: values.audioTrackSamples?.peak ?? 0
                    ),
                    duration: audioTrack.duration,
                    trimRange: values.audioTrackTrimRange,
                    offset: values.audioTrackOffset,
                    isMain: tracks.isEmpty,
                    visibleInTimeline: true
                ))
            }
            
            guard !tracks.isEmpty else {
                return nil
            }
            
            var collageSamples: (Data, Int32)?
            if let samples = values.collageTrackSamples?.samples, let peak = values.collageTrackSamples?.peak {
                collageSamples = (samples, peak)
            }
            
            return MediaEditorPlayerState(
                generationTimestamp: CACurrentMediaTime(),
                tracks: tracks,
                position: playbackState.position,
                isPlaying: playbackState.isPlaying,
                collageSamples: collageSamples
            )
        }
    }
    
    public init(context: AccountContext, mode: Mode, subject: Subject, values: MediaEditorValues? = nil, hasHistogram: Bool = false) {
        self.context = context
        self.mode = mode
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
                videoVolume: 1.0,
                additionalVideoPath: nil,
                additionalVideoIsDual: false,
                additionalVideoPosition: nil,
                additionalVideoScale: nil,
                additionalVideoRotation: nil,
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
            self.playerPlaybackState = PlaybackState(duration: asset.duration, position: 0.0, isPlaying: false, hasAudio: asset.mediaType == .video)
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        } else if case let .video(_, _, _, _, _, duration) = subject {
            self.playerPlaybackState = PlaybackState(duration: duration, position: 0.0, isPlaying: false, hasAudio: true)
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        } else if case let .draft(mediaEditorDraft) = subject, mediaEditorDraft.isVideo {
            self.playerPlaybackState = PlaybackState(duration: mediaEditorDraft.duration ?? 0.0, position: 0.0, isPlaying: false, hasAudio: true)
            self.playerPlaybackStatePromise.set(.single(self.playerPlaybackState))
        }
    }
    
    deinit {
        self.cutoutDisposable.dispose()
        self.textureSourceDisposable?.dispose()
        self.invalidateTimeObservers()
    }
    
    public func replaceSource(_ image: UIImage, additionalImage: UIImage?, time: CMTime, mirror: Bool) {
        guard let renderTarget = self.previewView, let device = renderTarget.mtlDevice, let texture = loadTexture(image: image, device: device) else {
            return
        }
        let additionalTexture = additionalImage.flatMap { loadTexture(image: $0, device: device) }
        if mirror {
            self.renderer.videoFinishPass.additionalTextureRotation = .rotate0DegreesMirrored
        }
        let hasTransparency = imageHasTransparency(image)
        self.renderer.consume(main: .texture(texture, time, hasTransparency, nil, 1.0, .zero), additionals: additionalTexture.flatMap { [.texture($0, time, false, nil, 1.0, .zero)] } ?? [], render: true, displayEnabled: false)
    }
    
    private func setupSource(andPlay: Bool) {
        guard let renderTarget = self.previewView else {
            return
        }
        
        let context = self.context
        if let device = renderTarget.mtlDevice, CVMetalTextureCacheCreate(nil, nil, device, nil, &self.textureCache) != kCVReturnSuccess {
            print("error")
        }
            
        struct TextureSourceResult {
            let image: UIImage?
            let nightImage: UIImage?
            let player: AVPlayer?
            let stickerEntity: MediaEditorComposerStickerEntity?
            let playerIsReference: Bool
            let rect: CGRect?
            let scale: CGFloat
            let offset: CGPoint
            let gradientColors: GradientColors
            
            init(
                image: UIImage? = nil,
                nightImage: UIImage? = nil,
                player: AVPlayer? = nil,
                stickerEntity: MediaEditorComposerStickerEntity? = nil,
                playerIsReference: Bool = false,
                rect: CGRect? = nil,
                scale: CGFloat = 1.0,
                offset: CGPoint = .zero,
                gradientColors: GradientColors
            ) {
                self.image = image
                self.nightImage = nightImage
                self.player = player
                self.stickerEntity = stickerEntity
                self.playerIsReference = playerIsReference
                self.rect = rect
                self.scale = scale
                self.offset = offset
                self.gradientColors = gradientColors
            }
        }
                
        func textureSourceResult(for asset: AVAsset, gradientColors: GradientColors? = nil, rect: CGRect? = nil, scale: CGFloat = 1.0, offset: CGPoint = .zero) -> Signal<TextureSourceResult, NoError> {
            return Signal { [weak self] subscriber in
                guard let self else {
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                let player = self.makePlayer(asset: asset)
                if let gradientColors {
                    subscriber.putNext(TextureSourceResult(
                        player: player,
                        rect: rect,
                        scale: scale,
                        offset: offset,
                        gradientColors: gradientColors
                    ))
                    subscriber.putCompletion()
                    return EmptyDisposable
                } else {
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    imageGenerator.maximumSize = CGSize(width: 72, height: 128)
                    imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0, preferredTimescale: CMTimeScale(30.0)))]) { _, image, _, _, _ in
                        let gradientColors: GradientColors = image.flatMap({ mediaEditorGetGradientColors(from: UIImage(cgImage: $0)) }) ?? GradientColors(top: .black, bottom: .black)
                        subscriber.putNext(TextureSourceResult(
                            player: player,
                            rect: rect,
                            scale: scale,
                            offset: offset,
                            gradientColors: gradientColors
                        ))
                        subscriber.putCompletion()
                    }
                    return ActionDisposable {
                        imageGenerator.cancelAllCGImageGeneration()
                    }
                }
            }
        }
        
        func textureSourceResult(for asset: PHAsset, rect: CGRect? = nil, scale: CGFloat = 1.0, offset: CGPoint = .zero) -> Signal<TextureSourceResult, NoError> {
            return Signal { [weak self] subscriber in
                let isVideo = asset.mediaType == .video
                                
                let targetSize = isVideo ? CGSize(width: 128.0, height: 128.0) : CGSize(width: 1920.0, height: 1920.0)
                let options = PHImageRequestOptions()
                let deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat
                options.deliveryMode = deliveryMode
                options.isNetworkAccessAllowed = true
             
                let requestId = PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options,
                    resultHandler: { [weak self] image, info in
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
                            if isVideo {
                                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil, resultHandler: { asset, _, _ in
                                    if let asset, let player = self?.makePlayer(asset: asset) {
                                        subscriber.putNext(
                                            TextureSourceResult(
                                                player: player,
                                                rect: rect,
                                                scale: scale,
                                                offset: offset,
                                                gradientColors: mediaEditorGetGradientColors(from: image)
                                            )
                                        )
                                        subscriber.putCompletion()
                                    }
                                })
                            } else {
                                if !degraded {
                                    subscriber.putNext(
                                        TextureSourceResult(
                                            image: image,
                                            rect: rect,
                                            scale: scale,
                                            offset: offset,
                                            gradientColors: mediaEditorGetGradientColors(from: image)
                                        )
                                    )
                                    subscriber.putCompletion()
                                }
                            }
                        }
                    }
                )
                return ActionDisposable {
                    PHImageManager.default().cancelImageRequest(requestId)
                }
            }
        }
        
        let textureSource: Signal<TextureSourceResult, NoError>
        switch self.subject {
        case let .image(image, _):
            textureSource = .single(
                TextureSourceResult(
                    image: image,
                    gradientColors: mediaEditorGetGradientColors(from: image)
                )
            )
        case let .draft(draft):
            let gradientColors = draft.values.gradientColors.flatMap { GradientColors(colors: $0) }
            let fullPath = draft.fullPath(engine: context.engine)
            if draft.isVideo {
                let url = URL(fileURLWithPath: fullPath)
                let asset = AVURLAsset(url: url)
                textureSource = textureSourceResult(for: asset, gradientColors: gradientColors)
            } else {
                guard let image = UIImage(contentsOfFile: fullPath) else {
                    return
                }
                textureSource = .single(
                    TextureSourceResult(
                        image: image,
                        gradientColors: gradientColors ?? mediaEditorGetGradientColors(from: image)
                    )
                )
            }
        case let .video(path, _, mirror, _, _, _):
            //TODO: pass mirror
            let _ = mirror
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            textureSource = textureSourceResult(for: asset)
        case let .videoCollage(items):
            if let longestItem = longestCollageItem(items) {
                switch longestItem.content {
                case let .video(path, _):
                    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                    textureSource = textureSourceResult(for: asset, rect: longestItem.frame, scale: longestItem.contentScale, offset: longestItem.contentOffset)
                case let .asset(asset):
                    textureSource = textureSourceResult(for: asset, rect: longestItem.frame, scale: longestItem.contentScale, offset: longestItem.contentOffset)
                default:
                    textureSource = .complete()
                }
            } else {
                textureSource = .complete()
            }
        case let .asset(asset):
            textureSource = textureSourceResult(for: asset)
        case let .message(messageId):
            textureSource = self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> mapToSignal { message in
                var player: AVPlayer?
                if let message, !"".isEmpty {
                    if let maybeFile = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile, maybeFile.isVideo, let path = self.context.account.postbox.mediaBox.completedResourcePath(maybeFile.resource, pathExtension: "mp4") {
                        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                        player = self.makePlayer(asset: asset)
                    }
                }
                return getChatWallpaperImage(context: self.context, peerId: messageId.peerId)
                |> map { _, image, nightImage in
                    return TextureSourceResult(
                        image: image,
                        nightImage: nightImage,
                        player: player,
                        playerIsReference: true,
                        gradientColors: GradientColors(top: .black, bottom: .black)
                    )
                }
            }
        case .gift:
            textureSource = getChatWallpaperImage(context: self.context, peerId: self.context.account.peerId)
            |> map { _, image, nightImage in
                return TextureSourceResult(
                    image: image,
                    nightImage: nightImage,
                    player: nil,
                    playerIsReference: true,
                    gradientColors: GradientColors(top: .black, bottom: .black)
                )
            }
        case let .sticker(file):
            let entity = MediaEditorComposerStickerEntity(
                postbox: self.context.account.postbox,
                content: .file(file),
                position: .zero,
                scale: 1.0,
                rotation: 0.0,
                baseSize: CGSize(width: 512.0, height: 512.0),
                mirrored: false,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                tintColor: nil,
                isStatic: false,
                highRes: true
            )
            textureSource = .single(
                TextureSourceResult(
                    stickerEntity: entity,
                    gradientColors: GradientColors(top: .clear, bottom: .clear)
                )
            )
        }
        
        self.textureSourceDisposable = (textureSource
        |> deliverOnMainQueue).start(next: { [weak self] textureSourceResult in
            if let self {
                self.renderer.onNextRender = { [weak self] in
                    self?.onFirstDisplay()
                }
                
                let textureSource = UniversalTextureSource(renderTarget: renderTarget)
                
                switch self.subject {
                case .message, .gift:
                    if let image = textureSourceResult.image {
                        self.wallpapersValue = (image, textureSourceResult.nightImage ?? image)
                    }
                default:
                    break
                }
            
                self.player = textureSourceResult.player
                self.playerPromise.set(.single(self.player))
                            
                if let image = textureSourceResult.image {
                    if self.values.nightTheme, let nightImage = textureSourceResult.nightImage {
                        textureSource.setMainInput(.image(nightImage, nil, 1.0, .zero))
                    } else {
                        textureSource.setMainInput(.image(image, nil, 1.0, .zero))
                    }
                    
                    if case .sticker = self.mode {
                        if !imageHasTransparency(image) {
                            self.cutoutDisposable.set((cutoutAvailability(context: self.context)
                            |> mapToSignal { availability -> Signal<MediaEditor.CutoutStatus, NoError> in
                                switch availability {
                                case .available:
                                    return cutoutStickerImage(from: image, context: context, onlyCheck: true)
                                    |> map { result in
                                        return .known(canCutout: result != nil, availability: .available, hasTransparency: false)
                                    }
                                case let .progress(progress):
                                    return .single(.known(canCutout: false, availability: .preparing(progress: progress), hasTransparency: false))
                                case .unavailable:
                                    return .single(.known(canCutout: false, availability: .unavailable, hasTransparency: false))
                                }
                            }
                            |> deliverOnMainQueue).start(next: { [weak self] status in
                                guard let self else {
                                    return
                                }
                                self.cutoutStatusValue = status
                            }))
                            self.maskUpdated(image, false)
                        } else {
                            self.cutoutStatusValue = .known(canCutout: false, availability: .unavailable, hasTransparency: true)
                            
                            if let maskImage = generateTintedImage(image: image, color: .white, backgroundColor: .black) {
                                self.maskUpdated(maskImage, true)
                            }
                        }
                        let _ = (classifyImage(image)
                        |> deliverOnMainQueue).start(next: { [weak self] classes in
                            self?.classificationUpdated(classes)
                        })
                    }
                }
                if let player = self.player, let playerItem = player.currentItem, !textureSourceResult.playerIsReference {
                    textureSource.setMainInput(.video(playerItem, textureSourceResult.rect, textureSourceResult.scale, textureSourceResult.offset))
                }
                if self.values.collage.isEmpty, let additionalPlayer = self.additionalPlayers.first, let playerItem = additionalPlayer.currentItem {
                    textureSource.setAdditionalInputs([.video(playerItem, nil, 1.0, .zero)])
                }
                if let entity = textureSourceResult.stickerEntity {
                    textureSource.setMainInput(.entity(entity))
                }
                self.stickerEntity = textureSourceResult.stickerEntity
                
                self.renderer.textureSource = textureSource
                if !self.values.collage.isEmpty {
                    self.setupAdditionalVideoPlayback()
                }
                
                switch self.mode {
                case .default:
                    self.setGradientColors(textureSourceResult.gradientColors)
                case .sticker, .avatar:
                    self.setGradientColors(GradientColors(top: .clear, bottom: .clear))
                }
                
                if let _ = textureSourceResult.player {
                    self.updateRenderChain()
//                    let _ = image
//                    self.maybeGeneratePersonSegmentation(image)
                }
                
                if let _ = self.values.audioTrack {
                    self.setupAudioPlayback()
                    self.updateAudioPlaybackRange()
                }
                
                if let player {
                    player.isMuted = self.values.videoIsMuted
                    if let trimRange = self.values.videoTrimRange {
                        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
//                        additionalPlayer?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
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
                            guard andPlay else {
                                return
                            }
                            player.playImmediately(atRate: 1.0)
                            for player in self.additionalPlayers {
                                player.playImmediately(atRate: 1.0)
                            }
//                            additionalPlayer?.playImmediately(atRate: 1.0)
                            self.audioPlayer?.playImmediately(atRate: 1.0)
                            self.onPlaybackAction(.play)
                            self.volumeFadeIn = player.fadeVolume(from: 0.0, to: 1.0, duration: 0.4)
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
    
    public func setOnNextDisplay(_ f: @escaping () -> Void) {
        self.renderer.onNextRender = f
    }
    
    public func setOnNextAdditionalDisplay(_ f: @escaping () -> Void) {
        self.renderer.onNextAdditionalRender = f
    }
    
    private func setupTimeObservers() {
        var observedPlayer = self.player
        if observedPlayer == nil {
            observedPlayer = self.additionalPlayers.first
        }
        if observedPlayer == nil {
            observedPlayer = self.audioPlayer
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
                    self.playerPlaybackState = PlaybackState(duration: duration, position: time.seconds, isPlaying: observedPlayer.rate > 0.0, hasAudio: hasAudio)
                }
            }
        }

        if self.didPlayToEndTimeObserver == nil {
            self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: observedPlayer.currentItem, queue: nil, using: { [weak self] notification in
                if let self {
                    var start: Double = 0.0
                    if self.player != nil {
                        start = self.values.videoTrimRange?.lowerBound ?? 0.0
                    } else if !self.additionalPlayers.isEmpty {
                        start = self.values.additionalVideoTrimRange?.lowerBound ?? 0.0
                    } else if self.audioPlayer != nil {
                        start = (self.values.audioTrackOffset ?? 0.0) + (self.values.audioTrackTrimRange?.lowerBound ?? 0.0)
                    }
                    
                    self.player?.pause()
                    self.additionalPlayers.forEach { $0.pause() }
                    self.audioPlayer?.pause()
                    
                    self.seek(start, andPlay: true)
                }
            })
        }
    }
    
    private func invalidateTimeObservers() {
        if let timeObserver = self.timeObserver {
            self.timeObserverPlayer?.removeTimeObserver(timeObserver)
            
            self.timeObserver = nil
            self.timeObserverPlayer = nil
        }
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
            self.didPlayToEndTimeObserver = nil
        }
        
        self.videoDelayTimer.values.forEach { $0.invalidate() }
        self.videoDelayTimer = [:]
        
        self.audioDelayTimer?.invalidate()
        self.audioDelayTimer = nil
    }
    
    public func attachPreviewView(_ previewView: MediaEditorPreviewView, andPlay: Bool) {
        self.previewView?.renderer = nil
        
        self.previewView = previewView
        previewView.renderer = self.renderer
        
        self.setupSource(andPlay: andPlay)
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
        self.updateValues(mode: .forceRendering) { values in
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
    
    public func setToolValue(_ key: EditorToolKey, value: Any?) {
        self.updateValues { values in
            var updatedToolValues = values.toolValues
            updatedToolValues[key] = value
            return values.withUpdatedToolValues(updatedToolValues)
        }
    }
    
    private var hadSound = false
    public func maybeMuteVideo() {
        guard let player = self.player else {
            return
        }
        if !player.isMuted {
            self.hadSound = true
            player.isMuted = true
        }
    }
    
    public func maybeUnmuteVideo() {
        guard let player = self.player else {
            return
        }
        if self.hadSound {
            self.hadSound = false
            player.isMuted = false
        }
    }
    
    private var wasPlaying = false
    @discardableResult
    public func maybePauseVideo() -> Bool {
        if self.isPlaying {
            self.wasPlaying = true
            self.stop(isInternal: true)
            return true
        }
        return false
    }
    
    @discardableResult
    public func maybeUnpauseVideo() -> Bool {
        if self.wasPlaying {
            self.wasPlaying = false
            self.play(isInternal: true)
            return true
        }
        return false
    }
    
    public func setVideoIsMuted(_ videoIsMuted: Bool) {
        self.player?.isMuted = videoIsMuted
        if !self.values.collage.isEmpty {
            for player in self.additionalPlayers {
                player.isMuted = videoIsMuted
            }
        }
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedVideoIsMuted(videoIsMuted)
        }
    }
    
    public func setVideoVolume(_ volume: CGFloat?) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedVideoVolume(volume)
        }
        
        let audioMix: AVMutableAudioMix
        if let current = self.playerAudioMix {
            audioMix = current
        } else {
            audioMix = AVMutableAudioMix()
            self.playerAudioMix = audioMix
        }
        if let asset = self.player?.currentItem?.asset {
            let audioMixInputParameters = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first)
            audioMixInputParameters.setVolume(Float(volume ?? 1.0), at: .zero)
            audioMix.inputParameters = [audioMixInputParameters]
            self.player?.currentItem?.audioMix = audioMix
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
    
    public func setNightTheme(_ nightTheme: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedNightTheme(nightTheme)
        }
        
        guard let (dayImage, nightImage) = self.wallpapersValue, let nightImage else {
            return
        }
        
        if let textureSource = self.renderer.textureSource as? UniversalTextureSource {
            if nightTheme {
                textureSource.setMainInput(.image(nightImage, nil, 1.0, .zero))
            } else {
                textureSource.setMainInput(.image(dayImage, nil, 1.0, .zero))
            }
        }
    }
    
    public func toggleNightTheme() {
        self.setNightTheme(!self.values.nightTheme)
    }
    
    public enum PlaybackAction {
        case play
        case pause
        case seek(Double)
    }
    
    public var onPlaybackAction: (PlaybackAction) -> Void = { _ in }
    
    public var currentPosition: CMTime {
        return self.player?.currentTime() ?? .zero
    }
    
    private var initialSeekPosition: Double?
    private var targetTimePosition: (CMTime, Bool)?
    private var updatingTimePosition = false
    public func seek(_ position: Double, andPlay play: Bool) {
        if self.player == nil && self.additionalPlayers.isEmpty && self.audioPlayer == nil {
            self.initialSeekPosition = position
            return
        }
        self.renderer.setRate(1.0)
        if !play {
            self.player?.pause()
            self.additionalPlayers.forEach { $0.pause() }
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
                            
            if self.player == nil && self.additionalPlayers.isEmpty {
                self.audioPlayer?.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero)
                self.audioPlayer?.play()
            } else {
                if let _ = self.additionalPlayers.first {
                    if self.player != nil {
                        var index: Int32 = 0
                        for additionalPlayer in self.additionalPlayers {
                            let videoTime = self.videoTime(for: targetPosition, playerId: index)
                            if let videoDelay = self.videoDelay(for: targetPosition, playerId: index) {
                                self.videoDelayTimer[index] = SwiftSignalKit.Timer(timeout: videoDelay, repeat: false, completion: { [weak additionalPlayer] in
                                    additionalPlayer?.seek(to: videoTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                    additionalPlayer?.play()
                                }, queue: Queue.mainQueue())
                                self.videoDelayTimer[index]?.start()
                            } else {
                                additionalPlayer.seek(to: videoTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                additionalPlayer.play()
                            }
                            index += 1
                        }
                    } else {
                        self.additionalPlayers.forEach { $0.play() }
                    }
                }
                
                if let _ = self.audioPlayer {
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
                }
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
        self.additionalPlayers.forEach { $0.pause() }
        self.audioPlayer?.pause()
        
        let targetPosition = CMTime(seconds: position, preferredTimescale: CMTimeScale(1000.0))
        player.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: {  _ in
            Queue.mainQueue().async {
                completion()
            }
        })
        
        var index: Int32 = 0
        for player in self.additionalPlayers {
            if let _ = self.videoDelay(for: targetPosition, playerId: index) {
            } else {
                player.seek(to: self.videoTime(for: targetPosition, playerId: index), toleranceBefore: .zero, toleranceAfter: .zero)
            }
            index += 1
        }
                        
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
        var videoStart: Double = 0.0
        if self.player != nil {
            videoStart = self.values.videoTrimRange?.lowerBound ?? 0.0
        } else if !self.additionalPlayers.isEmpty {
            videoStart = self.values.additionalVideoTrimRange?.lowerBound ?? 0.0
        }
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
    
    private var videoDelayTimer: [Int32: SwiftSignalKit.Timer] = [:]
    private func videoDelay(for time: CMTime, playerId: Int32?) -> Double? {
        let playerId = self.values.collage.isEmpty ? nil : playerId
        
        var time = time
        if time == .invalid {
            time = .zero
        }
        let mainStart = self.values.videoTrimRange?.lowerBound ?? 0.0
        var trackStart: Double
        if let playerId {
            let trackId = playerId + 1
            if let collageIndex = self.collageItemIndexForTrackId(trackId) {
                trackStart = self.values.collage[collageIndex].videoTrimRange?.lowerBound ?? 0.0
                if let offset = self.values.collage[collageIndex].videoOffset, offset < 0.0 {
                    trackStart -= offset
                }
            } else {
                trackStart = 0.0
            }
        } else {
            trackStart = self.values.additionalVideoTrimRange?.lowerBound ?? 0.0
            if let offset = self.values.additionalVideoOffset, offset < 0.0 {
                trackStart -= offset
            }
        }
        if trackStart - mainStart > 0.0 {
            let delay = trackStart - time.seconds
            if delay > 0 {
                return delay
            }
        }
        return nil
    }
    
    private func videoTime(for time: CMTime, playerId: Int32?) -> CMTime {
        let playerId = self.values.collage.isEmpty ? nil : playerId
        
        var time = time
        if time == .invalid {
            time = .zero
        }
        let seconds = time.seconds
        
        let offset: Double
        let trackStart: Double
        if let playerId {
            let trackId = playerId + 1
            if let collageIndex = self.collageItemIndexForTrackId(trackId) {
                offset = self.values.collage[collageIndex].videoOffset ?? 0.0
                trackStart = self.values.collage[collageIndex].videoTrimRange?.lowerBound ?? 0.0
            } else {
                offset = 0.0
                trackStart = 0.0
            }
        } else {
            offset = self.values.additionalVideoOffset ?? 0.0
            trackStart = self.values.additionalVideoTrimRange?.lowerBound ?? 0.0
        }
        
        let trackOffset = max(0.0, offset)
        if seconds < trackStart - min(0.0, offset) {
            return CMTime(seconds: trackOffset + trackStart, preferredTimescale: CMTimeScale(1000.0))
        } else {
            return CMTime(seconds: trackOffset + seconds + min(0.0, offset), preferredTimescale: CMTimeScale(1000.0))
        }
    }
        
    public var isPlaying: Bool {
        var effectivePlayer: AVPlayer?
        if let player = self.player {
            effectivePlayer = player
        } else if let additionalPlayer = self.additionalPlayers.first {
            effectivePlayer = additionalPlayer
        } else if let audioPlayer = self.audioPlayer {
            effectivePlayer = audioPlayer
        }
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
        self.play(isInternal: false)
    }
    
    public func stop() {
        self.stop(isInternal: false)
    }
    
    private func play(isInternal: Bool) {
        if !isInternal {
            self.wasPlaying = false
        }
        self.setRate(1.0)
    }
    
    private func stop(isInternal: Bool) {
        if !isInternal {
            self.wasPlaying = false
        }
        self.setRate(0.0)
    }
    
    public var mainFramerate: Float? {
        if let player = self.player, let asset = player.currentItem?.asset, let track = asset.tracks(withMediaType: .video).first {
            if track.nominalFrameRate > 0.0 {
                return track.nominalFrameRate
            } else if track.minFrameDuration.seconds > 0.0 {
                return Float(1.0 / track.minFrameDuration.seconds)
            }
        }
        return nil
    }
    
    private func setRate(_ rate: Float) {
        let hostTime: UInt64 = mach_absolute_time()
        let time: TimeInterval = 0
        let cmHostTime = CMClockMakeHostTimeFromSystemUnits(hostTime)
        let cmVTime = CMTimeMakeWithSeconds(time, preferredTimescale: 1000000)
        let futureTime = CMTimeAdd(cmHostTime, cmVTime)
        
        if self.player == nil && self.additionalPlayers.isEmpty, let audioPlayer = self.audioPlayer {
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
            var itemTime = self.player?.currentItem?.currentTime() ?? .invalid
            self.player?.setRate(rate, time: itemTime, atHostTime: futureTime)
            
            if let additionalPlayer = self.additionalPlayers.first {
                if self.player != nil {
                    var index: Int32 = 0
                    for additionalPlayer in self.additionalPlayers {
                        let videoTime = self.videoTime(for: itemTime, playerId: index)
                        if rate > 0.0 {
                            if let videoDelay = self.videoDelay(for: itemTime, playerId: index) {
                                self.videoDelayTimer[index] = SwiftSignalKit.Timer(timeout: videoDelay, repeat: false, completion: { [weak additionalPlayer] in
                                    additionalPlayer?.seek(to: videoTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                    additionalPlayer?.play()
                                }, queue: Queue.mainQueue())
                                self.videoDelayTimer[index]?.start()
                            } else {
                                if additionalPlayer.status == .readyToPlay {
                                    additionalPlayer.setRate(rate, time: videoTime, atHostTime: futureTime)
                                    additionalPlayer.play()
                                } else {
                                    additionalPlayer.seek(to: videoTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                    additionalPlayer.play()
                                }
                            }
                        } else {
                            additionalPlayer.pause()
                        }
                        index += 1
                    }
                } else {
                    itemTime = additionalPlayer.currentItem?.currentTime() ?? .invalid
                    if itemTime != .invalid {
                        if additionalPlayer.status == .readyToPlay {
                            additionalPlayer.setRate(rate, time: itemTime, atHostTime: futureTime)
                        } else {
                            additionalPlayer.seek(to: itemTime, toleranceBefore: .zero, toleranceAfter: .zero)
                            if rate > 0.0 {
                                additionalPlayer.play()
                            } else {
                                additionalPlayer.pause()
                            }
                        }
                    }
                }
            }
            
            if let audioPlayer = self.audioPlayer {
                let audioTime = self.audioTime(for: itemTime)
                if rate > 0.0 {
                    if let audioDelay = self.audioDelay(for: itemTime) {
                        self.audioDelayTimer = SwiftSignalKit.Timer(timeout: audioDelay, repeat: false, completion: { [weak self] in
                            self?.audioPlayer?.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                            self?.audioPlayer?.play()
                        }, queue: Queue.mainQueue())
                        self.audioDelayTimer?.start()
                    } else {
                        if audioPlayer.status == .readyToPlay {
                            audioPlayer.setRate(rate, time: audioTime, atHostTime: futureTime)
                            audioPlayer.play()
                        } else {
                            audioPlayer.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                            audioPlayer.play()
                        }
                    }
                } else {
                    audioPlayer.pause()
                }
            }
        }
        
        self.renderer.setRate(rate)
        if rate > 0.0 {
            self.onPlaybackAction(.play)
        } else {
            self.onPlaybackAction(.pause)
            
            self.videoDelayTimer.values.forEach { $0.invalidate() }
            self.videoDelayTimer = [:]
            
            self.audioDelayTimer?.invalidate()
            self.audioDelayTimer = nil
        }
    }
    
    public func invalidate() {
        self.player?.pause()
        self.additionalPlayers.forEach { $0.pause() }
        self.audioPlayer?.pause()
        self.onPlaybackAction(.pause)
        self.renderer.textureSource?.invalidate()
        
        self.audioDelayTimer?.invalidate()
        self.audioDelayTimer = nil
        
        self.videoDelayTimer.values.forEach { $0.invalidate() }
        self.videoDelayTimer = [:]
    }
    
    private func updateVideoTimePosition() {
        guard let (targetPosition, _) = self.targetTimePosition else {
            return
        }
        self.updatingTimePosition = true
        
        if self.player == nil && self.additionalPlayers.isEmpty, let audioPlayer = self.audioPlayer {
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
            
            if let additionalPlayer = self.additionalPlayers.first {
                if self.player != nil {
                    var index: Int32 = 0
                    for additionalPlayer in self.additionalPlayers {
                        if let _ = self.videoDelay(for: targetPosition, playerId: index) {
                        } else {
                            additionalPlayer.seek(to: self.videoTime(for: targetPosition, playerId: index), toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                        index += 1
                    }
                } else {
                    additionalPlayer.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] _ in
                        if let self {
                            if let (currentTargetPosition, _) = self.targetTimePosition, currentTargetPosition == targetPosition {
                                self.updatingTimePosition = false
                                self.targetTimePosition = nil
                            } else {
                                self.updateVideoTimePosition()
                            }
                        }
                    })
                }
            }
                        
            if let _ = self.audioDelay(for: targetPosition) {
            } else {
                self.audioPlayer?.seek(to: self.audioTime(for: targetPosition), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        self.onPlaybackAction(.seek(targetPosition.seconds))
    }
    
    public func setVideoTrimRange(_ trimRange: Range<Double>, apply: Bool) {
        self.updateValues(mode: .skipRendering) { values in
            var updatedValues = values.withUpdatedVideoTrimRange(trimRange)
            if let coverImageTimestamp = updatedValues.coverImageTimestamp {
                if coverImageTimestamp < trimRange.lowerBound {
                    updatedValues = updatedValues.withUpdatedCoverImageTimestamp(trimRange.lowerBound)
                } else if coverImageTimestamp > trimRange.upperBound {
                    updatedValues = updatedValues.withUpdatedCoverImageTimestamp(trimRange.upperBound)
                }
            }
            return updatedValues
        }
        
        if apply {
            self.player?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
//            self.additionalPlayer?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
        }
    }
    
    public func setupCollage(_ items: [MediaEditor.Subject.VideoCollageItem]) {
        let longestItem = longestCollageItem(items)
        var collage: [MediaEditorValues.VideoCollageItem] = []
        
        var index = 0
        var passedFirstVideo = false
        var mainVideoIsMuted = false
        
        for item in items {
            var content: MediaEditorValues.VideoCollageItem.Content
            var isVideo = false
            if item.content == longestItem?.content {
                content = .main
                isVideo = true
            } else {
                switch item.content {
                case let .image(image):
                    let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).jpg"
                    if let data = image.jpegData(compressionQuality: 0.85) {
                        try? data.write(to: URL(fileURLWithPath: tempImagePath))
                    }
                    content = .imageFile(path: tempImagePath)
                case let .video(path, _):
                    content = .videoFile(path: path)
                    isVideo = true
                case let .asset(asset):
                    content = .asset(localIdentifier: asset.localIdentifier, isVideo: asset.mediaType == .video)
                    isVideo = asset.mediaType == .video
                }
            }
            let item = MediaEditorValues.VideoCollageItem(
                content: content,
                frame: item.frame,
                contentScale: item.contentScale,
                contentOffset: item.contentOffset,
                videoTrimRange: 0 ..< item.duration,
                videoOffset: nil,
                videoVolume: passedFirstVideo ? 0.0 : nil
            )
            collage.append(item)
            if isVideo {
                passedFirstVideo = true
            }
            index += 1
            
            if item.content == .main, let videoVolume = item.videoVolume, videoVolume.isZero {
                mainVideoIsMuted = true
            }
        }
        
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedCollage(collage)
        }
        
        if mainVideoIsMuted {
            Queue.mainQueue().after(0.3) {
                self.setVideoVolume(0.0)
            }
        }
                
        self.setupAdditionalVideoPlayback()
        self.updateAdditionalVideoPlaybackRange()
    }
    
    public func setAdditionalVideo(_ path: String?, isDual: Bool = false, positionChanges: [VideoPositionChange]) {
        self.updateValues(mode: .skipRendering) { values in
            var values = values.withUpdatedAdditionalVideo(path: path, isDual: isDual, positionChanges: positionChanges)
            if path == nil {
                values = values.withUpdatedAdditionalVideoOffset(nil).withUpdatedAdditionalVideoTrimRange(nil).withUpdatedAdditionalVideoVolume(nil)
            }
            return values
        }
        
        if !self.additionalPlayers.isEmpty {
            self.additionalPlayers.forEach { $0.pause() }
            self.additionalPlayers = []
            self.additionalPlayersPromise.set(.single([]))
            self.additionalPlayerAudioMixes = []
            
            if let textureSource = self.renderer.textureSource as? UniversalTextureSource {
                textureSource.forceUpdates = true
                self.renderer.videoFinishPass.animateAdditionalRemoval { [weak textureSource] in
                    if let textureSource {
                        textureSource.setAdditionalInputs([])
                        textureSource.forceUpdates = false
                    }
                }
            }
            
            self.videoDelayTimer.values.forEach { $0.invalidate() }
            self.videoDelayTimer = [:]
            
            if self.player == nil {
                self.invalidateTimeObservers()
            }
        }
        
        self.setupAdditionalVideoPlayback()
        self.updateAdditionalVideoPlaybackRange()
        
        if self.player == nil {
            self.invalidateTimeObservers()
            self.setupTimeObservers()
            self.additionalPlayers.forEach { $0.play() }
        }
    }
    
    private func setupAdditionalVideoPlayback() {
        if !self.values.collage.isEmpty {
            var signals: [Signal<(UniversalTextureSource.Input, AVPlayer?, CGFloat?), NoError>] = []
            for item in self.values.collage {
                switch item.content {
                case .main:
                    break
                case let .imageFile(path):
                    if let image = UIImage(contentsOfFile: path) {
                        signals.append(.single((.image(image, item.frame, item.contentScale, item.contentOffset), nil, nil)))
                    }
                case let .videoFile(path):
                    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                    let player = self.makePlayer(asset: asset)
                    if let playerItem = player.currentItem {
                        signals.append(.single((.video(playerItem, item.frame, item.contentScale, item.contentOffset), player, item.videoVolume)))
                    }
                case let .asset(localIdentifier, _):
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
                    if fetchResult.count != 0 {
                        let asset = fetchResult.object(at: 0)
                        signals.append(Signal { subscriber in
                            let options = PHVideoRequestOptions()
                            options.isNetworkAccessAllowed = true
                            options.deliveryMode = .highQualityFormat
            
                            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: { [weak self] avAsset, _, _ in
                                guard let self, let avAsset else {
                                    subscriber.putCompletion()
                                    return
                                }
                                let player = self.makePlayer(asset: avAsset)
                                if let playerItem = player.currentItem {
                                    subscriber.putNext((.video(playerItem, item.frame, item.contentScale, item.contentOffset), player, item.videoVolume))
                                }
                                subscriber.putCompletion()
                            })
                            
                            return EmptyDisposable
                        })
                    }
                }
            }
            
            let _ = (combineLatest(signals)
            |> deliverOnMainQueue).start(next: { [weak self] results in
                guard let self else {
                    return
                }
                var additionalInputs: [UniversalTextureSource.Input] = []
                var additionalPlayers: [AVPlayer] = []
                var audioMixes: [AVMutableAudioMix] = []
                
                for (input, player, volume) in results {
                    additionalInputs.append(input)
                    if let player {
                        additionalPlayers.append(player)
                        
                        if let asset = player.currentItem?.asset {
                            let audioMix = AVMutableAudioMix()
                            let audioMixInputParameters = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first)
                            if let volume {
                                audioMixInputParameters.setVolume(Float(volume), at: .zero)
                            }
                            audioMix.inputParameters = [audioMixInputParameters]
                            player.currentItem?.audioMix = audioMix
                            audioMixes.append(audioMix)
                        }
                    }
                }
                
                self.additionalPlayers = additionalPlayers
                self.additionalPlayersPromise.set(.single(additionalPlayers))
                self.additionalPlayerAudioMixes = audioMixes
                
                (self.renderer.textureSource as? UniversalTextureSource)?.setAdditionalInputs(additionalInputs)
                
                for player in additionalPlayers {
                    player.play()
                }
                
                if let asset = self.player?.currentItem?.asset {
                    self.maybeGenerateAudioSamples(asset: asset, collage: true)
                }
            })
        } else if let additionalVideoPath = self.values.additionalVideoPath {
            let asset = AVURLAsset(url: URL(fileURLWithPath: additionalVideoPath))
            let player = self.makePlayer(asset: asset)
            guard let playerItem = player.currentItem else {
                return
            }
                        
            let audioMix = AVMutableAudioMix()
            let audioMixInputParameters = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first)
            if let volume = self.values.additionalVideoVolume {
                audioMixInputParameters.setVolume(Float(volume), at: .zero)
            }
            audioMix.inputParameters = [audioMixInputParameters]
            player.currentItem?.audioMix = audioMix
            
            self.additionalPlayers = [player]
            self.additionalPlayersPromise.set(.single([player]))
            self.additionalPlayerAudioMixes = [audioMix]
            
            (self.renderer.textureSource as? UniversalTextureSource)?.setAdditionalInputs([.video(playerItem, nil, 1.0, .zero)])
        }
    }
    
    public func collageItemIndexForTrackId(_ trackId: Int32) -> Int? {
        var trackIdToIndex: [Int32: Int] = [:]
        
        var index = 0
        var trackIndex: Int32 = 0
        for item in self.values.collage {
            if case .main = item.content {
                trackIdToIndex[0] = index
            } else {
                if item.content.isVideo {
                    trackIndex += 1
                    trackIdToIndex[trackIndex] = index
                }
            }
            index += 1
        }
        
        return trackIdToIndex[trackId]
                
//        var collageIndex = -1
//        var trackIndex = -1
//        for item in self.values.collage {
//            if case .main = item.content {
//                trackIndex += 1
//            } else if case .videoFile = item.content {
//                trackIndex += 1
//            } else if case .asset(_, true) = item.content {
//                trackIndex += 1
//            }
//            collageIndex += 1
//            
//            if trackIndex == trackId {
//                return collageIndex
//            }
//        }
//        return nil
    }
    
    public func playerIndexForTrackId(_ trackId: Int32) -> Int? {
        let index = trackId - 1
        if index >= self.additionalPlayers.count {
            return nil
        }
        return Int(index)
    }
    
    public func setAdditionalVideoPosition(_ position: CGPoint, scale: CGFloat, rotation: CGFloat) {
        self.updateValues(mode: .forceRendering) { values in
            return values.withUpdatedAdditionalVideo(position: position, scale: scale, rotation: rotation)
        }
    }
    
    public func setAdditionalVideoTrimRange(_ trimRange: Range<Double>, trackId: Int32? = nil, apply: Bool) {
        if let trackId {
            if let index = self.collageItemIndexForTrackId(trackId) {
                self.updateValues(mode: .generic) { values in
                    var updatedCollage = values.collage
                    updatedCollage[index] = values.collage[index].withUpdatedVideoTrimRange(trimRange)
                    return values.withUpdatedCollage(updatedCollage)
                }
            }
        } else {
            self.updateValues(mode: .generic) { values in
                return values.withUpdatedAdditionalVideoTrimRange(trimRange)
            }
        }
        
        if apply {
            self.updateAdditionalVideoPlaybackRange()
        }
    }
    
    public func setAdditionalVideoOffset(_ offset: Double?, trackId: Int32? = nil, apply: Bool) {
        if let trackId {
            if let index = self.collageItemIndexForTrackId(trackId) {
                self.updateValues(mode: .generic) { values in
                    var updatedCollage = values.collage
                    updatedCollage[index] = values.collage[index].withUpdatedVideoOffset(offset)
                    return values.withUpdatedCollage(updatedCollage)
                }
            }
        } else {
            self.updateValues(mode: .generic) { values in
                return values.withUpdatedAdditionalVideoOffset(offset)
            }
        }
        
        if apply {
            self.updateAdditionalVideoPlaybackRange()
        }
    }
    
    public func setAdditionalVideoVolume(_ volume: CGFloat?, trackId: Int32? = nil) {
        if let trackId {
            if let index = self.collageItemIndexForTrackId(trackId) {
                self.updateValues(mode: .generic) { values in
                    var updatedCollage = values.collage
                    updatedCollage[index] = values.collage[index].withUpdatedVideoVolume(volume)
                    return values.withUpdatedCollage(updatedCollage)
                }
            }
        } else {
            self.updateValues(mode: .skipRendering) { values in
                return values.withUpdatedAdditionalVideoVolume(volume)
            }
        }
        
        if let trackId {
            if let index = self.playerIndexForTrackId(trackId), index < self.additionalPlayerAudioMixes.count && index < self.additionalPlayers.count, let asset = self.additionalPlayers[index].currentItem?.asset {
                let audioMix = self.additionalPlayerAudioMixes[index]
                let audioMixInputParameters = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first)
                audioMixInputParameters.setVolume(Float(volume ?? 1.0), at: .zero)
                audioMix.inputParameters = [audioMixInputParameters]
                self.additionalPlayers[index].currentItem?.audioMix = audioMix
            }
        } else {
            if let audioMix = self.additionalPlayerAudioMixes.first, let asset = self.additionalPlayers.first?.currentItem?.asset {
                let audioMixInputParameters = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first)
                audioMixInputParameters.setVolume(Float(volume ?? 1.0), at: .zero)
                audioMix.inputParameters = [audioMixInputParameters]
                self.additionalPlayers.first?.currentItem?.audioMix = audioMix
            }
        }
    }
    
    private func updateAdditionalVideoPlaybackRange() {
        if !self.values.collage.isEmpty {
            var trackId: Int32 = 0
            for player in self.additionalPlayers {
                if let index = self.collageItemIndexForTrackId(trackId), let upperBound = self.values.collage[index].videoTrimRange?.upperBound {
                    let offset = max(0.0, self.values.collage[index].videoOffset ?? 0.0)
                    player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: offset + upperBound, preferredTimescale: CMTimeScale(1000))
                } else {
                    player.currentItem?.forwardPlaybackEndTime = .invalid
                }
                trackId += 1
            }
        }
        if let upperBound = self.values.additionalVideoTrimRange?.upperBound {
            let offset = max(0.0, self.values.additionalVideoOffset ?? 0.0)
            self.additionalPlayers.first?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: offset + upperBound, preferredTimescale: CMTimeScale(1000))
        } else {
            self.additionalPlayers.first?.currentItem?.forwardPlaybackEndTime = .invalid
        }
    }
        
    public func setAudioTrack(_ audioTrack: MediaAudioTrack?, trimRange: Range<Double>? = nil, offset: Double? = nil) {
        self.updateValues(mode: .skipRendering) { values in
            return values
                .withUpdatedAudioTrack(audioTrack)
                .withUpdatedAudioTrackSamples(nil)
                .withUpdatedAudioTrackTrimRange(trimRange)
                .withUpdatedAudioTrackVolume(nil)
                .withUpdatedAudioTrackOffset(offset)
        }
        
        if let audioPlayer = self.audioPlayer {
            audioPlayer.pause()
            
            self.audioPlayer = nil
            self.audioPlayerPromise.set(.single(nil))
            self.audioPlayerAudioMix = nil
            
            self.audioDelayTimer?.invalidate()
            self.audioDelayTimer = nil
            
            if self.player == nil {
                self.invalidateTimeObservers()
            }
        }
        
        self.setupAudioPlayback()
        self.updateAudioPlaybackRange()
    }
    
    private func setupAudioPlayback() {
        guard let audioTrack = self.values.audioTrack else {
            return
        }
        let audioPath = fullDraftPath(peerId: self.context.account.peerId, path: audioTrack.path)
        let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
        let audioPlayer = AVPlayer(playerItem: AVPlayerItem(asset: audioAsset))
        audioPlayer.automaticallyWaitsToMinimizeStalling = false
        
        let audioMix = AVMutableAudioMix()
        let audioMixInputParameters = AVMutableAudioMixInputParameters(track: audioAsset.tracks(withMediaType: .audio).first)
        if let volume = self.values.audioTrackVolume {
            audioMixInputParameters.setVolume(Float(volume), at: .zero)
        }
        audioMix.inputParameters = [audioMixInputParameters]
        audioPlayer.currentItem?.audioMix = audioMix
        
        self.audioPlayer = audioPlayer
        self.audioPlayerPromise.set(.single(audioPlayer))
        self.audioPlayerAudioMix = audioMix
        self.maybeGenerateAudioSamples(asset: audioAsset, collage: false)
        
        self.setupTimeObservers()
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
        
        if let audioMix = self.audioPlayerAudioMix, let asset = self.audioPlayer?.currentItem?.asset {
            let audioMixInputParameters = AVMutableAudioMixInputParameters(track: asset.tracks(withMediaType: .audio).first)
            audioMixInputParameters.setVolume(Float(volume ?? 1.0), at: .zero)
            audioMix.inputParameters = [audioMixInputParameters]
            self.audioPlayer?.currentItem?.audioMix = audioMix
        }
    }
    
    public func setCoverImageTimestamp(_ coverImageTimestamp: Double?) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedCoverImageTimestamp(coverImageTimestamp)
        }
    }
    
    public func setCoverDimensions(_ coverDimensions: CGSize?) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedCoverDimensions(coverDimensions)
        }
    }
    
    public func setDrawingAndEntities(data: Data?, image: UIImage?, entities: [CodableDrawingEntity]) {
        self.updateValues(mode: .skipRendering) { values in
            return values.withUpdatedDrawingAndEntities(drawing: image, entities: entities)
        }
    }
    
    public func setGradientColors(_ gradientColors: GradientColors) {
        self.gradientColorsPromise.set(.single(gradientColors))
        self.updateValues(mode: self.sourceIsVideo ? .skipRendering : .generic) { values in
            return values.withUpdatedGradientColors(gradientColors: gradientColors.array)
        }
    }
    
    private var previousUpdateTime: Double?
    private var scheduledUpdate = false
    private func updateRenderChain() {
        self.renderer.skipEditingPasses = self.previewUnedited
        self.renderChain.update(values: self.values)
        self.renderer.videoFinishPass.update(values: self.values, videoDuration: self.mainVideoDuration, additionalVideoDuration: self.additionalVideoDuration)
        
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
    
    private var mainInputMask: MTLTexture?
    public func removeSegmentationMask() {        
        self.mainInputMask = nil
        self.renderer.currentMainInputMask = nil
        if !self.skipRendering {
            self.updateRenderChain()
        }
    }
    
    public func setSegmentationMask(_ image: UIImage, andEnable enable: Bool = false) {
        guard let renderTarget = self.previewView, let device = renderTarget.mtlDevice else {
            return
        }
        
        //TODO:replace with pixelbuffer?
        self.mainInputMask = loadTexture(image: image, device: device)
        if enable {
            self.isSegmentationMaskEnabled = true
        }
        self.renderer.currentMainInputMask = self.isSegmentationMaskEnabled ? self.mainInputMask : nil
        if !self.skipRendering {
            self.updateRenderChain()
        }
    }
    
    public var isSegmentationMaskEnabled: Bool = true {
        didSet {
            self.renderer.currentMainInputMask = self.isSegmentationMaskEnabled ? self.mainInputMask : nil
            if !self.skipRendering {
                self.updateRenderChain()
            }
        }
    }
    
    
    public func processImage(with f: @escaping (UIImage, UIImage?) -> Void) {
        guard let textureSource = self.renderer.textureSource as? UniversalTextureSource, let image = textureSource.mainImage else {
            return
        }
        Queue.concurrentDefaultQueue().async {
            f(image, self.resultImage)
        }
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
    
    private func maybeGenerateAudioSamples(asset: AVAsset, collage: Bool) {
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
                        let samples = MediaAudioTrackSamples(samples: samplesData, peak: peak)
                        if collage {
                            return values.withUpdatedCollageTrackSamples(samples)
                        } else {
                            return values.withUpdatedAudioTrackSamples(samples)
                        }
                    }
                }
            } catch {
            }
        }
    }
    
    private func makePlayer(asset: AVAsset) -> AVPlayer {
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        if #available(iOS 15.0, *) {
            player.sourceClock = clock
        } else {
            player.masterClock = clock
        }
        player.automaticallyWaitsToMinimizeStalling = false
        return player
    }

}

public func videoFrames(asset: AVAsset?, count: Int, initialPlaceholder: UIImage? = nil, initialTimestamp: Double? = nil, mirror: Bool = false) -> Signal<([UIImage], Double), NoError> {
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
   
   
    var firstFrame: UIImage

    var imageGenerator: AVAssetImageGenerator?
    if let asset {
        let scale = UIScreen.main.scale
        
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator?.maximumSize = CGSize(width: 48.0 * scale, height: 36.0 * scale)
        imageGenerator?.appliesPreferredTrackTransform = true
        imageGenerator?.requestedTimeToleranceBefore = .zero
        imageGenerator?.requestedTimeToleranceAfter = .zero
    }
    
    if var initialPlaceholder {
        initialPlaceholder = generateScaledImage(image: initialPlaceholder, size: initialPlaceholder.size.aspectFitted(CGSize(width: 144.0, height: 144.0)), scale: 1.0)!
        if let blurred = blurredImage(initialPlaceholder) {
            firstFrame = blurred
        } else {
            firstFrame = initialPlaceholder
        }
    } else if let imageGenerator {
        if let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil) {
            firstFrame = UIImage(cgImage: cgImage)
            if let blurred = blurredImage(firstFrame) {
                firstFrame = blurred
            }
        } else {
            firstFrame = generateSingleColorImage(size: CGSize(width: 24.0, height: 36.0), color: .black)!
        }
    } else {
        firstFrame = generateSingleColorImage(size: CGSize(width: 24.0, height: 36.0), color: .black)!
    }
    
    if let asset {
        return Signal { subscriber in
            subscriber.putNext((Array(repeating: firstFrame, count: count), initialTimestamp ?? CACurrentMediaTime()))
            
            var timestamps: [NSValue] = []
            let duration = asset.duration.seconds
            let interval = duration / Double(count)
            for i in 0 ..< count {
                timestamps.append(NSValue(time: CMTime(seconds: Double(i) * interval, preferredTimescale: CMTimeScale(1000))))
            }
            
            var updatedFrames: [UIImage] = []
            imageGenerator?.generateCGImagesAsynchronously(forTimes: timestamps) { _, image, _, _, _ in
                if let image {
                    updatedFrames.append(UIImage(cgImage: image, scale: 1.0, orientation: mirror ? .upMirrored : .up))
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
                } else {
                    if let previous = updatedFrames.last {
                        updatedFrames.append(previous)
                    }
                }
            }
            
            return ActionDisposable {
                imageGenerator?.cancelAllCGImageGeneration()
            }
        }
    } else {
        var frames: [UIImage] = []
        for _ in 0 ..< count {
            frames.append(firstFrame)
        }
        return .single((frames, CACurrentMediaTime()))
    }
}

private func longestCollageItem(_ items: [MediaEditor.Subject.VideoCollageItem]) -> MediaEditor.Subject.VideoCollageItem? {
    var longestItem: MediaEditor.Subject.VideoCollageItem?
    for item in items {
        guard item.isVideo else {
            continue
        }
        if let current = longestItem {
            if item.duration > current.duration {
                longestItem = item
            }
        } else {
            longestItem = item
        }
    }
    return longestItem
}
