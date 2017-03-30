import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private func contentNodeClassesForItem(_ item: ChatMessageItem) -> [AnyClass] {
    var result: [AnyClass] = []
    for media in item.message.media {
        if let _ = media as? TelegramMediaImage {
            result.append(ChatMessageMediaBubbleContentNode.self)
        } else if let file = media as? TelegramMediaFile {
            if file.isVideo || (file.isAnimated && file.dimensions != nil) {
                result.append(ChatMessageMediaBubbleContentNode.self)
            } else {
                result.append(ChatMessageFileBubbleContentNode.self)
            }
        }
    }
    
    if !item.message.text.isEmpty {
        result.append(ChatMessageTextBubbleContentNode.self)
    }
    
    for media in item.message.media {
        if let webpage = media as? TelegramMediaWebpage {
            if case .Loaded = webpage.content {
                result.append(ChatMessageWebpageBubbleContentNode.self)
            }
            break
        }
    }
    
    return result
}

private let nameFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 14.0, weight: UIFontWeightMedium)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 14.0, nil)
    }
}()

private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

private let chatMessagePeerIdColors: [UIColor] = [
    UIColor(0xfc5c51),
    UIColor(0xfa790f),
    UIColor(0x0fb297),
    UIColor(0x3ca5ec),
    UIColor(0x3d72ed),
    UIColor(0x895dd5)
]

class ChatMessageBubbleItemNode: ChatMessageItemView {
    private let backgroundNode: ChatMessageBackground
    private var transitionClippingNode: ASDisplayNode?
    
    private var selectionNode: ChatMessageSelectionNode?
    
    private var nameNode: TextNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var replyInfoNode: ChatMessageReplyInfoNode?
    
    private var contentNodes: [ChatMessageBubbleContentNode] = []
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    
    private var messageId: MessageId?
    private var messageStableId: UInt32?
    private var backgroundType: ChatMessageBackgroundType?
    private var highlightedState: Bool = false
    
    private var backgroundFrameTransition: (CGRect, CGRect)?
    
