import Foundation
import AsyncDisplayKit
import Display

private let titleFont = Font.regular(14.0)

final class FormControllerHeaderItem: FormControllerItem {
    let text: String
    
    init(text: String) {
        self.text = text
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerHeaderItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let node = node as? FormControllerHeaderItemNode else {
            assertionFailure()
            return 0.0
        }
        return node.update(item: self, width: width, theme: theme, transition: transition)
    }
}

final class FormControllerHeaderItemNode: ASDisplayNode, FormControllerItemNode {
    private let textNode: ImmediateTextNode
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func update(item: FormControllerHeaderItem, width: CGFloat, theme: PresentationTheme, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.textNode.attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        let leftInset: CGFloat = 16.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - 10.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: textSize))
        
        return 30.0
    }
}
