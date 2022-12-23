import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import WallpaperBackgroundNode
import ShimmerEffect
import ChatPresentationInterfaceState

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
private let avatarImage = generateFilledCircleImage(diameter: avatarSize.width, color: .white)
private let avatarBorderImage = generateCircleImage(diameter: avatarSize.width, lineWidth: 1.0 - UIScreenPixel, color: .white)

final class ChatLoadingPlaceholderMessageContainer {
    var avatarNode: ASImageNode?
    var avatarBorderNode: ASImageNode?
    
    let bubbleNode: ASImageNode
    let bubbleBorderNode: ASImageNode
    
    var parentView: UIView? {
        return self.bubbleNode.supernode?.view
    }
    
    var frame: CGRect {
        return self.bubbleNode.frame
    }
        
    init(bubbleImage: UIImage?, bubbleBorderImage: UIImage?) {
        self.bubbleNode = ASImageNode()
        self.bubbleNode.displaysAsynchronously = false
        self.bubbleNode.image = bubbleImage
        
        self.bubbleBorderNode = ASImageNode()
        self.bubbleBorderNode.displaysAsynchronously = false
        self.bubbleBorderNode.image = bubbleBorderImage
    }
    
    func setup(maskNode: ASDisplayNode, borderMaskNode: ASDisplayNode) {
        maskNode.addSubnode(self.bubbleNode)
        borderMaskNode.addSubnode(self.bubbleBorderNode)
    }
    
    func animateWith(_ listItemNode: ListViewItemNode, delay: Double, transition: ContainedViewLayoutTransition) {
        listItemNode.allowsGroupOpacity = true
        listItemNode.alpha = 1.0
        listItemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay, completion: { _ in
            listItemNode.allowsGroupOpacity = false
        })
        
