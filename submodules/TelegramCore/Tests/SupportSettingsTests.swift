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
        XCTAssertEqual(settings.switchBehavior, .next)
        XCTAssertTrue(settings.fixChatsOrder)
        XCTAssertTrue(settings.templatesAutocomplete)
        XCTAssertEqual(settings.chatLoadPeriod, 7 * self.day)
        XCTAssertFalse(settings.allSearchResults)
        XCTAssertFalse(settings.sendAllSilently)
    }

    func testRoundTrip() {
        let settings = SupportSettings(switchBehavior: .previous, fixChatsOrder: false, templatesAutocomplete: false, chatLoadPeriod: SupportSettings.allChatsLoadPeriod, allSearchResults: true, sendAllSilently: true)
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self), settings)
        XCTAssertEqual(PreferencesEntry(SupportSettings.default)?.get(SupportSettings.self), .default)
    }

    func testChatListBesideDefaultsToOffAndRoundTrips() {
        XCTAssertEqual(SupportSettings.default.chatListBeside, .off)
        for value: SupportChatListBeside in [.off, .landscape, .everywhere] {
            var settings = SupportSettings.default
            settings.chatListBeside = value
            XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.chatListBeside, value)
        }
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self)?.chatListBeside, .off)
    }

    func testChatListBesideUsesTheSplitViewInLandscapeAndTheColumnInPortrait() {
        XCTAssertFalse(supportChatListBesideUsesSplitView(.off, isLandscape: true))
        XCTAssertFalse(supportChatListBesideUsesSplitView(.off, isLandscape: false))
        XCTAssertFalse(supportChatListBesideNarrowsList(.off, isLandscape: false))
        XCTAssertTrue(supportChatListBesideUsesSplitView(.landscape, isLandscape: true))
        XCTAssertFalse(supportChatListBesideUsesSplitView(.landscape, isLandscape: false))
        XCTAssertFalse(supportChatListBesideNarrowsList(.landscape, isLandscape: false))
        XCTAssertFalse(supportChatListBesideNarrowsList(.landscape, isLandscape: true))
        XCTAssertTrue(supportChatListBesideUsesSplitView(.everywhere, isLandscape: true))
        XCTAssertTrue(supportChatListBesideUsesSplitView(.everywhere, isLandscape: false))
        XCTAssertFalse(supportChatListBesideNarrowsList(.everywhere, isLandscape: true))
        XCTAssertTrue(supportChatListBesideNarrowsList(.everywhere, isLandscape: false))
    }

    func testTrailingTagsAreOnByDefaultAndFollowTheSettings() {
        XCTAssertTrue(SupportSettings.default.trailingTags)
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self)?.trailingTags, true)

        var settings = SupportSettings.default
        settings.trailingTags = false
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.trailingTags, false)

        let promise = ValuePromise<SupportSettings>(.default)
        let context = SupportContext(settings: promise.get())
        XCTAssertTrue(context.currentTrailingTags)
        promise.set(settings)
        XCTAssertFalse(context.currentTrailingTags)
    }

    func testMiddleTagsCollapseByDefaultAndFollowTheSettings() {
        XCTAssertTrue(SupportSettings.default.collapseMiddleTags)
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self)?.collapseMiddleTags, true)

        var settings = SupportSettings.default
        settings.collapseMiddleTags = false
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.collapseMiddleTags, false)

        let promise = ValuePromise<SupportSettings>(.default)
        let context = SupportContext(settings: promise.get())
        XCTAssertTrue(context.currentCollapseMiddleTags)
        promise.set(settings)
        XCTAssertFalse(context.currentCollapseMiddleTags)
    }

    func testChatsWithoutIncomingMessagesAreShownByDefaultAndFollowTheSettings() {
        XCTAssertFalse(SupportSettings.default.hideChatsWithoutIncomingMessages)
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self)?.hideChatsWithoutIncomingMessages, false)

        var settings = SupportSettings.default
        settings.hideChatsWithoutIncomingMessages = true
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.hideChatsWithoutIncomingMessages, true)

        let promise = ValuePromise<SupportSettings>(.default)
        let context = SupportContext(settings: promise.get())
        var values: [Bool] = []
        let disposable = context.hidesChatsWithoutIncomingMessages.start(next: { values.append($0) })
        promise.set(settings)
        disposable.dispose()
        XCTAssertEqual(values, [false, true])
    }

    func testKeyboardHidesOnSwitchByDefaultAndFollowsTheSettings() {
        XCTAssertTrue(SupportSettings.default.hideKeyboardOnSwitch)
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self)?.hideKeyboardOnSwitch, true)

        var settings = SupportSettings.default
        settings.hideKeyboardOnSwitch = false
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.hideKeyboardOnSwitch, false)

        let promise = ValuePromise<SupportSettings>(.default)
        let context = SupportContext(settings: promise.get())
        XCTAssertTrue(context.currentHideKeyboardOnSwitch)
        promise.set(settings)
        XCTAssertFalse(context.currentHideKeyboardOnSwitch)
    }

    func testSwipeToNextChatIsOffByDefaultAndRoundTrips() {
        XCTAssertFalse(SupportSettings.default.swipeToNextChat)
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self)?.swipeToNextChat, false)

        var settings = SupportSettings.default
        settings.swipeToNextChat = true
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.swipeToNextChat, true)
    }

    func testComposerFocusSkipIsForOneChatOnceAndExpires() {
        let context = SupportContext(settings: .single(.default))
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        let otherPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2))

        context.skipComposerFocus(peerId: peerId, now: 100.0)
        XCTAssertFalse(context.takeComposerFocusSkip(peerId: otherPeerId, now: 100.5))
        XCTAssertTrue(context.takeComposerFocusSkip(peerId: peerId, now: 100.5))
        XCTAssertFalse(context.takeComposerFocusSkip(peerId: peerId, now: 100.6))

        context.skipComposerFocus(peerId: peerId, now: 200.0)
        XCTAssertFalse(context.takeComposerFocusSkip(peerId: peerId, now: 203.0))
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

    func testCleanupDoesNotRunForAllChats() {
        XCTAssertFalse(supportChatListCleanupRuns(cutoffAtLaunch: 0, cutoff: 0))
    }

    func testCleanupDoesNotRunAfterAChangeThisSession() {
        XCTAssertTrue(supportChatListCleanupRuns(cutoffAtLaunch: 1000, cutoff: 1000))
        XCTAssertFalse(supportChatListCleanupRuns(cutoffAtLaunch: 1000, cutoff: 2000))
        XCTAssertFalse(supportChatListCleanupRuns(cutoffAtLaunch: 1000, cutoff: 500))
        XCTAssertFalse(supportChatListCleanupRuns(cutoffAtLaunch: nil, cutoff: nil))
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
