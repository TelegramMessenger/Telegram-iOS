import SnapKit
import UIKit

public extension UIView {
    func setIntrinsicContentSizeMinimumPriority() {
        self.snp.contentHuggingHorizontalPriority = 1
        self.snp.contentHuggingVerticalPriority = 1
        self.snp.contentCompressionResistanceHorizontalPriority = 1
        self.snp.contentCompressionResistanceVerticalPriority = 1
    }
}

public extension UIView {
    func horizontalCenteringContainer() -> UIView {
        let view = UIView()
        view.addSubview(self)
        self.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
        }
        return view
    }
}
