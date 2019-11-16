import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import LocationResources

public final class ItemListVenueItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let account: Account
    let venue: TelegramMediaMap
    
    public let sectionId: ItemListSectionId
    let action: (() -> Void)?
    
    public init(theme: PresentationTheme, account: Account, venue: TelegramMediaMap, sectionId: ItemListSectionId, action: (() -> Void)?) {
        self.theme = theme
        self.account = account
        self.venue = venue
        self.sectionId = sectionId
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListVenueItemNode()
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
            if let nodeValue = node() as? ItemListVenueItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
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

private let titleFont = Font.regular(17.0)
private let addressFont = Font.regular(14.0)

public class ItemListVenueItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let iconNode: TransformImageNode
    private let titleNode: TextNode
    private let addressNode: TextNode
    
    private var layoutParams: (ItemListVenueItem, ListViewItemLayoutParams, ItemListNeighbors)?
    
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
        
        self.iconNode = TransformImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
    
        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        self.addressNode.contentMode = .left
        self.addressNode.contentsScale = UIScreen.main.scale
    
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.addressNode)
    }
    
    public func asyncLayout() -> (_ item: ItemListVenueItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        let iconLayout = self.iconNode.asyncLayout()
        
        let currentItem = self.layoutParams?.0
                
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            var updatedVenueType: String?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
        
            let venueType = item.venue.venue?.type ?? ""
            if currentItem?.venue.venue?.type != venueType {
                updatedVenueType = venueType
            }
        
            let titleAttributedString = NSAttributedString(string: item.venue.venue?.title ?? "", font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
            let addressAttributedString = NSAttributedString(string: item.venue.venue?.address ?? "", font: addressFont, textColor: item.theme.list.itemSecondaryTextColor)
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            let height: CGFloat = 50.0
            let iconSize: CGFloat = 40.0
           
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (addressLayout, addressApply) = makeAddressLayout(TextNodeLayoutArguments(attributedString: addressAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let contentSize = CGSize(width: params.width, height: height)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, neighbors)
                                        
                    strongSelf.accessibilityLabel = titleAttributedString.string
                    strongSelf.accessibilityValue = addressAttributedString.string
                     
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                                        
                    let transition = ContainedViewLayoutTransition.immediate
                                        
                    let _ = titleApply()
                    let _ = addressApply()
                    
                    if let updatedVenueType = updatedVenueType {
                        strongSelf.iconNode.setSignal(venueIcon(postbox: item.account.postbox, type: updatedVenueType, background: true))
                    }
                    
                    let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: iconSize, height: iconSize), boundingSize: CGSize(width: iconSize, height: iconSize), intrinsicInsets: UIEdgeInsets()))
                    iconApply()
                                        
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
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: (addressAttributedString.string.isEmpty ? 14.0 : 6.0)), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.addressNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 27.0), size: addressLayout.size))
                    
                    transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: floorToScreenPixels((height - iconSize) / 2.0)), size: CGSize(width: iconSize, height: iconSize)))
                    
//                    if item.peer.id == item.account.peerId, case .threatSelfAsSaved = item.aliasHandling {
//                        strongSelf.avatarNode.setPeer(account: item.account, theme: item.theme, peer: item.peer, overrideImage: .savedMessagesIcon, emptyColor: item.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
//                    } else {
//                        var overrideImage: AvatarNodeImageOverride?
//                        if item.peer.isDeleted {
//                            overrideImage = .deletedIcon
//                        }
//                        strongSelf.avatarNode.setPeer(account: item.account, theme: item.theme, peer: item.peer, overrideImage: overrideImage, emptyColor: item.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
//                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: height + UIScreenPixel + UIScreenPixel))
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
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
