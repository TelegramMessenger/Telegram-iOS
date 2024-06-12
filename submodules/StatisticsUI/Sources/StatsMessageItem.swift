import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import PhotoResources
import AvatarStoryIndicatorComponent
import AvatarNode

public class StatsMessageItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let peer: Peer
    let item: StatsPostItem
    let views: Int32
    let reactions: Int32
    let forwards: Int32
    let isPeer: Bool
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let action: (() -> Void)?
    let openStory: (UIView) -> Void
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init(context: AccountContext, presentationData: ItemListPresentationData, peer: Peer, item: StatsPostItem, views: Int32, reactions: Int32, forwards: Int32, isPeer: Bool = false, sectionId: ItemListSectionId, style: ItemListStyle, action: (() -> Void)?, openStory: @escaping (UIView) -> Void, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?) {
        self.context = context
        self.presentationData = presentationData
        self.peer = peer
        self.item = item
        self.views = views
        self.reactions = reactions
        self.forwards = forwards
        self.isPeer = isPeer
        self.sectionId = sectionId
        self.style = style
        self.action = action
        self.openStory = openStory
        self.contextAction = contextAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = StatsMessageItemNode()
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
            if let nodeValue = node() as? StatsMessageItemNode {
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
    
    public var selectable: Bool = true
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
    }
}


private let badgeFont = Font.regular(15.0)

