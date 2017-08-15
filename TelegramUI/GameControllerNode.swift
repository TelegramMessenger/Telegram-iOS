import Foundation
import Display
import AsyncDisplayKit
import WebKit

private class WeakGameScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

final class GameControllerNode: ViewControllerTracingNode {
    private var webView: WKWebView?
    
    var presentationData: PresentationData
    
    init(presentationData: PresentationData, url: String) {
        self.presentationData = presentationData
        
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
        
        userController.add(WeakGameScriptMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")
        
        configuration.userContentController = userController
        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        if #available(iOSApplicationExtension 9.0, *) {
            webView.allowsLinkPreview = false
        }
        self.webView = webView

        self.view.addSubview(webView)
        
        if let parsedUrl = URL(string: url) {
            webView.load(URLRequest(url: parsedUrl))
        }
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
        
        if eventName == "share_game" || eventName == "share_score" {
            
        }
    }
}
