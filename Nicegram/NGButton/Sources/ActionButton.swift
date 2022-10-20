import UIKit

public class ActionButton: UIButton {
    public var touchUpInside: (() -> Void)? {
        didSet {
            if touchUpInside != nil {
                addTarget(self, action: #selector(onTouchUpInside), for: .touchUpInside)
            } else {
                removeTarget(self, action: #selector(onTouchUpInside), for: .touchUpInside)
            }
        }
    }
}

private extension ActionButton {
    @objc func onTouchUpInside() {
        touchUpInside?()
    }
}
