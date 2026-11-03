import XCTest
import WebKit
@testable import WebProxyTransport

final class WebProxyWebViewHardeningTests: XCTestCase {
    private let policy = WebProxyWebViewHardening.contentSecurityPolicy(host: "proxy.example.com")

    /// The exact policy IOS.md §"Required WKWebView hardening" specifies, directive for
    /// directive. Written out rather than derived, so a change to the source has to be a
    /// deliberate change here too.
    func testPolicyMatchesTheSpecifiedDirectives() {
        XCTAssertEqual(self.policy, [
            "default-src 'none'",
            "base-uri 'none'",
            "child-src 'none'",
            "connect-src https://proxy.example.com wss://proxy.example.com",
            "font-src 'none'",
            "form-action 'none'",
            "frame-src 'none'",
            "img-src 'none'",
            "manifest-src 'none'",
            "media-src 'none'",
            "object-src 'none'",
            "script-src 'unsafe-inline'",
            "style-src 'none'",
            "worker-src 'none'"
        ].joined(separator: "; "))
    }

    func testPolicyAdmitsNothingItMustNot() {
        for forbidden in ["'unsafe-eval'", "blob:", "data:", "*", "http://", ":80", ":8080"] {
            XCTAssertFalse(self.policy.contains(forbidden), forbidden)
        }
        // A meta policy ignores these, so including them would only be misleading.
        for ignored in ["frame-ancestors", "report-uri", "report-to", "sandbox"] {
            XCTAssertFalse(self.policy.contains(ignored), ignored)
        }
    }

    func testPolicyIsBoundToTheConfiguredHost() {
        let other = WebProxyWebViewHardening.contentSecurityPolicy(host: "other.example.com")
        XCTAssertNotEqual(self.policy, other)
        XCTAssertFalse(self.policy.contains("other.example.com"))
    }

    /// The base path never reaches the policy: CSP source expressions are origin-scoped, and
    /// the profile is the same whether the relay lives at the root or under a prefix.
    func testPolicyIgnoresTheBasePath() throws {
        let prefixed = try XCTUnwrap(WebProxyConfiguration(
            host: "proxy.example.com",
            path: "dobry-cola-super-app",
            secret: try XCTUnwrap(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))
        ))
        XCTAssertEqual(WebProxyWebViewHardening.contentSecurityPolicy(host: prefixed.host), self.policy)
    }

    func testScriptCarriesThePolicyAndTheShims() {
        let script = WebProxyWebViewHardening.script(host: "proxy.example.com", flag: "flagName")
        XCTAssertTrue(script.contains("Content-Security-Policy"))
        XCTAssertTrue(script.contains("x-dns-prefetch-control"))
        XCTAssertTrue(script.contains("\"flagName\""))
        for shim in [
            "localStorage", "sessionStorage", "indexedDB", "caches", "cookie",
            "Worker", "SharedWorker", "BroadcastChannel", "serviceWorker",
            "AudioContext", "clipboard", "mediaDevices", "geolocation",
            "open", "print", "alert", "confirm", "prompt"
        ] {
            XCTAssertTrue(script.contains(shim), shim)
        }
    }

    func testConfigurationRefusesPersistenceAndMedia() {
        let configuration = WKWebViewConfiguration()
        WebProxyWebViewHardening.apply(to: configuration)
        XCTAssertFalse(configuration.websiteDataStore.isPersistent)
        XCTAssertFalse(configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        XCTAssertEqual(configuration.mediaTypesRequiringUserActionForPlayback, .all)
        XCTAssertFalse(configuration.allowsAirPlayForMediaPlayback)
        if #available(macOS 12.3, iOS 15.4, *) {
            XCTAssertFalse(configuration.preferences.isElementFullscreenEnabled)
        }
        #if os(iOS)
        XCTAssertFalse(configuration.allowsPictureInPictureMediaPlayback)
        // Inline playback is the RESTRICTIVE setting: `false` hands video to the native
        // full-screen controller, which is the one path to the whole screen.
        XCTAssertTrue(configuration.allowsInlineMediaPlayback)
        #endif
    }

    /// Each carrier gets a store of its own: nothing here may be shared with Telegram's
    /// other web views, and nothing may outlive the carrier.
    func testEachCarrierGetsItsOwnDataStore() {
        let first = WKWebViewConfiguration()
        let second = WKWebViewConfiguration()
        WebProxyWebViewHardening.apply(to: first)
        WebProxyWebViewHardening.apply(to: second)
        XCTAssertFalse(first.websiteDataStore === second.websiteDataStore)
        XCTAssertFalse(first.websiteDataStore === WKWebsiteDataStore.default())
    }
}
