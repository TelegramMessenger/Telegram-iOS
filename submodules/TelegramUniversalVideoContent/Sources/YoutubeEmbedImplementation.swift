import Foundation
import Display
import Postbox
import TelegramCore
import AccountContext
import WebKit
import SwiftSignalKit
import UniversalMediaPlayer
import AppBundle

func extractYoutubeVideoIdAndTimestamp(url: String) -> (String, Int)? {
    guard let url = URL(string: url), let host = url.host?.lowercased() else {
        return nil
    }
    
    let match = ["youtube.com", "youtu.be"].contains(where: { (domain) -> Bool in
        return host == domain || host.contains(".\(domain)")
    })
    
    guard match else {
        return nil
    }
    
    var videoId: String?
    var timestamp = 0
    
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        if let queryItems = components.queryItems {
            for queryItem in queryItems {
                if let value = queryItem.value {
                    if queryItem.name == "v" {
                        videoId = value
                    } else if queryItem.name == "t" || queryItem.name == "time_continue" {
                        if value.contains("s") {
                            var range = value.startIndex..<value.endIndex
                            if let hoursRange = value.range(of: "h", options: .caseInsensitive, range: range, locale: nil) {
                                let subvalue = String(value[range.lowerBound ..< hoursRange.lowerBound])
                                if let hours = Int(subvalue) {
                                    timestamp = timestamp + hours * 3600
                                }
                                range = hoursRange.upperBound..<value.endIndex
                            }
                            
                            if let minutesRange = value.range(of: "m", options: .caseInsensitive, range: range, locale: nil) {
                                let subvalue = String(value[range.lowerBound ..< minutesRange.lowerBound])
                                if let minutes = Int(subvalue) {
                                    timestamp = timestamp + minutes * 60
                                }
                                range = minutesRange.upperBound..<value.endIndex
                            }
                            
                            if let secondsRange = value.range(of: "s", options: .caseInsensitive, range: range, locale: nil) {
                                let subvalue = String(value[range.lowerBound ..< secondsRange.lowerBound])
                                if let seconds = Int(subvalue) {
                                    timestamp = timestamp + seconds
                                }
                            }
                        } else {
                            if let seconds = Int(value) {
                                timestamp = seconds
                            }
                        }
                    }
                }
            }
        }
        
        if videoId == nil {
            let pathComponents = components.path.components(separatedBy: "/")
            var nextComponentIsVideoId = host.contains("youtu.be")
            
            for component in pathComponents {
                if component.count > 0 && nextComponentIsVideoId {
                    videoId = component
                    break
                } else if component == "embed" {
                    nextComponentIsVideoId = true
                }
            }
        }
    }
    
    if let videoId = videoId {
        return (videoId, timestamp)
    }
    
    return nil
}

