import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import AvatarNode
import TelegramCore
import TelegramUniversalVideoContent
import UniversalMediaPlayer
import GalleryUI
import HierarchyTrackingLayer
import WallpaperBackgroundNode
import ChatControllerInteraction
import AvatarVideoNode
import ChatMessageItem
import AvatarNode
import ComponentFlow
import EmojiStatusComponent
import AppBundle

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

private let granularity: Int32 = 60 * 60 * 24

public final class ChatMessageDateHeader: ListViewItemHeader {
    public struct Id: Hashable {
        public let roundedTimestamp: Int64?
        public let separableThreadId: Int64?
        
        public init(roundedTimestamp: Int64?, separableThreadId: Int64?) {
            self.roundedTimestamp = roundedTimestamp
            self.separableThreadId = separableThreadId
        }
    }
    
    public final class HeaderData {
        public enum Contents {
            case peer(EnginePeer)
            case thread(id: Int64, info: Message.AssociatedThreadInfo)
        }
        
        public let contents: Contents
        
        public init(contents: Contents) {
            self.contents = contents
        }
    }
    
    private let timestamp: Int32
    private let roundedTimestamp: Int32
    private let scheduled: Bool
    public let displayHeader: HeaderData?
    
    public let id: ListViewItemNode.HeaderId
    public let stackingId: ListViewItemNode.HeaderId?
    public let idValue: Id
    public let presentationData: ChatPresentationData
    public let controllerInteraction: ChatControllerInteraction?
    public let context: AccountContext
    public let action: ((Int32, Bool) -> Void)?
    
    public init(timestamp: Int32, separableThreadId: Int64?, scheduled: Bool, displayHeader: HeaderData?, presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction?, context: AccountContext, action: ((Int32, Bool) -> Void)? = nil) {
        self.timestamp = timestamp
        self.scheduled = scheduled
        self.displayHeader = displayHeader
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        self.context = context
        self.action = action
        self.roundedTimestamp = dateHeaderTimestampId(timestamp: timestamp)
        if let _ = self.displayHeader {
            self.idValue = ChatMessageDateHeader.Id(roundedTimestamp: 0, separableThreadId: separableThreadId)
            self.id = ListViewItemNode.HeaderId(space: 3, id: self.idValue)
            self.stackingId = ListViewItemNode.HeaderId(space: 2, id: ChatMessageDateHeader.Id(roundedTimestamp: Int64(self.roundedTimestamp), separableThreadId: nil))
        } else {
            self.idValue = ChatMessageDateHeader.Id(roundedTimestamp: Int64(self.roundedTimestamp), separableThreadId: nil)
            self.id = ListViewItemNode.HeaderId(space: 2, id: self.idValue)
            self.stackingId = nil
        }
        
        let isRotated = controllerInteraction?.chatIsRotated ?? true
        
        self.stickDirection = isRotated ? .bottom : .top
    }
    
    public let stickDirection: ListViewItemHeaderStickDirection
    public let stickOverInsets: Bool = true
    
    public let height: CGFloat = 34.0

    public func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? ChatMessageDateHeader, other.id == self.id {
            return true
        } else {
            return false
        }
    }
    
    public func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
        return ChatMessageDateHeaderNodeImpl(localTimestamp: self.roundedTimestamp, scheduled: self.scheduled, displayHeader: self.displayHeader, presentationData: self.presentationData, controllerInteraction: self.controllerInteraction, context: self.context, action: self.action)
    }
    
    public func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        guard let node = node as? ChatMessageDateHeaderNodeImpl, let next = next as? ChatMessageDateHeader else {
            return
        }
        node.updatePresentationData(next.presentationData, context: next.context)
    }
}

private func monthAtIndex(_ index: Int, strings: PresentationStrings) -> String {
    switch index {
        case 0:
            return strings.Month_GenJanuary
        case 1:
            return strings.Month_GenFebruary
        case 2:
            return strings.Month_GenMarch
        case 3:
            return strings.Month_GenApril
        case 4:
            return strings.Month_GenMay
        case 5:
            return strings.Month_GenJune
        case 6:
            return strings.Month_GenJuly
        case 7:
            return strings.Month_GenAugust
        case 8:
            return strings.Month_GenSeptember
        case 9:
            return strings.Month_GenOctober
        case 10:
            return strings.Month_GenNovember
        case 11:
            return strings.Month_GenDecember
        default:
            return ""
    }
}

private func dateHeaderTimestampId(timestamp: Int32) -> Int32 {
    if timestamp == scheduleWhenOnlineTimestamp || timestamp >= Int32.max - 1000 {
        return timestamp
    } else if timestamp == Int32.max {
        return timestamp / (granularity) * (granularity)
    } else {
        return ((timestamp + timezoneOffset) / (granularity)) * (granularity)
    }
}

private final class ChatMessageDateSectionSeparatorNode: ASDisplayNode {
    private let controllerInteraction: ChatControllerInteraction?
    private let presentationData: ChatPresentationData
    
    public let backgroundNode: NavigationBackgroundNode
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private let patternLayer: SimpleShapeLayer
    
    init(
        controllerInteraction: ChatControllerInteraction?,
        presentationData: ChatPresentationData
    ) {
        self.controllerInteraction = controllerInteraction
        self.presentationData = presentationData
        
        if controllerInteraction?.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true, let backgroundContent = controllerInteraction?.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
            backgroundContent.clipsToBounds = true
            self.backgroundContent = backgroundContent
        }
                
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.patternLayer = SimpleShapeLayer()
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        if let backgroundContent = self.backgroundContent {
            self.addSubnode(backgroundContent)
            backgroundContent.layer.mask = self.patternLayer
        } else {
            self.addSubnode(self.backgroundNode)
            self.backgroundNode.layer.mask = self.patternLayer
        }
        
