import Foundation
import Display
import AsyncDisplayKit

final class ChatRequestInProgressTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let separatorNode: ASDisplayNode
    private let titleNode: ASTextNode
    
    private var theme: PresentationTheme?
    private var strings: PresentationStrings?
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if interfaceState.strings !== self.strings {
            self.strings = interfaceState.strings
            
            self.titleNode.attributedText = NSAttributedString(string: interfaceState.strings.Channel_NotificationLoading, font: Font.regular(14.0), textColor: interfaceState.theme.rootController.navigationBar.primaryTextColor)
        }
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.backgroundColor = interfaceState.theme.rootController.navigationBar.backgroundColor
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }
        
        let panelHeight: CGFloat = 40.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - rightInset, height: 100.0))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: floor((panelHeight - titleSize.height) / 2.0)), size: titleSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
}
