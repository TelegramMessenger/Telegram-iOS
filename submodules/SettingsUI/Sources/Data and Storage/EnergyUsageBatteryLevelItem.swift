import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AppBundle
import ComponentFlow
import SliderComponent

class EnergyUsageBatteryLevelItem: ListViewItem, ItemListItem {
    let systemStyle: ItemListSystemStyle
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: Int32
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void
    
    init(systemStyle: ItemListSystemStyle = .legacy, theme: PresentationTheme, strings: PresentationStrings, value: Int32, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.systemStyle = systemStyle
        self.theme = theme
        self.strings = strings
        self.value = value
        self.sectionId = sectionId
        self.updated = updated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = EnergyUsageBatteryLevelItemNode()
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
            if let nodeValue = node() as? EnergyUsageBatteryLevelItemNode {
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

private func rescaleBatteryValueToSlider(_ value: CGFloat) -> CGFloat {
    var result = (value - 0.04) / (0.96 - 0.04)
    result = max(0.0, min(1.0, result))
    return result
}

private func rescaleSliderToBatteryValue(_ value: CGFloat) -> CGFloat {
    return 0.04 + (0.96 - 0.04) * value
}

class EnergyUsageBatteryLevelItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let leftTextNode: ImmediateTextNode
    private let rightTextNode: ImmediateTextNode
    private let centerTextNode: ImmediateTextNode
    private let centerMeasureTextNode: ImmediateTextNode
    private let slider = ComponentView<Empty>()
    
    private let batteryImage: UIImage?
    private let batteryBackgroundNode: ASImageNode
    private let batteryForegroundNode: ASImageNode
    
    private var item: EnergyUsageBatteryLevelItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.leftTextNode = ImmediateTextNode()
        self.rightTextNode = ImmediateTextNode()
        self.centerTextNode = ImmediateTextNode()
        self.centerMeasureTextNode = ImmediateTextNode()
        
        self.batteryImage = UIImage(bundleImageName: "Settings/UsageBatteryFrame")
        self.batteryBackgroundNode = ASImageNode()
        self.batteryForegroundNode = ASImageNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.leftTextNode)
        self.addSubnode(self.rightTextNode)
        self.addSubnode(self.centerTextNode)
        self.addSubnode(self.batteryBackgroundNode)
        self.addSubnode(self.batteryForegroundNode)
    }
        
