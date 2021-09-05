import Foundation
import UIKit

public extension Gesture {
    enum PanGestureState {
        case began
        case updated(offset: CGPoint)
        case ended
    }

    private final class PanGesture: Gesture {
        private class Impl: UIPanGestureRecognizer {
            var action: (PanGestureState) -> Void

            init(action: @escaping (PanGestureState) -> Void) {
                self.action = action

                super.init(target: nil, action: nil)
                self.addTarget(self, action: #selector(self.onAction))
            }

            @objc private func onAction() {
                switch self.state {
                case .began:
                    self.action(.began)
                case .ended, .cancelled:
                    self.action(.ended)
                case .changed:
                    let offset = self.translation(in: self.view)
                    self.action(.updated(offset: offset))
                default:
                    break
                }
            }
        }

        static let id = Id()

        private let action: (PanGestureState) -> Void

        init(action: @escaping (PanGestureState) -> Void) {
            self.action = action

            super.init(id: Self.id)
        }

        override func create() -> UIGestureRecognizer {
            return Impl(action: self.action)
        }

        override func update(gesture: UIGestureRecognizer) {
            (gesture as! Impl).action = action
        }
    }

    static func pan(_ action: @escaping (PanGestureState) -> Void) -> Gesture {
        return PanGesture(action: action)
    }
}
