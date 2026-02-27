import Foundation
import UIKit
import AsyncDisplayKit

open class ListViewAccessoryItemNode: ASDisplayNode {
    var transitionOffset: CGPoint = CGPoint() {
        didSet {
            self.bounds = CGRect(origin: self.transitionOffset, size: self.bounds.size)
        }
    }
    
    private var transitionOffsetAnimation: ListViewAnimation?
    
    final func animateTransitionOffset(_ from: CGPoint, beginAt: Double, duration: Double, curve: @escaping (CGFloat) -> CGFloat) {
        self.transitionOffset = from
        self.transitionOffsetAnimation = ListViewAnimation(from: from, to: CGPoint(), duration: duration, curve: curve, beginAt: beginAt, update: { [weak self] _, currentValue in
            if let strongSelf = self {
                strongSelf.transitionOffset = currentValue
            }
        })
    }
    
    final func removeAllAnimations() {
        self.transitionOffsetAnimation = nil
        self.transitionOffset = CGPoint()
    }
    
    final func animate(_ timestamp: Double) -> Bool {
        if let animation = self.transitionOffsetAnimation {
            animation.applyAt(timestamp)
                
            if animation.completeAt(timestamp) {
                self.transitionOffsetAnimation = nil
            } else {
                return true
            }
        }
    
        return false
    }
    
    override open func layout() {
        super.layout()
        
        self.updateLayout(size: self.bounds.size, leftInset: 0.0, rightInset: 0.0)
    }
    
    open func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
    }
}
