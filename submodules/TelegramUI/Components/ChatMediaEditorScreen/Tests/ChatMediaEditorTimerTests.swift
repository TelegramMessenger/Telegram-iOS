import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import AccountContext
import ChatMediaEditorScreen

private final class FakeTimerSelectionAdapter: ChatMediaEditorSelectionAdapter {
    let selectionLimit: Int
    private(set) var selected: [String]
    private let pipe = ValuePipe<Void>()

    init(selectionLimit: Int = 100, selected: [String] = []) {
        self.selectionLimit = selectionLimit
        self.selected = selected
    }

    func isSelected(_ uniqueId: String) -> Bool {
        return self.selected.contains(uniqueId)
    }

    func index(of uniqueId: String) -> Int? {
        return self.selected.firstIndex(of: uniqueId)
    }

    func selectedIds() -> [String] {
        return self.selected
    }

    func setSelected(_ uniqueId: String, _ selected: Bool, sender: AnyObject?) -> Bool {
        if selected {
            if self.selected.contains(uniqueId) || self.selected.count >= self.selectionLimit {
                return false
            }
            self.selected.append(uniqueId)
        } else {
            guard let index = self.selected.firstIndex(of: uniqueId) else {
                return false
            }
            self.selected.remove(at: index)
        }
        self.pipe.putNext(Void())
        return true
    }

    var changes: Signal<Void, NoError> {
        return self.pipe.signal()
    }
}

private final class FakeTimerAdapter: ChatMediaEditorTimerAdapter {
    private(set) var timers: [String: Int32] = [:]
    private(set) var writes: [(String, Int32?)] = []

    func timer(for uniqueId: String) -> Int32? {
        return self.timers[uniqueId]
    }

    func setTimer(_ timer: Int32?, for uniqueId: String) {
        self.writes.append((uniqueId, timer))
        self.timers[uniqueId] = timer
    }
}

