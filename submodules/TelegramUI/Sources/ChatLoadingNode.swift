import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import ActivityIndicator

final class ChatLoadingNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let activityIndicator: ActivityIndicator
    private let offset: CGPoint
    
    init(theme: PresentationTheme, chatWallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        let graphics = PresentationResourcesChat.additionalGraphics(theme, wallpaper: chatWallpaper, bubbleCorners: bubbleCorners)
        self.backgroundNode.image = graphics.chatLoadingIndicatorBackgroundImage
        
        let serviceColor = serviceMessageColorComponents(theme: theme, wallpaper: chatWallpaper)
        self.activityIndicator = ActivityIndicator(type: .custom(serviceColor.primaryText, 22.0, 2.0, false), speed: .regular)
        if serviceColor.primaryText != .white {
            self.offset = CGPoint(x: 0.5, y: 0.5)
        } else {
            self.offset = CGPoint()
        }
        
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
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - activitySize.width) / 2.0) + self.offset.x, y: displayRect.minY + floor((displayRect.height - activitySize.height) / 2.0) + self.offset.y), size: activitySize))
    }
}

