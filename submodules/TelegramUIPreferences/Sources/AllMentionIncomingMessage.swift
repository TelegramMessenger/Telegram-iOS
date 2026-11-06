import Postbox
import TelegramCore

/// Maps a validated incoming collective entity to Telegram's existing mention
/// and notification machinery. Silent delivery still creates an unread mention.
public func allMentionIncomingAttributes(_ attributes: [MessageAttribute], isCollective: Bool, isSilent: Bool) -> [MessageAttribute] {
    var result = attributes.filter { !($0 is NotificationInfoMessageAttribute) }
    var flags = attributes.compactMap { $0 as? NotificationInfoMessageAttribute }.reduce(NotificationInfoMessageAttributeFlags()) { $0.union($1.flags) }
    if isCollective {
        flags.insert(.personal)
        result.removeAll { $0 is ConsumablePersonalMentionMessageAttribute }
        result.append(ConsumablePersonalMentionMessageAttribute(consumed: false, pending: false))
    }
    if isSilent { flags.insert(.muted) }
    if !flags.isEmpty { result.append(NotificationInfoMessageAttribute(flags: flags)) }
    return result
}

/// Local read acknowledgement: no pending network action is needed in the mock.
public func allMentionConsumedAttributes(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.map { attribute in
        if attribute is ConsumablePersonalMentionMessageAttribute {
            return ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
        }
        return attribute
    }
}
