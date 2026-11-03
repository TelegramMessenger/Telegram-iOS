import Foundation
import CoreGraphics

/// The page a released swipe between the News tabs settles on. `translation` and `velocity` are horizontal,
/// positive to the right, towards the previous page. A flick goes its own way; a slow release goes on once it
/// is past half the width.
public func newsPagerSettledIndex(currentIndex: Int, pageCount: Int, translation: CGFloat, velocity: CGFloat, width: CGFloat) -> Int {
    var step = 0
    if abs(velocity) > 10.0 {
        step = velocity < 0.0 ? 1 : -1
    } else if abs(translation) > width * 0.5 {
        step = translation < 0.0 ? 1 : -1
    }
    return max(0, min(pageCount - 1, currentIndex + step))
}

/// The header's scroll offset while swiping from one list to the other. Each list's offset is limited to the
/// range over which the header folds (0...`foldHeight`; a list whose top is not loaded counts as folded), and the
/// two are blended by the swipe's progress: 0 on the current list, 1 on the next.
public func newsPagerHeaderOffset(current: CGFloat?, next: CGFloat?, progress: CGFloat, foldHeight: CGFloat) -> CGFloat {
    func fold(_ offset: CGFloat?) -> CGFloat {
        guard let offset else {
            return foldHeight
        }
        return max(0.0, min(foldHeight, offset))
    }
    let progress = max(0.0, min(1.0, progress))
    return fold(current) * (1.0 - progress) + fold(next) * progress
}
