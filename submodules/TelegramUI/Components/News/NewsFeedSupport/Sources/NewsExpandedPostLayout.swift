import Foundation
import CoreGraphics

/// An expanded post row's measures (the "-1T Valuation" mockup, Channels frame): a 36 pt avatar at the left, the
/// channel line, the message bubble's content and the media in a horizontal gallery.
public enum NewsExpandedPostMetrics {
    public static let avatarInset: CGFloat = 8.0
    public static let avatarSize: CGFloat = 36.0
    public static let avatarTop: CGFloat = 5.0
    /// Between the avatar and the content: the bubble's tail on the mockup.
    public static let avatarContentSpacing: CGFloat = 10.0
    public static let rightInset: CGFloat = 16.0
    public static let headerTop: CGFloat = 6.0
    public static let headerHeight: CGFloat = 18.0
    public static let headerSpacing: CGFloat = 4.0
    /// The text starts under the channel line.
    public static var textTop: CGFloat {
        return headerTop + headerHeight + 3.0
    }
    public static let galleryHeight: CGFloat = 270.0
    public static let galleryItemSpacing: CGFloat = 4.0
    public static let galleryCornerRadius: CGFloat = 8.0
    public static let galleryMinimumItemWidth: CGFloat = 120.0
    public static let galleryTopSpacing: CGFloat = 6.0
    public static let showMoreTopSpacing: CGFloat = 2.0
    public static let bottomInset: CGFloat = 8.0
    /// A post longer than this shows "Show more" instead of the rest (spec).
    public static let collapsedLineLimit = 10

    /// The chat bubble's own geometry (`ChatMessageItemLayoutConstants`), which the row places the bubble by: an
    /// incoming bubble's text starts 20 pt into its item (3 edge inset, 6 content inset, 11 text inset), 6 pt
    /// under the bubble's top, and the item wants its text width plus 73 pt of width (36 fill inset, 9 of edge
    /// insets, 6 content inset, 22 text insets).
    public static let bubbleTextLeadingInset: CGFloat = 20.0
    public static let bubbleTextTopInset: CGFloat = 6.0
    public static let bubbleWidthOverhead: CGFloat = 73.0

    /// Where the content column starts: after the avatar and the gap.
    public static func contentX(leftInset: CGFloat) -> CGFloat {
        return leftInset + avatarInset + avatarSize + avatarContentSpacing
    }

    public static func contentWidth(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat) -> CGFloat {
        return max(1.0, width - contentX(leftInset: leftInset) - rightInset - NewsExpandedPostMetrics.rightInset)
    }
}

/// The gallery's items, side by side from x 0 in the scroll view's content, and the content's size.
public struct NewsExpandedGalleryLayout {
    public let items: [CGRect]
    public let contentSize: CGSize
}

/// One media's frame in the gallery, from its dimensions. A single photo keeps its aspect within the column: as tall
/// as the gallery allows, or as wide as the column when it is wider than that. Several photos share the gallery's
/// height, each as wide as its aspect makes it, never narrower than the minimum or wider than the column, so a
/// carousel of portraits reads as on the mockup (190 × 270 side by side).
public func newsExpandedGalleryLayout(dimensions: [CGSize], columnWidth: CGFloat) -> NewsExpandedGalleryLayout {
    let metrics = NewsExpandedPostMetrics.self
    let columnWidth = max(1.0, columnWidth)
    guard !dimensions.isEmpty else {
        return NewsExpandedGalleryLayout(items: [], contentSize: CGSize())
    }
    func aspect(_ size: CGSize) -> CGFloat {
        guard size.width > 0.0, size.height > 0.0 else {
            return 1.0
        }
        return size.width / size.height
    }
    if dimensions.count == 1 {
        let ratio = aspect(dimensions[0])
        var width = min(columnWidth, floor(metrics.galleryHeight * ratio))
        width = max(width, min(columnWidth, metrics.galleryMinimumItemWidth))
        let height = min(metrics.galleryHeight, floor(width / ratio))
        let frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        return NewsExpandedGalleryLayout(items: [frame], contentSize: frame.size)
    }
    var items: [CGRect] = []
    var x: CGFloat = 0.0
    for size in dimensions {
        let width = min(columnWidth, max(metrics.galleryMinimumItemWidth, floor(metrics.galleryHeight * aspect(size))))
        items.append(CGRect(x: x, y: 0.0, width: width, height: metrics.galleryHeight))
        x += width + metrics.galleryItemSpacing
    }
    return NewsExpandedGalleryLayout(items: items, contentSize: CGSize(width: x - metrics.galleryItemSpacing, height: metrics.galleryHeight))
}

/// How far the avatar moves left while the gallery is scrolled. The gallery's content passes under the avatar's
/// column once scrolled; where the two meet vertically the avatar goes along with the content (as a leading item of
/// the carousel would), so it never lies over a photo. Where they do not meet it stays. `scrolled` is how far the
/// gallery's content has moved from its resting position (0 at rest, positive scrolled left).
public func newsExpandedAvatarOffset(galleryScrolled scrolled: CGFloat, galleryFrame: CGRect, avatarFrame: CGRect) -> CGFloat {
    guard scrolled > 0.0, galleryFrame.minY < avatarFrame.maxY, galleryFrame.maxY > avatarFrame.minY else {
        return 0.0
    }
    return -min(scrolled, avatarFrame.maxX + NewsExpandedPostMetrics.avatarContentSpacing)
}

/// The text kept while a post is collapsed: its first `lineLimit` lines, when it has more. `lineRanges` are the
/// laid-out lines' character ranges, in order. nil when the whole text fits.
public func newsCollapsedTextRange(lineRanges: [NSRange], lineLimit: Int = NewsExpandedPostMetrics.collapsedLineLimit) -> NSRange? {
    guard lineRanges.count > lineLimit, lineLimit > 0 else {
        return nil
    }
    let last = lineRanges[lineLimit - 1]
    return NSRange(location: 0, length: last.location + last.length)
}
