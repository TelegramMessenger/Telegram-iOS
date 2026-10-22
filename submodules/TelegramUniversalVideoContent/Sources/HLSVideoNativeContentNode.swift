import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramAudio
import UniversalMediaPlayer
import AccountContext
import UIKitRuntimeUtils
import RangeSet
import HLSPlayback

// Plays an adaptive (HLS) video with the native playback controller: qualities chosen per segment, cache first,
// every byte through MediaBox's own file contexts, parts rendered by ChunkMediaPlayerV2.
final class HLSVideoNativeContentNode: ASDisplayNode, UniversalVideoContentNode {
    private struct VideoQualityState: Equatable {
        var current: Int
        var preferred: UniversalVideoContentVideoQuality
        var available: [Int]
    }
    
    // The qualities of `file` in `HLSLevels.sorted` order, or nil when there is nothing to play adaptively.
    static func qualityFiles(file: FileMediaReference, codecConfiguration: HLSCodecConfiguration) -> (levels: [HLSLevel], files: [HLSNativeQualityFile])? {
        guard let qualitySet = HLSQualitySet(baseFile: file, codecConfiguration: codecConfiguration) else {
            return nil
        }
        var candidates: [(level: HLSLevel, file: FileMediaReference, playlist: FileMediaReference, size: Int64)] = []
        for (key, qualityFile) in qualitySet.qualityFiles {
            guard let playlistFile = qualitySet.playlistFiles[key], let size = qualityFile.media.size, size > 0 else {
                continue
            }
            let dimensions = qualityFile.media.dimensions?.cgSize ?? CGSize(width: 1280.0, height: 720.0)
            let bandwidth: Int
            if let duration = qualityFile.media.duration ?? file.media.duration, duration > 0.0 {
                bandwidth = Int(Double(size) / duration) * 8
            } else {
                bandwidth = 1_000_000
            }
            let level = HLSLevel(key: key, width: Int(dimensions.width), height: Int(dimensions.height), bandwidth: bandwidth)
            candidates.append((level, qualityFile, playlistFile, size))
        }
        if candidates.isEmpty {
            return nil
        }
        let levels = HLSLevels.sorted(candidates.map(\.level))
        var files: [HLSNativeQualityFile] = []
        for (index, level) in levels.enumerated() {
            guard let candidate = candidates.first(where: { $0.level == level }) else {
                return nil
            }
            files.append(HLSNativeQualityFile(level: index, file: candidate.file, playlistFile: candidate.playlist, size: candidate.size))
        }
        return (levels, files)
    }
    
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize
    private let captureProtected: Bool
    
