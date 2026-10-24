import XCTest
@testable import WebProxyTransport

final class WebProxyProcessPolicyTests: XCTestCase {
    func testMainAppCanBootstrapWithoutAHost() {
        let policy = WebProxyProcessPolicy(isAppExtension: false, extensionPointIdentifier: nil)
        XCTAssertTrue(policy.allowsCarrier)
        XCTAssertTrue(policy.shouldRun(hasConfiguration: true, hasDemand: true, hasViewHost: false))
    }

    func testShareRequiresAHostAndStopsWhenItDisappears() {
        let policy = WebProxyProcessPolicy(isAppExtension: true, extensionPointIdentifier: "com.apple.share-services")
        XCTAssertTrue(policy.allowsCarrier)
        for visible in [false, true, false, true] {
            XCTAssertEqual(policy.shouldRun(hasConfiguration: true, hasDemand: true, hasViewHost: visible), visible)
        }
    }

    func testHeadlessAndUnknownExtensionsStayDisabledEvenWithAHost() {
        for point: String? in [nil, "com.apple.widgetkit-extension", "com.apple.usernotifications.service", "com.apple.intents-service", "unknown"] {
            let policy = WebProxyProcessPolicy(isAppExtension: true, extensionPointIdentifier: point)
            XCTAssertFalse(policy.allowsCarrier)
            XCTAssertFalse(policy.shouldRun(hasConfiguration: true, hasDemand: true, hasViewHost: true))
        }
    }

    func testConfigurationAndDemandAreStillRequired() {
        for isExtension in [false, true] {
            let policy = WebProxyProcessPolicy(isAppExtension: isExtension, extensionPointIdentifier: "com.apple.share-services")
            XCTAssertFalse(policy.shouldRun(hasConfiguration: false, hasDemand: true, hasViewHost: true))
            XCTAssertFalse(policy.shouldRun(hasConfiguration: true, hasDemand: false, hasViewHost: true))
        }
    }
}
