import SwiftUI

/// Identifies a poll to vote on. `id` is the message id (unique within a chat),
/// so it doubles as the `.sheet(item:)` identity.
struct PollVoteTarget: Identifiable {
    let id: Int64
    let poll: PollVisual
}

/// The dedicated voting screen. Single-answer regular polls and quizzes cast
/// immediately on tap; multiple-answer polls accumulate selections behind a
/// "Vote" button. After a quiz vote, re-reads the live poll (via `currentPoll`)
/// to reveal the correct answer + explanation inline, then "Done" dismisses.
struct PollVoteView: View {
    let initialPoll: PollVisual
    /// Re-reads the latest projected poll (post-`updatePoll`) for the quiz reveal.
    let currentPoll: () -> PollVisual?
    /// Casts the vote; 0-based option positions; returns true on success.
    let onVote: ([Int]) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<Int> = []
    @State private var revealed: Bool = false
    @State private var submitting: Bool = false
    @State private var liveOverride: PollVisual?

    /// The poll to render: the live (post-vote) snapshot once revealed, else the
    /// snapshot the screen opened with.
    private var poll: PollVisual { liveOverride ?? initialPoll }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(poll.question).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(poll.options, id: \.position) { option in
                    optionButton(option)
                }
                if revealed, let explanation = poll.explanation {
                    Text(explanation).font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if poll.allowsMultipleAnswers && !revealed {
                    Button("Vote") {
                        guard !submitting else { return }
                        Task { _ = await cast(Array(selection).sorted()) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection.isEmpty || submitting)
                }
                if revealed {
                    Button("Done") { dismiss() }.buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func optionButton(_ option: PollOptionVisual) -> some View {
        Button {
            handleTap(option)
        } label: {
            HStack(spacing: 6) {
                glyph(option)
                Text(option.text).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.bordered)
        .disabled(submitting || revealed)
    }

    @ViewBuilder
    private func glyph(_ option: PollOptionVisual) -> some View {
        if revealed && poll.isQuiz {
            if option.isCorrect == true {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if option.isChosen {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            } else {
                Image(systemName: "circle")
            }
        } else if poll.allowsMultipleAnswers {
            Image(systemName: selection.contains(option.position) ? "checkmark.square.fill" : "square")
        } else {
            Image(systemName: "circle")
        }
    }

    private func handleTap(_ option: PollOptionVisual) {
        if poll.allowsMultipleAnswers && !poll.isQuiz {
            if selection.contains(option.position) { selection.remove(option.position) }
            else { selection.insert(option.position) }
            return
        }
        // Single-answer regular OR quiz: cast immediately.
        guard !submitting else { return }
        Task { _ = await cast([option.position]) }
    }

    private func cast(_ ids: [Int]) async -> Bool {
        submitting = true
        let ok = await onVote(ids)
        submitting = false
        guard ok else { return false }
        if initialPoll.isQuiz {
            // Give the resulting updatePoll a moment to land, then read the live
            // poll so the reveal shows the true correct answer + explanation.
            try? await Task.sleep(nanoseconds: 400_000_000)
            liveOverride = currentPoll() ?? initialPoll
            revealed = true
        } else {
            dismiss()
        }
        return true
    }
}

#if DEBUG
// NOTE: these render blank in the headless EmergeTools snapshot harness —
// watchOS ImageRenderer renders ScrollView content transparent. They are
// accurate in Xcode's live preview canvas; the Vote screen is verified on-sim.

#Preview("Single-answer") {
    PollVoteView(
        initialPoll: PollVisual(
            pollId: 1, question: "Favorite color?", isQuiz: false, isAnonymous: true,
            isClosed: false, allowsMultipleAnswers: false, allowsRevoting: false,
            totalVoterCount: 0, hasVoted: false, explanation: nil,
            options: [
                PollOptionVisual(position: 0, text: "Red", votePercentage: 0, voterCount: 0, isChosen: false, isBeingChosen: false, isCorrect: nil),
                PollOptionVisual(position: 1, text: "Green", votePercentage: 0, voterCount: 0, isChosen: false, isBeingChosen: false, isCorrect: nil)
            ]
        ),
        currentPoll: { nil }, onVote: { _ in true }
    )
}

#Preview("Multiple-answer") {
    PollVoteView(
        initialPoll: PollVisual(
            pollId: 1, question: "Pick toppings", isQuiz: false, isAnonymous: true,
            isClosed: false, allowsMultipleAnswers: true, allowsRevoting: false,
            totalVoterCount: 0, hasVoted: false, explanation: nil,
            options: [
                PollOptionVisual(position: 0, text: "Cheese", votePercentage: 0, voterCount: 0, isChosen: false, isBeingChosen: false, isCorrect: nil),
                PollOptionVisual(position: 1, text: "Mushroom", votePercentage: 0, voterCount: 0, isChosen: false, isBeingChosen: false, isCorrect: nil),
                PollOptionVisual(position: 2, text: "Olives", votePercentage: 0, voterCount: 0, isChosen: false, isBeingChosen: false, isCorrect: nil)
            ]
        ),
        currentPoll: { nil }, onVote: { _ in true }
    )
}
#endif
