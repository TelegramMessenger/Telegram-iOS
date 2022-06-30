import Foundation
import UIKit
import Display
import AsyncDisplayKit

private final class ExpansionPanRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    private var targetScrollView: UIScrollView?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    override func reset() {
        self.targetScrollView = nil
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        /*if let scrollView = otherGestureRecognizer.view as? UIScrollView {
            if scrollView.bounds.height > 200.0 {
                self.targetScrollView = scrollView
                scrollView.contentOffset = CGPoint()
            }
        }*/
        
        return false
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let targetScrollView = self.targetScrollView {
            targetScrollView.contentOffset = CGPoint()
        }
    }
}

public final class ChatInputPanelContainer: SparseNode, UIScrollViewDelegate {
    public var expansionUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    private var expansionRecognizer: ExpansionPanRecognizer?
    
    private var scrollableDistance: CGFloat?
    public private(set) var initialExpansionFraction: CGFloat = 0.0
    public private(set) var expansionFraction: CGFloat = 0.0
    
    override public init() {
        super.init()
        
        let expansionRecognizer = ExpansionPanRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.expansionRecognizer = expansionRecognizer
        self.view.addGestureRecognizer(expansionRecognizer)
        expansionRecognizer.isEnabled = false
    }
    
    @objc private func panGesture(_ recognizer: ExpansionPanRecognizer) {
        switch recognizer.state {
        case .began:
            guard let _ = self.scrollableDistance else {
                return
            }
            self.initialExpansionFraction = self.expansionFraction
        case .changed:
            guard let scrollableDistance = self.scrollableDistance else {
                return
            }
            
            let delta = -recognizer.translation(in: self.view).y / scrollableDistance
            
            self.expansionFraction = max(0.0, min(1.0, self.initialExpansionFraction + delta))
            self.expansionUpdated?(.immediate)
        case .ended, .cancelled:
            guard let _ = self.scrollableDistance else {
                return
            }
            
            let velocity = recognizer.velocity(in: self.view)
            if abs(self.initialExpansionFraction - self.expansionFraction) > 0.25 {
                if self.initialExpansionFraction < 0.5 {
                    self.expansionFraction = 1.0
                } else {
                    self.expansionFraction = 0.0
                }
            } else if abs(velocity.y) > 100.0 {
                if velocity.y < 0.0 {
                    self.expansionFraction = 1.0
                } else {
                    self.expansionFraction = 0.0
                }
            } else {
                if self.initialExpansionFraction < 0.5 {
                    self.expansionFraction = 0.0
                } else {
                    self.expansionFraction = 1.0
                }
            }
            self.expansionUpdated?(.animated(duration: 0.4, curve: .spring))
        default:
            break
        }
    }
    
    public func update(size: CGSize, scrollableDistance: CGFloat, isExpansionEnabled: Bool, transition: ContainedViewLayoutTransition) {
        self.expansionRecognizer?.isEnabled = isExpansionEnabled
        
        self.scrollableDistance = scrollableDistance
    }
    
    public func collapse() {
        self.expansionFraction = 0.0
    }
}
