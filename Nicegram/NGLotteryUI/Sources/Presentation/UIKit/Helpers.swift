import NGCoreUI
import NGCustomViews
import UIKit

public extension UIColor {
    static var lotteryBackgroundTint: UIColor {
        return UIColor(hex: "FBBC05")
    }
    
    static var lotteryForegroundTint: UIColor {
        return UIColor(hex: "6F0215")
    }
}

public extension UILabel {
    func applySectionTitleStyle() {
        self.applyStyle(
            font: .systemFont(ofSize: 16, weight: .semibold),
            textColor: .white,
            textAlignment: .natural,
            numberOfLines: 2,
            adjustFontSize: .yes(0.8)
        )
    }
}

public extension UIView {
    func applyLotteryBackground() {
        let backgroundImageView = UIImageView(image: UIImage(named: "ng.lottery.background"))
        backgroundImageView.applyStyle(
            contentMode: .scaleToFill,
            tintColor: nil,
            cornerRadius: .zero
        )
        backgroundImageView.setIntrinsicContentSizeMinimumPriority()
        insertSubview(backgroundImageView, at: 0)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    static func lotterySectionsSeparator() -> UIView {
        return .separator(color: .white.withAlphaComponent(0.15))
    }
}
