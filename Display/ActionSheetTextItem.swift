import Foundation
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
    public static let defaultFont: UIFont = Font.regular(13.0)
    
    private let theme: ActionSheetControllerTheme
    
    private var item: ActionSheetTextItem?
    
    private let label: ASTextNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.label = ASTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 0
        self.label.displaysAsynchronously = false
        self.label.truncationMode = .byTruncatingTail
        
        super.init(theme: theme)
        
        self.label.isUserInteractionEnabled = false
        self.addSubnode(self.label)
    }
    
    func setItem(_ item: ActionSheetTextItem) {
        self.item = item
        
        self.label.attributedText = NSAttributedString(string: item.title, font: ActionSheetTextNode.defaultFont, textColor: self.theme.secondaryTextColor, paragraphAlignment: .center)
        
        self.setNeedsLayout()
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let labelSize = self.label.measure(CGSize(width: max(1.0, constrainedSize.width - 20.0), height: constrainedSize.height))
        return CGSize(width: constrainedSize.width, height: max(57.0, labelSize.height + 32.0))
    }
    
    public override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let labelSize = self.label.measure(CGSize(width: max(1.0, size.width - 20.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
    }
}