final class YoutubeEmbedImplementation: WebEmbedImplementation {
    private var evalImpl: ((String, ((Any?) -> Void)?) -> Void)?
    private var updateStatus: ((MediaPlayerStatus) -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    
    fileprivate let videoId: String
    fileprivate var storyboardSpec: String?
    fileprivate var duration: Double {
        return self.status.duration
    }
    
    private var timestamp: Int
    private var baseRate: Double = 1.0
    private var ignoreEarlierTimestamps = false
    private var status: MediaPlayerStatus
    
    private var ready = false
    private var started = false
    private var ignorePosition: Int?
    
    private var isPlaying = true
    
    private enum PlaybackDelay {
        case none
        case afterPositionUpdates(count: Int)
    }
    private var playbackDelay = PlaybackDelay.none
    
    private let benchmarkStartTime: CFAbsoluteTime
    
    init(videoId: String, timestamp: Int = 0) {
        self.videoId = videoId
        self.timestamp = timestamp
        if self.timestamp > 0 {
            self.ignoreEarlierTimestamps = true
        }
        self.status = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: Double(timestamp), baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true)
        
        self.benchmarkStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String, ((Any?) -> Void)?) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void) {
        let bundle = getAppBundle()
        guard let userScriptPath = bundle.path(forResource: "YoutubeUserScript", ofType: "js") else {
            return
        }
        guard let userScriptData = try? Data(contentsOf: URL(fileURLWithPath: userScriptPath)) else {
            return
        }
        guard let userScript = String(data: userScriptData, encoding: .utf8) else {
            return
        }
        guard let htmlTemplatePath = bundle.path(forResource: "Youtube", ofType: "html") else {
            return
        }
        guard let htmlTemplateData = try? Data(contentsOf: URL(fileURLWithPath: htmlTemplatePath)) else {
            return
        }
        guard let htmlTemplate = String(data: htmlTemplateData, encoding: .utf8) else {
            return
        }
        
        let params: [String : Any] = [ "videoId": self.videoId,
                                       "width": "100%",
                                       "height": "100%",
                                       "events": [ "onReady": "onReady",
                                                   "onStateChange": "onStateChange",
                                                   "onPlaybackQualityChange": "onPlaybackQualityChange",
                                                   "onError": "onPlayerError" ],
                                       "playerVars": [ "cc_load_policy": 1,
                                                       "iv_load_policy": 3,
                                                       "controls": 0,
                                                       "playsinline": 1,
                                                       "autohide": 1,
                                                       "showinfo": 0,
                                                       "rel": 0,
                                                       "modestbranding": 1,
                                                       "start": self.timestamp ] ]
        
        guard let paramsJsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted), let paramsJson = String(data: paramsJsonData, encoding: .utf8) else {
            return
        }
        
        self.evalImpl = evaluateJavaScript
        self.updateStatus = updateStatus
        self.onPlaybackStarted = onPlaybackStarted
        updateStatus(self.status)
        
        let html = String(format: htmlTemplate, paramsJson)
        webView.loadHTMLString(html, baseURL: URL(string: "https://telegram.youtube.com"))
