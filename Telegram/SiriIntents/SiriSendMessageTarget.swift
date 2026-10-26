import Foundation
import Intents
import Postbox
import TelegramCore

/// The chat a Siri `INSendMessageIntent` is addressed to.
///
/// A reply to a message Siri just read arrives with that message's `conversationIdentifier`
/// (the chat's peer id, as `INMessage` published it) and the message's sender as recipient.
/// For a group message those differ, and sending to the recipient would drop a group reply
/// into the author's private chat, so the conversation wins whenever it is present. Without
/// one, the recipient is a person this extension resolved earlier, whose `customIdentifier`
/// is `tg<peerId>`.
func siriSendMessageTarget(conversationIdentifier: String?, recipientCustomIdentifier: String?) -> PeerId? {
    if let conversationIdentifier, let peerIdValue = Int64(conversationIdentifier) {
        return PeerId(peerIdValue)
    }
    if let recipientCustomIdentifier, recipientCustomIdentifier.hasPrefix("tg"), let peerIdValue = Int64(recipientCustomIdentifier.dropFirst(2)) {
        return PeerId(peerIdValue)
    }
    return nil
}

/// Whether Siri may send a message to this peer.
///
/// The standalone send swallows the server's refusal, so a chat the user cannot write to has to
/// be refused here or Siri would report the reply as sent: users that still exist and do not
/// gate their messages (paid messages are never spent from Siri; a Premium gate is honoured
/// unless the account is Premium), groups the user is still a member of and may post text in,
/// never a broadcast channel (Siri can read its posts, but a "reply" there is not a thing the
/// user can be offered), never a chat that charges for messages, and not yet a forum or
/// monoforum, because `INMessage.conversationIdentifier` names the chat only and the reply
/// would land in the wrong topic.
///
/// `cachedData` is the peer's `CachedUserData` when the store has it; it is refreshed only when
/// the chat is opened, while the user's own flags arrive with every update, so either source
/// saying the chat is gated is enough to refuse. `isAccountPeer` is the account itself (Saved
/// Messages), which is never gated.
func peerAcceptsSiriMessages(_ peer: Peer, cachedData: CachedPeerData? = nil, accountIsPremium: Bool = false, isAccountPeer: Bool = false) -> Bool {
    switch peer {
    case let user as TelegramUser:
        if user.isDeleted || isServicePeer(user) {
            return false
        }
        if isAccountPeer {
            return true
        }
        if let cachedData = cachedData as? CachedUserData, cachedData.isBlocked {
            return false
        }
        // The same gate the app applies before it asks the server; Siri cannot ask, and a
        // paid message is never something to spend from a voice reply.
        switch localRequirementToContact(peer: user, cachedData: cachedData) {
        case .stars:
            return false
        case .premium:
            return accountIsPremium
        case nil:
            return true
        }
    case let group as TelegramGroup:
        if group.membership != .Member {
            return false
        }
        if group.flags.contains(.deactivated) || group.migrationReference != nil {
            return false
        }
        return !group.hasBannedPermission(.banSendText)
    case let channel as TelegramChannel:
        if case .broadcast = channel.info {
            return false
        }
        if channel.participationStatus != .member {
            return false
        }
        if channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum) {
            return false
        }
        if channel.sendPaidMessageStars != nil {
            return false
        }
        return channel.hasBannedPermission(.banSendText) == nil
    default:
        return false
    }
}

/// What recipient resolution says about a peer Siri named, by conversation or by a person
/// this extension handed it earlier.
enum SiriRecipientDecision {
    /// The peer is not in the store; Siri has to ask again.
    case unknown
    /// The peer exists but is not something the user may message (a channel, a forum, a chat
    /// they cannot write to). Siri says so, and no send is attempted.
    case refused
    /// The peer Siri should address, as the person it will hand back in the send.
    case person(INPerson)
}

/// Every recipient Siri resolves goes through this, so `peerAcceptsSiriMessages` is applied
/// before Siri ever confirms a message, not only when the send runs.
func siriRecipientDecision(for peer: Peer?, cachedData: CachedPeerData? = nil, accountIsPremium: Bool = false, isAccountPeer: Bool = false) -> SiriRecipientDecision {
    guard let peer else {
        return .unknown
    }
    if !peerAcceptsSiriMessages(peer, cachedData: cachedData, accountIsPremium: accountIsPremium, isAccountPeer: isAccountPeer) {
        return .refused
    }
    return .person(personWithPeer(stableId: "tg\(peer.id.toInt64())", peer: peer))
}

/// Everything the recipient decision reads from the store for one peer.
private struct SiriRecipientContext {
    var peer: Peer?
    var cachedData: CachedPeerData?
    var accountIsPremium: Bool
    var isAccountPeer: Bool

    init(transaction: Transaction, accountPeerId: PeerId, peerId: PeerId) {
        self.peer = transaction.getPeer(peerId)
        self.cachedData = transaction.getPeerCachedData(peerId: peerId)
        self.accountIsPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
        self.isAccountPeer = peerId == accountPeerId
    }
}

/// The same decision, read out of the store: the peer, its cached data and whether the account
/// itself is Premium. Recipient resolution goes through this; the send goes through
/// `siriRecipientAccepted`, which reads the same rows, so the send can never accept a peer
/// that resolution refused.
func siriRecipientDecision(transaction: Transaction, accountPeerId: PeerId, peerId: PeerId) -> SiriRecipientDecision {
    let context = SiriRecipientContext(transaction: transaction, accountPeerId: accountPeerId, peerId: peerId)
    return siriRecipientDecision(for: context.peer, cachedData: context.cachedData, accountIsPremium: context.accountIsPremium, isAccountPeer: context.isAccountPeer)
}

/// Whether the send may go ahead: the yes/no half of `siriRecipientDecision`, without building
/// the person Siri would be handed (the send has nobody to hand it to).
func siriRecipientAccepted(transaction: Transaction, accountPeerId: PeerId, peerId: PeerId) -> Bool {
    let context = SiriRecipientContext(transaction: transaction, accountPeerId: accountPeerId, peerId: peerId)
    guard let peer = context.peer else {
        return false
    }
    return peerAcceptsSiriMessages(peer, cachedData: context.cachedData, accountIsPremium: context.accountIsPremium, isAccountPeer: context.isAccountPeer)
}
