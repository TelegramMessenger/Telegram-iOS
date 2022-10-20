import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ActivityIndicator

final class CalculatingCacheSizeItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(theme: PresentationTheme, title: String, sectionId: ItemListSectionId, style: ItemListStyle) {
        self.theme = theme
        self.title = title
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CalculatingCacheSizeItemNode()
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
            if let nodeValue = node() as? CalculatingCacheSizeItemNode {
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

private let titleFont = Font.regular(14.0)

private final class CalculatingCacheSizeItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var activityIndicator: ActivityIndicator?
    private let titleNode: TextNode
    
    private var item: CalculatingCacheSizeItem?
    
    var tag: Any? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
    }
    
    func asyncLayout() -> (_ item: CalculatingCacheSizeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
                    contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0 + 24.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
                    contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0 + 24.0)
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let activityIndicator: ActivityIndicator
                    if let current = strongSelf.activityIndicator {
                        activityIndicator = current
                    } else {
                        activityIndicator = ActivityIndicator(type: .custom(item.theme.list.itemAccentColor, 20.0, 2.0, false), speed: ActivityIndicatorSpeed.slow)
                        strongSelf.activityIndicator = activityIndicator
                        strongSelf.addSubnode(activityIndicator)
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        activityIndicator.type = .custom(item.theme.list.itemAccentColor, 20.0, 2.0, false)
                    }
                    
                    let _ = titleApply()
                    
                    let leftInset: CGFloat
                    
                    switch item.style {
                        case .plain:
                            leftInset = 35.0 + params.leftInset
                            
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                            
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                        case .blocks:
                            leftInset = 16.0 + params.leftInset
                            
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
                                bottomStripeInset = 16.0 + params.leftInset
                                bottomStripeOffset = -separatorHeight
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                bottomStripeOffset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                            }
                            
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                            
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((params.width - params.leftInset - params.rightInset - titleLayout.size.width) / 2.0), y: 11.0 + 24.0), size: titleLayout.size)
                    
                    activityIndicator.frame = CGRect(origin: CGPoint(x: floor((params.width - 20.0) / 2.0), y: 8.0), size: CGSize(width: 20.0, height: 20.0))
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
