import UIKit

public extension UIImageView {
    func applyStyle(contentMode: UIView.ContentMode, tintColor: UIColor?, cornerRadius: CGFloat) {
        self.contentMode = contentMode
        if let tintColor {
            self.tintColor = tintColor
        }
        self.clipsToBounds = true
        self.layer.cornerRadius = cornerRadius
    }
}
