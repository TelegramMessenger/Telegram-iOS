import Foundation
import Display
import AsyncDisplayKit

final class ChatRequestInProgressTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let separatorNode: ASDisplayNode
    private let titleNode: ASTextNode
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: "Loading...", font: Font.regular(14.0), textColor: UIColor.black)
        self.titleNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.backgroundColor = UIColor(0xF5F6F8)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 40.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: 100.0))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: floor((panelHeight - titleSize.height) / 2.0)), size: titleSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
}
