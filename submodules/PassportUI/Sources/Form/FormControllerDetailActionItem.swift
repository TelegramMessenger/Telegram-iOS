import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let textFont = Font.regular(17.0)
private let errorFont = Font.regular(13.0)

final class FormControllerDetailActionItem: FormControllerItem {
    let title: String
    let text: String
    let placeholder: String
    let error: String?
    let activated: () -> Void
    
    init(title: String, text: String, placeholder: String, error: String?, activated: @escaping () -> Void) {
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.error = error
        self.activated = activated
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerDetailActionItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? FormControllerDetailActionItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class FormControllerDetailActionItemNode: FormBlockItemNode<FormControllerDetailActionItem> {
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let errorNode: ImmediateTextNode
    
    private var item: FormControllerDetailActionItem?
    
    init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.errorNode = ImmediateTextNode()
        self.errorNode.displaysAsynchronously = false
        self.errorNode.maximumNumberOfLines = 0
        
        super.init(selectable: true, topSeparatorInset: .regular)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.errorNode)
    }
    
    override func update(item: FormControllerDetailActionItem, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
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
            
            self.errorNode.attributedText = NSAttributedString(string: item.error ?? "", font: errorFont, textColor: theme.list.freeTextErrorColor)
            let errorSize = self.errorNode.updateLayout(CGSize(width: width - params.maxAligningInset - 16.0, height: CGFloat.greatestFiniteMagnitude))
            
            transition.updateFrame(node: self.errorNode, frame: CGRect(origin: CGPoint(x: params.maxAligningInset, y: 44.0 - 4.0), size: errorSize))
            
            var height: CGFloat = 44.0
            if !errorSize.width.isZero {
                height += -4.0 + errorSize.height + 8.0
            }
            
            return height
        })
    }
    
    func activate() {
        self.item?.activated()
    }
    
    override func selected() {
        activate()
    }
}