//        webView.isUserInteractionEnabled = false
        
        userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
    
    func play() {
        guard self.ready else {
            self.playbackDelay = .afterPositionUpdates(count: 2)
            return
        }
        
        self.isPlaying = true
        
        if let eval = self.evalImpl {
            eval("play();", nil)
        }
        
        self.ignorePosition = 2
    }
    
    func pause() {
        self.isPlaying = false
        if let eval = self.evalImpl {
            eval("pause();", nil)
        }
    }
    
    func togglePlayPause() {
        if case .playing = self.status.status {
            self.pause()
        } else {
            self.play()
        }
    }
    
    func seek(timestamp: Double) {
        if !self.ready {
            self.timestamp = Int(timestamp)
            self.ignoreEarlierTimestamps = true
        }
        
        if let eval = self.evalImpl {
            eval("seek(\(timestamp));", nil)
        }
        
        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: timestamp, baseRate: self.status.baseRate, seekId: self.status.seekId + 1, status: self.status.status, soundEnabled: true)
        self.updateStatus?(self.status)
        
        self.ignorePosition = 2
    }
    
    func setBaseRate(_ baseRate: Double) {
        var baseRate = baseRate
        if baseRate < 0.5 {
            baseRate = 0.5
        }
        if baseRate > 2.0 {
            baseRate = 2.0
        }
        if !self.ready {
            self.baseRate = baseRate
        }
        
        if let eval = self.evalImpl {
            eval("setRate(\(baseRate));", nil)
        }
        
        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: self.status.timestamp, baseRate: baseRate, seekId: self.status.seekId + 1, status: self.status.status, soundEnabled: true)
        self.updateStatus?(self.status)
    }
    
    func pageReady() {
    }
    
    func callback(url: URL) {
        switch url.host {
            case "onState":
                var newTimestamp = self.status.timestamp
                
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    var playback: Int?
                    var position: Double?
                    var duration: Int?
                    var download: Float?
                    var failed: Bool?
                    
                    if let queryItems = components.queryItems {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "playback" {
                                    playback = Int(value)
                                } else if queryItem.name == "position" {
                                    position = Double(value)
                                } else if queryItem.name == "duration" {
                                    duration = Int(value)
                                } else if queryItem.name == "download" {
                                    download = Float(value)
                                } else if queryItem.name == "failed" {
                                    failed = Bool(value)
                                } else if queryItem.name == "storyboard" {
                                    let urlString = url.absoluteString
                                    if value.count > 10, let range = urlString.range(of: "storyboard=") {
                                        self.storyboardSpec = String(urlString[range.upperBound..<urlString.endIndex]).removingPercentEncoding
                                    }
                                }
                            }
                        }
                    }

                    let _ = download
                    let _ = failed
                    
                    if let position = position {
                        if self.ignoreEarlierTimestamps {
                            if position >= Double(self.timestamp) {
                                self.ignoreEarlierTimestamps = false
                                newTimestamp = Double(position)
                            }
                        } else if let ticksToIgnore = self.ignorePosition {
                            if ticksToIgnore > 1 {
                                self.ignorePosition = ticksToIgnore - 1
                            } else {
                                self.ignorePosition = nil
                            }
                        } else {
                            newTimestamp = Double(position)
                        }
                    }
                
                    if let updateStatus = self.updateStatus, let playback = playback, let duration = duration {
                        let playbackStatus: MediaPlayerPlaybackStatus
                        switch playback {
                            case 0:
                                if newTimestamp > Double(duration) - 1.0 {
                                    self.isPlaying = false
                                    playbackStatus = .paused
                                    newTimestamp = 0.0
                                } else {
                                    playbackStatus = .buffering(initial: false, whilePlaying: true, progress: 0.0, display: false)
                                }
                            case 1:
                                playbackStatus = .playing
                            case 2:
                                playbackStatus = .paused
                            case 3:
                                playbackStatus = .buffering(initial: !self.started, whilePlaying: self.isPlaying, progress: 0.0, display: false)
                            default:
                                playbackStatus = .buffering(initial: true, whilePlaying: true, progress: 0.0, display: false)
                        }
                        
                        if case .playing = playbackStatus, !self.started {
                            self.started = true
                            print("YT started in \(CFAbsoluteTimeGetCurrent() - self.benchmarkStartTime)")
                            
                            self.onPlaybackStarted?()
                        }
                        
                        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: Double(duration), dimensions: self.status.dimensions, timestamp: newTimestamp, baseRate: self.status.baseRate, seekId: self.status.seekId, status: playbackStatus, soundEnabled: true)
                        updateStatus(self.status)
                    }
                }
                
                if case let .afterPositionUpdates(count) = self.playbackDelay {
                    if count == 1 {
                        self.ready = true
                        self.playbackDelay = .none
                        self.play()
                    } else {
                        self.playbackDelay = .afterPositionUpdates(count: count - 1)
                    }
                }
            case "onReady":
                self.ready = true
                
                if case .afterPositionUpdates(_) = self.playbackDelay {
                    self.playbackDelay = .none
                    self.play()
                }
                
                if self.baseRate != 1.0 {
                    self.setBaseRate(self.baseRate)
                }
                
                print("YT ready in \(CFAbsoluteTimeGetCurrent() - self.benchmarkStartTime)")

                Queue.mainQueue().async {
                    let delay = self.timestamp > 0 ? 2.8 : 2.0
                    if self.timestamp > 0 {
                        self.seek(timestamp: Double(self.timestamp))
                        self.play()
                    } else {
                        self.play()
                    }
                    Queue.mainQueue().after(delay, {
                        if !self.started {
                            self.play()
                        }
                        self.onPlaybackStarted?()
                    })
                }
            default:
                break
        }
    }
}

public struct YoutubeEmbedStoryboardMediaResourceId {
    public let videoId: String
    public let storyboardId: Int32

    public var uniqueId: String {
        return "youtube-storyboard-\(self.videoId)-\(self.storyboardId)"
    }
    
    public var hashValue: Int {
        return self.uniqueId.hashValue
    }
}

public class YoutubeEmbedStoryboardMediaResource: TelegramMediaResource {
    public let videoId: String
    public let storyboardId: Int32
    public let url: String
    
    public var size: Int64? {
        return nil
    }
    
    public init(videoId: String, storyboardId: Int32, url: String) {
        self.videoId = videoId
        self.storyboardId = storyboardId
        self.url = url
    }
    
