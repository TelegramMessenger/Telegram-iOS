import Foundation
import AsyncDisplayKit
import Display

private let textFont = Font.regular(17.0)

final class FormControllerDetailActionItem: FormControllerItem {
    let title: String
    let text: String
    let placeholder: String
    let activated: () -> Void
    
    init(title: String, text: String, placeholder: String, activated: @escaping () -> Void) {
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.activated = activated
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerDetailActionItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? FormControllerDetailActionItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class FormControllerDetailActionItemNode: FormBlockItemNode<FormControllerDetailActionItem> {
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var item: FormControllerDetailActionItem?
    
    init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = false
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = false
        
        super.init(selectable: true, topSeparatorInset: .regular)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    override func update(item: FormControllerDetailActionItem, theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        self.item = item
        
        let leftInset: CGFloat = 16.0
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: theme.list.itemPrimaryTextColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        let aligningInset: CGFloat
        if titleSize.width.isZero {
            aligningInset = 0.0
        } else {
            aligningInset = leftInset + titleSize.width + 17.0
        }
        
        return (FormControllerItemPreLayout(aligningInset: aligningInset), { params in
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleSize))
            
            if !item.text.isEmpty {
                self.textNode.attributedText = NSAttributedString(string: item.text, font: textFont, textColor: theme.list.itemPrimaryTextColor)
            } else {
                self.textNode.attributedText = NSAttributedString(string: item.placeholder, font: textFont, textColor: theme.list.itemPlaceholderTextColor)
            }
            
            let textSize = self.textNode.updateLayout(CGSize(width: width - params.maxAligningInset - 16.0, height: CGFloat.greatestFiniteMagnitude))
            
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: params.maxAligningInset, y: 11.0), size: textSize))
            return 44.0
        })
    }
    
    override func selected() {
        self.item?.activated()
    }
}
