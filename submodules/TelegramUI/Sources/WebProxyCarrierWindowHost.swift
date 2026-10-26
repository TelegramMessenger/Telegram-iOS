import Foundation
import UIKit
import WebKit
import WebProxyTransport

/// Keeps the WEB proxy carrier's web view in the app's view hierarchy.
///
/// WebKit throttles work in off-screen views, which would stall the carrier's long
/// poll silently. The view is one point square, non-interactive and effectively
/// invisible, and sits at the bottom of the root container so it can never take a
/// touch or occlude anything.
final class WebProxyCarrierWindowHost: WebProxyCarrierViewHost {
    private weak var containerView: UIView?

    init(containerView: UIView) {
        self.containerView = containerView
    }

    func attachCarrierWebView(_ webView: WKWebView) {
        guard let containerView = self.containerView else {
            return
        }
        webView.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        webView.isUserInteractionEnabled = false
        // Accessibility traversal does NOT follow `isUserInteractionEnabled`, so without
        // this the provider's DOM is reachable text inside Telegram's own window: VoiceOver
        // would happily focus and read out whatever the relay operator put there. The view
        // has no content anyone should reach, so hide the whole subtree.
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        // Deliberately not zero: a fully transparent view may still be treated as
        // off-screen by WebKit. Confirm the working value on device.
        webView.alpha = 0.01
        containerView.insertSubview(webView, at: 0)
    }

    func detachCarrierWebView(_ webView: WKWebView) {
        webView.removeFromSuperview()
    }
}
