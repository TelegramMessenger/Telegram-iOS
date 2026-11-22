import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let textFont = Font.regular(17.0)

enum FormControllerActionType {
    case accent
    case destructive
}

final class FormControllerActionItem: FormControllerItem {
    let type: FormControllerActionType
    let title: String
    let fullTopInset: Bool
    let activated: () -> Void
    
    init(type: FormControllerActionType, title: String, fullTopInset: Bool = false, activated: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.fullTopInset = fullTopInset
        self.activated = activated
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerActionItemNode(fullTopInset: self.fullTopInset)
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? FormControllerActionItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class FormControllerActionItemNode: FormBlockItemNode<FormControllerActionItem> {
    private let titleNode: ImmediateTextNode
    
    private var item: FormControllerActionItem?
    
    init(fullTopInset: Bool = false) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        super.init(selectable: true, topSeparatorInset: fullTopInset ? .custom(0.0) : .regular)
        
        self.addSubnode(self.titleNode)
    }
    
    override func update(item: FormControllerActionItem, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        self.item = item
        
        let leftInset: CGFloat = 16.0
        let titleColor: UIColor
        switch item.type {
            case .accent:
                titleColor = theme.list.itemAccentColor
            case .destructive:
                titleColor = theme.list.itemDestructiveColor
        }
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: titleColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - 16.0, height: CGFloat.greatestFiniteMagnitude))
        
        return (FormControllerItemPreLayout(aligningInset: 0.0), { params in
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleSize))
            return 44.0
        })
    }
    
    override func selected() {
        self.item?.activated()
    }
}
