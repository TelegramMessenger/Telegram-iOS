import Foundation
import AVFoundation
import SwiftSignalKit
import UniversalMediaPlayer
import Postbox
import TelegramCore
import WebKit
import AsyncDisplayKit
import AccountContext
import TelegramAudio
import Display
import PhotoResources
import TelegramVoip
import RangeSet
import AppBundle
import ManagedFile
import FFMpegBinding
import RangeSet

final class HLSJSServerSource: SharedHLSServer.Source {
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
            let bundle = Bundle(for: HLSJSServerSource.self)
            
            let bundlePath = bundle.bundlePath + "/HlsBundle.bundle"
            if let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath + "/" + path)) {
                let mimeType: String
                let pathExtension = (path as NSString).pathExtension
                if pathExtension == "html" {
                    mimeType = "text/html"
                } else if pathExtension == "html" {
                    mimeType = "application/javascript"
                } else {
                    mimeType = "application/octet-stream"
                }
                subscriber.putNext((data, mimeType))
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
        let fetchFromRemote: Signal<(TempBoxFile, Range<Int>, Int)?, NoError> = Signal { subscriber in
            let partialFile = TempBox.shared.tempFile(fileName: "data")
            
            if let cachedData = postbox.mediaBox.internal_resourceData(id: file.media.resource.id, size: size, in: Int64(range.lowerBound) ..< Int64(range.upperBound)) {
                #if DEBUG
                print("Fetched \(quality)p part from cache")
                #endif
                
                let outputFile = ManagedFile(queue: nil, path: partialFile.path, mode: .readwrite)
                if let outputFile {
                    let blockSize = 128 * 1024
                    var tempBuffer = Data(count: blockSize)
                    var blockOffset = 0
                    while blockOffset < cachedData.length {
                        let currentBlockSize = min(cachedData.length - blockOffset, blockSize)
                        
                        tempBuffer.withUnsafeMutableBytes { bytes -> Void in
                            let _ = cachedData.file.read(bytes.baseAddress!, currentBlockSize)
                            let _ = outputFile.write(bytes.baseAddress!, count: currentBlockSize)
                        }
                        
                        blockOffset += blockSize
                    }
                    outputFile._unsafeClose()
                    subscriber.putNext((partialFile, 0 ..< cachedData.length, Int(size)))
                    subscriber.putCompletion()
                } else {
                    #if DEBUG
                    print("Error writing cached file to disk")
                    #endif
                }
                
                return EmptyDisposable
            }
            
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
        
        return fetchFromRemote
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

final class HLSVideoJSNativeContentNode: ASDisplayNode, UniversalVideoContentNode {
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
    
    private static var sharedBandwidthEstimate: Double?
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playerSource: HLSJSServerSource?
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
    
    private let _isNativePictureInPictureActive = ValuePromise<Bool>(false, ignoreRepeated: true)
    var isNativePictureInPictureActive: Signal<Bool, NoError> {
        return self._isNativePictureInPictureActive.get()
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
    
    private let player: ChunkMediaPlayer
    private let playerNode: MediaPlayerNode
    
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
    private var playerAvailableLevels: [Int: Level] = [:]
    private var playerCurrentLevelIndex: Int?
    
    private var hasRequestedPlayerLoad: Bool = false
    
    private var requestedPlaying: Bool = false
    private var requestedBaseRate: Double = 1.0
    private var requestedLevelIndex: Int?
    
    private var videoElements: [Int: VideoElement] = [:]
    private var mediaSources: [Int: MediaSource] = [:]
    private var sourceBuffers: [Int: SourceBuffer] = [:]
    
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    
    private let chunkPlayerPartsState = Promise<ChunkMediaPlayerPartsState>(ChunkMediaPlayerPartsState(duration: nil, parts: []))
    private var sourceBufferStateDisposable: Disposable?
    
    private var playerStatusDisposable: Disposable?
    
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
        config.allowsPictureInPictureMediaPlayback = true
        
        var playerSource: HLSJSServerSource?
        if let qualitySet = HLSQualitySet(baseFile: fileReference) {
            let playerSourceValue = HLSJSServerSource(accountId: accountId.int64, fileId: fileReference.media.fileId.id, postbox: postbox, userLocation: userLocation, playlistFiles: qualitySet.playlistFiles, qualityFiles: qualitySet.qualityFiles)
            playerSource = playerSourceValue
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
        var intrinsicDimensions = mediaDimensions.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
        
        config.userContentController = userController
        
        intrinsicDimensions.width = floor(intrinsicDimensions.width / UIScreenScale)
        intrinsicDimensions.height = floor(intrinsicDimensions.height / UIScreenScale)
        self.intrinsicDimensions = intrinsicDimensions
        
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
        
        
        self.player = ChunkMediaPlayer(
            postbox: postbox,
            audioSessionManager: audioSessionManager,
            partsState: self.chunkPlayerPartsState.get(),
            video: true,
            enableSound: true,
            baseRate: baseRate
        )
        
        self.playerNode = MediaPlayerNode()
        self.player.attachPlayerNode(self.playerNode)
        
        super.init()
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)

        self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, userLocation: self.userLocation, videoReference: fileReference, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true) |> map { [weak self] getSize, getData in
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
        self.addSubnode(self.playerNode)
        
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
                case "windowOnLoad":
                    let userScriptJs = """
                    playerInitialize({
                        'debug': \(isDebug),
                        'bandwidthEstimate': \(HLSVideoJSNativeContentNode.sharedBandwidthEstimate ?? 500000.0)
                    });
                    """
                    if "".isEmpty {
                        self.webView.evaluateJavaScript(userScriptJs, completionHandler: nil)
                    }
                case "bridgeInvoke":
                    guard let eventData = body["data"] as? [String: Any] else {
                        return
                    }
                    guard let bridgeId = eventData["bridgeId"] as? Int else {
                        return
                    }
                    guard let callbackId = eventData["callbackId"] as? Int else {
                        return
                    }
                    guard let className = eventData["className"] as? String else {
                        return
                    }
                    guard let methodName = eventData["methodName"] as? String else {
                        return
                    }
                    guard let params = eventData["params"] as? [String: Any] else {
                        return
                    }
                    self.bridgeInvoke(
                        bridgeId: bridgeId,
                        className: className,
                        methodName: methodName,
                        params: params,
                        completion: { [weak self] result in
                            guard let self else {
                                return
                            }
                            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
                            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
                            self.webView.evaluateJavaScript("bridgeInvokeCallback(\(callbackId), \(jsonResultString));", completionHandler: nil)
                        }
                    )
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
                    
                    self._isNativePictureInPictureActive.set(eventData["isPictureInPictureActive"] as? Bool ?? false)
                    
                    if let currentLevel = eventData["currentLevel"] as? Int {
                        if self.playerAvailableLevels[currentLevel] != nil {
                            self.playerCurrentLevelIndex = currentLevel
                        } else {
                            self.playerCurrentLevelIndex = nil
                        }
                    } else {
                        self.playerCurrentLevelIndex = nil
                    }
                    
                    if self.playerIsReady {
                        if !self.hasRequestedPlayerLoad {
                            if !self.playerAvailableLevels.isEmpty {
                                var selectedLevelIndex: Int?
                                if let minimizedQualityFile = HLSVideoContent.minimizedHLSQuality(file: self.fileReference)?.file {
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
                    
                    var bandwidthEstimate = eventData["bandwidthEstimate"] as? Double
                    if let bandwidthEstimateValue = bandwidthEstimate, bandwidthEstimateValue.isNaN || bandwidthEstimateValue.isInfinite {
                        bandwidthEstimate = nil
                    }
                    
                    HLSVideoJSNativeContentNode.sharedBandwidthEstimate = bandwidthEstimate
                    
                    self.updateStatus()
                    
                    //TODO
                    //self.controlledPlayer?.currentReferenceTime = value
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
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            let _ = self
        })
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            let _ = self
        })
        
        self.playerStatusDisposable = (self.player.status
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            guard let self else {
                return
            }
            self.updatePlayerStatus(status: status)
        })
        
        self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 25.0, repeats: true, block: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateStatus()
        })
    }
    
    deinit {
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let willResignActiveObserver = self.willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        
        self.serverDisposable?.dispose()
        self.audioSessionDisposable.dispose()
        
        self.statusTimer?.invalidate()
        
        self.sourceBufferStateDisposable?.dispose()
        self.playerStatusDisposable?.dispose()
    }
    
    private func bridgeInvoke(
        bridgeId: Int,
        className: String,
        methodName: String,
        params: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        if (className == "VideoElement") {
            if (methodName == "constructor") {
                let videoElement = VideoElement()
                self.videoElements[bridgeId] = videoElement
                completion([:])
            } else if (methodName == "setCurrentTime") {
                guard let currentTime = params["currentTime"] as? Double else {
                    assertionFailure()
                    return
                }
                self.player.seek(timestamp: currentTime)
                completion([:])
            } else if (methodName == "play") {
                self.player.play()
                completion([:])
            } else if (methodName == "pause") {
                self.player.pause()
                completion([:])
            }
        } else if (className == "MediaSource") {
            if (methodName == "constructor") {
                let mediaSource = MediaSource()
                self.mediaSources[bridgeId] = mediaSource
                completion([:])
            } else if (methodName == "setDuration") {
                guard let duration = params["duration"] as? Double else {
                    assertionFailure()
                    return
                }
                guard let mediaSource = self.mediaSources[bridgeId] else {
                    assertionFailure()
                    return
                }
                if mediaSource.duration != duration {
                    mediaSource.duration = duration
                    
                    if let sourceBuffer = self.sourceBuffers.first?.value {
                        self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: self.mediaSources.first?.value.duration, parts: sourceBuffer.items)))
                    }
                }
                completion([:])
            }
        } else if (className == "SourceBuffer") {
            if (methodName == "constructor") {
                guard let mimeType = params["mimeType"] as? String else {
                    assertionFailure()
                    return
                }
                let sourceBuffer = SourceBuffer(mimeType: mimeType)
                self.sourceBuffers[bridgeId] = sourceBuffer

                self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: self.mediaSources.first?.value.duration, parts: sourceBuffer.items)))
                if self.sourceBufferStateDisposable == nil {
                    self.sourceBufferStateDisposable = (sourceBuffer.updated.signal()
                    |> deliverOnMainQueue).startStrict(next: { [weak self, weak sourceBuffer] _ in
                        guard let self, let sourceBuffer else {
                            return
                        }
                        self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: self.mediaSources.first?.value.duration, parts: sourceBuffer.items)))
                        
                        self.updateBuffered()
                    })
                }
                completion([:])
            } else if (methodName == "appendBuffer") {
                guard let base64Data = params["data"] as? String else {
                    assertionFailure()
                    return
                }
                guard let data = Data(base64Encoded: base64Data.data(using: .utf8)!) else {
                    assertionFailure()
                    return
                }
                guard let sourceBuffer = self.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.appendBuffer(data: data, completion: { bufferedRanges in
                    completion(["ranges": serializeRanges(bufferedRanges)])
                })
            } else if methodName == "remove" {
                guard let start = params["start"] as? Double, let end = params["end"] as? Double else {
                    assertionFailure()
                    return
                }
                guard let sourceBuffer = self.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.remove(start: start, end: end, completion: { bufferedRanges in
                    completion(["ranges": serializeRanges(bufferedRanges)])
                })
            } else if methodName == "abort" {
                guard let sourceBuffer = self.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.abortOperation()
                completion([:])
            }
        }
    }
    
    private func updatePlayerStatus(status: MediaPlayerStatus) {
        self._status.set(status)
        
        if let (bridgeId, _) = self.videoElements.first {
            var isPlaying: Bool = false
            var isBuffering = false
            switch status.status {
            case .playing:
                isPlaying = true
            case .paused:
                break
            case let .buffering(_, whilePlaying, _, _):
                isPlaying = whilePlaying
                isBuffering = true
            }
            
            let result: [String: Any] = [
                "isPlaying": isPlaying,
                "isWaiting": isBuffering,
                "currentTime": status.timestamp
            ]
            
            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
            self.webView.evaluateJavaScript("window.bridgeObjectMap[\(bridgeId)].bridgeUpdateStatus(\(jsonResultString));", completionHandler: nil)
        }
    }
    
    private func updateBuffered() {
        let bufferedRanges = self.sourceBuffers.first?.value.ranges ?? RangeSet()
        
        if let (bridgeId, _) = self.videoElements.first {
            let result = serializeRanges(bufferedRanges)
            
            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
            self.webView.evaluateJavaScript("window.bridgeObjectMap[\(bridgeId)].bridgeUpdateBuffered(\(jsonResultString));", completionHandler: nil)
        }
        
        if let duration = self.mediaSources.first?.value.duration {
            var mappedRanges = RangeSet<Int64>()
            for range in bufferedRanges.ranges {
                mappedRanges.formUnion(RangeSet<Int64>(Int64(range.lowerBound * 1000.0) ..< Int64(range.upperBound * 1000.0)))
            }
            self._bufferingStatus.set(.single((mappedRanges, Int64(duration * 1000.0))))
        }
    }
    
    private func updateStatus() {
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(layer: self.webView.layer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(layer: self.webView.layer, scale: size.width / self.intrinsicDimensions.width)
        
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
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: self.requestedBaseRate, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true))
        }
        /*if !self.hasAudioSession {
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
        } else*/ do {
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
    
    func enterNativePictureInPicture() -> Bool {
        self.webView.evaluateJavaScript("playerRequestPictureInPicture();", completionHandler: nil)
        return true
    }
    
    func exitNativePictureInPicture() {
        self.webView.evaluateJavaScript("playerStopPictureInPicture();", completionHandler: nil)
    }
}

