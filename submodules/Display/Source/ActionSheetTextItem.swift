import Foundation
import UIKit
import AsyncDisplayKit

public class ActionSheetTextItem: ActionSheetItem {
    public let title: String
    
    public init(title: String) {
        self.title = title
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = ActionSheetTextNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? ActionSheetTextNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
    }
}

public class ActionSheetTextNode: ActionSheetItemNode {
    private let defaultFont: UIFont
    
    private let theme: ActionSheetControllerTheme
    
    private var item: ActionSheetTextItem?
    
    private let label: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.label = ImmediateTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 0
        self.label.displaysAsynchronously = false
        self.label.truncationType = .end
        self.label.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        self.accessibilityArea.accessibilityTraits = .staticText
        
        super.init(theme: theme)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
        
        self.addSubnode(self.accessibilityArea)
    }
    
    func setItem(_ item: ActionSheetTextItem) {
        self.item = item
        
        let defaultFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.label.attributedText = NSAttributedString(string: item.title, font: defaultFont, textColor: self.theme.secondaryTextColor, paragraphAlignment: .center)
        self.accessibilityArea.accessibilityLabel = item.title
        
        self.setNeedsLayout()
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, constrainedSize.width - 20.0), height: constrainedSize.height))
        return CGSize(width: constrainedSize.width, height: max(57.0, labelSize.height + 32.0))
    }
    
    public override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, size.width - 20.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
    }
}