    private var enableSound: Bool
    private var requestedBaseRate: Double
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    var isNativePictureInPictureActive: Signal<Bool, NoError> {
        return .single(false)
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let imageNode: TransformImageNode
    private let player: ChunkMediaPlayer
    private let playerNode: MediaPlayerNode
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
    private let levels: [HLSLevel]
    private let preloadLevel: Int
    private let partStore: HLSNativePartStore
    private let environment: HLSNativeEnvironment
    private let playlistLoader: HLSNativePlaylistLoader
    private let controller: HLSPlaybackController
    private let playerSource: HLSNativePlayerSource
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    private var videoQualityStateValue: VideoQualityState?
    private let videoQualityStatePromise = Promise<VideoQualityState?>(nil)
    private var lastPosition: Double = 0.0
    
    private var playerStatusDisposable: Disposable?
    private var connectionStatusDisposable: Disposable?
    
    private let startInitTime = CFAbsoluteTimeGetCurrent()
    private var startPlayTime: Double?
    private var didLogStart = false
    
    init(context: AccountContext, audioSessionManager: ManagedAudioSession, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, levels: [HLSLevel], qualityFiles: [HLSNativeQualityFile], loopVideo: Bool, enableSound: Bool, baseRate: Double, captureProtected: Bool, thumbnail: Signal<(() -> CGSize?, (TransformImageArguments) -> DrawingContext?), NoError>) {
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.captureProtected = captureProtected
        self.enableSound = enableSound
        self.requestedBaseRate = baseRate
        self.levels = levels
        self.preloadLevel = HLSLevels.preloadQualityKey(keys: levels.map(\.key)).flatMap({ key in levels.firstIndex(where: { $0.key == key }) }) ?? 0
        
        if var dimensions = fileReference.media.dimensions {
            if let thumbnail = fileReference.media.previewRepresentations.first {
                let dimensionsVertical = dimensions.width < dimensions.height
                let thumbnailVertical = thumbnail.dimensions.width < thumbnail.dimensions.height
                if dimensionsVertical != thumbnailVertical {
                    dimensions = PixelDimensions(width: dimensions.height, height: dimensions.width)
                }
            }
            self.dimensions = dimensions.cgSize
        } else {
            self.dimensions = CGSize(width: 128.0, height: 128.0)
        }
        
        let mediaDimensions = fileReference.media.dimensions?.cgSize ?? CGSize(width: 480.0, height: 320.0)
        var intrinsicDimensions = mediaDimensions.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
        intrinsicDimensions.width = floor(intrinsicDimensions.width / UIScreenScale)
        intrinsicDimensions.height = floor(intrinsicDimensions.height / UIScreenScale)
        self.intrinsicDimensions = intrinsicDimensions
        
        self.imageNode = TransformImageNode()
        self.playerNode = MediaPlayerNode(captureProtected: captureProtected)
        
        let engine = context.engine
        self.partStore = HLSNativePartStore(engine: engine, files: qualityFiles)
        self.environment = HLSNativeEnvironment(engine: engine, userLocation: userLocation, files: qualityFiles, partStore: self.partStore)
        self.playlistLoader = HLSNativePlaylistLoader(engine: engine, userLocation: userLocation, files: qualityFiles, startLevel: self.preloadLevel)
        self.controller = HLSPlaybackController(levels: levels, preloadLevel: self.preloadLevel, environment: self.environment)
        self.playerSource = HLSNativePlayerSource()
        
        self.player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(context: context),
            audioSessionManager: audioSessionManager,
            source: .custom(self.playerSource),
            video: true,
            enableSound: enableSound,
            baseRate: baseRate,
            playerNode: self.playerNode
        )
        
        super.init()
        
        if loopVideo {
            self.player.actionAtEnd = .loop(nil)
        }
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        
        var didProcessFramesToDisplay = false
        self.playerNode.isHidden = true
        self.playerNode.hasSentFramesToDisplay = { [weak self] in
            guard let self, !didProcessFramesToDisplay else {
                return
            }
            didProcessFramesToDisplay = true
            self.playerNode.isHidden = false
            self.logStartIfNeeded()
        }
        
        if captureProtected {
            setLayerDisableScreenshots(self.imageNode.layer, true)
        }
        self.imageNode.setSignal(thumbnail |> map { [weak self] getSize, getData in
            Queue.mainQueue().async {
                if let self, self.dimensions == nil {
                    if let dimensions = getSize() {
                        self.dimensions = dimensions
                        self.dimensionsPromise.set(dimensions)
                        if let validLayout = self.validLayout {
                            self.updateLayout(size: validLayout.size, actualSize: validLayout.actualSize, transition: .immediate)
                        }
                    }
                }
            }
            return getData
        })
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self._bufferingStatus.set(.single(nil))
        
        self.playerStatusDisposable = (self.player.status
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            self?._status.set(status)
        })
        
