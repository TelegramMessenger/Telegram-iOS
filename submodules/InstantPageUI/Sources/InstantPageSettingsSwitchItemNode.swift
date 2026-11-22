import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class InstantPageSettingsSwitchNode: InstantPageSettingsItemNode {
    private let title: String
    private let toggled: (Bool) -> Void
    
    private let labelNode: ASTextNode
    private let switchNode: SwitchNode
    
    var isOn: Bool {
        didSet {
            if self.isEnabled && self.isOn != self.switchNode.isOn {
                self.switchNode.setOn(self.isOn, animated: true)
            }
        }
    }
    
    var isEnabled: Bool {
        didSet {
            if self.isEnabled {
                self.switchNode.setOn(self.isOn, animated: true)
                self.switchNode.allowsGroupOpacity = false
                self.switchNode.alpha = 1.0
            } else {
                self.switchNode.setOn(false, animated: true)
                self.switchNode.allowsGroupOpacity = true
                self.switchNode.alpha = 0.6
            }
            self.switchNode.isUserInteractionEnabled = self.isEnabled
        }
    }
    
    init(theme: InstantPageSettingsItemTheme, title: String, isOn: Bool, isEnabled: Bool, toggled: @escaping (Bool) -> Void) {
        self.title = title
        self.toggled = toggled
        
        self.labelNode = ASTextNode()
        
        self.switchNode = SwitchNode()
        if isEnabled {
            self.switchNode.isOn = isOn
        } else {
            self.switchNode.isOn = false
            self.switchNode.allowsGroupOpacity = true
            self.switchNode.alpha = 0.6
        }
        
        self.isOn = isOn
        self.isEnabled = isEnabled
        
        super.init(theme: theme, selectable: false)
        
        self.addSubnode(self.labelNode)
        self.addSubnode(self.switchNode)
        
        self.switchNode.valueUpdated = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isOn = value
                toggled(value)
            }
        }
    }
    
    override func updateTheme(_ theme: InstantPageSettingsItemTheme) {
        super.updateTheme(theme)
        
        self.labelNode.attributedText = NSAttributedString(string: self.title, font: Font.regular(17.0), textColor: theme.primaryColor)
    }
    
    override func updateInternalLayout(width: CGFloat, insets: UIEdgeInsets, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> (height: CGFloat, separatorInset: CGFloat?) {
        
        let labelSize = self.labelNode.measure(CGSize(width: width - 46.0 - 5.0, height: 44.0))
        self.labelNode.frame = CGRect(origin: CGPoint(x: 15.0, y: insets.top + floor((44.0 - labelSize.height) / 2.0)), size: labelSize)
        if let switchView = self.switchNode.view as? UISwitch {
            if self.switchNode.bounds.size.width.isZero {
                switchView.sizeToFit()
            }
            let switchSize = switchView.bounds.size
            
            self.switchNode.frame = CGRect(origin: CGPoint(x: width - switchSize.width - 15.0, y: insets.top + 6.0), size: switchSize)
        }
        return (44.0 + insets.top + insets.bottom, nil)
    }
}