        let fullTranslucency: Bool = self.controllerInteraction?.enableFullTranslucency ?? true
        
        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: self.presentationData.theme.theme, wallpaper: self.presentationData.theme.wallpaper), enableBlur: fullTranslucency && dateFillNeedsBlur(theme: self.presentationData.theme.theme, wallpaper: self.presentationData.theme.wallpaper), transition: .immediate)
        
        self.patternLayer.lineWidth = 1.66
        self.patternLayer.strokeColor = UIColor.white.cgColor
        
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: 0.0, y: self.patternLayer.lineWidth * 0.5))
        linePath.addLine(to: CGPoint(x: 10000.0, y: self.patternLayer.lineWidth * 0.5))
        self.patternLayer.path = linePath
        self.patternLayer.lineDashPattern = [6.0 as NSNumber, 2.0 as NSNumber] as [NSNumber]
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 10.0))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(size: backgroundFrame.size, transition: transition)
        
        transition.updateFrame(layer: self.patternLayer, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 1.66)))
        
        if let backgroundContent = self.backgroundContent {
            backgroundContent.allowsGroupOpacity = true
            self.backgroundNode.isHidden = true
            
            transition.updateFrame(node: backgroundContent, frame: self.backgroundNode.frame)
            backgroundContent.cornerRadius = backgroundFrame.size.height / 2.0
            
            /*if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += containerSize.height - rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
            }*/
        }
    }
}

private final class ChatMessageDateContentNode: ASDisplayNode {
    private var presentationData: ChatPresentationData
    private let controllerInteraction: ChatControllerInteraction?
    
    public let labelNode: TextNode
    public let backgroundNode: NavigationBackgroundNode
    public let stickBackgroundNode: ASImageNode
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private var text: String
    
    init(presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction?, localTimestamp: Int32, scheduled: Bool) {
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = !presentationData.isPreview
        
        if controllerInteraction?.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true, let backgroundContent = controllerInteraction?.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
            backgroundContent.clipsToBounds = true
            self.backgroundContent = backgroundContent
        }
                
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.stickBackgroundNode = ASImageNode()
        self.stickBackgroundNode.isLayerBacked = true
        self.stickBackgroundNode.displayWithoutProcessing = true
        self.stickBackgroundNode.displaysAsynchronously = false
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(localTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        var text: String
        if timeinfo.tm_year == timeinfoNow.tm_year {
            if timeinfo.tm_yday == timeinfoNow.tm_yday {
                text = presentationData.strings.Weekday_Today
            } else {
                text = presentationData.strings.Date_ChatDateHeader(monthAtIndex(Int(timeinfo.tm_mon), strings: presentationData.strings), "\(timeinfo.tm_mday)").string
            }
        } else {
            text = presentationData.strings.Date_ChatDateHeaderYear(monthAtIndex(Int(timeinfo.tm_mon), strings: presentationData.strings), "\(timeinfo.tm_mday)", "\(1900 + timeinfo.tm_year)").string
        }
        
        if scheduled {
            if localTimestamp == scheduleWhenOnlineTimestamp {
                text = presentationData.strings.ScheduledMessages_ScheduledOnline
            } else if timeinfo.tm_year == timeinfoNow.tm_year && timeinfo.tm_yday == timeinfoNow.tm_yday {
                text = presentationData.strings.ScheduledMessages_ScheduledToday
            } else {
                text = presentationData.strings.ScheduledMessages_ScheduledDate(text).string
            }
        }
        self.text = text
        
        super.init()
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)

        let fullTranslucency: Bool = true
        
        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: fullTranslucency && dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
        self.stickBackgroundNode.image = graphics.dateFloatingBackground
        self.stickBackgroundNode.alpha = 0.0
        
        if let backgroundContent = self.backgroundContent {
            self.addSubnode(backgroundContent)
        } else {
            self.addSubnode(self.backgroundNode)
        }
        self.addSubnode(self.labelNode)
                
        let titleFont = Font.medium(min(18.0, floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)))
        
        let attributedString = NSAttributedString(string: text, font: titleFont, textColor: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper))
        let labelLayout = TextNode.asyncLayout(self.labelNode)
                
        let (size, apply) = labelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        self.labelNode.frame = CGRect(origin: CGPoint(), size: size.size)
    }
    
    func updatePresentationData(_ presentationData: ChatPresentationData, context: AccountContext) {
        let previousPresentationData = self.presentationData
        self.presentationData = presentationData
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
        
        let fullTranslucency: Bool = true

        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: fullTranslucency && dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
        self.stickBackgroundNode.image = graphics.dateFloatingBackground
        
        let titleFont = Font.medium(min(18.0, floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)))
        
        let attributedString = NSAttributedString(string: self.text, font: titleFont, textColor: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper))
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        
        let (size, apply) = labelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        
        if presentationData.fontSize != previousPresentationData.fontSize {
            self.labelNode.bounds = CGRect(origin: CGPoint(), size: size.size)
        }
    }
    
    func updateBackgroundColor(color: UIColor, enableBlur: Bool) {
        self.backgroundNode.updateColor(color: color, enableBlur: enableBlur, transition: .immediate)
    }
    
    func update(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let chatDateSize: CGFloat = 22.0
        let chatDateInset: CGFloat = 6.0
        
        let labelSize = self.labelNode.bounds.size
        let backgroundSize = CGSize(width: labelSize.width + chatDateInset * 2.0, height: chatDateSize)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: leftInset + floorToScreenPixels((size.width - leftInset - rightInset - backgroundSize.width) / 2.0), y: (size.height - chatDateSize) / 2.0), size: backgroundSize)
        
        transition.updateFrame(node: self.stickBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.size.height / 2.0, transition: transition)
        let labelFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + chatDateInset, y: backgroundFrame.origin.y + floorToScreenPixels((backgroundSize.height - labelSize.height) / 2.0)), size: labelSize)
        
        transition.updatePosition(node: self.labelNode, position: labelFrame.center)
        self.labelNode.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
                
        if let backgroundContent = self.backgroundContent {
            backgroundContent.allowsGroupOpacity = true
            self.backgroundNode.isHidden = true
            
            transition.updateFrame(node: backgroundContent, frame: self.backgroundNode.frame)
            backgroundContent.cornerRadius = backgroundFrame.size.height / 2.0
            
            /*if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += containerSize.height - rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
            }*/
        }
    }
    
    func updateStickDistanceFactor(_ factor: CGFloat, transition: ContainedViewLayoutTransition) {
        self.stickBackgroundNode.alpha = factor
    }
}

