import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class SupportSettingsTests: XCTestCase {
    private struct PartialSettings: Codable {
        var sendAllSilently: Bool
    }

    private let day: Int32 = 24 * 60 * 60

    func testDefaultsMatchTDesktop() {
        let settings = SupportSettings.default
        XCTAssertEqual(settings.chatLoadPeriod, 7 * self.day)
        XCTAssertFalse(settings.sendAllSilently)
    }

    func testRoundTrip() {
        let settings = SupportSettings(chatLoadPeriod: SupportSettings.allChatsLoadPeriod, sendAllSilently: true)
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self), settings)
        XCTAssertEqual(PreferencesEntry(SupportSettings.default)?.get(SupportSettings.self), .default)
    }

    func testMissingValuesTakeTheirDefaults() {
        var expected = SupportSettings.default
        expected.sendAllSilently = true
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self), expected)
    }

    func testAllChatsHoldsNothing() {
        let loadTill = supportChatListInitialLoadTill(now: 1_800_000_000, period: SupportSettings.allChatsLoadPeriod)
        XCTAssertEqual(loadTill, 0)
        XCTAssertFalse(supportChatListHoleIsHeld(holeTimestamp: 1_000, loadTill: loadTill))
        XCTAssertFalse(supportChatListHoleIsHeld(holeTimestamp: 0, loadTill: loadTill))
    }

    func testContextPublishesNothingBeforeSettingsAreRead() {
        let settings = Promise<SupportSettings>()
        let context = SupportContext(settings: settings.get())
        var values: [Int32] = []
        let disposable = context.chatListLoadTill.start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        context.loadMoreChats(holeTimestamp: 1_000_000)
        XCTAssertEqual(values, [])

        settings.set(.single(.default))
        XCTAssertEqual(values.count, 1)
    }

    func testPeriodChangeRecountsFromNowAndDropsLoadMore() {
        let settings = ValuePromise<SupportSettings>(.default, ignoreRepeated: true)
        let context = SupportContext(settings: settings.get())
        var values: [Int32] = []
        let disposable = context.chatListLoadTill.start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        let hole = values[0] - 3 * 7 * self.day
        context.loadMoreChats(holeTimestamp: hole)
        XCTAssertEqual(values.last, hole - 7 * self.day)

        var updated = SupportSettings.default
        updated.chatLoadPeriod = self.day
        settings.set(updated)
        XCTAssertEqual(values.count, 3)
        XCTAssertGreaterThan(values[2], values[0])

        updated.chatLoadPeriod = SupportSettings.allChatsLoadPeriod
        settings.set(updated)
        XCTAssertEqual(values.last, 0)
    }

    func testOtherSettingsKeepTheLoadMoreCutoff() {
        let settings = ValuePromise<SupportSettings>(.default, ignoreRepeated: true)
        let context = SupportContext(settings: settings.get())
        var values: [Int32] = []
        let disposable = context.chatListLoadTill.start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        let hole = values[0] - 3 * 7 * self.day
        context.loadMoreChats(holeTimestamp: hole)
        let cutoff = hole - 7 * self.day

        var updated = SupportSettings.default
        updated.sendAllSilently = true
        settings.set(updated)
        XCTAssertEqual(values.last, cutoff)
        XCTAssertEqual(values.count, 2)
    }

    func testLoadMoreStepsByTheChosenPeriod() {
        var settings = SupportSettings.default
        settings.chatLoadPeriod = 30 * self.day
        let context = SupportContext(settings: .single(settings))
        var value: Int32 = 0
        let disposable = context.chatListLoadTill.start(next: { next in
            value = next
        })
        defer {
            disposable.dispose()
        }

        let hole = value - self.day
        context.loadMoreChats(holeTimestamp: hole)
        XCTAssertEqual(value, hole - 30 * self.day)
    }

    func testLoadState() {
        XCTAssertEqual(supportChatListLoadState(holeTimestamps: [], loadTill: 1000), .allLoaded)
        XCTAssertEqual(supportChatListLoadState(holeTimestamps: [1001], loadTill: 1000), .loading)
        XCTAssertEqual(supportChatListLoadState(holeTimestamps: [900, 800], loadTill: 1000), .held(holeTimestamp: 900))
        XCTAssertEqual(supportChatListLoadState(holeTimestamps: [1500, 800], loadTill: 1000), .loading)
        XCTAssertEqual(supportChatListLoadState(holeTimestamps: [800], loadTill: 0), .loading)
    }

    private func isMuted(_ attributes: [MessageAttribute]) -> Bool {
        return attributes.contains(where: { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
    }

    func testSilentAttributeIsAddedOnce() {
        let once = supportSilentMessageAttributes([])
        XCTAssertTrue(self.isMuted(once))
        XCTAssertEqual(supportSilentMessageAttributes(once).count, 1)
    }

    func testSilentAttributeSurvivesEverySendShape() {
        let silent = supportSilentMessageAttributes([])
        XCTAssertTrue(self.isMuted(outgoingMessageAttributes(requestedAttributes: silent, isSecretChat: false, peerAutoremoveTimeout: nil)))
        XCTAssertTrue(self.isMuted(outgoingMessageAttributes(requestedAttributes: silent, isSecretChat: true, peerAutoremoveTimeout: nil)))
        XCTAssertTrue(self.isMuted(forwardedMessageAttributes(requestedAttributes: silent, sourceAttributes: [], forwardedMessageIds: nil)))
        XCTAssertTrue(self.isMuted(forwardCopyRequestedAttributes(sourceAttributes: [], forwardAttributes: silent, hidesCaption: false)))
    }
}
