import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents

public final class GalleryNavigationRecipientNode: ASDisplayNode, NavigationButtonCustomDisplayNode {
    private var iconNode: ASImageNode
    private var textNode: ImmediateTextNode
    
    public init(color: UIColor, title: String) {
        self.iconNode = ASImageNode()
        self.iconNode.alpha = 0.45
        self.iconNode.image = TGComponentsImageNamed("PhotoPickerArrow")
        
        self.textNode = ImmediateTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.bold(13.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.45))
        self.textNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
        
        if title.isEmpty {
            self.iconNode.isHidden = true
            self.textNode.isHidden = true
        }
    }
    
    public var isHighlightable: Bool {
        return false
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 50.0, height: constrainedSize.height))
        return CGSize(width: textSize.width + 12.0, height: 30.0)
    }
    
    override public func layout() {
        super.layout()
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: -2.0, y: 9.0), size: image.size)
        }
        
        self.textNode.frame = CGRect(x: self.iconNode.frame.maxX + 6.0, y: 7.0, width: self.frame.size.width - 12.0, height: 15.0)
    }
}
