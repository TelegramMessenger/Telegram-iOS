import UIKit

public extension UITextView {
    func applyPlainStyle() {
        backgroundColor = .clear
        isEditable = false
        isScrollEnabled = false
        textContainer.lineFragmentPadding = .zero
        textContainerInset = .zero
        linkTextAttributes = [:]
    }
}
