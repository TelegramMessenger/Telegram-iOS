import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AVFoundation
import UniversalMediaPlayer
import TelegramAudio
import AccountContext
import PhotoResources
import RangeSet
import TelegramVoip
import ManagedFile
import WebKit
import AppBundle

public final class HLSQualitySet {
    public let qualityFiles: [Int: FileMediaReference]
    public let playlistFiles: [Int: FileMediaReference]
    
    public init?(baseFile: FileMediaReference) {
        var qualityFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        let _ = size
                        if let videoCodec, NativeVideoContent.isVideoCodecSupported(videoCodec: videoCodec) {
                            qualityFiles[Int(size.height)] = baseFile.withMedia(alternativeFile)
                        }
                    }
                }
            }
        }
        
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                if alternativeFile.mimeType == "application/x-mpegurl" {
                    if let fileName = alternativeFile.fileName {
                        if fileName.hasPrefix("mtproto:") {
                            let fileIdString = String(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...])
                            if let fileId = Int64(fileIdString) {
                                for (quality, file) in qualityFiles {
                                    if file.media.fileId.id == fileId {
                                        playlistFiles[quality] = baseFile.withMedia(alternativeFile)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if !playlistFiles.isEmpty && playlistFiles.keys == qualityFiles.keys {
            self.qualityFiles = qualityFiles
            self.playlistFiles = playlistFiles
        } else {
            return nil
        }
    }
}

public final class HLSVideoContent: UniversalVideoContent {
    public static func minimizedHLSQualityFile(file: FileMediaReference) -> FileMediaReference? {
        guard let qualitySet = HLSQualitySet(baseFile: file) else {
            return nil
        }
        for (quality, qualityFile) in qualitySet.qualityFiles.sorted(by: { $0.key < $1.key }) {
            if quality >= 400 {
                return qualityFile
            }
        }
        return nil
    }
    
    public let id: AnyHashable
    public let nativeId: PlatformVideoContentId
    let userLocation: MediaResourceUserLocation
    public let fileReference: FileMediaReference
    public let dimensions: CGSize
    public let duration: Double
    let streamVideo: Bool
    let loopVideo: Bool
    let enableSound: Bool
    let baseRate: Double
    let fetchAutomatically: Bool
    
    public init(id: PlatformVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true) {
        self.id = id
        self.userLocation = userLocation
        self.nativeId = id
        self.fileReference = fileReference
        self.dimensions = self.fileReference.media.dimensions?.cgSize ?? CGSize(width: 480, height: 320)
        self.duration = self.fileReference.media.duration ?? 0.0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
    }
    
    public func makeContentNode(accountId: AccountRecordId, postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        if #available(iOS 17.1, *) {
            return HLSVideoJSContentNode(accountId: accountId, postbox: postbox, audioSessionManager: audioSession, userLocation: self.userLocation, fileReference: self.fileReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically)
        } else {
            return HLSVideoAVContentNode(accountId: accountId, postbox: postbox, audioSessionManager: audioSession, userLocation: self.userLocation, fileReference: self.fileReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically)
        }
    }
    
    public func isEqual(to other: UniversalVideoContent) -> Bool {
        if let other = other as? HLSVideoContent {
            if case let .message(_, stableId, _) = self.nativeId {
                if case .message(_, stableId, _) = other.nativeId {
                    if self.fileReference.media.isInstantVideo {
                        return true
                    }
                }
            }
        }
        return false
    }
}

private final class HLSServerSource: SharedHLSServer.Source {
    let id: String
    let postbox: Postbox
    let userLocation: MediaResourceUserLocation
    let playlistFiles: [Int: FileMediaReference]
    let qualityFiles: [Int: FileMediaReference]
    
    private var playlistFetchDisposables: [Int: Disposable] = [:]
    
    init(accountId: Int64, fileId: Int64, postbox: Postbox, userLocation: MediaResourceUserLocation, playlistFiles: [Int: FileMediaReference], qualityFiles: [Int: FileMediaReference]) {
        self.id = "\(UInt64(bitPattern: accountId))_\(fileId)"
        self.postbox = postbox
        self.userLocation = userLocation
        self.playlistFiles = playlistFiles
        self.qualityFiles = qualityFiles
    }
    
    deinit {
        for (_, disposable) in self.playlistFetchDisposables {
            disposable.dispose()
        }
    }
    
    func arbitraryFileData(path: String) -> Signal<(data: Data, contentType: String)?, NoError> {
        return Signal { subscriber in
            if path == "index.html" {
                if let path = getAppBundle().path(forResource: "HLSVideoPlayer", ofType: "html"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    subscriber.putNext((data, "text/html"))
                } else {
                    subscriber.putNext(nil)
                }
            } else if path == "hls.js" {
                if let path = getAppBundle().path(forResource: "hls", ofType: "js"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    subscriber.putNext((data, "application/javascript"))
                } else {
                    subscriber.putNext(nil)
                }
            } else {
                subscriber.putNext(nil)
            }
            
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    func masterPlaylistData() -> Signal<String, NoError> {
        var playlistString: String = ""
        playlistString.append("#EXTM3U\n")
        
        for (quality, file) in self.qualityFiles.sorted(by: { $0.key > $1.key }) {
            let width = file.media.dimensions?.width ?? 1280
            let height = file.media.dimensions?.height ?? 720
            
            let bandwidth: Int
            if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                bandwidth = Int(Double(size) / duration) * 8
            } else {
                bandwidth = 1000000
            }
            
            playlistString.append("#EXT-X-STREAM-INF:BANDWIDTH=\(bandwidth),RESOLUTION=\(width)x\(height)\n")
            playlistString.append("hls_level_\(quality).m3u8\n")
        }
        return .single(playlistString)
    }
    
    func playlistData(quality: Int) -> Signal<String, NoError> {
        guard let playlistFile = self.playlistFiles[quality] else {
            return .never()
        }
        if self.playlistFetchDisposables[quality] == nil {
            self.playlistFetchDisposables[quality] = freeMediaFileResourceInteractiveFetched(postbox: self.postbox, userLocation: self.userLocation, fileReference: playlistFile, resource: playlistFile.media.resource).startStrict()
        }
        
        return self.postbox.mediaBox.resourceData(playlistFile.media.resource)
        |> filter { data in
            return data.complete
        }
        |> map { data -> String in
            guard data.complete else {
                return ""
            }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                return ""
            }
            guard var playlistString = String(data: data, encoding: .utf8) else {
                return ""
            }
            let partRegex = try! NSRegularExpression(pattern: "mtproto:([\\d]+)", options: [])
            let results = partRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
            for result in results.reversed() {
                if let range = Range(result.range, in: playlistString) {
                    if let fileIdRange = Range(result.range(at: 1), in: playlistString) {
                        let fileId = String(playlistString[fileIdRange])
                        playlistString.replaceSubrange(range, with: "partfile\(fileId).mp4")
                    }
                }
            }
            return playlistString
        }
    }
    
    func partData(index: Int, quality: Int) -> Signal<Data?, NoError> {
        return .never()
    }
    
    func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError> {
        guard let (quality, file) = self.qualityFiles.first(where: { $0.value.media.fileId.id == id }) else {
            return .single(nil)
        }
        let _ = quality
        guard let size = file.media.size else {
            return .single(nil)
        }
        
        let postbox = self.postbox
        let userLocation = self.userLocation
        
        let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
        
        let queue = postbox.mediaBox.dataQueue
        return Signal<(TempBoxFile, Range<Int>, Int)?, NoError> { subscriber in
            guard let fetchResource = postbox.mediaBox.fetchResource else {
                return EmptyDisposable
            }
            
            let location = MediaResourceStorageLocation(userLocation: userLocation, reference: file.resourceReference(file.media.resource))
            let params = MediaResourceFetchParameters(
                tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
                info: TelegramCloudMediaResourceFetchInfo(reference: file.resourceReference(file.media.resource), preferBackgroundReferenceRevalidation: true, continueInBackground: true),
                location: location,
                contentType: .video,
                isRandomAccessAllowed: true
            )
            
            let completeFile = TempBox.shared.tempFile(fileName: "data")
            let partialFile = TempBox.shared.tempFile(fileName: "data")
            let metaFile = TempBox.shared.tempFile(fileName: "data")
            
            guard let fileContext = MediaBoxFileContextV2Impl(
                queue: queue,
                manager: postbox.mediaBox.dataFileManager,
                storageBox: nil,
                resourceId: file.media.resource.id.stringRepresentation.data(using: .utf8)!,
                path: completeFile.path,
                partialPath: partialFile.path,
                metaPath: metaFile.path
            ) else {
                return EmptyDisposable
            }
            
            let fetchDisposable = fileContext.fetched(
                range: mappedRange,
                priority: .default,
                fetch: { intervals in
                    return fetchResource(file.media.resource, intervals, params)
                },
                error: { _ in
                },
                completed: {
                }
            )
            
            #if DEBUG
            let startTime = CFAbsoluteTimeGetCurrent()
            #endif
            
            let dataDisposable = fileContext.data(
                range: mappedRange,
                waitUntilAfterInitialFetch: true,
                next: { result in
                    if result.complete {
                        #if DEBUG
                        let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
                        print("Fetching \(quality)p part took \(fetchTime * 1000.0) ms")
                        #endif
                        subscriber.putNext((partialFile, Int(result.offset) ..< Int(result.offset + result.size), Int(size)))
                        subscriber.putCompletion()
                    }
                }
            )
            
            return ActionDisposable {
                queue.async {
                    fetchDisposable.dispose()
                    dataDisposable.dispose()
                    fileContext.cancelFullRangeFetches()
                    
                    TempBox.shared.dispose(completeFile)
                    TempBox.shared.dispose(metaFile)
                }
            }
        }
        |> runOn(queue)
    }
}

private final class HLSVideoAVContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
    private var baseRate: Double = 1.0
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private var playerSource: HLSServerSource?
    private var serverDisposable: Disposable?
    
    private let imageNode: TransformImageNode
    
    private var playerItem: AVPlayerItem?
    private var player: AVPlayer?
    private let playerNode: ASDisplayNode
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    private var failureObserverId: NSObjectProtocol?
    private var errorObserverId: NSObjectProtocol?
    private var playerItemFailedToPlayToEndTimeObserver: NSObjectProtocol?
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    init(accountId: AccountRecordId, postbox: Postbox, audioSessionManager: ManagedAudioSession, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.audioSessionManager = audioSessionManager
        self.userLocation = userLocation
        self.baseRate = baseRate
        
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
        
        self.imageNode = TransformImageNode()
        
        var player: AVPlayer?
        player = AVPlayer(playerItem: nil)
        self.player = player
        if #available(iOS 16.0, *) {
            player?.defaultRate = Float(baseRate)
        }
        if !enableSound {
            player?.volume = 0.0
        }
        
        self.playerNode = ASDisplayNode()
        self.playerNode.setLayerBlock({
            return AVPlayerLayer(player: player)
        })
        
        self.intrinsicDimensions = fileReference.media.dimensions?.cgSize ?? CGSize(width: 480.0, height: 320.0)
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        
        if let qualitySet = HLSQualitySet(baseFile: fileReference) {
            self.playerSource = HLSServerSource(accountId: accountId.int64, fileId: fileReference.media.fileId.id, postbox: postbox, userLocation: userLocation, playlistFiles: qualitySet.playlistFiles, qualityFiles: qualitySet.qualityFiles)
        }
        
        super.init()

        self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, userLocation: self.userLocation, videoReference: fileReference) |> map { [weak self] getSize, getData in
            Queue.mainQueue().async {
                if let strongSelf = self, strongSelf.dimensions == nil {
                    if let dimensions = getSize() {
                        strongSelf.dimensions = dimensions
                        strongSelf.dimensionsPromise.set(dimensions)
                        if let validLayout = strongSelf.validLayout {
                            strongSelf.updateLayout(size: validLayout.size, actualSize: validLayout.actualSize, transition: .immediate)
                        }
                    }
                }
            }
            return getData
        })
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self.player?.actionAtItemEnd = .pause
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        self._bufferingStatus.set(.single(nil))
        
        if let playerSource = self.playerSource {
            self.serverDisposable = SharedHLSServer.shared.registerPlayer(source: playerSource, completion: { [weak self] in
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    
                    let playerItem: AVPlayerItem
                    let assetUrl = "http://127.0.0.1:\(SharedHLSServer.shared.port)/\(playerSource.id)/master.m3u8"
                    #if DEBUG
                    print("HLSVideoAVContentNode: playing \(assetUrl)")
                    #endif
                    playerItem = AVPlayerItem(url: URL(string: assetUrl)!)
                    
                    if #available(iOS 14.0, *) {
                        playerItem.startsOnFirstEligibleVariant = true
                    }
                    
                    self.setPlayerItem(playerItem)
                }
            })
        }
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let strongSelf = self, let layer = strongSelf.playerNode.layer as? AVPlayerLayer else {
                return
            }
            layer.player = strongSelf.player
        })
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let strongSelf = self, let layer = strongSelf.playerNode.layer as? AVPlayerLayer else {
                return
            }
            layer.player = nil
        })
    }
    
    deinit {
        self.player?.removeObserver(self, forKeyPath: "rate")
        
        self.setPlayerItem(nil)
        
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.statusDisposable?.dispose()
        
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let willResignActiveObserver = self.willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
        if let failureObserverId = self.failureObserverId {
            NotificationCenter.default.removeObserver(failureObserverId)
        }
        if let errorObserverId = self.errorObserverId {
            NotificationCenter.default.removeObserver(errorObserverId)
        }
        
        self.serverDisposable?.dispose()
        
        self.statusTimer?.invalidate()
    }
    
    private func setPlayerItem(_ item: AVPlayerItem?) {
        if let playerItem = self.playerItem {
            playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            playerItem.removeObserver(self, forKeyPath: "playbackBufferFull")
            playerItem.removeObserver(self, forKeyPath: "status")
            playerItem.removeObserver(self, forKeyPath: "presentationSize")
        }
        
        if let playerItemFailedToPlayToEndTimeObserver = self.playerItemFailedToPlayToEndTimeObserver {
            self.playerItemFailedToPlayToEndTimeObserver = nil
            NotificationCenter.default.removeObserver(playerItemFailedToPlayToEndTimeObserver)
        }
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            self.didPlayToEndTimeObserver = nil
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
        if let failureObserverId = self.failureObserverId {
            self.failureObserverId = nil
            NotificationCenter.default.removeObserver(failureObserverId)
        }
        if let errorObserverId = self.errorObserverId {
            self.errorObserverId = nil
            NotificationCenter.default.removeObserver(errorObserverId)
        }
        
        self.playerItem = item
        
        if let item {
            self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: nil, using: { [weak self] notification in
                self?.performActionAtEnd()
            })
            
            self.failureObserverId = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main, using: { notification in
#if DEBUG
                print("Player Error: \(notification.description)")
#endif
            })
            self.errorObserverId = NotificationCenter.default.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: item, queue: .main, using: { [weak item] notification in
                if let item {
                    let event = item.errorLog()?.events.last
                    if let event {
                        let _ = event
#if DEBUG
                        print("Player Error: \(event.errorComment ?? "<no comment>")")
#endif
                    }
                }
            })
            item.addObserver(self, forKeyPath: "presentationSize", options: [], context: nil)
        }
        
        if let playerItem = self.playerItem {
            playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            self.playerItemFailedToPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: OperationQueue.main, using: { [weak self] _ in
                guard let self else {
                    return
                }
                let _ = self
            })
        }
        
        self.player?.replaceCurrentItem(with: self.playerItem)
    }
    
    private func updateStatus() {
        guard let player = self.player else {
            return
        }
        let isPlaying = !player.rate.isZero
        let status: MediaPlayerPlaybackStatus
        if self.isBuffering {
            status = .buffering(initial: false, whilePlaying: isPlaying, progress: 0.0, display: true)
        } else {
            status = isPlaying ? .playing : .paused
        }
        var timestamp = player.currentTime().seconds
        if timestamp.isFinite && !timestamp.isNaN {
        } else {
            timestamp = 0.0
        }
        self.statusValue = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: timestamp, baseRate: self.baseRate, seekId: self.seekId, status: status, soundEnabled: true)
        self._status.set(self.statusValue)
        
        if case .playing = status {
            if self.statusTimer == nil {
                self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateStatus()
                })
            }
        } else if let statusTimer = self.statusTimer {
            self.statusTimer = nil
            statusTimer.invalidate()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if let player = self.player {
                let isPlaying = !player.rate.isZero
                if isPlaying {
                    self.isBuffering = false
                }
            }
            self.updateStatus()
        } else if keyPath == "playbackBufferEmpty" {
            self.isBuffering = true
            self.updateStatus()
        } else if keyPath == "playbackLikelyToKeepUp" || keyPath == "playbackBufferFull" {
            self.isBuffering = false
            self.updateStatus()
        } else if keyPath == "presentationSize" {
            if let currentItem = self.player?.currentItem {
                print("Presentation size: \(Int(currentItem.presentationSize.height))")
            }
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
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
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: self.baseRate, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true))
        }
        if !self.hasAudioSession {
            if self.player?.volume != 0.0 {
                self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play(mixWithOthers: false), activate: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.hasAudioSession = true
                    self.player?.play()
                }, deactivate: { [weak self] _ in
                    guard let self else {
                        return .complete()
                    }
                    self.hasAudioSession = false
                    self.player?.pause()
                    
                    return .complete()
                }))
            } else {
                self.player?.play()
            }
        } else {
            self.player?.play()
        }
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player?.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        
        guard let player = self.player else {
            return
        }
        
        if player.rate.isZero {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if value {
            if !self.hasAudioSession {
                self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play(mixWithOthers: false), activate: { [weak self] _ in
                    self?.hasAudioSession = true
                    self?.player?.volume = 1.0
                }, deactivate: { [weak self] _ in
                    self?.hasAudioSession = false
                    self?.player?.pause()
                    return .complete()
                }))
            }
        } else {
            self.player?.volume = 0.0
            self.hasAudioSession = false
            self.audioSessionDisposable.set(nil)
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        self.player?.seek(to: CMTime(seconds: timestamp, preferredTimescale: 30))
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        self.player?.volume = 1.0
        self.play()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.player?.volume = soundMuted ? 0.0 : 1.0
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        self.player?.volume = 0.0
        self.hasAudioSession = false
        self.audioSessionDisposable.set(nil)
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {   
    }
    
    func setBaseRate(_ baseRate: Double) {
        guard let player = self.player else {
            return
        }
        self.baseRate = baseRate
        if #available(iOS 16.0, *) {
            player.defaultRate = Float(baseRate)
        }
        if player.rate != 0.0 {
            player.rate = Float(baseRate)
        }
        self.updateStatus()
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        guard let currentItem = self.player?.currentItem else {
            return
        }
        guard let playerSource = self.playerSource else {
            return
        }
        
        switch videoQuality {
        case .auto:
            currentItem.preferredPeakBitRate = 0.0
        case let .quality(qualityValue):
            if let file = playerSource.qualityFiles[qualityValue] {
                if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                    let bandwidth = Int(Double(size) / duration) * 8
                    currentItem.preferredPeakBitRate = Double(bandwidth)
                }
            }
        }
        
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        guard let currentItem = self.player?.currentItem else {
            return nil
        }
        guard let playerSource = self.playerSource else {
            return nil
        }
        let current = Int(currentItem.presentationSize.height)
        var available: [Int] = Array(playerSource.qualityFiles.keys)
        available.sort(by: { $0 > $1 })
        return (current, self.preferredVideoQuality, available)
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
    }
}