private func serializeRanges(_ ranges: RangeSet<Double>) -> [Double] {
    var result: [Double] = []
    for range in ranges.ranges {
        result.append(range.lowerBound)
        result.append(range.upperBound)
    }
    return result
}

private final class VideoElement {
    init() {
    }
}

private final class MediaSource {
    var duration: Double?
    
    init() {
    }
}

private final class SourceBuffer {
    private static let sharedQueue = Queue(name: "SourceBuffer")
    
    final class Item {
        let tempFile: TempBoxFile
        let asset: AVURLAsset
        let startTime: Double
        let endTime: Double
        let rawData: Data
        
        var clippedStartTime: Double
        var clippedEndTime: Double
        
        init(tempFile: TempBoxFile, asset: AVURLAsset, startTime: Double, endTime: Double, rawData: Data) {
            self.tempFile = tempFile
            self.asset = asset
            self.startTime = startTime
            self.endTime = endTime
            self.rawData = rawData
            
            self.clippedStartTime = startTime
            self.clippedEndTime = endTime
        }
        
        func removeRange(start: Double, end: Double) {
            //TODO
        }
    }
    
    let mimeType: String
    var initializationData: Data?
    var items: [ChunkMediaPlayerPart] = []
    var ranges = RangeSet<Double>()
    
