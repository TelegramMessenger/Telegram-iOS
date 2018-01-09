import Foundation
import AsyncDisplayKit

import LegacyComponents

enum CheckNodeStyle {
    case plain
    case overlay
}

final class CheckNode: ASDisplayNode {
    private let strokeColor: UIColor
    private let fillColor: UIColor
    private let foregroundColor: UIColor
    private let checkStyle: CheckNodeStyle
    
    private var checkView: TGCheckButtonView?
    
    private(set) var isChecked: Bool = false
    
    init(strokeColor: UIColor, fillColor: UIColor, foregroundColor: UIColor, style: CheckNodeStyle) {
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
        self.checkStyle = style
        
        super.init()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let style: TGCheckButtonStyle
        switch self.checkStyle {
            case .plain:
                style = TGCheckButtonStyleDefault
            case .overlay:
                style = TGCheckButtonStyleMedia
        }
        let checkView = TGCheckButtonView(style: style, pallete: TGCheckButtonPallete(defaultBackgroundColor: self.fillColor, accentBackgroundColor: self.fillColor, defaultBorderColor: self.strokeColor, mediaBorderColor: self.strokeColor, chatBorderColor: self.strokeColor, check: self.foregroundColor, blueColor: self.fillColor, barBackgroundColor: self.fillColor))!
        checkView.setSelected(true, animated: false)
        checkView.layoutSubviews()
        checkView.setSelected(self.isChecked, animated: false)
        self.checkView = checkView
        self.view.addSubview(checkView)
        checkView.frame = self.bounds
    }
    
    func setIsChecked(_ isChecked: Bool, animated: Bool) {
        if isChecked != self.isChecked {
            self.isChecked = isChecked
            self.checkView?.setSelected(isChecked, animated: animated)
        }
    }
}
