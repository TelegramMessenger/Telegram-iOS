import Foundation
import Display
import AsyncDisplayKit
import WebKit

final class GameControllerNode: ViewControllerTracingNode {
    private let webView: WKWebView
    
    var presentationData: PresentationData
    
    init(presentationData: PresentationData, url: String) {
        self.presentationData = presentationData
        
        self.webView = WKWebView()
        
        super.init()
        
        self.view.addSubview(self.webView)
        
        if let parsedUrl = URL(string: url) {
            self.webView.load(URLRequest(url: parsedUrl))
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.webView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height - navigationBarHeight)))
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
}
