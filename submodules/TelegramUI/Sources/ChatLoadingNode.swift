import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import WallpaperBackgroundNode
import ShimmerEffect

final class ChatLoadingNode: ASDisplayNode {
    private let backgroundNode: NavigationBackgroundNode
    private let activityIndicator: ActivityIndicator
    private let offset: CGPoint
    
    init(theme: PresentationTheme, chatWallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners) {
        self.backgroundNode = NavigationBackgroundNode(color: selectDateFillStaticColor(theme: theme, wallpaper: chatWallpaper), enableBlur: dateFillNeedsBlur(theme: theme, wallpaper: chatWallpaper))
        
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

        let backgroundSize: CGFloat = 30.0
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - backgroundSize) / 2.0), y: displayRect.minY + floor((displayRect.height - backgroundSize) / 2.0)), size: CGSize(width: backgroundSize, height: backgroundSize)))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: self.backgroundNode.bounds.height / 2.0, transition: transition)
        
        let activitySize = self.activityIndicator.measure(size)
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: displayRect.minX + floor((displayRect.width - activitySize.width) / 2.0) + self.offset.x, y: displayRect.minY + floor((displayRect.height - activitySize.height) / 2.0) + self.offset.y), size: activitySize))
    }
    
    var progressFrame: CGRect {
        return self.backgroundNode.frame
    }
}

private let avatarSize = CGSize(width: 38.0, height: 38.0)

final class ChatLoadingPlaceholderMessageContainer {
    let avatarNode: ASImageNode?
    let avatarBorderNode: ASImageNode?
    
    let bubbleNode: ASImageNode
    let bubbleBorderNode: ASImageNode
    
    var parentView: UIView? {
        return self.bubbleNode.supernode?.view
    }
    
    var frame: CGRect {
        return self.bubbleNode.frame
    }
        
    init(hasAvatar: Bool, bubbleImage: UIImage?, bubbleBorderImage: UIImage?) {
        if hasAvatar {
            self.avatarNode = ASImageNode()
            self.avatarNode?.displaysAsynchronously = false
            self.avatarNode?.image = generateFilledCircleImage(diameter: avatarSize.width, color: .white)
            
            self.avatarBorderNode = ASImageNode()
            self.avatarBorderNode?.displaysAsynchronously = false
            self.avatarBorderNode?.image = generateCircleImage(diameter: avatarSize.width, lineWidth: 1.0 - UIScreenPixel, color: .red)
        } else {
            self.avatarNode = nil
            self.avatarBorderNode = nil
        }
        
        self.bubbleNode = ASImageNode()
        self.bubbleNode.displaysAsynchronously = false
        self.bubbleNode.image = bubbleImage
        
        self.bubbleBorderNode = ASImageNode()
        self.bubbleBorderNode.displaysAsynchronously = false
        self.bubbleBorderNode.image = bubbleBorderImage
    }
    
    func setup(maskNode: ASDisplayNode, borderMaskNode: ASDisplayNode) {
        if let avatarNode = self.avatarNode, let avatarBorderNode = self.avatarBorderNode {
            maskNode.addSubnode(avatarNode)
            borderMaskNode.addSubnode(avatarBorderNode)
        }
        maskNode.addSubnode(self.bubbleNode)
        borderMaskNode.addSubnode(self.bubbleBorderNode)
    }
    
    func animateWith(_ listItemNode: ListViewItemNode, transition: ContainedViewLayoutTransition) {
        if let bubbleItemNode = listItemNode as? ChatMessageBubbleItemNode {
            bubbleItemNode.animateFromLoadingPlaceholder(messageContainer: self, transition: transition)
        } else if let stickerItemNode = listItemNode as? ChatMessageAnimatedStickerItemNode {
            stickerItemNode.animateFromLoadingPlaceholder(messageContainer: self, transition: transition)
        }
    }
    
