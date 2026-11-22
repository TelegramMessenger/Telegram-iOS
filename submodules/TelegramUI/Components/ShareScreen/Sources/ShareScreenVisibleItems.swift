import Foundation

// The bounds come from the sheet's scroll view (or the recommendations strip).
// Calculate indices directly instead of walking every item on each scroll tick.
func shareScreenVisibleItems(min: CGFloat, max: CGFloat, origin: CGFloat, stride: CGFloat, count: Int, columns: Int = 1) -> Range<Int> {
    guard count > 0, stride > 0, columns > 0, max > min else { return 0 ..< 0 }
    let rowCount = (count + columns - 1) / columns
    let firstRow = Swift.max(0, Swift.min(rowCount, Int(floor((min - origin) / stride))))
    let lastRow = Swift.max(firstRow, Swift.min(rowCount, Int(ceil((max - origin) / stride))))
    return Swift.min(count, firstRow * columns) ..< Swift.min(count, lastRow * columns)
}

func shareScreenActivityCenterY(contentBottom: CGFloat, visibleBounds: CGRect, bottomInset: CGFloat) -> CGFloat {
    let top = Swift.max(contentBottom, visibleBounds.minY)
    let bottom = visibleBounds.maxY - bottomInset
    return Swift.max(contentBottom + 30.0, floor((top + bottom) * 0.5))
}
