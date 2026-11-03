import SwiftUI
import OSLog

private let pillLogger = Logger(subsystem: "com.isaac.tgwatch", category: "chatlist")

/// Horizontal scroller of folder pills. Embedded as the first item inside the chat list's
/// scrollable area so it scrolls off with the content. Stable `.id("folderPillBar")` keeps
/// the inner horizontal `ScrollView` offset preserved across folder switches.
///
/// `.focusable(false)` keeps the digital crown bound to the outer chat list. Otherwise
/// tapping a pill would park crown focus on this horizontal ScrollView, where rotation has
/// no useful effect (one-axis, short content), and the user would lose vertical scroll
/// until they manually touched the chat list again.
///
/// `onUserInteraction` fires on any horizontal pan (via `onScrollGeometryChange`) so the
/// caller can re-assert digital-crown focus on the outer chat list after a scroll gesture
/// that bypasses normal gesture recognizers.
struct FolderPillBar: View {
    let pills: [FolderPill]
    let onSelect: (FolderPill) -> Void
    /// Called when the user horizontally pans the pill bar. ChatListView uses this to
    /// re-assert digital-crown focus on the outer List (horizontal scroll bypasses the
    /// `simultaneousGesture` workaround on the List row).
    let onUserInteraction: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(pills) { pill in
                    Button {
                        onSelect(pill)
                    } label: {
                        HStack(spacing: 4) {
                            Text(pill.name)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            if pill.unreadCount > 0 {
                                let badgeFill: AnyShapeStyle = pill.isActive
                                    ? AnyShapeStyle(Color.black.opacity(0.25))
                                    : AnyShapeStyle(Color.accentColor.opacity(0.85))
                                let badgeFore: AnyShapeStyle = pill.isActive
                                    ? AnyShapeStyle(.primary)
                                    : AnyShapeStyle(Color.black)
                                Text("\(pill.unreadCount)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 4)
                                    .background(Capsule().fill(badgeFill))
                                    .foregroundStyle(badgeFore)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(pill.isActive ? Color.accentColor.opacity(0.85) : .clear)
                        )
                        .overlay(
                            Capsule().stroke(
                                pill.isActive ? .clear : Color.secondary.opacity(0.5),
                                lineWidth: 1
                            )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // watchOS: List + ScrollView(.horizontal) gesture system can swallow
                    // Button taps. A high-priority TapGesture on the button itself
                    // ensures the tap reaches the pill even when the outer gestures are
                    // competing. The Button action still fires for visual-feedback purposes.
                    .highPriorityGesture(TapGesture().onEnded { onSelect(pill) })
                    .accessibilityIdentifier("folderPill-\(pill.id)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .id("folderPillBar")
        .focusable(false)
        // Re-assert outer List crown focus whenever the user horizontally pans the pill bar.
        // A horizontal drag moves watchOS crown focus to this inner ScrollView (bypassing the
        // simultaneousGesture(DragGesture) on the List row, which the pan recognizer cancels).
        // onScrollGeometryChange observes content-offset changes directly on this ScrollView,
        // so it fires even when outer gesture recognizers are cancelled.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, _ in
            pillLogger.info("folderbar.interact reason=scroll")
            onUserInteraction()
        }
    }
}
