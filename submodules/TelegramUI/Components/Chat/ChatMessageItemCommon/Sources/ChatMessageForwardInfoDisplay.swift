import Foundation
import Postbox
import TelegramCore

/// The forward header an item node last applied.
///
/// `Message.forwardInfo.author` is resolved through the peer table
/// (`MessageHistoryTable.renderMessage`), so it is nil whenever the author peer has not been
/// fetched yet — for a plain forward that also means no `authorSignature`, i.e. no name at all.
/// Retaining the last applied values lets the header keep the name and avatar it already showed
/// instead of blanking out and then filling back in once the peer arrives.
///
/// The `messageId` is what makes that safe: item nodes are reused for unrelated messages, and a
/// cache with no identity hands the next message the previous one's sender.
public struct ChatMessageAppliedForwardInfo {
    public let messageId: MessageId
    public let source: Peer?
    public let authorSignature: String?

    public init(messageId: MessageId, source: Peer?, authorSignature: String?) {
        self.messageId = messageId
        self.source = source
        self.authorSignature = authorSignature
    }
}

/// Resolves the `(source, authorSignature)` pair an item node passes to
/// `ChatMessageForwardInfoNode.asyncLayout`, and which it then stores back as
/// `appliedForwardInfo`.
///
/// `peerDisplayTitle` renders a peer's name; it is a closure so that this module does not need to
/// depend on the presentation strings.
public func chatMessageForwardInfoDisplay(
    forwardInfo: MessageForwardInfo,
    messageId: MessageId,
    previouslyApplied: ChatMessageAppliedForwardInfo?,
    peerDisplayTitle: (Peer) -> String
) -> ChatMessageAppliedForwardInfo {
    let source: Peer?
    let authorSignature: String?

    if let forwardSource = forwardInfo.source {
        source = forwardSource
        if let signature = forwardInfo.authorSignature {
            authorSignature = signature
        } else if let author = forwardInfo.author, author.id != forwardSource.id {
            authorSignature = peerDisplayTitle(author)
        } else {
            authorSignature = nil
        }
    } else if forwardInfo.author == nil, let previouslyApplied, previouslyApplied.messageId == messageId, previouslyApplied.source != nil {
        // The author peer is not available right now: keep displaying what this same message last
        // resolved to. An anonymous forward also has a nil author, but it carries its name in
        // `authorSignature` and never resolved to a source, so it never reaches this branch for
        // its own previous value.
        source = previouslyApplied.source
        authorSignature = previouslyApplied.authorSignature
    } else {
        source = forwardInfo.author
        authorSignature = forwardInfo.authorSignature
    }

    return ChatMessageAppliedForwardInfo(messageId: messageId, source: source, authorSignature: authorSignature)
}
