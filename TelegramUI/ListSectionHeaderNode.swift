import Foundation
import AsyncDisplayKit
import Display

final class ListSectionHeaderNode: ASDisplayNode {
    private let label: TextNode
    private var theme: PresentationTheme
    
    var title: String? {
        didSet {
            self.calculatedLayoutDidChange()
            self.setNeedsLayout()
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.label = TextNode()
        self.label.isLayerBacked = true
        self.label.isOpaque = true
        
        super.init()
        
        self.addSubnode(self.label)
        
        self.backgroundColor = theme.chatList.sectionHeaderFillColor
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.backgroundColor = theme.chatList.sectionHeaderFillColor
            if !self.bounds.size.width.isZero && !self.bounds.size.height.isZero {
                self.layout()
            }
        }
    }
    
    override func layout() {
        let size = self.bounds.size
        
        let makeLayout = TextNode.asyncLayout(self.label)
        let (labelLayout, labelApply) = makeLayout(NSAttributedString(string: self.title ?? "", font: Font.medium(12.0), textColor: self.theme.chatList.sectionHeaderTextColor), self.backgroundColor, 1, .end, CGSize(width: max(0.0, size.width - 18.0), height: size.height), .natural, nil, UIEdgeInsets())
        let _ = labelApply()
        self.label.frame = CGRect(origin: CGPoint(x: 9.0, y: 6.0), size: labelLayout.size)
    }
}
