import Foundation
import UIKit

public extension Gesture {
    enum LongPressGestureState {
        case began
        case ended
    }

    private final class LongPressGesture: Gesture {
        private class Impl: UILongPressGestureRecognizer {
            var action: (LongPressGestureState) -> Void

            init(pressDuration: Double, action: @escaping (LongPressGestureState) -> Void) {
                self.action = action
                
                super.init(target: nil, action: nil)
                self.minimumPressDuration = pressDuration
                self.addTarget(self, action: #selector(self.onAction))
            }

            @objc private func onAction() {
                switch self.state {
                case .began:
                    self.action(.began)
                case .ended, .cancelled:
                    self.action(.ended)
                default:
                    break
                }
            }
        }

        static let id = Id()

        private let pressDuration: Double
        private let action: (LongPressGestureState) -> Void

        init(pressDuration: Double, action: @escaping (LongPressGestureState) -> Void) {
            self.pressDuration = pressDuration
            self.action = action

            super.init(id: Self.id)
        }

        override func create() -> UIGestureRecognizer {
            return Impl(pressDuration: self.pressDuration, action: self.action)
        }

        override func update(gesture: UIGestureRecognizer) {
            (gesture as! Impl).minimumPressDuration = self.pressDuration
            (gesture as! Impl).action = self.action
        }
    }

    static func longPress(duration: Double = 0.2, _ action: @escaping (LongPressGestureState) -> Void) -> Gesture {
        return LongPressGesture(pressDuration: duration, action: action)
    }
}
