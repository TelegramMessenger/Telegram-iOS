import Foundation
import UIKit
import ObjectiveC

private var rasterizedAnimationCountKey: UInt8 = 0

public extension CALayer {
    func beginRasterizedAnimation() -> (Bool) -> Void {
        let count = (objc_getAssociatedObject(self, &rasterizedAnimationCountKey) as? NSNumber)?.intValue ?? 0
        objc_setAssociatedObject(self, &rasterizedAnimationCountKey, NSNumber(value: count + 1), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        self.rasterizationScale = UIScreenScale
        self.shouldRasterize = true
        var ended = false
        return { [weak self] _ in
            guard let self, !ended else { return }
            ended = true
            let count = max(0, ((objc_getAssociatedObject(self, &rasterizedAnimationCountKey) as? NSNumber)?.intValue ?? 1) - 1)
            objc_setAssociatedObject(self, &rasterizedAnimationCountKey, NSNumber(value: count), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if count == 0 {
                self.shouldRasterize = false
            }
        }
    }
}
