import Foundation
import Postbox
import TelegramCore

public enum AllMentionSendBlockReason: Equatable {
    case permissionDisabled
    case rateLimit
}

public enum AllMentionScheduledDeliveryDecision: Equatable {
    case wait
    case blocked(AllMentionSendBlockReason)
    case deliver(AllMentionGroupPermission)
}

/// Queueing never reserves a call. Check the current permission and quota only
/// when a scheduled message is due, or when the user explicitly sends it now.
public func allMentionScheduledDeliveryDecision(scheduleTime: Int32, timestamp: TimeInterval, requiresCollectiveMention: Bool, hasFailed: Bool, force: Bool, permission: AllMentionGroupPermission) -> AllMentionScheduledDeliveryDecision {
    if !force && (hasFailed || TimeInterval(scheduleTime) > timestamp) { return .wait }
    guard requiresCollectiveMention else { return .deliver(permission) }
    guard permission.isEnabled else { return .blocked(.permissionDisabled) }
    guard let reserved = permission.reservingCall(at: timestamp) else { return .blocked(.rateLimit) }
    return .deliver(reserved)
}

/// Preserve notification/effect/reply attributes through local storage and
/// scheduled delivery; only transport bookkeeping changes at these boundaries.
public func allMentionLocalOutgoingAttributes(_ attributes: [MessageAttribute], keepSchedule: Bool) -> [MessageAttribute] {
    return attributes.filter { attribute in
        if attribute is OutgoingMessageInfoAttribute { return false }
        if !keepSchedule && attribute is OutgoingScheduleInfoMessageAttribute { return false }
        return true
    }
}
