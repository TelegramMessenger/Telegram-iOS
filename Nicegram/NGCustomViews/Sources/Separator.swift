import UIKit
import SnapKit
import NGTheme

public extension UIView {
    static func separator(ngTheme: NGThemeColors) -> UIView {
        return separator(color: ngTheme.separatorColor)
    }
    
    static func separator(color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
        return view
    }
}
