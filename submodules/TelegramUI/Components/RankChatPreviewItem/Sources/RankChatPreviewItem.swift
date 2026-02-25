import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import WallpaperBackgroundNode
import ListItemComponentAdaptor
import ChatMessageItemImpl

public final class RankChatPreviewItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    public struct MessageItem: Equatable {
        public static func ==(lhs: MessageItem, rhs: MessageItem) -> Bool {
            if lhs.text != rhs.text {
                return false
            }
            if areMediaArraysEqual(lhs.media, rhs.media) {
                return false
            }
            if lhs.rank != rhs.rank {
                return false
            }
            return true
        }
        
        let peer: EnginePeer
        let text: String
        let entities: TextEntitiesMessageAttribute?
        let media: [Media]
        let rank: String
        let rankRole: ChatRankInfoScreenRole
        
        public init(peer: EnginePeer, text: String, entities: TextEntitiesMessageAttribute?, media: [Media], rank: String, rankRole: ChatRankInfoScreenRole) {
            self.peer = peer
            self.text = text
            self.entities = entities
            self.media = media
            self.rank = rank
            self.rankRole = rankRole
        }
    }
    
    let context: AccountContext
    let systemStyle: ItemListSystemStyle
    let theme: PresentationTheme
    let componentTheme: PresentationTheme
    let strings: PresentationStrings
    public let sectionId: ItemListSectionId
    let fontSize: PresentationFontSize
    let chatBubbleCorners: PresentationChatBubbleCorners
    let wallpaper: TelegramWallpaper
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let messageItems: [MessageItem]
    let containerWidth: CGFloat?
    let hideAvatars: Bool
    let verticalInset: CGFloat
    let maskSide: Bool
    
    public init(
        context: AccountContext,
        systemStyle: ItemListSystemStyle = .legacy,
        theme: PresentationTheme,
        componentTheme: PresentationTheme,
        strings: PresentationStrings,
        sectionId: ItemListSectionId,
        fontSize: PresentationFontSize,
        chatBubbleCorners: PresentationChatBubbleCorners,
        wallpaper: TelegramWallpaper,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        messageItems: [MessageItem],
        containerWidth: CGFloat? = nil,
        hideAvatars: Bool = false,
        verticalInset: CGFloat = 0.0,
        maskSide: Bool = false
    ) {
        self.context = context
        self.systemStyle = systemStyle
        self.theme = theme
        self.componentTheme = componentTheme
        self.strings = strings
        self.sectionId = sectionId
        self.fontSize = fontSize
        self.chatBubbleCorners = chatBubbleCorners
        self.wallpaper = wallpaper
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.messageItems = messageItems
        self.containerWidth = containerWidth
        self.hideAvatars = hideAvatars
        self.verticalInset = verticalInset
        self.maskSide = maskSide
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = RankChatPreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? RankChatPreviewItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: RankChatPreviewItem, rhs: RankChatPreviewItem) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.componentTheme !== rhs.componentTheme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.chatBubbleCorners != rhs.chatBubbleCorners {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.messageItems != rhs.messageItems {
            return false
        }
        if lhs.containerWidth != rhs.containerWidth {
            return false
        }
        if lhs.hideAvatars != rhs.hideAvatars {
            return false
        }
        return true
    }
}

final class RankChatPreviewItemNode: ListViewItemNode {
    private var backgroundNode: WallpaperBackgroundNode?
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?
    private var itemHeaderNodes: [ListViewItemNode.HeaderId: ListViewItemHeaderNode] = [:]
    
    private var item: RankChatPreviewItem?
    
    private let disposable = MetaDisposable()
    
