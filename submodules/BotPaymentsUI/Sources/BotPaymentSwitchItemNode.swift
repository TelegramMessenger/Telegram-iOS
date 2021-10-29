import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(17.0)

final class BotPaymentSwitchItemNode: BotPaymentItemNode {
    private let toggled: (Bool) -> Void
    
    private let title: String
    private let titleNode: ASTextNode
    private let switchNode: SwitchNode
    private let buttonNode: HighlightableButtonNode
    
    private var theme: PresentationTheme?
    
    var canBeSwitched: Bool {
        didSet {
            
        }
    }
    
    var isOn: Bool {
        get {
            return self.switchNode.isOn
        } set(value) {
            if self.switchNode.isOn != value {
                self.switchNode.setOn(value, animated: true)
            }
        }
    }
    
    init(title: String, isOn: Bool, canBeSwitched: Bool = true, toggled: @escaping (Bool) -> Void = { _ in }) {
        self.title = title
        self.canBeSwitched = canBeSwitched
        self.toggled = toggled
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        self.switchNode = SwitchNode()
        self.switchNode.setOn(isOn, animated: false)
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init(needsBackground: true)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.switchNode)
        self.addSubnode(self.buttonNode)
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        if canBeSwitched {
            self.switchNode.isUserInteractionEnabled = true
            self.buttonNode.isUserInteractionEnabled = false
        } else {
            self.switchNode.isUserInteractionEnabled = false
            self.buttonNode.isUserInteractionEnabled = true
        }
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            
            self.switchNode.frameColor = theme.list.itemSwitchColors.frameColor
            self.switchNode.contentColor = theme.list.itemSwitchColors.contentColor
            self.switchNode.handleColor = theme.list.itemSwitchColors.handleColor
        }
        
        let leftInset: CGFloat = 16.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0 - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + sideInset, y: 11.0), size: titleSize))
        
        let switchSize = self.switchNode.measure(CGSize(width: 100.0, height: 100.0))
        let switchFrame = CGRect(origin: CGPoint(x: width - switchSize.width - 15.0 - sideInset, y: 6.0), size: switchSize)
        transition.updateFrame(node: self.switchNode, frame: switchFrame)
        transition.updateFrame(node: self.buttonNode, frame: switchFrame)
        
        return 44.0
    }
    
    @objc private func buttonPressed() {
        self.toggled(!self.isOn)
    }
}
