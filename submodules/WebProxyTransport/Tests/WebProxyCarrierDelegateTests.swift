import XCTest
import WebKit
import MtProtoKit
@testable import WebProxyTransport

final class WebProxyCarrierDelegateTests: XCTestCase {
    /// Every refusal the carrier installs is an OPTIONAL protocol method. A Swift spelling
    /// that does not map to the ObjC selector compiles cleanly and is then simply never
    /// called - the refusal silently reverts to the platform default, which for several of
    /// these is "present the panel" (WebKit documents that for media capture, and for the
    /// iOS file panel from 18.4). Nothing else in the build catches that, so pin the
    /// bindings here.
    ///
    /// Asked of the class rather than an instance: this needs no `WKWebView`, so it cannot
    /// be weakened by anything about the unit-test environment.
    func testEveryUIPresentingDelegateIsActuallyBound() {
        var selectors = [
            // Dialogs: the direct phishing surface, prompt() most of all.
            "webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:",
            "webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:",
            "webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:",
            // Credential sheets: chrome-rendered and carrying the host name, so the most
            // convincing of the lot. A relay answering 401 must not be able to raise one.
            "webView:didReceiveAuthenticationChallenge:completionHandler:",
            // Permission prompts.
            "webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:",
            // Anything that would put a view on screen or write a file.
            "webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:",
            "webView:didReceiveServerRedirectForProvisionalNavigation:",
            "webView:navigationAction:didBecomeDownload:",
            "webView:navigationResponse:didBecomeDownload:"
        ]
        #if os(iOS)
        selectors.append("webView:requestDeviceOrientationAndMotionPermissionForOrigin:initiatedByFrame:decisionHandler:")
        #endif
        if #available(macOS 27.0, iOS 27.0, *) {
            selectors.append("webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:")
        }
        if #available(macOS 10.12, iOS 18.4, *) {
            // Public on iOS from 18.4. WebKit documents that leaving it out there makes the
            // view "match the file upload behavior of Safari" - i.e. present a picker.
            selectors.append("webView:runOpenPanelWithParameters:initiatedByFrame:completionHandler:")
        }

        for selector in selectors {
            XCTAssertTrue(WebProxyWebViewCarrier.instancesRespond(to: Selector(selector)), selector)
        }
    }

    /// `MTTcpConnection` finds the carrier through `respondsToSelector:`, so this binding
    /// fails the same silent way as the delegates above: rename it in Swift and the ObjC
    /// side simply stops recognising the carrier. It pairs the interface with
    /// `MTSocksProxySettings.webProxy` - the carrier ignores the address it is handed, so a
    /// connection with a real address to reach must never be given one, and a WEB proxy
    /// connection must never fall back to a socket.
    func testTheConnectionInterfaceIdentifiesItselfAsTheCarrier() {
        XCTAssertTrue(WebProxyConnectionInterface.instancesRespond(to: Selector("isWebProxyCarrier")))
        // Optional on the protocol, so the ObjC side reaches it through respondsToSelector:
        // and a nil here is exactly the silent miss this guards against.
        let interface = WebProxyTransport.shared.makeConnectionInterface(
            delegate: NoopConnectionDelegate(),
            delegateQueue: DispatchQueue(label: "test")
        )
        XCTAssertEqual(interface.isWebProxyCarrier?(), true)
    }

    /// Normal system TLS validation, and nothing else answered. Driving the delegate
    /// directly needs a real carrier; the WebKit value types the other delegates take
    /// (`WKFrameInfo`, `WKNavigationAction`) trap when constructed outside WebKit, which is
    /// why the rest are covered by the binding test above rather than by invocation.
    func testOnlyServerTrustChallengesAreHandled() throws {
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

        let cases: [(String, URLSession.AuthChallengeDisposition)] = [
            (NSURLAuthenticationMethodServerTrust, .performDefaultHandling),
            (NSURLAuthenticationMethodHTTPBasic, .cancelAuthenticationChallenge),
            (NSURLAuthenticationMethodHTTPDigest, .cancelAuthenticationChallenge),
            (NSURLAuthenticationMethodNTLM, .cancelAuthenticationChallenge),
            (NSURLAuthenticationMethodClientCertificate, .cancelAuthenticationChallenge)
        ]
        for (method, expected) in cases {
            let space = URLProtectionSpace(host: "proxy.example.com", port: 443, protocol: "https", realm: "Telegram", authenticationMethod: method)
            let challenge = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: NoopChallengeSender())
            let answered = expectation(description: method)
            carrier.webView(carrier.hostedWebView, didReceive: challenge) { disposition, credential in
                XCTAssertEqual(disposition, expected, method)
                XCTAssertNil(credential, method)
                answered.fulfill()
            }
            self.wait(for: [answered], timeout: 1.0)
        }
    }
}

private final class NoopConnectionDelegate: NSObject, MTTcpConnectionInterfaceDelegate {
    func connectionInterfaceDidReadPartialData(ofLength partialLength: UInt, tag: Int) {}
    func connectionInterfaceDidRead(_ rawData: Data, withTag tag: Int, networkType: Int32) {}
    func connectionInterfaceDidConnect() {}
    func connectionInterfaceDidDisconnectWithError(_ error: Error?) {}
}

private final class NoopChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