    let updated = ValuePipe<Void>()
    
    private var currentUpdateId: Int = 0
    
    init(mimeType: String) {
        self.mimeType = mimeType
    }
    
    func abortOperation() {
        self.currentUpdateId += 1
    }
    
    func appendBuffer(data: Data, completion: @escaping (RangeSet<Double>) -> Void) {
        let initializationData = self.initializationData
        self.currentUpdateId += 1
        let updateId = self.currentUpdateId
        
        SourceBuffer.sharedQueue.async { [weak self] in
            let tempFile = TempBox.shared.tempFile(fileName: "data.mp4")
            
            var combinedData = Data()
            if let initializationData {
                combinedData.append(initializationData)
            }
            combinedData.append(data)
            guard let _ = try? combinedData.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) else {
                Queue.mainQueue().async {
                    guard let self else {
                        completion(RangeSet())
                        return
                    }
                    
                    if self.currentUpdateId != updateId {
                        return
                    }
                    
                    completion(self.ranges)
                }
                return
            }
            
            if let fragmentInfo = extractFFMpegMediaInfo(path: tempFile.path) {
                Queue.mainQueue().async {
                    guard let self else {
                        completion(RangeSet())
                        return
                    }
                    
                    if self.currentUpdateId != updateId {
                        return
                    }
                    
                    if fragmentInfo.duration.value == 0 {
                        self.initializationData = data
                        
                        completion(self.ranges)
                    } else {
                        let item = ChunkMediaPlayerPart(
                            startTime: fragmentInfo.startTime.seconds,
                            endTime: fragmentInfo.startTime.seconds + fragmentInfo.duration.seconds,
                            file: tempFile
                        )
                        self.items.append(item)
                        self.updateRanges()
                        
                        completion(self.ranges)
                        
                        self.updated.putNext(Void())
                    }
                }
            } else {
                assertionFailure()
                Queue.mainQueue().async {
                    guard let self else {
                        completion(RangeSet())
                        return
                    }
                    
                    if self.currentUpdateId != updateId {
                        return
                    }
                    
                    completion(self.ranges)
                }
                return
            }
        }
    }
    
    func remove(start: Double, end: Double, completion: @escaping (RangeSet<Double>) -> Void) {
        self.items.removeAll(where: { item in
            if item.startTime >= start && item.endTime <= end {
                return true
            } else {
                return false
            }
        })
        self.updateRanges()
        completion(self.ranges)
        
        self.updated.putNext(Void())
    }
    
    private func updateRanges() {
        self.ranges = RangeSet()
        for item in self.items {
            let itemStartTime = round(item.startTime * 1000.0) / 1000.0
            let itemEndTime = round(item.endTime * 1000.0) / 1000.0
            self.ranges.formUnion(RangeSet<Double>(itemStartTime ..< itemEndTime))
        }
    }
}

private func parseFragment(filePath: String) -> (offset: CMTime, duration: CMTime)? {
    let source = SoftwareVideoSource(path: filePath, hintVP9: false, unpremultiplyAlpha: false)
    return source.readTrackInfo()
}
