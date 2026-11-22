// Verbatim copy of the pre-refactor merge logic from
// submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift
//
// This is the ORACLE for the differential test. Do not restructure it, and do not "fix" it to
// match the new implementation — its whole value is being an unmodified record of prior behavior.
// Only two changes from the original: `private` -> no modifier, and messagesShouldBeMerged is
// renamed to referenceMessagesShouldBeMerged.

import Foundation
import Postbox
import TelegramCore
import ChatMessageItemCommon

func mediaMergeableStyle(_ media: EngineRawMedia) -> ChatMessageMerge {
    if let story = media as? TelegramMediaStory, story.isMention {
        return .none
    }
    if let file = media as? TelegramMediaFile {
        for attribute in file.attributes {
            switch attribute {
                case .Sticker:
                    return .semanticallyMerged
                case let .Video(_, _, flags, _, _, _):
                    if flags.contains(.instantRoundVideo) {
                        return .none
                    }
                default:
                    break
            }
        }
        return .fullyMerged
    }
    if let _ = media as? TelegramMediaAction {
        return .none
    }
    if let _ = media as? TelegramMediaExpiredContent {
        return .none
    }
    
    return .fullyMerged
}

func anonymousGroupAdminSignature(message: EngineRawMessage, effectiveAuthor: EngineRawPeer?) -> String? {
    guard let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info else {
        return nil
    }
    guard effectiveAuthor?.id == channel.id else {
        return nil
    }
    guard let signature = message.authorSignatureAttribute?.signature, !signature.isEmpty else {
        return nil
    }
    return signature
}