private final class ChatMessagePeerContentNode: ASDisplayNode {
    private static let arrowImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/HeaderArrow"), color: .white)!.withRenderingMode(.alwaysTemplate)
    
    private let context: AccountContext
    private var presentationData: ChatPresentationData
    private let controllerInteraction: ChatControllerInteraction?
    private let displayHeader: ChatMessageDateHeader.HeaderData
    
    private var avatarNode: AvatarNode?
    private var icon: ComponentView<Empty>?
    private var arrowIcon: UIImageView?
    
    public let labelNode: TextNode
    public let backgroundNode: NavigationBackgroundNode
    public let stickBackgroundNode: ASImageNode
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private var text: String
    
    init(context: AccountContext, presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction?, displayHeader: ChatMessageDateHeader.HeaderData) {
        self.context = context
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        self.displayHeader = displayHeader
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = !presentationData.isPreview
        
        if controllerInteraction?.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true, let backgroundContent = controllerInteraction?.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
            backgroundContent.clipsToBounds = true
            self.backgroundContent = backgroundContent
        }
                
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.stickBackgroundNode = ASImageNode()
        self.stickBackgroundNode.isLayerBacked = true
        self.stickBackgroundNode.displayWithoutProcessing = true
        self.stickBackgroundNode.displaysAsynchronously = false
        
        let text: String
        switch displayHeader.contents {
        case let .peer(peer):
            text = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        case let .thread(_, info):
            text = info.title
        }
        self.text = text
        
        super.init()
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)

        let fullTranslucency: Bool = true
        
        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: fullTranslucency && dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
        self.stickBackgroundNode.image = graphics.dateFloatingBackground
        self.stickBackgroundNode.alpha = 0.0
        
        if let backgroundContent = self.backgroundContent {
            self.addSubnode(backgroundContent)
        } else {
            self.addSubnode(self.backgroundNode)
        }
        
        switch displayHeader.contents {
        case let .peer(peer):
            let avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
            self.avatarNode = avatarNode
            self.addSubnode(avatarNode)
            
            if peer.smallProfileImage != nil {
                avatarNode.setPeerV2(context: context, theme: presentationData.theme.theme, peer: peer, displayDimensions: CGSize(width: 16.0, height: 16.0))
            } else {
                avatarNode.setPeer(context: context, theme: presentationData.theme.theme, peer: peer, displayDimensions: CGSize(width: 16.0, height: 16.0))
            }
        case let .thread(id, info):
            let avatarIconContent: EmojiStatusComponent.Content
            if id != 1 {
                if let fileId = info.icon, fileId != 0 {
                    avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 16.0, height: 16.0), placeholderColor: presentationData.theme.theme.list.mediaPlaceholderColor, themeColor: presentationData.theme.theme.list.itemAccentColor, loopMode: .count(0))
                } else {
                    avatarIconContent = .topic(title: String(info.title.prefix(1)), color: info.iconColor, size: CGSize(width: 16.0, height: 16.0))
                }
            } else {
                avatarIconContent = .image(image: PresentationResourcesChatList.generalTopicIcon(presentationData.theme.theme)?.withRenderingMode(.alwaysTemplate), tintColor: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper))
            }
            
            let avatarIconComponent = EmojiStatusComponent(
                context: context,
                animationCache: context.animationCache,
                animationRenderer: context.animationRenderer,
                content: avatarIconContent,
                isVisibleForAnimations: false,
                action: nil
            )
            let icon = ComponentView<Empty>()
            self.icon = icon
            let _ = icon.update(
                transition: .immediate,
                component: AnyComponent(avatarIconComponent),
                environment: {},
                containerSize: CGSize(width: 16.0, height: 16.0)
            )
            if let iconView = icon.view {
                self.view.addSubview(iconView)
            }
        }
        self.addSubnode(self.labelNode)
                
        let titleFont = Font.medium(min(18.0, floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)))
        
        let attributedString = NSAttributedString(string: text, font: titleFont, textColor: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper))
        let labelLayout = TextNode.asyncLayout(self.labelNode)
                
        let (size, apply) = labelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        self.labelNode.frame = CGRect(origin: CGPoint(), size: size.size)
        
        let arrowIcon = UIImageView(image: ChatMessagePeerContentNode.arrowImage)
        self.arrowIcon = arrowIcon
        self.view.addSubview(arrowIcon)
    }
    
    func updatePresentationData(_ presentationData: ChatPresentationData, context: AccountContext) {
        let previousPresentationData = self.presentationData
        self.presentationData = presentationData
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
        
        let fullTranslucency: Bool = true

        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: fullTranslucency && dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
        self.stickBackgroundNode.image = graphics.dateFloatingBackground
        
        let titleFont = Font.medium(min(18.0, floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0)))
        
        let attributedString = NSAttributedString(string: self.text, font: titleFont, textColor: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper))
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        
        let (size, apply) = labelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = apply()
        
        if presentationData.fontSize != previousPresentationData.fontSize {
            self.labelNode.bounds = CGRect(origin: CGPoint(), size: size.size)
        }
    }
    
    func updateBackgroundColor(color: UIColor, enableBlur: Bool) {
        self.backgroundNode.updateColor(color: color, enableBlur: enableBlur, transition: .immediate)
    }
    
    func update(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let chatDateSize: CGFloat = 22.0
        let chatDateInset: CGFloat = 6.0
        let arrowInset: CGFloat = 5.0
        let arrowSpacing: CGFloat = arrowInset + 6.0
        
        let avatarDiameter: CGFloat = 16.0
        let avatarInset: CGFloat
        switch self.displayHeader.contents {
        case .peer:
            avatarInset = 2.0
        case .thread:
            avatarInset = 4.0
        }
        let avatarSpacing: CGFloat = 4.0
        
        let labelSize = self.labelNode.bounds.size
        let backgroundSize = CGSize(width: avatarInset + avatarDiameter + avatarSpacing + labelSize.width + chatDateInset + arrowSpacing, height: chatDateSize)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: leftInset + floorToScreenPixels((size.width - leftInset - rightInset - backgroundSize.width) / 2.0), y: (size.height - chatDateSize) / 2.0), size: backgroundSize)
        
        let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + avatarInset, y: backgroundFrame.origin.y + floorToScreenPixels((backgroundSize.height - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter))
        
        if let avatarNode = self.avatarNode {
            transition.updateFrame(node: avatarNode, frame: iconFrame)
            avatarNode.updateSize(size: iconFrame.size)
        }
        if let iconView = self.icon?.view {
            transition.updateFrame(view: iconView, frame: iconFrame)
        }
        
        transition.updateFrame(node: self.stickBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.size.height / 2.0, transition: transition)
        let labelFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + avatarInset + avatarDiameter + avatarSpacing, y: backgroundFrame.origin.y + floorToScreenPixels((backgroundSize.height - labelSize.height) / 2.0)), size: labelSize)
        
        transition.updatePosition(node: self.labelNode, position: labelFrame.center)
        self.labelNode.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
        
        if let arrowIcon = self.arrowIcon, let image = arrowIcon.image {
            arrowIcon.tintColor = bubbleVariableColor(variableColor: presentationData.theme.theme.chat.serviceMessage.dateTextColor, wallpaper: presentationData.theme.wallpaper).withMultipliedAlpha(0.7)
            let arrowSize = image.size
            let arrowFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - arrowInset - arrowSize.width, y: backgroundFrame.minY + floorToScreenPixels((backgroundFrame.height - arrowSize.height) * 0.5)), size: arrowSize)
            transition.updateFrame(view: arrowIcon, frame: arrowFrame)
        }
                
        if let backgroundContent = self.backgroundContent {
            backgroundContent.allowsGroupOpacity = true
            self.backgroundNode.isHidden = true
            
            transition.updateFrame(node: backgroundContent, frame: self.backgroundNode.frame)
            backgroundContent.cornerRadius = backgroundFrame.size.height / 2.0
            
            /*if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += containerSize.height - rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: transition)
            }*/
        }
    }
    
    func updateStickDistanceFactor(_ factor: CGFloat, transition: ContainedViewLayoutTransition) {
        self.stickBackgroundNode.alpha = factor
    }
}

