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
    let values: [Int32]
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, value: Int32, values: [Int32], sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.values = values
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
    
    private let textNodes: [TextNode]
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
        
        self.textNodes = (0 ..< 10).map { _ -> TextNode in
            let textNode = TextNode()
            textNode.isUserInteractionEnabled = false
            textNode.displaysAsynchronously = false
            return textNode
        }
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.textNodes.forEach(self.addSubnode)
    }
    
    func updateSliderView() {
        if let sliderView = self.sliderView, let item = self.item {
            sliderView.maximumValue = CGFloat(item.values.count - 1)
            sliderView.positionsCount = item.values.count
            var value: Int32 = 0
            for i in 0 ..< item.values.count {
                if item.values[i] >= item.value {
                    value = Int32(i)
                    break
                }
            }
            
            sliderView.value = CGFloat(value)
            
            sliderView.isUserInteractionEnabled = true
            sliderView.alpha = 1.0
            sliderView.layer.allowsGroupOpacity = false
        }
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
            var value: Int32 = 0
            for i in 0 ..< item.values.count {
                if item.values[i] >= item.value {
                    value = Int32(i)
                    break
                }
            }
            sliderView.value = CGFloat(value)
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
        let makeTextLayouts = self.textNodes.map(TextNode.asyncLayout)
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            var textLayoutAndApply: [(TextNodeLayout, () -> TextNode)] = []
            
            for i in 0 ..< item.values.count {
                let value = item.values[i]
                
                let valueString: String = "\(value)"
                let (textLayout, textApply) = makeTextLayouts[i](TextNodeLayoutArguments(attributedString: NSAttributedString(string: valueString, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
                textLayoutAndApply.append((textLayout, textApply))
            }
          
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
                    
                    for (_, apply) in textLayoutAndApply {
                        let _ = apply()
                    }
                    
                    let textNodes: [(TextNode, CGSize)] = textLayoutAndApply.map { layout, apply -> (TextNode, CGSize) in
                        let node = apply()
                        return (node, layout.size)
                    }
                    
                    let delta = (params.width - params.leftInset - params.rightInset - 18.0 * 2.0) / CGFloat(max(item.values.count - 1, 1))
                    for i in 0 ..< strongSelf.textNodes.count {
                        guard i < item.values.count else {
                            strongSelf.textNodes[i].isHidden = true
                            continue
                        }
                        let (textNode, textSize) = textNodes[i]
                        textNode.isHidden = false
                        var position = params.leftInset + 18.0 + delta * CGFloat(i)
                        if i == textNodes.count - 1 {
                            position -= textSize.width / 2.0 + 2.0
                        } else if i > 0 {
                            position -= textSize.width / 2.0
                        }
                        
                        textNode.frame = CGRect(origin: CGPoint(x: position, y: 15.0), size: textSize)
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
                        
                        strongSelf.updateSliderView()
                    }
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
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView, let item = self.item else {
            return
        }
        let value = Int(sliderView.value)
        if value >= 0 && value < item.values.count {
            self.item?.updated(item.values[value])
        }
    }
}
