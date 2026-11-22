import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

final class MediaGridSelectionGesture: UIPanGestureRecognizer {
    var itemAt: (CGPoint) -> (Int, Bool)? = { _ in return nil }
    var updateSelection: (Int, Bool) -> Void = { _, _ in }
    var updateIsScrollEnabled: (Bool) -> Void = { _ in }
    var sideInset: CGFloat = 0.0

    private var processing = false

    var isProcessing: Bool {
        return self.processing
    }
    private var selecting = false
    private var initialLocation: CGPoint?

    init() {
        super.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard let touch = touches.first, self.numberOfTouches == 1 else {
            if !self.processing {
                self.state = .failed
            }
            return
        }

        let location = touch.location(in: self.view)
        if location.x > self.sideInset {
            self.initialLocation = location
        } else {
            self.state = .failed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard let touch = touches.first, let initialLocation = self.initialLocation else {
            self.state = .failed
            return
        }

        let location = touch.location(in: self.view)
        let translation = CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y)

        var additionalLocation: CGPoint?
        if !self.processing {
            if abs(translation.y) > 5.0 {
                self.state = .failed
            } else if abs(translation.x) > 8.0 {
                self.processing = true
                self.updateIsScrollEnabled(false)

                if let (_, selected) = self.itemAt(location) {
                    self.selecting = !selected
                }

                additionalLocation = self.initialLocation
            }
        }

        if self.processing {
            if let additionalLocation {
                if let (item, selected) = self.itemAt(additionalLocation), selected != self.selecting {
                    self.updateSelection(item, self.selecting)
                }
            }

            if let (item, selected) = self.itemAt(location), selected != self.selecting {
                self.updateSelection(item, self.selecting)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        self.state = .failed
        self.reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)

        self.state = .failed
        self.reset()
    }

    override func reset() {
        super.reset()

        self.processing = false
        self.initialLocation = nil
        self.updateIsScrollEnabled(true)
    }
}
