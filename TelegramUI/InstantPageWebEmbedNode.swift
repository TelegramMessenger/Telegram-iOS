import Foundation
import TelegramCore
import WebKit
import AsyncDisplayKit

final class instantPageWebEmbedNode: ASDisplayNode, InstantPageNode {
    let url: String?
    let html: String?
    
    private let webView: WKWebView
    
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool) {
        self.url = url
        self.html = html
        
        self.webView = WKWebView(frame: CGRect(origin: CGPoint(), size: frame.size))
        
        super.init()
        
        if let html = html {
            self.webView.loadHTMLString(html, baseURL: nil)
        } else if let url = url, let parsedUrl = URL(string: url) {
            var request = URLRequest(url: parsedUrl)
            if let scheme = parsedUrl.scheme, let host = parsedUrl.host {
                let referrer = "\(scheme)://\(host)"
                request.setValue(referrer, forHTTPHeaderField: "Referer")
            }
            self.webView.load(request)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.webView)
    }
    
    override func layout() {
        super.layout()
        
        self.webView.frame = self.bounds
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
}