private func parseRange(from rangeString: String) -> Range<Int>? {
    guard rangeString.hasPrefix("bytes=") else {
        return nil
    }
    
    let rangeValues = rangeString.dropFirst("bytes=".count).split(separator: "-")
    
    guard rangeValues.count == 2,
          let start = Int(rangeValues[0]),
          let end = Int(rangeValues[1]) else {
        return nil
    }
    return start..<end + 1
}

private final class CustomVideoSchemeHandler: NSObject, WKURLSchemeHandler {
    private final class PendingTask {
        let sourceTask: any WKURLSchemeTask
        let isCompleted = Atomic<Bool>(value: false)
        var disposable: Disposable?
        
        init(source: HLSServerSource, sourceTask: any WKURLSchemeTask) {
            self.sourceTask = sourceTask
            
            var requestRange: Range<Int>?
            if let rangeString = sourceTask.request.allHTTPHeaderFields?["Range"] {
                requestRange = parseRange(from: rangeString)
            }
            
            guard let url = sourceTask.request.url else {
                return
            }
            let filePath = (url.absoluteString as NSString).lastPathComponent

            if filePath == "master.m3u8" {
                self.disposable = source.masterPlaylistData().startStrict(next: { [weak self] data in
                    guard let self else {
                        return
                    }
                    self.sendResponseAndClose(data: data.data(using: .utf8)!)
                })
            } else if filePath.hasPrefix("hls_level_") && filePath.hasSuffix(".m3u8") {
                guard let levelIndex = Int(String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_level_".count) ..< filePath.index(filePath.endIndex, offsetBy: -".m3u8".count)])) else {
                    self.sendErrorAndClose()
                    return
                }
                
                self.disposable = source.playlistData(quality: levelIndex).startStrict(next: { [weak self] data in
                    guard let self else {
                        return
                    }
                    self.sendResponseAndClose(data: data.data(using: .utf8)!)
                })
            } else if filePath.hasPrefix("partfile") && filePath.hasSuffix(".mp4") {
                let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "partfile".count) ..< filePath.index(filePath.endIndex, offsetBy: -".mp4".count)])
                guard let fileIdValue = Int64(fileId) else {
                    self.sendErrorAndClose()
                    return
                }
                guard let requestRange else {
                    self.sendErrorAndClose()
                    return
                }
                self.disposable = (source.fileData(id: fileIdValue, range: requestRange.lowerBound ..< requestRange.upperBound + 1)
                |> take(1)).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    
                    if let (file, range, totalSize) = result {
                        guard let allData = try? Data(contentsOf: URL(fileURLWithPath: file.path), options: .mappedIfSafe) else {
                            return
                        }
                        let data = allData.subdata(in: range)
                        
                        self.sendResponseAndClose(data: data, range: requestRange, totalSize: totalSize)
                    } else {
                        self.sendErrorAndClose()
                    }
                })
            } else {
                self.sendErrorAndClose()
            }
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func cancel() {
        }
        
        func sendErrorAndClose() {
            self.sourceTask.didFailWithError(NSError(domain: "LocalVideoError", code: 500, userInfo: nil))
        }
        
        private func sendResponseAndClose(data: Data, range: Range<Int>? = nil, totalSize: Int? = nil) {
            // Create the response with the appropriate content-type and content-length
            //let mimeType = "application/octet-stream"
            let responseLength = data.count
            
            // Construct URLResponse with optional range headers (for partial content responses)
            var headers: [String: String] = [
                "Content-Length": "\(responseLength)",
                "Connection": "close",
                "Access-Control-Allow-Origin": "*"
            ]
            
            if let range = range, let totalSize = totalSize {
                headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound)/\(totalSize)"
            }
            
            // Create the URLResponse object
            let response = HTTPURLResponse(url: self.sourceTask.request.url!,
                                           statusCode: 200,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: headers)
            
            // Send the response headers
            self.sourceTask.didReceive(response!)
            
            // Send the response data
            self.sourceTask.didReceive(data)
            
            // Complete the task
            self.sourceTask.didFinish()
        }
    }
    
    private let source: HLSServerSource
    private var pendingTasks: [PendingTask] = []
    
    init(source: HLSServerSource) {
        self.source = source
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        self.pendingTasks.append(PendingTask(source: self.source, sourceTask: urlSchemeTask))
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        if let index = self.pendingTasks.firstIndex(where: { $0.sourceTask === urlSchemeTask }) {
            let task = self.pendingTasks[index]
            self.pendingTasks.remove(at: index)
            task.cancel()
        }
    }
}

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