    public required init(decoder: PostboxDecoder) {
        self.videoId = decoder.decodeStringForKey("v", orElse: "")
        self.storyboardId = decoder.decodeInt32ForKey("i", orElse: 0)
        self.url = decoder.decodeStringForKey("u", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.videoId, forKey: "v")
        encoder.encodeInt32(self.storyboardId, forKey: "i")
        encoder.encodeString(self.url, forKey: "u")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(YoutubeEmbedStoryboardMediaResourceId(videoId: self.videoId, storyboardId: self.storyboardId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? YoutubeEmbedStoryboardMediaResource {
            return self.videoId == to.videoId && self.storyboardId == to.storyboardId && self.url == to.url
        } else {
            return false
        }
    }
}

public final class YoutubeEmbedStoryboardMediaResourceRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .shortLived
    
    public var uniqueId: String {
        return "cached"
    }
    
    public init() {
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is YoutubeEmbedStoryboardMediaResourceRepresentation {
            return true
        } else {
            return false
        }
    }
}

public func fetchYoutubeEmbedStoryboardResource(resource: YoutubeEmbedStoryboardMediaResource) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
                
        let disposable = MetaDisposable()
        disposable.set(fetchHttpResource(url: resource.url).start(next: { next in
            if case let .dataPart(_, data, _, complete) = next, complete {
                let tempFile = TempBox.shared.tempFile(fileName: "image.jpg")
                if let _ = try? data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) {
                    subscriber.putNext(.tempFile(tempFile))
                    subscriber.putCompletion()
                }
            }
        }))
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}

private func youtubeEmbedStoryboardData(account: Account, resource: YoutubeEmbedStoryboardMediaResource) -> Signal<Data?, NoError> {
    return Signal<Data?, NoError> { subscriber in
        let dataDisposable = account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: YoutubeEmbedStoryboardMediaResourceRepresentation(), complete: true).start(next: { next in
            if next.size != 0 {
                subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
            }
        }, error: subscriber.putError, completed: subscriber.putCompletion)
        
        return ActionDisposable {
            dataDisposable.dispose()
        }
    }
}

private func youtubeEmbedStoryboardImage(account: Account, resource: YoutubeEmbedStoryboardMediaResource, frame: Int32, size: YoutubeEmbedFramePreview.StoryboardSpec.StoryboardSize) -> Signal<UIImage?, NoError> {
    let signal = youtubeEmbedStoryboardData(account: account, resource: resource)
    
    return signal |> map { fullSizeData in
        let drawingSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
        let context = DrawingContext(size: drawingSize, clear: true)
        
        var fullSizeImage: CGImage?
        if let fullSizeData = fullSizeData {
            let options = NSMutableDictionary()
            options[kCGImageSourceShouldCache as NSString] = false as NSNumber
            if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                fullSizeImage = image
            }
            
            if let fullSizeImage = fullSizeImage {
                let rect: CGRect
                let imageSize = CGSize(width: CGFloat(fullSizeImage.width), height: CGFloat(fullSizeImage.height))
                
                let row = floor(CGFloat(frame) / CGFloat(size.cols))
                let col = CGFloat(frame % size.cols)
                
                rect = CGRect(origin: CGPoint(x: -drawingSize.width * col, y: -drawingSize.height * row), size: imageSize)
                
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: rect)
                }
                return context.generateImage()
            }
        }
        return nil
    }
}

public final class YoutubeEmbedFramePreview: FramePreview {
    fileprivate struct StoryboardSpec {
        struct StoryboardSize {
            let width: Int32
            let height: Int32
            let quality: Int32
            let cols: Int32
            let rows: Int32
            let duration: Int32
            let imageName: String
            let sigh: String
        }
        
        let baseUrl: String
        let sizes: [StoryboardSize]
        
        init?(specString: String) {
            let sections = specString.components(separatedBy: "|")
            if sections.count < 2 {
                return nil
            }
            guard let baseUrl = sections.first else {
                return nil
            }
            self.baseUrl = baseUrl
            
            var sizes: [StoryboardSize] = []
            for i in 1 ..< sections.count - 1 {
                let section = sections[i]
                let data = section.components(separatedBy: "#")
                
                if data.count >= 8, let width = Int32(data[0]), let height = Int32(data[1]), let quality = Int32(data[2]), let cols = Int32(data[3]), let rows = Int32(data[4]), let duration = Int32(data[5]) {
                    let size = StoryboardSize(width: width, height: height, quality: quality, cols: cols, rows: rows, duration: duration, imageName: data[6], sigh: data[7])
                    sizes.append(size)
                }
            }
            
            self.sizes = sizes
        }
        
        var bestSize: (Int, StoryboardSize)? {
            var best: (Int, StoryboardSize)?
            for i in 0 ..< self.sizes.count {
                let size = self.sizes[i]
                if let (_, currentBest) = best {
                    if currentBest.width < size.width || (currentBest.width == size.width && currentBest.cols < size.cols) {
                        best = (i, size)
                    }
                } else {
                    best = (i, size)
                }
            }
            return best
        }
    }
    
