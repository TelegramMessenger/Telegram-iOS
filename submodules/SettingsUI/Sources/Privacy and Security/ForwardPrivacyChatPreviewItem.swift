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

class ForwardPrivacyChatPreviewItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sectionId: ItemListSectionId
    let fontSize: PresentationFontSize
    let chatBubbleCorners: PresentationChatBubbleCorners
    let wallpaper: TelegramWallpaper
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let peerName: String
    let linkEnabled: Bool
    let tooltipText: String
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, wallpaper: TelegramWallpaper, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, peerName: String, linkEnabled: Bool, tooltipText: String) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.sectionId = sectionId
        self.fontSize = fontSize
        self.chatBubbleCorners = chatBubbleCorners
        self.wallpaper = wallpaper
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.peerName = peerName
        self.linkEnabled = linkEnabled
        self.tooltipText = tooltipText
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ForwardPrivacyChatPreviewItemNode()
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
            if let nodeValue = node() as? ForwardPrivacyChatPreviewItemNode {
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

class ForwardPrivacyChatPreviewItemNode: ListViewItemNode {
    private var backgroundNode: WallpaperBackgroundNode?
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    
    private var messageNode: ListViewItemNode?
    
    private let tooltipContainerNode: ContextMenuContainerNode
    private let textNode: ImmediateTextNode
    private let measureTextNode: TextNode
    
    private var item: ForwardPrivacyChatPreviewItem?
    
    init() {
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.containerNode = ASDisplayNode()
        self.containerNode.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.tooltipContainerNode = ContextMenuContainerNode()
        self.tooltipContainerNode.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        
        self.measureTextNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.containerNode)
        
        self.tooltipContainerNode.addSubnode(self.textNode)
        
        self.addSubnode(self.tooltipContainerNode)
    }
    
    func asyncLayout() -> (_ item: ForwardPrivacyChatPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentNode = self.messageNode
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)

        var currentBackgroundNode = self.backgroundNode
        
        return { item, params, neighbors in
            if currentBackgroundNode == nil {
                currentBackgroundNode = createWallpaperBackgroundNode(context: item.context, forChatDisplay: false)
            }
            currentBackgroundNode?.update(wallpaper: item.wallpaper)
            currentBackgroundNode?.updateBubbleTheme(bubbleTheme: item.theme, bubbleCorners: item.chatBubbleCorners)
            
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
            
            var peers = SimpleDictionary<PeerId, Peer>()
            let messages = SimpleDictionary<MessageId, Message>()
            
            peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: item.peerName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [])
            
            let forwardInfo = MessageForwardInfo(author: item.linkEnabled ? peers[peerId] : nil, source: nil, sourceMessageId: nil, date: 0, authorSignature: item.linkEnabled ? nil : item.peerName, psaType: nil, flags: [])
            
            let messageItem = item.context.sharedContext.makeChatMessagePreviewItem(context: item.context, messages: [Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: forwardInfo, author: nil, text: item.strings.Privacy_Forwards_PreviewMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil)], theme: item.theme, strings: item.strings, wallpaper: item.wallpaper, fontSize: item.fontSize, chatBubbleCorners: item.chatBubbleCorners, dateTimeFormat: item.dateTimeFormat, nameOrder: item.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: currentBackgroundNode, availableReactions: nil, isCentered: false)
            
            var node: ListViewItemNode?
            if let current = currentNode {
                node = current
                messageItem.updateNode(async: { $0() }, node: { return current }, params: params, previousItem: nil, nextItem: nil, animation: .None, completion: { (layout, apply) in
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
            }
            
            var contentSize = CGSize(width: params.width, height: 8.0 + 8.0)
            if let node = node {
                contentSize.height += node.frame.size.height
            }
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            var authorNameCenter: CGFloat?
            
            let forwardedString = item.strings.Message_ForwardedMessageShort("").string
            var fromString: String?
            if let newlineRange = forwardedString.range(of: "\n") {
                let from = forwardedString[newlineRange.upperBound...]
                if !from.isEmpty {
                    fromString = String(from)
                }
            }
            let authorString = item.peerName
            
            if let fromString = fromString {
                var attributedMeasureText = NSAttributedString(string: fromString, font: Font.regular(13.0), textColor: .black)
                let (fromTextLayout, _) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedMeasureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
                
                let fromWidth = fromTextLayout.size.width
                attributedMeasureText = NSAttributedString(string: authorString, font: Font.regular(13.0), textColor: .black)
                let (authorNameLayout, _) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedMeasureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
                
                let authorNameWidth = authorNameLayout.size.width
                authorNameCenter = fromWidth + authorNameWidth / 2.0 + 3.0
            }
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                    
                    var topOffset: CGFloat = 8.0
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
                    
                    strongSelf.textNode.attributedText = NSAttributedString(string: item.tooltipText, font: Font.regular(14.0), textColor: .white, paragraphAlignment: .center)
                    
                    var textSize = strongSelf.textNode.updateLayout(CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude))
                    textSize.width = ceil(textSize.width / 2.0) * 2.0
                    textSize.height = ceil(textSize.height / 2.0) * 2.0
                    let contentSize = CGSize(width: textSize.width + 12.0, height: textSize.height + 34.0)
                    
                    var sourceRect: CGRect
                    if let messageNode = strongSelf.messageNode as? ChatMessagePreviewItemNode, let forwardInfoNode = messageNode.forwardInfoReferenceNode {
                        sourceRect = forwardInfoNode.convert(forwardInfoNode.bounds, to: strongSelf)
                        if let authorNameCenter = authorNameCenter {
                            sourceRect.origin = CGPoint(x: sourceRect.minX + authorNameCenter, y: sourceRect.minY)
                            sourceRect.size.width = 0.0
                        }
                    } else {
                        sourceRect = CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0), size: CGSize())
                    }
                    
                    let verticalOrigin: CGFloat
                    var arrowOnBottom = true
                    if sourceRect.minY - 54.0 > 0.0 {
                        verticalOrigin = sourceRect.minY - contentSize.height
                    } else {
                        verticalOrigin = min(layout.size.height - contentSize.height, sourceRect.maxY)
                        arrowOnBottom = false
                    }
                    
                    let horizontalOrigin: CGFloat = floor(min(max(params.leftInset + 8.0, sourceRect.midX - contentSize.width / 2.0), layout.size.width - contentSize.width - 8.0))
                    
                    strongSelf.tooltipContainerNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin), size: contentSize)
                    strongSelf.tooltipContainerNode.relativeArrowPosition = (sourceRect.midX - horizontalOrigin, arrowOnBottom)
                    
                    strongSelf.tooltipContainerNode.updateLayout(transition: .immediate)
                    
                    let textFrame = CGRect(origin: CGPoint(x: 6.0, y: 17.0), size: textSize)                    
                    strongSelf.textNode.frame = textFrame
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
