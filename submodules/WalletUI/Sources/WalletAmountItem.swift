import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AnimatedStickerNode
import SwiftSignalKit
import AppBundle

class WalletAmountItem: ListViewItem, ItemListItem {
    let theme: WalletTheme
    let amount: String
    let sectionId: ItemListSectionId
    let textUpdated: (String) -> Void
    let shouldUpdateText: (String) -> Bool
    let processPaste: ((String) -> String)?
    let updatedFocus: ((Bool) -> Void)?
    let tag: ItemListItemTag?
    
    init(theme: WalletTheme, amount: String, sectionId: ItemListSectionId, textUpdated: @escaping (String) -> Void, shouldUpdateText: @escaping (String) -> Bool = { _ in return true }, processPaste: ((String) -> String)? = nil, updatedFocus: ((Bool) -> Void)? = nil, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.amount = amount
        self.sectionId = sectionId
        self.textUpdated = textUpdated
        self.shouldUpdateText = shouldUpdateText
        self.processPaste = processPaste
        self.updatedFocus = updatedFocus
        self.tag = tag
    }
    
     func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
           async {
               let node = WalletAmountItemNode()
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
               if let nodeValue = node() as? WalletAmountItemNode {
               
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

private let integralFont = Font.medium(48.0)
private let fractionalFont = Font.medium(24.0)

private let iconSize = CGSize(width: 50.0, height: 50.0)
private let verticalOffset: CGFloat = -10.0

class WalletAmountItemNode: ListViewItemNode, UITextFieldDelegate, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode

    private let containerNode: ASDisplayNode
    private let textNode: TextFieldNode
    private let iconNode: AnimatedStickerNode
    private let measureNode: TextNode
        
    private var item: WalletAmountItem?
    private var validLayout: (CGFloat, CGFloat, CGFloat, CGFloat)?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
                
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
                
        self.containerNode = ASDisplayNode()
        
        self.textNode = TextFieldNode()
        
        self.iconNode = AnimatedStickerNode()
        if let path = getAppBundle().path(forResource: "WalletIntroStatic", ofType: "tgs") {
            self.iconNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 120, height: 120, mode: .direct)
            self.iconNode.visibility = true
        }
        
        self.measureNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = false
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.textNode)
        self.containerNode.addSubnode(self.iconNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textNode.textField.textAlignment = .center
        self.textNode.textField.typingAttributes = [NSAttributedString.Key.font: integralFont]
        self.textNode.textField.font = integralFont
        if let item = self.item {
            self.textNode.textField.textColor = item.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = item.theme.keyboardAppearance
            self.textNode.textField.tintColor = item.theme.list.itemAccentColor
            //self.textNode.textField.accessibilityHint = item.placeholder
        }
        self.textNode.clipsToBounds = true
        self.textNode.textField.delegate = self
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    private func inputFieldAsyncLayout() -> (_ item: WalletAmountItem, _ params: ListViewItemLayoutParams) -> (NSAttributedString, NSAttributedString, () -> Void) {
        let makeMeasureLayout = TextNode.asyncLayout(self.measureNode)
        
        return { item, params in
            let contentSize = CGSize(width: params.width, height: 100.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            let attributedPlaceholderText = NSAttributedString(string: "0", font: integralFont, textColor: item.theme.list.itemPlaceholderTextColor)
            let attributedAmountText = amountAttributedString(item.amount, integralFont: integralFont, fractionalFont: fractionalFont, color: item.theme.list.itemPrimaryTextColor)
                 
            let (measureLayout, _) = makeMeasureLayout(TextNodeLayoutArguments(attributedString: item.amount.isEmpty ? attributedPlaceholderText : attributedAmountText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (attributedPlaceholderText, attributedAmountText, { [weak self] in
                if let strongSelf = self {
                    let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - max(31.0, measureLayout.size.width)) / 2.0 - 28.0), y: floor((layout.contentSize.height - iconSize.height) / 2.0) - 3.0 + verticalOffset), size: iconSize)
                    strongSelf.iconNode.updateLayout(size: iconFrame.size)
                    strongSelf.iconNode.frame = iconFrame
                    
                    let totalWidth = measureLayout.size.width + iconSize.width + 6.0
                    let paddedWidth = layout.size.width - 32.0
                    if totalWidth > paddedWidth {
                        let scale = paddedWidth / totalWidth
                        strongSelf.containerNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
                    } else {
                        strongSelf.containerNode.transform = CATransform3DIdentity
                    }
                }
            })
        }
    }
    