    private func storyboardUrl(spec: StoryboardSpec, sizeIndex: Int, num: Int32) -> String {
        let size = spec.sizes[sizeIndex]
        
        var url = spec.baseUrl
        url = url.replacingOccurrences(of: "$L", with: "\(sizeIndex)")
        url = url.replacingOccurrences(of: "$N", with: size.imageName)
        url = url.replacingOccurrences(of: "$M", with: "\(num)")
        url += "&sigh=\(size.sigh)"
        
        return url
    }
    
    private let context: AccountContext
    private weak var content: WebEmbedVideoContent?
    
    private let currentFrameDisposable = MetaDisposable()
    private var currentFrameTimestamp: Double?
    private var nextFrameTimestamp: Double?
    fileprivate let framePipe = ValuePipe<FramePreviewResult>()
    
    public init(context: AccountContext, content: WebEmbedVideoContent) {
        self.context = context
        self.content = content
    }
    
    deinit {
        self.currentFrameDisposable.dispose()
    }
    
    public var generatedFrames: Signal<FramePreviewResult, NoError> {
        return self.framePipe.signal()
    }
    
    public func generateFrame(at timestamp: Double) {
        guard let content = self.content else {
            return
        }
        
        if self.currentFrameTimestamp != nil {
            self.nextFrameTimestamp = timestamp
            return
        }
        self.currentFrameTimestamp = timestamp
        
        self.context.sharedContext.mediaManager.universalVideoManager.withUniversalVideoContent(id: content.id) { [weak self] node in
            guard let strongSelf = self, let node = node as? WebEmbedVideoContentNode, let youtubeImpl = node.impl as? YoutubeEmbedImplementation, youtubeImpl.duration > 0.0, let specString = youtubeImpl.storyboardSpec, let storyboardSpec = StoryboardSpec(specString: specString), let bestSize = storyboardSpec.bestSize else {
                return
            }
            
            var duration: Double = Double(bestSize.1.duration) / 1000.0
            var totalFrames: Int32 = 1
            let framesOnStoryboard: Int32 = bestSize.1.cols * bestSize.1.rows
            
            if duration > 0.0 {
                totalFrames = Int32(ceil(youtubeImpl.duration / duration))
            } else {
                duration = youtubeImpl.duration / Double(framesOnStoryboard)
            }
            
            let globalFrame = Int32(floor(timestamp / youtubeImpl.duration * Double(totalFrames)))
            let frame: Int32 = globalFrame % framesOnStoryboard

            let num: Int32 = Int32(floor(Double(globalFrame) / Double(framesOnStoryboard)))
            let url = storyboardUrl(spec: storyboardSpec, sizeIndex: bestSize.0, num: num)
            
            strongSelf.framePipe.putNext(.waitingForData)
            strongSelf.currentFrameDisposable.set(youtubeEmbedStoryboardImage(account: strongSelf.context.account, resource: YoutubeEmbedStoryboardMediaResource(videoId: youtubeImpl.videoId, storyboardId: num, url: url), frame: frame, size: bestSize.1).start(next: { [weak self] image in
                if let strongSelf = self {
                    if let image = image {
                        strongSelf.framePipe.putNext(.image(image))
                    }
                    strongSelf.currentFrameTimestamp = nil
                    if let nextFrameTimestamp = strongSelf.nextFrameTimestamp {
                        strongSelf.nextFrameTimestamp = nil
                        strongSelf.generateFrame(at: nextFrameTimestamp)
                    }
                }
            }))
        }
    }
    
    public func cancelPendingFrames() {
        self.nextFrameTimestamp = nil
        self.currentFrameTimestamp = nil
        self.currentFrameDisposable.set(nil)
    }
}
