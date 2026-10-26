import XCTest
import WebKit
@testable import WebProxyTransport

private final class RecordingHost: WebProxyCarrierViewHost {
    var attached: [WKWebView] = []
    var detached: [WKWebView] = []

    func attachCarrierWebView(_ webView: WKWebView) {
        self.attached.append(webView)
    }

    func detachCarrierWebView(_ webView: WKWebView) {
        self.detached.append(webView)
    }
}

final class WebProxyViewAttachmentTests: XCTestCase {
    func testWebViewBeforeHostAttachesWhenTheHostArrives() {
        let attachment = WebProxyViewAttachment()
        let webView = WKWebView(frame: .zero)
        attachment.setWebView(webView)

        let host = RecordingHost()
        attachment.setHost(host)

        XCTAssertEqual(host.attached.count, 1)
        XCTAssertTrue(host.attached.first === webView)
    }

    func testHostBeforeWebViewAttachesWhenTheWebViewArrives() {
        let attachment = WebProxyViewAttachment()
        let host = RecordingHost()
        attachment.setHost(host)
        XCTAssertTrue(host.attached.isEmpty)

        let webView = WKWebView(frame: .zero)
        attachment.setWebView(webView)
        XCTAssertTrue(host.attached.first === webView)
    }

    func testReplacingTheWebViewDetachesTheOldOne() {
        let attachment = WebProxyViewAttachment()
        let host = RecordingHost()
        attachment.setHost(host)

        let first = WKWebView(frame: .zero)
        let second = WKWebView(frame: .zero)
        attachment.setWebView(first)
        attachment.setWebView(second)

        XCTAssertTrue(host.detached.first === first)
        XCTAssertEqual(host.attached.count, 2)
        XCTAssertTrue(host.attached.last === second)
    }

    func testClearingTheWebViewDetachesIt() {
        let attachment = WebProxyViewAttachment()
        let host = RecordingHost()
        attachment.setHost(host)
        let webView = WKWebView(frame: .zero)
        attachment.setWebView(webView)

        attachment.setWebView(nil)

        XCTAssertEqual(host.detached.count, 1)
        XCTAssertTrue(host.detached.first === webView)
    }

    func testReplacingTheHostMovesTheWebView() {
        let attachment = WebProxyViewAttachment()
        let first = RecordingHost()
        let second = RecordingHost()
        let webView = WKWebView(frame: .zero)
        attachment.setHost(first)
        attachment.setWebView(webView)

        attachment.setHost(second)

        XCTAssertTrue(first.detached.first === webView)
        XCTAssertTrue(second.attached.first === webView)
    }

    func testClearingTheHostDetachesWithoutLosingTheWebView() {
        let attachment = WebProxyViewAttachment()
        let host = RecordingHost()
        let webView = WKWebView(frame: .zero)
        attachment.setHost(host)
        attachment.setWebView(webView)

        attachment.setHost(nil)
        XCTAssertTrue(host.detached.first === webView)

        let replacement = RecordingHost()
        attachment.setHost(replacement)
        XCTAssertTrue(replacement.attached.first === webView)
    }

    func testSettingTheSameHostTwiceIsInert() {
        let attachment = WebProxyViewAttachment()
        let host = RecordingHost()
        let webView = WKWebView(frame: .zero)
        attachment.setWebView(webView)
        attachment.setHost(host)
        attachment.setHost(host)

        XCTAssertEqual(host.attached.count, 1)
        XCTAssertTrue(host.detached.isEmpty)
    }
}
