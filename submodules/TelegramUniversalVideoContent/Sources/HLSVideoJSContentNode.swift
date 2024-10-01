import Foundation
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

final class HLSVideoJSContentNode: ASDisplayNode, UniversalVideoContentNode {
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
        
        /*#if DEBUG
        if let minimizedQualityFile = HLSVideoContent.minimizedHLSQualityFile(file: self.fileReference) {
            let _ = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: userLocation, userContentType: .video, reference: minimizedQualityFile.resourceReference(minimizedQualityFile.media.resource), range: (0 ..< 5 * 1024 * 1024, .default)).startStandalone()
        }
        #endif*/
        
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
        var intrinsicDimensions = mediaDimensions.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
        
        let userScriptJs = """
        playerInitialize({
            'debug': \(isDebug),
            'width': \(Int(intrinsicDimensions.width)),
            'height': \(Int(intrinsicDimensions.height)),
            'bandwidthEstimate': \(HLSVideoJSContentNode.sharedBandwidthEstimate ?? 500000.0)
        });
        """;
        let userScript = WKUserScript(source: userScriptJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userController.addUserScript(userScript)
        
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
                    
                    self.webView.alpha = self.playerIsFirstFrameReady ? 1.0 : 0.0
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
                    self.playerTimeGenerationTimestamp = CACurrentMediaTime()
                    
                    var bandwidthEstimate = eventData["bandwidthEstimate"] as? Double
                    if let bandwidthEstimateValue = bandwidthEstimate, bandwidthEstimateValue.isNaN || bandwidthEstimateValue.isInfinite {
                        bandwidthEstimate = nil
                    }
                    
                    HLSVideoJSContentNode.sharedBandwidthEstimate = bandwidthEstimate
                    
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