        if let bubbleItemNode = listItemNode as? ChatMessageBubbleItemNode {
            bubbleItemNode.animateFromLoadingPlaceholder(messageContainer: self, delay: delay, transition: transition)
        } else if let stickerItemNode = listItemNode as? ChatMessageStickerItemNode {
            stickerItemNode.animateFromLoadingPlaceholder(messageContainer: self, delay: delay, transition: transition)
        } else if let stickerItemNode = listItemNode as? ChatMessageAnimatedStickerItemNode {
            stickerItemNode.animateFromLoadingPlaceholder(messageContainer: self, delay: delay, transition: transition)
        } else if let videoItemNode = listItemNode as? ChatMessageInstantVideoItemNode {
            videoItemNode.animateFromLoadingPlaceholder(messageContainer: self, delay: delay, transition: transition)
        }
    }
        
    func update(size: CGSize, hasAvatar: Bool, rect: CGRect, transition: ContainedViewLayoutTransition) {
        var avatarOffset: CGFloat = 0.0
        
        if hasAvatar && self.avatarNode == nil {
            let avatarNode = ASImageNode()
            avatarNode.displaysAsynchronously = false
            avatarNode.image = avatarImage
            self.bubbleNode.supernode?.addSubnode(avatarNode)
            self.avatarNode = avatarNode
            
            let avatarBorderNode = ASImageNode()
            avatarBorderNode.displaysAsynchronously = false
            avatarBorderNode.image = avatarBorderImage
            self.bubbleBorderNode.supernode?.addSubnode(avatarBorderNode)
            self.avatarBorderNode = avatarBorderNode
        }
        
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
    
    init(theme: PresentationTheme, chatWallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners, backgroundNode: WallpaperBackgroundNode) {
        self.backgroundNode = backgroundNode
        
        self.maskNode = ASDisplayNode()
        self.borderMaskNode = ASDisplayNode()
                
        let bubbleImage = messageBubbleImage(maxCornerRadius: bubbleCorners.mainRadius, minCornerRadius: bubbleCorners.auxiliaryRadius, incoming: true, fillColor: .white, strokeColor: .clear, neighbors: .none, theme: theme.chat, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
        let bubbleBorderImage = messageBubbleImage(maxCornerRadius: bubbleCorners.mainRadius, minCornerRadius: bubbleCorners.auxiliaryRadius, incoming: true, fillColor: .clear, strokeColor: .red, neighbors: .none, theme: theme.chat, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true, onlyOutline: true)
        
        var messageContainers: [ChatLoadingPlaceholderMessageContainer] = []
        for _ in 0 ..< 11 {
            let container = ChatLoadingPlaceholderMessageContainer(bubbleImage: bubbleImage, bubbleBorderImage: bubbleBorderImage)
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
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.containerNode.view.mask = self.maskNode.view
        self.borderNode.view.mask = self.borderMaskNode.view
        
        self.backgroundNode?.updateIsLooping(true)
    }
    
    private var bottomInset: (Int, CGFloat)?
    func setup(_ historyNode: ChatHistoryNode, updating: Bool = false) {
        guard let listNode = historyNode as? ListView else {
            return
        }
        
        var listItemNodes: [ASDisplayNode] = []
        var count = 0
        var inset: CGFloat = 0.0
        listNode.forEachVisibleItemNode { itemNode in
            inset += itemNode.frame.height
            count += 1
            
            listItemNodes.append(itemNode)
        }
        
        
        if updating {
            let heightNorm = listNode.bounds.height - listNode.insets.top
            listNode.forEachItemHeaderNode { itemNode in
                var animateScale = true
                if itemNode is ChatMessageAvatarHeaderNode {
                    animateScale = false
                }
                
                let delayFactor = itemNode.frame.minY / heightNorm
                let delay = Double(delayFactor * 0.2)
                
                itemNode.allowsGroupOpacity = true
                itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay, completion: { [weak itemNode] _ in
                    itemNode?.allowsGroupOpacity = false
                })
                if animateScale {
                    itemNode.layer.animateScale(from: 0.94, to: 1.0, duration: 0.4, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        }
        
        if count > 0 {
            self.bottomInset = (count, inset)
        }
        
        if updating {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
            transition.animateOffsetAdditive(node: self.maskNode, offset: -inset)
            transition.animateOffsetAdditive(node: self.borderMaskNode, offset: -inset)
            
            for listItemNode in listItemNodes {
                var incoming = false
                if let itemNode = listItemNode as? ChatMessageItemView, let item = itemNode.item, item.message.effectivelyIncoming(item.context.account.peerId) {
                    incoming = true
                }
                
                transition.animatePositionAdditive(node: listItemNode, offset: CGPoint(x: incoming ? 30.0 : -30.0, y: -30.0))
                transition.animateTransformScale(node: listItemNode, from: CGPoint(x: 0.85, y: 0.85))
                
                listItemNode.allowsGroupOpacity = true
                listItemNode.alpha = 1.0
                listItemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { _ in
                    listItemNode.allowsGroupOpacity = false
                })
            }
        }
        
        self.maskNode.bounds = self.maskNode.bounds.offsetBy(dx: 0.0, dy: inset)
        self.borderMaskNode.bounds = self.borderMaskNode.bounds.offsetBy(dx: 0.0, dy: inset)
    }
        
    func animateOut(_ historyNode: ChatHistoryNode, completion: @escaping () -> Void = {}) {
        guard let listNode = historyNode as? ListView, let (size, _) = self.validLayout else {
            return
        }
        
        self.backgroundNode?.updateIsLooping(false)
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
        
        var lastFrame: CGRect?
        
        let heightNorm = listNode.bounds.height - listNode.insets.top
        
        var index = 0
        var skipCount = self.bottomInset?.0 ?? 0
        listNode.forEachVisibleItemNode { itemNode in
            guard index < self.messageContainers.count, let listItemNode = itemNode as? ListViewItemNode else {
                return
            }
        
            let delayFactor = listItemNode.frame.minY / heightNorm
            let delay = Double(delayFactor * 0.1)
            
            if skipCount > 0 {
                skipCount -= 1
                return
            }
            
            if let itemNode = itemNode as? ChatUnreadItemNode {
                itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: 0.0)
                return
            }
            if let itemNode = itemNode as? ChatReplyCountItemNode {
                itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: 0.0)
                return
            }
            
            let messageContainer = self.messageContainers[index]
            messageContainer.animateWith(listItemNode, delay: delay, transition: transition)
            
            lastFrame = messageContainer.frame
            
            index += 1
        }
        
        skipCount = self.bottomInset?.0 ?? 0
        listNode.forEachItemHeaderNode { itemNode in
            var animateScale = true
            if itemNode is ChatMessageAvatarHeaderNode {
                animateScale = false
                if skipCount > 0 {
                    return
                }
            }
            if itemNode is ChatMessageDateHeaderNode {
                if skipCount > 0 {
                    skipCount -= 1
                    return
                }
            }
            
            let delayFactor = itemNode.frame.minY / heightNorm
            let delay = Double(delayFactor * 0.2)

            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
            if animateScale {
                itemNode.layer.animateScale(from: 0.94, to: 1.0, duration: 0.4, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
            }
        }
        
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
            completion()
        })
        
        if let lastFrame = lastFrame, index < self.messageContainers.count {
            var offset = lastFrame.minY
            for k in index ..< self.messageContainers.count {
                let messageContainer = self.messageContainers[k]
                let messageSize = messageContainer.frame.size
                
                messageContainer.update(size: size, hasAvatar: self.chatType != .channel, rect: CGRect(origin: CGPoint(x: 0.0, y: offset - messageSize.height), size: messageSize), transition: transition)
                offset -= messageSize.height
            }
        }
    }
    
    func addContentOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.maskNode.bounds = self.maskNode.bounds.offsetBy(dx: 0.0, dy: -offset)
        self.borderMaskNode.bounds = self.borderMaskNode.bounds.offsetBy(dx: 0.0, dy: -offset)
        transition.animateOffsetAdditive(node: self.maskNode, offset: offset)
        transition.animateOffsetAdditive(node: self.borderMaskNode, offset: offset)
        if let (rect, containerSize) = self.absolutePosition {
            self.update(rect: rect, within: containerSize)
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition = .immediate) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
        }
    }
    
    enum ChatType: Equatable {
        case generic
        case group
        case channel
    }
    private var chatType: ChatType = .channel
    func updatePresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState) {
        var chatType: ChatType = .channel
        if let peer = chatPresentationInterfaceState.renderedPeer?.peer {
            if peer is TelegramGroup {
                chatType = .group
            } else if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    chatType = .group
                } else {
                    chatType = .channel
                }
            }
        }
        
        if self.chatType != chatType {
            self.chatType = chatType
            if let (size, insets) = self.validLayout {
                self.updateLayout(size: size, insets: insets, transition: .immediate)
            }
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
        
        self.effectNode.update(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.14), horizontal: true, effectSize: 280.0, globalTimeOffset: false, duration: 1.6)
        self.borderEffectNode.update(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.35), horizontal: true, effectSize: 320.0, globalTimeOffset: false, duration: 1.6)
        
        let shortHeight: CGFloat = 71.0
        let tallHeight: CGFloat = 93.0

        let dimensions: [CGSize] = [
            CGSize(width: floorToScreenPixels(0.47 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.58 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.69 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.47 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.58 * size.width), height: shortHeight),
            CGSize(width: floorToScreenPixels(0.36 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.47 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.36 * size.width), height: shortHeight),
            CGSize(width: floorToScreenPixels(0.58 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.69 * size.width), height: tallHeight),
            CGSize(width: floorToScreenPixels(0.58 * size.width), height: tallHeight),
        ].map {
            if self.chatType == .channel {
                return CGSize(width: floor($0.width * 1.3), height: floor($0.height * 1.8))
            } else {
                return $0
            }
        }
                
        var offset: CGFloat = 5.0
        var index = 0
        
        for messageContainer in self.messageContainers {
            let messageSize = dimensions[index % 11]
            messageContainer.update(size: bounds.size, hasAvatar: self.chatType != .channel, rect: CGRect(origin: CGPoint(x: 0.0, y: bounds.size.height - insets.bottom - offset - messageSize.height), size: messageSize), transition: transition)
            offset += messageSize.height
            index += 1
        }
        
        if self.backgroundNode?.hasExtraBubbleBackground() == true {
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
                self.update(rect: rect, within: containerSize)
            }
        }
    }
}
