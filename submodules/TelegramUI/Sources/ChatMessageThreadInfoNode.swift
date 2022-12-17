import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting
import TextFormat
import InvisibleInkDustNode
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import EmojiStatusComponent
import WallpaperBackgroundNode
import ChatControllerInteraction

private func generateRectsImage(color: UIColor, rects: [CGRect], inset: CGFloat, outerRadius: CGFloat, innerRadius: CGFloat) -> (CGPoint, UIImage?) {
    enum CornerType {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    func drawFullCorner(context: CGContext, color: UIColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
        if radius.isZero {
            return
        }
        context.setFillColor(color.cgColor)
        switch type {
        case .topLeft:
            context.clear(CGRect(origin: point, size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: point, size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .topRight:
            context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomLeft:
            context.clear(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomRight:
            context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        }
    }

    func drawConnectingCorner(context: CGContext, color: UIColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
        context.setFillColor(color.cgColor)
        switch type {
        case .topLeft:
            context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .topRight:
            context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomLeft:
            context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        case .bottomRight:
            context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
        }
    }
    
    if rects.isEmpty {
        return (CGPoint(), nil)
    }
    
    var topLeft = rects[0].origin
    var bottomRight = CGPoint(x: rects[0].maxX, y: rects[0].maxY)
    for i in 1 ..< rects.count {
        topLeft.x = min(topLeft.x, rects[i].origin.x)
        topLeft.y = min(topLeft.y, rects[i].origin.y)
        bottomRight.x = max(bottomRight.x, rects[i].maxX)
        bottomRight.y = max(bottomRight.y, rects[i].maxY)
    }
    
    topLeft.x -= inset
    topLeft.y -= inset
    bottomRight.x += inset * 2.0
    bottomRight.y += inset * 2.0
    
    return (topLeft, generateImage(CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        
        context.setBlendMode(.copy)
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset)
            context.fill(rect.offsetBy(dx: -topLeft.x, dy: -topLeft.y))
        }
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            
            var previous: CGRect?
            if i != 0 {
                previous = rects[i - 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            var next: CGRect?
            if i != rects.count - 1 {
                next = rects[i + 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            if let previous = previous {
                if previous.contains(rect.topLeft) {
                    if abs(rect.topLeft.x - previous.minX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topLeft.x, y: previous.maxY), type: .topLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                }
                if previous.contains(rect.topRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.topRight.x - previous.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topRight.x, y: previous.maxY), type: .topRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
            }
            
            if let next = next {
                if next.contains(rect.bottomLeft) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomLeft.x, y: next.minY), type: .bottomLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                }
                if next.contains(rect.bottomRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomRight.x, y: next.minY), type: .bottomRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
            }
        }
    }))
}

enum ChatMessageThreadInfoType {
    case bubble(incoming: Bool)
    case standalone
}

class ChatMessageThreadInfoNode: ASDisplayNode {
    class Arguments {
        let presentationData: ChatPresentationData
        let strings: PresentationStrings
        let context: AccountContext
        let controllerInteraction: ChatControllerInteraction
        let type: ChatMessageThreadInfoType
        let threadId: Int64
        let parentMessage: Message
        let constrainedSize: CGSize
        let animationCache: AnimationCache?
        let animationRenderer: MultiAnimationRenderer?
        
        init(
            presentationData: ChatPresentationData,
            strings: PresentationStrings,
            context: AccountContext,
            controllerInteraction: ChatControllerInteraction,
            type: ChatMessageThreadInfoType,
            threadId: Int64,
            parentMessage: Message,
            constrainedSize: CGSize,
            animationCache: AnimationCache?,
            animationRenderer: MultiAnimationRenderer?
        ) {
            self.presentationData = presentationData
            self.strings = strings
            self.context = context
            self.controllerInteraction = controllerInteraction
            self.type = type
            self.threadId = threadId
            self.parentMessage = parentMessage
            self.constrainedSize = constrainedSize
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
        }
    }
    
    var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.textNode?.visibilityRect = self.visibility ? CGRect.infinite : nil
                
                if let titleTopicIconView = self.titleTopicIconView, let titleTopicIconComponent = self.titleTopicIconComponent {
                    let _ = titleTopicIconView.update(
                        transition: .immediate,
                        component: AnyComponent(titleTopicIconComponent.withVisibleForAnimations(self.visibility)),
                        environment: {},
                        containerSize: titleTopicIconView.bounds.size
                    )
                }
            }
        }
    }
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private var backgroundNode: NavigationBackgroundNode?
    
    private let contentNode: HighlightTrackingButtonNode
    private let contentBackgroundNode: ASImageNode
    private var textNode: TextNodeWithEntities?
    private let arrowNode: ASImageNode
    
    private var titleTopicIconView: ComponentHostView<Empty>?
    private var titleTopicIconComponent: EmojiStatusComponent?
    
    private var lineRects: [CGRect] = []
    
    private var pressed = { }
    
    private var absolutePosition: (CGRect, CGSize)?
    
    override init() {
        self.contentNode = HighlightTrackingButtonNode()
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.alpha = 0.1
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.isLayerBacked = true
        self.contentBackgroundNode.isUserInteractionEnabled = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.isLayerBacked = true
        self.arrowNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.contentNode.isUserInteractionEnabled = true
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.contentBackgroundNode)
        self.contentNode.addSubnode(self.arrowNode)
        
        self.contentNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted, !strongSelf.frame.width.isZero {
                    let scale = (strongSelf.frame.width - 10.0) / strongSelf.frame.width
                    
                    strongSelf.contentNode.layer.animateScale(from: 1.0, to: scale, duration: 0.15, removeOnCompletion: false)
                    
                    strongSelf.contentBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.contentBackgroundNode.alpha = 0.2
                } else if let presentationLayer = strongSelf.contentNode.layer.presentation() {
                    strongSelf.contentNode.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    
                    strongSelf.contentBackgroundNode.alpha = 0.1
                    strongSelf.contentBackgroundNode.layer.animateAlpha(from: 0.2, to: 0.1, duration: 0.2)
                }
            }
        }
        
        self.contentNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageThreadInfoNode?) -> (_ arguments: Arguments) -> (CGSize, (Bool) -> ChatMessageThreadInfoNode) {
        let textNodeLayout = TextNodeWithEntities.asyncLayout(maybeNode?.textNode)
    
        return { arguments in
            let fontSize = floor(arguments.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let textFont = Font.medium(fontSize)
                        
            var topicTitle = ""
            var topicIconId: Int64?
            var topicIconColor: Int32 = 0
            if let _ = arguments.parentMessage.threadId, let channel = arguments.parentMessage.peers[arguments.parentMessage.id.peerId] as? TelegramChannel, channel.flags.contains(.isForum), let threadInfo = arguments.parentMessage.associatedThreadInfo {
                topicTitle = threadInfo.title
                topicIconId = threadInfo.icon
                topicIconColor = threadInfo.iconColor
            }
            
            let backgroundColor: UIColor
            let textColor: UIColor
            let arrowIcon: UIImage?
            let generalThreadIcon: UIImage?
            switch arguments.type {
            case let .bubble(incoming):
                if topicIconId == nil, topicIconColor != 0, incoming, arguments.threadId != 1 {
                    let colors = topicIconColors(for: topicIconColor)
                    backgroundColor = UIColor(rgb: colors.0.last ?? 0x000000)
                    textColor = UIColor(rgb: colors.1.first ?? 0x000000)
                    arrowIcon = PresentationResourcesChat.chatBubbleArrowImage(color: textColor.withAlphaComponent(0.3))
                } else {
                    if incoming {
                        backgroundColor = arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor
                        textColor = arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor
                        arrowIcon = PresentationResourcesChat.chatBubbleArrowIncomingImage(arguments.presentationData.theme.theme)
                    } else {
                        backgroundColor = arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                        textColor = arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                        arrowIcon = PresentationResourcesChat.chatBubbleArrowOutgoingImage(arguments.presentationData.theme.theme)
                    }
                }
                generalThreadIcon = incoming ? PresentationResourcesChat.chatGeneralThreadIncomingIcon(arguments.presentationData.theme.theme) : PresentationResourcesChat.chatGeneralThreadOutgoingIcon(arguments.presentationData.theme.theme)
            case .standalone:
                textColor = arguments.presentationData.theme.theme.chat.message.mediaOverlayControlColors.foregroundColor
                backgroundColor = .white
                arrowIcon = PresentationResourcesChat.chatBubbleArrowFreeImage(arguments.presentationData.theme.theme)
                generalThreadIcon = PresentationResourcesChat.chatGeneralThreadFreeIcon(arguments.presentationData.theme.theme)
            }
            
            let placeholderColor: UIColor = arguments.parentMessage.effectivelyIncoming(arguments.context.account.peerId) ? arguments.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : arguments.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
            
            let text = NSAttributedString(string: topicTitle, font: textFont, textColor: textColor)
                         
            let lineInset: CGFloat = 7.0
            let fillInset: CGFloat = 5.0
            let iconSize = CGSize(width: 22.0, height: 22.0)
            let insets = UIEdgeInsets(top: 2.0, left: 4.0, bottom: 2.0, right: 4.0)
            let spacing: CGFloat = 4.0
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: arguments.constrainedSize.width - insets.left - insets.right - iconSize.width - spacing, height: arguments.constrainedSize.height), alignment: .natural, cutout: nil, insets: .zero))
            
            var lineRects = textLayout.linesRects().map { rect in
                return CGRect(origin: rect.origin.offsetBy(dx: insets.left, dy: 0.0), size: CGSize(width: rect.width + iconSize.width + spacing + 3.0, height: rect.size.height))
            }
            var outerRadius: CGFloat = 13.0
            let innerRadius: CGFloat = 8.0
            
            var firstLineMidY: CGFloat?
            if lineRects.count > 0 {
                if let firstLine = lineRects.first {
                    firstLineMidY = firstLine.midY - firstLine.minY
                    outerRadius = min(floorToScreenPixels((firstLine.height + fillInset * 2.0) / 2.0), outerRadius)
                }
                let lastRect = lineRects[lineRects.count - 1]
                lineRects[lineRects.count - 1] = CGRect(origin: lastRect.origin, size: CGSize(width: lastRect.width + 11.0, height: lastRect.height))
            }
            
            let size = CGSize(width: insets.left + iconSize.width + spacing + textLayout.size.width + insets.right + lineInset * 2.0, height: insets.top + textLayout.size.height + insets.bottom)
            
            return (size, { attemptSynchronous in
                let node: ChatMessageThreadInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageThreadInfoNode()
                }
                
                node.pressed = {
                    arguments.controllerInteraction.navigateToThreadMessage(arguments.parentMessage.id.peerId, arguments.threadId, arguments.parentMessage.id)
                }
                                
                if node.lineRects != lineRects {
                    let (_, image) = generateRectsImage(color: backgroundColor, rects: lineRects, inset: fillInset, outerRadius: outerRadius, innerRadius: innerRadius)
                    if let image = image {
                        if case .standalone = arguments.type {
                            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -3.0), size: CGSize(width: size.width + fillInset, height: size.height + fillInset * 2.0))
                            
                            if arguments.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                                if node.backgroundContent == nil, let backgroundContent = arguments.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                    backgroundContent.clipsToBounds = true
                                    backgroundContent.isUserInteractionEnabled = false
                                    node.backgroundContent = backgroundContent
                                    node.contentNode.insertSubnode(backgroundContent, at: 0)
                                    
                                    let backgroundMask = UIImageView(image: image)
                                    backgroundContent.view.mask = backgroundMask
                                }
                                                                
                                if let backgroundContent = node.backgroundContent {
                                    backgroundContent.view.mask?.bounds = CGRect(origin: .zero, size: image.size)
                                    (backgroundContent.view.mask as? UIImageView)?.image = image
                                    
                                    backgroundContent.frame = backgroundFrame
                                    if let (rect, containerSize) = node.absolutePosition {
                                        var backgroundFrame = backgroundContent.frame
                                        backgroundFrame.origin.x += rect.minX
                                        backgroundFrame.origin.y += rect.minY
                                        backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                                    }
                                }
                            } else {
                                node.backgroundContent?.removeFromSupernode()
                                node.backgroundContent = nil
                                
                                let backgroundNode: NavigationBackgroundNode
                                if let current = node.backgroundNode {
                                    backgroundNode = current
                                } else {
                                    backgroundNode = NavigationBackgroundNode(color: .clear)
                                    backgroundNode.isUserInteractionEnabled = false
                                    node.backgroundNode = backgroundNode
                                    node.contentNode.insertSubnode(backgroundNode, at: 0)
                                    
                                    let backgroundMask = UIImageView(image: image)
                                    backgroundNode.view.mask = backgroundMask
                                }
                                
                                backgroundNode.view.mask?.bounds = CGRect(origin: .zero, size: image.size)
                                (backgroundNode.view.mask as? UIImageView)?.image = image
                                
                                backgroundNode.frame = backgroundFrame
                                backgroundNode.update(size: backgroundNode.bounds.size, cornerRadius: 0.0, transition: .immediate)
                                backgroundNode.updateColor(color: selectDateFillStaticColor(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper), transition: .immediate)
                            }
                        } else {
                            node.contentBackgroundNode.frame = CGRect(origin: CGPoint(x: -1.0, y: -3.0), size: image.size)
                            node.contentBackgroundNode.image = image
                        }
                    }
                }
                
                node.textNode?.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                var textArguments: TextNodeWithEntities.Arguments?
                if let cache = arguments.animationCache, let renderer = arguments.animationRenderer {
                    textArguments = TextNodeWithEntities.Arguments(context: arguments.context, cache: cache, renderer: renderer, placeholderColor: placeholderColor, attemptSynchronous: attemptSynchronous)
                }
                let textNode = textApply(textArguments)
                textNode.visibilityRect = node.visibility ? CGRect.infinite : nil
                
                if node.textNode == nil {
                    textNode.textNode.isUserInteractionEnabled = false
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode.textNode)
                }
                
                let titleTopicIconView: ComponentHostView<Empty>
                if let current = node.titleTopicIconView {
                    titleTopicIconView = current
                } else {
                    titleTopicIconView = ComponentHostView<Empty>()
                    node.titleTopicIconView = titleTopicIconView
                    node.contentNode.view.addSubview(titleTopicIconView)
                }
                
                let titleTopicIconContent: EmojiStatusComponent.Content
                if arguments.threadId == 1 {
                    titleTopicIconContent = .image(image: generalThreadIcon)
                } else if let fileId = topicIconId, fileId != 0 {
                    titleTopicIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 36.0, height: 36.0), placeholderColor: arguments.presentationData.theme.theme.list.mediaPlaceholderColor, themeColor: arguments.presentationData.theme.theme.list.itemAccentColor, loopMode: .count(1))
                } else {
                    titleTopicIconContent = .topic(title: String(topicTitle.prefix(1)), color: topicIconColor, size: CGSize(width: 22.0, height: 22.0))
                }
                
                if let animationCache = arguments.animationCache, let animationRenderer = arguments.animationRenderer {
                    let titleTopicIconComponent = EmojiStatusComponent(
                        context: arguments.context,
                        animationCache: animationCache,
                        animationRenderer: animationRenderer,
                        content: titleTopicIconContent,
                        isVisibleForAnimations: node.visibility,
                        action: nil
                    )
                    node.titleTopicIconComponent = titleTopicIconComponent
                    
                    let iconSize = titleTopicIconView.update(
                        transition: .immediate,
                        component: AnyComponent(titleTopicIconComponent),
                        environment: {},
                        containerSize: CGSize(width: 22.0, height: 22.0)
                    )
                    
                    let iconY: CGFloat
                    if let firstLineMidY = firstLineMidY {
                        iconY = floorToScreenPixels(firstLineMidY - iconSize.height / 2.0)
                    } else {
                        iconY = 0.0
                    }
                    
                    titleTopicIconView.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top + iconY), size: iconSize)
                }

                let textFrame = CGRect(origin: CGPoint(x: iconSize.width + 2.0 + insets.left, y: insets.top), size: textLayout.size)
                textNode.textNode.frame = textFrame
                 
                if let arrowIcon = arrowIcon, let firstLine = lineRects.first, let lastLine = lineRects.last {
                    let lastRectMidY = lastLine.midY - firstLine.minY
                    
                    node.arrowNode.image = arrowIcon
                    node.arrowNode.frame = CGRect(origin: CGPoint(x: lastLine.maxX - arrowIcon.size.width - 1.0, y: insets.top + floorToScreenPixels(lastRectMidY - arrowIcon.size.height / 2.0) + UIScreenPixel), size: arrowIcon.size)
                }
                
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }
}
