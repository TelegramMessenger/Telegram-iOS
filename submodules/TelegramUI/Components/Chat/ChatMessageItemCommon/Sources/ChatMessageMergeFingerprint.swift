import Foundation
import Postbox
import TelegramCore

private func mediaMergeableStyle(_ media: EngineRawMedia) -> ChatMessageMerge {
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

public struct ChatMessageSourceAuthorKey: Equatable {
    public let originalAuthor: EnginePeer.Id?
    public let originalAuthorName: String?
}

/// A per-message projection sufficient to reproduce the pairwise merge decision against any other
/// message's projection.
///
/// Stores raw *ingredients* rather than resolved values. Three branches of the original
/// `messagesShouldBeMerged` read only the upper message and apply the answer to both sides, so
/// resolution has to happen pairwise in `chatMessageMerge(upper:lower:)`.
public struct ChatMessageMergeFingerprint: Equatable {
    let peerId: EnginePeer.Id
    let isEphemeral: Bool
    let isWelcomeMessage: Bool
    let rawAuthorId: EnginePeer.Id?
    let overriddenAuthorId: EnginePeer.Id?
    let hasBroadcastProfiles: Bool
    let groupChannelId: EnginePeer.Id?
    let isMonoforumChannel: Bool
    let authorSignature: String?
    let isEffectivelyIncoming: Bool
    let isRepliesOrSavedMessages: Bool
    let sourceAuthorInfo: ChatMessageSourceAuthorKey?
    let hasForwardInfo: Bool
    let forwardAuthorId: EnginePeer.Id?
    let forwardAuthorSignature: String?
    let importedForwardDate: Int32?
    let timestamp: Int32
    let hasPaidStars: Bool
    let mediaMergeStyle: Int32
    let hasInlineReplyMarkup: Bool

    public init(message: EngineRawMessage, accountPeerId: EnginePeer.Id) {
        self.peerId = message.id.peerId
        self.isEphemeral = Namespaces.Message.allEphemeral.contains(message.id.namespace) || Namespaces.Message.allWelcomeMessages.contains(message.id.namespace)
        self.isWelcomeMessage = Namespaces.Message.allWelcomeMessages.contains(message.id.namespace)
        self.rawAuthorId = message.author?.id
        self.timestamp = message.timestamp
        self.isEffectivelyIncoming = message.effectivelyIncoming(accountPeerId)
        self.isRepliesOrSavedMessages = message.id.peerId.isRepliesOrSavedMessages(accountPeerId: accountPeerId)

        // Resolution order mirrors the original exactly: author, then
        // SourceReferenceMessageAttribute, then sourceAuthorInfo.originalAuthor. The
        // messagesShouldHaveProfiles override is NOT applied here — it is applied pairwise,
        // because the original gates it on the *upper* message's channel.
        var overriddenAuthorId = message.author?.id
        for attribute in message.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                overriddenAuthorId = message.peers[attribute.messageId.peerId]?.id
                break
            }
        }
        let sourceAuthorInfo = message.sourceAuthorInfo
        if let sourceAuthorInfo = sourceAuthorInfo, let originalAuthor = sourceAuthorInfo.originalAuthor {
            overriddenAuthorId = message.peers[originalAuthor]?.id
        }
        self.overriddenAuthorId = overriddenAuthorId
        self.sourceAuthorInfo = sourceAuthorInfo.flatMap { info in
            return ChatMessageSourceAuthorKey(originalAuthor: info.originalAuthor,
                                              originalAuthorName: info.originalAuthorName)
        }

        var hasBroadcastProfiles = false
        var groupChannelId: EnginePeer.Id?
        var isMonoforumChannel = false
        if let channel = message.peers[message.id.peerId] as? TelegramChannel {
            switch channel.info {
            case let .broadcast(info):
                hasBroadcastProfiles = info.flags.contains(.messagesShouldHaveProfiles)
            case .group:
                groupChannelId = channel.id
            }
            isMonoforumChannel = channel.flags.contains(.isMonoforum)
        }
        self.hasBroadcastProfiles = hasBroadcastProfiles
        self.groupChannelId = groupChannelId
        self.isMonoforumChannel = isMonoforumChannel

        if let signature = message.authorSignatureAttribute?.signature, !signature.isEmpty {
            self.authorSignature = signature
        } else {
            self.authorSignature = nil
        }

        self.hasForwardInfo = message.forwardInfo != nil
        self.forwardAuthorId = message.forwardInfo?.author?.id
        self.forwardAuthorSignature = message.forwardInfo?.authorSignature
        if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) {
            self.importedForwardDate = forwardInfo.date
        } else {
            self.importedForwardDate = nil
        }

        self.hasPaidStars = message.paidStarsAttribute != nil

        var mediaMergeStyle = ChatMessageMerge.fullyMerged.rawValue
        for media in message.media {
            let style = mediaMergeableStyle(media).rawValue
            if style < mediaMergeStyle {
                mediaMergeStyle = style
            }
        }
        self.mediaMergeStyle = mediaMergeStyle

        var hasInlineReplyMarkup = false
        for attribute in message.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    hasInlineReplyMarkup = true
                }
                break
            }
        }
        self.hasInlineReplyMarkup = hasInlineReplyMarkup
    }
}

