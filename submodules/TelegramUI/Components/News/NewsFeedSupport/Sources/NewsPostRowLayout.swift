import Foundation
import CoreGraphics

/// A post row's measures (Feed2 FeedRow.swift:379-460, Appearance.swift:41-101). Fonts and line spacing are the
/// app's own; only the geometry follows the mockup.
public enum NewsPostRowMetrics {
    public static let sideInset: CGFloat = 16.0
    public static let topInset: CGFloat = 8.0
    public static let headerHeight: CGFloat = 22.0
    public static let headerSpacing: CGFloat = 4.0
    public static let avatarSize: CGFloat = 16.0
    public static let bottomInset: CGFloat = 8.0
    public static let thumbnailSize: CGFloat = 82.0
    public static let thumbnailSpacing: CGFloat = 16.0
    public static let thumbnailCornerRadius: CGFloat = 10.0
    /// The text starts under the header line.
    public static var textTop: CGFloat {
        return topInset + headerHeight
    }
    /// A row with a thumbnail is never shorter than the thumbnail with its padding.
    public static var minimumThumbnailRowHeight: CGFloat {
        return topInset + thumbnailSize + bottomInset
    }
}

/// The width of the text column, and of the header line: the row less its side insets and, with a thumbnail, the
/// thumbnail and the 16 pt before it.
public func newsPostTextWidth(width: CGFloat, hasThumbnail: Bool) -> CGFloat {
    let metrics = NewsPostRowMetrics.self
    return max(1.0, width - metrics.sideInset * 2.0 - (hasThumbnail ? metrics.thumbnailSize + metrics.thumbnailSpacing : 0.0))
}

/// How wide the channel name may be: the header line less the avatar, the badge and the time, 4 pt apart.
public func newsPostTitleMaxWidth(textWidth: CGFloat, credibilityWidth: CGFloat, timeWidth: CGFloat) -> CGFloat {
    let spacing = NewsPostRowMetrics.headerSpacing
    var result = textWidth - NewsPostRowMetrics.avatarSize - spacing - spacing - timeWidth
    if credibilityWidth > 0.0 {
        result -= credibilityWidth + spacing
    }
    return max(1.0, result)
}

public struct NewsPostRowLayout: Equatable {
    public let avatar: CGRect
    public let title: CGRect
    public let credibility: CGRect?
    public let time: CGRect
    public let text: CGRect
    public let thumbnail: CGRect?
    public let separator: CGRect
    public let height: CGFloat
}

/// Every frame of a post row from its measured parts. The avatar, name, badge and time are centred in a 22 pt
/// header line 8 pt from the top; the text starts at 30; the thumbnail is 82 pt at top 8, right 16.
public func newsPostRowLayout(width: CGFloat, titleSize: CGSize, credibilitySize: CGSize?, timeSize: CGSize, textSize: CGSize, hasThumbnail: Bool, screenScale: CGFloat) -> NewsPostRowLayout {
    let metrics = NewsPostRowMetrics.self
    let lineMidY = metrics.topInset + metrics.headerHeight * 0.5
    func centred(x: CGFloat, size: CGSize) -> CGRect {
        return CGRect(origin: CGPoint(x: x, y: floor((lineMidY - size.height * 0.5) * screenScale) / screenScale), size: size)
    }

    let avatar = centred(x: metrics.sideInset, size: CGSize(width: metrics.avatarSize, height: metrics.avatarSize))
    let title = centred(x: avatar.maxX + metrics.headerSpacing, size: titleSize)
    var nextX = title.maxX + metrics.headerSpacing
    var credibility: CGRect?
    if let credibilitySize, credibilitySize.width > 0.0 {
        let frame = centred(x: nextX, size: credibilitySize)
        credibility = frame
        nextX = frame.maxX + metrics.headerSpacing
    }
    let time = centred(x: nextX, size: timeSize)

    let text = CGRect(origin: CGPoint(x: metrics.sideInset, y: metrics.textTop), size: textSize)
    var height = text.maxY + metrics.bottomInset
    var thumbnail: CGRect?
    if hasThumbnail {
        thumbnail = CGRect(x: width - metrics.sideInset - metrics.thumbnailSize, y: metrics.topInset, width: metrics.thumbnailSize, height: metrics.thumbnailSize)
        height = max(height, metrics.minimumThumbnailRowHeight)
    }

    let pixel = 1.0 / screenScale
    let separator = CGRect(x: metrics.sideInset, y: height - pixel, width: width - metrics.sideInset * 2.0, height: pixel)
    return NewsPostRowLayout(avatar: avatar, title: title, credibility: credibility, time: time, text: text, thumbnail: thumbnail, separator: separator, height: height)
}
