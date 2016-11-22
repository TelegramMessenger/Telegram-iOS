import Foundation
import Display
import AsyncDisplayKit

final class ChatToastAlertPanelNode: ChatTitleAccessoryPanelNode {
    private let separatorNode: ASDisplayNode
    private let titleNode: ASTextNode
    
    var text: String = "" {
        didSet {
            if self.text != oldValue {
                self.titleNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: UIColor.black)
                self.setNeedsLayout()
            }
        }
    }
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: "", font: Font.regular(14.0), textColor: UIColor.black)
        self.titleNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.backgroundColor = UIColor(0xF5F6F8)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 40.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        self.setNeedsLayout()
        
        return panelHeight
    }
    
    override func layout() {
        super.layout()
        
        let titleSize = self.titleNode.measure(CGSize(width: self.bounds.size.width - 20.0, height: 100.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((self.bounds.size.width - titleSize.width) / 2.0), y: floor((self.bounds.size.height - titleSize.height) / 2.0)), size: titleSize)
    }
}
