import Foundation
import WebKit
import SwiftSignalKit
import UniversalMediaPlayer
import AppBundle

func isTwitchVideoUrl(_ url: String) -> Bool {
    return url.contains("//player.twitch.tv/") || url.contains("//clips.twitch.tv/")
}

final class TwitchEmbedImplementation: WebEmbedImplementation {
    private var evalImpl: ((String, ((Any?) -> Void)?) -> Void)?
    private var updateStatus: ((MediaPlayerStatus) -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    
    private let url: String
    private var status : MediaPlayerStatus
    
    private var started = false
    
    init(url: String) {
        self.url = url
        self.status = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true)
    }
    
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String, ((Any?) -> Void)?) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void) {
        let bundle = getAppBundle()
        guard let userScriptPath = bundle.path(forResource: "TwitchUserScript", ofType: "js") else {
            return
        }
        guard let userScriptData = try? Data(contentsOf: URL(fileURLWithPath: userScriptPath)) else {
            return
        }
        guard let userScript = String(data: userScriptData, encoding: .utf8) else {
            return
        }
        guard let htmlTemplatePath = bundle.path(forResource: "Twitch", ofType: "html") else {
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
        
        let html = String(format: htmlTemplate, self.url)
        webView.loadHTMLString(html, baseURL: URL(string: "about:blank"))
        
        userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
    
    func play() {
        if let eval = self.evalImpl {
            eval("playPause()", nil)
        }
        
        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: self.status.timestamp, baseRate: 1.0, seekId: self.status.seekId, status: .playing, soundEnabled: self.status.soundEnabled)
        if let updateStatus = self.updateStatus {
            updateStatus(self.status)
        }
    }
    
    func pause() {
        if let eval = self.evalImpl {
            eval("playPause()", nil)
        }
        
        self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: self.status.timestamp, baseRate: 1.0, seekId: self.status.seekId, status: .paused, soundEnabled: self.status.soundEnabled)
        if let updateStatus = self.updateStatus {
            updateStatus(self.status)
        }
    }
    
    func togglePlayPause() {
        if self.status.status == .playing {
            self.pause()
        } else {
            self.play()
        }
    }
    
    func seek(timestamp: Double) {
    }
    
    func setBaseRate(_ baseRate: Double) {
    }
    
    func pageReady() {
//        Queue.mainQueue().after(delay: 0.5) {
//            if let onPlaybackStarted = self.onPlaybackStarted {
//                onPlaybackStarted()
//            }
//        }
    }
    
    func callback(url: URL) {
         switch url.host {
            case "onPlayback":
                if !self.started {
                    self.started = true
                    self.status = MediaPlayerStatus(generationTimestamp: self.status.generationTimestamp, duration: self.status.duration, dimensions: self.status.dimensions, timestamp: self.status.timestamp, baseRate: 1.0, seekId: self.status.seekId, status: .playing, soundEnabled: self.status.soundEnabled)
                    if let updateStatus = self.updateStatus {
                        updateStatus(self.status)
                    }
                    
                    if let onPlaybackStarted = self.onPlaybackStarted {
                         onPlaybackStarted()
                     }
                }
            default:
                break
        }
    }
}