public final class ChatMessageDateHeaderNodeImpl: ListViewItemHeaderNode, ChatMessageDateHeaderNode {
    private var dateContentNode: ChatMessageDateContentNode?
    private var peerContentNode: ChatMessagePeerContentNode?
    
    private var sectionSeparator: ChatMessageDateSectionSeparatorNode?
    
    private let context: AccountContext
    private let localTimestamp: Int32
    private let scheduled: Bool
    private let displayHeader: ChatMessageDateHeader.HeaderData?
    private var presentationData: ChatPresentationData
    private let controllerInteraction: ChatControllerInteraction?
    
    private var flashingOnScrolling = false
    private var stickDistanceFactor: CGFloat = 0.0
    private var action: ((Int32, Bool) -> Void)? = nil
    
    private var params: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?
    private var absolutePosition: (CGRect, CGSize)?
    
    public init(localTimestamp: Int32, scheduled: Bool, displayHeader: ChatMessageDateHeader.HeaderData?, presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction?, context: AccountContext, action: ((Int32, Bool) -> Void)? = nil) {
        self.context = context
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        
        self.localTimestamp = localTimestamp
        self.scheduled = scheduled
        self.displayHeader = displayHeader
        self.action = action
        
        let isRotated = controllerInteraction?.chatIsRotated ?? true
        
        super.init(layerBacked: false, dynamicBounce: true, isRotated: isRotated, seeThrough: false)
        
        if isRotated {
            self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        }
        
        if let displayHeader {
            if self.peerContentNode == nil {
                let sectionSeparator = ChatMessageDateSectionSeparatorNode(controllerInteraction: controllerInteraction, presentationData: presentationData)
                self.sectionSeparator = sectionSeparator
                self.addSubnode(sectionSeparator)
                
                let peerContentNode = ChatMessagePeerContentNode(context: self.context, presentationData: self.presentationData, controllerInteraction: self.controllerInteraction, displayHeader: displayHeader)
                self.peerContentNode = peerContentNode
                self.addSubnode(peerContentNode)
            }
        } else {
            if self.dateContentNode == nil {
                let dateContentNode = ChatMessageDateContentNode(presentationData: self.presentationData, controllerInteraction: self.controllerInteraction, localTimestamp: self.localTimestamp, scheduled: self.scheduled)
                self.dateContentNode = dateContentNode
                self.addSubnode(dateContentNode)
            }
        }
    }

    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(ListViewTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateItem(hasDate: Bool, hasPeer: Bool) {
    }
    
    public func updatePresentationData(_ presentationData: ChatPresentationData, context: AccountContext) {
        if let dateContentNode = self.dateContentNode {
            dateContentNode.updatePresentationData(presentationData, context: context)
        }
        if let peerContentNode = self.peerContentNode {
            peerContentNode.updatePresentationData(presentationData, context: context)
        }

        self.setNeedsLayout()
    }
    
    public func updateBackgroundColor(color: UIColor, enableBlur: Bool) {
        if let dateContentNode = self.dateContentNode {
            dateContentNode.updateBackgroundColor(color: color, enableBlur: enableBlur)
        }
        if let peerContentNode = self.peerContentNode {
            peerContentNode.updateBackgroundColor(color: color, enableBlur: enableBlur)
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        /*self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += containerSize.height - rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }*/
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.params = (size, leftInset, rightInset)
        
        var contentOffsetY: CGFloat = 0.0
        var isFirst = true
        if let dateContentNode = self.dateContentNode {
            if isFirst {
                isFirst = false
                contentOffsetY += 7.0
            } else {
                contentOffsetY += 7.0
            }
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: contentOffsetY), size: CGSize(width: size.width, height: 20.0))
            transition.updateFrame(node: dateContentNode, frame: contentFrame)
            dateContentNode.update(size: contentFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
            contentOffsetY += 20.0
        }
        if let peerContentNode = self.peerContentNode {
            if isFirst {
                isFirst = false
                contentOffsetY += 7.0
            } else {
                contentOffsetY += 7.0
            }
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: contentOffsetY), size: CGSize(width: size.width, height: 20.0))
            transition.updateFrame(node: peerContentNode, frame: contentFrame)
            peerContentNode.update(size: contentFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
            contentOffsetY += 20.0
            
            if let sectionSeparator = self.sectionSeparator {
                let sectionSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.minY + floorToScreenPixels((contentFrame.height - 1.66) * 0.5)), size: CGSize(width: size.width, height: 1.66))
                sectionSeparator.update(size: sectionSeparatorFrame.size, transition: transition)
                transition.updatePosition(node: sectionSeparator, position: sectionSeparatorFrame.center)
                transition.updateBounds(node: sectionSeparator, bounds: CGRect(origin: CGPoint(), size: sectionSeparatorFrame.size))
            }
        }
        contentOffsetY += 7.0
    }
    
    override public func updateStickDistanceFactor(_ factor: CGFloat, distance: CGFloat, transition: ContainedViewLayoutTransition) {
        if !self.stickDistanceFactor.isEqual(to: factor) {
            if let dateContentNode = self.dateContentNode {
                dateContentNode.updateStickDistanceFactor(factor, transition: transition)
            }
            if let peerContentNode = self.peerContentNode {
                peerContentNode.updateStickDistanceFactor(factor, transition: transition)
            }
            
            let wasZero = self.stickDistanceFactor < 0.5
            let isZero = factor < 0.5
            self.stickDistanceFactor = factor
            
            if wasZero != isZero {
                var animated = true
                if case .immediate = transition {
                    animated = false
                }
                self.updateFlashing(animated: animated)
            }
        }
        
        if let sectionSeparator = self.sectionSeparator {
            transition.updateTransform(node: sectionSeparator, transform: CGAffineTransformMakeTranslation(0.0, -distance))
        }
    }
    
    override public func updateFlashingOnScrolling(_ isFlashingOnScrolling: Bool, animated: Bool) {
        self.flashingOnScrolling = isFlashingOnScrolling
        self.updateFlashing(animated: animated)
    }
    
    private func updateFlashing(animated: Bool) {
        let flashing = self.flashingOnScrolling || self.stickDistanceFactor < 0.5
        
        let alpha: CGFloat = flashing ? 1.0 : 0.0
        
        if let dateContentNode = self.dateContentNode {
            let previousAlpha = dateContentNode.alpha
            
            if !previousAlpha.isEqual(to: alpha) {
                dateContentNode.alpha = alpha
                if animated {
                    let duration: Double = flashing ? 0.3 : 0.4
                    dateContentNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration)
                }
            }
        }
        
        if let peerContentNode = self.peerContentNode {
            let previousAlpha = peerContentNode.alpha
            
            if !previousAlpha.isEqual(to: alpha) {
                peerContentNode.alpha = alpha
                if animated {
                    let duration: Double = flashing ? 0.3 : 0.4
                    peerContentNode.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration)
                }
            }
        }
    }
    
    override public func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
        if self.dateContentNode != nil {
            self.layer.animateScale(from: 1.0, to: 0.2, duration: duration, removeOnCompletion: false)
        }
    }

    override public func animateAdded(duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: self.alpha, duration: 0.2)
        if self.dateContentNode != nil {
            self.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2)
        }
    }
    
    override public func getEffectiveAlpha() -> CGFloat {
        if let dateContentNode = self.dateContentNode {
            return dateContentNode.alpha
        }
        if let peerContentNode = self.peerContentNode {
            return peerContentNode.alpha
        }
        return 0.0
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        if let dateContentNode = self.dateContentNode {
            if dateContentNode.frame.contains(point) {
                if dateContentNode.alpha.isZero {
                    return nil
                }
                
                if dateContentNode.backgroundNode.frame.contains(point.offsetBy(dx: -dateContentNode.frame.minX, dy: -dateContentNode.frame.minY)) {
                    return self.view
                }
            }
        }
        if let peerContentNode = self.peerContentNode {
            if peerContentNode.frame.contains(point) {
                if peerContentNode.alpha.isZero {
                    return nil
                }
                
                if peerContentNode.backgroundNode.frame.contains(point.offsetBy(dx: -peerContentNode.frame.minX, dy: -peerContentNode.frame.minY)) {
                    return self.view
                }
            }
        }
        return nil
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
    
    @objc private func tapGesture(_ recognizer: ListViewTapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action?(self.localTimestamp, self.stickDistanceFactor < 0.5)
        }
    }
}