func referenceMessagesShouldBeMerged(accountPeerId: EnginePeer.Id, _ lhs: EngineRawMessage, _ rhs: EngineRawMessage) -> ChatMessageMerge {
    var lhsEffectiveAuthor: EngineRawPeer? = lhs.author
    var rhsEffectiveAuthor: EngineRawPeer? = rhs.author
    for attribute in lhs.attributes {
        if let attribute = attribute as? SourceReferenceMessageAttribute {
            lhsEffectiveAuthor = lhs.peers[attribute.messageId.peerId]
            break
        }
    }
    let lhsSourceAuthorInfo = lhs.sourceAuthorInfo
    if let sourceAuthorInfo = lhsSourceAuthorInfo {
        if let originalAuthor = sourceAuthorInfo.originalAuthor {
            lhsEffectiveAuthor = lhs.peers[originalAuthor]
        }
    }
    for attribute in rhs.attributes {
        if let attribute = attribute as? SourceReferenceMessageAttribute {
            rhsEffectiveAuthor = rhs.peers[attribute.messageId.peerId]
            break
        }
    }
    let rhsSourceAuthorInfo = rhs.sourceAuthorInfo
    if let sourceAuthorInfo = rhsSourceAuthorInfo {
        if let originalAuthor = sourceAuthorInfo.originalAuthor {
            rhsEffectiveAuthor = rhs.peers[originalAuthor]
        }
    }
    
    if let channel = lhs.peers[lhs.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info {
        if info.flags.contains(.messagesShouldHaveProfiles) {
            lhsEffectiveAuthor = lhs.author
            rhsEffectiveAuthor = rhs.author
        }
    }
    
    var sameChat = true
    if lhs.id.peerId != rhs.id.peerId {
        sameChat = false
    }
    
    var isPaid = false
    if let _ = lhs.paidStarsAttribute, let _ = rhs.paidStarsAttribute {
        isPaid = true
    }
    
    let sameThread = true
    /*if let lhsPeer = lhs.peers[lhs.id.peerId], let rhsPeer = rhs.peers[rhs.id.peerId], arePeersEqual(lhsPeer, rhsPeer), let channel = lhsPeer as? TelegramChannel, channel.isForumOrMonoForum, lhs.threadId != rhs.threadId {
        sameThread = false
    }*/
        
    var sameAuthor = false
    if lhsEffectiveAuthor?.id == rhsEffectiveAuthor?.id && lhs.effectivelyIncoming(accountPeerId) == rhs.effectivelyIncoming(accountPeerId) {
        sameAuthor = true
    }
    
    if let lhsSourceAuthorInfo, let rhsSourceAuthorInfo {
        if lhsSourceAuthorInfo.originalAuthor != rhsSourceAuthorInfo.originalAuthor {
            sameAuthor = false
        } else if lhsSourceAuthorInfo.originalAuthorName != rhsSourceAuthorInfo.originalAuthorName {
            sameAuthor = false
        }
    } else if (lhsSourceAuthorInfo == nil) != (rhsSourceAuthorInfo == nil) {
        sameAuthor = false
    }
    
    if sameAuthor {
        let lhsAnonymousAdminSignature = anonymousGroupAdminSignature(message: lhs, effectiveAuthor: lhsEffectiveAuthor)
        let rhsAnonymousAdminSignature = anonymousGroupAdminSignature(message: rhs, effectiveAuthor: rhsEffectiveAuthor)
        if lhsAnonymousAdminSignature != rhsAnonymousAdminSignature && (lhsAnonymousAdminSignature != nil || rhsAnonymousAdminSignature != nil) {
            sameAuthor = false
        }
    }

    var lhsEffectiveTimestamp = lhs.timestamp
    var rhsEffectiveTimestamp = rhs.timestamp
    
    if let lhsForwardInfo = lhs.forwardInfo, lhsForwardInfo.flags.contains(.isImported), let rhsForwardInfo = rhs.forwardInfo, rhsForwardInfo.flags.contains(.isImported) {
        lhsEffectiveTimestamp = lhsForwardInfo.date
        rhsEffectiveTimestamp = rhsForwardInfo.date
        
        if (lhsForwardInfo.author?.id != nil) == (rhsForwardInfo.author?.id != nil) && (lhsForwardInfo.authorSignature != nil) == (rhsForwardInfo.authorSignature != nil) {
            if let lhsAuthorId = lhsForwardInfo.author?.id, let rhsAuthorId = rhsForwardInfo.author?.id {
                sameAuthor = lhsAuthorId == rhsAuthorId
            } else if let lhsAuthorSignature = lhsForwardInfo.authorSignature, let rhsAuthorSignature = rhsForwardInfo.authorSignature {
                sameAuthor = lhsAuthorSignature == rhsAuthorSignature
            }
        } else {
            sameAuthor = false
        }
    }
    
    if lhs.id.peerId.isRepliesOrSavedMessages(accountPeerId: accountPeerId) {
        if let forwardInfo = lhs.forwardInfo {
            lhsEffectiveAuthor = forwardInfo.author
        }
    }
    if rhs.id.peerId.isRepliesOrSavedMessages(accountPeerId: accountPeerId) {
        if let forwardInfo = rhs.forwardInfo {
            rhsEffectiveAuthor = forwardInfo.author
        }
    }
    
    var isNonMergeablePaid = isPaid
    if isNonMergeablePaid {
        if let channel = lhs.peers[lhs.id.peerId] as? TelegramChannel, channel.flags.contains(.isMonoforum) {
            isNonMergeablePaid = false
        }
    }
    
    if abs(lhsEffectiveTimestamp - rhsEffectiveTimestamp) < Int32(10 * 60) && sameChat && sameAuthor && sameThread && !isNonMergeablePaid {
        if let channel = lhs.peers[lhs.id.peerId] as? TelegramChannel, case .group = channel.info, lhsEffectiveAuthor?.id == channel.id, !lhs.effectivelyIncoming(accountPeerId) {
            return .none
        }
        
        var upperStyle: Int32 = ChatMessageMerge.fullyMerged.rawValue
        var lowerStyle: Int32 = ChatMessageMerge.fullyMerged.rawValue
        for media in lhs.media {
            let style = mediaMergeableStyle(media).rawValue
            if style < upperStyle {
                upperStyle = style
            }
        }
        for media in rhs.media {
            let style = mediaMergeableStyle(media).rawValue
            if style < lowerStyle {
                lowerStyle = style
            }
        }
        for attribute in lhs.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    upperStyle = ChatMessageMerge.none.rawValue
                }
                break
            }
        }
        
        let style = min(upperStyle, lowerStyle)
        return ChatMessageMerge(rawValue: style)!
    }
    
    return .none
}
