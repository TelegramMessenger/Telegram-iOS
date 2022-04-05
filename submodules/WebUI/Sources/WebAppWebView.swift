import Foundation
import UIKit
import Display
import WebKit
import SwiftSignalKit

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

private class WebViewTouchGestureRecognizer: UITapGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = .began
    }
}

final class WebAppWebView: WKWebView {
    var handleScriptMessage: (WKScriptMessage) -> Void = { _ in }
    
    init() {
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
            "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
            "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
            "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
                   
        var handleScriptMessageImpl: ((WKScriptMessage) -> Void)?
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        userController.add(WeakGameScriptMessageHandler { message in
            handleScriptMessageImpl?(message)
        }, name: "performAction")
        
        let selectionString = "var css = '*{-webkit-touch-callout:none;} :not(input):not(textarea){-webkit-user-select:none;}';"
                + " var head = document.head || document.getElementsByTagName('head')[0];"
                + " var style = document.createElement('style'); style.type = 'text/css';" +
                " style.appendChild(document.createTextNode(css)); head.appendChild(style);"
        let selectionScript: WKUserScript = WKUserScript(source: selectionString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userController.addUserScript(selectionScript)
        
        configuration.userContentController = userController
        
        configuration.allowsInlineMediaPlayback = true
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            configuration.requiresUserActionForMediaPlayback = false
        } else {
            configuration.mediaPlaybackRequiresUserAction = false
        }
        
        super.init(frame: CGRect(), configuration: configuration)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            self.allowsLinkPreview = false
        }
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.interactiveTransitionGestureRecognizerTest = { point -> Bool in
            return point.x > 30.0
        }
        self.allowsBackForwardNavigationGestures = false
        
        handleScriptMessageImpl = { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }
        
//        let tapGestureRecognizer = WebViewTouchGestureRecognizer(target: self, action: #selector(self.handleTap))
//        tapGestureRecognizer.delegate = self
//        self.addGestureRecognizer(tapGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if #available(iOS 11.0, *) {
            let webScrollView = self.subviews.compactMap { $0 as? UIScrollView }.first
            Queue.mainQueue().after(0.1, {
                let contentView = webScrollView?.subviews.first(where: { $0.interactions.count > 1 })
                guard let dragInteraction = (contentView?.interactions.compactMap { $0 as? UIDragInteraction }.first) else {
                    return
                }
                contentView?.removeInteraction(dragInteraction)
            })
        }
    }
    
    func sendEvent(name: String, data: String?) {
        let script = "window.TelegramGameProxy.receiveEvent(\"\(name)\", \(data ?? "null"))"
        self.evaluateJavaScript(script, completionHandler: { _, _ in
        })
    }
        
    func updateFrame(frame: CGRect, transition: ContainedViewLayoutTransition) {
        self.sendEvent(name: "viewport_changed", data: "{height:\(frame.height)}")
    }
    
    private(set) var didTouchOnce = true
    @objc func handleTap() {
        self.didTouchOnce = true
    }
    
    override var inputAccessoryView: UIView? {
        return nil
    }
}
