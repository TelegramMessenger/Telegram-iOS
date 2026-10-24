import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

public final class ListViewTapGestureRecognizer: UITapGestureRecognizer {
    /// How far a touch may travel and still be a tap: the same 2pt `TapLongTapOrDoubleTapGestureRecognizer` allows a
    /// message bubble. A plain `UITapGestureRecognizer` tolerates more movement than a list's pan needs to begin
    /// scrolling, so a slight swipe that started on the floating date pill and stayed under that threshold used to land
    /// as a tap on it and jump the chat to that date.
    static let allowableMovement: CGFloat = 2.0

    private var touchStartLocation: CGPoint?
    /// The current touch has travelled past `allowableMovement`, so it is a swipe and never a tap.
    private(set) var touchMovedTooFar = false

    public func cancel() {
        self.state = .failed
    }

    override public func reset() {
        super.reset()

        self.touchStartLocation = nil
        self.touchMovedTooFar = false
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        if let touch = touches.first {
            self.noteTouchBegan(at: touch.location(in: self.view))
        }
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        if let touch = touches.first {
            self.noteTouchMoved(to: touch.location(in: self.view))
        }
    }

    // Touch delivery, separate from the touch handlers so tests can drive it (they cannot make a `UITouch`).
    func noteTouchBegan(at location: CGPoint) {
        if self.touchStartLocation == nil {
            self.touchStartLocation = location
        }
    }

    func noteTouchMoved(to location: CGPoint) {
        guard let touchStartLocation = self.touchStartLocation, !self.touchMovedTooFar else {
            return
        }
        let dx = location.x - touchStartLocation.x
        let dy = location.y - touchStartLocation.y
        if dx * dx + dy * dy > ListViewTapGestureRecognizer.allowableMovement * ListViewTapGestureRecognizer.allowableMovement {
            self.touchMovedTooFar = true
            if self.state == .possible {
                self.state = .failed
            }
        }
    }
}
