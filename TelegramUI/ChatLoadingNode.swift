import Foundation
import AsyncDisplayKit
import Display

final class ChatLoadingNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let activityIndicator: ActivityIndicator
    
    init(theme: PresentationTheme) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = PresentationResourcesChat.chatLoadingIndicatorBackgroundImage(theme)
        
        self.activityIndicator = ActivityIndicator(type: .custom(theme.chat.serviceMessage.serviceMessagePrimaryTextColor, 22.0, 2.0, false), speed: .regular)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.activityIndicator)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        let displayRect = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
        
        if let image = self.backgroundNode.image {
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - image.size.width) / 2.0), y: displayRect.minY + floor((displayRect.height - image.size.height) / 2.0)), size: image.size))
        }
        
        let activitySize = self.activityIndicator.measure(size)
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - activitySize.width) / 2.0), y: displayRect.minY + floor((displayRect.height - activitySize.height) / 2.0)), size: activitySize))
    }
}

