import UIKit

public extension CustomButton {
    func applyMainActionStyle() {
        foregroundColor = .white
        backgroundColor = .ngActiveButton
        layer.cornerRadius = 6
        configureTitleLabel { label in
            label.font = .systemFont(ofSize: 16, weight: .semibold)
        }
    }
}
