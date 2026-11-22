import Foundation
import TelegramCore

/// A post's `feed.likePost` or `feed.dislikePost`.
public enum NewsPostVote: Equatable {
    case like
    case dislike
}

public struct NewsPostVoteRequest: Equatable {
    public let messageId: EngineMessage.Id
    public let vote: NewsPostVote

    public init(messageId: EngineMessage.Id, vote: NewsPostVote) {
        self.messageId = messageId
        self.vote = vote
    }
}

/// Votes go out one at a time, in the order they were cast: an Undo's like must reach the server after the dislike
/// it takes back, and nothing orders two requests in flight.
public struct NewsPostVoteQueue {
    private var pending: [NewsPostVoteRequest] = []
    private var isSending = false

    public init() {
    }

    /// Queues the vote; returns it to send now when no vote is in flight.
    public mutating func cast(_ vote: NewsPostVote, messageId: EngineMessage.Id) -> NewsPostVoteRequest? {
        self.pending.append(NewsPostVoteRequest(messageId: messageId, vote: vote))
        if self.isSending {
            return nil
        }
        return self.takeNext()
    }

    /// The vote in flight finished; returns the next one to send, if any.
    public mutating func finished() -> NewsPostVoteRequest? {
        self.isSending = false
        return self.takeNext()
    }

    private mutating func takeNext() -> NewsPostVoteRequest? {
        guard !self.pending.isEmpty else {
            return nil
        }
        self.isSending = true
        return self.pending.removeFirst()
    }
}
