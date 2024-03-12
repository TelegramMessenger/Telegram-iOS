import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import SolidRoundedButtonNode
import TelegramCore
import EmojiTextAttachmentView
import TextFormat

final class MonetizationBalanceItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let stats: MonetizationStats
    let animatedEmoji: TelegramMediaFile?
    let address: String
    let withdrawAction: () -> Void
    let qrAction: () -> Void
    let action: (() -> Void)?
    let textUpdated: (String) -> Void
    let shouldUpdateText: (String) -> Bool
    let processPaste: ((String) -> Void)?
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        stats: MonetizationStats,
        animatedEmoji: TelegramMediaFile?,
        address: String,
        withdrawAction: @escaping () -> Void,
        qrAction: @escaping () -> Void,
        action: (() -> Void)?,
        textUpdated: @escaping (String) -> Void,
        shouldUpdateText: @escaping (String) -> Bool,
        processPaste: ((String) -> Void)?,
        sectionId: ItemListSectionId,
        style: ItemListStyle
    ) {
        self.context = context
        self.presentationData = presentationData
        self.stats = stats
        self.animatedEmoji = animatedEmoji
        self.address = address
        self.withdrawAction = withdrawAction
        self.qrAction = qrAction
        self.action = action
        self.textUpdated = textUpdated
        self.shouldUpdateText = shouldUpdateText
        self.processPaste = processPaste
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MonetizationBalanceItemNode()
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
            if let nodeValue = node() as? MonetizationBalanceItemNode {
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
    
    var selectable: Bool = false
}

final class MonetizationBalanceItemNode: ListViewItemNode, ItemListItemNode, ASEditableTextNodeDelegate {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var animatedEmojiLayer: InlineStickerItemLayer?
    private let balanceTextNode: TextNode
    private let valueTextNode: TextNode
    
    private let fieldNode: ASImageNode
    private let textClippingNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let measureTextNode: TextNode
    
    private let qrButtonNode: HighlightableButtonNode
    private var withdrawButtonNode: SolidRoundedButtonNode?
        
    private let activateArea: AccessibilityAreaNode
    
    private var item: MonetizationBalanceItem?
    
    override var canBeSelected: Bool {
        return false
    }
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.balanceTextNode = TextNode()
        self.balanceTextNode.isUserInteractionEnabled = false
        self.balanceTextNode.displaysAsynchronously = false
        
        self.valueTextNode = TextNode()
        self.valueTextNode.isUserInteractionEnabled = false
        self.valueTextNode.displaysAsynchronously = false
        
        self.fieldNode = ASImageNode()
        self.fieldNode.displaysAsynchronously = false
        self.fieldNode.displayWithoutProcessing = true
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        
        self.textNode = EditableTextNode()
        self.measureTextNode = TextNode()
        
        self.qrButtonNode = HighlightableButtonNode()
    
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.balanceTextNode)
        self.addSubnode(self.valueTextNode)
        self.addSubnode(self.fieldNode)
        self.addSubnode(self.qrButtonNode)
        
        self.textClippingNode.addSubnode(self.textNode)
        self.addSubnode(self.textClippingNode)
        
        self.qrButtonNode.addTarget(self, action: #selector(self.qrButtonPressed), forControlEvents: .touchUpInside)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        var textColor: UIColor = .black
        if let item = self.item {
            textColor = item.presentationData.theme.list.itemPrimaryTextColor
            self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), NSAttributedString.Key.foregroundColor.rawValue: textColor]
        } else {
            self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: textColor]
        }
        self.textNode.clipsToBounds = true
        self.textNode.delegate = self
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    @objc private func qrButtonPressed() {
        guard let item = self.item else {
            return
        }
        item.qrAction()
    }
    
    func asyncLayout() -> (_ item: MonetizationBalanceItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeBalanceTextLayout = TextNode.asyncLayout(self.balanceTextNode)
        let makeValueTextLayout = TextNode.asyncLayout(self.valueTextNode)
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.leftInset
            let rightInset = 16.0 + params.rightInset
            let constrainedWidth = params.width - leftInset - rightInset
            
            let integralFont = Font.with(size: 48.0, design: .round, weight: .semibold)
            let fractionalFont = Font.with(size: 24.0, design: .round, weight: .semibold)
            
            let cryptoValue = formatBalanceText(item.stats.availableBalance.cryptoAmount, decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
            
            let amountString = amountAttributedString(cryptoValue, integralFont: integralFont, fractionalFont: fractionalFont, color: item.presentationData.theme.list.itemPrimaryTextColor)

            let (balanceLayout, balanceApply) = makeBalanceTextLayout(TextNodeLayoutArguments(attributedString: amountString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let value = "≈$100"
            let (valueLayout, valueApply) = makeValueTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: value, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            var measureText = item.address
            if measureText.hasSuffix("\n") || measureText.isEmpty {
               measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: .black)
            let attributedText = NSAttributedString(string: item.address, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let (textLayout, _) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedMeasureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 12.0 - 36.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let attributedPlaceholderText = NSAttributedString(string: "Enter your TON address", font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
            
            let verticalInset: CGFloat = 16.0
            let fieldHeight: CGFloat = max(52.0, textLayout.size.height + 32.0)
            let fieldSpacing: CGFloat = 16.0
            let buttonHeight: CGFloat = 50.0
            
            var height: CGFloat = verticalInset * 2.0 + balanceLayout.size.height + 7.0
            if valueLayout.size.height > 0.0 {
                height += valueLayout.size.height
                height += fieldHeight + fieldSpacing + buttonHeight
            }

            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = .clear
                insets = UIEdgeInsets()
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
                        
            contentSize = CGSize(width: params.width, height: height)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = balanceApply()
                    let _ = valueApply()
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityTraits = []
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.fieldNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: item.presentationData.theme.list.itemInputField.backgroundColor)
                        
                        strongSelf.qrButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/QrButtonIcon"), color: item.presentationData.theme.list.itemAccentColor), for: .normal)
                    }
                                                            
                    switch item.style {
                    case .plain:
                        if strongSelf.backgroundNode.supernode != nil {
                            strongSelf.backgroundNode.removeFromSupernode()
                        }
                        if strongSelf.topStripeNode.supernode != nil {
                            strongSelf.topStripeNode.removeFromSupernode()
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                        }
                        if strongSelf.maskNode.supernode != nil {
                            strongSelf.maskNode.removeFromSupernode()
                        }
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    case .blocks:
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
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    var emojiItemFrame: CGRect = .zero
                    var emojiItemSize: CGFloat = 0.0
                    if let animatedEmoji = item.animatedEmoji {
                        emojiItemSize = floorToScreenPixels(46.0 * 20.0 / 17.0)
                        
                        emojiItemFrame = CGRect(origin: CGPoint(x: -emojiItemSize / 2.0 - 5.0, y: -3.0), size: CGSize()).insetBy(dx: -emojiItemSize / 2.0, dy: -emojiItemSize / 2.0)
                        emojiItemFrame.origin.x = floorToScreenPixels(emojiItemFrame.origin.x)
                        emojiItemFrame.origin.y = floorToScreenPixels(emojiItemFrame.origin.y)
                        
                        let itemLayer: InlineStickerItemLayer
                        if let current = strongSelf.animatedEmojiLayer {
                            itemLayer = current
                        } else {
                            let pointSize = floor(emojiItemSize * 1.3)
                            itemLayer = InlineStickerItemLayer(context: item.context, userLocation: .other, attemptSynchronousLoad: true, emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: animatedEmoji.fileId.id, file: animatedEmoji, custom: nil), file: animatedEmoji, cache: item.context.animationCache, renderer: item.context.animationRenderer, placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, pointSize: CGSize(width: pointSize, height: pointSize), dynamicColor: nil)
                            strongSelf.animatedEmojiLayer = itemLayer
                            strongSelf.layer.addSublayer(itemLayer)
                            
                            itemLayer.isVisibleForAnimations = true
                        }
                    }
                    
                    let balanceTotalWidth: CGFloat = emojiItemSize + balanceLayout.size.width
                    let balanceTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - balanceTotalWidth) / 2.0) + emojiItemSize, y: 13.0), size: balanceLayout.size)
                    strongSelf.balanceTextNode.frame = balanceTextFrame
                    strongSelf.animatedEmojiLayer?.frame = emojiItemFrame.offsetBy(dx: balanceTextFrame.minX, dy: balanceTextFrame.midY)
                    
                    strongSelf.valueTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - valueLayout.size.width) / 2.0), y: balanceTextFrame.maxY - 5.0), size: valueLayout.size)
                    
                    strongSelf.textNode.textView.autocapitalizationType = .none
                    strongSelf.textNode.textView.autocorrectionType = .no
                    strongSelf.textNode.textView.returnKeyType = .done
                    
                    if let currentText = strongSelf.textNode.attributedText {
                        if currentText.string != attributedText.string || updatedTheme != nil {
                            strongSelf.textNode.attributedText = attributedText
                        }
                    } else {
                        strongSelf.textNode.attributedText = attributedText
                    }
                    
                    if strongSelf.textNode.attributedPlaceholderText == nil || !strongSelf.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.attributedPlaceholderText = attributedPlaceholderText
                    }
                    strongSelf.textNode.keyboardAppearance = item.presentationData.theme.rootController.keyboardColor.keyboardAppearance
                    
                    let textTopInset: CGFloat = 108.0
                    if strongSelf.animationForKey("apparentHeight") == nil {
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset + 12.0, y: textTopInset + 15.0), size: CGSize(width: params.width - leftInset - rightInset - 12.0 - 36.0, height: textLayout.size.height))
                    }
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width - leftInset - rightInset - 12.0 - 36.0, height: textLayout.size.height + 1.0))
                    
                    let fieldFrame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: params.width - leftInset - rightInset, height: fieldHeight))
                    strongSelf.fieldNode.frame = fieldFrame
                    
                    let qrButtonSize = CGSize(width: 32.0, height: 32.0)
                    let qrButtonFrame = CGRect(origin: CGPoint(x: fieldFrame.maxX - qrButtonSize.width - 5.0, y: fieldFrame.midY - qrButtonSize.height / 2.0), size: qrButtonSize)
                    strongSelf.qrButtonNode.frame = qrButtonFrame
                           
                    let withdrawButtonNode: SolidRoundedButtonNode
                    if let currentShareButtonNode = strongSelf.withdrawButtonNode {
                        withdrawButtonNode = currentShareButtonNode
                    } else {
                        var buttonTheme = SolidRoundedButtonTheme(theme: item.presentationData.theme)
                        buttonTheme = buttonTheme.withUpdated(disabledBackgroundColor: buttonTheme.backgroundColor, disabledForegroundColor: buttonTheme.foregroundColor.withAlphaComponent(0.6))
                        withdrawButtonNode = SolidRoundedButtonNode(theme: buttonTheme, height: buttonHeight, cornerRadius: 11.0)
                        withdrawButtonNode.pressed = { [weak self] in
                            if let self, let item = self.item {
                                item.withdrawAction()
                            }
                        }
                        strongSelf.addSubnode(withdrawButtonNode)
                        strongSelf.withdrawButtonNode = withdrawButtonNode
                    }
                    if cryptoValue != "0" {
                        withdrawButtonNode.title = "Transfer \(cryptoValue) TON"
                    }
                    withdrawButtonNode.isEnabled = (strongSelf.textNode.attributedText?.string.count ?? 0) == walletAddressLength
                    
                    let buttonWidth = contentSize.width - leftInset - rightInset
                    let _ = withdrawButtonNode.updateLayout(width: buttonWidth, transition: .immediate)
                    withdrawButtonNode.frame = CGRect(x: leftInset, y: fieldFrame.maxY + fieldSpacing, width: buttonWidth, height: buttonHeight)
                }
            })
        }
    }
    
    public func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let item = self.item {
            if text.count > 1, let processPaste = item.processPaste {
                processPaste(text)
                return false
            }
            
            if let action = item.action, text == "\n" {
                action()
                return false
            }
            
            let newText = (editableTextNode.textView.text as NSString).replacingCharacters(in: range, with: text)
            if !item.shouldUpdateText(newText) {
                return false
            }
        }
        return true
    }
    
    public func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let item = self.item {
            if let text = self.textNode.attributedText {
                let updatedText = text.string
                let updatedAttributedText = NSAttributedString(string: updatedText, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                if text.string != updatedAttributedText.string {
                    self.textNode.attributedText = updatedAttributedText
                }
                self.withdrawButtonNode?.isEnabled = (self.textNode.attributedText?.string.count ?? 0) == walletAddressLength
                item.textUpdated(updatedText)
            } else {
                item.textUpdated("")
            }
        }
    }
    
    public func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool {
        if let _ = self.item {
            let text: String? = UIPasteboard.general.string
            if let _ = text {
                return true
            }
        }
        return false
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
