import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramUIPreferences
import TelegramPresentationData
import LegacyComponents
import ItemListUI
import PresentationDataUtils

class ChatSlowmodeItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: Int32
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, value: Int32, enabled: Bool, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.sectionId = sectionId
        self.updated = updated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatSlowmodeItemNode()
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
            if let nodeValue = node() as? ChatSlowmodeItemNode {
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

private func generateKnobImage() -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setShadow(offset: CGSize(width: 0.0, height: -2.0), blur: 3.5, color: UIColor(white: 0.0, alpha: 0.35).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 28.0, height: 28.0)))
    })
}

private let allowedValues: [Int32] = [0, 10, 30, 60, 300, 900, 3600]

class ChatSlowmodeItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let textNodes: [TextNode]
    private var sliderView: TGPhotoEditorSliderView?
    
    private var item: ChatSlowmodeItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var reportedValue: Int32?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.textNodes = allowedValues.map { _ -> TextNode in
            let textNode = TextNode()
            textNode.isUserInteractionEnabled = false
            textNode.displaysAsynchronously = false
            return textNode
        }
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.textNodes.forEach(self.addSubnode)
    }
    
    func forceSetValue(_ value: Int32) {
        if let sliderView = self.sliderView {
            sliderView.value = CGFloat(value)
        }
    }
    
    func updateSliderView() {
        if let sliderView = self.sliderView, let item = self.item {
            sliderView.maximumValue = CGFloat(allowedValues.count - 1)
            sliderView.positionsCount = allowedValues.count
            var value: Int32 = 0
            for i in 0 ..< allowedValues.count {
                if allowedValues[i] >= item.value {
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
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.limitValueChangedToLatestState = true
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 2.0
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = CGFloat(allowedValues.count - 1)
        sliderView.positionsCount = allowedValues.count
        sliderView.startValue = 0.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.useLinesForPositions = true
        if let item = self.item, let params = self.layoutParams {
            var value: Int32 = 0
            for i in 0 ..< allowedValues.count {
                if allowedValues[i] >= item.value {
                    value = Int32(i)
                    break
                }
            }
            
            sliderView.value = CGFloat(value)
            self.reportedValue = item.value
            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.theme.list.disclosureArrowColor
            sliderView.startColor = item.theme.list.disclosureArrowColor
            sliderView.trackColor = item.theme.list.itemAccentColor
            sliderView.knobImage = generateKnobImage()
            
            sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
            sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
        }
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
        
        self.updateSliderView()
    }
    
    func asyncLayout() -> (_ item: ChatSlowmodeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
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
            
            for i in 0 ..< allowedValues.count {
                let value = allowedValues[i]
                
                let valueString: String
                if value == 0 {
                    valueString = item.strings.GroupInfo_Permissions_SlowmodeValue_Off
                } else {
                    valueString = shortTimeIntervalString(strings: item.strings, value: value)
                }
                let (textLayout, textApply) = makeTextLayouts[i](TextNodeLayoutArguments(attributedString: NSAttributedString(string: valueString, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
                textLayoutAndApply.append((textLayout, textApply))
            }
            
            contentSize = CGSize(width: params.width, height: 88.0)
            insets = itemListNeighborsGroupedInsets(neighbors)
            
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
                    switch neighbors.top {
                    case .sameSection(false):
                        strongSelf.topStripeNode.isHidden = true
                    default:
                        strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = 0.0 //params.leftInset + 16.0
                        bottomStripeOffset = -separatorHeight
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    for (_, apply) in textLayoutAndApply {
                        let _ = apply()
                    }
                    
                    var textNodes: [(TextNode, CGSize)] = textLayoutAndApply.map { layout, apply -> (TextNode, CGSize) in
                        let node = apply()
                        return (node, layout.size)
                    }
                    
                    let delta = (params.width - params.leftInset - params.rightInset - 18.0 * 2.0) / CGFloat(textNodes.count - 1)
                    for i in 0 ..< textNodes.count {
                        let (textNode, textSize) = textNodes[i]
                        
                        var position = params.leftInset + 18.0 + delta * CGFloat(i)
                        if i == textNodes.count - 1 {
                            position -= textSize.width
                        } else if i > 0 {
                            position -= textSize.width / 2.0
                        }
                        
                        textNode.frame = CGRect(origin: CGPoint(x: position, y: 15.0), size: textSize)
                    }
                    
                    if let sliderView = strongSelf.sliderView {
                        if themeUpdated {
                            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                            sliderView.backColor = item.theme.list.disclosureArrowColor
                            sliderView.trackColor = item.theme.list.itemAccentColor
                            sliderView.knobImage = generateKnobImage()
                        }
                        
                        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
                        sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
                        
                        strongSelf.updateSliderView()
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
        guard let item = self.item, let sliderView = self.sliderView else {
            return
        }
        
        let position = Int(sliderView.value)
        let value: Int32 = allowedValues[max(0, min(allowedValues.count - 1, position))]
        if self.reportedValue != value {
            self.reportedValue = value
            item.updated(value)
        }
    }
}
