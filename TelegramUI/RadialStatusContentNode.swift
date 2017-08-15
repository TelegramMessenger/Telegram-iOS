import Foundation
import Display
import AsyncDisplayKit

class RadialStatusContentNode: ASDisplayNode {
    func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        f()
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false)
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15)
    }
}
