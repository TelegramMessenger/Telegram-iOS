import UIKit

public enum AdjustingFontSizeMode {
    case no
    case yes(CGFloat)
}

public extension UILabel {
    func applyStyle(font: UIFont, textColor: UIColor, textAlignment: NSTextAlignment, numberOfLines: Int, adjustFontSize: AdjustingFontSizeMode) {
        self.font = font
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.numberOfLines = numberOfLines
        
        switch adjustFontSize {
        case .no:
            self.adjustsFontSizeToFitWidth = false
        case .yes(let cGFloat):
            self.adjustsFontSizeToFitWidth = true
            self.minimumScaleFactor = cGFloat
        }
    }
}

public extension UILabel {
    func enableFontSizeAdjusting(minimumScaleFactor: CGFloat) {
        self.adjustsFontSizeToFitWidth = true
        self.minimumScaleFactor = minimumScaleFactor
    }
}
