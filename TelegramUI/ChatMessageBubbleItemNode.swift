import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

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

private let chatMessageBackgroundIncomingImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleIncoming")?.precomposed()
private let chatMessageBackgroundOutgoingImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleOutgoing")?.precomposed()
private let chatMessageBackgroundIncomingMergedTopImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleIncomingMergedTop")?.precomposed()
private let chatMessageBackgroundIncomingMergedBottomImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleIncomingMergedBottom")?.precomposed()
private let chatMessageBackgroundIncomingMergedBothImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleIncomingMergedBoth")?.precomposed()
private let chatMessageBackgroundOutgoingMergedImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()
private let chatMessageBackgroundOutgoingMergedTopImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()
private let chatMessageBackgroundOutgoingMergedBottomImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()
private let chatMessageBackgroundOutgoingMergedBothImage = UIImage(bundleImageName: "Chat/Message/Background/BubbleOutgoingMerged")?.precomposed()

class ChatMessageBackground: ASImageNode {
    private var type: ChatMessageBackgroundType?
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
    }
    
    fileprivate func setType(type: ChatMessageBackgroundType) {
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
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.doNotWaitForDoubleTapAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let replyInfoNode = strongSelf.replyInfoNode, replyInfoNode.frame.contains(point) {
                    return true
                }
                if let forwardInfoNode = strongSelf.forwardInfoNode, forwardInfoNode.frame.contains(point) {
                    return true
                }
            }
            return false
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        var currentContentClassesPropertiesAndLayouts: [(AnyClass, ChatMessageBubbleContentProperties, (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))))] = []
        for contentNode in self.contentNodes {
            currentContentClassesPropertiesAndLayouts.append((type(of: contentNode) as AnyClass, contentNode.properties, contentNode.asyncLayoutContent()))
        }
        
        let authorNameLayout = TextNode.asyncLayout(self.nameNode)
        let forwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let replyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        
        let layoutConstants = self.layoutConstants
        
        return { item, width, mergedTop, mergedBottom in
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
                    
                    let sizeAndApply = authorNameLayout(attributedString, nil, 1, .end, CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude), nil)
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
                    let sizeAndApply = forwardInfoLayout(incoming, forwardInfo.source == nil ? forwardInfo.author : forwardInfo.source!, forwardInfo.source == nil ? nil : forwardInfo.author, CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
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
                    let sizeAndApply = replyInfoLayout(incoming, replyMessage, CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
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
            
            var contentNodePropertiesAndFinalize: [(ChatMessageBubbleContentProperties, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))] = []
            
            var maxContentWidth: CGFloat = headerSize.width
            for (contentNodeProperties, contentNodeLayout) in contentPropertiesAndLayouts {
                let (contentNodeWidth, contentNodeFinalize) = contentNodeLayout(CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude))
                maxContentWidth = max(maxContentWidth, contentNodeWidth)
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
            }
            
            var contentSize = CGSize(width: maxContentWidth, height: 0.0)
            index = 0
            var contentNodeSizesPropertiesAndApply: [(CGSize, ChatMessageBubbleContentProperties, (ListViewItemUpdateAnimation) -> Void)] = []
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
                        apply(animation)
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
                    let offset: CGFloat = incoming ? 42.0 : 0.0
                    strongSelf.selectionNode?.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: width, height: layout.size.height))
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
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
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
                                        self.controllerInteraction?.openPeer(forwardInfo.source?.id ?? forwardInfo.author.id, .chat)
                                    }
                                    return
                                }
                            }
                            self.controllerInteraction?.clickThroughMessage()
                        case .longTap, .doubleTap:
                            if let item = self.item {
                                self.controllerInteraction?.openMessageContextMenu(item.message.id, self, self.backgroundNode.frame)
                            }
                    }
                }
            default:
                break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let selectionNode = self.selectionNode {
            if selectionNode.frame.offsetBy(dx: 42.0, dy: 0.0).contains(point) {
                return selectionNode.view
            } else {
                return nil
            }
        }
        
        if !self.backgroundNode.frame.contains(point) {
            return nil
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
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.bounds.size.width, height: self.bounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(toggle: { [weak self] in
                    if let strongSelf = self, let item = strongSelf.item {
                        strongSelf.controllerInteraction?.toggleMessageSelection(item.message.id)
                    }
                })
                
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.bounds.size.width, height: self.bounds.size.height))
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
}
