import Foundation
import AsyncDisplayKit
import Display

private let titleFont = Font.regular(17.0)

final class BotPaymentSwitchItemNode: BotPaymentItemNode {
    private let title: String
    private let titleNode: ASTextNode
    private let switchNode: SwitchNode
    
    private var theme: PresentationTheme?
    
    var isOn: Bool {
        get {
            return self.switchNode.isOn
        } set(value) {
            if self.switchNode.isOn != value {
                self.switchNode.setOn(value, animated: true)
            }
        }
    }
    
    init(title: String, isOn: Bool) {
        self.title = title
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        self.switchNode = SwitchNode()
        self.switchNode.setOn(isOn, animated: false)
        
        super.init(needsBackground: true)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.switchNode)
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            
            self.switchNode.frameColor = theme.list.itemSwitchColors.frameColor
            self.switchNode.contentColor = theme.list.itemSwitchColors.contentColor
            self.switchNode.handleColor = theme.list.itemSwitchColors.handleColor
        }
        
        let leftInset: CGFloat = 16.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleSize))
        
        let switchSize = self.switchNode.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.switchNode, frame: CGRect(origin: CGPoint(x: width - switchSize.width - 15.0, y: 6.0), size: switchSize))
        
        return 44.0
    }
}
