import UIKit

public extension UIStackView {
    func removeAllArrangedSubviews() {
        let arrangedSubviews = arrangedSubviews
        for arrangedSubview in arrangedSubviews {
            self.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
    }
}

public extension UIStackView {
    convenience init(arrangedSubviews: [UIView], axis: NSLayoutConstraint.Axis, spacing: CGFloat, alignment: Alignment) {
        self.init(arrangedSubviews: arrangedSubviews)
        self.applyStyle(axis: axis, spacing: spacing, alignment: alignment)
    }
    
    func applyStyle(axis: NSLayoutConstraint.Axis, spacing: CGFloat, alignment: Alignment) {
        self.axis = axis
        self.spacing = spacing
        self.alignment = alignment
    }
}