    init() {
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.containerNode = ASDisplayNode()
        self.containerNode.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false)
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.containerNode)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func asyncLayout() -> (_ item: RankChatPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentNodes = self.messageNodes

        var currentBackgroundNode = self.backgroundNode
                
        return { item, params, neighbors in
            if currentBackgroundNode == nil {
                currentBackgroundNode = createWallpaperBackgroundNode(context: item.context, forChatDisplay: false)
                currentBackgroundNode?.update(wallpaper: item.wallpaper, animated: false)
                currentBackgroundNode?.updateBubbleTheme(bubbleTheme: item.componentTheme, bubbleCorners: item.chatBubbleCorners)
            }

            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
                        
            var items: [ListViewItem] = []
            for messageItem in item.messageItems.reversed() {
                var userPeer = messageItem.peer._asPeer()
                
                let updatedId = PeerId.Id._internalFromInt64Value(userPeer.id.id._internalGetInt64Value() - 7)
                let authorPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: updatedId)
                let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(0))
                let groupPeer = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, title: "", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
                
                
                if let user = userPeer as? TelegramUser {
                    userPeer = TelegramUser(id: authorPeerId, accessHash: user.accessHash, firstName: user.firstName, lastName: user.lastName, username: "", phone: user.phone, photo: user.photo, botInfo: user.botInfo, restrictionInfo: user.restrictionInfo, flags: user.flags, emojiStatus: user.emojiStatus, usernames: user.usernames, storiesHidden: user.storiesHidden, nameColor: user.nameColor, backgroundEmojiId: user.backgroundEmojiId, profileColor: user.profileColor, profileBackgroundEmojiId: user.profileBackgroundEmojiId, subscriberCount: user.subscriberCount, verificationIconFileId: user.verificationIconFileId)
                }
                                
                var peers = SimpleDictionary<PeerId, Peer>()
                let messages = SimpleDictionary<MessageId, Message>()
                
                peers[authorPeerId] = userPeer
                peers[groupPeerId] = groupPeer
                
                let media = messageItem.media
                var attributes: [MessageAttribute] = []
                if let entities = messageItem.entities {
                    attributes.append(entities)
                }
                
                let message = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: groupPeerId, namespace: Namespaces.Message.Local, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 20460, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: peers[authorPeerId], text: messageItem.text, attributes: attributes, media: media, peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                items.append(item.context.sharedContext.makeChatMessagePreviewItem(context: item.context, messages: [message], theme: item.componentTheme, strings: item.strings, wallpaper: item.wallpaper, fontSize: item.fontSize, chatBubbleCorners: item.chatBubbleCorners, dateTimeFormat: item.dateTimeFormat, nameOrder: item.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: currentBackgroundNode, availableReactions: nil, accountPeer: nil, isCentered: item.containerWidth != nil, isPreview: true, isStandalone: false, rank: messageItem.rank, rankRole: messageItem.rankRole))
            }
            
            let itemParams = ListViewItemLayoutParams(width: item.containerWidth ?? params.width, leftInset: params.leftInset, rightInset: params.rightInset, availableHeight: params.availableHeight, isStandalone: params.isStandalone)
            
            var nodes: [ListViewItemNode] = []
            if let messageNodes = currentNodes {
                nodes = messageNodes
                for i in 0 ..< items.count {
                    let itemNode = messageNodes[i]
                    items[i].updateNode(async: { $0() }, node: {
                        return itemNode
                    }, params: itemParams, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                        let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                        
                        itemNode.contentSize = layout.contentSize
                        itemNode.insets = layout.insets
                        itemNode.frame = nodeFrame
                        itemNode.isUserInteractionEnabled = false
                        
                        Queue.mainQueue().after(0.01) {
                            apply(ListViewItemApply(isOnScreen: true))
                        }
                    })
                }
            } else {
                var messageNodes: [ListViewItemNode] = []
                for i in 0 ..< items.count {
                    var itemNode: ListViewItemNode?
                    items[i].nodeConfiguredForParams(async: { $0() }, params: itemParams, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                        itemNode = node
                        apply().1(ListViewItemApply(isOnScreen: true))
                    })
                    itemNode!.isUserInteractionEnabled = false
                    messageNodes.append(itemNode!)
                }
                nodes = messageNodes
            }
            
            var contentSize = CGSize(width: params.width, height: 4.0 + 4.0)
            for node in nodes {
                contentSize.height += node.frame.size.height
            }
            contentSize.height += item.verticalInset * 2.0
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            insets.top = 0.0
            insets.bottom = 0.0
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let leftInset = params.leftInset
            let rightInset = params.leftInset
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if item.maskSide {
                        let gradientLayer: SimpleGradientLayer
                        if let current = strongSelf.containerNode.layer.mask as? SimpleGradientLayer {
                            gradientLayer = current
                        } else {
                            gradientLayer = SimpleGradientLayer()
                            gradientLayer.colors = [UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.cgColor, UIColor.white.cgColor]
                            gradientLayer.locations = [0.0, 0.25, 1.0]
                            gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
                            gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                            gradientLayer.type = .axial
                            strongSelf.containerNode.layer.mask = gradientLayer
                        }
                        gradientLayer.frame = CGRect(origin: .zero, size: layoutSize)
                    } else {
                        strongSelf.containerNode.layer.mask = nil
                    }
                    
                    if let currentBackgroundNode {
                        currentBackgroundNode.update(wallpaper: item.wallpaper, animated: false)
                        currentBackgroundNode.updateBubbleTheme(bubbleTheme: item.theme, bubbleCorners: item.chatBubbleCorners)
                    }
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                    
                    strongSelf.messageNodes = nodes
                    var topOffset: CGFloat = 4.0 + item.verticalInset
                    for node in nodes {
                        if node.supernode == nil {
                            strongSelf.containerNode.addSubnode(node)
                        }
                        var leftOffset: CGFloat = 0.0
                        if item.containerWidth != nil {
                            leftOffset -= 27.0
                        }
                        
                        node.updateFrame(CGRect(origin: CGPoint(x: leftOffset, y: topOffset), size: node.frame.size), within: layoutSize)
                        topOffset += node.frame.size.height
                        
                        if let header = node.headers()?.first(where: { $0 is ChatMessageAvatarHeader }) {
                            let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: 3.0 + node.frame.minY), size: CGSize(width: layoutSize.width, height: header.height))
                            let stickLocationDistanceFactor: CGFloat = 0.0
                            
                            let id = header.id
                            let headerNode: ListViewItemHeaderNode
                            if let current = strongSelf.itemHeaderNodes[id] {
                                headerNode = current
                                headerNode.updateFrame(headerFrame, within: layoutSize)
                                
                                if headerNode.item !== header {
                                    header.updateNode(headerNode, previous: nil, next: nil)
                                    headerNode.item = header
                                }
                                headerNode.updateLayoutInternal(size: headerFrame.size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                                headerNode.updateStickDistanceFactor(stickLocationDistanceFactor, distance: 0.0, transition: .immediate)
                            } else {
                                headerNode = header.node(synchronousLoad: true)
                                if headerNode.item !== header {
                                    header.updateNode(headerNode, previous: nil, next: nil)
                                    headerNode.item = header
                                }
                                headerNode.frame = headerFrame
                                headerNode.updateLayoutInternal(size: headerFrame.size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                                strongSelf.itemHeaderNodes[id] = headerNode

                                strongSelf.containerNode.addSubnode(headerNode)
                                headerNode.updateStickDistanceFactor(stickLocationDistanceFactor, distance: 0.0, transition: .immediate)
                            }
                            headerNode.isHidden = item.hideAvatars
                        }
                    }
                    
                    if let currentBackgroundNode = currentBackgroundNode, strongSelf.backgroundNode !== currentBackgroundNode {
                        strongSelf.backgroundNode = currentBackgroundNode
                        strongSelf.insertSubnode(currentBackgroundNode, at: 0)
                    }
                    
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    if params.isStandalone {
                        strongSelf.topStripeNode.isHidden = true
                        strongSelf.bottomStripeNode.isHidden = true
                        strongSelf.maskNode.isHidden = true
                    } else {
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        
                        switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                        }
                        let bottomStripeInset: CGFloat
                        let bottomStripeOffset: CGFloat
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = 0.0
                                bottomStripeOffset = -separatorHeight
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                bottomStripeOffset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.componentTheme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil
                        
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    
                    let displayMode: WallpaperDisplayMode
                    if abs(params.availableHeight - params.width) < 100.0, params.availableHeight > 700.0 {
                        displayMode = .halfAspectFill
                    } else {
                        if backgroundFrame.width > backgroundFrame.height * 4.0 {
                            if params.availableHeight < 700.0 {
                                displayMode = .halfAspectFill
                            } else {
                                displayMode = .aspectFill
                            }
                        } else {
                            displayMode = .aspectFill
                        }
                    }
                    
                    if let backgroundNode = strongSelf.backgroundNode {
                        backgroundNode.frame = backgroundFrame
                        backgroundNode.updateLayout(size: backgroundNode.bounds.size, displayMode: displayMode, transition: .immediate)
                    }
                    strongSelf.maskNode.frame = backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