    func animateBackgroundFrame(to frame: CGRect, transition: ContainedViewLayoutTransition) {
        let targetFrame = CGRect(origin: CGPoint(x: self.bubbleNode.frame.minX, y: frame.minY), size: frame.size)
        
        transition.updateFrame(node: self.bubbleNode, frame: targetFrame)
        transition.updateFrame(node: self.bubbleBorderNode, frame: targetFrame)
        
        if let avatarNode = self.avatarNode, let avatarBorderNode = self.avatarBorderNode {
            let avatarFrame = CGRect(origin: CGPoint(x: 3.0, y: frame.maxY + 1.0 - avatarSize.height), size: avatarSize)
            
            transition.updateFrame(node: avatarNode, frame: avatarFrame)
            transition.updateFrame(node: avatarBorderNode, frame: avatarFrame)
        }
    }
    
    func update(size: CGSize, rect: CGRect, transition: ContainedViewLayoutTransition) {
        var avatarOffset: CGFloat = 0.0
        if let avatarNode = self.avatarNode, let avatarBorderNode = self.avatarBorderNode {
            let avatarFrame = CGRect(origin: CGPoint(x: 3.0, y: rect.maxY + 1.0 - avatarSize.height), size: avatarSize)

            transition.updateFrame(node: avatarNode, frame: avatarFrame)
            transition.updateFrame(node: avatarBorderNode, frame: avatarFrame)
            
            avatarOffset += avatarSize.width - 1.0
        }
        
        let bubbleFrame = CGRect(origin: CGPoint(x: 3.0 + avatarOffset, y: rect.origin.y), size: CGSize(width: rect.width, height: rect.height))
        transition.updateFrame(node: self.bubbleNode, frame: bubbleFrame)
        transition.updateFrame(node: self.bubbleBorderNode, frame: bubbleFrame)
    }
}

final class ChatLoadingPlaceholderNode: ASDisplayNode {
    private weak var backgroundNode: WallpaperBackgroundNode?
    
    private let maskNode: ASDisplayNode
    private let borderMaskNode: ASDisplayNode
    
    private let containerNode: ASDisplayNode
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private let backgroundColorNode: ASDisplayNode
    private let effectNode: ShimmerEffectForegroundNode
    
    private let borderNode: ASDisplayNode
    private let borderEffectNode: ShimmerEffectForegroundNode
    
    private let messageContainers: [ChatLoadingPlaceholderMessageContainer]
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var validLayout: (CGSize, UIEdgeInsets)?
    
    init(theme: PresentationTheme, chatWallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners, backgroundNode: WallpaperBackgroundNode, hasAvatar: Bool) {
        self.backgroundNode = backgroundNode
        self.maskNode = ASDisplayNode()
        self.borderMaskNode = ASDisplayNode()
                
        let bubbleImage = messageBubbleImage(maxCornerRadius: bubbleCorners.mainRadius, minCornerRadius: bubbleCorners.auxiliaryRadius, incoming: true, fillColor: .white, strokeColor: .clear, neighbors: .none, theme: theme.chat, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
        let bubbleBorderImage = messageBubbleImage(maxCornerRadius: bubbleCorners.mainRadius, minCornerRadius: bubbleCorners.auxiliaryRadius, incoming: true, fillColor: .clear, strokeColor: .red, neighbors: .none, theme: theme.chat, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true, onlyOutline: true)
        
        var messageContainers: [ChatLoadingPlaceholderMessageContainer] = []
        for _ in 0 ..< 8 {
            let container = ChatLoadingPlaceholderMessageContainer(hasAvatar: hasAvatar, bubbleImage: bubbleImage, bubbleBorderImage: bubbleBorderImage)
            container.setup(maskNode: self.maskNode, borderMaskNode: self.borderMaskNode)
            messageContainers.append(container)
        }
        self.messageContainers = messageContainers
        
        self.containerNode = ASDisplayNode()
        self.borderNode = ASDisplayNode()
        
        self.backgroundColorNode = ASDisplayNode()
        self.backgroundColorNode.backgroundColor = selectDateFillStaticColor(theme: theme, wallpaper: chatWallpaper)
        
        self.effectNode = ShimmerEffectForegroundNode()
        self.effectNode.layer.compositingFilter = "screenBlendMode"
        
        self.borderEffectNode = ShimmerEffectForegroundNode()
        self.borderEffectNode.layer.compositingFilter = "screenBlendMode"
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundColorNode)
        self.containerNode.addSubnode(self.effectNode)
        
        self.addSubnode(self.borderNode)
        self.borderNode.addSubnode(self.borderEffectNode)
//        self.addSubnode(self.maskNode)
//        self.addSubnode(self.borderMaskNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.containerNode.view.mask = self.maskNode.view
        self.borderNode.view.mask = self.borderMaskNode.view
        
//        self.backgroundNode?.updateIsLooping(true)
    }
    
