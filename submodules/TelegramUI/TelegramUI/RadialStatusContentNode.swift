import Foundation
import UIKit
import Display
import AsyncDisplayKit

class RadialStatusContentNode: ASDisplayNode {
    func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        f()
    }
    
    private let duration: Double = 0.2
    
    func prepareAnimateOut(completion: @escaping (Double) -> Void) {
        completion(0.0)
    }
    
    func animateOut(to: RadialStatusNodeState, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.layer.animateScale(from: 1.0, to: 0.2, duration: duration, removeOnCompletion: false)
    }
    
    func prepareAnimateIn(from: RadialStatusNodeState?) {
    }
    
    func animateIn(from: RadialStatusNodeState, delay: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, delay: delay)
        self.layer.animateScale(from: 0.2, to: 1.0, duration: duration, delay: delay)
    }
}
