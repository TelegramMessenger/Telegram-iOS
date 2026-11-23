import Foundation
import XCTest
import Postbox
import SwiftSignalKit
import TelegramApi
@testable import TelegramCore

final class SupportApiTests: XCTestCase {
    private static let logger: Logger = {
        let logger = Logger(rootPath: NSTemporaryDirectory(), basePath: NSTemporaryDirectory())
        logger.logToFile = false
        logger.logToConsole = false
        return logger
    }()

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(SupportApiTests.logger)
    }

    private let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1001))
    private let otherPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1002))

    private func context() -> SupportContext {
        return SupportContext(settings: .single(.default))
    }

    func testNameMapping() {
        XCTAssertEqual(supportName(.supportName(.init(name: "Agent"))), "Agent")
    }

    func testNameFallbackMatchesTDesktop() {
        XCTAssertEqual(supportNameFallback(installationTag: 18446744073709551615), "[rand^18446744073709551615]")
    }

    func testInstallationTagRoundTrip() {
        let tag = SupportInstallationTag(value: -5)
        XCTAssertEqual(PreferencesEntry(tag)?.get(SupportInstallationTag.self), tag)
    }

    func testSupportNameIsPublishedOnceSet() {
        let context = self.context()
        var values: [String] = []
        let disposable = context.supportName.start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        XCTAssertEqual(values, [])
        context.setSupportName("Agent")
        XCTAssertEqual(values, ["Agent"])
    }

}
