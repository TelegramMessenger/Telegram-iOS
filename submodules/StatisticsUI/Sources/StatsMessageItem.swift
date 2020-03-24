import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import PhotoResources

public class StatsMessageItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let message: Message
    let views: Int32
    let forwards: Int32
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let action: (() -> Void)?
    
    init(context: AccountContext, presentationData: ItemListPresentationData, message: Message, views: Int32, forwards: Int32, sectionId: ItemListSectionId, style: ItemListStyle, action: (() -> Void)?) {
        self.context = context
        self.presentationData = presentationData
        self.message = message
        self.views = views
        self.forwards = forwards
        self.sectionId = sectionId
        self.style = style
        self.action = action
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
        self.action?()
    }
}


private let badgeFont = Font.regular(15.0)

public class StatsMessageItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    let contentImageNode: TransformImageNode
    let titleNode: TextNode
    let labelNode: TextNode
    let viewsNode: TextNode
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
        
        self.contentImageNode = TransformImageNode()
        self.contentImageNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

        self.viewsNode = TextNode()
        self.viewsNode.isUserInteractionEnabled = false
        
        self.forwardsNode = TextNode()
        self.forwardsNode.isUserInteractionEnabled = false
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.contentImageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.viewsNode)
        self.addSubnode(self.forwardsNode)
        
        self.addSubnode(self.activateArea)
    }
    
    public func asyncLayout() -> (_ item: StatsMessageItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeViewsLayout = TextNode.asyncLayout(self.viewsNode)
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
            let additionalRightInset: CGFloat = 93.0
        
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            let contentKind = messageContentKind(contentSettings: item.context.currentContentSettings.with { $0 }, message: item.message, strings: item.presentationData.strings, nameDisplayOrder: .firstLast, accountPeerId: item.context.account.peerId)
            var text = !item.message.text.isEmpty ? item.message.text : stringForMediaKind(contentKind, strings: item.presentationData.strings).0
            text = foldLineBreaks(text)
            
            var contentImageMedia: Media?
            for media in item.message.media {
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
            
            if let _ = contentImageMedia {
                totalLeftInset += 48.0
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let contentImageMedia = contentImageMedia {
                if let currentContentImageMedia = currentContentImageMedia, contentImageMedia.isSemanticallyEqual(to: currentContentImageMedia) {
                } else {
                    if let image = contentImageMedia as? TelegramMediaImage {
                        updateImageSignal = mediaGridMessagePhoto(account: item.context.account, photoReference: .message(message: MessageReference(item.message), media: image))
                    } else if let file = contentImageMedia as? TelegramMediaFile {
                        updateImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, videoReference: .message(message: MessageReference(item.message), media: file), autoFetchFullSizeThumbnail: true)
                    }
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - totalLeftInset - rightInset - additionalRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        
            let labelFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
            
            let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
            let label = stringForFullDate(timestamp: item.message.timestamp, strings: item.presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: label, font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - totalLeftInset - rightInset - additionalRightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (viewsLayout, viewsApply) = makeViewsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_MessageViews(item.views), font: labelFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .right, cutout: nil, insets: UIEdgeInsets()))
            
            let (forwardsLayout, forwardsApply) = makeForwardsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Stats_MessageForwards(item.forwards), font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: CGFloat.greatestFiniteMagnitude), alignment: .right, cutout: nil, insets: UIEdgeInsets()))
            
            let verticalInset: CGFloat = 11.0
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
                insets = itemListNeighborsGroupedInsets(neighbors)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = text
                    strongSelf.activateArea.accessibilityValue = label
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    var dimensions: CGSize?
                    if let contentImageMedia = contentImageMedia as? TelegramMediaImage {
                        dimensions = largestRepresentationForPhoto(contentImageMedia)?.dimensions.cgSize
                    } else if let contentImageMedia = contentImageMedia as? TelegramMediaFile {
                        dimensions = contentImageMedia.dimensions?.cgSize
                    }
                    
                    let contentImageSize = CGSize(width: 40.0, height: 40.0)
                    
                    var contentImageNodeAppeared = false
                    if let dimensions = dimensions {
                        let makeImageLayout = strongSelf.contentImageNode.asyncLayout()
                        let imageSize = contentImageSize
                        
                        let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: dimensions.aspectFilled(imageSize), boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
                        applyImageLayout()
                        
                        if let updateImageSignal = updateImageSignal {
                            strongSelf.contentImageNode.setSignal(updateImageSignal)
                            if currentContentImageMedia == nil {
                                strongSelf.contentImageNode.isHidden = false
                                contentImageNodeAppeared = true
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
                                bottomStripeInset = leftInset
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
                    
                    let contentImageFrame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((height - contentImageSize.height) / 2.0)), size: contentImageSize)
                    strongSelf.contentImageNode.frame = contentImageFrame
                    
                    let titleFrame = CGRect(origin: CGPoint(x: totalLeftInset, y: 11.0), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                                        
                    let labelFrame = CGRect(origin: CGPoint(x: totalLeftInset, y: titleFrame.maxY + titleSpacing), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    
                    let viewsFrame = CGRect(origin: CGPoint(x: params.width - rightInset - viewsLayout.size.width, y: 15.0), size: viewsLayout.size)
                    strongSelf.viewsNode.frame = viewsFrame
                    
                    let forwardsFrame = CGRect(origin: CGPoint(x: params.width - rightInset - forwardsLayout.size.width, y: titleFrame.maxY + titleSpacing), size: forwardsLayout.size)
                    strongSelf.forwardsNode.frame = forwardsFrame
 
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: height + UIScreenPixel))
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