final class StatsMessageItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode
    private let countersContainerNode: ASDisplayNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    var avatarNode: AvatarNode?
    let contentImageNode: TransformImageNode
    var storyIndicator: ComponentView<Empty>?
    var storyButton: HighlightTrackingButton?
    
    let titleNode: TextNode
    let labelNode: TextNode
    let viewsNode: TextNode
    
    let reactionsIconNode: ASImageNode
    let reactionsNode: TextNode
    let forwardsIconNode: ASImageNode
    let forwardsNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: StatsMessageItem?
    private var contentImageMedia: Media?
    
    override public var canBeSelected: Bool {
        return true
    }
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.contentImageNode = TransformImageNode()
        self.contentImageNode.isLayerBacked = false
        
        self.offsetContainerNode = ASDisplayNode()
        self.countersContainerNode = ASDisplayNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

        self.viewsNode = TextNode()
        self.viewsNode.isUserInteractionEnabled = false
        
        self.forwardsNode = TextNode()
        self.forwardsNode.isUserInteractionEnabled = false
        
        self.forwardsIconNode = ASImageNode()
        self.forwardsIconNode.displaysAsynchronously = false
        
        self.reactionsNode = TextNode()
        self.reactionsNode.isUserInteractionEnabled = false
        
        self.reactionsIconNode = ASImageNode()
        self.reactionsIconNode.displaysAsynchronously = false
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.contextSourceNode.contentNode.addSubnode(self.countersContainerNode)
        
        self.offsetContainerNode.addSubnode(self.contentImageNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.labelNode)
        self.countersContainerNode.addSubnode(self.viewsNode)
        self.countersContainerNode.addSubnode(self.forwardsNode)
        self.countersContainerNode.addSubnode(self.forwardsIconNode)
        self.countersContainerNode.addSubnode(self.reactionsNode)
        self.countersContainerNode.addSubnode(self.reactionsIconNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        
        self.addSubnode(self.activateArea)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.itemBlocksBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
                        
            transition.updateAlpha(node: strongSelf.countersContainerNode, alpha: isExtracted ? 0.0 : 1.0)

            transition.updateSublayerTransformOffset(layer: strongSelf.countersContainerNode.layer, offset: CGPoint(x: isExtracted ? -16.0 : 0.0, y: 0.0))
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 16.0 : 0.0, y: 0.0))
                       
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result
    }
    
    override func selected() {
        guard let item = self.item else {
            return
        }
        if item.isPeer {
            if case .story = item.item {
                self.storyPressed()
            } else {
                item.action?()
            }
        } else {
            item.action?()
        }
    }
    
    @objc private func storyPressed() {
        guard let item = self.item else {
            return
        }
        if let avatarNode = self.avatarNode {
            item.openStory(avatarNode.view)
        } else {
            item.openStory(self.contentImageNode.view)
        }
    }
    
    public func asyncLayout() -> (_ item: StatsMessageItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeViewsLayout = TextNode.asyncLayout(self.viewsNode)
        let makeReactionsLayout = TextNode.asyncLayout(self.reactionsNode)
        let makeForwardsLayout = TextNode.asyncLayout(self.forwardsNode)
        
        let currentItem = self.item
        let currentContentImageMedia = self.contentImageMedia
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
                      
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
                        
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset
            let rightInset = 16.0 + params.rightInset
            var totalLeftInset = leftInset
        
            let titleFont = Font.semibold(item.presentationData.fontSize.itemListBaseFontSize)
            let labelFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
            
            let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
            
            var text: String
            var contentImageMedia: Media?
            let timestamp: Int32
            
            switch item.item {
            case let .message(message):
                let contentKind: MessageContentKind
                contentKind = messageContentKind(contentSettings: item.context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: .firstLast,  dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: item.context.account.peerId)
                text = !message.text.isEmpty ? message.text : stringForMediaKind(contentKind, strings: item.presentationData.strings).0.string
                
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        contentImageMedia = image
                        break
                    } else if let file = media as? TelegramMediaFile {
                        if file.isVideo && !file.isInstantVideo {
                            contentImageMedia = file
                            break
                        }
                    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                        if let image = content.image {
                            contentImageMedia = image
                            break
                        } else if let file = content.file {
                            if file.isVideo && !file.isInstantVideo {
                                contentImageMedia = file
                                break
                            }
                        }
                    }
                }
                timestamp = message.timestamp
            case let .story(_, story):
                text = item.presentationData.strings.Message_Story
                timestamp = story.timestamp
                if let image = story.media._asMedia() as? TelegramMediaImage {
                    contentImageMedia = image
                    break
                } else if let file = story.media._asMedia() as? TelegramMediaFile {
                    contentImageMedia = file
                    break
                }
            }
            
            if item.isPeer {
                text = EnginePeer(item.peer).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
            } else {
                text = foldLineBreaks(text)
            }
            
            if contentImageMedia != nil || item.isPeer {
                totalLeftInset += 46.0
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let contentImageMedia = contentImageMedia {
                if let currentContentImageMedia = currentContentImageMedia, contentImageMedia.isSemanticallyEqual(to: currentContentImageMedia) {
                } else {
                    switch item.item {
                    case let .message(message):
                        if let image = contentImageMedia as? TelegramMediaImage {
                            updateImageSignal = mediaGridMessagePhoto(account: item.context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(message), media: image))
                        } else if let file = contentImageMedia as? TelegramMediaFile {
                            updateImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, userLocation: .peer(message.id.peerId), videoReference: .message(message: MessageReference(message), media: file), autoFetchFullSizeThumbnail: true)
                        }
                    case let .story(_, story):
                        if let peerReference = PeerReference(item.peer) {
                            if let image = contentImageMedia as? TelegramMediaImage {
                                updateImageSignal = mediaGridMessagePhoto(account: item.context.account, userLocation: .peer(item.peer.id), photoReference: .story(peer: peerReference, id: story.id, media: image))
                            } else if let file = contentImageMedia as? TelegramMediaFile {
                                updateImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, userLocation: .peer(item.peer.id), videoReference: .story(peer: peerReference, id: story.id, media: file), autoFetchFullSizeThumbnail: true)
                            }
                        }
                    }
                }
            }
            
            let viewsString: String
            if item.views == 0 {
                viewsString = item.presentationData.strings.Stats_MessageViews_NoViews
            } else {
                viewsString = item.presentationData.strings.Stats_MessageViews(item.views)
            }
            let (viewsLayout, viewsApply) = makeViewsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: viewsString, font: labelFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 128.0, height: CGFloat.greatestFiniteMagnitude), alignment: .right, cutout: nil, insets: UIEdgeInsets()))
            
            let reactions = item.reactions > 0 ? compactNumericCountString(Int(item.reactions), decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator) : ""
            let (reactionsLayout, reactionsApply) = makeReactionsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: reactions, font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 128.0, height: CGFloat.greatestFiniteMagnitude), alignment: .right, cutout: nil, insets: UIEdgeInsets()))
            
            let forwards = item.forwards > 0 ? compactNumericCountString(Int(item.forwards), decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator) : ""
            let (forwardsLayout, forwardsApply) = makeForwardsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: forwards, font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 128.0, height: CGFloat.greatestFiniteMagnitude), alignment: .right, cutout: nil, insets: UIEdgeInsets()))
            
            let additionalRightInset = max(viewsLayout.size.width, reactionsLayout.size.width + forwardsLayout.size.width + 36.0) + 8.0
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - totalLeftInset - rightInset - additionalRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                                    
            let label = stringForMediumDate(timestamp: timestamp, strings: item.presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: label, font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - totalLeftInset - rightInset - additionalRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let verticalInset: CGFloat = 10.0
            let titleSpacing: CGFloat = 3.0
            
            let height: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + labelLayout.size.height
         
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                contentSize = CGSize(width: params.width, height: height)
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    let themeUpdated = strongSelf.item?.presentationData.theme !== item.presentationData.theme
                    strongSelf.item = item
                    
                    if themeUpdated {
                        strongSelf.forwardsIconNode.image = PresentationResourcesItemList.statsForwardsIcon(item.presentationData.theme)
                        strongSelf.reactionsIconNode.image = PresentationResourcesItemList.statsReactionsIcon(item.presentationData.theme)
                    }
                    
                    let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width - 16.0, height: layout.contentSize.height))
                    let extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    if strongSelf.contextSourceNode.isExtractedToContextPreview {
                        strongSelf.extractedBackgroundImageNode.frame = extractedRect
                    } else {
                        strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                    }
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.countersContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = text
                    strongSelf.activateArea.accessibilityValue = label
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    var contentImageSize = CGSize(width: 40.0, height: 40.0)
                    
                    var contentImageInset = leftInset - 6.0
                    var dimensions: CGSize?
                    if item.isPeer {
                        let avatarNode: AvatarNode
                        if let current = strongSelf.avatarNode {
                            avatarNode = current
                        } else {
                            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0)))
                            strongSelf.offsetContainerNode.addSubnode(avatarNode)
                            strongSelf.avatarNode = avatarNode
                        }
                        avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(item.peer))
                        
                        if case .story = item.item {
                            contentImageInset += 3.0
                            contentImageSize = CGSize(width: 34.0, height: 34.0)
                        }
                    } else {
                        strongSelf.avatarNode?.removeFromSupernode()
                        strongSelf.avatarNode = nil
                        
                        if let contentImageMedia = contentImageMedia as? TelegramMediaImage {
                            dimensions = largestRepresentationForPhoto(contentImageMedia)?.dimensions.cgSize
                        } else if let contentImageMedia = contentImageMedia as? TelegramMediaFile {
                            dimensions = contentImageMedia.dimensions?.cgSize
                        }
                    }
                
                    if let dimensions = dimensions {
                        let makeImageLayout = strongSelf.contentImageNode.asyncLayout()
                        
                        let cornerRadius: CGFloat
                        if case .story = item.item {
                            contentImageInset += 3.0
                            contentImageSize = CGSize(width: 34.0, height: 34.0)
                            cornerRadius = contentImageSize.width / 2.0
                        } else {
                            cornerRadius = 6.0
                        }
                        
                        let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(radius: cornerRadius), imageSize: dimensions.aspectFilled(contentImageSize), boundingSize: contentImageSize, intrinsicInsets: UIEdgeInsets()))
                        applyImageLayout()
                        
                        if let updateImageSignal = updateImageSignal {
                            strongSelf.contentImageNode.setSignal(updateImageSignal)
                            if currentContentImageMedia == nil {
                                strongSelf.contentImageNode.isHidden = false
                            }
                        }
                    } else {
                        if currentContentImageMedia != nil {
                            strongSelf.contentImageNode.removeFromSupernode()
                            strongSelf.contentImageNode.setSignal(.single({ _ in nil }))
                            strongSelf.contentImageNode.isHidden = true
                        }
                    }
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    let _ = viewsApply()
                    let _ = forwardsApply()
                    let _ = reactionsApply()
                    
                    switch item.style {
                    case .plain:
                        if strongSelf.backgroundNode.supernode != nil {
                            strongSelf.backgroundNode.removeFromSupernode()
                        }
                        if strongSelf.topStripeNode.supernode != nil {
                            strongSelf.topStripeNode.removeFromSupernode()
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                        }
                        if strongSelf.maskNode.supernode != nil {
                            strongSelf.maskNode.removeFromSupernode()
                        }
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    case .blocks:
                        if strongSelf.backgroundNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
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
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = totalLeftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let contentImageFrame = CGRect(origin: CGPoint(x: contentImageInset, y: floorToScreenPixels((height - contentImageSize.height) / 2.0)), size: contentImageSize)
                    strongSelf.contentImageNode.frame = contentImageFrame
                    
                    if let avatarNode = strongSelf.avatarNode {
                        avatarNode.frame = contentImageFrame
                    }
                    
                    let titleFrame = CGRect(origin: CGPoint(x: totalLeftInset, y: 9.0), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                                        
                    let labelFrame = CGRect(origin: CGPoint(x: totalLeftInset, y: titleFrame.maxY + titleSpacing), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    
                    let viewsOriginY: CGFloat = forwardsLayout.size.width > 0.0 || reactionsLayout.size.width > 0.0 ? 13.0 : floorToScreenPixels((contentSize.height - viewsLayout.size.height) / 2.0)
                    let viewsFrame = CGRect(origin: CGPoint(x: params.width - rightInset - viewsLayout.size.width, y: viewsOriginY), size: viewsLayout.size)
                    strongSelf.viewsNode.frame = viewsFrame
                    
                    let iconSpacing: CGFloat = 3.0 - UIScreenPixel
                    
                    var rightContentInset: CGFloat = rightInset
                    if forwardsLayout.size.width > 0.0 {
                        strongSelf.forwardsIconNode.isHidden = false
                        strongSelf.forwardsNode.isHidden = false
                        
                        let forwardsFrame = CGRect(origin: CGPoint(x: params.width - rightContentInset - forwardsLayout.size.width, y: titleFrame.maxY + titleSpacing), size: forwardsLayout.size)
                        strongSelf.forwardsNode.frame = forwardsFrame
                        
                        if let icon = strongSelf.forwardsIconNode.image {
                            let forwardsIconFrame = CGRect(origin: CGPoint(x: params.width - rightContentInset - forwardsLayout.size.width - icon.size.width - iconSpacing, y: titleFrame.maxY + titleSpacing - 2.0 + UIScreenPixel), size: icon.size)
                            strongSelf.forwardsIconNode.frame = forwardsIconFrame
                            
                            rightContentInset += forwardsIconFrame.width + forwardsFrame.width + iconSpacing
                        }
                        rightContentInset += 10.0
                    } else {
                        strongSelf.forwardsIconNode.isHidden = true
                        strongSelf.forwardsNode.isHidden = true
                    }
                    
                    if reactionsLayout.size.width > 0.0 {
                        strongSelf.reactionsIconNode.isHidden = false
                        strongSelf.reactionsNode.isHidden = false
                        
                        let reactionsFrame = CGRect(origin: CGPoint(x: params.width - rightContentInset - reactionsLayout.size.width, y: titleFrame.maxY + titleSpacing), size: reactionsLayout.size)
                        strongSelf.reactionsNode.frame = reactionsFrame
                        
                        if let icon = strongSelf.reactionsIconNode.image {
                            let reactionsIconFrame = CGRect(origin: CGPoint(x: params.width - rightContentInset - reactionsLayout.size.width - icon.size.width - iconSpacing, y: titleFrame.maxY + titleSpacing - 2.0 + UIScreenPixel), size: icon.size)
                            strongSelf.reactionsIconNode.frame = reactionsIconFrame
                            
                            rightContentInset += reactionsIconFrame.width + reactionsFrame.width + iconSpacing
                        }
                    } else {
                        strongSelf.reactionsIconNode.isHidden = true
                        strongSelf.reactionsNode.isHidden = true
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: height + UIScreenPixel))
                    
                    if case .story = item.item {
                        let lineWidth: CGFloat = 1.5
                        let imageSize = CGSize(width: contentImageFrame.width + 6.0, height: contentImageFrame.height + 6.0)
                        let indicatorSize = CGSize(width: imageSize.width - lineWidth * 4.0, height: imageSize.height - lineWidth * 4.0)

                        let storyIndicator: ComponentView<Empty>
                        let indicatorTransition: ComponentTransition = .immediate
                        if let current = strongSelf.storyIndicator {
                            storyIndicator = current
                        } else {
                            storyIndicator = ComponentView()
                            strongSelf.storyIndicator = storyIndicator
                        }
                        let _ = storyIndicator.update(
                            transition: indicatorTransition,
                            component: AnyComponent(AvatarStoryIndicatorComponent(
                                hasUnseen: true,
                                hasUnseenCloseFriendsItems: false,
                                colors: AvatarStoryIndicatorComponent.Colors(
                                    unseenColors: item.presentationData.theme.chatList.storyUnseenColors.array,
                                    unseenCloseFriendsColors: item.presentationData.theme.chatList.storyUnseenPrivateColors.array,
                                    seenColors: item.presentationData.theme.chatList.storySeenColors.array
                                ),
                                activeLineWidth: lineWidth,
                                inactiveLineWidth: lineWidth,
                                counters: AvatarStoryIndicatorComponent.Counters(
                                    totalCount: 1,
                                    unseenCount: 1
                                ),
                                progress: nil
                            )),
                            environment: {},
                            containerSize: indicatorSize
                        )
                        let storyIndicatorFrame = CGRect(origin: CGPoint(x: contentImageFrame.midX - indicatorSize.width / 2.0, y: contentImageFrame.midY - indicatorSize.height / 2.0), size: indicatorSize)
                        if let storyIndicatorView = storyIndicator.view {
                            if storyIndicatorView.superview == nil {
                                strongSelf.offsetContainerNode.view.addSubview(storyIndicatorView)
                            }
                            indicatorTransition.setFrame(view: storyIndicatorView, frame: storyIndicatorFrame)
                        }
                        
                        let storyButton: HighlightTrackingButton
                        if let current = strongSelf.storyButton {
                            storyButton = current
                        } else {
                            storyButton = HighlightTrackingButton()
                            storyButton.addTarget(strongSelf, action: #selector(strongSelf.storyPressed), for: .touchUpInside)
                            strongSelf.view.addSubview(storyButton)
                            strongSelf.storyButton = storyButton
                        }
                        storyButton.frame = storyIndicatorFrame
                    } else if let storyIndicator = strongSelf.storyIndicator {
                        if let storyIndicatorView = storyIndicator.view {
                            storyIndicatorView.removeFromSuperview()
                        }
                        strongSelf.storyIndicator = nil
                        
                        if let storyButton = strongSelf.storyButton {
                            storyButton.removeFromSuperview()
                            strongSelf.storyButton = nil
                        }
                    }
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        var highlighted = highlighted
        if let avatarButton = self.storyButton, avatarButton.bounds.contains(self.view.convert(point, to: storyButton)) {
            highlighted = false
        }
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
