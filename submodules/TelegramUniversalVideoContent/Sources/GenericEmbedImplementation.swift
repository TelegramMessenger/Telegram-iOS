import Foundation
import WebKit
import SwiftSignalKit
import UniversalMediaPlayer
import AppBundle

final class GenericEmbedImplementation: WebEmbedImplementation {
    private var evalImpl: ((String, ((Any?) -> Void)?) -> Void)?
    private var updateStatus: ((MediaPlayerStatus) -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    private var status : MediaPlayerStatus
    
    private let url: String
    
    init(url: String) {
        self.url = url
        self.status = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true)
    }
    
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String, ((Any?) -> Void)?) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void) {
        let bundle = getAppBundle()
        guard let userScriptPath = bundle.path(forResource: "GenericUserScript", ofType: "js") else {
            return
        }
        guard let userScriptData = try? Data(contentsOf: URL(fileURLWithPath: userScriptPath)) else {
            return
        }
        guard let userScript = String(data: userScriptData, encoding: .utf8) else {
            return
        }
        guard let htmlTemplatePath = bundle.path(forResource: "Generic", ofType: "html") else {
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
        
        if self.url.contains(".twitch.tv/"), let url = URL(string: self.url) {
            webView.load(URLRequest(url: url))
        } else {
            let html = String(format: htmlTemplate, self.url)
            webView.loadHTMLString(html, baseURL: URL(string: "about:blank"))
        }
        
        userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        
        if self.url.hasSuffix(".mp4") || self.url.hasSuffix(".mov") {
            if let onPlaybackStarted = self.onPlaybackStarted {
                onPlaybackStarted()
            }
        }
    }
    
    func play() {
    }
    
    func pause() {
    }
    
    func togglePlayPause() {
    }
    
    func seek(timestamp: Double) {
    }
    
    func setBaseRate(_ baseRate: Double) {
    }
    
    func pageReady() {
        self.status = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .playing, soundEnabled: true)
        self.updateStatus?(self.status)
        
        if let onPlaybackStarted = self.onPlaybackStarted {
            onPlaybackStarted()
        }
    }
    
    func callback(url: URL) {
    }
}