    required init() {
        self.backgroundNode = ChatMessageBackground()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.backgroundNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        for node in self.subnodes {
            if node !== self.accessoryItemNode {
                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        for contentNode in self.contentNodes {
            //contentNode.animateInsertion(currentTimestamp, duration: duration)
        }
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        
        for contentNode in self.contentNodes {
            //contentNode.animateRemoved(currentTimestamp, duration: duration)
        }
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        self.nameNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.forwardInfoNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.replyInfoNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        for contentNode in self.contentNodes {
            contentNode.animateAdded(currentTimestamp, duration: duration)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let avatarNode = strongSelf.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                
                if let nameNode = strongSelf.nameNode, nameNode.frame.contains(point) {
                    if let item = strongSelf.item {
                        for attribute in item.message.attributes {
                            if let _ = attribute as? InlineBotMessageAttribute {
                                return .waitForSingleTap
                            }
                        }
                    }
                }
                if let replyInfoNode = strongSelf.replyInfoNode, replyInfoNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                if let forwardInfoNode = strongSelf.forwardInfoNode, forwardInfoNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                for contentNode in strongSelf.contentNodes {
                    let tapAction = contentNode.tapActionAtPoint(CGPoint(x: point.x - contentNode.frame.minX, y: point.y - contentNode.frame.minY))
                    switch tapAction {
                        case .none:
                            break
                        case .url, .peerMention, .textMention, .botCommand, .hashtag, .instantPage:
                            return .waitForSingleTap
                        case .holdToPreviewSecretMedia:
                            return .waitForHold
                    }
                }
            }
            
            return .waitForDoubleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        var currentContentClassesPropertiesAndLayouts: [(AnyClass, ChatMessageBubbleContentProperties, (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))))] = []
        for contentNode in self.contentNodes {
            currentContentClassesPropertiesAndLayouts.append((type(of: contentNode) as AnyClass, contentNode.properties, contentNode.asyncLayoutContent()))
        }
        
        let authorNameLayout = TextNode.asyncLayout(self.nameNode)
        let forwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let replyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        
        let layoutConstants = self.layoutConstants
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
            let message = item.message
            let incoming = item.message.effectivelyIncoming
            
            let displayAuthorInfo = !mergedTop && incoming && item.peerId.isGroupOrChannel && item.message.author != nil
            
            let avatarInset: CGFloat = (item.peerId.isGroupOrChannel && item.message.author != nil) ? layoutConstants.avatarDiameter : 0.0
            
            let tmpWidth = width * layoutConstants.bubble.maximumWidthFillFactor
            let maximumContentWidth = floor(tmpWidth - layoutConstants.bubble.edgeInset - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - layoutConstants.bubble.contentInsets.right - avatarInset)
            
            var contentPropertiesAndPrepareLayouts: [(ChatMessageBubbleContentProperties, (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))))] = []
            var addedContentNodes: [ChatMessageBubbleContentNode]?
            
            let contentNodeClasses = contentNodeClassesForItem(item)
            for contentNodeClass in contentNodeClasses {
                var found = false
                for (currentClass, currentProperties, currentLayout) in currentContentClassesPropertiesAndLayouts {
                    if currentClass == contentNodeClass {
                        contentPropertiesAndPrepareLayouts.append((currentProperties, currentLayout))
                        found = true
                        break
                    }
                }
                if !found {
                    let contentNode = (contentNodeClass as! ChatMessageBubbleContentNode.Type).init()
                    contentPropertiesAndPrepareLayouts.append((contentNode.properties, contentNode.asyncLayoutContent()))
                    if addedContentNodes == nil {
                        addedContentNodes = [contentNode]
                    } else {
                        addedContentNodes!.append(contentNode)
                    }
                }
            }
            
            var authorNameString: String?
            var inlineBotNameString: String?
            var replyMessage: Message?
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            for attribute in message.attributes {
                if let attribute = attribute as? InlineBotMessageAttribute, let bot = message.peers[attribute.peerId] as? TelegramUser {
                    inlineBotNameString = bot.username
                } else if let attribute = attribute as? ReplyMessageAttribute {
                    replyMessage = message.associatedMessages[attribute.messageId]
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            var displayHeader = true
            if inlineBotNameString == nil && message.forwardInfo == nil && replyMessage == nil {
                if let first = contentPropertiesAndPrepareLayouts.first, first.0.hidesSimpleAuthorHeader {
                    displayHeader = false
                }
            }
            
            var contentPropertiesAndLayouts: [(ChatMessageBubbleContentProperties, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void)))] = []
            
            let topNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedTop ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
            let bottomNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedBottom ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
            
            let firstNodeTopPosition: ChatMessageBubbleRelativePosition
            if displayHeader {
                firstNodeTopPosition = .Neighbour
            } else {
                firstNodeTopPosition = .None(topNodeMergeStatus)
            }
            let lastNodeTopPosition: ChatMessageBubbleRelativePosition = .None(bottomNodeMergeStatus)
            
            var maximumNodeWidth = maximumContentWidth
            let contentNodeCount = contentPropertiesAndPrepareLayouts.count
            var index = 0
            for (properties, prepareLayout) in contentPropertiesAndPrepareLayouts {
                let topPosition: ChatMessageBubbleRelativePosition
                let bottomPosition: ChatMessageBubbleRelativePosition
                
                if index == 0 {
                    topPosition = firstNodeTopPosition
                } else {
                    topPosition = .Neighbour
                }
                
                if index == contentNodeCount - 1 {
                    bottomPosition = lastNodeTopPosition
                } else {
                    bottomPosition = .Neighbour
                }
                
                let (maxNodeWidth, nodeLayout) = prepareLayout(item, layoutConstants, ChatMessageBubbleContentPosition(top: topPosition, bottom: bottomPosition), CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude))
                maximumNodeWidth = min(maximumNodeWidth, maxNodeWidth)
                
                contentPropertiesAndLayouts.append((properties, nodeLayout))
                index += 1
            }
            
            var headerSize = CGSize()
            
            var nameNodeOriginY: CGFloat = 0.0
            var nameNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
            var authorNameColor: UIColor?
            
            var replyInfoOriginY: CGFloat = 0.0
            var replyInfoSizeApply: (CGSize, () -> ChatMessageReplyInfoNode?) = (CGSize(), { nil })
            
            var forwardInfoOriginY: CGFloat = 0.0
            var forwardInfoSizeApply: (CGSize, () -> ChatMessageForwardInfoNode?) = (CGSize(), { nil })
            
            if displayHeader {
                if let author = message.author, displayAuthorInfo {
                    authorNameString = author.displayTitle
                    authorNameColor = chatMessagePeerIdColors[Int(author.id.id % 6)]
                }
                
                if authorNameString != nil || inlineBotNameString != nil {
                    if headerSize.height < CGFloat.ulpOfOne {
                        headerSize.height += 4.0
                    }
                    
                    let inlineBotNameColor = incoming ? UIColor(0x007ee5) : UIColor(0x00a700)
                    
                    let attributedString: NSAttributedString
                    if let authorNameString = authorNameString, let authorNameColor = authorNameColor, let inlineBotNameString = inlineBotNameString {
                        let botPrefixString: NSString = " via "
                        let mutableString = NSMutableAttributedString(string: "\(authorNameString)\(botPrefixString)@\(inlineBotNameString)", attributes: [NSFontAttributeName: inlineBotNameFont, NSForegroundColorAttributeName: inlineBotNameColor])
                        mutableString.addAttributes([NSFontAttributeName: nameFont, NSForegroundColorAttributeName: authorNameColor], range: NSMakeRange(0, (authorNameString as NSString).length))
                        mutableString.addAttributes([NSFontAttributeName: inlineBotPrefixFont, NSForegroundColorAttributeName: inlineBotNameColor], range: NSMakeRange((authorNameString as NSString).length, botPrefixString.length))
                        attributedString = mutableString
                    } else if let authorNameString = authorNameString, let authorNameColor = authorNameColor {
                        attributedString = NSAttributedString(string: authorNameString, font: nameFont, textColor: authorNameColor)
                    } else if let inlineBotNameString = inlineBotNameString {
                        attributedString = NSAttributedString(string: "via @\(inlineBotNameString)", font: inlineBotNameFont, textColor: inlineBotNameColor)
                    } else {
                        attributedString = NSAttributedString(string: "", font: nameFont, textColor: UIColor.black)
                    }
                    
                    let sizeAndApply = authorNameLayout(attributedString, nil, 1, .end, CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
                    nameNodeSizeApply = (sizeAndApply.0.size, {
                        return sizeAndApply.1()
                    })
                    nameNodeOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, nameNodeSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += nameNodeSizeApply.0.height
                }
                
                if let forwardInfo = message.forwardInfo {
                    if headerSize.height < CGFloat.ulpOfOne {
                        headerSize.height += 4.0
                    }
                    let sizeAndApply = forwardInfoLayout(incoming, forwardInfo.source == nil ? forwardInfo.author : forwardInfo.source!, forwardInfo.source == nil ? nil : forwardInfo.author, CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                    forwardInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                    
                    forwardInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, forwardInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += forwardInfoSizeApply.0.height
                }
                
                if let replyMessage = replyMessage {
                    if headerSize.height < CGFloat.ulpOfOne {
                        headerSize.height += 6.0
                    } else {
                        headerSize.height += 2.0
                    }
                    let sizeAndApply = replyInfoLayout(item.account, .bubble(incoming: incoming), replyMessage, CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                    replyInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                    
                    replyInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, replyInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += replyInfoSizeApply.0.height + 2.0
                }
                
                if headerSize.height > CGFloat.ulpOfOne {
                    headerSize.height -= 3.0
                }
            }
            
            var removedContentNodeIndices: [Int]?
            findRemoved: for i in 0 ..< currentContentClassesPropertiesAndLayouts.count {
                let currentClass: AnyClass = currentContentClassesPropertiesAndLayouts[i].0
                for contentNodeClass in contentNodeClasses {
                    if currentClass == contentNodeClass {
                        continue findRemoved
                    }
                }
                if removedContentNodeIndices == nil {
                    removedContentNodeIndices = [i]
                } else {
                    removedContentNodeIndices!.append(i)
                }
            }
            
            var contentNodePropertiesAndFinalize: [(ChatMessageBubbleContentProperties, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))] = []
            
            var maxContentWidth: CGFloat = headerSize.width
            for (contentNodeProperties, contentNodeLayout) in contentPropertiesAndLayouts {
                let (contentNodeWidth, contentNodeFinalize) = contentNodeLayout(CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                maxContentWidth = max(maxContentWidth, contentNodeWidth)
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
            }
            
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animated: Bool) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(replyMarkup, maximumNodeWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            }
            
            var contentSize = CGSize(width: maxContentWidth, height: 0.0)
            index = 0
            var contentNodeSizesPropertiesAndApply: [(CGSize, ChatMessageBubbleContentProperties, (ListViewItemUpdateAnimation) -> Void)] = []
            for (properties, finalize) in contentNodePropertiesAndFinalize {
                let (size, apply) = finalize(maxContentWidth)
                contentNodeSizesPropertiesAndApply.append((size, properties, apply))
                
                contentSize.height += size.height
                
                if index == 0 && headerSize.height > CGFloat.ulpOfOne {
                    contentSize.height += properties.headerSpacing
                }
                
                index += 1
            }
            
            var actionButtonsSizeAndApply: (CGSize, (Bool) -> ChatMessageActionButtonsNode)?
            if let actionButtonsFinalize = actionButtonsFinalize {
                actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
            }
            
            let layoutBubbleSize = CGSize(width: max(contentSize.width, headerSize.width) + layoutConstants.bubble.contentInsets.left + layoutConstants.bubble.contentInsets.right, height: max(layoutConstants.bubble.minimumSize.height, headerSize.height + contentSize.height + layoutConstants.bubble.contentInsets.top + layoutConstants.bubble.contentInsets.bottom))
            
            let backgroundFrame = CGRect(origin: CGPoint(x: incoming ? (layoutConstants.bubble.edgeInset + avatarInset) : (width - layoutBubbleSize.width - layoutConstants.bubble.edgeInset), y: 0.0), size: layoutBubbleSize)
            
            let contentOrigin = CGPoint(x: backgroundFrame.origin.x + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)

            var layoutSize = CGSize(width: width, height: layoutBubbleSize.height)
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            
            var layoutInsets = UIEdgeInsets(top: mergedTop ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let layout = ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets)
            
            return (layout, { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.messageId = message.id
                    strongSelf.messageStableId = message.stableId
                    
                    let mergeType = ChatMessageBackgroundMergeType(top: mergedBottom, bottom: mergedTop)
                    let backgroundType: ChatMessageBackgroundType
                    if !incoming {
                        backgroundType = .Outgoing(mergeType)
                    } else {
                        backgroundType = .Incoming(mergeType)
                    }
                    strongSelf.backgroundNode.setType(type: backgroundType, highlighted: strongSelf.highlightedState)
                    
                    strongSelf.backgroundType = backgroundType
                    
                    if let nameNode = nameNodeSizeApply.1() {
                        strongSelf.nameNode = nameNode
                        if nameNode.supernode == nil {
                            if !nameNode.isNodeLoaded {
                                nameNode.isLayerBacked = true
                            }
                            strongSelf.addSubnode(nameNode)
                        }
                        nameNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY), size: nameNodeSizeApply.0)
                    } else {
                        strongSelf.nameNode?.removeFromSupernode()
                        strongSelf.nameNode = nil
                    }
                    
                    if let forwardInfoNode = forwardInfoSizeApply.1() {
                        strongSelf.forwardInfoNode = forwardInfoNode
                        var animateFrame = true
                        if forwardInfoNode.supernode == nil {
                            strongSelf.addSubnode(forwardInfoNode)
                            animateFrame = false
                        }
                        let previousForwardInfoNodeFrame = forwardInfoNode.frame
                        forwardInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + forwardInfoOriginY), size: forwardInfoSizeApply.0)
                        if case let .System(duration) = animation {
                            if animateFrame {
                                forwardInfoNode.layer.animateFrame(from: previousForwardInfoNodeFrame, to: forwardInfoNode.frame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else {
                        strongSelf.forwardInfoNode?.removeFromSupernode()
                        strongSelf.forwardInfoNode = nil
                    }
                    
                    if let replyInfoNode = replyInfoSizeApply.1() {
                        strongSelf.replyInfoNode = replyInfoNode
                        var animateFrame = true
                        if replyInfoNode.supernode == nil {
                            strongSelf.addSubnode(replyInfoNode)
                            animateFrame = false
                        }
                        let previousReplyInfoNodeFrame = replyInfoNode.frame
                        replyInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + replyInfoOriginY), size: replyInfoSizeApply.0)
                        if case let .System(duration) = animation {
                            if animateFrame {
                                replyInfoNode.layer.animateFrame(from: previousReplyInfoNodeFrame, to: replyInfoNode.frame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else {
                        strongSelf.replyInfoNode?.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    if removedContentNodeIndices?.count ?? 0 != 0 || addedContentNodes?.count ?? 0 != 0 {
                        var updatedContentNodes = strongSelf.contentNodes
                        
                        if let removedContentNodeIndices = removedContentNodeIndices {
                            for index in removedContentNodeIndices.reversed() {
                                updatedContentNodes[index].removeFromSupernode()
                                let _ = updatedContentNodes.remove(at: index)
                            }
                        }
                        
                        if let addedContentNodes = addedContentNodes {
                            for contentNode in addedContentNodes {
                                updatedContentNodes.append(contentNode)
                                strongSelf.addSubnode(contentNode)
                                contentNode.controllerInteraction = strongSelf.controllerInteraction
                            }
                        }
                        
                        strongSelf.contentNodes = updatedContentNodes
                    }
                    
                    var contentNodeOrigin = contentOrigin
                    var contentNodeIndex = 0
                    for (size, properties, apply) in contentNodeSizesPropertiesAndApply {
                        apply(animation)
                        if contentNodeIndex == 0 && headerSize.height > CGFloat.ulpOfOne {
                            contentNodeOrigin.y += properties.headerSpacing
                        }
                        let contentNode = strongSelf.contentNodes[contentNodeIndex]
                        let contentNodeFrame = CGRect(origin: contentNodeOrigin, size: size)
                        let previousContentNodeFrame = contentNode.frame
                        contentNode.frame = contentNodeFrame
                        
                        if case let .System(duration) = animation {
                            var animateFrame = false
                            var animateAlpha = false
                            if let addedContentNodes = addedContentNodes {
                                if !addedContentNodes.contains(where: { $0 === contentNode }) {
                                    animateFrame = true
                                } else {
                                    animateAlpha = true
                                }
                            } else {
                                animateFrame = true
                            }
                            
                            if animateFrame {
                                contentNode.layer.animateFrame(from: previousContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            } else if animateAlpha {
                                contentNode.animateInsertionIntoBubble(duration)
                                var previousAlignedContentNodeFrame = contentNodeFrame
                                previousAlignedContentNodeFrame.origin.x += backgroundFrame.size.width - strongSelf.backgroundNode.frame.size.width
                                contentNode.layer.animateFrame(from: previousAlignedContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                        contentNodeIndex += 1
                        contentNodeOrigin.y += size.height
                    }
                    
                    if case .System = animation {
                        if !strongSelf.backgroundNode.frame.equalTo(backgroundFrame) {
                            strongSelf.backgroundFrameTransition = (strongSelf.backgroundNode.frame, backgroundFrame)
                            strongSelf.enableTransitionClippingNode()
                        }
                    } else {
                        if let _ = strongSelf.backgroundFrameTransition {
                            strongSelf.animateFrameTransition(1.0, backgroundFrame.size.height)
                            strongSelf.backgroundFrameTransition = nil
                        }
                        strongSelf.backgroundNode.frame = backgroundFrame
                        strongSelf.disableTransitionClippingNode()
                    }
                    let offset: CGFloat = incoming ? 42.0 : 0.0
                    strongSelf.selectionNode?.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: width, height: layout.size.height))
                    
                    if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                        var animated = false
                        if let _ = strongSelf.actionButtonsNode {
                            if case .System = animation {
                                animated = true
                            }
                        }
                        let actionButtonsNode = actionButtonsSizeAndApply.1(animated)
                        let previousFrame = actionButtonsNode.frame
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.maxY), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button in
                                if let strongSelf = self {
                                    strongSelf.performMessageButtonAction(button: button)
                                }
                            }
                            strongSelf.addSubnode(actionButtonsNode)
                        } else {
                            if case let .System(duration) = animation {
                                actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else if let actionButtonsNode = strongSelf.actionButtonsNode {
                        actionButtonsNode.removeFromSupernode()
                        strongSelf.actionButtonsNode = nil
                    }
                }
            })
        }
    }
    
    private func addContentNode(node: ChatMessageBubbleContentNode) {
        if let transitionClippingNode = self.transitionClippingNode {
            transitionClippingNode.addSubnode(node)
        } else {
            self.addSubnode(node)
        }
    }
    
    private func enableTransitionClippingNode() {
        if self.transitionClippingNode == nil {
            let node = ASDisplayNode()
            node.clipsToBounds = true
            var backgroundFrame = self.backgroundNode.frame
            backgroundFrame = backgroundFrame.insetBy(dx: 0.0, dy: 1.0)
            node.frame = backgroundFrame
            node.bounds = CGRect(origin: CGPoint(x: backgroundFrame.origin.x, y: backgroundFrame.origin.y), size: backgroundFrame.size)
            if let forwardInfoNode = self.forwardInfoNode {
                node.addSubnode(forwardInfoNode)
            }
            if let replyInfoNode = self.replyInfoNode {
                node.addSubnode(replyInfoNode)
            }
            for contentNode in self.contentNodes {
                node.addSubnode(contentNode)
            }
            self.addSubnode(node)
            self.transitionClippingNode = node
        }
    }
    
    private func disableTransitionClippingNode() {
        if let transitionClippingNode = self.transitionClippingNode {
            if let forwardInfoNode = self.forwardInfoNode {
                self.addSubnode(forwardInfoNode)
            }
            if let replyInfoNode = self.replyInfoNode {
                self.addSubnode(replyInfoNode)
            }
            for contentNode in self.contentNodes {
                self.addSubnode(contentNode)
            }
            transitionClippingNode.removeFromSupernode()
            self.transitionClippingNode = nil
        }
    }
    
    override func shouldAnimateHorizontalFrameTransition() -> Bool {
        if let _ = self.backgroundFrameTransition {
            return true
        } else {
            return false
        }
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        if let backgroundFrameTransition = self.backgroundFrameTransition {
            let backgroundFrame = CGRect.interpolator()(backgroundFrameTransition.0, backgroundFrameTransition.1, progress) as! CGRect
            self.backgroundNode.frame = backgroundFrame
            
            if let transitionClippingNode = self.transitionClippingNode {
                var fixedBackgroundFrame = backgroundFrame
                fixedBackgroundFrame = fixedBackgroundFrame.insetBy(dx: 0.0, dy: 1.0)
                
                transitionClippingNode.frame = fixedBackgroundFrame
                transitionClippingNode.bounds = CGRect(origin: CGPoint(x: fixedBackgroundFrame.origin.x, y: fixedBackgroundFrame.origin.y), size: fixedBackgroundFrame.size)
                
                if progress >= 1.0 - CGFloat.ulpOfOne {
                    self.disableTransitionClippingNode()
                }
            }
            
            if CGFloat(1.0).isLessThanOrEqualTo(progress) {
                self.backgroundFrameTransition = nil
            }
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation, case .hold = gesture {
                    if let item = self.item, item.message.containsSecretMedia {
                        self.controllerInteraction?.openSecretMessagePreview(item.message.id)
                    }
                }
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                                if let item = self.item, let author = item.message.author {
                                    self.controllerInteraction?.openPeer(author.id, .info, item.message.id)
                                }
                                return
                            }
                            
                            if let nameNode = self.nameNode, nameNode.frame.contains(location) {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? InlineBotMessageAttribute, let botPeer = item.message.peers[attribute.peerId], let addressName = botPeer.addressName {
                                            self.controllerInteraction?.updateInputState { textInputState in
                                                return ChatTextInputState(inputText: "@" + addressName + " ")
                                            }
                                            return
                                        }
                                    }
                                }
                            } else if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? ReplyMessageAttribute {
                                            self.controllerInteraction?.navigateToMessage(item.message.id, attribute.messageId)
                                            return
                                        }
                                    }
                                }
                            }
                            if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                                if let item = self.item, let forwardInfo = item.message.forwardInfo {
                                    if let sourceMessageId = forwardInfo.sourceMessageId {
                                        self.controllerInteraction?.navigateToMessage(item.message.id, sourceMessageId)
                                    } else {
                                        self.controllerInteraction?.openPeer(forwardInfo.source?.id ?? forwardInfo.author.id, .chat(textInputState: nil), nil)
                                    }
                                    return
                                }
                            }
                            var foundTapAction = false
                            loop: for contentNode in self.contentNodes {
                                let tapAction = contentNode.tapActionAtPoint(CGPoint(x: location.x - contentNode.frame.minX, y: location.y - contentNode.frame.minY))
                                switch tapAction {
                                    case .none:
                                        break
                                    case let .url(url):
                                        foundTapAction = true
                                        if let controllerInteraction = self.controllerInteraction {
                                            controllerInteraction.openUrl(url)
                                        }
                                        break loop
                                    case let .peerMention(peerId):
                                        foundTapAction = true
                                        if let controllerInteraction = self.controllerInteraction {
                                            controllerInteraction.openPeer(peerId, .chat(textInputState: nil), nil)
                                        }
                                        break loop
                                    case let .textMention(name):
                                        foundTapAction = true
                                        if let controllerInteraction = self.controllerInteraction {
                                            controllerInteraction.openPeerMention(name)
                                        }
                                        break loop
                                    case let .botCommand(command):
                                        foundTapAction = true
                                        if let item = self.item, let controllerInteraction = self.controllerInteraction {
                                            controllerInteraction.sendBotCommand(item.message.id, command)
                                        }
                                        break loop
                                    case let .hashtag(peerName, hashtag):
                                        foundTapAction = true
                                        if let controllerInteraction = self.controllerInteraction {
                                            controllerInteraction.openHashtag(peerName, hashtag)
                                        }
                                        break loop
                                    case .instantPage:
                                        foundTapAction = true
                                        if let item = self.item, let controllerInteraction = self.controllerInteraction {
                                            controllerInteraction.openInstantPage(item.message.id)
                                        }
                                        break loop
                                    case .holdToPreviewSecretMedia:
                                        foundTapAction = true
                                        break
                                }
                            }
                            if !foundTapAction {
                                self.controllerInteraction?.clickThroughMessage()
                            }
                        case .longTap, .doubleTap:
                            if let item = self.item, self.backgroundNode.frame.contains(location) {
                                self.controllerInteraction?.openMessageContextMenu(item.message.id, self, self.backgroundNode.frame)
                            }
                        case .hold:
                            if let item = self.item, item.message.containsSecretMedia {
                                self.controllerInteraction?.closeSecretMessagePreview()
                            }
                    }
                }
            case .cancelled:
                if let item = self.item, item.message.containsSecretMedia {
                    self.controllerInteraction?.closeSecretMessagePreview()
                }
            default:
                break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(point) {
            return self.view
        }
        
        if let selectionNode = self.selectionNode {
            if selectionNode.frame.offsetBy(dx: 42.0, dy: 0.0).contains(point) {
                return selectionNode.view
            } else {
                return nil
            }
        }
        
        if !self.backgroundNode.frame.contains(point) {
            if self.actionButtonsNode == nil || !self.actionButtonsNode!.frame.contains(point) {
                return nil
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        if let item = self.item, item.message.id == id {
            for contentNode in self.contentNodes {
                if let result = contentNode.transitionNode(media: media) {
                    return result
                }
            }
        }
        return nil
    }
    
    override func updateHiddenMedia() {
        if let item = self.item, let controllerInteraction = self.controllerInteraction {
            for contentNode in self.contentNodes {
                contentNode.updateHiddenMedia(controllerInteraction.hiddenMedia[item.message.id])
            }
        }
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let controllerInteraction = self.controllerInteraction else {
            return
        }
        
        if let selectionState = controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            if let item = self.item {
                selected = selectionState.selectedIds.contains(item.message.id)
                incoming = item.message.effectivelyIncoming
            }
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(toggle: { [weak self] in
                    if let strongSelf = self, let item = strongSelf.item {
                        strongSelf.controllerInteraction?.toggleMessageSelection(item.message.id)
                    }
                })
                
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.addSubnode(selectionNode)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                } else {
                    selectionNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func updateHighlightedState(animated: Bool) {
        if let controllerInteraction = self.controllerInteraction {
            var highlighted = false
            if let messageStableId = self.messageStableId, let highlightedState = controllerInteraction.highlightedState {
                if highlightedState.messageStableId == messageStableId {
                    highlighted = true
                }
            }
            
            if self.highlightedState != highlighted {
                self.highlightedState = highlighted
                if let backgroundType = self.backgroundType {
                    if highlighted {
                        self.backgroundNode.setType(type: backgroundType, highlighted: true)
                    } else {
                        if let previousContents = self.backgroundNode.layer.contents, animated {
                            self.backgroundNode.setType(type: backgroundType, highlighted: false)
                            
                            if let updatedContents = self.backgroundNode.layer.contents {
                                self.backgroundNode.layer.animate(from: previousContents as AnyObject, to: updatedContents as AnyObject, keyPath: "contents", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: 0.3)
                            }
                        } else {
                            self.backgroundNode.setType(type: backgroundType, highlighted: false)
                        }
                    }
                }
            }
        }
    }
    
    private func performMessageButtonAction(button: ReplyMarkupButton) {
        if let item = self.item, let controllerInteraction = self.controllerInteraction {
            switch button.action {
                case .text:
                    controllerInteraction.sendMessage(button.title)
                case let .url(url):
                    controllerInteraction.openUrl(url)
                case .requestMap:
                    controllerInteraction.shareCurrentLocation()
                case .requestPhone:
                    controllerInteraction.shareAccountContact()
                case .openWebApp:
                    controllerInteraction.requestMessageActionCallback(item.message.id, nil, true)
                case let .callback(data):
                    controllerInteraction.requestMessageActionCallback(item.message.id, data, false)
                case let .switchInline(samePeer, query):
                    var botPeer: Peer?
                    
                    var found = false
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute {
                            botPeer = item.message.peers[attribute.peerId]
                            found = true
                        }
                    }
                    if !found {
                        botPeer = item.message.author
                    }
                    
                    var peerId: PeerId?
                    if samePeer {
                        peerId = item.message.id.peerId
                    }
                    if let botPeer = botPeer, let addressName = botPeer.addressName {
                        controllerInteraction.openPeer(peerId, .chat(textInputState: ChatTextInputState(inputText: "@\(addressName) \(query)")), nil)
                    }
            }
        }
    }
}
