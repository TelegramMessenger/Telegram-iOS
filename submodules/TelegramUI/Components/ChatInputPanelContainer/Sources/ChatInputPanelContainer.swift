import Foundation
import UIKit
import Display
import AsyncDisplayKit
import PagerComponent

private func traceScrollView(view: UIView, point: CGPoint) -> (UIScrollView?, Bool) {
    for subview in view.subviews.reversed() {
        let subviewPoint = view.convert(point, to: subview)
        if subview.frame.contains(point) || subview is PagerExternalTopPanelContainer {
            let (result, shouldContinue) = traceScrollView(view: subview, point: subviewPoint)
            if let result = result {
                return (result, false)
            } else if subview.backgroundColor != nil {
                return (nil, false)
            } else if !shouldContinue {
                return (nil, false)
            }
        }
    }
    if let scrollView = view as? UIScrollView {
        return (scrollView, false)
    }
    return (nil, true)
}

private func traceScrollViewUp(view: UIView) -> UIScrollView? {
    if let scrollView = view as? UIScrollView {
        return scrollView
    } else if let superview = view.superview {
        return traceScrollViewUp(view: superview)
    } else {
        return nil
    }
}

private final class ExpansionPanRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    enum LockDirection {
        case up
        case down
        case any
    }
    
    var requiredLockDirection: LockDirection = .up
    
    private var beginPosition = CGPoint()
    private var currentTranslation = CGPoint()
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    override public func reset() {
        super.reset()
        
        self.state = .possible
        self.currentTranslation = CGPoint()
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer.view as? PagerExpandableScrollView {
            return true
        }
        
        if let _ = gestureRecognizer as? PagerPanGestureRecognizer {
            return true
        }
        
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer.view as? PagerExpandableScrollView {
            return true
        }
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, let view = self.view else {
            self.state = .failed
            return
        }
        
        var found = false
        let point = touch.location(in: self.view)
        
        let hitView = view.hitTest(point, with: event)
        
        if let _ = hitView as? UIButton {
        } else if let hitView = hitView, hitView.asyncdisplaykit_node is ASButtonNode {
        } else {
            if let scrollView = traceScrollView(view: view, point: point).0 ?? hitView.flatMap(traceScrollViewUp) {
                if scrollView is ListViewScroller || scrollView is GridNodeScrollerView || scrollView.asyncdisplaykit_node is ASScrollNode {
                    found = false
                } else if let textView = scrollView as? UITextView {
                    if textView.contentSize.height <= textView.bounds.height {
                        found = true
                    } else {
                        found = false
                    }
                } else {
                    found = true
                }
            } else {
                found = true
            }
        }
        
        if found {
            self.beginPosition = point
        } else {
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first, let view = self.view else {
            self.state = .failed
            return
        }
        
        let point = touch.location(in: self.view)
        
        let translation = CGPoint(x: point.x - self.beginPosition.x, y: point.y - self.beginPosition.y)
        self.currentTranslation = translation
        
        if self.state == .possible {
            if abs(translation.x) > 8.0 {
                self.state = .failed
                return
            }
            var lockDirection: LockDirection?
            let point = touch.location(in: self.view)
            let tracedView = view.hitTest(point, with: event)
            if let scrollView = traceScrollView(view: view, point: point).0 {
                if !(scrollView is PagerExpandableScrollView) {
                    lockDirection = .any
                } else {
                    let contentOffset = scrollView.contentOffset
                    let contentInset = scrollView.contentInset
                    if contentOffset.y <= contentInset.top {
                        lockDirection = .down
                    }
                }
            } else {
                lockDirection = .any
            }
            if let lockDirection = lockDirection {
                if abs(translation.y) > 2.0 {
                    switch lockDirection {
                    case .up:
                        if translation.y < 0.0 {
                            if let tracedView = tracedView {
                                cancelParentGestures(view: tracedView, ignore: [self])
                            }
                            self.state = .began
                        } else {
                            self.state = .failed
                        }
                    case .down:
                        if translation.y > 0.0 {
                            if let tracedView = tracedView {
                                cancelParentGestures(view: tracedView, ignore: [self])
                            }
                            self.state = .began
                        } else {
                            self.state = .failed
                        }
                    case .any:
                        if let tracedView = tracedView {
                            cancelParentGestures(view: tracedView, ignore: [self])
                        }
                        self.state = .began
                    }
                }
            } else {
                self.state = .failed
            }
        } else {
            self.state = .changed
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .ended
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    func translation() -> CGPoint {
        return self.currentTranslation
    }
    
    func velocity() -> CGPoint {
        return CGPoint()
    }
}

public final class ChatInputPanelContainer: SparseNode {
    public var expansionUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    private var expansionRecognizer: ExpansionPanRecognizer?
    
    private var scrollableDistance: CGFloat?
    public private(set) var initialExpansionFraction: CGFloat = 0.0
    public private(set) var expansionFraction: CGFloat = 0.0
    public private(set) var stableIsExpanded: Bool = false
    
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
            
            let delta = -recognizer.translation().y / scrollableDistance
            
            self.expansionFraction = max(0.0, min(1.0, self.initialExpansionFraction + delta))
            self.expansionUpdated?(.immediate)
        case .ended, .cancelled:
            guard let _ = self.scrollableDistance else {
                return
            }
            
            let velocity = recognizer.velocity()
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
            
            self.stableIsExpanded = self.expansionFraction == 1.0
            
            if let expansionRecognizer = self.expansionRecognizer {
                expansionRecognizer.requiredLockDirection = self.expansionFraction == 0.0 ? .up : .down
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
    
    public func expand() {
        self.expansionFraction = 1.0
        self.expansionRecognizer?.requiredLockDirection = self.expansionFraction == 0.0 ? .up : .down
        self.stableIsExpanded = self.expansionFraction == 1.0
    }
    
    public func collapse() {
        self.expansionFraction = 0.0
        self.expansionRecognizer?.requiredLockDirection = self.expansionFraction == 0.0 ? .up : .down
        self.stableIsExpanded = self.expansionFraction == 1.0
    }
    
    public func toggleIfEnabled() {
        if let expansionRecognizer = self.expansionRecognizer, expansionRecognizer.isEnabled {
            if self.expansionFraction == 0.0 {
                self.expansionFraction = 1.0
            } else {
                self.expansionFraction = 0.0
            }
            self.stableIsExpanded = self.expansionFraction == 1.0
            self.expansionUpdated?(.animated(duration: 0.4, curve: .spring))
        }
    }
}
