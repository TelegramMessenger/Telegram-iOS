import Foundation
import AsyncDisplayKit
import Display

final class ListSectionHeaderNode: ASDisplayNode {
    private let label: TextNode
    
    var title: String? {
        didSet {
            self.calculatedLayoutDidChange()
            self.setNeedsLayout()
        }
    }
    
    override init() {
        self.label = TextNode()
        self.label.isLayerBacked = true
        self.label.isOpaque = true
        
        super.init()
        
        self.addSubnode(self.label)
        
        self.backgroundColor = UIColor(0xf7f7f7)
    }
    
    override func layout() {
        let size = self.bounds.size
        
        let makeLayout = TextNode.asyncLayout(self.label)
        let (labelLayout, labelApply) = makeLayout(NSAttributedString(string: self.title ?? "", font: Font.medium(12.0), textColor: UIColor(0x8e8e93)), self.backgroundColor, 1, .end, CGSize(width: max(0.0, size.width - 18.0), height: size.height), .natural, nil)
        let _ = labelApply()
        self.label.frame = CGRect(origin: CGPoint(x: 9.0, y: 6.0), size: labelLayout.size)
    }
}
