import XCTest
import WebKit
@testable import WebProxyTransport

/// The execution profile must reach every frame, not just the main one.
///
/// Measured on an iOS 26.5 simulator (a throwaway app, since a logic-test bundle has no
/// `UIApplication` and WebKit will not run a page for a view that is in no window). A page
/// under the profile's own CSP does `document.createElement('iframe')`, appends it with no
/// `src`, and reads the child's globals:
///
///     forMainFrameOnly: true  -> navigator.geolocation=object    Worker=function   BroadcastChannel=function
///     forMainFrameOnly: false -> navigator.geolocation=undefined Worker=undefined  BroadcastChannel=undefined
///
/// So `frame-src 'none'` does NOT stop the child being created - the initial `about:blank`
/// is not a fetch - and a main-frame-only profile left a completely pristine realm one
/// `createElement` away. That matters most for geolocation, which below iOS 27 has no
/// public delegate to refuse it and would otherwise reach WebKit's own
/// `WKWebGeolocationPolicyDecider` alert.
final class WebProxyFrameIsolationTests: XCTestCase {
    func testTheCarrierInstallsTheProfileInEveryFrameAndTheShimInTheMainFrameOnly() throws {
        let configuration = try XCTUnwrap(WebProxyConfiguration(
            host: "proxy.example.com",
            secret: try XCTUnwrap(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))
        ))
        let carrier = try XCTUnwrap(WebProxyWebViewCarrier(
            configuration: configuration,
            generation: 1,
            received: { _, _ in },
            failed: { _, _ in }
        ))
        defer { carrier.invalidate() }

        let scripts = carrier.hostedWebView.configuration.userContentController.userScripts
        XCTAssertEqual(scripts.count, 2)
        XCTAssertFalse(scripts[0].isForMainFrameOnly, "the execution profile must reach every realm")
        XCTAssertTrue(scripts[1].isForMainFrameOnly, "the bridge shim is the half that can reach native")
        XCTAssertTrue(scripts.allSatisfy { $0.injectionTime == .atDocumentStart })
    }
}
