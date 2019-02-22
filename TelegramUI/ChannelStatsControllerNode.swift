import Foundation
import Display
import AsyncDisplayKit
import WebKit
import TelegramCore
import Postbox
import SwiftSignalKit

private class WeakChannelStatsScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

final class ChannelStatsControllerNode: ViewControllerTracingNode, WKNavigationDelegate {
    private var webView: WKWebView?
    
    private let context: AccountContext
    private let peerId: PeerId
    var presentationData: PresentationData
    private let present: (ViewController, Any?) -> Void
    
    private let refreshDisposable = MetaDisposable()
    
    init(context: AccountContext, presentationData: PresentationData, peerId: PeerId, url: String, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.peerId = peerId
        self.present = present
        
        super.init()
        
        self.backgroundColor = .white
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
            "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
            "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
            "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
        
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        userController.add(WeakChannelStatsScriptMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")
        
        configuration.userContentController = userController
        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        if #available(iOSApplicationExtension 9.0, *) {
            webView.allowsLinkPreview = false
        }
        if #available(iOSApplicationExtension 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.navigationDelegate = self
        webView.interactiveTransitionGestureRecognizerTest = { point -> Bool in
            return point.x > 30.0
        }
        
        self.view.addSubview(webView)
        self.webView = webView
        
        if let parsedUrl = URL(string: url) {
            webView.load(URLRequest(url: parsedUrl))
        }
    }
    
    deinit {
        self.refreshDisposable.dispose()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        if let webView = self.webView {
            webView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height - navigationBarHeight)))
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String else {
            return
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
        if let url = navigationAction.request.url, url.scheme == "tg" {
            if url.path == "statsrefresh" {
                var params = ""
                if let query = url.query, let components = URLComponents(string: "/" + query) {
                    if let queryItems = components.queryItems {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "params" {
                                    params = value
                                }
                            }
                        }
                    }
                }
                self.refreshDisposable.set((channelStatsUrl(postbox: self.context.account.postbox, network: self.context.account.network, peerId: self.peerId, params: params)
                |> deliverOnMainQueue).start(next: { [weak self] url in
                    guard let strongSelf = self else {
                        return
                    }
                    if let parsedUrl = URL(string: url) {
                        strongSelf.webView?.load(URLRequest(url: parsedUrl))
                    }
                }, error: { _ in
                    
                }))
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