private final class HLSVideoJSContentNode: ASDisplayNode, UniversalVideoContentNode {
    private struct Level {
        let bitrate: Int
        let width: Int
        let height: Int
        
        init(bitrate: Int, width: Int, height: Int) {
            self.bitrate = bitrate
            self.width = width
            self.height = height
        }
    }
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playerSource: HLSServerSource?
    private var serverDisposable: Disposable?
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private let imageNode: TransformImageNode
    private let webView: WKWebView
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    private var playerIsReady: Bool = false
    private var playerIsFirstFrameReady: Bool = false
    private var playerIsPlaying: Bool = false
    private var playerRate: Double = 0.0
    private var playerDefaultRate: Double = 1.0
    private var playerTime: Double = 0.0
    private var playerTimeGenerationTimestamp: Double = 0.0
    private var playerAvailableLevels: [Int: Level] = [:]
    private var playerCurrentLevelIndex: Int?
    
    private var hasRequestedPlayerLoad: Bool = false
    
    private var requestedPlaying: Bool = false
    private var requestedBaseRate: Double = 1.0
    private var requestedLevelIndex: Int?
    
    init(accountId: AccountRecordId, postbox: Postbox, audioSessionManager: ManagedAudioSession, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.audioSessionManager = audioSessionManager
        self.userLocation = userLocation
        self.requestedBaseRate = baseRate
        
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
        
        self.imageNode = TransformImageNode()
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false
        
        var playerSource: HLSServerSource?
        if let qualitySet = HLSQualitySet(baseFile: fileReference) {
            let playerSourceValue = HLSServerSource(accountId: accountId.int64, fileId: fileReference.media.fileId.id, postbox: postbox, userLocation: userLocation, playlistFiles: qualitySet.playlistFiles, qualityFiles: qualitySet.qualityFiles)
            playerSource = playerSourceValue
            let schemeHandler = CustomVideoSchemeHandler(source: playerSourceValue)
            config.setURLSchemeHandler(schemeHandler, forURLScheme: "tghls")
        }
        self.playerSource = playerSource
        
        let userController = WKUserContentController()
        
        var handleScriptMessage: ((WKScriptMessage) -> Void)?
        userController.add(WeakScriptMessageHandler { message in
            handleScriptMessage?(message)
        }, name: "performAction")
        
        let isDebug: Bool
        #if DEBUG
        isDebug = true
        #else
        isDebug = false
        #endif
        
        let mediaDimensions = fileReference.media.dimensions?.cgSize ?? CGSize(width: 480.0, height: 320.0)
        self.intrinsicDimensions = mediaDimensions.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
        
        let userScriptJs = """
        playerInitialize({
            'debug': \(isDebug),
            'width': \(Int(self.intrinsicDimensions.width)),
            'height': \(Int(self.intrinsicDimensions.height))
        });
        """;
        let userScript = WKUserScript(source: userScriptJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userController.addUserScript(userScript)
        
        config.userContentController = userController
        
        self.webView = WKWebView(frame: CGRect(origin: CGPoint(), size: self.intrinsicDimensions), configuration: config)
        self.webView.scrollView.isScrollEnabled = false
        self.webView.allowsLinkPreview = false
        self.webView.allowsBackForwardNavigationGestures = false
        self.webView.accessibilityIgnoresInvertColors = true
        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView.alpha = 0.0
        
        if #available(iOS 16.4, *) {
            #if DEBUG
            self.webView.isInspectable = true
            #endif
        }
        
        super.init()

        self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, userLocation: self.userLocation, videoReference: fileReference) |> map { [weak self] getSize, getData in
            Queue.mainQueue().async {
                if let strongSelf = self, strongSelf.dimensions == nil {
                    if let dimensions = getSize() {
                        strongSelf.dimensions = dimensions
                        strongSelf.dimensionsPromise.set(dimensions)
                        if let validLayout = strongSelf.validLayout {
                            strongSelf.updateLayout(size: validLayout.size, actualSize: validLayout.actualSize, transition: .immediate)
                        }
                    }
                }
            }
            return getData
        })
        
        self.addSubnode(self.imageNode)
        self.view.addSubview(self.webView)
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self._bufferingStatus.set(.single(nil))
        
        handleScriptMessage = { [weak self] message in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                guard let body = message.body as? [String: Any] else {
                    return
                }
                guard let eventName = body["event"] as? String else {
                    return
                }
                
                switch eventName {
                case "playerStatus":
                    guard let eventData = body["data"] as? [String: Any] else {
                        return
                    }
                    if let isReady = eventData["isReady"] as? Bool {
                        self.playerIsReady = isReady
                    } else {
                        self.playerIsReady = false
                    }
                    if let isFirstFrameReady = eventData["isFirstFrameReady"] as? Bool {
                        self.playerIsFirstFrameReady = isFirstFrameReady
                    } else {
                        self.playerIsFirstFrameReady = false
                    }
                    if let isPlaying = eventData["isPlaying"] as? Bool {
                        self.playerIsPlaying = isPlaying
                    } else {
                        self.playerIsPlaying = false
                    }
                    if let rate = eventData["rate"] as? Double {
                        self.playerRate = rate
                    } else {
                        self.playerRate = 0.0
                    }
                    if let defaultRate = eventData["defaultRate"] as? Double {
                        self.playerDefaultRate = defaultRate
                    } else {
                        self.playerDefaultRate = 0.0
                    }
                    if let levels = eventData["levels"] as? [[String: Any]] {
                        self.playerAvailableLevels.removeAll()
                        
                        for level in levels {
                            guard let levelIndex = level["index"] as? Int else {
                                continue
                            }
                            guard let levelBitrate = level["bitrate"] as? Int else {
                                continue
                            }
                            guard let levelWidth = level["width"] as? Int else {
                                continue
                            }
                            guard let levelHeight = level["height"] as? Int else {
                                continue
                            }
                            self.playerAvailableLevels[levelIndex] = Level(
                                bitrate: levelBitrate,
                                width: levelWidth,
                                height: levelHeight
                            )
                        }
                    } else {
                        self.playerAvailableLevels.removeAll()
                    }
                    
                    if let currentLevel = eventData["currentLevel"] as? Int {
                        if self.playerAvailableLevels[currentLevel] != nil {
                            self.playerCurrentLevelIndex = currentLevel
                        } else {
                            self.playerCurrentLevelIndex = nil
                        }
                    } else {
                        self.playerCurrentLevelIndex = nil
                    }
                    
                    self.webView.alpha = self.playerIsFirstFrameReady ? 1.0 : 0.0
                    if self.playerIsReady {
                        if !self.hasRequestedPlayerLoad {
                            if !self.playerAvailableLevels.isEmpty {
                                var selectedLevelIndex: Int?
                                if let minimizedQualityFile = HLSVideoContent.minimizedHLSQualityFile(file: self.fileReference) {
                                    if let dimensions = minimizedQualityFile.media.dimensions {
                                        for (index, level) in self.playerAvailableLevels {
                                            if level.height == Int(dimensions.height) {
                                                selectedLevelIndex = index
                                                break
                                            }
                                        }
                                    }
                                }
                                if selectedLevelIndex == nil {
                                    selectedLevelIndex = self.playerAvailableLevels.sorted(by: { $0.value.height > $1.value.height }).first?.key
                                }
                                if let selectedLevelIndex {
                                    self.hasRequestedPlayerLoad = true
                                    self.webView.evaluateJavaScript("playerLoad(\(selectedLevelIndex));", completionHandler: nil)
                                }
                            }
                        }
                        
                        self.webView.evaluateJavaScript("playerSetBaseRate(\(self.requestedBaseRate));", completionHandler: nil)
                        
                        if self.requestedPlaying {
                            self.requestPlay()
                        } else {
                            self.requestPause()
                        }
                    }
                    
                    self.updateStatus()
                case "playerCurrentTime":
                    guard let eventData = body["data"] as? [String: Any] else {
                        return
                    }
                    guard let value = eventData["value"] as? Double else {
                        return
                    }
                    self.playerTime = value
                    self.playerTimeGenerationTimestamp = CACurrentMediaTime()
                    self.updateStatus()
                default:
                    break
                }
            }
        }
        
        if let playerSource = self.playerSource {
            self.serverDisposable = SharedHLSServer.shared.registerPlayer(source: playerSource, completion: { [weak self] in
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    
                    let htmlUrl = "http://127.0.0.1:\(SharedHLSServer.shared.port)/\(playerSource.id)/index.html"
                    self.webView.load(URLRequest(url: URL(string: htmlUrl)!))
                }
            })
        }
    }
    
    deinit {
        self.serverDisposable?.dispose()
        self.audioSessionDisposable.dispose()
        
        self.statusTimer?.invalidate()
    }
    
    private func updateStatus() {
        let isPlaying = self.requestedPlaying && self.playerRate != 0.0
        let status: MediaPlayerPlaybackStatus
        if self.requestedPlaying && !isPlaying {
            status = .buffering(initial: false, whilePlaying: self.requestedPlaying, progress: 0.0, display: true)
        } else {
            status = self.requestedPlaying ? .playing : .paused
        }
        var timestamp = self.playerTime
        if timestamp.isFinite && !timestamp.isNaN {
        } else {
            timestamp = 0.0
        }
        self.statusValue = MediaPlayerStatus(generationTimestamp: self.playerTimeGenerationTimestamp, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: timestamp, baseRate: self.requestedBaseRate, seekId: self.seekId, status: status, soundEnabled: true)
        self._status.set(self.statusValue)
        
        if case .playing = status {
            if self.statusTimer == nil {
                self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateStatus()
                })
            }
        } else if let statusTimer = self.statusTimer {
            self.statusTimer = nil
            statusTimer.invalidate()
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(layer: self.webView.layer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(layer: self.webView.layer, scale: size.width / self.intrinsicDimensions.width)
        
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
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: self.requestedBaseRate, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true))
        }
        if !self.hasAudioSession {
            self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play(mixWithOthers: false), activate: { [weak self] _ in
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    self.hasAudioSession = true
                    self.requestPlay()
                }
            }, deactivate: { [weak self] _ in
                return Signal { subscriber in
                    if let self {
                        self.hasAudioSession = false
                        self.requestPause()
                    }
                    
                    subscriber.putCompletion()
                    
                    return EmptyDisposable
                }
                |> runOn(.mainQueue())
            }))
        } else {
            self.requestPlay()
        }
    }
    
    private func requestPlay() {
        self.requestedPlaying = true
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerPlay();", completionHandler: nil)
        }
        self.updateStatus()
    }

    private func requestPause() {
        self.requestedPlaying = false
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerPause();", completionHandler: nil)
        }
        self.updateStatus()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.requestPause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        
        if self.requestedPlaying {
            self.pause()
        } else {
            self.play()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        /*if value {
            if !self.hasAudioSession {
                self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play(mixWithOthers: false), activate: { [weak self] _ in
                    self?.hasAudioSession = true
                    self?.player?.volume = 1.0
                }, deactivate: { [weak self] _ in
                    self?.hasAudioSession = false
                    self?.player?.pause()
                    return .complete()
                }))
            }
        } else {
            self.player?.volume = 0.0
            self.hasAudioSession = false
            self.audioSessionDisposable.set(nil)
        }*/
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        
        self.webView.evaluateJavaScript("playerSeek(\(timestamp));", completionHandler: nil)
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        self.webView.evaluateJavaScript("playerSetIsMuted(false);", completionHandler: nil)
        
        self.play()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.webView.evaluateJavaScript("playerSetIsMuted(\(soundMuted));", completionHandler: nil)
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        self.webView.evaluateJavaScript("playerSetIsMuted(true);", completionHandler: nil)
        self.hasAudioSession = false
        self.audioSessionDisposable.set(nil)
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.requestedBaseRate = baseRate
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerSetBaseRate(\(self.requestedBaseRate));", completionHandler: nil)
        }
        self.updateStatus()
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        switch videoQuality {
        case .auto:
            self.requestedLevelIndex = nil
        case let .quality(quality):
            if let level = self.playerAvailableLevels.first(where: { $0.value.height == quality }) {
                self.requestedLevelIndex = level.key
            } else {
                self.requestedLevelIndex = nil
            }
        }
        
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerSetLevel(\(self.requestedLevelIndex ?? -1));", completionHandler: nil)
        }
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        guard let playerCurrentLevelIndex = self.playerCurrentLevelIndex else {
            return nil
        }
        guard let currentLevel = self.playerAvailableLevels[playerCurrentLevelIndex] else {
            return nil
        }
        
        var available = self.playerAvailableLevels.values.map(\.height)
        available.sort(by: { $0 > $1 })
        
        return (currentLevel.height, self.preferredVideoQuality, available)
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
    }
}

