import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import LegacyComponents
import ItemListUI
import PresentationDataUtils
import AppBundle

private func mapTimeoutToSliderValue(_ value: Int32, availableValues: [Int32]) -> CGFloat {
    for i in 0 ..< availableValues.count {
        if availableValues[i] == Int32.max {
            if value == Int32.max {
                return CGFloat(i)
            }
        } else {
            if value <= availableValues[i] {
                return CGFloat(i)
            }
        }
    }
    return CGFloat(availableValues.count - 1)
}

private func mapSliderValueToTimeout(_ value: CGFloat, availableValues: [Int32]) -> Int32 {
    let intValue = Int(round(value))
    if intValue == 0 {
        return Int32.max
    } else if intValue >= 0 && intValue < availableValues.count {
        return availableValues[intValue]
    } else {
        return availableValues[availableValues.count - 1]
    }
}

class PeerRemoveTimeoutItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let value: Int32
    let availableValues: [Int32]
    let enabled: Bool
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void
    let tag: ItemListItemTag?
    
    init(presentationData: ItemListPresentationData, value: Int32, availableValues: [Int32], enabled: Bool = true, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void, tag: ItemListItemTag? = nil) {
        self.presentationData = presentationData
        self.value = value
        self.availableValues = availableValues
        self.enabled = enabled
        self.sectionId = sectionId
        self.updated = updated
        self.tag = tag
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeerRemoveTimeoutItemNode()
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
            if let nodeValue = node() as? PeerRemoveTimeoutItemNode {
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

class PeerRemoveTimeoutItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var sliderView: TGPhotoEditorSliderView?
    private let titleNodes: [TextNode]
    private let disabledOverlayNode: ASDisplayNode
    
    private var item: PeerRemoveTimeoutItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.disabledOverlayNode = ASDisplayNode()
        
        self.titleNodes = (0 ..< 4).map { _ in
            return TextNode()
        }
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.titleNodes.forEach(self.addSubnode)
        
        self.addSubnode(self.disabledOverlayNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 2.0
        sliderView.lineSize = 4.0
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = CGFloat(self.titleNodes.count - 1)
        sliderView.startValue = 0.0
        sliderView.positionsCount = self.titleNodes.count
        sliderView.useLinesForPositions = true
        sliderView.minimumUndottedValue = 0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        if let item = self.item, let params = self.layoutParams {
            sliderView.isUserInteractionEnabled = item.enabled
            
            sliderView.value = mapTimeoutToSliderValue(item.value, availableValues: item.availableValues)
            
            sliderView.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.presentationData.theme.list.itemSwitchColors.frameColor
            sliderView.trackColor = item.enabled ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemDisabledTextColor
            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.presentationData.theme)
            
            let sliderInset: CGFloat = params.leftInset + 16.0
            
            sliderView.frame = CGRect(origin: CGPoint(x: sliderInset, y: 38.0), size: CGSize(width: params.width - sliderInset * 2.0, height: 44.0))
        }
        self.view.insertSubview(sliderView, belowSubview: self.disabledOverlayNode.view)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
    }
    
    func asyncLayout() -> (_ item: PeerRemoveTimeoutItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        let makeTitleNodeLayouts = self.titleNodes.map(TextNode.asyncLayout)
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let titleLayouts = zip(0 ..< makeTitleNodeLayouts.count, makeTitleNodeLayouts).map { index, makeLayout -> (TextNodeLayout, () -> TextNode) in
                let text: String
                if item.availableValues[index] == Int32.max {
                    text = item.presentationData.strings.AutoremoveSetup_TimerValueNever
                } else {
                    text = timeIntervalString(strings: item.presentationData.strings, value: item.availableValues[index])
                }
                return makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: Font.regular(13.0), textColor: item.presentationData.theme.list.itemSecondaryTextColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0)))
            }
            
            contentSize = CGSize(width: params.width, height: 88.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    let firstTime = strongSelf.item == nil
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    let leftInset = 16.0 + params.leftInset
                    
                    strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    
                    strongSelf.disabledOverlayNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4)
                    strongSelf.disabledOverlayNode.isHidden = item.enabled
                    strongSelf.disabledOverlayNode.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 8.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: 44.0))
                    
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
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))

                    let usableWidth = params.width - (leftInset + 7.0) * 2.0

                    for i in 0 ..< titleLayouts.count {
                        let textNode = titleLayouts[i].1()

                        let size = titleLayouts[i].0.size

                        let nextX: CGFloat
                        if i == 0 {
                            nextX = leftInset
                        } else if i == titleLayouts.count - 1 {
                            nextX = params.width - leftInset - size.width
                        } else {
                            nextX = floor(leftInset + 7.0 + CGFloat(i) * usableWidth / CGFloat(titleLayouts.count - 1) - size.width / 2.0)
                        }

                        textNode.frame = CGRect(origin: CGPoint(x: nextX, y: 13.0), size: size)
                    }
                    
                    if let sliderView = strongSelf.sliderView {
                        sliderView.isUserInteractionEnabled = item.enabled
                        sliderView.trackColor = item.enabled ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemDisabledTextColor
                        
                        if themeUpdated {
                            sliderView.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                            sliderView.backColor = item.presentationData.theme.list.itemSwitchColors.frameColor
                            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.presentationData.theme)
                        }
                        
                        let value: CGFloat
                        switch item.value {
                        case 24 * 60 * 60:
                            value = 0.0
                        case 7 * 24 * 60 * 60:
                            value = 1.0
                        default:
                            value = 2.0
                        }
                        if firstTime {
                            sliderView.value = value
                        }

                        sliderView.frame = CGRect(origin: CGPoint(x: leftInset, y: 38.0), size: CGSize(width: params.width - leftInset * 2.0, height: 44.0))
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
        guard let sliderView = self.sliderView, let item = self.item else {
            return
        }
        self.item?.updated(mapSliderValueToTimeout(sliderView.value, availableValues: item.availableValues))
    }
}

