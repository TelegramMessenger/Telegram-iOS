import Foundation
import TDShim

/// Per-poll data the bubble consumes. Projected from `messagePoll`. Mutually
/// exclusive with the other `MessageBubble` media fields.
struct PollVisual: Equatable, Hashable {
    /// The poll's own id (NOT the message id). Used to match `updatePoll`.
    let pollId: TdInt64
    let question: String
    let isQuiz: Bool
    let isAnonymous: Bool
    let isClosed: Bool
    let allowsMultipleAnswers: Bool
    /// Regular polls only; always false for quizzes.
    let allowsRevoting: Bool
    let totalVoterCount: Int
    /// True if any option is `isChosen` — i.e. the current user has voted.
    let hasVoted: Bool
    /// Quiz explanation; nil for regular polls and for quizzes the user hasn't
    /// answered yet (TDLib leaves it empty until then).
    let explanation: String?
    let options: [PollOptionVisual]

    /// Percent bars / vote counts are only meaningful once the user has voted or
    /// the poll has closed — TDLib doesn't populate them before then.
    var resultsVisible: Bool { hasVoted || isClosed }
}

struct PollOptionVisual: Equatable, Hashable {
    /// 0-based index into the poll's options — the value passed to `setPollAnswer`.
    let position: Int
    let text: String
    let votePercentage: Int
    let voterCount: Int
    let isChosen: Bool
    let isBeingChosen: Bool
    /// Quiz only: true if this option is a correct answer. nil for regular polls.
    /// Only meaningful once `correctOptionIds` is populated (after answering/close).
    let isCorrect: Bool?
}

/// Builds a `PollVisual` for `messagePoll` content, or returns `nil` for any other
/// content. Internal (not `private`) so `PollVisualTests` can exercise it directly
/// via `@testable import`, matching the `voiceNoteVisual`/`locationVisual` precedent.
func pollVisual(for content: MessageContent) -> PollVisual? {
    guard case .messagePoll(let m) = content else { return nil }
    let poll = m.poll

    let isQuiz: Bool
    let correctIds: [Int]
    let explanationText: String?
    if case .pollTypeQuiz(let quiz) = poll.type {
        isQuiz = true
        correctIds = quiz.correctOptionIds
        explanationText = quiz.explanation.text.isEmpty ? nil : quiz.explanation.text
    } else {
        isQuiz = false
        correctIds = []
        explanationText = nil
    }

    let options = poll.options.enumerated().map { idx, opt in
        PollOptionVisual(
            position: idx,
            text: opt.text.text,
            votePercentage: opt.votePercentage,
            voterCount: opt.voterCount,
            isChosen: opt.isChosen,
            isBeingChosen: opt.isBeingChosen,
            isCorrect: isQuiz ? correctIds.contains(idx) : nil
        )
    }

    return PollVisual(
        pollId: poll.id,
        question: poll.question.text,
        isQuiz: isQuiz,
        isAnonymous: poll.isAnonymous,
        isClosed: poll.isClosed,
        allowsMultipleAnswers: poll.allowsMultipleAnswers,
        allowsRevoting: poll.allowsRevoting,
        totalVoterCount: poll.totalVoterCount,
        hasVoted: poll.options.contains { $0.isChosen },
        explanation: explanationText,
        options: options
    )
}
