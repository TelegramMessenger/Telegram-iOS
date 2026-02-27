import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ComponentFlow
import SliderComponent

enum AutomaticDownloadDataUsage: Int {
    case low
    case medium
    case high
    case custom
    
    init(preset: MediaAutoDownloadPreset) {
        switch preset {
            case .low:
                self = .low
            case .medium:
                self = .medium
            case .high:
                self = .high
            case .custom:
                self = .custom
        }
    }
}

final class AutodownloadDataUsagePickerItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let systemStyle: ItemListSystemStyle
    let value: AutomaticDownloadDataUsage
    let customPosition: Int?
    let enabled: Bool
    let sectionId: ItemListSectionId
    let updated: (AutomaticDownloadDataUsage) -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, systemStyle: ItemListSystemStyle = .legacy, value: AutomaticDownloadDataUsage, customPosition: Int?, enabled: Bool, sectionId: ItemListSectionId, updated: @escaping (AutomaticDownloadDataUsage) -> Void, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.strings = strings
        self.systemStyle = systemStyle
        self.value = value
        self.customPosition = customPosition
        self.enabled = enabled
        self.sectionId = sectionId
        self.updated = updated
        self.tag = tag
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AutodownloadDataUsagePickerItemNode()
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
            if let nodeValue = node() as? AutodownloadDataUsagePickerItemNode {
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

private final class AutodownloadDataUsagePickerItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let lowTextNode: TextNode
    private let mediumTextNode: TextNode
    private let highTextNode: TextNode
    private let customTextNode: TextNode
    private let slider = ComponentView<Empty>()
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: AutodownloadDataUsagePickerItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    public var tag: ItemListItemTag? {
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
        
        self.lowTextNode = TextNode()
        self.lowTextNode.isUserInteractionEnabled = false
        self.lowTextNode.displaysAsynchronously = false
        
        self.mediumTextNode = TextNode()
        self.mediumTextNode.isUserInteractionEnabled = false
        self.mediumTextNode.displaysAsynchronously = false
        
        self.highTextNode = TextNode()
        self.highTextNode.isUserInteractionEnabled = false
        self.highTextNode.displaysAsynchronously = false
      
        self.customTextNode = TextNode()
        self.customTextNode.isUserInteractionEnabled = false
        self.customTextNode.displaysAsynchronously = false
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.lowTextNode)
        self.addSubnode(self.mediumTextNode)
        self.addSubnode(self.highTextNode)
        self.addSubnode(self.customTextNode)
        self.addSubnode(self.activateArea)
        
//        self.activateArea.increment = { [weak self] in
//            if let self {
//                self.sliderView?.increase()
//            }
//        }
//        
//        self.activateArea.decrement = { [weak self] in
//            if let self {
//                self.sliderView?.decrease()
//            }
//        }
    }
    
    func asyncLayout() -> (_ item: AutodownloadDataUsagePickerItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLowTextLayout = TextNode.asyncLayout(self.lowTextNode)
        let makeMediumTextLayout = TextNode.asyncLayout(self.mediumTextNode)
        let makeHighTextLayout = TextNode.asyncLayout(self.highTextNode)
        let makeCustomTextLayout = TextNode.asyncLayout(self.customTextNode)
        
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let (lowTextLayout, lowTextApply) = makeLowTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.AutoDownloadSettings_DataUsageLow, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))

            let (mediumTextLayout, mediumTextApply) = makeMediumTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.AutoDownloadSettings_DataUsageMedium, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (highTextLayout, highTextApply) = makeHighTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.AutoDownloadSettings_DataUsageHigh, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let (customTextLayout, customTextApply) = makeCustomTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.AutoDownloadSettings_DataUsageCustom, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
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
                        bottomStripeInset = 0.0 //params.leftInset + 16.0
                        bottomStripeOffset = -separatorHeight
                        strongSelf.bottomStripeNode.isHidden = false
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                        hasBottomCorners = true
                        strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    let _ = lowTextApply()
                    let _ = mediumTextApply()
                    let _ = highTextApply()
                    let _ = customTextApply()
                    
                    var textNodes: [(TextNode, CGSize)] = [(strongSelf.lowTextNode, lowTextLayout.size),
                                                           (strongSelf.mediumTextNode, mediumTextLayout.size),
                                                           (strongSelf.highTextNode, highTextLayout.size)]
                    if let customPosition = item.customPosition {
                        textNodes.insert((strongSelf.customTextNode, customTextLayout.size), at: customPosition)
                    }
                    
                    let delta = (params.width - params.leftInset - params.rightInset - 25.0 * 2.0) / CGFloat(textNodes.count - 1)
                    for i in 0 ..< textNodes.count {
                        let (textNode, textSize) = textNodes[i]
                        
                        let leftEdge = params.leftInset + 18.0
                        let rightEdge = params.width - params.rightInset - 18.0
                        let position = params.leftInset + 25.0 + delta * CGFloat(i)
                        let origin = max(leftEdge, min(rightEdge - textSize.width, position - textSize.width / 2.0))
                        
                        textNode.frame = CGRect(origin: CGPoint(x: origin, y: 15.0), size: textSize)
                    }
                    
                    
                    var valueCount = 3
                    var value = item.value.rawValue
                    if let customPosition = item.customPosition {
                        valueCount += 1
                        if case .custom = item.value {
                            value = customPosition
                        } else {
                            if value >= customPosition {
                                value += 1
                            }
                        }
                    }
                    
                    let sliderSize = strongSelf.slider.update(
                        transition: .immediate,
                        component: AnyComponent(
                            SliderComponent(
                                content: .discrete(.init(
                                    valueCount: valueCount,
                                    value: value,
                                    markPositions: true,
                                    valueUpdated: { [weak self] position in
                                        guard let self else {
                                            return
                                        }
                                        var value: AutomaticDownloadDataUsage?
                                        if let customPosition = self.item?.customPosition {
                                            if position == customPosition {
                                                value = .custom
                                            } else {
                                                value = AutomaticDownloadDataUsage(rawValue: position > customPosition ? (position - 1) : position)
                                            }
                                        } else {
                                            value = AutomaticDownloadDataUsage(rawValue: position)
                                        }
                                        if let value = value {
                                            self.item?.updated(value)
                                        }
                                    }
                                )),
                                useNative: true,
                                trackBackgroundColor: item.theme.list.itemSwitchColors.frameColor,
                                trackForegroundColor: item.theme.list.itemAccentColor
                            )
                        ),
                        environment: {},
                        containerSize: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0)
                    )
                    if let sliderView = strongSelf.slider.view {
                        if sliderView.superview == nil {
                            strongSelf.view.addSubview(sliderView)
                        }
                        sliderView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - sliderSize.width) / 2.0), y: 37.0), size: sliderSize)
                        sliderView.isUserInteractionEnabled = item.enabled
                        sliderView.alpha = item.enabled ? 1.0 : 0.4
                        sliderView.layer.allowsGroupOpacity = !item.enabled
                    }
                    
                    strongSelf.activateArea.accessibilityLabel = item.strings.AutoDownloadSettings_DataUsage
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                }
            })
        }
    }
    
    private func updateAccessibilityLabels() {
//        guard let item = self.item else {
//            return
//        }
//        var textNodes: [TextNode] = [self.lowTextNode, self.mediumTextNode, self.highTextNode]
//        if let customPosition = item.customPosition {
//            textNodes.insert(self.customTextNode, at: customPosition)
//        }
//        if let value = self.sliderView?.value {
//            self.activateArea.accessibilityValue = textNodes[Int(value)].cachedLayout?.attributedString?.string ?? ""
//        }
//        var accessibilityTraits: UIAccessibilityTraits = [.adjustable]
//        if item.enabled {
//        } else {
//            accessibilityTraits.insert(.notEnabled)
//        }
//        self.activateArea.accessibilityTraits = accessibilityTraits
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

