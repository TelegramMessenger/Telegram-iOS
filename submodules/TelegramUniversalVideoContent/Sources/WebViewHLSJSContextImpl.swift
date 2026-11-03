import Foundation
import UIKit
@preconcurrency import WebKit
import SwiftSignalKit

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

final class WebViewHLSJSContextImpl: HLSJSContext {
    let webView: WKWebView
    
    init(handleScriptMessage: @escaping ([String: Any]) -> Void) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        let userController = WKUserContentController()
        
        var handleScriptMessageImpl: (([String: Any]) -> Void)?
        userController.add(WeakScriptMessageHandler { message in
            guard let body = message.body as? [String: Any] else {
                return
            }
            handleScriptMessageImpl?(body)
        }, name: "performAction")
        
        let isDebug: Bool
        #if DEBUG
        isDebug = true
        #else
        isDebug = false
        #endif
        
        config.userContentController = userController
        
        let webView = WKWebView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 100.0)), configuration: config)
        self.webView = webView
        
        webView.scrollView.isScrollEnabled = false
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.accessibilityIgnoresInvertColors = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.alpha = 0.0
        
        if #available(iOS 16.4, *) {
            webView.isInspectable = isDebug
        }
        
        handleScriptMessageImpl = { message in
            Queue.mainQueue().async {
                handleScriptMessage(message)
            }
        }
        
        let bundle = Bundle(for: WebViewHLSJSContextImpl.self)
        let bundlePath = bundle.bundlePath + "/HlsBundle.bundle"
        webView.loadFileURL(URL(fileURLWithPath: bundlePath + "/index.html"), allowingReadAccessTo: URL(fileURLWithPath: bundlePath))
    }
    
    func evaluateJavaScript(_ string: String) {
        self.webView.evaluateJavaScript(string, completionHandler: nil)
    }
}
