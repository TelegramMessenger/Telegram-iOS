import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import WallpaperBackgroundNode
import ListItemComponentAdaptor

final class ChatGiftPreviewItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    enum Subject: Equatable {
        case premium(months: Int32, amount: Int64, currency: String)
        case starGift(gift: StarGift.Gift)
        case uniqueGift(gift: StarGift.UniqueGift, nameHidden: Bool)
    }
    let context: AccountContext
    let theme: PresentationTheme
    let componentTheme: PresentationTheme
    let strings: PresentationStrings
    let sectionId: ItemListSectionId
    let fontSize: PresentationFontSize
    let chatBubbleCorners: PresentationChatBubbleCorners
    let wallpaper: TelegramWallpaper
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    
    let peers: [EnginePeer]
    let subject: ChatGiftPreviewItem.Subject
    let chatPeerId: EnginePeer.Id?
    let text: String
    let entities: [MessageTextEntity]
    let upgradeStars: Int64?
    let chargeStars: Int64?
    let bottomInset: CGFloat
    let contentHeight: CGFloat
    let maximumBubbleBottom: CGFloat?
    let action: (() -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        componentTheme: PresentationTheme,
        strings: PresentationStrings,
        sectionId: ItemListSectionId,
        fontSize: PresentationFontSize,
        chatBubbleCorners: PresentationChatBubbleCorners,
        wallpaper: TelegramWallpaper,
        dateTimeFormat: PresentationDateTimeFormat,
        nameDisplayOrder: PresentationPersonNameOrder,
        peers: [EnginePeer],
        subject: ChatGiftPreviewItem.Subject,
        chatPeerId: EnginePeer.Id?,
        text: String,
        entities: [MessageTextEntity],
        upgradeStars: Int64?,
        chargeStars: Int64?,
        bottomInset: CGFloat = 0.0,
        contentHeight: CGFloat = 370.0,
        maximumBubbleBottom: CGFloat? = nil,
        action: (() -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.componentTheme = componentTheme
        self.strings = strings
        self.sectionId = sectionId
        self.fontSize = fontSize
        self.chatBubbleCorners = chatBubbleCorners
        self.wallpaper = wallpaper
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.peers = peers
        self.subject = subject
        self.chatPeerId = chatPeerId
        self.text = text
        self.entities = entities
        self.upgradeStars = upgradeStars
        self.chargeStars = chargeStars
        self.bottomInset = bottomInset
        self.contentHeight = contentHeight
        self.maximumBubbleBottom = maximumBubbleBottom
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = ChatGiftPreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { _ in apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatGiftPreviewItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                completion(layout, { _ in
                    apply()
                })
            }
        }
    }
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: ChatGiftPreviewItem, rhs: ChatGiftPreviewItem) -> Bool {
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
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.chatPeerId != rhs.chatPeerId {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.upgradeStars != rhs.upgradeStars {
            return false
        }
        if lhs.chargeStars != rhs.chargeStars {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.contentHeight != rhs.contentHeight {
            return false
        }
        if lhs.maximumBubbleBottom != rhs.maximumBubbleBottom {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
}

final class ChatGiftPreviewItemNode: ListViewItemNode {
    private var backgroundNode: WallpaperBackgroundNode?
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?
    private var itemHeaderNodes: [ListViewItemNode.HeaderId: ListViewItemHeaderNode] = [:]
    
    private var item: ChatGiftPreviewItem?
    
    private let disposable = MetaDisposable()
    
    private var initialBubbleHeight: CGFloat?
    
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
    
    func asyncLayout() -> (_ item: ChatGiftPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentNodes = self.messageNodes

        var currentBackgroundNode = self.backgroundNode
                
        return { [weak self] item, params, neighbors in
            if currentBackgroundNode == nil {
                currentBackgroundNode = createWallpaperBackgroundNode(context: item.context, forChatDisplay: false)
                currentBackgroundNode?.update(wallpaper: item.wallpaper, animated: false)
                currentBackgroundNode?.updateBubbleTheme(bubbleTheme: item.componentTheme, bubbleCorners: item.chatBubbleCorners)
            }

            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))
            let chatPeerId = item.chatPeerId ?? peerId
            
            var items: [ListViewItem] = []
            for _ in 0 ..< 1 {
                let authorPeerId = item.context.account.peerId
                
                var peers = EngineSimpleDictionary<EnginePeer.Id, EngineRawPeer>()
                let messages = EngineSimpleDictionary<EngineMessage.Id, EngineRawMessage>()
                
                for peer in item.peers {
                    peers[peer.id] = peer._asPeer()
                }
                
                let media: [EngineRawMedia]
                switch item.subject {
                case let .premium(months, amount, currency):
                    media = [
                        TelegramMediaAction(
                            action: .giftPremium(currency: currency, amount: amount, days: months * 30, cryptoCurrency: nil, cryptoAmount: nil, text: item.text, entities: item.entities)
                        )
                    ]
                case let .starGift(gift):
                    media = [
                        TelegramMediaAction(
                            action: .starGift(gift: .generic(gift), convertStars: gift.convertStars, text: item.text, entities: item.entities, nameHidden: false, savedToProfile: false, converted: false, upgraded: false, canUpgrade: gift.upgradeStars != nil, upgradeStars: item.upgradeStars, isRefunded: false, isPrepaidUpgrade: false, upgradeMessageId: nil, peerId: nil, senderId: nil, savedId: nil, prepaidUpgradeHash: nil, giftMessageId: nil, upgradeSeparate: false, isAuctionAcquired: false, toPeerId: nil, number: nil)
                        )
                    ]
                case let .uniqueGift(gift, nameHidden):
                    media = [
                        TelegramMediaAction(
                            action: .starGiftUnique(
                                gift: .unique(gift),
                                isUpgrade: false,
                                isTransferred: false,
                                savedToProfile: false,
                                canExportDate: nil,
                                transferStars: nil,
                                isRefunded: false,
                                isPrepaidUpgrade: false,
                                peerId: chatPeerId,
                                senderId: authorPeerId,
                                savedId: nil,
                                resaleAmount: nil,
                                canTransferDate: nil,
                                canResaleDate: nil,
                                dropOriginalDetailsStars: nil,
                                assigned: false,
                                fromOffer: false,
                                canCraftAt: nil,
                                isCrafted: false,
                                text: item.text.isEmpty ? nil : item.text,
                                entities: item.entities.isEmpty ? nil : item.entities,
                                nameHidden: nameHidden
                            )
                        )
                    ]
                }
                
                let messageFlags: EngineMessage.Flags
                if case .uniqueGift = item.subject {
                    messageFlags = []
                } else {
                    messageFlags = [.Incoming]
                }
                let message = EngineRawMessage(stableId: 1, stableVersion: 0, id: EngineMessage.Id(peerId: chatPeerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: messageFlags, tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: peers[authorPeerId], text: "", attributes: [], media: media, peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                items.append(item.context.sharedContext.makeChatMessagePreviewItem(context: item.context, messages: [message], theme: item.componentTheme, strings: item.strings, wallpaper: item.wallpaper, fontSize: item.fontSize, chatBubbleCorners: item.chatBubbleCorners, dateTimeFormat: item.dateTimeFormat, nameOrder: item.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: item.action.map { action in
                    return { _ in action() }
                }, clickThroughMessage: nil, backgroundNode: currentBackgroundNode, availableReactions: nil, accountPeer: item.action == nil ? nil : peers[authorPeerId], isCentered: false, isPreview: true, isStandalone: false, rank: nil, rankRole: nil, isGiftMessageComposerPreview: item.action != nil))
            }
            
            var nodes: [ListViewItemNode] = []
            var currentNodes = currentNodes
            if let nodes = currentNodes, nodes.count != items.count {
                for node in nodes {
                    node.removeFromSupernode()
                }
                currentNodes = nil
            }
            
            let transition = ControlledTransition(duration: 0.2, curve: .spring, interactive: false)
            if let messageNodes = currentNodes {
                nodes = messageNodes
                for i in 0 ..< items.count {
                    let itemNode = messageNodes[i]
                    items[i].updateNode(async: { $0() }, node: {
                        return itemNode
                    }, params: params, neighbors: ListViewItemNeighbors(previous: i == 0 ? nil : items[i - 1].neighborDescriptor, next: i == (items.count - 1) ? nil : items[i + 1].neighborDescriptor), animation: .System(duration: 0.2, transition: transition), completion: { (layout, apply) in
                        itemNode.bounds = CGRect(origin: .zero, size: layout.size)
                        itemNode.contentSize = layout.contentSize
                        itemNode.insets = layout.insets
                        itemNode.isUserInteractionEnabled = item.action != nil
                        itemNode.visibility = .visible(1.0, .infinite)
                        
                        apply(ListViewItemApply())
                    })
                }
            } else {
                var messageNodes: [ListViewItemNode] = []
                for i in 0 ..< items.count {
                    var itemNode: ListViewItemNode?
                    items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, neighbors: ListViewItemNeighbors(previous: i == 0 ? nil : items[i - 1].neighborDescriptor, next: i == (items.count - 1) ? nil : items[i + 1].neighborDescriptor), completion: { node, apply in
                        itemNode = node
                        apply().1(ListViewItemApply())
                    })
                    itemNode!.isUserInteractionEnabled = item.action != nil
                    itemNode!.visibility = .visible(1.0, .infinite)
                    messageNodes.append(itemNode!)
                    
                    if itemNode!.frame.height > 44.0 {
                        self?.initialBubbleHeight = itemNode!.frame.height
                    }
                }
                nodes = messageNodes
            }
            
            let baseContentHeight: CGFloat = item.contentHeight
            var contentSize = CGSize(width: params.width, height: 4.0 + 4.0)
            contentSize.height = baseContentHeight + item.bottomInset
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            if params.width <= 320.0 {
                insets.top = 0.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: .zero)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.isUserInteractionEnabled = item.action != nil
                    
                    if let currentBackgroundNode {
                        currentBackgroundNode.update(wallpaper: item.wallpaper, animated: false)
                        currentBackgroundNode.updateBubbleTheme(bubbleTheme: item.theme, bubbleCorners: item.chatBubbleCorners)
                    }
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                                        
                    strongSelf.messageNodes = nodes
                    var totalHeight: CGFloat = 0.0
                    for node in nodes {
                        let bubbleHeight: CGFloat
                        if node.frame.height > 44.0, let initialBubbleHeight = strongSelf.initialBubbleHeight {
                            bubbleHeight = max(node.frame.height, initialBubbleHeight)
                        } else {
                            bubbleHeight = node.frame.height
                        }
                        totalHeight += bubbleHeight
                    }
                    
                    var visualOriginY: CGFloat = floor((baseContentHeight - totalHeight) / 2.0)
                    if let maximumBubbleBottom = item.maximumBubbleBottom {
                        visualOriginY = min(visualOriginY, maximumBubbleBottom - totalHeight)
                    }
                    var originY = contentSize.height - visualOriginY - totalHeight
                    for node in nodes {
                        if node.supernode == nil {
                            strongSelf.containerNode.addSubnode(node)
                        }
                        let bubbleHeight: CGFloat
//                        if node.frame.height > 44.0, let initialBubbleHeight = strongSelf.initialBubbleHeight {
//                            bubbleHeight = max(node.frame.height, initialBubbleHeight)
//                        } else {
                            bubbleHeight = node.frame.height
//                        }
                        transition.legacyAnimator.transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: 0.0, y: originY), size: node.frame.size))
                        
                        //node.updateFrame(CGRect(origin: CGPoint(x: 0.0, y: originY), size: node.frame.size), within: layoutSize, transition: transition)
                        originY += bubbleHeight
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
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.componentTheme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
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
