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

final class SubscriptionsCountItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: Int32
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, value: Int32, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.sectionId = sectionId
        self.updated = updated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = SubscriptionsCountItemNode()
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
            if let nodeValue = node() as? SubscriptionsCountItemNode {
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

private final class SubscriptionsCountItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let label1TextNode: TextNode
    private let label3TextNode: TextNode
    private let label5TextNode: TextNode
    private let label7TextNode: TextNode
    private let label10TextNode: TextNode
    private let label25TextNode: TextNode
    private let label50TextNode: TextNode
    private var sliderView: TGPhotoEditorSliderView?
    
    private var item: SubscriptionsCountItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.label1TextNode = TextNode()
        self.label1TextNode.isUserInteractionEnabled = false
        self.label1TextNode.displaysAsynchronously = false
        
        self.label3TextNode = TextNode()
        self.label3TextNode.isUserInteractionEnabled = false
        self.label3TextNode.displaysAsynchronously = false
        
        self.label5TextNode = TextNode()
        self.label5TextNode.isUserInteractionEnabled = false
        self.label5TextNode.displaysAsynchronously = false
        
        self.label7TextNode = TextNode()
        self.label7TextNode.isUserInteractionEnabled = false
        self.label7TextNode.displaysAsynchronously = false
        
        self.label10TextNode = TextNode()
        self.label10TextNode.isUserInteractionEnabled = false
        self.label10TextNode.displaysAsynchronously = false
        
        self.label25TextNode = TextNode()
        self.label25TextNode.isUserInteractionEnabled = false
        self.label25TextNode.displaysAsynchronously = false
        
        self.label50TextNode = TextNode()
        self.label50TextNode.isUserInteractionEnabled = false
        self.label50TextNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.label1TextNode)
        self.addSubnode(self.label3TextNode)
        self.addSubnode(self.label5TextNode)
        self.addSubnode(self.label7TextNode)
        self.addSubnode(self.label10TextNode)
        self.addSubnode(self.label25TextNode)
        self.addSubnode(self.label50TextNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 2.0
        sliderView.lineSize = 4.0
        sliderView.dotSize = 8.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = 6.0
        sliderView.startValue = 0.0
        sliderView.positionsCount = 7
        sliderView.useLinesForPositions = true
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        if let item = self.item, let params = self.layoutParams {
            var mappedValue: Int32 = 0
            switch Int(item.value) {
            case 1:
                mappedValue = 0
            case 3:
                mappedValue = 1
            case 5:
                mappedValue = 2
            case 7:
                mappedValue = 3
            case 10:
                mappedValue = 4
            case 25:
                mappedValue = 5
            case 50:
                mappedValue = 6
            default:
                mappedValue = 0
            }
            sliderView.value = CGFloat(mappedValue)
            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.startColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.trackColor = item.theme.list.itemAccentColor
            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
            
            sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
            sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
        }
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
    }
    
    func asyncLayout() -> (_ item: SubscriptionsCountItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeLabel1TextLayout = TextNode.asyncLayout(self.label1TextNode)
        let makeLabel3TextLayout = TextNode.asyncLayout(self.label3TextNode)
        let makeLabel5TextLayout = TextNode.asyncLayout(self.label5TextNode)
        let makeLabel7TextLayout = TextNode.asyncLayout(self.label7TextNode)
        let makeLabel10TextLayout = TextNode.asyncLayout(self.label10TextNode)
        let makeLabel25TextLayout = TextNode.asyncLayout(self.label25TextNode)
        let makeLabel50TextLayout = TextNode.asyncLayout(self.label50TextNode)
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let (label1TextLayout, label1TextApply) = makeLabel1TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "1", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (label3TextLayout, label3TextApply) = makeLabel3TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "3", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (label5TextLayout, label5TextApply) = makeLabel5TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "5", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (label7TextLayout, label7TextApply) = makeLabel7TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "7", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (label10TextLayout, label10TextApply) = makeLabel10TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "10", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (label25TextLayout, label25TextApply) = makeLabel25TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "25", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (label50TextLayout, label50TextApply) = makeLabel50TextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "50", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            contentSize = CGSize(width: params.width, height: 88.0)
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
                    
                    let _ = label1TextApply()
                    let _ = label3TextApply()
                    let _ = label5TextApply()
                    let _ = label7TextApply()
                    let _ = label10TextApply()
                    let _ = label25TextApply()
                    let _ = label50TextApply()
                    
                    let textNodes: [(TextNode, CGSize)] = [
                        (strongSelf.label1TextNode, label1TextLayout.size),
                        (strongSelf.label3TextNode, label3TextLayout.size),
                        (strongSelf.label5TextNode, label5TextLayout.size),
                        (strongSelf.label7TextNode, label7TextLayout.size),
                        (strongSelf.label10TextNode, label10TextLayout.size),
                        (strongSelf.label25TextNode, label25TextLayout.size),
                        (strongSelf.label50TextNode, label50TextLayout.size)
                    ]
                    
                    let delta = (params.width - params.leftInset - params.rightInset - 20.0 * 2.0) / CGFloat(textNodes.count - 1)
                    for i in 0 ..< textNodes.count {
                        let (textNode, textSize) = textNodes[i]
                        
                        let position = params.leftInset + 20.0 + delta * CGFloat(i)
                        textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(position - textSize.width / 2.0), y: 15.0), size: textSize)
                    }
                    
                    if let sliderView = strongSelf.sliderView {
                        if themeUpdated {
                            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
                            sliderView.trackColor = item.theme.list.itemAccentColor
                            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
                        }
                        
                        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
                        sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
                        
                        var mappedValue: Int32 = 0
                        switch Int(item.value) {
                        case 1:
                            mappedValue = 0
                        case 3:
                            mappedValue = 1
                        case 5:
                            mappedValue = 2
                        case 7:
                            mappedValue = 3
                        case 10:
                            mappedValue = 4
                        case 25:
                            mappedValue = 5
                        case 50:
                            mappedValue = 6
                        default:
                            mappedValue = 0
                        }
                        if Int32(sliderView.value) != mappedValue {
                            sliderView.value = CGFloat(mappedValue)
                        }
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
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        
        var mappedValue: Int32 = 1
        switch Int(sliderView.value) {
        case 0:
            mappedValue = 1
        case 1:
            mappedValue = 3
        case 2:
            mappedValue = 5
        case 3:
            mappedValue = 7
        case 4:
            mappedValue = 10
        case 5:
            mappedValue = 25
        case 6:
            mappedValue = 50
        default:
            mappedValue = 1
        }
        
        self.item?.updated(Int32(mappedValue))
    }
}
