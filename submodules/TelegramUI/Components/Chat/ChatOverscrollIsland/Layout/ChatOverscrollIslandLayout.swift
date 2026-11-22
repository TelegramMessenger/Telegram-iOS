import Foundation
import CoreGraphics

/// The bubble-free mode's "next channel" island: a glass drop that grows out of the input panel's control as a channel
/// is pulled up past its end, then stretches into an island naming the next channel.
public enum ChatOverscrollIslandMetrics {
    public static let height: CGFloat = 44.0
    public static let avatarSize: CGFloat = 32.0
    public static let avatarX: CGFloat = 6.0
    public static let leadingWithAvatar: CGFloat = 48.0
    public static let leading: CGFloat = 18.0
    public static let trailing: CGFloat = 18.0
    public static let countSpacing: CGFloat = 8.0
    /// Between the control and the island once it has let go: wider than the glass container's merge distance, so the
    /// bridge between them snaps.
    public static let detachedGap: CGFloat = 12.0
    /// The drop the pull starts from, and the one the island sinks back into.
    public static let dropDiameter: CGFloat = 14.0
    public static let sideMargin: CGFloat = 16.0
    /// The drop has swollen to the island's height by this progress; the island stretches and rises after it.
    static let dropPhaseEnd: CGFloat = 0.55
    /// How far the drop overlaps the control's top edge while the two are one shape.
    static let overlap: CGFloat = 2.0
    /// The avatar, title and count fade in from this progress to full.
    static let contentFadeStart: CGFloat = 0.8
}

private func interpolate(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
    return from + (to - from) * max(0.0, min(1.0, t))
}

public func chatOverscrollIslandMaxWidth(containerWidth: CGFloat) -> CGFloat {
    return max(120.0, containerWidth - ChatOverscrollIslandMetrics.sideMargin * 2.0)
}

/// The title's width once cut to fit, and the island's full width: leading, title, then the count 8pt after it when
/// there is one (`countWidth` 0 means none), trailing.
public func chatOverscrollIslandTextWidths(titleWidth: CGFloat, countWidth: CGFloat, hasAvatar: Bool, maxWidth: CGFloat) -> (title: CGFloat, full: CGFloat) {
    let leading = hasAvatar ? ChatOverscrollIslandMetrics.leadingWithAvatar : ChatOverscrollIslandMetrics.leading
    let countSpace = countWidth > 0.0 ? countWidth + ChatOverscrollIslandMetrics.countSpacing : 0.0
    let title = max(0.0, min(ceil(titleWidth), maxWidth - leading - ChatOverscrollIslandMetrics.trailing - countSpace))
    return (title, leading + title + countSpace + ChatOverscrollIslandMetrics.trailing)
}

/// The island's frame in the control's coordinate space. `progress` runs from 0 (a drop resting in the control's top
/// edge) to 1 (pulled far enough to switch): the drop swells to the island's height, still part of the control, then
/// stretches to `fullWidth` and rises clear of it.
public func chatOverscrollIslandFrame(progress: CGFloat, anchorFrame: CGRect, fullWidth: CGFloat) -> CGRect {
    let progress = max(0.0, min(1.0, progress))
    let dropPhase = min(1.0, progress / ChatOverscrollIslandMetrics.dropPhaseEnd)
    let stretchPhase = max(0.0, (progress - ChatOverscrollIslandMetrics.dropPhaseEnd) / (1.0 - ChatOverscrollIslandMetrics.dropPhaseEnd))
    let diameter = interpolate(ChatOverscrollIslandMetrics.dropDiameter, ChatOverscrollIslandMetrics.height, dropPhase)
    let width = interpolate(diameter, fullWidth, stretchPhase)
    let attachedCenterY = anchorFrame.minY - diameter * 0.5 + interpolate(diameter * 0.5 + ChatOverscrollIslandMetrics.overlap, ChatOverscrollIslandMetrics.overlap, dropPhase)
    let detachedCenterY = anchorFrame.minY - ChatOverscrollIslandMetrics.detachedGap - ChatOverscrollIslandMetrics.height * 0.5
    let centerY = interpolate(attachedCenterY, detachedCenterY, stretchPhase)
    return CGRect(x: floor(anchorFrame.midX - width * 0.5), y: floor(centerY - diameter * 0.5), width: width, height: diameter)
}

public func chatOverscrollIslandContentAlpha(progress: CGFloat) -> CGFloat {
    let start = ChatOverscrollIslandMetrics.contentFadeStart
    return max(0.0, min(1.0, (progress - start) / (1.0 - start)))
}

/// Where the island sinks to when it is let go: a drop just inside the control's top edge.
public func chatOverscrollIslandSinkFrame(anchorFrame: CGRect) -> CGRect {
    let diameter = ChatOverscrollIslandMetrics.dropDiameter
    return CGRect(x: anchorFrame.midX - diameter * 0.5, y: anchorFrame.minY + ChatOverscrollIslandMetrics.overlap, width: diameter, height: diameter)
}
