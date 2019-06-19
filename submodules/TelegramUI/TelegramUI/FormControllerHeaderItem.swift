import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(14.0)

final class FormControllerHeaderItem: FormControllerItem {
    let text: String
    
    init(text: String) {
        self.text = text
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerHeaderItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
            guard let node = node as? FormControllerHeaderItemNode else {
                assertionFailure()
                return 0.0
            }
            return node.update(item: self, previousNeighbor: previousNeighbor, width: width, theme: theme, transition: transition)
        })
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
    
    func update(item: FormControllerHeaderItem, previousNeighbor: FormControllerItemNeighbor, width: CGFloat, theme: PresentationTheme, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.textNode.attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        let leftInset: CGFloat = 16.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - 10.0, height: CGFloat.greatestFiniteMagnitude))
        
        let height: CGFloat
        switch previousNeighbor {
            case .none:
                height = 20.0 + 30.0
            case .spacer:
                height = 14.0
            case .item:
                height = 14.0
        }
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: height - 23.0), size: textSize))
        
        return height
    }
    
    var preventsTouchesToOtherItems: Bool {
        return false
    }
    
    func touchesToOtherItemsPrevented() {
    }
}