    func animateOut(_ historyNode: ChatHistoryNode) {
        guard let listNode = historyNode as? ListView, let (size, _) = self.validLayout else {
            return
        }
        
        self.backgroundNode?.updateIsLooping(false)
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
        
        var lastFrame: CGRect?
        
        var i = 0
        listNode.forEachVisibleItemNode { itemNode in
            guard i < self.messageContainers.count, let listItemNode = itemNode as? ListViewItemNode else {
                return
            }
            
            if let bubbleItemNode = itemNode as? ChatMessageBubbleItemNode,
                bubbleItemNode.contentNodes.contains(where: { $0 is ChatMessageActionBubbleContentNode }) {
                return
            }
            
            let messageContainer = self.messageContainers[i]
            messageContainer.animateWith(listItemNode, transition: transition)
            
            lastFrame = messageContainer.frame
            
            i += 1
        }
        
        if let lastFrame = lastFrame, i < self.messageContainers.count {
            var offset = lastFrame.minY
            for k in i ..< self.messageContainers.count {
                let messageContainer = self.messageContainers[k]
                let messageSize = messageContainer.frame.size
                
                messageContainer.update(size: size, rect: CGRect(origin: CGPoint(x: 0.0, y: offset - messageSize.height), size: messageSize), transition: transition)
                offset -= messageSize.height
            }
        }
    }
    
    public func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets)
        
        let bounds = CGRect(origin: .zero, size: size)
        
        transition.updateFrame(node: self.maskNode, frame: bounds)
        transition.updateFrame(node: self.borderMaskNode, frame: bounds)
        transition.updateFrame(node: self.containerNode, frame: bounds)
        transition.updateFrame(node: self.borderNode, frame: bounds)
        
        transition.updateFrame(node: self.backgroundColorNode, frame: bounds)
        
        transition.updateFrame(node: self.effectNode, frame: bounds)
        transition.updateFrame(node: self.borderEffectNode, frame: bounds)
        
        self.effectNode.updateAbsoluteRect(bounds, within: bounds.size)
        self.borderEffectNode.updateAbsoluteRect(bounds, within: bounds.size)
        
        self.effectNode.update(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.15), horizontal: true, effectSize: 280.0, globalTimeOffset: false, duration: 1.6)
        self.borderEffectNode.update(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.45), horizontal: true, effectSize: 320.0, globalTimeOffset: false, duration: 1.6)
        
        let shortHeight: CGFloat = 71.0
        let tallHeight: CGFloat = 93.0
        
        let dimensions: [CGSize] = [
            CGSize(width: floorToScreenPixels(0.47 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.57 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.73 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.47 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.57 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.36 * size.width), height: shortHeight),
            CGSize(width: floorToScreenPixels(0.47 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.57 * size.width), height: tallHeight),
        ]
        
        var offset: CGFloat = 5.0
        var i = 0
        for messageContainer in self.messageContainers {
            let messageSize = dimensions[i % 12]
            messageContainer.update(size: size, rect: CGRect(origin: CGPoint(x: 0.0, y: size.height - insets.bottom - offset - messageSize.height), size: messageSize), transition: transition)
            offset += messageSize.height
            i += 1
        }
        
        if backgroundNode?.hasExtraBubbleBackground() == true {
            self.backgroundColorNode.isHidden = true
        } else {
            self.backgroundColorNode.isHidden = false
        }
        
        if let backgroundNode = self.backgroundNode, let backgroundContent = backgroundNode.makeBubbleBackground(for: .free) {
            if self.backgroundContent == nil {
                self.backgroundContent = backgroundContent
                self.containerNode.insertSubnode(backgroundContent, at: 0)
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let backgroundContent = self.backgroundContent {
            transition.updateFrame(node: backgroundContent, frame: bounds)
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
            }
        }
    }
}
