import Foundation
import CoreGraphics

/// Without bubbles a loading message is its author's avatar, name and a few lines of text on the text column, drawn as
/// gray bars (spec 5.7). `rect` is the bubble the loading row would have had: its height picks how many lines, its
/// width how long they run. The column starts where a message's does (past the avatar, or at the margin) and keeps 16pt
/// from the right safe inset.
public func chatLoadingBubblelessSkeletonColumn(rect: CGRect, containerWidth: CGFloat, rightInset: CGFloat, showsAvatar: Bool) -> (avatar: CGRect?, column: CGRect) {
    let columnX: CGFloat = showsAvatar ? 51.0 : 16.0
    let column = CGRect(x: rect.minX + columnX, y: rect.minY, width: max(1.0, containerWidth - rightInset - rect.minX - columnX - 16.0), height: rect.height)
    let avatar: CGRect? = showsAvatar ? CGRect(x: rect.minX + 8.0, y: rect.minY + 1.0, width: 34.0, height: 34.0) : nil
    return (avatar, column)
}

/// The bars of a loading message in its column: a name bar and two or more lines, the last one short.
public func chatLoadingBubblelessSkeletonBars(columnSize: CGSize, bubbleWidth: CGFloat) -> [CGRect] {
    let lineCount = max(2, Int((columnSize.height - 28.0) / 22.0))
    let nameWidth = max(56.0, floor(bubbleWidth * 0.35))
    let lineWidth = min(columnSize.width, floor(bubbleWidth * 1.35))
    var rects: [CGRect] = [CGRect(x: 0.0, y: 4.0, width: min(nameWidth, columnSize.width), height: 10.0)]
    for i in 0 ..< lineCount {
        let width: CGFloat
        if i == lineCount - 1 {
            width = floor(lineWidth * 0.55)
        } else if i % 2 == 1 {
            width = floor(lineWidth * 0.9)
        } else {
            width = lineWidth
        }
        rects.append(CGRect(x: 0.0, y: 24.0 + CGFloat(i) * 22.0, width: min(width, columnSize.width), height: 11.0))
    }
    return rects
}
