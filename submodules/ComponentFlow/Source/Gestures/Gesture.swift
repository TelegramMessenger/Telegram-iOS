import Foundation
import UIKit

public class Gesture {
    class Id {
        private var _id: UInt = 0
        public var id: UInt {
            return self._id
        }

        init() {
            self._id = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
        }
    }

    let id: Id

    init(id: Id) {
        self.id = id
    }

    func create() -> UIGestureRecognizer {
        preconditionFailure()
    }

    func update(gesture: UIGestureRecognizer) {
        preconditionFailure()
    }
}
