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
import ReactionSelectionNode

class ReactionChatPreviewItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sectionId: ItemListSectionId
    let fontSize: PresentationFontSize
    let chatBubbleCorners: PresentationChatBubbleCorners
    let wallpaper: TelegramWallpaper
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let availableReactions: AvailableReactions?
    let reaction: String?
    let toggleReaction: () -> Void
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, wallpaper: TelegramWallpaper, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, availableReactions: AvailableReactions?, reaction: String?, toggleReaction: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sectionId = sectionId
        self.fontSize = fontSize
        self.chatBubbleCorners = chatBubbleCorners
        self.wallpaper = wallpaper
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.availableReactions = availableReactions
        self.reaction = reaction
        self.toggleReaction = toggleReaction
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ReactionChatPreviewItemNode()
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ReactionChatPreviewItemNode {
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
}

class ReactionChatPreviewItemNode: ListViewItemNode {
    private var backgroundNode: WallpaperBackgroundNode?
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    
    private var messageNode: ListViewItemNode?
    
    private var item: ReactionChatPreviewItem?
    private(set) weak var standaloneReactionAnimation: StandaloneReactionAnimation?
    
    init() {
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.containerNode = ASDisplayNode()
        self.containerNode.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.containerNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForDoubleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .doubleTap:
                    self.item?.toggleReaction()
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.view
        } else {
            return nil
        }
    }
    
    private func beginReactionAnimation() {
        if let item = self.item, let updatedReaction = item.reaction, let availableReactions = item.availableReactions, let messageNode = self.messageNode as? ChatMessageItemNodeProtocol {
            if let targetView = messageNode.targetReactionView(value: updatedReaction) {
                for reaction in availableReactions.reactions {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if reaction.value == updatedReaction {
                        if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                            standaloneReactionAnimation.cancel()
                            standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                                standaloneReactionAnimation?.removeFromSupernode()
                            })
                            self.standaloneReactionAnimation = nil
                        }
                        
                        if let supernode = self.supernode {
                            let standaloneReactionAnimation = StandaloneReactionAnimation()
                            self.standaloneReactionAnimation = standaloneReactionAnimation
                            
                            supernode.addSubnode(standaloneReactionAnimation)
                            standaloneReactionAnimation.frame = supernode.bounds
                            standaloneReactionAnimation.animateReactionSelection(
                                context: item.context, theme: item.theme, reaction: ReactionItem(
                                    reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                    appearAnimation: reaction.appearAnimation,
                                    stillAnimation: reaction.selectAnimation,
                                    listAnimation: centerAnimation,
                                    largeListAnimation: reaction.activateAnimation,
                                    applicationAnimation: aroundAnimation,
                                    largeApplicationAnimation: reaction.effectAnimation
                                ),
                                avatarPeers: [],
                                playHaptic: false,
                                isLarge: false,
                                targetView: targetView,
                                addStandaloneReactionAnimation: nil,
                                completion: { [weak standaloneReactionAnimation] in
                                standaloneReactionAnimation?.removeFromSupernode()
                                }
                            )
                        }
                        
                        break
                    }
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: ReactionChatPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentNode = self.messageNode

        let previousItem = self.item
        var currentBackgroundNode = self.backgroundNode
        
        return { item, params, neighbors in
            if currentBackgroundNode == nil {
                currentBackgroundNode = createWallpaperBackgroundNode(context: item.context, forChatDisplay: false)
            }
            currentBackgroundNode?.update(wallpaper: item.wallpaper)
            currentBackgroundNode?.updateBubbleTheme(bubbleTheme: item.theme, bubbleCorners: item.chatBubbleCorners)
            
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2))
            let chatPeerId = userPeerId
            
            var peers = SimpleDictionary<PeerId, Peer>()
            let messages = SimpleDictionary<MessageId, Message>()
            
            peers[userPeerId] = TelegramUser(id: userPeerId, accessHash: nil, firstName: item.strings.Settings_QuickReactionSetup_DemoMessageAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
            
            let messageText = item.strings.Settings_QuickReactionSetup_DemoMessageText
            
            var attributes: [MessageAttribute] = []
            if let reaction = item.reaction {
                attributes.append(ReactionsMessageAttribute(canViewList: false, reactions: [MessageReaction(value: reaction, count: 1, isSelected: true)], recentPeers: []))
            }
            
            let messageItem = item.context.sharedContext.makeChatMessagePreviewItem(context: item.context, messages: [Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: chatPeerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[userPeerId], text: messageText, attributes: attributes, media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])], theme: item.theme, strings: item.strings, wallpaper: item.wallpaper, fontSize: item.fontSize, chatBubbleCorners: item.chatBubbleCorners, dateTimeFormat: item.dateTimeFormat, nameOrder: item.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: currentBackgroundNode, availableReactions: item.availableReactions, isCentered: true)
            
            var node: ListViewItemNode?
            if let current = currentNode {
                node = current
                messageItem.updateNode(async: { $0() }, node: { return current }, params: params, previousItem: nil, nextItem: nil, animation: .System(duration: 0.3, transition: ControlledTransition(duration: 0.3, curve: .easeInOut, interactive: false)), completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: current.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                    
                    current.contentSize = layout.contentSize
                    current.insets = layout.insets
                    current.frame = nodeFrame
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            } else {
                messageItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { messageNode, apply in
                    node = messageNode
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                node?.isUserInteractionEnabled = false
            }
            
            var contentSize = CGSize(width: params.width, height: 16.0 + 16.0)
            if let node = node {
                contentSize.height += node.frame.size.height
            }
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    if let previousItem = strongSelf.item, previousItem.reaction != item.reaction {
                        if let standaloneReactionAnimation = strongSelf.standaloneReactionAnimation {
                            standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak standaloneReactionAnimation] _ in
                                standaloneReactionAnimation?.removeFromSupernode()
                            })
                            strongSelf.standaloneReactionAnimation = nil
                        }
                    }
                       
                    strongSelf.item = item
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                    
                    var topOffset: CGFloat = 16.0
                    if let node = node {
                        strongSelf.messageNode = node
                        if node.supernode == nil {
                            strongSelf.containerNode.addSubnode(node)
                        }
                        node.updateFrame(CGRect(origin: CGPoint(x: 0.0, y: topOffset), size: node.frame.size), within: layout.contentSize)
                        
                        topOffset += node.frame.size.height
                    }

                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                    if let currentBackgroundNode = currentBackgroundNode, strongSelf.backgroundNode !== currentBackgroundNode {
                        strongSelf.backgroundNode = currentBackgroundNode
                        strongSelf.insertSubnode(currentBackgroundNode, at: 0)
                    }

                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
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
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))

                    if let backgroundNode = strongSelf.backgroundNode {
                        backgroundNode.frame = backgroundFrame.insetBy(dx: 0.0, dy: -100.0)
                        backgroundNode.update(wallpaper: item.wallpaper)
                        backgroundNode.updateBubbleTheme(bubbleTheme: item.theme, bubbleCorners: item.chatBubbleCorners)
                        backgroundNode.updateLayout(size: backgroundNode.bounds.size, transition: .immediate)
                    }

                    strongSelf.maskNode.frame = backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    if let previousItem = previousItem, previousItem.reaction != item.reaction {
                        strongSelf.beginReactionAnimation()
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
