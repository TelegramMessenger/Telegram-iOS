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
import ComponentFlow
import ButtonComponent
import BundleIconComponent
import MultilineTextComponent
import ListItemComponentAdaptor

private let textFont = Font.with(size: 17.0, traits: .monospacedNumbers)
private let smallTextFont = Font.with(size: 13.0, traits: .monospacedNumbers)

public final class MessagePriceItem: Equatable, ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let isEnabled: Bool
    let minValue: Int64
    let maxValue: Int64
    let value: Int64
    let price: String
    public let sectionId: ItemListSectionId
    let updated: (Int64, Bool) -> Void
    let openSetCustom: (() -> Void)?
    let openPremiumInfo: (() -> Void)?
    
    public init(theme: PresentationTheme, strings: PresentationStrings, isEnabled: Bool, minValue: Int64, maxValue: Int64, value: Int64, price: String, sectionId: ItemListSectionId, updated: @escaping (Int64, Bool) -> Void, openSetCustom: (() -> Void)? = nil, openPremiumInfo: (() -> Void)? = nil) {
        self.theme = theme
        self.strings = strings
        self.isEnabled = isEnabled
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.price = price
        self.sectionId = sectionId
        self.updated = updated
        self.openSetCustom = openSetCustom
        self.openPremiumInfo = openPremiumInfo
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MessagePriceItemNode()
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
            if let nodeValue = node() as? MessagePriceItemNode {
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
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: MessagePriceItem, rhs: MessagePriceItem) -> Bool {
        
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.price != rhs.price {
            return false
        }
        if (lhs.openSetCustom == nil) != (rhs.openSetCustom == nil) {
            return false
        }
        if (lhs.openPremiumInfo == nil) != (rhs.openPremiumInfo == nil) {
            return false
        }
        
        return true
    }
}

private class MessagePriceItemNode: ListViewItemNode {
    private struct Amount: Equatable {
        private let sliderSteps: [Int]
        private let minRealValue: Int
        private let maxRealValue: Int
        let maxSliderValue: Int
        private let isLogarithmic: Bool
        
        private(set) var realValue: Int
        private(set) var sliderValue: Int
        
        private static func makeSliderSteps(minRealValue: Int, maxRealValue: Int, isLogarithmic: Bool) -> [Int] {
            if isLogarithmic {
                var sliderSteps: [Int] = [ minRealValue, 10, 50, 100, 500, 1_000, 2_000, 5_000, 7_500, 10_000 ]
                sliderSteps.removeAll(where: { $0 >= maxRealValue })
                sliderSteps.append(maxRealValue)
                return sliderSteps
            } else {
                return [1, maxRealValue]
            }
        }
        
        private static func remapValueToSlider(realValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
            guard realValue >= steps.first!, realValue <= steps.last! else { return 0 }

            for i in 0 ..< steps.count - 1 {
                if realValue >= steps[i] && realValue <= steps[i + 1] {
                    let range = steps[i + 1] - steps[i]
                    let relativeValue = realValue - steps[i]
                    let stepFraction = Float(relativeValue) / Float(range)
                    return Int(Float(i) * Float(maxSliderValue) / Float(steps.count - 1)) + Int(stepFraction * Float(maxSliderValue) / Float(steps.count - 1))
                }
            }
            return maxSliderValue
        }

        private static func remapSliderToValue(sliderValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
            guard sliderValue >= 0, sliderValue <= maxSliderValue else { return steps.first! }

            let stepIndex = Int(Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1))
            let fraction = Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1) - Float(stepIndex)
            
