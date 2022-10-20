import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import WebKit
import TelegramCore
import UniversalMediaPlayer

protocol WebEmbedImplementation {
    func setup(_ webView: WKWebView, userContentController: WKUserContentController, evaluateJavaScript: @escaping (String, ((Any?) -> Void)?) -> Void, updateStatus: @escaping (MediaPlayerStatus) -> Void, onPlaybackStarted: @escaping () -> Void)
    
    func play()
    func pause()
    func togglePlayPause()
    func seek(timestamp: Double)
    func setBaseRate(_ baseRate: Double)
    
    func pageReady()
    func callback(url: URL)
}

public enum WebEmbedType {
    case youtube(videoId: String, timestamp: Int)
    case vimeo(videoId: String, timestamp: Int)
    case twitch(url: String)
    case iframe(url: String)
    
    public var supportsSeeking: Bool {
        switch self {
        case .youtube, .vimeo:
            return true
        default:
            return false
        }
    }
}

public func webEmbedType(content: TelegramMediaWebpageLoadedContent, forcedTimestamp: Int? = nil) -> WebEmbedType {
    if let (videoId, timestamp) = extractYoutubeVideoIdAndTimestamp(url: content.url) {
        return .youtube(videoId: videoId, timestamp: forcedTimestamp ?? timestamp)
    } else if let embedUrl = content.embedUrl, let (videoId, timestamp) = extractYoutubeVideoIdAndTimestamp(url: embedUrl) {
        return .youtube(videoId: videoId, timestamp: forcedTimestamp ?? timestamp)
    } else if let (videoId, timestamp) = extractVimeoVideoIdAndTimestamp(url: content.url) {
        return .vimeo(videoId: videoId, timestamp: forcedTimestamp ?? timestamp)
    } else if let embedUrl = content.embedUrl, isTwitchVideoUrl(embedUrl) && false {
        return .twitch(url: embedUrl)
    } else {
        return .iframe(url: content.embedUrl ?? content.url)
    }
}

func webEmbedImplementation(for type: WebEmbedType) -> WebEmbedImplementation {
    switch type {
        case let .youtube(videoId, timestamp):
            return YoutubeEmbedImplementation(videoId: videoId, timestamp: timestamp)
        case let .vimeo(videoId, timestamp):
            return VimeoEmbedImplementation(videoId: videoId, timestamp: timestamp)
        case let .twitch(url):
            return TwitchEmbedImplementation(url: url)
        case let .iframe(url):
            return GenericEmbedImplementation(url: url)
    }
}

final class WebEmbedPlayerNode: ASDisplayNode, WKNavigationDelegate {
    private let statusValue = ValuePromise<MediaPlayerStatus>(MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true), ignoreRepeated: true)
    
    var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusValue.get()
    }
    
    private var readyValue: ValuePromise<Bool> = ValuePromise<Bool>(false)
    
    var ready: Signal<Bool, NoError> {
        return self.readyValue.get()
    }
    
    let impl: WebEmbedImplementation
    
    private let openUrl: (URL) -> Void
    private let intrinsicDimensions: CGSize
    private let webView: WKWebView
    
    private let semaphore = DispatchSemaphore(value: 0)
    private let queue = Queue()
    
    init(impl: WebEmbedImplementation, intrinsicDimensions: CGSize, openUrl: @escaping (URL) -> Void) {
        self.impl = impl
        self.intrinsicDimensions = intrinsicDimensions
        self.openUrl = openUrl
        
        let userContentController = WKUserContentController()
        if impl is YoutubeEmbedImplementation {
            
        } else {
            userContentController.addUserScript(WKUserScript(source: "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta)", injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController = userContentController
        
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.mediaPlaybackRequiresUserAction = false
        }
        
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = false
        }

        let frame = CGRect(origin: CGPoint.zero, size: intrinsicDimensions)
        self.webView = WKWebView(frame: frame, configuration: configuration)
        
        super.init()
        self.frame = frame
        
        self.webView.navigationDelegate = self
        self.webView.scrollView.isScrollEnabled = false
        self.webView.allowsLinkPreview = false
        self.webView.allowsBackForwardNavigationGestures = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.webView.accessibilityIgnoresInvertColors = true
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.view.addSubview(self.webView)
        
        self.impl.setup(self.webView, userContentController: userContentController, evaluateJavaScript: { [weak self] js, completion in
            self?.evaluateJavaScript(js: js, completion: completion)
        }, updateStatus: { [weak self] status in
            self?.statusValue.set(status)
        }, onPlaybackStarted: { [weak self] in
            self?.readyValue.set(true)
        })
    }
    
    deinit {
        let webView = self.webView
        Queue.mainQueue().after(1.0) {
            print(webView.debugDescription)
        }
        func disableGestures(view: UIView) {
            if let recognizers = view.gestureRecognizers {
                for recognizer in recognizers {
                    recognizer.isEnabled = false
                }
            }
            for subview in view.subviews {
                disableGestures(view: subview)
            }
        }
        
        disableGestures(view: self.webView)
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
    
    func setBaseRate(_ baseRate: Double) {
        self.impl.setBaseRate(baseRate)
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
            if let url = navigationAction.request.url, url.absoluteString.contains("youtube") {
                self.openUrl(url)
            }
            decisionHandler(.cancel)
        }
    }
    
    private func evaluateJavaScript(js: String, completion: ((Any?) -> Void)?) {
        self.queue.async { [weak self] in
            if let strongSelf = self {
                let impl = {
                    strongSelf.webView.evaluateJavaScript(js, completionHandler: { (result, _) in
                        strongSelf.semaphore.signal()
                        if let completion = completion {
                            completion(result)
                        }
                    })
                }
                
                Queue.mainQueue().async(impl)
                strongSelf.semaphore.wait()
            }
        }
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
        if impl is YoutubeEmbedImplementation {
            self.webView.isUserInteractionEnabled = !hidden
        }
    }

    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
    }
}
