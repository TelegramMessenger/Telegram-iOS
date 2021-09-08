import Foundation
import UIKit
import TelegramCore
import WebKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private class WeakInstantPageWebEmbedNodeMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

final class InstantPageWebEmbedNode: ASDisplayNode, InstantPageNode {
    let url: String?
    let html: String?
    let updateWebEmbedHeight: (CGFloat) -> Void
    
    private var webView: WKWebView?
    
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool, updateWebEmbedHeight: @escaping (CGFloat) -> Void) {
        self.url = url
        self.html = html
        self.updateWebEmbedHeight = updateWebEmbedHeight
        
        super.init()
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
            "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
            "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
            "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
        
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        userController.add(WeakInstantPageWebEmbedNodeMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")
        
        configuration.userContentController = userController
        
        let webView = WKWebView(frame: CGRect(origin: CGPoint(), size: frame.size), configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            webView.allowsLinkPreview = false
        }
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.scrollView.isScrollEnabled = enableScrolling
        
        if let html = html {
            webView.loadHTMLString(html, baseURL: nil)
        } else if let url = url, let parsedUrl = URL(string: url) {
            var request = URLRequest(url: parsedUrl)
            if let scheme = parsedUrl.scheme, let host = parsedUrl.host {
                let referrer = "\(scheme)://\(host)"
                request.setValue(referrer, forHTTPHeaderField: "Referer")
            }
            webView.load(request)
        }
        self.webView = webView
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String, let eventString = body["eventData"] as? String else {
            return
        }
        
        guard let eventData = eventString.data(using: .utf8) else {
            return
        }
        
        guard let dict = (try? JSONSerialization.jsonObject(with: eventData, options: [])) as? [String: Any] else {
            return
        }
        
        if eventName == "resize_frame", let height = dict["height"] as? Int {
            self.updateWebEmbedHeight(CGFloat(height))
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let webView = self.webView {
            self.view.addSubview(webView)
        }
    }
    
    override func layout() {
        super.layout()
        
        self.webView?.frame = self.bounds
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
}