private func anonymousSignature(_ fingerprint: ChatMessageMergeFingerprint,
                                effectiveAuthorId: EnginePeer.Id?) -> String? {
    guard let groupChannelId = fingerprint.groupChannelId, effectiveAuthorId == groupChannelId else {
        return nil
    }
    return fingerprint.authorSignature
}

/// Whether the message described by `upper` should visually merge with the one below it, described
/// by `lower`. Exact replacement for the former `messagesShouldBeMerged(accountPeerId:_:_:)`.
public func chatMessageMerge(upper: ChatMessageMergeFingerprint,
                             lower: ChatMessageMergeFingerprint) -> ChatMessageMerge {
    if upper.isEphemeral != lower.isEphemeral {
        return .none
    }

    // Read from the upper message only, as the original reads it from lhs.
    let useRawAuthors = upper.hasBroadcastProfiles
    var upperEffectiveAuthorId = useRawAuthors ? upper.rawAuthorId : upper.overriddenAuthorId
    let lowerEffectiveAuthorId = useRawAuthors ? lower.rawAuthorId : lower.overriddenAuthorId

    var sameChat = true
    if upper.peerId != lower.peerId {
        sameChat = false
    }

    var isPaid = false
    if upper.hasPaidStars && lower.hasPaidStars {
        isPaid = true
    }

    // The original's real thread check is commented out and hard-coded true. Preserved.
    let sameThread = true

    var sameAuthor = false
    if upperEffectiveAuthorId == lowerEffectiveAuthorId
        && upper.isEffectivelyIncoming == lower.isEffectivelyIncoming {
        sameAuthor = true
    }

    if let upperSource = upper.sourceAuthorInfo, let lowerSource = lower.sourceAuthorInfo {
        if upperSource.originalAuthor != lowerSource.originalAuthor {
            sameAuthor = false
        } else if upperSource.originalAuthorName != lowerSource.originalAuthorName {
            sameAuthor = false
        }
    } else if (upper.sourceAuthorInfo == nil) != (lower.sourceAuthorInfo == nil) {
        sameAuthor = false
    }

    if sameAuthor {
        let upperSignature = anonymousSignature(upper, effectiveAuthorId: upperEffectiveAuthorId)
        let lowerSignature = anonymousSignature(lower, effectiveAuthorId: lowerEffectiveAuthorId)
        if upperSignature != lowerSignature && (upperSignature != nil || lowerSignature != nil) {
            sameAuthor = false
        }
    }

    var upperEffectiveTimestamp = upper.timestamp
    var lowerEffectiveTimestamp = lower.timestamp

    // Only when BOTH sides are imported forwards. This replaces sameAuthor wholesale, discarding
    // the anonymous-admin adjustment computed above — keep that ordering.
    if let upperImported = upper.importedForwardDate, let lowerImported = lower.importedForwardDate {
        upperEffectiveTimestamp = upperImported
        lowerEffectiveTimestamp = lowerImported

        if (upper.forwardAuthorId != nil) == (lower.forwardAuthorId != nil)
            && (upper.forwardAuthorSignature != nil) == (lower.forwardAuthorSignature != nil) {
            if let upperAuthorId = upper.forwardAuthorId, let lowerAuthorId = lower.forwardAuthorId {
                sameAuthor = upperAuthorId == lowerAuthorId
            } else if let upperSignature = upper.forwardAuthorSignature,
                      let lowerSignature = lower.forwardAuthorSignature {
                sameAuthor = upperSignature == lowerSignature
            }
        } else {
            sameAuthor = false
        }
    }

    // The original applies this swap to both sides, but only ever reads the upper effective author
    // afterwards, so the lower side's swap has no observable effect. Resolves to nil when the
    // forward has no author — intentional, matching `lhsEffectiveAuthor = forwardInfo.author`.
    if upper.isRepliesOrSavedMessages, upper.hasForwardInfo {
        upperEffectiveAuthorId = upper.forwardAuthorId
    }

    var isNonMergeablePaid = isPaid
    if isNonMergeablePaid, upper.isMonoforumChannel {
        isNonMergeablePaid = false
    }

    // Welcome templates can be created far apart, but recipients receive them as one batch.
    let isWelcomeMessagePair = upper.isWelcomeMessage && lower.isWelcomeMessage
    if (isWelcomeMessagePair || abs(upperEffectiveTimestamp - lowerEffectiveTimestamp) < Int32(10 * 60))
        && sameChat && sameAuthor && sameThread && !isNonMergeablePaid {
        if let groupChannelId = upper.groupChannelId,
           upperEffectiveAuthorId == groupChannelId,
           !upper.isEffectivelyIncoming {
            return .none
        }

        var upperStyle = upper.mediaMergeStyle
        let lowerStyle = lower.mediaMergeStyle
        if upper.hasInlineReplyMarkup {
            upperStyle = ChatMessageMerge.none.rawValue
        }
        return ChatMessageMerge(rawValue: min(upperStyle, lowerStyle))!
    }

    return .none
}
