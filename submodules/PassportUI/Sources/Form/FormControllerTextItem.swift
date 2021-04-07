import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(14.0)

enum FormControllerTextItemColor {
    case standard
    case error
}

final class FormControllerTextItem: FormControllerItem {
    let text: String
    let color: FormControllerTextItemColor
    
    init(text: String, color: FormControllerTextItemColor = .standard) {
        self.text = text
        self.color = color
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerTextItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
            guard let node = node as? FormControllerTextItemNode else {
                assertionFailure()
                return 0.0
            }
            return node.update(item: self, width: width, theme: theme, transition: transition)
        })
    }
}

final class FormControllerTextItemNode: ASDisplayNode, FormControllerItemNode {
    private let textNode: ImmediateTextNode
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    func update(item: FormControllerTextItem, width: CGFloat, theme: PresentationTheme, transition: ContainedViewLayoutTransition) -> CGFloat {
        let color: UIColor
        switch item.color {
            case .standard:
                color = theme.list.freeTextColor
            case .error:
                color = theme.list.freeTextErrorColor
        }
        self.textNode.attributedText = NSAttributedString(string: item.text, font: titleFont, textColor: color)
        let leftInset: CGFloat = 16.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - 10.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: textSize))
        
        return textSize.height + 14.0
    }
    
    var preventsTouchesToOtherItems: Bool {
        return false
    }
    
    func touchesToOtherItemsPrevented() {
    }
}