            if stepIndex >= steps.count - 1 {
                return steps.last!
            } else {
                let range = steps[stepIndex + 1] - steps[stepIndex]
                return steps[stepIndex] + Int(fraction * Float(range))
            }
        }
        
        init(realValue: Int, minRealValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
            self.sliderSteps = Amount.makeSliderSteps(minRealValue: minRealValue, maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
            self.minRealValue = minRealValue
            self.maxRealValue = maxRealValue
            self.maxSliderValue = maxSliderValue
            self.isLogarithmic = isLogarithmic
            
            self.realValue = realValue
            self.sliderValue = Amount.remapValueToSlider(realValue: self.realValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
        }
        
        init(sliderValue: Int, minRealValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
            self.sliderSteps = Amount.makeSliderSteps(minRealValue: minRealValue, maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
            self.minRealValue = minRealValue
            self.maxRealValue = maxRealValue
            self.maxSliderValue = maxSliderValue
            self.isLogarithmic = isLogarithmic
            
            self.sliderValue = sliderValue
            self.realValue = Amount.remapSliderToValue(sliderValue: self.sliderValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
        }
        
        func withRealValue(_ realValue: Int) -> Amount {
            return Amount(realValue: realValue, minRealValue: self.minRealValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
        
        func withSliderValue(_ sliderValue: Int) -> Amount {
            return Amount(sliderValue: sliderValue, minRealValue: self.minRealValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
    }
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var sliderView: TGPhotoEditorSliderView?
    private let leftTextNode: ImmediateTextNode
    private let rightTextNode: ImmediateTextNode
    private let centerTextButtonNode: HighlightableButtonNode
    private let centerTextButtonBackground: UIImageView
    private let centerLeftTextNode: ImmediateTextNode
    private let centerRightTextNode: ImmediateTextNode
    private let lockIconNode: ASImageNode
    
    private let button: ComponentView<Empty>
    
    private var amount: Amount = Amount(realValue: 1, minRealValue: 1, maxRealValue: 1000, maxSliderValue: 1000, isLogarithmic: true)
    
    private var item: MessagePriceItem?
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
        
        self.centerTextButtonNode = HighlightableButtonNode()
        self.centerTextButtonBackground = UIImageView()
        self.centerLeftTextNode = ImmediateTextNode()
        self.centerLeftTextNode.isUserInteractionEnabled = false
        self.centerLeftTextNode.displaysAsynchronously = false
        self.centerRightTextNode = ImmediateTextNode()
        self.centerRightTextNode.displaysAsynchronously = false
        self.centerRightTextNode.isUserInteractionEnabled = false
        
        self.lockIconNode = ASImageNode()
        self.lockIconNode.displaysAsynchronously = false
        
        self.button = ComponentView<Empty>()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.leftTextNode)
        self.addSubnode(self.rightTextNode)
        self.addSubnode(self.centerTextButtonNode)
        self.centerTextButtonNode.view.addSubview(self.centerTextButtonBackground)
        self.centerTextButtonNode.addSubnode(self.centerLeftTextNode)
        self.centerTextButtonNode.addSubnode(self.centerRightTextNode)
        self.addSubnode(self.lockIconNode)
        
        self.centerTextButtonNode.addTarget(self, action: #selector(self.centerTextButtonPressed), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enableEdgeTap = true
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 4.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        if let item = self.item, let params = self.layoutParams {
            self.amount = Amount(realValue: Int(item.value), minRealValue: Int(item.minValue), maxRealValue: Int(item.maxValue), maxSliderValue: 999, isLogarithmic: true)
            
            sliderView.minimumValue = 0
            sliderView.startValue = 0
            sliderView.maximumValue = CGFloat(self.amount.maxSliderValue)
            sliderView.displayEdges = true
            sliderView.value = CGFloat(self.amount.sliderValue)
            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.trackColor = item.theme.list.itemAccentColor
            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
            
            sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 18.0, y: 36.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 18.0 * 2.0, height: 44.0))
        }
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
    }
    
    @objc private func centerTextButtonPressed() {
        self.item?.openSetCustom?()
    }
    
    func asyncLayout() -> (_ item: MessagePriceItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            var contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: params.width, height: 88.0)
            if !item.isEnabled {
                contentSize.height = 166.0
            }
            
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
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.leftTextNode.attributedText = NSAttributedString(string: "\(item.minValue)", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor)
                    strongSelf.rightTextNode.attributedText = NSAttributedString(string: "\(item.maxValue)", font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor)
                    
                    let centralLeftText = item.value == 0 ? item.strings.Stars_SendMessage_PriceFree : item.strings.Privacy_Messages_Stars(Int32(item.value))
                    
                    strongSelf.centerLeftTextNode.attributedText = NSAttributedString(string: centralLeftText, font: textFont, textColor: item.openSetCustom != nil ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor)
                    strongSelf.centerRightTextNode.attributedText = NSAttributedString(string: item.price, font: smallTextFont, textColor: item.openSetCustom != nil ? item.theme.list.itemAccentColor.withMultipliedAlpha(0.5) : item.theme.list.itemSecondaryTextColor)
                    
                    let leftTextSize = strongSelf.leftTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                    let rightTextSize = strongSelf.rightTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
                    let centerLeftTextSize = strongSelf.centerLeftTextNode.updateLayout(CGSize(width: 200.0, height: 100.0))
                    let centerRightTextSize = strongSelf.centerRightTextNode.updateLayout(CGSize(width: 200.0, height: 100.0))
                    let centerSpacing: CGFloat = item.price.isEmpty ? 0.0 : 6.0
                    
                    let sideInset: CGFloat = 18.0
                    
                    strongSelf.leftTextNode.frame = CGRect(origin: CGPoint(x: params.leftInset + sideInset, y: 15.0), size: leftTextSize)
                    strongSelf.rightTextNode.frame = CGRect(origin: CGPoint(x: params.width - params.leftInset - sideInset - rightTextSize.width, y: 15.0), size: rightTextSize)
                    
                    let totalCenterWidth = centerLeftTextSize.width + centerSpacing + centerRightTextSize.width
                    let centerLeftFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - totalCenterWidth) / 2.0), y: 11.0), size: centerLeftTextSize)
                    let centerRightFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - totalCenterWidth) / 2.0) + totalCenterWidth - centerRightTextSize.width, y: 14.0 - UIScreenPixel), size: centerRightTextSize)
                    
                    let centerButtonFrame = CGRect(origin: CGPoint(x: centerLeftFrame.minX, y: centerLeftFrame.minY), size: CGSize(width: centerRightFrame.maxX - centerLeftFrame.minX, height: centerLeftFrame.height)).insetBy(dx: -8.0, dy: -4.0)
                    
                    strongSelf.centerTextButtonNode.frame = centerButtonFrame
                    
                    strongSelf.centerTextButtonBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: UIScreenPixel), size: centerButtonFrame.size)
                    if strongSelf.centerTextButtonBackground.image == nil {
                        strongSelf.centerTextButtonBackground.image = generateStretchableFilledCircleImage(diameter: 16.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                    }
                    strongSelf.centerTextButtonBackground.tintColor = item.theme.list.itemAccentColor.withMultipliedAlpha(0.1)
                    
                    if item.openSetCustom != nil {
                        strongSelf.centerTextButtonNode.isEnabled = true
                        strongSelf.centerTextButtonBackground.isHidden = false
                    } else {
                        strongSelf.centerTextButtonNode.isEnabled = false
                        strongSelf.centerTextButtonBackground.isHidden = true
                    }
                    
                    strongSelf.centerLeftTextNode.frame = centerLeftFrame.offsetBy(dx: -centerButtonFrame.minX, dy: -centerButtonFrame.minY)
                    strongSelf.centerRightTextNode.frame = centerRightFrame.offsetBy(dx: -centerButtonFrame.minX, dy: -centerButtonFrame.minY)
                    
                    if let sliderView = strongSelf.sliderView {
                        if themeUpdated {
                            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                            sliderView.backColor = item.theme.list.itemSecondaryTextColor
                            sliderView.trackColor = item.theme.list.itemAccentColor.withAlphaComponent(0.45)
                            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
                        }
                        
                        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 18.0, y: 36.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 18.0 * 2.0, height: 44.0))
                        
                        sliderView.interactionEnded = {
                            guard let self else {
                                return
                            }
                            self.item?.updated(Int64(self.amount.realValue), true)
                        }
                        
                        if !sliderView.isTracking {
                            strongSelf.amount = Amount(realValue: Int(item.value), minRealValue: Int(item.minValue), maxRealValue: Int(item.maxValue), maxSliderValue: 999, isLogarithmic: true)
                            sliderView.value = CGFloat(strongSelf.amount.sliderValue)
                        }
                    }
                    
                    strongSelf.lockIconNode.isHidden = item.isEnabled
                    if !item.isEnabled {
                        if themeUpdated {
                            strongSelf.lockIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/SmallLock"), color: item.theme.list.itemSecondaryTextColor.withMultipliedAlpha(0.5))
                        }
                        if let image = strongSelf.lockIconNode.image {
                            strongSelf.lockIconNode.frame = CGRect(origin: CGPoint(x: centerLeftFrame.minX - image.size.width - 1.0, y: 12.0 + UIScreenPixel), size: image.size)
                        }
                        
                        let sideInset: CGFloat = 16.0
                        let buttonSize = CGSize(width: params.width - params.leftInset - params.rightInset - sideInset * 2.0, height: 50.0)
                        let _ = strongSelf.button.update(
                            transition: .immediate,
                            component: AnyComponent(
                                ButtonComponent(
                                    background: ButtonComponent.Background(
                                        color: item.theme.list.itemCheckColors.fillColor,
                                        foreground: item.theme.list.itemCheckColors.foregroundColor,
                                        pressedColor: item.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                                    ),
                                    content: AnyComponentWithIdentity(
                                        id: AnyHashable("unlock"),
                                        component: AnyComponent(
                                            HStack([
                                                AnyComponentWithIdentity(
                                                    id: AnyHashable("icon"),
                                                    component: AnyComponent(BundleIconComponent(name: "Chat/Stickers/Lock", tintColor: item.theme.list.itemCheckColors.foregroundColor))
                                                ),
                                                AnyComponentWithIdentity(
                                                    id: AnyHashable("label"),
                                                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: item.strings.Privacy_Messages_Unlock, font: Font.semibold(17.0), textColor: item.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                                                )
                                            ], spacing: 3.0)
                                        )
                                    ),
                                    isEnabled: true,
                                    tintWhenDisabled: false,
                                    allowActionWhenDisabled: false,
                                    displaysProgress: false,
                                    action: { [weak self] in
                                        guard let self, let item = self.item else {
                                            return
                                        }
                                        item.openPremiumInfo?()
                                    }
                                )
                            ),
                            environment: {},
                            containerSize: buttonSize
                        )
                        if let buttonView = strongSelf.button.view {
                            if buttonView.superview == nil {
                                strongSelf.view.addSubview(buttonView)
                            }
                            buttonView.frame = CGRect(origin: CGPoint(x: params.leftInset + sideInset, y: contentSize.height - buttonSize.height - sideInset), size: buttonSize)
                        }
                    } else if let buttonView = strongSelf.button.view, buttonView.superview != nil {
                        buttonView.removeFromSuperview()
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
        guard let sliderView = self.sliderView else {
            return
        }
        var updatedAmount = self.amount.withSliderValue(Int(sliderView.value))
        if updatedAmount.realValue > 50 {
            if updatedAmount.realValue < 100 {
                updatedAmount = updatedAmount.withRealValue(Int(round(Double(updatedAmount.realValue) / 1.0) * 1.0))
            } else if updatedAmount.realValue < 500 {
                updatedAmount = updatedAmount.withRealValue(Int(round(Double(updatedAmount.realValue) / 5.0) * 5.0))
            } else if updatedAmount.realValue < 1000 {
                updatedAmount = updatedAmount.withRealValue(Int(round(Double(updatedAmount.realValue) / 10.0) * 10.0))
            } else if updatedAmount.realValue < 5000 {
                updatedAmount = updatedAmount.withRealValue(Int(round(Double(updatedAmount.realValue) / 25.0) * 25.0))
            } else {
                updatedAmount = updatedAmount.withRealValue(Int(round(Double(updatedAmount.realValue) / 50.0) * 50.0))
            }
        }
        self.amount = updatedAmount
        
        self.item?.updated(Int64(self.amount.realValue), false)
    }
}