final class ChatMediaEditorTimerTests: XCTestCase {
    private let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func peerId(_ namespace: EnginePeer.Id.Namespace, _ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: namespace, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    func testTimerGating() {
        let user = self.peerId(Namespaces.Peer.CloudUser, 2)
        XCTAssertTrue(chatMediaGalleryHasTimer(peerId: user, accountPeerId: self.accountPeerId))
        XCTAssertTrue(chatMediaGalleryHasTimer(peerId: self.peerId(Namespaces.Peer.CloudUser, 1271266957), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasTimer(peerId: self.accountPeerId, accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasTimer(peerId: self.peerId(Namespaces.Peer.CloudGroup, 2), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasTimer(peerId: self.peerId(Namespaces.Peer.CloudChannel, 2), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasTimer(peerId: self.peerId(Namespaces.Peer.SecretChat, 2), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasTimer(peerId: nil, accountPeerId: self.accountPeerId))

        let scheduledUserChat = chatMediaGalleryHasTimer(peerId: user, accountPeerId: self.accountPeerId)
        XCTAssertTrue(ChatMediaEditorTimerTooltipCounter(defaults: UserDefaults(suiteName: "ChatMediaEditorTimerTests.gating.\(UUID().uuidString)")!).shouldDisplay(hasTimer: scheduledUserChat))

        XCTAssertNil(chatMediaEditorTimerValue(nil))
        XCTAssertNil(chatMediaEditorTimerValue(0))
        XCTAssertEqual(chatMediaEditorTimerValue(10), 10)
        XCTAssertEqual(chatMediaEditorTimerValue(viewOnceTimeout), viewOnceTimeout)

        XCTAssertTrue(chatMediaEditorSendMenuOptions(hasSchedule: true, sendWhenOnlineAvailable: true, hasTimer: true, hasAnyTimer: false).hasTimer)
        XCTAssertFalse(chatMediaEditorSendMenuOptions(hasSchedule: true, sendWhenOnlineAvailable: true, hasTimer: false, hasAnyTimer: false).hasTimer)
    }

    func testSettingTimerSelectsItem() {
        let adapter = FakeTimerAdapter()
        let selectionAdapter = FakeTimerSelectionAdapter(selected: ["a"])
        let selection = ChatMediaEditorSelectionModel(adapter: selectionAdapter)
        let model = ChatMediaEditorTimerModel(adapter: adapter, selection: selection)

        model.timerUpdated(10, for: "b")
        XCTAssertEqual(adapter.timers["b"], 10)
        XCTAssertEqual(model.timer(for: "b"), 10)
        XCTAssertEqual(selectionAdapter.selected, ["a", "b"])

        model.timerUpdated(0, for: "b")
        XCTAssertNil(adapter.timers["b"])
        XCTAssertNil(adapter.writes.last?.1)
        XCTAssertNil(model.timer(for: "b"))
        XCTAssertEqual(selectionAdapter.selected, ["a", "b"])

        model.timerUpdated(nil, for: "c")
        XCTAssertNil(adapter.timers["c"])
        XCTAssertEqual(selectionAdapter.selected, ["a", "b", "c"])

        model.timerUpdated(viewOnceTimeout, for: "a")
        XCTAssertEqual(model.timer(for: "a"), viewOnceTimeout)
        XCTAssertEqual(selectionAdapter.selected, ["a", "b", "c"])

        let unselectedModel = ChatMediaEditorTimerModel(adapter: adapter, selection: nil)
        unselectedModel.timerUpdated(3, for: "d")
        XCTAssertEqual(adapter.timers["d"], 3)
    }

    func testSendWithTimerSetsAllSelectedPlusCurrent() {
        let adapter = FakeTimerAdapter()
        let selectionAdapter = FakeTimerSelectionAdapter(selected: ["a", "b"])
        let selection = ChatMediaEditorSelectionModel(adapter: selectionAdapter)
        let model = ChatMediaEditorTimerModel(adapter: adapter, selection: selection)

        let ids = model.applySendTimer(25, currentId: "c")
        XCTAssertEqual(ids, ["a", "b", "c"])
        XCTAssertEqual(adapter.timers, ["a": 25, "b": 25, "c": 25])
        XCTAssertEqual(selectionAdapter.selected, ["a", "b"])

        let again = model.applySendTimer(viewOnceTimeout, currentId: "a")
        XCTAssertEqual(again, ["a", "b"])
        XCTAssertEqual(adapter.timers, ["a": viewOnceTimeout, "b": viewOnceTimeout, "c": 25])

        let single = ChatMediaEditorTimerModel(adapter: adapter, selection: nil)
        XCTAssertEqual(single.applySendTimer(5, currentId: "z"), ["z"])
        XCTAssertEqual(adapter.timers["z"], 5)
    }

    func testScheduleHiddenWhenAnyTimer() {
        let adapter = FakeTimerAdapter()
        let selectionAdapter = FakeTimerSelectionAdapter(selected: ["a", "b"])
        let selection = ChatMediaEditorSelectionModel(adapter: selectionAdapter)
        let model = ChatMediaEditorTimerModel(adapter: adapter, selection: selection)

        XCTAssertFalse(model.hasAnyTimer(currentId: "c"))
        let plain = chatMediaEditorSendMenuOptions(hasSchedule: true, sendWhenOnlineAvailable: true, hasTimer: true, hasAnyTimer: model.hasAnyTimer(currentId: "c"))
        XCTAssertEqual(plain, ChatMediaEditorSendMenuOptions(canSendWhenOnline: true, canSchedule: true, hasTimer: true))

        model.timerUpdated(10, for: "b")
        XCTAssertTrue(model.hasAnyTimer(currentId: "c"))
        let selectedTimer = chatMediaEditorSendMenuOptions(hasSchedule: true, sendWhenOnlineAvailable: true, hasTimer: true, hasAnyTimer: model.hasAnyTimer(currentId: "c"))
        XCTAssertEqual(selectedTimer, ChatMediaEditorSendMenuOptions(canSendWhenOnline: false, canSchedule: false, hasTimer: true))

        let currentOnly = ChatMediaEditorTimerModel(adapter: FakeTimerAdapter(), selection: nil)
        currentOnly.timerUpdated(3, for: "x")
        XCTAssertTrue(currentOnly.hasAnyTimer(currentId: "x"))
        XCTAssertFalse(currentOnly.hasAnyTimer(currentId: "y"))

        let secretChat = chatMediaEditorSendMenuOptions(hasSchedule: false, sendWhenOnlineAvailable: true, hasTimer: false, hasAnyTimer: false)
        XCTAssertEqual(secretChat, ChatMediaEditorSendMenuOptions(canSendWhenOnline: false, canSchedule: false, hasTimer: false))

        let offline = chatMediaEditorSendMenuOptions(hasSchedule: true, sendWhenOnlineAvailable: false, hasTimer: true, hasAnyTimer: false)
        XCTAssertEqual(offline, ChatMediaEditorSendMenuOptions(canSendWhenOnline: false, canSchedule: true, hasTimer: true))
    }

    func testTooltipCounterStopsAtThree() {
        let suiteName = "ChatMediaEditorTimerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail()
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        XCTAssertEqual(chatMediaEditorTimerTooltipDefaultsKey, "TG_displayedMediaTimerTooltip_v3")
        XCTAssertEqual(chatMediaEditorTimerTooltipDelay, 0.5)
        XCTAssertEqual(chatMediaEditorTimerTooltipDuration, 3.5)

        let counter = ChatMediaEditorTimerTooltipCounter(defaults: defaults)
        XCTAssertFalse(counter.shouldDisplay(hasTimer: false))
        for expected in 1 ... 3 {
            XCTAssertTrue(counter.shouldDisplay(hasTimer: true))
            counter.noteDisplayed()
            XCTAssertEqual(defaults.integer(forKey: chatMediaEditorTimerTooltipDefaultsKey), expected)
        }
        XCTAssertFalse(counter.shouldDisplay(hasTimer: true))

        let suppressedSuite = "ChatMediaEditorTimerTests.\(UUID().uuidString)"
        guard let suppressedDefaults = UserDefaults(suiteName: suppressedSuite) else {
            XCTFail()
            return
        }
        defer {
            suppressedDefaults.removePersistentDomain(forName: suppressedSuite)
        }
        let suppressed = ChatMediaEditorTimerTooltipCounter(defaults: suppressedDefaults)
        XCTAssertTrue(suppressed.shouldDisplay(hasTimer: true))
        suppressed.suppress()
        XCTAssertEqual(suppressedDefaults.object(forKey: chatMediaEditorTimerTooltipDefaultsKey) as? NSNumber, NSNumber(value: 3))
        XCTAssertFalse(suppressed.shouldDisplay(hasTimer: true))
    }
}
