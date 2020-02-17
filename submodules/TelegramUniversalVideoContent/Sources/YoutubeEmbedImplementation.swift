import Foundation
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
    private var evalImpl: ((String) -> Void)?
    private var updateStatus: ((MediaPlayerStatus) -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    
    private let videoId: String
    private var timestamp: Int
    private var ignoreEarlierTimestamps = false
    private var status : MediaPlayerStatus
    
    private var ready = false
    private var started = false
    private var ignorePosition: Int?
    
    private enum PlaybackDelay {
        case none
        case afterPositionUpdates(count: Int)
    }
    private var playbackDelay = PlaybackDelay.none
    
    private let benchmarkStartTime: CFAbsoluteTime
    
    init(videoId: String, timestamp: Int = 0) {
        self.videoId = videoId
        self.timestamp = timestamp
        if timestamp > 0 {
            self.ignoreEarlierTimestamps = true
        }
        self.status = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: Double(timestamp), baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true), soundEnabled: true)
        
        self.benchmarkStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void) {
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
        webView.loadHTMLString(html, baseURL: URL(string: "https://youtube.com/"))
        webView.isUserInteractionEnabled = false
        
        userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
    
    func play() {
        guard self.ready else {
            self.playbackDelay = .afterPositionUpdates(count: 2)
            return
        }
        
        if let eval = self.evalImpl {
            eval("play();")
        }
        
        self.ignorePosition = 2
    }
    
    func pause() {
        if let eval = self.evalImpl {
            eval("pause();")
        }
    }
    
    func togglePlayPause() {
        if case .playing = self.status.status {
            pause()
        } else {
            play()
        }
    }
    
    func seek(timestamp: Double) {
        if !self.ready {
            self.timestamp = Int(timestamp)
            self.ignoreEarlierTimestamps = true
        }
        
        if let eval = evalImpl {
            eval("seek(\(timestamp));")
        }
        
        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: timestamp, baseRate: 1.0, seekId: self.status.seekId + 1, status: self.status.status, soundEnabled: true)
        self.updateStatus?(self.status)
        
        self.ignorePosition = 2
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
                                }
                            }
                        }
                    }
                    
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
                                    playbackStatus = .paused
                                    newTimestamp = 0.0
                                } else {
                                    playbackStatus = .buffering(initial: false, whilePlaying: true)
                                }
                            case 1:
                                playbackStatus = .playing
                            case 2:
                                playbackStatus = .paused
                            case 3:
                                playbackStatus = .buffering(initial: false, whilePlaying: true)
                            default:
                                playbackStatus = .buffering(initial: true, whilePlaying: false)
                        }
                        
                        if case .playing = playbackStatus, !self.started {
                            self.started = true
                            print("YT started in \(CFAbsoluteTimeGetCurrent() - self.benchmarkStartTime)")
                            
                            self.onPlaybackStarted?()
                        }
                        
                        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: Double(duration), dimensions: self.status.dimensions, timestamp: newTimestamp, baseRate: 1.0, seekId: self.status.seekId, status: playbackStatus, soundEnabled: true)
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
                
                print("YT ready in \(CFAbsoluteTimeGetCurrent() - self.benchmarkStartTime)")

                Queue.mainQueue().async {
                    self.play()
                    
                    let delay = self.timestamp > 0 ? 2.8 : 2.0
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
