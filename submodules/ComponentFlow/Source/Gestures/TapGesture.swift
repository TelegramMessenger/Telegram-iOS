import Foundation
import UIKit

public extension Gesture {
    private final class TapGesture: Gesture {
        private class Impl: UITapGestureRecognizer {
            var action: () -> Void

            init(action: @escaping () -> Void) {
                self.action = action

                super.init(target: nil, action: nil)
                self.addTarget(self, action: #selector(self.onAction))
            }

            @objc private func onAction() {
                self.action()
            }
        }

        static let id = Id()

        private let action: () -> Void

        init(action: @escaping () -> Void) {
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

    static func tap(_ action: @escaping () -> Void) -> Gesture {
        return TapGesture(action: action)
    }
}