public final class ChatMessageAvatarHeader: ListViewItemHeader {
    public struct Id: Hashable {
        public var peerId: PeerId
        public var timestampId: Int32
    }

    public let id: ListViewItemNode.HeaderId
    public let stackingId: ListViewItemNode.HeaderId? = nil
    public let peerId: PeerId
    public let peer: Peer?
    public let messageReference: MessageReference?
    public let adMessageId: EngineMessage.Id?
    public let effectiveTimestamp: Int32
    public let presentationData: ChatPresentationData
    public let context: AccountContext
    public let controllerInteraction: ChatControllerInteraction?
    public let storyStats: PeerStoryStats?

    public init(timestamp: Int32, peerId: PeerId, peer: Peer?, messageReference: MessageReference?, message: Message, presentationData: ChatPresentationData, context: AccountContext, controllerInteraction: ChatControllerInteraction?, storyStats: PeerStoryStats?) {
        self.peerId = peerId
        self.peer = peer
        self.messageReference = messageReference
        if message.adAttribute != nil {
            self.adMessageId = message.id
        } else {
            self.adMessageId = nil
        }

        var effectiveTimestamp = message.timestamp
        if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) {
            effectiveTimestamp = forwardInfo.date
        }
        self.effectiveTimestamp = effectiveTimestamp

