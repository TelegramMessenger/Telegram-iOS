import Foundation
import AsyncDisplayKit
import Display
import Postbox

enum ChatMessageBackgroundMergeType {
    case None, Top, Bottom, Both
    
    init(top: Bool, bottom: Bool) {
        if top && bottom {
            self = .Both
        } else if top {
            self = .Top
        } else if bottom {
            self = .Bottom
        } else {
            self = .None
        }
    }
}

private enum ChatMessageBackgroundType: Equatable {
    case Incoming(ChatMessageBackgroundMergeType), Outgoing(ChatMessageBackgroundMergeType)
}

private func ==(lhs: ChatMessageBackgroundType, rhs: ChatMessageBackgroundType) -> Bool {
    switch lhs {
        case let .Incoming(lhsMergeType):
            switch rhs {
                case let .Incoming(rhsMergeType):
                    return lhsMergeType == rhsMergeType
                case .Outgoing:
                    return false
            }
        case let .Outgoing(lhsMergeType):
            switch rhs {
                case .Incoming:
                    return false
                case let .Outgoing(rhsMergeType):
                    return lhsMergeType == rhsMergeType
            }
    }
}

private let chatMessageBackgroundIncomingImage = UIImage(named: "Chat/Message/Background/BubbleIncoming")?.precomposed()
private let chatMessageBackgroundOutgoingImage = UIImage(named: "Chat/Message/Background/BubbleOutgoing")?.precomposed()
private let chatMessageBackgroundIncomingMergedTopImage = UIImage(named: "Chat/Message/Background/BubbleIncomingMergedTop")?.precomposed()
private let chatMessageBackgroundIncomingMergedBottomImage = UIImage(named: "Chat/Message/Background/BubbleIncomingMergedBottom")?.precomposed()
private let chatMessageBackgroundIncomingMergedBothImage = UIImage(named: "Chat/Message/Background/BubbleIncomingMergedBoth")?.precomposed()
private let chatMessageBackgroundOutgoingMergedImage = UIImage(named: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()
private let chatMessageBackgroundOutgoingMergedTopImage = UIImage(named: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()
private let chatMessageBackgroundOutgoingMergedBottomImage = UIImage(named: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()
private let chatMessageBackgroundOutgoingMergedBothImage = UIImage(named: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()

class ChatMessageBackground: ASImageNode {
    private var type: ChatMessageBackgroundType?
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
    }
    
    private func setType(type: ChatMessageBackgroundType) {
        if let currentType = self.type, currentType == type {
            return
        }
        self.type = type
        
        let image: UIImage?
        switch type {
            case let .Incoming(mergeType):
                switch mergeType {
                    case .None:
                        image = chatMessageBackgroundIncomingImage
                    case .Top:
                        image = chatMessageBackgroundIncomingMergedBottomImage
                    case .Bottom:
                        image = chatMessageBackgroundIncomingMergedTopImage
                    case .Both:
                        image = chatMessageBackgroundIncomingMergedBothImage
                }
            case let .Outgoing(mergeType):
                switch mergeType {
                    case .None:
                        image = chatMessageBackgroundOutgoingImage
                    case .Top:
                        image = chatMessageBackgroundOutgoingMergedTopImage
                    case .Bottom:
                        image = chatMessageBackgroundOutgoingMergedBottomImage
                    case .Both:
                        image = chatMessageBackgroundOutgoingMergedBothImage
                }
        }
        self.image = image
    }
}

private func contentNodeClassesForItem(_ item: ChatMessageItem) -> [AnyClass] {
    var result: [AnyClass] = []
    for media in item.message.media {
        if let _ = media as? TelegramMediaImage {
            result.append(ChatMessageMediaBubbleContentNode.self)
        } else if let file = media as? TelegramMediaFile {
            if file.isVideo {
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
        return CTFontCreateWithName("HelveticaNeue-Medium", 14.0, nil)
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
    
    private var nameNode: TextNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var replyInfoNode: ChatMessageReplyInfoNode?
    
    private var contentNodes: [ChatMessageBubbleContentNode] = []
    
    private var messageId: MessageId?
    
    private var backgroundFrameTransition: (CGRect, CGRect)?
    
    required init() {
        self.backgroundNode = ChatMessageBackground()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.backgroundNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        super.animateInsertion(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        for contentNode in self.contentNodes {
            contentNode.animateInsertion(currentTimestamp, duration: duration)
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
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    override func asyncLayout() -> (item: ChatMessageItem, width: CGFloat, mergedTop: Bool, mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        var currentContentClassesPropertiesAndLayouts: [(AnyClass, ChatMessageBubbleContentProperties, (item: ChatMessageItem, layoutConstants: ChatMessageItemLayoutConstants, position: ChatMessageBubbleContentPosition, constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))))] = []
        for contentNode in self.contentNodes {
            currentContentClassesPropertiesAndLayouts.append((contentNode.dynamicType as AnyClass, contentNode.properties, contentNode.asyncLayoutContent()))
        }
        
        let authorNameLayout = TextNode.asyncLayout(self.nameNode)
        let forwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let replyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        
        let layoutConstants = self.layoutConstants
        
        return { item, width, mergedTop, mergedBottom in
            let message = item.message
            
            let incoming = item.account.peerId != message.author?.id
            let displayAuthorInfo = !mergedTop && incoming && item.peerId.isGroup && item.message.author != nil
            
            let avatarInset: CGFloat = (item.peerId.isGroup && item.message.author != nil) ? layoutConstants.avatarDiameter : 0.0
            
            let tmpWidth = width * layoutConstants.bubble.maximumWidthFillFactor
            let maximumContentWidth = floor(tmpWidth - layoutConstants.bubble.edgeInset - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - layoutConstants.bubble.contentInsets.right - avatarInset)
            
            var contentPropertiesAndPrepareLayouts: [(ChatMessageBubbleContentProperties, (item: ChatMessageItem, layoutConstants: ChatMessageItemLayoutConstants, position: ChatMessageBubbleContentPosition, constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))))] = []
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
            
            for attribute in message.attributes {
                if let attribute = attribute as? InlineBotMessageAttribute, let bot = message.peers[attribute.peerId] as? TelegramUser {
                    inlineBotNameString = bot.username
                } else if let attribute = attribute as? ReplyMessageAttribute {
                    replyMessage = message.associatedMessages[attribute.messageId]
                }
            }
            
            var displayHeader = true
            if inlineBotNameString == nil && message.forwardInfo == nil && replyMessage == nil {
                if let first = contentPropertiesAndPrepareLayouts.first, first.0.hidesSimpleAuthorHeader {
                    displayHeader = false
                }
            }
            
            var contentPropertiesAndLayouts: [(ChatMessageBubbleContentProperties, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void)))] = []
            
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
                
                let (maxNodeWidth, nodeLayout) = prepareLayout(item: item, layoutConstants: layoutConstants, position: ChatMessageBubbleContentPosition(top: topPosition, bottom: bottomPosition), constrainedSize: CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude))
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
                    if headerSize.height < CGFloat(FLT_EPSILON) {
                        headerSize.height += 4.0
                    }
                    
                    let inlineBotNameColor = incoming ? UIColor(0x1195f2) : UIColor(0x00a700)
                    
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
                    
                    let sizeAndApply = authorNameLayout(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude), cutout: nil)
                    nameNodeSizeApply = (sizeAndApply.0.size, {
                        return sizeAndApply.1()
                    })
                    nameNodeOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, nameNodeSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += nameNodeSizeApply.0.height
                }
                
                if let forwardInfo = message.forwardInfo {
                    if headerSize.height < CGFloat(FLT_EPSILON) {
                        headerSize.height += 4.0
                    }
                    let sizeAndApply = forwardInfoLayout(incoming: incoming, peer: forwardInfo.source == nil ? forwardInfo.author : forwardInfo.source!, authorPeer: forwardInfo.source == nil ? nil : forwardInfo.author, constrainedSize: CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                    forwardInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                    
                    forwardInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, forwardInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += forwardInfoSizeApply.0.height
                }
                
                if let replyMessage = replyMessage {
                    if headerSize.height < CGFloat(FLT_EPSILON) {
                        headerSize.height += 6.0
                    } else {
                        headerSize.height += 2.0
                    }
                    let sizeAndApply = replyInfoLayout(incoming: incoming, message: replyMessage, constrainedSize: CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                    replyInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                    
                    replyInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, replyInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += replyInfoSizeApply.0.height + 2.0
                }
                
                if headerSize.height > CGFloat(FLT_EPSILON) {
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
            
            var contentNodePropertiesAndFinalize: [(ChatMessageBubbleContentProperties, (CGFloat) -> (CGSize, () -> Void))] = []
            
            var maxContentWidth: CGFloat = headerSize.width
            for (contentNodeProperties, contentNodeLayout) in contentPropertiesAndLayouts {
                let (contentNodeWidth, contentNodeFinalize) = contentNodeLayout(CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                maxContentWidth = max(maxContentWidth, contentNodeWidth)
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
            }
            
            var contentSize = CGSize(width: maxContentWidth, height: 0.0)
            index = 0
            var contentNodeSizesPropertiesAndApply: [(CGSize, ChatMessageBubbleContentProperties, () -> Void)] = []
            for (properties, finalize) in contentNodePropertiesAndFinalize {
                let (size, apply) = finalize(maxContentWidth)
                contentNodeSizesPropertiesAndApply.append((size, properties, apply))
                
                contentSize.height += size.height
                
                if index == 0 && headerSize.height > CGFloat(FLT_EPSILON) {
                    contentSize.height += properties.headerSpacing
                }
                
                index += 1
            }
            
            let layoutBubbleSize = CGSize(width: max(contentSize.width, headerSize.width) + layoutConstants.bubble.contentInsets.left + layoutConstants.bubble.contentInsets.right, height: max(layoutConstants.bubble.minimumSize.height, headerSize.height + contentSize.height + layoutConstants.bubble.contentInsets.top + layoutConstants.bubble.contentInsets.bottom))
            
            let backgroundFrame = CGRect(origin: CGPoint(x: incoming ? (layoutConstants.bubble.edgeInset + avatarInset) : (width - layoutBubbleSize.width - layoutConstants.bubble.edgeInset), y: 0.0), size: layoutBubbleSize)
            
            let contentOrigin = CGPoint(x: backgroundFrame.origin.x + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)

            let layoutSize = CGSize(width: width, height: layoutBubbleSize.height)
            let layoutInsets = UIEdgeInsets(top: mergedTop ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            
            let layout = ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets)
            
            return (layout, { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.messageId = message.id
                    
                    if let nameNode = nameNodeSizeApply.1() {
                        strongSelf.nameNode = nameNode
                        if nameNode.supernode == nil {
                            nameNode.isLayerBacked = true
                            strongSelf.addSubnode(nameNode)
                        }
                        nameNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY), size: nameNodeSizeApply.0)
                    } else {
                        strongSelf.nameNode?.removeFromSupernode()
                        strongSelf.nameNode = nil
                    }
                    
                    if let forwardInfoNode = forwardInfoSizeApply.1() {
                        strongSelf.forwardInfoNode = forwardInfoNode
                        if forwardInfoNode.supernode == nil {
                            strongSelf.addSubnode(forwardInfoNode)
                        }
                        forwardInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + forwardInfoOriginY), size: forwardInfoSizeApply.0)
                    } else {
                        strongSelf.forwardInfoNode?.removeFromSupernode()
                        strongSelf.forwardInfoNode = nil
                    }
                    
                    if let replyInfoNode = replyInfoSizeApply.1() {
                        strongSelf.replyInfoNode = replyInfoNode
                        if replyInfoNode.supernode == nil {
                            strongSelf.addSubnode(replyInfoNode)
                        }
                        replyInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + replyInfoOriginY), size: replyInfoSizeApply.0)
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
                        apply()
                        if contentNodeIndex == 0 && headerSize.height > CGFloat(FLT_EPSILON) {
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
                    
                    let mergeType = ChatMessageBackgroundMergeType(top: mergedBottom, bottom: mergedTop)
                    if !incoming {
                        strongSelf.backgroundNode.setType(type: .Outgoing(mergeType))
                    } else {
                        strongSelf.backgroundNode.setType(type: .Incoming(mergeType))
                    }
                    
                    if case .System = animation {
                        strongSelf.backgroundFrameTransition = (strongSelf.backgroundNode.frame, backgroundFrame)
                        strongSelf.enableTransitionClippingNode()
                    } else {
                        if let _ = strongSelf.backgroundFrameTransition {
                            strongSelf.animateFrameTransition(1.0)
                            strongSelf.backgroundFrameTransition = nil
                        }
                        strongSelf.backgroundNode.frame = backgroundFrame
                        strongSelf.disableTransitionClippingNode()
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
            for contentNode in self.contentNodes {
                node.addSubnode(contentNode)
            }
            self.addSubnode(node)
            self.transitionClippingNode = node
        }
    }
    
    private func disableTransitionClippingNode() {
        if let transitionClippingNode = self.transitionClippingNode {
            for contentNode in self.contentNodes {
                self.addSubnode(contentNode)
            }
            transitionClippingNode.removeFromSupernode()
            self.transitionClippingNode = nil
        }
    }
    
    override func animateFrameTransition(_ progress: CGFloat) {
        super.animateFrameTransition(progress)
        
        if let backgroundFrameTransition = self.backgroundFrameTransition {
            let backgroundFrame = CGRect.interpolator()(backgroundFrameTransition.0, backgroundFrameTransition.1, progress) as! CGRect
            self.backgroundNode.frame = backgroundFrame
            
            if let transitionClippingNode = self.transitionClippingNode {
                var fixedBackgroundFrame = backgroundFrame
                fixedBackgroundFrame = fixedBackgroundFrame.insetBy(dx: 0.0, dy: 1.0)
                
                transitionClippingNode.frame = fixedBackgroundFrame
                transitionClippingNode.bounds = CGRect(origin: CGPoint(x: fixedBackgroundFrame.origin.x, y: fixedBackgroundFrame.origin.y), size: fixedBackgroundFrame.size)
                
                if progress >= 1.0 - CGFloat(FLT_EPSILON) {
                    self.disableTransitionClippingNode()
                }
            }
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                let location = recognizer.location(in: self.view)
                if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                self.controllerInteraction?.testNavigateToMessage(item.message.id, attribute.messageId)
                                break
                            }
                        }
                    }
                    //self.controllerInteraction?.testNavigateToMessage(messageId)
                }
            default:
                break
        }
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
}
