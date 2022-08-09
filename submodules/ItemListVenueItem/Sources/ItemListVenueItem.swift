import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import LocationResources
import ShimmerEffect

public final class ItemListVenueItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let engine: TelegramEngine
    let venue: TelegramMediaMap?
    let title: String?
    let subtitle: String?
    let style: ItemListStyle
    let action: (() -> Void)?
    let infoAction: (() -> Void)?
    
    public let sectionId: ItemListSectionId
    let header: ListViewItemHeader?
    
    public init(presentationData: ItemListPresentationData, engine: TelegramEngine, venue: TelegramMediaMap?, title: String? = nil, subtitle: String? = nil, sectionId: ItemListSectionId = 0, style: ItemListStyle, action: (() -> Void)?, infoAction: (() -> Void)? = nil, header: ListViewItemHeader? = nil) {
        self.presentationData = presentationData
        self.engine = engine
        self.venue = venue
        self.title = title
        self.subtitle = subtitle
        self.sectionId = sectionId
        self.style = style
        self.action = action
        self.infoAction = infoAction
        self.header = header
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            var firstWithHeader = false
            var last = false
            if self.style == .plain {
                if previousItem == nil {
                    firstWithHeader = true
                } else if let previousItem = previousItem as? ItemListVenueItem, self.header != nil && previousItem.header?.id != self.header?.id {
                    firstWithHeader = true
                }
                if nextItem == nil {
                    last = true
                } else if let nextItem = nextItem as? ItemListVenueItem, self.header != nil && nextItem.header?.id != self.header?.id {
                    last = true
                }
            }
            let node = ItemListVenueItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), firstWithHeader, last)
            
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
            if let nodeValue = node() as? ItemListVenueItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    var firstWithHeader = false
                    var last = false
                    if self.style == .plain {
                        if previousItem == nil {
                            firstWithHeader = true
                        } else if let previousItem = previousItem as? ItemListVenueItem, self.header != nil && previousItem.header?.id != self.header?.id {
                            firstWithHeader = true
                        }
                        if nextItem == nil {
                            last = true
                        } else if let nextItem = nextItem as? ItemListVenueItem, self.header != nil && nextItem.header?.id != self.header?.id {
                            last = true
                        }
                    }
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), firstWithHeader, last)
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

