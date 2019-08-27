import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class InstantPageSettingsButtonItemNode: InstantPageSettingsItemNode {
    private let title: String
    private let tapped: () -> Void
    
    private let labelNode: ASTextNode
    
    init(theme: InstantPageSettingsItemTheme, title: String, tapped: @escaping () -> Void) {
        self.title = title
        self.tapped = tapped
        
        self.labelNode = ASTextNode()
        
        super.init(theme: theme, selectable: true)
        
        self.addSubnode(self.labelNode)
        
        self.updateTheme(theme)
    }
    
    override func updateTheme(_ theme: InstantPageSettingsItemTheme) {
        super.updateTheme(theme)
        
        self.labelNode.attributedText = NSAttributedString(string: self.title, font: Font.regular(17.0), textColor: theme.accentColor)
    }
    
    override func updateInternalLayout(width: CGFloat, insets: UIEdgeInsets, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> (height: CGFloat, separatorInset: CGFloat?) {
        var separatorInset: CGFloat?
        if case .sameSection = previousItem.0, let previousNode = previousItem.1, previousNode is InstantPageSettingsFontFamilyNode {
            separatorInset = 46.0
        }
        let labelSize = self.labelNode.measure(CGSize(width: width - 15.0 - 5.0, height: 44.0))
        self.labelNode.frame = CGRect(origin: CGPoint(x: 15.0, y: insets.top + floor((44.0 - labelSize.height) / 2.0)), size: labelSize)
        return (44.0 + insets.top + insets.bottom, separatorInset)
    }
    
    override func pressed() {
        self.tapped()
    }
}
