import SwiftUI

/// Renders one poll / quiz bubble inside the standard gray-incoming / accent-outgoing
/// chrome. Shows the question, option rows (with result bars + percentages once
/// `resultsVisible`), quiz correct/chosen markers + explanation, a voter-count footer,
/// and a "Vote" button when the poll is still actionable. Tapping Vote calls
/// `onVote`, which opens the dedicated `PollVoteView`.
struct PollBubbleView: View {
    let poll: PollVisual
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?
    let onVote: () -> Void

    @Environment(\.bubbleMetrics) private var metrics
    private var maxWidth: CGFloat { metrics.bubbleMaxWidth }
    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }

    private var typeLabel: String {
        if poll.isClosed { return "Final results" }
        if poll.isQuiz { return "Quiz" }
        return poll.isAnonymous ? "Anonymous Poll" : "Poll"
    }

    private var canVote: Bool {
        guard !poll.isClosed else { return false }
        if poll.isQuiz { return !poll.hasVoted }
        return !poll.hasVoted || poll.allowsRevoting
    }

    private var voterCountLabel: String {
        poll.totalVoterCount == 0
            ? "No votes yet"
            : "\(poll.totalVoterCount) voter\(poll.totalVoterCount == 1 ? "" : "s")"
    }

    private var secondaryColor: Color { style.secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: BubbleStyle.resolve(isOutgoing: isOutgoing))
            }
            Text(typeLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(secondaryColor)
            Text(poll.question)
                .font(.caption).bold()
                .fixedSize(horizontal: false, vertical: true)
            ForEach(poll.options, id: \.position) { option in
                optionRow(option)
            }
            if let explanation = poll.explanation {
                Text(explanation)
                    .font(.system(size: 9))
                    .foregroundStyle(secondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if canVote {
                Button(action: onVote) {
                    Text("Vote").font(.caption2).bold().frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            Text(voterCountLabel)
                .font(.system(size: 9))
                .foregroundStyle(secondaryColor)
        }
        .padding(8)
        .frame(minWidth: BubbleShape.minSize, maxWidth: maxWidth, minHeight: BubbleShape.minSize, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BubbleShape.cornerRadius)
                .fill(style.fill)
        )
        .foregroundStyle(style.content)
    }

    @ViewBuilder
    private func optionRow(_ option: PollOptionVisual) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                optionGlyph(option).font(.system(size: 11))
                Text(option.text).font(.caption2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if poll.resultsVisible {
                    Text("\(option.votePercentage)%")
                        .font(.system(size: 9)).foregroundStyle(secondaryColor)
                }
            }
            if poll.resultsVisible {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(secondaryColor.opacity(0.25)).frame(height: 3)
                        Capsule().fill(barColor(option))
                            .frame(width: geo.size.width * CGFloat(option.votePercentage) / 100, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
    }

    @ViewBuilder
    private func optionGlyph(_ option: PollOptionVisual) -> some View {
        if poll.isQuiz, poll.resultsVisible, let correct = option.isCorrect {
            if correct {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if option.isChosen {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            } else {
                Image(systemName: "circle").foregroundStyle(secondaryColor)
            }
        } else if option.isChosen {
            Image(systemName: "checkmark.circle.fill")
        } else {
            Image(systemName: "circle").foregroundStyle(secondaryColor)
        }
    }

    private func barColor(_ option: PollOptionVisual) -> Color {
        if poll.isQuiz, let correct = option.isCorrect {
            if correct { return .green }
            if option.isChosen { return .red }
        }
        return isOutgoing ? Color.white : Color.accentColor
    }
}

#if DEBUG
private func previewOption(
    _ text: String, position: Int = 0, pct: Int = 0, chosen: Bool = false, correct: Bool? = nil
) -> PollOptionVisual {
    PollOptionVisual(position: position, text: text, votePercentage: pct, voterCount: pct,
                     isChosen: chosen, isBeingChosen: false, isCorrect: correct)
}

#Preview("Regular — unvoted (incoming)") {
    PollBubbleView(
        poll: PollVisual(
            pollId: 1, question: "Favorite color?", isQuiz: false, isAnonymous: true,
            isClosed: false, allowsMultipleAnswers: false, allowsRevoting: false,
            totalVoterCount: 0, hasVoted: false, explanation: nil,
            options: [previewOption("Red", position: 0), previewOption("Green", position: 1), previewOption("Blue", position: 2)]
        ),
        isOutgoing: false, replyHeader: nil, onVote: {}
    ).bubblePreview()
}

#Preview("Regular — voted (outgoing)") {
    PollBubbleView(
        poll: PollVisual(
            pollId: 1, question: "Favorite color?", isQuiz: false, isAnonymous: true,
            isClosed: false, allowsMultipleAnswers: false, allowsRevoting: false,
            totalVoterCount: 4, hasVoted: true, explanation: nil,
            options: [previewOption("Red", position: 0, pct: 75, chosen: true),
                      previewOption("Green", position: 1, pct: 25)]
        ),
        isOutgoing: true, replyHeader: nil, onVote: {}
    ).bubblePreview()
}

#Preview("Quiz — answered wrong (incoming)") {
    PollBubbleView(
        poll: PollVisual(
            pollId: 1, question: "Capital of France?", isQuiz: true, isAnonymous: true,
            isClosed: false, allowsMultipleAnswers: false, allowsRevoting: false,
            totalVoterCount: 9, hasVoted: true, explanation: "Paris is the capital.",
            options: [previewOption("Berlin", position: 0, pct: 30, chosen: true, correct: false),
                      previewOption("Paris", position: 1, pct: 60, correct: true),
                      previewOption("Rome", position: 2, pct: 10, correct: false)]
        ),
        isOutgoing: false, replyHeader: nil, onVote: {}
    ).bubblePreview()
}

#Preview("Closed — final results") {
    PollBubbleView(
        poll: PollVisual(
            pollId: 1, question: "Best day?", isQuiz: false, isAnonymous: true,
            isClosed: true, allowsMultipleAnswers: false, allowsRevoting: false,
            totalVoterCount: 12, hasVoted: false, explanation: nil,
            options: [previewOption("Sat", position: 0, pct: 58), previewOption("Sun", position: 1, pct: 42)]
        ),
        isOutgoing: false, replyHeader: nil, onVote: {}
    ).bubblePreview()
}
#endif