public class ItemListVenueItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let iconNode: TransformImageNode
    private let titleNode: TextNode
    private let addressNode: TextNode
    private let infoButton: HighlightableButtonNode
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var item: ItemListVenueItem?
    private var layoutParams: (ItemListVenueItem, ListViewItemLayoutParams, ItemListNeighbors, Bool, Bool)?
    
    public var tag: ItemListItemTag?
    
    override public var canBeSelected: Bool {
        if let item = self.layoutParams?.0, let _ = item.action {
            return true
        } else {
            return false
        }
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.iconNode = TransformImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
    
        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        self.addressNode.contentMode = .left
        self.addressNode.contentsScale = UIScreen.main.scale
        
        self.infoButton = HighlightableButtonNode()
    
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.addressNode)
        self.addSubnode(self.infoButton)
        self.addSubnode(self.iconNode)
        
        self.infoButton.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    public func asyncLayout() -> (_ item: ItemListVenueItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors, _ firstWithHeader: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        let iconLayout = self.iconNode.asyncLayout()
        
        let currentItem = self.layoutParams?.0
                
        return { item, params, neighbors, firstWithHeader, last in
            var updatedTheme: PresentationTheme?
            var updatedVenueType: String?
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let addressFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
        
            let venueType = item.venue?.venue?.type ?? ""
            if currentItem?.venue?.venue?.type != venueType {
                updatedVenueType = venueType
            }
        
            let title: String
            if let venueTitle = item.venue?.venue?.title {
                title = venueTitle
            } else if let customTitle = item.title {
                title = customTitle
            } else {
                title = " "
            }
            
            let subtitle: String
            if let address = item.venue?.venue?.address {
                subtitle = address
            } else if let customSubtitle = item.subtitle {
                subtitle = customSubtitle
            } else {
                subtitle = " "
            }
            
            let titleAttributedString = NSAttributedString(string: title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let addressAttributedString = NSAttributedString(string: subtitle, font: addressFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset + (item.infoAction != nil ? 48.0 : 0.0)
            let verticalInset: CGFloat = addressAttributedString.string.isEmpty ? 14.0 : 8.0
            let iconSize: CGFloat = 40.0
           
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (addressLayout, addressApply) = makeAddressLayout(TextNodeLayoutArguments(attributedString: addressAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + addressLayout.size.height
            
            var insets: UIEdgeInsets
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    insets = itemListNeighborsPlainInsets(neighbors)
                    insets.top = firstWithHeader ? 29.0 : 0.0
                    insets.bottom = 0.0
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = (item, params, neighbors, firstWithHeader, last)
                                        
                    strongSelf.accessibilityLabel = titleAttributedString.string
                    strongSelf.accessibilityValue = addressAttributedString.string
                     
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        strongSelf.infoButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoIcon"), color: item.presentationData.theme.list.itemAccentColor), for: .normal)
                    }
                                        
                    let transition = ContainedViewLayoutTransition.immediate
                                        
                    let _ = titleApply()
                    let _ = addressApply()
                    
                    if let updatedVenueType = updatedVenueType {
                        strongSelf.iconNode.setSignal(venueIcon(engine: item.engine, type: updatedVenueType, background: true))
                    }
                    
                    let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: iconSize, height: iconSize), boundingSize: CGSize(width: iconSize, height: iconSize), intrinsicInsets: UIEdgeInsets()))
                    iconApply()
                    
                    let placeholderBackgroundColor: UIColor
                    
                    switch item.style {
                        case .plain:
                            placeholderBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
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
                            
                            let stripeInset: CGFloat
                            if case .none = neighbors.bottom {
                                stripeInset = 0.0
                            } else {
                                stripeInset = leftInset
                            }
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: stripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - stripeInset, height: separatorHeight))
                            strongSelf.bottomStripeNode.isHidden = last
                        case .blocks:
                            placeholderBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
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
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.addressNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + titleLayout.size.height + titleSpacing), size: addressLayout.size))
                    
                    transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: floorToScreenPixels((layout.contentSize.height - iconSize) / 2.0)), size: CGSize(width: iconSize, height: iconSize)))
                    
                    transition.updateFrame(node: strongSelf.infoButton, frame: CGRect(x: layout.contentSize.width - params.rightInset - 60.0, y: 0.0, width: 60.0, height: layout.contentSize.height))
                    strongSelf.infoButton.isHidden = item.infoAction == nil
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    if item.venue == nil {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            if strongSelf.bottomStripeNode.supernode != nil {
                                
                                strongSelf.insertSubnode(shimmerNode, belowSubnode: strongSelf.bottomStripeNode)
                            } else {
                                strongSelf.addSubnode(shimmerNode)
                            }
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }
                        
                        var shapes: [ShimmerEffectNode.Shape] = []
                        
                        let titleLineWidth: CGFloat = 180.0
                        let subtitleLineWidth: CGFloat = 90.0
                        let lineDiameter: CGFloat = 10.0
                        
                        let iconFrame = strongSelf.iconNode.frame
                        shapes.append(.circle(iconFrame))
                        
                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                        
                        let subtitleFrame = strongSelf.addressNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: subtitleFrame.minX, y: subtitleFrame.minY + floor((subtitleFrame.height - lineDiameter) / 2.0)), width: subtitleLineWidth, diameter: lineDiameter))
                                                
                        shimmerNode.update(backgroundColor: placeholderBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: layout.contentSize)
                        
                        strongSelf.iconNode.removeFromSupernode()
                    } else if let shimmerNode = strongSelf.placeholderNode {
                        strongSelf.placeholderNode = nil
                        shimmerNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                if self.bottomStripeNode.supernode != nil {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.bottomStripeNode)
                } else if self.backgroundNode.supernode != nil {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.backgroundNode)
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
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc private func infoPressed() {
        self.item?.infoAction?()
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
}
