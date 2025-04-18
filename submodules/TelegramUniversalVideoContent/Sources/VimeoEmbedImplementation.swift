import Foundation
import WebKit
import SwiftSignalKit
import UniversalMediaPlayer
import AppBundle

func extractVimeoVideoIdAndTimestamp(url: String) -> (String, Int)? {
    guard let url = URL(string: url), let host = url.host?.lowercased() else {
        return nil
    }
    
    let match = ["vimeo.com", "player.vimeo.com"].contains(where: { (domain) -> Bool in
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
                    if queryItem.name == "t" {
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
            var nextComponentIsVideoId = false
            
            for component in pathComponents {
                if !component.isEmpty && (CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: component)) || nextComponentIsVideoId) {
                    videoId = component
                    break
                } else if component == "video" {
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

final class VimeoEmbedImplementation: WebEmbedImplementation {
    private var evalImpl: ((String, ((Any?) -> Void)?) -> Void)?
    private var updateStatus: ((MediaPlayerStatus) -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    
    private let videoId: String
    private let timestamp: Int
    private var baseRate: Double = 1.0
    private var status : MediaPlayerStatus
    
    private var ready: Bool = false
    private var started: Bool = false
    private var ignorePosition: Int?
    
    init(videoId: String, timestamp: Int = 0) {
        self.videoId = videoId
        self.timestamp = timestamp
        self.status = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: Double(timestamp), baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true)
    }
    
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String, ((Any?) -> Void)?) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void) {
        let bundle = getAppBundle()
        guard let userScriptPath = bundle.path(forResource: "VimeoUserScript", ofType: "js") else {
            return
        }
        guard let userScriptData = try? Data(contentsOf: URL(fileURLWithPath: userScriptPath)) else {
            return
        }
        guard let userScript = String(data: userScriptData, encoding: .utf8) else {
            return
        }
        guard let htmlTemplatePath = bundle.path(forResource: "Vimeo", ofType: "html") else {
            return
        }
        guard let htmlTemplateData = try? Data(contentsOf: URL(fileURLWithPath: htmlTemplatePath)) else {
            return
        }
        guard let htmlTemplate = String(data: htmlTemplateData, encoding: .utf8) else {
            return
        }
        
        self.evalImpl = evaluateJavaScript
        self.updateStatus = updateStatus
        self.onPlaybackStarted = onPlaybackStarted
        updateStatus(self.status)
        
        let html = String(format: htmlTemplate, self.videoId, "true")
        webView.loadHTMLString(html, baseURL: URL(string: "https://player.vimeo.com/"))
        webView.isUserInteractionEnabled = false
        
        userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
    
    func play() {
        if let eval = self.evalImpl {
            eval("play();", nil)
        }
        
        ignorePosition = 2
    }
    
    func pause() {
        if let eval = self.evalImpl {
            eval("pause();", nil)
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
        if let eval = self.evalImpl {
            eval("seek(\(timestamp));", nil)
        }
        
        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: timestamp, baseRate: self.status.baseRate, seekId: self.status.seekId + 1, status: self.status.status, soundEnabled: self.status.soundEnabled)
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
        if url.host == "onState" {
            var newTimestamp = self.status.timestamp
            
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var playback: Int?
                var position: Double?
                var duration: Double?
                var download: Float?
                //var failed: Bool?
                
                if let queryItems = components.queryItems {
                    for queryItem in queryItems {
                        if let value = queryItem.value {
                            if queryItem.name == "playback" {
                                playback = Int(value)
                            } else if queryItem.name == "position" {
                                position = Double(value)
                            } else if queryItem.name == "duration" {
                                duration = Double(value)
                            } else if queryItem.name == "download" {
                                download = Float(value)
                            }
                        }
                    }
                }

                let _ = download
                
                if let position = position {
                    if let ticksToIgnore = self.ignorePosition {
                        if ticksToIgnore > 1 {
                            self.ignorePosition = ticksToIgnore - 1
                        } else {
                            self.ignorePosition = nil
                        }
                    } else {
                        newTimestamp = Double(position)
                    }
                }
                
                if !self.ready {
                    self.ready = true
                    self.play()
                }
                
                if let updateStatus = self.updateStatus, let playback = playback, let duration = duration {
                    let playbackStatus: MediaPlayerPlaybackStatus
                    switch playback {
                    case 0:
                        playbackStatus = .paused
                    case 1:
                        playbackStatus = .playing
                    case 2:
                        playbackStatus = .paused
                        newTimestamp = 0.0
                    default:
                        playbackStatus = .buffering(initial: true, whilePlaying: false, progress: 0.0, display: true)
                    }
                    
                    if case .playing = playbackStatus, !self.started {
                        self.started = true
                        Queue.mainQueue().after(0.5) {
                            self.onPlaybackStarted?()
                        }
                    }
                    
                    self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: Double(duration), dimensions: self.status.dimensions, timestamp: newTimestamp, baseRate: self.status.baseRate, seekId: self.status.seekId, status: playbackStatus, soundEnabled: true)
                    updateStatus(self.status)
                }
            }
        }
    }
}