        self.presentationData = presentationData
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.id = ListViewItemNode.HeaderId(space: 1, id: Id(peerId: peerId, timestampId: dateHeaderTimestampId(timestamp: timestamp)))
        self.storyStats = storyStats
        
        let isRotated = controllerInteraction?.chatIsRotated ?? true
        
        self.stickDirection = isRotated ? .top : .bottom
    }
    
    public let stickDirection: ListViewItemHeaderStickDirection
    public let stickOverInsets: Bool = false

    public let height: CGFloat = 38.0

    public func combinesWith(other: ListViewItemHeader) -> Bool {
        if let other = other as? ChatMessageAvatarHeader, other.id == self.id {
            if abs(self.effectiveTimestamp - other.effectiveTimestamp) >= 10 * 60 {
                return false
            }
            return true
        } else {
            return false
        }
    }

    public func node(synchronousLoad: Bool) -> ListViewItemHeaderNode {
        return ChatMessageAvatarHeaderNodeImpl(peerId: self.peerId, peer: self.peer, messageReference: self.messageReference, adMessageId: self.adMessageId, presentationData: self.presentationData, context: self.context, controllerInteraction: self.controllerInteraction, storyStats: self.storyStats, synchronousLoad: synchronousLoad)
    }

    public func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        guard let node = node as? ChatMessageAvatarHeaderNodeImpl else {
            return
        }
        node.updatePresentationData(self.presentationData, context: self.context)
        if let peer = self.peer {
            node.updatePeer(peer: peer)
        }
        node.updateStoryStats(storyStats: self.storyStats, theme: self.presentationData.theme.theme, force: false)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

private let maxVideoLoopCount = 3

public final class ChatMessageAvatarHeaderNodeImpl: ListViewItemHeaderNode, ChatMessageAvatarHeaderNode {
    private let context: AccountContext
    private var presentationData: ChatPresentationData
    private let controllerInteraction: ChatControllerInteraction?
    private var storyStats: PeerStoryStats?
    
    private let peerId: PeerId
    private let messageReference: MessageReference?
    private var peer: Peer?
    private let adMessageId: EngineMessage.Id?

    private let containerNode: ContextControllerSourceNode
    public let avatarNode: AvatarNode
    private var avatarVideoNode: AvatarVideoNode?
        
    private var cachedDataDisposable = MetaDisposable()
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var isAvatarHidden: Bool = false
    
    private var trackingIsInHierarchy: Bool = false {
        didSet {
            if self.trackingIsInHierarchy != oldValue {
                Queue.mainQueue().justDispatch {
                    if self.trackingIsInHierarchy {
                        self.avatarVideoNode?.resetPlayback()
                    }
                    self.updateVideoVisibility()
                }
            }
        }
    }
    
    public init(peerId: PeerId, peer: Peer?, messageReference: MessageReference?, adMessageId: EngineMessage.Id?, presentationData: ChatPresentationData, context: AccountContext, controllerInteraction: ChatControllerInteraction?, storyStats: PeerStoryStats?, synchronousLoad: Bool) {
        self.peerId = peerId
        self.peer = peer
        self.messageReference = messageReference
        self.adMessageId = adMessageId
        self.presentationData = presentationData
        self.context = context
        self.controllerInteraction = controllerInteraction
        self.storyStats = storyStats

        self.containerNode = ContextControllerSourceNode()

        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.contentNode.displaysAsynchronously = !presentationData.isPreview

        let isRotated = controllerInteraction?.chatIsRotated ?? true
        
        super.init(layerBacked: false, dynamicBounce: true, isRotated: isRotated, seeThrough: false)

        if isRotated {
            self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        }

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)

        if let peer = peer {
            self.setPeer(context: context, theme: presentationData.theme.theme, synchronousLoad: synchronousLoad, peer: peer, authorOfMessage: messageReference, emptyColor: .black)
        }
        
