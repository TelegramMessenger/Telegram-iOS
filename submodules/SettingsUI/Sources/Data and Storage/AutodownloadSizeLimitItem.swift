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

private let autodownloadSizeValues: [(CGFloat, Int64)] = [
    (0.000, 512 * 1024),
    (0.257, 1024 * 1024),
    (0.520, 10 * 1024 * 1024),
    (0.763, 100 * 1024 * 1024),
    (1.000, 1536 * 1024 * 1024)
]

private func sliderValue(for size: Int64) -> CGFloat {
    for i in 1 ..< autodownloadSizeValues.count {
        let (previousValue, previousValueSize) = autodownloadSizeValues[i - 1]
        let (value, valueSize) = autodownloadSizeValues[i]
        if valueSize > size {
            return previousValue + CGFloat(size - previousValueSize) / CGFloat(valueSize - previousValueSize) * (value - previousValue)
        } else if previousValueSize == size {
            return previousValue
        } else if valueSize == size || i == autodownloadSizeValues.count - 1 {
            return value
        }
    }
    return 0.0
}

private func sizeValue(for sliderValue: CGFloat) -> Int64 {
    for i in 1 ..< autodownloadSizeValues.count {
        let (previousValue, previousValueSize) = autodownloadSizeValues[i - 1]
        let (value, valueSize) = autodownloadSizeValues[i]
        if value > sliderValue {
            let delta = (sliderValue - previousValue) / (value - previousValue) * CGFloat(valueSize - previousValueSize)
            return previousValueSize + Int64(delta)
        } else if previousValue == sliderValue {
            return previousValueSize
        } else if value == sliderValue || i == autodownloadSizeValues.count - 1 {
            return valueSize
        }
    }
    return 0
}

final class AutodownloadSizeLimitItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let decimalSeparator: String
    let text: String
    let value: Int64
    let sectionId: ItemListSectionId
    let updated: (Int64) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, decimalSeparator: String, text: String, value: Int64, sectionId: ItemListSectionId, updated: @escaping (Int64) -> Void) {
        self.theme = theme
        self.strings = strings
        self.decimalSeparator = decimalSeparator
        self.text = text
        self.value = value
        self.sectionId = sectionId
        self.updated = updated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AutodownloadSizeLimitItemNode()
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
            if let nodeValue = node() as? AutodownloadSizeLimitItemNode {
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

private final class AutodownloadSizeLimitItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let minTextNode: TextNode
    private let maxTextNode: TextNode
    private let textNode: TextNode
    private var sliderView: TGPhotoEditorSliderView?
    
    private var item: AutodownloadSizeLimitItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.minTextNode = TextNode()
        self.minTextNode.isUserInteractionEnabled = false
        self.minTextNode.displaysAsynchronously = false
        
        self.maxTextNode = TextNode()
        self.maxTextNode.isUserInteractionEnabled = false
        self.maxTextNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.minTextNode)
        self.addSubnode(self.maxTextNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 2.0
        sliderView.lineSize = 4.0
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = 1.0
        sliderView.startValue = 0.0
        sliderView.displayEdges = true
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        if let item = self.item, let params = self.layoutParams {
            sliderView.value = sliderValue(for: item.value)
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
    
    func asyncLayout() -> (_ item: AutodownloadSizeLimitItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeMinTextLayout = TextNode.asyncLayout(self.minTextNode)
        let makeMaxTextLayout = TextNode.asyncLayout(self.maxTextNode)
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let formatting = DataSizeStringFormatting(strings: item.strings, decimalSeparator: item.decimalSeparator)
            
            let (minTextLayout, minTextApply) = makeMinTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dataSizeString(512 * 1024, formatting: formatting), font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (maxTextLayout, maxTextApply) = makeMaxTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dataSizeString(1536 * 1024 * 1024, formatting: formatting), font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
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
                    
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floor((params.width - textLayout.size.width) / 2.0), y: 12.0), size: textLayout.size)
                    
                    let _ = minTextApply()
                    strongSelf.minTextNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 16.0, y: 16.0), size: minTextLayout.size)
                    
                    let _ = maxTextApply()
                    strongSelf.maxTextNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 16.0 - maxTextLayout.size.width, y: 16.0), size: maxTextLayout.size)
                    
                    if let sliderView = strongSelf.sliderView {
                        if themeUpdated {
                            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
                            sliderView.trackColor = item.theme.list.itemAccentColor
                            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
                        }
                        
                        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
                        sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
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
        let value = sizeValue(for: sliderView.value)
        self.item?.updated(value)
    }
}
