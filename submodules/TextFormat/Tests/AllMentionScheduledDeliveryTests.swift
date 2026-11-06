import Foundation
import XCTest
import Postbox
import TelegramCore
import TelegramUIPreferences
import TextFormat

final class AllMentionScheduledDeliveryTests: XCTestCase {
    private func decision(time: Int32 = 1100, now: TimeInterval = 1100, collective: Bool = true, failed: Bool = false, force: Bool = false, permission: AllMentionGroupPermission = AllMentionGroupPermission(isEnabled: true)) -> AllMentionScheduledDeliveryDecision {
        return allMentionScheduledDeliveryDecision(scheduleTime: time, timestamp: now, requiresCollectiveMention: collective, hasFailed: failed, force: force, permission: permission)
    }

    func testQueueDoesNotConsumeQuotaBeforeDueTime() {
        let state = AllMentionGroupPermission(isEnabled: true, callsInBurst: 2, burstResetsAt: 1300)
        XCTAssertEqual(decision(now: 1099.999, permission: state), .wait)
        XCTAssertEqual(state.availableCalls(at: 1099.999), 1)
        XCTAssertEqual(decision(permission: state), .deliver(AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1400)))
    }

    func testPermissionIsCheckedAtDeliveryInsteadOfQueueTime() {
        XCTAssertEqual(decision(now: 1000, permission: AllMentionGroupPermission()), .wait)
        XCTAssertEqual(decision(permission: AllMentionGroupPermission()), .blocked(.permissionDisabled))
        XCTAssertEqual(decision(permission: AllMentionGroupPermission(isEnabled: true)), .deliver(AllMentionGroupPermission(isEnabled: true, callsInBurst: 1, burstResetsAt: 1400)))
    }

    func testScheduledCollectiveCallUsesSameSharedBurst() {
        let exhausted = AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1400)
        XCTAssertEqual(decision(permission: exhausted), .blocked(.rateLimit))
        XCTAssertEqual(decision(now: 1399.999, permission: exhausted), .blocked(.rateLimit))
        XCTAssertEqual(decision(now: 1400, permission: exhausted), .deliver(AllMentionGroupPermission(isEnabled: true, callsInBurst: 1, burstResetsAt: 1700)))
    }

    func testFailedScheduledMessageNeedsManualRetry() {
        XCTAssertEqual(decision(now: 5000, failed: true), .wait)
        XCTAssertEqual(decision(now: 5000, failed: true, force: true), .deliver(AllMentionGroupPermission(isEnabled: true, callsInBurst: 1, burstResetsAt: 5300)))
    }

    func testSendNowSkipsDateButNeverSkipsPermissionOrQuota() {
        XCTAssertEqual(decision(time: 9000, force: true), .deliver(AllMentionGroupPermission(isEnabled: true, callsInBurst: 1, burstResetsAt: 1400)))
        XCTAssertEqual(decision(time: 9000, force: true, permission: AllMentionGroupPermission()), .blocked(.permissionDisabled))
        let exhausted = AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1400)
        XCTAssertEqual(decision(time: 9000, force: true, permission: exhausted), .blocked(.rateLimit))
    }

    func testOrdinaryMessagesDoNotRequireCollectivePermission() {
        let disabled = AllMentionGroupPermission()
        XCTAssertEqual(decision(collective: false, permission: disabled), .deliver(disabled))
        let exhausted = AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1400)
        XCTAssertEqual(decision(collective: false, permission: exhausted), .deliver(exhausted))
    }

    func testScheduledConversionKeepsSilenceAndExplicitEffect() {
        let attributes: [MessageAttribute] = [NotificationInfoMessageAttribute(flags: .muted), EffectMessageAttribute(id: 8100101), OutgoingScheduleInfoMessageAttribute(scheduleTime: 1100, repeatPeriod: nil)]
        let queued = allMentionLocalOutgoingAttributes(attributes, keepSchedule: true)
        let delivered = allMentionLocalOutgoingAttributes(queued, keepSchedule: false)
        XCTAssertTrue(delivered.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
        XCTAssertTrue(delivered.contains { ($0 as? EffectMessageAttribute)?.id == 8100101 })
        XCTAssertTrue(queued.contains { $0 is OutgoingScheduleInfoMessageAttribute })
        XCTAssertFalse(delivered.contains { $0 is OutgoingScheduleInfoMessageAttribute })
    }

    func testQueuedOrdinaryAtAllIsNeverPromotedAtDelivery() {
        let queued = allMentionEntitiesForLocalDemo(text: "@all", entities: [], isEnabled: false)
        XCTAssertTrue(allMentionEntitiesForScheduledDemoDelivery(text: "@all", entities: queued).isEmpty)
    }

    func testQueuedCollectiveIntentStillRespectsProtectedFormatting() {
        let queued = allMentionEntitiesForLocalDemo(text: "@all", entities: [], isEnabled: true)
        XCTAssertEqual(allMentionEntitiesForScheduledDemoDelivery(text: "@all", entities: queued), queued)
        let code = MessageTextEntity(range: 0 ..< 4, type: .Code)
        XCTAssertEqual(allMentionEntitiesForScheduledDemoDelivery(text: "@all", entities: queued + [code]), [code])
    }
}
