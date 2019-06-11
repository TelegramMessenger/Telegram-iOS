import Foundation
import UIKit
import AsyncDisplayKit
import Display
import WebKit

final class WebControllerNode: ViewControllerTracingNode {
    private let webView: WKWebView
    
    init(url: URL) {
        let configuration = WKWebViewConfiguration()
        self.webView = WKWebView(frame: CGRect(), configuration: configuration)
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            self.webView.allowsLinkPreview = false
        }
        self.webView.allowsBackForwardNavigationGestures = true
        //webView.navigationDelegate = self
            
        super.init()
        
        self.view.addSubview(self.webView)
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.webView.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 10.0)
        
        self.webView.load(URLRequest(url: url))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        transition.animateView {
            self.webView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height)))
        }
    }
}