    private func updateInputField() {
        guard let item = self.item, let validLayout = self.validLayout else {
            return
        }
        let makeInputFieldLayout = self.inputFieldAsyncLayout()
        let (_, _, inputFieldApply) = makeInputFieldLayout(item, ListViewItemLayoutParams(width: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, availableHeight: validLayout.3))
        inputFieldApply()
    }
    
    func asyncLayout() -> (_ item: WalletAmountItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeInputFieldLayout = self.inputFieldAsyncLayout()
        
        return { item, params, neighbors in
            var updatedTheme: WalletTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            var rightInset: CGFloat = 16.0 + params.rightInset
            
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: params.width, height: 100.0)
            var insets = itemListNeighborsGroupedInsets(neighbors)
            insets.top = 0.0
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let (attributedPlaceholderText, attributedAmountText, inputFieldApply) = makeInputFieldLayout(item, params)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.validLayout = (params.width, params.leftInset, params.rightInset, params.availableHeight)
                    
                    if let _ = updatedTheme {
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        
                        strongSelf.textNode.textField.textColor = item.theme.list.itemPrimaryTextColor
                        strongSelf.textNode.textField.keyboardAppearance = item.theme.keyboardAppearance
                        strongSelf.textNode.textField.tintColor = item.theme.list.itemAccentColor
                    }
                    
                    let capitalizationType = UITextAutocapitalizationType.none
                    let autocorrectionType = UITextAutocorrectionType.no
                    let keyboardType = UIKeyboardType.decimalPad
                    
                    if strongSelf.textNode.textField.keyboardType != keyboardType {
                        strongSelf.textNode.textField.keyboardType = keyboardType
                    }
                    if strongSelf.textNode.textField.autocapitalizationType != capitalizationType {
                        strongSelf.textNode.textField.autocapitalizationType = capitalizationType
                    }
                    if strongSelf.textNode.textField.autocorrectionType != autocorrectionType {
                        strongSelf.textNode.textField.autocorrectionType = autocorrectionType
                    }
                    
                    if let currentText = strongSelf.textNode.textField.text {
                        if currentText != item.amount {
                            strongSelf.textNode.textField.attributedText = attributedAmountText
                        }
                    } else {
                        strongSelf.textNode.textField.attributedText = attributedAmountText
                    }
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset - 67.0, y: floor((layout.contentSize.height - 48.0) / 2.0) + verticalOffset), size: CGSize(width: max(1.0, params.width + iconSize.width - 5.0 + 100.0), height: 48.0))
                                                            
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 1)
                    }
                    
                    let bottomStripeInset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                        default:
                            bottomStripeInset = 0.0
                            strongSelf.bottomStripeNode.isHidden = false
                    }
                                                            
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: layout.size.width - bottomStripeInset, height: separatorHeight))
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                    
                    if strongSelf.textNode.textField.attributedPlaceholder == nil || !strongSelf.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.textField.attributedPlaceholder = attributedPlaceholderText
                        strongSelf.textNode.textField.accessibilityHint = attributedPlaceholderText.string
                    }
                   
                    inputFieldApply()
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
    
    @objc private func textFieldTextChanged(_ textField: UITextField) {
        self.textUpdated(self.textNode.textField.text ?? "")
        self.updateInputField()
    }
    
    @objc private func clearButtonPressed() {
        self.textNode.textField.text = ""
        self.textUpdated("")
    }
    
    private func textUpdated(_ text: String) {
        self.item?.textUpdated(text)
    }
    
    func focus() {
        if !self.textNode.textField.isFirstResponder {
            self.textNode.textField.becomeFirstResponder()
        }
    }
    
    @objc func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        if let item = self.item {
            if !item.shouldUpdateText(newText) {
                return false
            }
        }
        
        if string.count > 1, let item = self.item, let processPaste = item.processPaste {
            let result = processPaste(string)
            if result != string {
                var text = textField.text ?? ""
                text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: result)
                textField.attributedText = amountAttributedString(text, integralFont: integralFont, fractionalFont: fractionalFont, color: item.theme.list.itemPrimaryTextColor)
                if let startPosition = textField.position(from: textField.beginningOfDocument, offset: range.lowerBound + result.count) {
                    let selectionRange = textField.textRange(from: startPosition, to: startPosition)
                    DispatchQueue.main.async {
                        textField.selectedTextRange = selectionRange
                    }
                }
                self.textFieldTextChanged(textField)
                return false
            }
        }
        if let item = self.item {
            textField.attributedText = amountAttributedString(newText, integralFont: integralFont, fractionalFont: fractionalFont, color: item.theme.list.itemPrimaryTextColor)
            self.textFieldTextChanged(textField)
            return false
        } else {
            return true
        }
    }
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        self.item?.updatedFocus?(true)
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        self.item?.updatedFocus?(false)
    }
}
