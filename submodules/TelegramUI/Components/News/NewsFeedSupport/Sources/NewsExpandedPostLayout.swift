import Foundation
import CoreGraphics

/// An expanded post row's measures: a 36 pt avatar at the left, the channel line, the message bubble's content and
/// the media in a horizontal gallery.
public enum NewsExpandedPostMetrics {
    public static let avatarInset: CGFloat = 8.0
    public static let avatarSize: CGFloat = 36.0
    public static let avatarTop: CGFloat = 5.0
    /// Between the avatar and the content, where a chat bubble's tail would be.
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
    /// "▶ 0:12" on a gallery video sits this far in from its bottom-left corner.
    public static let galleryLabelInset: CGFloat = 8.0
    public static let galleryMinimumItemWidth: CGFloat = 120.0
    public static let galleryTopSpacing: CGFloat = 6.0
    public static let showMoreTopSpacing: CGFloat = 2.0
    public static let bottomInset: CGFloat = 8.0
    /// A post longer than this many lines shows "Show more" instead of the rest.
    public static let collapsedLineLimit = 10

    /// The chat bubble's own geometry (`ChatMessageItemLayoutConstants`, `ChatMessageBubbleItemNode`), which the row
    /// places the bubble by: an incoming bubble's text starts 20 pt into its item (3 edge inset, 6 content inset,
    /// 11 text inset), 6 pt under the bubble's top, and the item wants its text width plus 40 pt of width. A
    /// channel post's bubble is allowed the full width (`allowFullWidth`, so no 36 pt fill inset applies): the
    /// item takes 3 off for the absent share button, 9 of edge insets, 6 content inset and 22 text insets.
    public static let bubbleTextLeadingInset: CGFloat = 20.0
    public static let bubbleTextTopInset: CGFloat = 6.0
    public static let bubbleWidthOverhead: CGFloat = 40.0

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
/// carousel of portraits shows them side by side (190 × 270 each).
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
private func newsCollapsedTextRange(lineRanges: [NSRange], lineLimit: Int) -> NSRange? {
    guard lineRanges.count > lineLimit, lineLimit > 0 else {
        return nil
    }
    let last = lineRanges[lineLimit - 1]
    return NSRange(location: 0, length: last.location + last.length)
}

/// The length (UTF-16) of the text a collapsed post keeps: its first `lineLimit` lines without the spaces and line
/// breaks that end them; nil when the whole text fits, or when those lines hold nothing but breaks. Never trimmed at
/// the start: the entities' offsets index the whole text, and the kept text must lay out as the start of the whole
/// text does.
public func newsCollapsedTextLength(text: NSString, lineRanges: [NSRange], lineLimit: Int) -> Int? {
    guard let range = newsCollapsedTextRange(lineRanges: lineRanges, lineLimit: lineLimit) else {
        return nil
    }
    var end = min(range.location + range.length, text.length)
    while end > 0, let scalar = Unicode.Scalar(text.character(at: end - 1)), CharacterSet.whitespacesAndNewlines.contains(scalar) {
        end -= 1
    }
    return end > 0 ? end : nil
}

/// "▶ 0:12" on a picture, `inset` in from its bottom-left corner: the compact thumbnail's, the gallery's, and the one a
/// mode morph carries between them on the travelling picture's corner.
public func newsVideoLabelFrame(pictureFrame: CGRect, labelSize: CGSize, inset: CGFloat) -> CGRect {
    return CGRect(origin: CGPoint(x: pictureFrame.minX + inset, y: pictureFrame.maxY - inset - labelSize.height), size: labelSize)
}

/// The widest picture the compact thumbnail draws whole. A wider panorama keeps the square drawing (its whole width
/// would cost up to its aspect times the square's bitmap), and its mode morph fades instead of travelling.
private let newsThumbnailMaximumWholeAspect: CGFloat = 4.0

/// The size the compact thumbnail draws its picture at: the whole picture, covering the square. What lies beyond the
/// square is an even number of points, so the layer's centred crop (`resizeAspectFill`) falls on whole pixels at every
/// scale and the thumbnail at rest is as sharp as a square drawing. A mode morph animates the thumbnail's frame into
/// the gallery's first photo; drawn whole, every frame on the way shows the photo's own crop at that aspect, not a
/// square zoomed to fill it. A picture taller than any gallery item shows is cut to the narrowest one
/// (`galleryMinimumItemWidth` at `galleryHeight`), which bounds a long screenshot. nil for a panorama or a picture
/// without dimensions: the square is drawn.
public func newsThumbnailDrawingSize(dimensions: CGSize, square: CGSize) -> CGSize? {
    guard dimensions.width > 0.0, dimensions.height > 0.0, square.width > 0.0, square.height > 0.0 else {
        return nil
    }
    let metrics = NewsExpandedPostMetrics.self
    let aspect = max(dimensions.width / dimensions.height, metrics.galleryMinimumItemWidth / metrics.galleryHeight)
    guard aspect <= newsThumbnailMaximumWholeAspect else {
        return nil
    }
    func covering(_ side: CGFloat, _ exact: CGFloat) -> CGFloat {
        return side + 2.0 * ceil(max(0.0, exact - side) / 2.0)
    }
    if aspect >= square.width / square.height {
        return CGSize(width: covering(square.width, square.height * aspect), height: square.height)
    } else {
        return CGSize(width: square.width, height: covering(square.height, square.width / aspect))
    }
}
