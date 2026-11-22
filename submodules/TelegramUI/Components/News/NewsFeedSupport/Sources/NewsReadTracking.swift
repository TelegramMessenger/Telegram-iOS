import Foundation
import CoreGraphics
import TelegramCore

public struct NewsVisibleRow: Equatable {
    public let position: EngineFeedPosition
    public let frame: CGRect

    public init(position: EngineFeedPosition, frame: CGRect) {
        self.position = position
        self.frame = frame
    }
}

/// The newest post whose row lies entirely inside `viewport` (0.5 pt tolerance), or nil.
public func newsNewestFullyVisiblePosition(rows: [NewsVisibleRow], viewport: CGRect) -> EngineFeedPosition? {
    let bounds = viewport.insetBy(dx: -0.5, dy: -0.5)
    var result: EngineFeedPosition?
    for row in rows where bounds.contains(row.frame) {
        if let current = result, row.position <= current {
            continue
        }
        result = row.position
    }
    return result
}
