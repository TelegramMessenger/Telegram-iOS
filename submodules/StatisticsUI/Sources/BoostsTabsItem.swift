import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import LegacyComponents
import ItemListUI
import PresentationDataUtils

final class BoostsTabsItem: ListViewItem, ItemListItem {
    enum Tab {
        case boosts
        case gifts
    }
    
    let theme: PresentationTheme
    
    let boostsText: String
    let giftsText: String
    let selectedTab: Tab
    
    let sectionId: ItemListSectionId
    let selectionUpdated: (Tab) -> Void
    
    init(theme: PresentationTheme, boostsText: String, giftsText: String, selectedTab: Tab, sectionId: ItemListSectionId, selectionUpdated: @escaping (Tab) -> Void) {
        self.theme = theme
        self.boostsText = boostsText
        self.giftsText = giftsText
        self.selectedTab = selectedTab
        self.sectionId = sectionId
        self.selectionUpdated = selectionUpdated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BoostsTabsItemNode()
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
            if let nodeValue = node() as? BoostsTabsItemNode {
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

private final class BoostsTabsItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let boostsButton: HighlightTrackingButtonNode
    private let boostsTextNode: TextNode
    
    private let giftsButton: HighlightTrackingButtonNode
    private let giftsTextNode: TextNode
    
    private let selectionNode: ASImageNode
    
    private var item: BoostsTabsItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.boostsButton = HighlightTrackingButtonNode()
        
        self.boostsTextNode = TextNode()
        self.boostsTextNode.isUserInteractionEnabled = false
        self.boostsTextNode.displaysAsynchronously = false
        
        self.giftsButton = HighlightTrackingButtonNode()
        
        self.giftsTextNode = TextNode()
        self.giftsTextNode.isUserInteractionEnabled = false
        self.giftsTextNode.displaysAsynchronously = false
        
        self.selectionNode = ASImageNode()
        self.selectionNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.boostsTextNode)
        self.addSubnode(self.giftsTextNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.boostsButton)
        self.addSubnode(self.giftsButton)
        
        self.boostsButton.addTarget(self, action: #selector(self.boostsPressed), forControlEvents: .touchUpInside)
        self.giftsButton.addTarget(self, action: #selector(self.giftsPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func boostsPressed() {
        if let item = self.item {
            item.selectionUpdated(.boosts)
        }
    }
    
    @objc private func giftsPressed() {
        if let item = self.item {
            item.selectionUpdated(.gifts)
        }
    }
    
    func asyncLayout() -> (_ item: BoostsTabsItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeBoostsTextLayout = TextNode.asyncLayout(self.boostsTextNode)
        let makeGiftsTextLayout = TextNode.asyncLayout(self.giftsTextNode)
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let accentColor = item.theme.list.itemAccentColor
            let secondaryColor = item.theme.list.itemSecondaryTextColor
            
            let (boostsTextLayout, boostsTextApply) = makeBoostsTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.boostsText, font: Font.medium(14.0), textColor: item.selectedTab == .boosts ? accentColor : secondaryColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (giftsTextLayout, giftsTextApply) = makeGiftsTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.giftsText, font: Font.medium(14.0), textColor: item.selectedTab == .gifts ? accentColor : secondaryColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            contentSize = CGSize(width: params.width, height: 48.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
                    if themeUpdated {
                        strongSelf.selectionNode.image = generateImage(CGSize(width: 4.0, height: 3.0), rotatedContext: { size, context in
                            context.clear(CGRect(origin: .zero, size: size))
                            
                            context.setFillColor(item.theme.list.itemAccentColor.cgColor)
                            
                            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width, height: 4.0)), cornerRadius: 2.0)
                            context.addPath(path.cgPath)
                            context.fillPath()
                        })?.stretchableImage(withLeftCapWidth: 2, topCapHeight: 0)
                    }
                    
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
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    let _ = boostsTextApply()
                    let _ = giftsTextApply()
                    
                    strongSelf.boostsTextNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 16.0, y: 16.0), size: boostsTextLayout.size)
                    strongSelf.giftsTextNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 16.0 + boostsTextLayout.size.width + 27.0, y: 16.0), size: giftsTextLayout.size)
                    
                    strongSelf.boostsButton.frame = strongSelf.boostsTextNode.frame.insetBy(dx: -10.0, dy: -10.0)
                    strongSelf.giftsButton.frame = strongSelf.giftsTextNode.frame.insetBy(dx: -10.0, dy: -10.0)
                    
                    let selectionHeight: CGFloat = 3.0
                    let selectionFrame: CGRect
                    
                    switch item.selectedTab {
                    case .boosts:
                        selectionFrame = CGRect(x: strongSelf.boostsTextNode.frame.minX, y: contentSize.height - selectionHeight, width: strongSelf.boostsTextNode.frame.width, height: selectionHeight)
                    case .gifts:
                        selectionFrame = CGRect(x: strongSelf.giftsTextNode.frame.minX, y: contentSize.height - selectionHeight, width: strongSelf.giftsTextNode.frame.width, height: selectionHeight)
                    }
                    
                    var transition: ContainedViewLayoutTransition = .immediate
                    if let currentItem, currentItem.selectedTab != item.selectedTab {
                        transition = .animated(duration: 0.3, curve: .spring)
                    }
                    transition.updateFrame(node: strongSelf.selectionNode, frame: selectionFrame)
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