        let fileId = fileReference.media.fileId.id
        self.controller.onLog = { line in
            Logger.shared.log("HLSNative", "\(fileId): \(line)")
        }
        self.controller.onBufferChanged = { [weak self] parts, duration in
            self?.bufferChanged(parts: parts, duration: duration)
        }
        self.playlistLoader.onLog = { line in
            Logger.shared.log("HLSNative", "\(fileId): \(line)")
        }
        self.playlistLoader.onPlaylist = { [weak self] level, playlist in
            self?.controller.setPlaylist(playlist, level: level)
        }
        self.playlistLoader.onPlaylistUnavailable = { [weak self] level in
            self?.controller.setPlaylistUnavailable(level: level)
        }
        self.playlistLoader.onPlaylistRejected = { [weak self] level in
            self?.controller.setPlaylistRejected(level: level)
            self?.updateVideoQualityState()
        }
        self.playerSource.onSeek = { [weak self] position in
            guard let self else {
                return
            }
            self.lastPosition = position
            self.controller.seek(to: position)
        }
        self.playerSource.onPlaybackState = { [weak self] position, isPlaying in
            guard let self else {
                return
            }
            self.lastPosition = position
            self.controller.updatePlayback(position: position, isPlaying: isPlaying, rate: self.requestedBaseRate)
            self.updateVideoQualityState()
        }
        self.environment.onDiskStateKnown = { [weak self] in
            guard let self else {
                return
            }
            Logger.shared.log("HLSNative", "\(fileId): disk state known ms=\(Int((CFAbsoluteTimeGetCurrent() - self.startInitTime) * 1000.0))")
            self.controller.start()
        }
        self.connectionStatusDisposable = (context.account.network.connectionStatus
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            switch status {
            case .online, .updating:
                self?.controller.setNetworkAvailable(true)
            case .waitingForNetwork, .connecting:
                self?.controller.setNetworkAvailable(false)
            }
        })
        
        self.applyCap()
        self.playlistLoader.start()
        if self.environment.isDiskStateKnown {
            self.controller.start()
        }
        self.updateVideoQualityState()
    }
    
    deinit {
        self.controller.stop()
        self.playlistLoader.cancel()
        self.partStore.removeAll()
        self.playerStatusDisposable?.dispose()
        self.connectionStatusDisposable?.dispose()
    }
    
    // MARK: Controller
    
    private func bufferChanged(parts: [HLSBufferedPart], duration: Double?) {
        let playerParts = self.partStore.parts(for: parts)
        self.playerSource.partsPromise.set(.single(ChunkMediaPlayerPartsState(duration: duration, content: .parts(playerParts))))
        
        if let duration, duration > 0.0 {
            // Widened by 0.2 s each way, as the JavaScript player reported it; the scrubber reads only the ratio.
            var ranges = RangeSet<Int64>()
            for part in parts {
                let lower = max(0.0, part.start - 0.2)
                let upper = min(duration, part.end + 0.2)
                if lower < upper {
                    ranges.formUnion(RangeSet<Int64>(Int64(lower * 1000.0) ..< Int64(upper * 1000.0)))
                }
            }
            self._bufferingStatus.set(.single((ranges, Int64(duration * 1000.0))))
        }
        self.updateVideoQualityState()
    }
    
    // Without sound the video plays at most at the preload quality.
    private func applyCap() {
        self.controller.setCap(self.enableSound ? nil : self.preloadLevel)
    }
    
    // MARK: Start time
    
    private func notePlayRequested() {
        if self.startPlayTime == nil {
            self.startPlayTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    private func logStartIfNeeded() {
        if self.didLogStart {
            return
        }
        self.didLogStart = true
        
        let firstFrameTime = CFAbsoluteTimeGetCurrent()
        let initToPlayMs = self.startPlayTime.map { Int(($0 - self.startInitTime) * 1000.0) } ?? -1
        let playToFirstFrameMs = self.startPlayTime.map { Int((firstFrameTime - $0) * 1000.0) } ?? -1
        let initToFirstFrameMs = Int((firstFrameTime - self.startInitTime) * 1000.0)
        let startQuality = self.controller.firstSegmentLevel.map { "\(self.levels[$0].key)" } ?? "unknown"
        let firstSegment: String
        switch self.controller.firstSegmentSource {
        case .disk:
            firstSegment = "disk"
        case .network:
            firstSegment = "network"
        case .none:
            firstSegment = "unknown"
        }
        let line = "HLSStart file=\(self.fileReference.media.fileId.id) engine=native initToPlayMs=\(initToPlayMs) playToFirstFrameMs=\(playToFirstFrameMs) initToFirstFrameMs=\(initToFirstFrameMs) startQuality=\(startQuality) firstSegment=\(firstSegment) sound=\(self.enableSound ? 1 : 0)"
        Logger.shared.log("HLSStart", line)
        #if DEBUG
        NSLog("%@", line)
        #endif
    }
    
    // MARK: UniversalVideoContentNode
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, actualSize)
        
        transition.updatePosition(node: self.playerNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(node: self.playerNode, scale: size.width / self.intrinsicDimensions.width)
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if let dimensions = self.dimensions {
            let imageSize = CGSize(width: floor(dimensions.width / 2.0), height: floor(dimensions.height / 2.0))
            let makeLayout = self.imageNode.asyncLayout()
            let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
            applyLayout()
        }
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        self.notePlayRequested()
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: self.requestedBaseRate, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: self.enableSound))
        }
        self.player.play()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.togglePlayPause(faded: false)
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if self.enableSound != value {
            self.enableSound = value
            if value {
                self.player.playOnceWithSound(playAndRecord: false, seek: .none)
            } else {
                self.player.continuePlayingWithoutSound(seek: .none)
            }
            self.applyCap()
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        self.player.seek(timestamp: timestamp, play: nil)
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        self.notePlayRequested()
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        self.enableSound = true
        switch actionAtEnd {
        case .loop:
            self.player.actionAtEnd = .loop({})
        case .loopDisablingSound:
            self.player.actionAtEnd = .loopDisablingSound(action)
        case .stop:
            self.player.actionAtEnd = .action(action)
        case .repeatIfNeeded:
            let _ = (self.player.status
            |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] status in
                guard let self else {
                    return
                }
                if status.timestamp > status.duration * 0.1 {
                    self.player.actionAtEnd = .loop({ [weak self] in
                        guard let self else {
                            return
                        }
                        self.player.actionAtEnd = .loopDisablingSound(action)
                    })
                } else {
                    self.player.actionAtEnd = .loopDisablingSound(action)
                }
            })
        }
        
        self.player.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
        self.applyCap()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.player.setSoundMuted(soundMuted: soundMuted)
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
        self.player.continueWithOverridingAmbientMode(isAmbient: isAmbient)
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        assert(Queue.mainQueue().isCurrent())
        self.player.setForceAudioToSpeaker(forceAudioToSpeaker)
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        self.notePlayRequested()
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        self.enableSound = false
        switch actionAtEnd {
        case .loop:
            self.player.actionAtEnd = .loop({})
        case .loopDisablingSound, .repeatIfNeeded:
            self.player.actionAtEnd = .loopDisablingSound(action)
        case .stop:
            self.player.actionAtEnd = .action(action)
        }
        self.player.continuePlayingWithoutSound(seek: .none)
        self.applyCap()
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        self.player.setContinuePlayingWithoutSoundOnLostAudioSession(value)
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.requestedBaseRate = baseRate
        self.player.setBaseRate(baseRate)
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        switch videoQuality {
        case .auto:
            self.controller.setManualLevel(nil)
        case let .quality(quality):
            self.controller.setManualLevel(self.levels.firstIndex(where: { $0.key == quality }))
        }
        self.updateVideoQualityState()
    }
    
    private func updateVideoQualityState() {
        var videoQualityState: VideoQualityState?
        if let value = self.videoQualityState() {
            videoQualityState = VideoQualityState(current: value.current, preferred: value.preferred, available: value.available)
        }
        if self.videoQualityStateValue != videoQualityState {
            self.videoQualityStateValue = videoQualityState
            self.videoQualityStatePromise.set(.single(videoQualityState))
        }
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        if self.levels.isEmpty {
            return nil
        }
        let currentLevel = self.controller.level(at: self.lastPosition) ?? self.controller.startLevel ?? self.preloadLevel
        // Rejected levels are left out, unless every level is.
        var keys = self.levels.indices.filter({ !self.controller.isPlaylistRejected(level: $0) }).map({ self.levels[$0].key })
        if keys.isEmpty {
            keys = self.levels.map(\.key)
        }
        let available = Array(Set(keys)).sorted(by: { $0 > $1 })
        return (self.levels[currentLevel].key, self.preferredVideoQuality, available)
    }
    
    func videoQualityStateSignal() -> Signal<(current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])?, NoError> {
        return self.videoQualityStatePromise.get()
        |> map { value -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? in
            guard let value else {
                return nil
            }
            return (value.current, value.preferred, value.available)
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
    }
    
    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
        self.playerNode.setCanPlaybackWithoutHierarchy(canPlaybackWithoutHierarchy)
    }
    
    func enterNativePictureInPicture() -> Bool {
        return false
    }
    
    func exitNativePictureInPicture() {
    }
    
    func setNativePictureInPictureIsActive(_ value: Bool) {
        self.imageNode.isHidden = !value
    }
}
