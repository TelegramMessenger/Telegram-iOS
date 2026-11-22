import Foundation
import WebKit

/// Somewhere for the carrier's `WKWebView` to live in the app's view hierarchy.
///
/// WebKit throttles off-screen views, and a throttled carrier stalls its long poll
/// with no error, so the view must be in a real hierarchy while the carrier runs.
/// The transport cannot reach the hierarchy itself: `TelegramCore` depends on this
/// module and is shared with Telegram-Mac, so nothing here may import UIKit. This
/// protocol is therefore typed in WebKit — `WKWebView` is a `UIView` on iOS and an
/// `NSView` on macOS — and the app supplies the platform half.
public protocol WebProxyCarrierViewHost: AnyObject {
    func attachCarrierWebView(_ webView: WKWebView)
    func detachCarrierWebView(_ webView: WKWebView)
}

/// Pairs the current carrier web view with the current host, in either arrival order.
///
/// The carrier can start before the app has a window at all — IOS.md requires WEB to
/// bootstrap the login network before authorization — so a missing host parks the
/// view rather than failing. Main-queue confined.
final class WebProxyViewAttachment {
    private weak var host: WebProxyCarrierViewHost?
    private var webView: WKWebView?

    init() {
    }

    func setHost(_ host: WebProxyCarrierViewHost?) {
        guard self.host !== host else { return }
        if let webView = self.webView {
            self.host?.detachCarrierWebView(webView)
        }
        self.host = host
        if let webView = self.webView {
            host?.attachCarrierWebView(webView)
        }
    }

    func setWebView(_ webView: WKWebView?) {
        guard self.webView !== webView else { return }
        if let existing = self.webView {
            self.host?.detachCarrierWebView(existing)
        }
        self.webView = webView
        if let webView {
            self.host?.attachCarrierWebView(webView)
        }
    }
}