        if let storyStats {
            self.updateStoryStats(storyStats: storyStats, theme: presentationData.theme.theme, force: true)
        }

        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let peer = strongSelf.peer else {
                return
            }
            var messageId: MessageId?
            if let messageReference = messageReference, case let .message(_, _, id, _, _, _, _) = messageReference.content {
                messageId = id
            }
            strongSelf.controllerInteraction?.openPeerContextMenu(peer, messageId, strongSelf.containerNode, strongSelf.containerNode.bounds, gesture)
        }

        self.updateSelectionState(animated: false)
    }
    
    deinit {
        self.cachedDataDisposable.dispose()
    }

    public func setCustomLetters(context: AccountContext, theme: PresentationTheme, synchronousLoad: Bool, letters: [String], emptyColor: UIColor) {
        self.containerNode.isGestureEnabled = false

        self.avatarNode.setCustomLetters(letters, icon: !letters.isEmpty ? nil : .phone)
    }
    
    public func updatePeer(peer: Peer) {
        if let previousPeer = self.peer, previousPeer.nameColor != peer.nameColor {
            self.peer = peer
            if peer.smallProfileImage != nil {
                self.avatarNode.setPeerV2(context: self.context, theme: self.presentationData.theme.theme, peer: EnginePeer(peer), authorOfMessage: self.messageReference, overrideImage: nil, emptyColor: .black, synchronousLoad: false, displayDimensions: CGSize(width: 38.0, height: 38.0))
            } else {
                self.avatarNode.setPeer(context: self.context, theme: self.presentationData.theme.theme, peer: EnginePeer(peer), authorOfMessage: self.messageReference, overrideImage: nil, emptyColor: .black, synchronousLoad: false, displayDimensions: CGSize(width: 38.0, height: 38.0))
            }
        }
    }

    public func setPeer(context: AccountContext, theme: PresentationTheme, synchronousLoad: Bool, peer: Peer, authorOfMessage: MessageReference?, emptyColor: UIColor) {
        if let messageReference = self.messageReference, let id = messageReference.id {
            self.containerNode.isGestureEnabled = !id.peerId.isVerificationCodes
        } else {
            self.containerNode.isGestureEnabled = true
        }

        var overrideImage: AvatarNodeImageOverride?
        if peer.isDeleted {
            overrideImage = .deletedIcon
        }
        if peer.smallProfileImage != nil {
            self.avatarNode.setPeerV2(context: context, theme: theme, peer: EnginePeer(peer), authorOfMessage: authorOfMessage, overrideImage: overrideImage, emptyColor: emptyColor, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: 38.0, height: 38.0))
        } else {
            self.avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer), authorOfMessage: authorOfMessage, overrideImage: overrideImage, emptyColor: emptyColor, synchronousLoad: synchronousLoad, displayDimensions: CGSize(width: 38.0, height: 38.0))
        }
        
        if peer.isPremium && context.sharedContext.energyUsageSettings.autoplayVideo {
            self.cachedDataDisposable.set((context.account.postbox.peerView(id: peer.id)
            |> deliverOnMainQueue).startStrict(next: { [weak self] peerView in
                guard let strongSelf = self else {
                    return
                }
                
                let cachedPeerData = peerView.cachedData as? CachedUserData
                var personalPhoto: TelegramMediaImage?
                var profilePhoto: TelegramMediaImage?
                var isKnown = false
                
                if let cachedPeerData = cachedPeerData {
                    if case let .known(maybePersonalPhoto) = cachedPeerData.personalPhoto {
                        personalPhoto = maybePersonalPhoto
                        isKnown = true
                    }
                    if case let .known(maybePhoto) = cachedPeerData.photo {
                        profilePhoto = maybePhoto
                        isKnown = true
                    }
                }
                
                if isKnown {
                    let photo = personalPhoto ?? profilePhoto
                    if let photo = photo, !photo.videoRepresentations.isEmpty || photo.emojiMarkup != nil {
                        let videoNode: AvatarVideoNode
                        if let current = strongSelf.avatarVideoNode {
                            videoNode = current
                        } else {
                            videoNode = AvatarVideoNode(context: context)
                            strongSelf.avatarNode.contentNode.addSubnode(videoNode)
                            strongSelf.avatarVideoNode = videoNode
                        }
                        videoNode.update(peer: EnginePeer(peer), photo: photo, size: CGSize(width: 38.0, height: 38.0))
                        
                        if strongSelf.hierarchyTrackingLayer == nil {
                            let hierarchyTrackingLayer = HierarchyTrackingLayer()
                            hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.trackingIsInHierarchy = true
                            }
                            
                            hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.trackingIsInHierarchy = false
                            }
                            strongSelf.hierarchyTrackingLayer = hierarchyTrackingLayer
                            strongSelf.layer.addSublayer(hierarchyTrackingLayer)
                        }
                    } else {
                        if let avatarVideoNode = strongSelf.avatarVideoNode {
                            avatarVideoNode.removeFromSupernode()
                            strongSelf.avatarVideoNode = nil
                        }
                        strongSelf.hierarchyTrackingLayer?.removeFromSuperlayer()
                        strongSelf.hierarchyTrackingLayer = nil
                    }
                    strongSelf.updateVideoVisibility()
                } else {
                    if let photo = peer.largeProfileImage, photo.hasVideo {
                        let _ = context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id).startStandalone()
                    }
                }
            }))
        } else {            
            self.cachedDataDisposable.set(nil)
            
            self.avatarVideoNode?.removeFromSupernode()
            self.avatarVideoNode = nil
            
            self.hierarchyTrackingLayer?.removeFromSuperlayer()
            self.hierarchyTrackingLayer = nil
        }
    }
    
    public func updateStoryStats(storyStats: PeerStoryStats?, theme: PresentationTheme, force: Bool) {
        /*if storyStats != nil {
            var backgroundContent: WallpaperBubbleBackgroundNode?
            if let current = self.backgroundContent {
                backgroundContent = current
            } else {
                if let backgroundContentValue = self.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                    backgroundContentValue.clipsToBounds = true
                    self.backgroundContent = backgroundContentValue
                    backgroundContent = backgroundContentValue
                    self.containerNode.insertSubnode(backgroundContentValue, belowSubnode: self.avatarNode)
                    
                    let maskLayer = SimpleShapeLayer()
                    maskLayer.fillColor = nil
                    maskLayer.strokeColor = UIColor.white.cgColor
                    maskLayer.lineWidth = 2.0
                    maskLayer.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0)).insetBy(dx: 1.0, dy: 1.0)).cgPath
                    backgroundContentValue.layer.mask = maskLayer
                }
            }
            
            if let backgroundContent {
                backgroundContent.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
                backgroundContent.cornerRadius = backgroundContent.bounds.width * 0.5
            }
        } else {
            if let backgroundContent = self.backgroundContent {
                self.backgroundContent = nil
                backgroundContent.removeFromSupernode()
            }
        }
        
        if self.storyStats != storyStats || self.presentationData.theme.theme !== theme || force {
            var colors = AvatarNode.Colors(theme: theme)
            colors.seenColors = [UIColor(white: 1.0, alpha: 0.2), UIColor(white: 1.0, alpha: 0.2)]
            self.avatarNode.setStoryStats(storyStats: storyStats.flatMap { storyStats in
                return AvatarNode.StoryStats(
                    totalCount: storyStats.totalCount != 0 ? 1 : 0,
                    unseenCount: storyStats.unseenCount != 0 ? 1 : 0,
                    hasUnseenCloseFriendsItems: storyStats.hasUnseenCloseFriends
                )
            }, presentationParams: AvatarNode.StoryPresentationParams(
                colors: colors,
                lineWidth: 2.0,
                inactiveLineWidth: 2.0
            ), transition: .immediate)
        }*/
    }

    override public func didLoad() {
        super.didLoad()

        self.avatarNode.view.addGestureRecognizer(ListViewTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    public func updatePresentationData(_ presentationData: ChatPresentationData, context: AccountContext) {
        if self.presentationData !== presentationData {
            self.presentationData = presentationData
            self.setNeedsLayout()
        }
    }

    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: leftInset + 3.0, y: 0.0), size: CGSize(width: 38.0, height: 38.0)))
        let avatarFrame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        self.avatarNode.position = avatarFrame.center
        self.avatarNode.bounds = CGRect(origin: CGPoint(), size: avatarFrame.size)
        self.avatarNode.updateSize(size: avatarFrame.size)
    }

    override public func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
        if !self.isAvatarHidden {
            self.avatarNode.layer.animateScale(from: 1.0, to: 0.2, duration: duration, removeOnCompletion: false)
        }
    }

    override public func animateAdded(duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: self.alpha, duration: 0.2)
        self.avatarNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2)
    }

    override public func updateStickDistanceFactor(_ factor: CGFloat, distance: CGFloat, transition: ContainedViewLayoutTransition) {
    }

    override public func updateFlashingOnScrolling(_ isFlashingOnScrolling: Bool, animated: Bool) {
    }
    
    private var currentSelectionOffset: CGFloat = 0.0

    public func updateSelectionState(animated: Bool) {
        let currentSelectionOffset = self.currentSelectionOffset
        let offset: CGFloat = self.controllerInteraction?.selectionState != nil ? 42.0 : 0.0
        self.currentSelectionOffset = offset

        let previousSubnodeTransform = CATransform3DMakeTranslation(currentSelectionOffset, 0.0, 0.0)
        self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0)
        if animated {
            self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
        }
    }
    
    public func updateAvatarIsHidden(isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.isAvatarHidden = isHidden
        var avatarTransform: CATransform3D = CATransform3DIdentity
        if isHidden {
            let scale: CGFloat = isHidden ? 0.001 : 1.0
            avatarTransform = CATransform3DTranslate(avatarTransform, -38.0 * 0.5, 38.0 * 0.5, 0.0)
            avatarTransform = CATransform3DScale(avatarTransform, scale, scale, 1.0)
        }
        transition.updateTransform(node: self.avatarNode, transform: avatarTransform)
        transition.updateAlpha(node: self.avatarNode, alpha: isHidden ? 0.0 : 1.0)
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        let result = self.containerNode.view.hitTest(self.view.convert(point, to: self.containerNode.view), with: event)
        return result
    }

    override public func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }

    @objc private func tapGesture(_ recognizer: ListViewTapGestureRecognizer) {
        if case .ended = recognizer.state {
            if self.peerId.namespace == Namespaces.Peer.Empty, case let .message(_, _, id, _, _, _, _) = self.messageReference?.content {
                self.controllerInteraction?.displayMessageTooltip(id, self.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, false, self, self.avatarNode.frame)
            } else if let peer = self.peer {
                if peer.id.isVerificationCodes {
                    self.controllerInteraction?.playShakeAnimation()
                } else if let adMessageId = self.adMessageId {
                    self.controllerInteraction?.activateAdAction(adMessageId, nil, false, false)
                } else {
                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        self.controllerInteraction?.openPeer(EnginePeer(peer), .chat(textInputState: nil, subject: nil, peekData: nil), self.messageReference, .default)
                    } else {
                        self.controllerInteraction?.openPeer(EnginePeer(peer), .info(nil), self.messageReference, .groupParticipant(storyStats: nil, avatarHeaderNode: self))
                    }
                }
            }
        }
    }
    
    private func updateVideoVisibility() {
        let isVisible = self.trackingIsInHierarchy
        self.avatarVideoNode?.updateVisibility(isVisible)
      
        if let videoNode = self.avatarVideoNode {
            videoNode.updateLayout(size: self.avatarNode.bounds.size, cornerRadius: self.avatarNode.bounds.size.width / 2.0, transition: .immediate)
            videoNode.frame = self.avatarNode.bounds
        }
    }
}
