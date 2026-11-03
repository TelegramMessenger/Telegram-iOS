import Foundation
import CoreGraphics

/// A post row measured at the list width, for the skeleton.
public struct NewsSkeletonModelRow: Equatable {
    public let height: CGFloat
    public let avatarFrame: CGRect
    public let titleFrame: CGRect
    public let textLineFrames: [CGRect]
    /// The text column's width (not the laid-out lines'): the bars are fractions of it.
    public let textWidth: CGFloat
    public let thumbnailFrame: CGRect?

    public init(height: CGFloat, avatarFrame: CGRect, titleFrame: CGRect, textLineFrames: [CGRect], textWidth: CGFloat, thumbnailFrame: CGRect?) {
        self.height = height
        self.avatarFrame = avatarFrame
        self.titleFrame = titleFrame
        self.textLineFrames = textLineFrames
        self.textWidth = textWidth
        self.thumbnailFrame = thumbnailFrame
    }
}

public enum NewsSkeletonShape: Equatable {
    case circle(CGRect)
    case roundedRect(CGRect, cornerRadius: CGFloat)
    /// A hairline, drawn outside the shimmer.
    case separator(CGRect)
}

/// The mockup's skeleton look (Feed2 Skeleton.swift:50-81).
public enum NewsSkeletonMetrics {
    public static let barHeight: CGFloat = 11.0
    public static let timeBarSize = CGSize(width: 24.0, height: 9.0)
    public static let timeBarSpacing: CGFloat = 8.0
    public static let secondLineFraction: CGFloat = 0.93
    public static let tailFractions: [CGFloat] = [0.56, 0.72, 0.44, 0.64, 0.5, 0.68, 0.38]
    public static let separatorInset: CGFloat = 16.0
}

/// The model row with a thumbnail, derived from the measured text-only one by the row's layout rules: the same
/// lines in the narrower column, the thumbnail at the top right, and at least 98 tall.
public func newsSkeletonPhotoRow(from plain: NewsSkeletonModelRow, width: CGFloat) -> NewsSkeletonModelRow {
    let metrics = NewsPostRowMetrics.self
    return NewsSkeletonModelRow(
        height: max(plain.height, metrics.minimumThumbnailRowHeight),
        avatarFrame: plain.avatarFrame,
        titleFrame: plain.titleFrame,
        textLineFrames: plain.textLineFrames,
        textWidth: newsPostTextWidth(width: width, hasThumbnail: true),
        thumbnailFrame: CGRect(x: width - metrics.sideInset - metrics.thumbnailSize, y: metrics.topInset, width: metrics.thumbnailSize, height: metrics.thumbnailSize)
    )
}

/// Rows 1, 2, 4, 5, … show a thumbnail (`index % 3 != 0`).
public func newsSkeletonRowHasThumbnail(index: Int) -> Bool {
    return index % 3 != 0
}

/// One skeleton row whose top is at `y`. The text bars are 100 %, 93 % and a per-row tail of the column width.
public func newsSkeletonRowShapes(row: NewsSkeletonModelRow, index: Int, y: CGFloat, width: CGFloat, pixel: CGFloat) -> [NewsSkeletonShape] {
    let metrics = NewsSkeletonMetrics.self
    let barRadius = metrics.barHeight * 0.5
    var shapes: [NewsSkeletonShape] = [.circle(row.avatarFrame.offsetBy(dx: 0.0, dy: y))]

    let nameMidY = y + row.titleFrame.midY
    let name = CGRect(x: row.titleFrame.minX, y: nameMidY - barRadius, width: row.titleFrame.width, height: metrics.barHeight)
    shapes.append(.roundedRect(name, cornerRadius: barRadius))
    let time = CGRect(x: name.maxX + metrics.timeBarSpacing, y: nameMidY - metrics.timeBarSize.height * 0.5, width: metrics.timeBarSize.width, height: metrics.timeBarSize.height)
    shapes.append(.roundedRect(time, cornerRadius: metrics.timeBarSize.height * 0.5))

    let lines = row.textLineFrames
    for (lineIndex, line) in lines.enumerated() {
        let fraction: CGFloat
        if lineIndex == lines.count - 1 && lines.count > 1 {
            fraction = metrics.tailFractions[index % metrics.tailFractions.count]
        } else if lineIndex == 0 {
            fraction = 1.0
        } else {
            fraction = metrics.secondLineFraction
        }
        let bar = CGRect(x: line.minX, y: y + line.midY - barRadius, width: floor(row.textWidth * fraction), height: metrics.barHeight)
        shapes.append(.roundedRect(bar, cornerRadius: barRadius))
    }

    if let thumbnail = row.thumbnailFrame {
        shapes.append(.roundedRect(thumbnail.offsetBy(dx: 0.0, dy: y), cornerRadius: NewsPostRowMetrics.thumbnailCornerRadius))
    }
    shapes.append(.separator(CGRect(x: metrics.separatorInset, y: y + row.height - pixel, width: width - metrics.separatorInset, height: pixel)))
    return shapes
}

/// Skeleton rows from the top down to `height`, alternating the text-only and photo models.
public func newsSkeletonShapes(plain: NewsSkeletonModelRow, width: CGFloat, height: CGFloat, pixel: CGFloat) -> [NewsSkeletonShape] {
    guard plain.height > 0.0 else {
        return []
    }
    let photo = newsSkeletonPhotoRow(from: plain, width: width)
    var shapes: [NewsSkeletonShape] = []
    var y: CGFloat = 0.0
    var index = 0
    while y < height {
        let row = newsSkeletonRowHasThumbnail(index: index) ? photo : plain
        shapes.append(contentsOf: newsSkeletonRowShapes(row: row, index: index, y: y, width: width, pixel: pixel))
        y += row.height
        index += 1
    }
    return shapes
}
