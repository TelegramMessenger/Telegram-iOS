import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ChatPresentationInterfaceState

final class ChatToastAlertPanelNode: ChatTitleAccessoryPanelNode {
    private let separatorNode: ASDisplayNode
    private let titleNode: ImmediateTextNode
    
    private var textColor: UIColor = .black {
        didSet {
            if !self.textColor.isEqual(oldValue) {
                self.titleNode.attributedText = NSAttributedString(string: self.text, font: Font.regular(14.0), textColor: self.textColor)
            }
        }
    }
    
    var text: String = "" {
        didSet {
            if self.text != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: self.textColor)
                self.setNeedsLayout()
            }
        }
    }
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.attributedText = NSAttributedString(string: "", font: Font.regular(14.0), textColor: UIColor.black)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.insets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
        
        super.init()

        self.addSubnode(self.titleNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let panelHeight: CGFloat = 40.0

        self.textColor = interfaceState.theme.rootController.navigationBar.primaryTextColor
        self.separatorNode.backgroundColor = interfaceState.theme.chat.historyNavigation.strokeColor
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - rightInset - 20.0, height: 100.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: floor((panelHeight - titleSize.height) / 2.0)), size: titleSize)
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight)
    }
}
