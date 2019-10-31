import Foundation
import UIKit
import Display
import AsyncDisplayKit
import WebKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

final class ChannelStatsControllerNode: ViewControllerTracingNode, WKNavigationDelegate {
    private var webView: WKWebView?
    
    private let context: AccountContext
    private let peerId: PeerId
    var presentationData: PresentationData
    private let present: (ViewController, Any?) -> Void
    private let updateActivity: (Bool) -> Void
    
    private let refreshDisposable = MetaDisposable()
    
    init(context: AccountContext, presentationData: PresentationData, peerId: PeerId, url: String, present: @escaping (ViewController, Any?) -> Void, updateActivity: @escaping (Bool) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.peerId = peerId
        self.present = present
        self.updateActivity = updateActivity
        
        super.init()
        
        self.backgroundColor = .white
        
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        configuration.userContentController = userController
        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            webView.allowsLinkPreview = false
        }
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
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
            webView.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight)))
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
        if let url = navigationAction.request.url, url.scheme == "tg" {
            if url.host == "statsrefresh" {
                var params = ""
                if let query = url.query, let components = URLComponents(string: "/?" + query) {
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
                self.refreshDisposable.set((channelStatsUrl(postbox: self.context.account.postbox, network: self.context.account.network, peerId: self.peerId, params: params, darkTheme: self.presentationData.theme.rootController.keyboardColor.keyboardAppearance == .dark)
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
    
    private func updateActivityIndicator(show: Bool) {
        self.updateActivity(show)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.updateActivityIndicator(show: false)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.updateActivityIndicator(show: true)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.updateActivityIndicator(show: false)
    }
}
