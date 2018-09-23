import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import WebKit

protocol WebEmbedImplementation {
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void)
    
    func play()
    func pause()
    func togglePlayPause()
    func seek(timestamp: Double)
    
    func pageReady()
    func callback(url: URL)
}

func webEmbedImplementation(embedUrl: String, url: String) -> WebEmbedImplementation {
    if let (videoId, timestamp) = extractYoutubeVideoIdAndTimestamp(url: url) {
        return YoutubeEmbedImplementation(videoId: videoId, timestamp: timestamp)
    } else if let (videoId, timestamp) = extractVimeoVideoIdAndTimestamp(url: url) {
        return VimeoEmbedImplementation(videoId: videoId, timestamp: timestamp)
    }
    
    return GenericEmbedImplementation(url: url)
}

final class WebEmbedPlayerNode: ASDisplayNode, WKNavigationDelegate {
    private let statusValue = ValuePromise<MediaPlayerStatus>(MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused), ignoreRepeated: true)
    
    var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusValue.get()
    }
    
    private var readyValue: ValuePromise<Bool> = ValuePromise<Bool>(false)
    
    var ready: Signal<Bool, NoError> {
        return self.readyValue.get()
    }
    
    private let impl: WebEmbedImplementation
    
    private let intrinsicDimensions: CGSize
    private let webView: WKWebView
    
    private let semaphore = DispatchSemaphore(value: 0)
    private let queue = Queue()
    
    init(impl: WebEmbedImplementation, intrinsicDimensions: CGSize) {
        self.impl = impl
        self.intrinsicDimensions = intrinsicDimensions
        
        let userContentController = WKUserContentController()
        userContentController.addUserScript(WKUserScript(source: "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta)", injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.userContentController = userContentController
        
        if #available(iOSApplicationExtension 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else if #available(iOSApplicationExtension 9.0, *) {
            config.requiresUserActionForMediaPlayback = false
        } else {
            config.mediaPlaybackRequiresUserAction = false
        }
        
        if #available(iOSApplicationExtension 9.0, *) {
            config.allowsPictureInPictureMediaPlayback = false
        }

        let frame = CGRect(origin: CGPoint.zero, size: intrinsicDimensions)
        self.webView = WKWebView(frame: frame, configuration: config)
        
        super.init()
        self.frame = frame
        
        self.webView.navigationDelegate = self
        self.webView.scrollView.isScrollEnabled = false
        if #available(iOSApplicationExtension 11.0, *) {
            self.webView.accessibilityIgnoresInvertColors = true
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.view.addSubview(self.webView)
        
        self.impl.setup(self.webView, userContentController: userContentController, evaluateJavaScript: { [weak self] js in
            if let strongSelf = self {
                strongSelf.evaluateJavaScript(js: js)
            }
        }, updateStatus: { [weak self] status in
            if let strongSelf = self {
                strongSelf.statusValue.set(status)
            }
        }, onPlaybackStarted: { [weak self] in
            if let strongSelf = self {
                strongSelf.readyValue.set(true)
            }
        })
    }
    
    func play() {
        self.impl.play()
    }
    
    func pause() {
        self.impl.pause()
    }
    
    func togglePlayPause() {
        self.impl.togglePlayPause()
    }
    
    func seek(timestamp: Double) {
        self.impl.seek(timestamp: timestamp)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.impl.pageReady()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let error = error as? WKError, error.code.rawValue == 204 {
            return
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme == "embed" {
            self.impl.callback(url: url)
            decisionHandler(.cancel)
        } else if let _ = navigationAction.targetFrame {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
    
    private func evaluateJavaScript(js: String) {
        self.queue.async { [weak self] in
            if let strongSelf = self {
                let impl = {
                    strongSelf.webView.evaluateJavaScript(js, completionHandler: { (_, _) in
                        strongSelf.semaphore.signal()
                    })
                }
                
                Queue.mainQueue().async(impl)
                strongSelf.semaphore.wait()
            }
        }
    }
}
