import Foundation
import AsyncDisplayKit
import Display
import LegacyComponents

final class GalleryNavigationRecipientNode: ASDisplayNode {
    private var iconNode: ASImageNode
    private var textNode: ASTextNode
    
    init(color: UIColor, title: String) {
        self.iconNode = ASImageNode()
        self.iconNode.alpha = 0.45
        self.iconNode.image = TGComponentsImageNamed("PhotoPickerArrow")
        
        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.bold(13.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.45))
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 30.0, height: 30.0)
    }
    
    override func layout() {
        super.layout()
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: -2.0, y: 9.0), size: image.size)
        }
        
        self.textNode.frame = CGRect(x: self.iconNode.frame.maxX + 6.0, y: 7.0, width: 150.0, height: 20.0)
    }
}
