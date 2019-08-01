import Foundation
import UIKit
import AsyncDisplayKit

import LegacyComponents

public enum CheckNodeStyle {
    case plain
    case overlay
    case navigation
}

public final class CheckNode: ASDisplayNode {
    private var strokeColor: UIColor
    private var fillColor: UIColor
    private var foregroundColor: UIColor
    private let checkStyle: CheckNodeStyle
    
    private var checkView: TGCheckButtonView?
    
    public private(set) var isChecked: Bool = false
    
    private weak var target: AnyObject?
    private var action: Selector?
    
    public init(strokeColor: UIColor, fillColor: UIColor, foregroundColor: UIColor, style: CheckNodeStyle) {
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
        self.checkStyle = style
        
        super.init()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let style: TGCheckButtonStyle
        let checkSize: CGSize
        switch self.checkStyle {
        case .plain:
            style = TGCheckButtonStyleDefault
            checkSize = CGSize(width: 32.0, height: 32.0)
        case .overlay:
            style = TGCheckButtonStyleMedia
            checkSize = CGSize(width: 32.0, height: 32.0)
        case .navigation:
            style = TGCheckButtonStyleGallery
            checkSize = CGSize(width: 39.0, height: 39.0)
        }
        let checkView = TGCheckButtonView(style: style, pallete: TGCheckButtonPallete(defaultBackgroundColor: self.fillColor, accentBackgroundColor: self.fillColor, defaultBorderColor: self.strokeColor, mediaBorderColor: self.strokeColor, chatBorderColor: self.strokeColor, check: self.foregroundColor, blueColor: self.fillColor, barBackgroundColor: self.fillColor))!
        checkView.setSelected(true, animated: false)
        checkView.layoutSubviews()
        checkView.setSelected(self.isChecked, animated: false)
        if let target = self.target, let action = self.action {
            checkView.addTarget(target, action: action, for: .touchUpInside)
        }
        self.checkView = checkView
        self.view.addSubview(checkView)
        
        checkView.frame = CGRect(origin: CGPoint(), size: checkSize)
    }
    
    public func setIsChecked(_ isChecked: Bool, animated: Bool) {
        if isChecked != self.isChecked {
            self.isChecked = isChecked
            self.checkView?.setSelected(isChecked, animated: animated)
        }
    }
    
    public func addTarget(target: AnyObject?, action: Selector) {
        self.target = target
        self.action = action
        if self.isNodeLoaded {
            self.checkView?.addTarget(target, action: action, for: .touchUpInside)
        }
    }
}
