import Foundation
import CoreGraphics

struct MediaGroupsContextMenuLayout {
    static let maxWidth: CGFloat = 220.0
    static let maxHeight: CGFloat = 295.0
    static let sideInset: CGFloat = 18.0
    static let verticalInset: CGFloat = 11.0
    static let titleSubtitleSpacing: CGFloat = 1.0
    static let listVerticalInset: CGFloat = 10.0
    static let iconSideInset: CGFloat = 20.0
    static let iconSpacing: CGFloat = 8.0
    static let iconSize = CGSize(width: 24.0, height: 24.0)
    static let highlightSideInset: CGFloat = 10.0
    static let highlightMaxCornerRadius: CGFloat = 20.0

    static func itemHeight(titleHeight: CGFloat, subtitleHeight: CGFloat) -> CGFloat {
        return verticalInset + titleHeight + titleSubtitleSpacing + subtitleHeight + verticalInset
    }

    static func contentHeight(itemCount: Int, itemHeight: CGFloat) -> CGFloat {
        if itemCount <= 0 {
            return 0.0
        }
        return listVerticalInset + CGFloat(itemCount) * itemHeight + listVerticalInset
    }

    static func itemFrame(index: Int, itemHeight: CGFloat, width: CGFloat) -> CGRect {
        return CGRect(origin: CGPoint(x: 0.0, y: listVerticalInset + CGFloat(index) * itemHeight), size: CGSize(width: width, height: itemHeight))
    }

    static func visibleIndices(minY: CGFloat, maxY: CGFloat, itemHeight: CGFloat, itemCount: Int) -> Range<Int> {
        guard itemHeight > 0.0, itemCount > 0 else {
            return 0 ..< 0
        }
        let lower = max(0, Int(floor((minY - listVerticalInset) / itemHeight)))
        let upper = min(itemCount, Int(ceil((maxY - listVerticalInset) / itemHeight)))
        if lower >= upper {
            return 0 ..< 0
        }
        return lower ..< upper
    }

    static func maxTextWidth(itemWidth: CGFloat) -> CGFloat {
        return max(1.0, itemWidth - sideInset - iconSpacing - iconSize.width - iconSideInset)
    }

    static func textFrames(itemSize: CGSize, titleSize: CGSize, subtitleSize: CGSize) -> (title: CGRect, subtitle: CGRect) {
        let contentHeight = titleSize.height + titleSubtitleSpacing + subtitleSize.height
        let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((itemSize.height - contentHeight) / 2.0)), size: titleSize)
        let subtitleFrame = CGRect(origin: CGPoint(x: sideInset, y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize)
        return (titleFrame, subtitleFrame)
    }

    static func iconFrame(itemSize: CGSize) -> CGRect {
        return CGRect(origin: CGPoint(x: itemSize.width - iconSideInset - iconSize.width, y: floor((itemSize.height - iconSize.height) / 2.0)), size: iconSize)
    }

    static func separatorFrame(itemSize: CGSize, thickness: CGFloat) -> CGRect {
        return CGRect(origin: CGPoint(x: sideInset, y: itemSize.height - thickness), size: CGSize(width: max(0.0, itemSize.width - sideInset * 2.0), height: thickness))
    }

    static func highlightFrame(itemSize: CGSize) -> CGRect {
        return CGRect(origin: CGPoint(x: highlightSideInset, y: 0.0), size: CGSize(width: max(0.0, itemSize.width - highlightSideInset * 2.0), height: itemSize.height))
    }

    static func highlightCornerRadius(highlightHeight: CGFloat) -> CGFloat {
        return min(highlightMaxCornerRadius, highlightHeight * 0.5)
    }

    static func isSeparatorHidden(index: Int, itemCount: Int, highlightedIndex: Int?) -> Bool {
        if index >= itemCount - 1 {
            return true
        }
        if let highlightedIndex, highlightedIndex == index || highlightedIndex == index + 1 {
            return true
        }
        return false
    }
}
