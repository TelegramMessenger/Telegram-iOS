import Foundation
import UIKit
import Display
import AsyncDisplayKit
import WebKit
import TelegramPresentationData

private class WeakPaymentScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

final class BotCheckoutWebInteractionControllerNode: ViewControllerTracingNode, WKNavigationDelegate {
    private var presentationData: PresentationData
    private let intent: BotCheckoutWebInteractionControllerIntent
    
    private var webView: WKWebView?
    
    init(presentationData: PresentationData, url: String, intent: BotCheckoutWebInteractionControllerIntent) {
        self.presentationData = presentationData
        self.intent = intent
        
        super.init()
        
        self.backgroundColor = .white
        
        let webView: WKWebView
        switch intent {
            case .addPaymentMethod:
                let js = "var TelegramWebviewProxyProto = function() {}; " +
                    "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
                    "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
                    "}; " +
                "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
                
                let configuration = WKWebViewConfiguration()
                let userController = WKUserContentController()
                
                let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                userController.addUserScript(userScript)
                
                userController.add(WeakPaymentScriptMessageHandler { [weak self] message in
                    if let strongSelf = self {
                        strongSelf.handleScriptMessage(message)
                    }
                }, name: "performAction")
                
                configuration.userContentController = userController
                
                webView = WKWebView(frame: CGRect(), configuration: configuration)
                if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                    webView.allowsLinkPreview = false
                }
            case .externalVerification:
                webView = WKWebView()
                if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                    webView.allowsLinkPreview = false
                }
                webView.navigationDelegate = self
        }
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.webView = webView
        self.view.addSubview(webView)
        
        if let parsedUrl = URL(string: url) {
            webView.load(URLRequest(url: parsedUrl))
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.webView?.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height - navigationBarHeight)))
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
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
        
        if eventName == "payment_form_submit" {
            guard let eventString = body["eventData"] as? String else {
                return
            }
            
            guard let eventData = eventString.data(using: .utf8) else {
                return
            }
            
            guard let dict = (try? JSONSerialization.jsonObject(with: eventData, options: [])) as? [String: Any] else {
                return
            }
            
            guard let title = dict["title"] as? String else {
                return
            }
            
            guard let credentials = dict["credentials"] else {
                return
            }
            
            guard let credentialsData = try? JSONSerialization.data(withJSONObject: credentials, options: []) else {
                return
            }
            
            guard let credentialsString = String(data: credentialsData, encoding: .utf8) else {
                return
            }
            
            if case let .addPaymentMethod(completion) = self.intent {
                completion(BotCheckoutPaymentWebToken(title: title, data: credentialsString, saveOnServer: false))
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if case let .externalVerification(completion) = self.intent, let host = navigationAction.request.url?.host {
            if host == "t.me" || host == "telegram.me" {
                decisionHandler(.cancel)
                completion(true)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}
