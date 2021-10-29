import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(14.0)

final class BotPaymentHeaderItemNode: BotPaymentItemNode {
    private let text: String
    private let textNode: ASTextNode
    
    private var theme: PresentationTheme?
    
    init(text: String) {
        self.text = text
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 1
        
        super.init(needsBackground: false)
        
        self.addSubnode(self.textNode)
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.textNode.attributedText = NSAttributedString(string: self.text, font: titleFont, textColor: theme.list.sectionHeaderTextColor)
        }
        
        let leftInset: CGFloat = 16.0
        
        let textSize = self.textNode.measure(CGSize(width: width - leftInset - 10.0 - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset + sideInset, y: 7.0), size: textSize))
        
        return 30.0
    }
}
