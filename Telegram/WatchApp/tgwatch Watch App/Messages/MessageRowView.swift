import SwiftUI

struct MessageRowView: View {
    let row: MessageRow
    let onPhotoTap: (PhotoVisual) -> Void
    let onVideoTap: (VideoVisual) -> Void
    let onVideoNoteTap: (VideoNoteVisual) -> Void
    let onPollTap: (Int64, PollVisual) -> Void
    var index: Int = 0
    var count: Int = 1
    var onEnterTopEdge: (() -> Void)? = nil
    var onEnterBottomEdge: (() -> Void)? = nil
    var onIncomingBubbleVisible: ((Int64) -> Void)? = nil

    var body: some View {
        if #available(watchOS 11.0, *) {
            rowBody.onScrollVisibilityChange(threshold: 0.01) { visible in
                guard visible else { return }
                if index <= 2 { onEnterTopEdge?() }
                if index >= count - 3 { onEnterBottomEdge?() }
            }
        } else {
            rowBody.onAppear {
                if index <= 2 { onEnterTopEdge?() }
                if index >= count - 3 { onEnterBottomEdge?() }
            }
        }
    }

    @ViewBuilder
    private var rowBody: some View {
        switch row {
        case .bubble(let b):
            bubbleRow(b)
        case .service(let s):      ServiceMessageView(line: s)
        case .daySeparator(let d): DaySeparatorView(label: d)
        case .unreadDivider:       UnreadDividerView()
        }
    }

    @ViewBuilder
    private func bubbleRow(_ b: MessageBubble) -> some View {
        let bubble = MessageBubbleView(bubble: b, onPhotoTap: onPhotoTap, onVideoTap: onVideoTap, onVideoNoteTap: onVideoNoteTap, onPollTap: onPollTap)
        if #available(watchOS 11.0, *) {
            bubble.onScrollVisibilityChange(threshold: 0.5) { visible in
                guard visible, !b.isOutgoing else { return }
                onIncomingBubbleVisible?(b.messageId)
            }
        } else {
            bubble.onAppear {
                guard !b.isOutgoing else { return }
                onIncomingBubbleVisible?(b.messageId)
            }
        }
    }
}
