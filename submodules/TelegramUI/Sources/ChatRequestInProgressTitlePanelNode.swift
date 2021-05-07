import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

final class ChatRequestInProgressTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let titleNode: ImmediateTextNode
    
    private var theme: PresentationTheme?
    private var strings: PresentationStrings?
    
    override init() {
        self.backgroundNode = NavigationBackgroundNode(color: .clear)

        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        super.init()

        self.addSubnode(self.backgroundNode)
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
            
            self.backgroundNode.color = interfaceState.theme.rootController.navigationBar.backgroundColor
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }
        
        let panelHeight: CGFloat = 40.0

        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight)))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - rightInset, height: 100.0))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: floor((panelHeight - titleSize.height) / 2.0)), size: titleSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
}