    func asyncLayout() -> (_ item: EnergyUsageBatteryLevelItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = item.systemStyle == .glass ? 16.0 : 0.0
            
            var verticalInset: CGFloat = 0.0
            if case .glass = item.systemStyle {
                verticalInset = 4.0
            }
            
            contentSize = CGSize(width: params.width, height: 88.0 + verticalInset * 2.0)
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
                            bottomStripeInset = params.leftInset + 16.0
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
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset - params.rightInset - separatorRightInset, height: separatorHeight))
                    
                    strongSelf.leftTextNode.attributedText = NSAttributedString(string: item.strings.PowerSaving_BatteryLevelLimit_Off, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor)
                    strongSelf.rightTextNode.attributedText = NSAttributedString(string: item.strings.PowerSaving_BatteryLevelLimit_On, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor)
                    
                    let centralText: String
                    let centralMeasureText: String
                    if item.value <= 4 {
                        centralText = item.strings.PowerSaving_BatteryLevelLimit_AlwaysOff
                        centralMeasureText = centralText
                        strongSelf.batteryBackgroundNode.isHidden = true
                    } else if item.value >= 96 {
                        centralText = item.strings.PowerSaving_BatteryLevelLimit_AlwaysOn
                        centralMeasureText = centralText
                        strongSelf.batteryBackgroundNode.isHidden = true
                    } else {
                        centralText = item.strings.PowerSaving_BatteryLevelLimit_WhenBelow("\(item.value)").string
                        centralMeasureText = item.strings.PowerSaving_BatteryLevelLimit_WhenBelow("99").string
                        strongSelf.batteryBackgroundNode.isHidden = false
                    }
                    strongSelf.batteryForegroundNode.isHidden = strongSelf.batteryBackgroundNode.isHidden
                    strongSelf.centerTextNode.attributedText = NSAttributedString(string: centralText, font: Font.regular(16.0), textColor: item.theme.list.itemPrimaryTextColor)
                    strongSelf.centerMeasureTextNode.attributedText = NSAttributedString(string: centralMeasureText, font: Font.regular(16.0), textColor: item.theme.list.itemPrimaryTextColor)
                    
                    let leftTextSize = strongSelf.leftTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                    let rightTextSize = strongSelf.rightTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                    let centerTextSize = strongSelf.centerTextNode.updateLayout(CGSize(width: 200.0, height: 100.0))
                    let centerMeasureTextSize = strongSelf.centerMeasureTextNode.updateLayout(CGSize(width: 200.0, height: 100.0))
                    
                    let sideInset: CGFloat = 18.0
                    
                    strongSelf.leftTextNode.frame = CGRect(origin: CGPoint(x: params.leftInset + sideInset, y: 15.0 + verticalInset), size: leftTextSize)
                    strongSelf.rightTextNode.frame = CGRect(origin: CGPoint(x: params.width - params.leftInset - sideInset - rightTextSize.width, y: 15.0 + verticalInset), size: rightTextSize)
                    
                    var centerFrame = CGRect(origin: CGPoint(x: floor((params.width - centerMeasureTextSize.width) / 2.0), y: 11.0 + verticalInset), size: centerTextSize)
                    if !strongSelf.batteryBackgroundNode.isHidden {
                        centerFrame.origin.x -= 12.0
                    }
                    strongSelf.centerTextNode.frame = centerFrame
                    
                    if let frameImage = strongSelf.batteryImage {
                        strongSelf.batteryBackgroundNode.image = generateImage(frameImage.size, rotatedContext: { size, context in
                            UIGraphicsPushContext(context)
                            
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            
                            if let image = generateTintedImage(image: frameImage, color: item.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.9)) {
                                image.draw(in: CGRect(origin: CGPoint(), size: size))
                                
                                let contentRect = CGRect(origin: CGPoint(x: 3.0, y: (size.height - 9.0) * 0.5), size: CGSize(width: 20.8, height: 9.0))
                                context.addPath(UIBezierPath(roundedRect: contentRect, cornerRadius: 2.0).cgPath)
                                context.clip()
                            }
                            
                            UIGraphicsPopContext()
                        })
                        strongSelf.batteryForegroundNode.image = generateImage(frameImage.size, rotatedContext: { size, context in
                            UIGraphicsPushContext(context)
                            
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            
                            let contentRect = CGRect(origin: CGPoint(x: 3.0, y: (size.height - 9.0) * 0.5), size: CGSize(width: 20.8, height: 9.0))
                            context.addPath(UIBezierPath(roundedRect: contentRect, cornerRadius: 2.0).cgPath)
                            context.clip()
                            
                            context.setFillColor(UIColor.white.cgColor)
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: contentRect.origin, size: CGSize(width: contentRect.width * CGFloat(item.value) / 100.0, height: contentRect.height)), cornerRadius: 1.0).cgPath)
                            context.fillPath()
                            
                            UIGraphicsPopContext()
                        })
                        
                        let batteryColor: UIColor
                        if item.value <= 20 {
                            batteryColor = UIColor(rgb: 0xFF3B30)
                        } else {
                            batteryColor = item.theme.list.itemSwitchColors.positiveColor
                        }
                        
                        if strongSelf.batteryForegroundNode.layer.layerTintColor == nil {
                            strongSelf.batteryForegroundNode.layer.layerTintColor = batteryColor.cgColor
                        } else {
                            ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut).updateTintColor(layer: strongSelf.batteryForegroundNode.layer, color: batteryColor)
                        }
                        
                        strongSelf.batteryBackgroundNode.frame = CGRect(origin: CGPoint(x: centerFrame.minX + centerMeasureTextSize.width + 4.0, y: floor(centerFrame.midY - frameImage.size.height * 0.5)), size: frameImage.size)
                        strongSelf.batteryForegroundNode.frame = strongSelf.batteryBackgroundNode.frame
                    }
                    
                    let sliderSize = strongSelf.slider.update(
                        transition: .immediate,
                        component: AnyComponent(
                            SliderComponent(
                                content: .continuous(.init(
                                    value: rescaleBatteryValueToSlider(CGFloat(item.value) / 100.0),
                                    minValue: nil,
                                    valueUpdated: { [weak self] value in
                                        self?.item?.updated(Int32(rescaleSliderToBatteryValue(value) * 100.0))
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
                        sliderView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - sliderSize.width) / 2.0), y: 36.0 + verticalInset), size: sliderSize)
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
}

