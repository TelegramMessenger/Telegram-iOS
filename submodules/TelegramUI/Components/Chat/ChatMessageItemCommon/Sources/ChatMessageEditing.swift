import Foundation
import TelegramCore

/// Whether the account may edit `message`: the rule behind the Edit context-menu item, up-arrow
/// editing and rescheduling. `reschedule` skips the uneditable-content checks and the time limit.
public func canEditMessage(accountPeerId: EnginePeer.Id, limitsConfiguration: EngineConfiguration.Limits, message: EngineRawMessage, reschedule: Bool = false) -> Bool {
    var hasEditRights = false
    var unlimitedInterval = reschedule

    if message.id.namespace == Namespaces.Message.ScheduledCloud {
        if let peer = message.peers[message.id.peerId], let channel = peer as? TelegramChannel {
            switch channel.info {
                case .broadcast:
                    if channel.hasPermission(.editAllMessages) || !message.flags.contains(.Incoming) {
                        hasEditRights = true
                    }
                default:
                    hasEditRights = true
            }
        } else {
            hasEditRights = true
        }
    } else if message.id.namespace == Namespaces.Message.QuickReplyCloud {
        hasEditRights = true
    } else if message.id.namespace == Namespaces.Message.WelcomeMessageCloud {
        hasEditRights = true
        unlimitedInterval = true
    } else if message.id.peerId.namespace == Namespaces.Peer.SecretChat || message.id.namespace != Namespaces.Message.Cloud {
        hasEditRights = false
    } else if let author = message.author, author.id == accountPeerId, let peer = message.peers[message.id.peerId] {
        hasEditRights = true
        if let peer = peer as? TelegramChannel {
            if peer.flags.contains(.isGigagroup) {
                if peer.flags.contains(.isCreator) || peer.adminRights != nil {
                    hasEditRights = true
                } else {
                    hasEditRights = false
                }
            }
            switch peer.info {
            case .broadcast:
                if peer.hasPermission(.editAllMessages) || !message.flags.contains(.Incoming) {
                    unlimitedInterval = true
                }
            case .group:
                if peer.hasPermission(.pinMessages) {
                    unlimitedInterval = true
                }
            }
        }
    } else if let author = message.author, message.author?.id != message.id.peerId, author.id.namespace == Namespaces.Peer.CloudChannel && message.id.peerId.namespace == Namespaces.Peer.CloudChannel, !message.flags.contains(.Incoming) {
        if message.media.contains(where: { $0 is TelegramMediaInvoice }) {
            hasEditRights = false
        } else {
            hasEditRights = true
        }
    } else if message.author?.id == message.id.peerId, let peer = message.peers[message.id.peerId] {
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.hasPermission(.editAllMessages) || !message.flags.contains(.Incoming) {
                    unlimitedInterval = true
                    hasEditRights = true
                }
            case .group:
                // Sent as the group by an anonymous admin. Only the sender's copy is outgoing; the
                // pin right lifts the time limit, as it does for the admin's own messages.
                if !message.flags.contains(.Incoming) {
                    hasEditRights = true
                    if peer.hasPermission(.pinMessages) {
                        unlimitedInterval = true
                    }
                }
            }
        }
    }

    var hasUneditableAttributes = false

    if hasEditRights {
        for attribute in message.attributes {
            if let _ = attribute as? InlineBotMessageAttribute {
                hasUneditableAttributes = true
                break
            } else if let _ = attribute as? PublishedSuggestedPostMessageAttribute, message.timestamp > Int32(Date().timeIntervalSince1970) - 60 * 60 * 24 {
                hasUneditableAttributes = true
                break
            }
        }
        if message.forwardInfo != nil {
            hasUneditableAttributes = true
        }

        for media in message.media {
            if let file = media as? TelegramMediaFile {
                if file.isSticker || file.isAnimatedSticker || file.isInstantVideo {
                    hasUneditableAttributes = true
                    break
                }
            } else if let _ = media as? TelegramMediaContact {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaExpiredContent {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaMap {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaPoll {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaDice {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaGame {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaInvoice {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaStory {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaGiveaway {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaGiveawayResults {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaAction {
                hasUneditableAttributes = true
                break
            } else if let _ = media as? TelegramMediaTodo {
                unlimitedInterval = true
            }
        }

        if !hasUneditableAttributes || reschedule {
            if canPerformEditingActions(limits: limitsConfiguration._asLimits(), accountPeerId: accountPeerId, message: message, unlimitedInterval: unlimitedInterval) {
                return true
            }
        }
    }
    return false
}

private func canPerformEditingActions(limits: LimitsConfiguration, accountPeerId: EnginePeer.Id, message: EngineRawMessage, unlimitedInterval: Bool) -> Bool {
    if message.id.peerId == accountPeerId {
        return true
    }

    if unlimitedInterval {
        return true
    }

    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    if Int64(message.timestamp) + Int64(limits.maxMessageEditingInterval) > Int64(timestamp) {
        return true
    }

    return false
}
