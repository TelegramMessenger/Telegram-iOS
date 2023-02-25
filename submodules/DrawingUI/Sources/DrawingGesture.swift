import Foundation
import UIKit

class DrawingGestureRecognizer: UIPanGestureRecognizer {
    var shouldBegin: (CGPoint) -> Bool = { _ in return true }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.count == 1, let touch = touches.first, self.shouldBegin(touch.location(in: self.view)) {
            super.touchesBegan(touches, with: event)
            self.state = .began
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.count > 1 {
            self.state = .cancelled
        } else {
            super.touchesMoved(touches, with: event)
        }
    }
}

struct DrawingPoint {
    let location: CGPoint
    let velocity: CGFloat
    
    var x: CGFloat {
        return self.location.x
    }
    
    var y: CGFloat {
        return self.location.y
    }
}

class DrawingGesturePipeline: NSObject, UIGestureRecognizerDelegate {
    enum DrawingGestureState {
        case began
        case changed
        case ended
        case cancelled
    }
    
    var onDrawing: (DrawingGestureState, DrawingPoint) -> Void = { _, _ in }
    
    var gestureRecognizer: DrawingGestureRecognizer?
    var transform: CGAffineTransform = .identity
        
    init(view: DrawingView) {
        super.init()
        
        let gestureRecognizer = DrawingGestureRecognizer(target: self, action: #selector(self.handleGesture(_:)))
        gestureRecognizer.delegate = self
        self.gestureRecognizer = gestureRecognizer
        view.addGestureRecognizer(gestureRecognizer)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return false
    }
    
    var previousPoint: DrawingPoint?
    @objc private func handleGesture(_ gestureRecognizer: DrawingGestureRecognizer) {
        let state: DrawingGestureState
        switch gestureRecognizer.state {
        case .began:
            state = .began
        case .changed:
            state = .changed
        case .ended:
            state = .ended
        case .cancelled:
            state = .cancelled
        case .failed:
            state = .cancelled
        case .possible:
            state = .cancelled
        @unknown default:
            state = .cancelled
        }
        
        let originalLocation = gestureRecognizer.location(in: gestureRecognizer.view)
        let location = originalLocation.applying(self.transform)
        let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view).applying(self.transform)
        let velocityValue = velocity.length
        
        let point = DrawingPoint(location: location, velocity: velocityValue)
        self.onDrawing(state, point)
    }
}
