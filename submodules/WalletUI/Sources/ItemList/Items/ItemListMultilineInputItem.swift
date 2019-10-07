import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

enum ItemListMultilineInputItemTextLimitMode {
    case characters
    case bytes
}

struct ItemListMultilineInputItemTextLimit {
    let value: Int
    let display: Bool
    let mode: ItemListMultilineInputItemTextLimitMode
    
    init(value: Int, display: Bool, mode: ItemListMultilineInputItemTextLimitMode = .characters) {
        self.value = value
        self.display = display
        self.mode = mode
    }
}

struct ItemListMultilineInputInlineAction {
    let icon: UIImage
    let action: (() -> Void)?
    
    init(icon: UIImage, action: (() -> Void)?) {
        self.icon = icon
        self.action = action
    }
}

class ItemListMultilineInputItem: ListViewItem, ItemListItem {
    let theme: WalletTheme
    let text: String
    let placeholder: String
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let capitalization: Bool
    let autocorrection: Bool
    let returnKeyType: UIReturnKeyType
    let action: (() -> Void)?
    let textUpdated: (String) -> Void
    let shouldUpdateText: (String) -> Bool
    let processPaste: ((String) -> Void)?
    let updatedFocus: ((Bool) -> Void)?
    let maxLength: ItemListMultilineInputItemTextLimit?
    let minimalHeight: CGFloat?
    let inlineAction: ItemListMultilineInputInlineAction?
    let tag: ItemListItemTag?
    
    init(theme: WalletTheme, text: String, placeholder: String, maxLength: ItemListMultilineInputItemTextLimit?, sectionId: ItemListSectionId, style: ItemListStyle, capitalization: Bool = true, autocorrection: Bool = true, returnKeyType: UIReturnKeyType = .default, minimalHeight: CGFloat? = nil, textUpdated: @escaping (String) -> Void, shouldUpdateText: @escaping (String) -> Bool = { _ in return true }, processPaste: ((String) -> Void)? = nil, updatedFocus: ((Bool) -> Void)? = nil, tag: ItemListItemTag? = nil, action: (() -> Void)? = nil, inlineAction: ItemListMultilineInputInlineAction? = nil) {
        self.theme = theme
        self.text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.sectionId = sectionId
        self.style = style
        self.capitalization = capitalization
        self.autocorrection = autocorrection
        self.returnKeyType = returnKeyType
        self.minimalHeight = minimalHeight
        self.textUpdated = textUpdated
        self.shouldUpdateText = shouldUpdateText
        self.processPaste = processPaste
        self.updatedFocus = updatedFocus
        self.tag = tag
        self.action = action
        self.inlineAction = inlineAction
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListMultilineInputItemNode()
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
            if let nodeValue = node() as? ItemListMultilineInputItemNode {
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

private let titleFont = Font.regular(17.0)

class ItemListMultilineInputItemNode: ListViewItemNode, ASEditableTextNodeDelegate, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let textClippingNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let measureTextNode: TextNode
    
    private let limitTextNode: TextNode
    private var inlineActionButtonNode: HighlightableButtonNode?
    
    private var item: ItemListMultilineInputItem?
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
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        
        self.textNode = EditableTextNode()
        self.measureTextNode = TextNode()
        
        self.limitTextNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.textClippingNode.addSubnode(self.textNode)
        self.addSubnode(self.textClippingNode)
        
    }
    
    override func didLoad() {
        super.didLoad()
        
        var textColor: UIColor = .black
        if let item = self.item {
            textColor = item.theme.list.itemPrimaryTextColor
        }
        self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: textColor]
        self.textNode.clipsToBounds = true
        self.textNode.delegate = self
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func asyncLayout() -> (_ item: ItemListMultilineInputItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        let makeLimitTextLayout = TextNode.asyncLayout(self.limitTextNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: WalletTheme?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.rightInset
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
                case .blocks:
                    itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
            }
            
            var limitTextString: NSAttributedString?
            var rightInset: CGFloat = params.rightInset
            
            if let maxLength = item.maxLength, maxLength.display {
                let textLength: Int
                switch maxLength.mode {
                case .characters:
                    textLength = item.text.count
                case .bytes:
                    textLength = item.text.data(using: .utf8, allowLossyConversion: true)?.count ?? 0
                }
                let displayTextLimit = textLength > maxLength.value * 70 / 100
                let remainingCount = maxLength.value - textLength
                if displayTextLimit {
                    limitTextString = NSAttributedString(string: "\(remainingCount)", font: Font.regular(13.0), textColor: remainingCount < 0 ? item.theme.list.itemDestructiveColor : item.theme.list.itemSecondaryTextColor)
                }
                
                rightInset += 30.0 + 4.0
            }
            
            let (limitTextLayout, limitTextApply) = makeLimitTextLayout(TextNodeLayoutArguments(attributedString: limitTextString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 100.0), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            if limitTextLayout.size.width > 30.0 {
                rightInset += 30.0
            }
            
            if let inlineAction = item.inlineAction {
                rightInset += inlineAction.icon.size.width + 8.0
            }
            
            var measureText = item.text
            if measureText.hasSuffix("\n") || measureText.isEmpty {
               measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            let attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedMeasureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - 16.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let textTopInset: CGFloat = 11.0
            let textBottomInset: CGFloat = 11.0
            
            var contentHeight: CGFloat = textLayout.size.height + textTopInset + textBottomInset
            if let minimalHeight = item.minimalHeight {
                contentHeight = max(minimalHeight, contentHeight)
            }
            
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        
                        if strongSelf.isNodeLoaded {
                            strongSelf.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: item.theme.list.itemPrimaryTextColor]
                            strongSelf.textNode.tintColor = item.theme.list.itemAccentColor
                        }
                        
                        if let inlineAction = item.inlineAction {
                            strongSelf.inlineActionButtonNode?.setImage(generateTintedImage(image: inlineAction.icon, color: item.theme.list.itemAccentColor), for: .normal)
                        }
                    }
                    
                    let capitalizationType: UITextAutocapitalizationType = item.capitalization ? .sentences : .none
                    let autocorrectionType: UITextAutocorrectionType = item.autocorrection ? .default : .no

                    if strongSelf.textNode.textView.autocapitalizationType != capitalizationType {
                        strongSelf.textNode.textView.autocapitalizationType = capitalizationType
                    }
                    if strongSelf.textNode.textView.autocorrectionType != autocorrectionType {
                        strongSelf.textNode.textView.autocorrectionType = autocorrectionType
                    }
                    if strongSelf.textNode.textView.returnKeyType != item.returnKeyType {
                        strongSelf.textNode.textView.returnKeyType = item.returnKeyType
                    }
                    
                    let _ = textApply()
                    if let currentText = strongSelf.textNode.attributedText {
                        if currentText.string != attributedText.string || updatedTheme != nil {
                            strongSelf.textNode.attributedText = attributedText
                        }
                    } else {
                        strongSelf.textNode.attributedText = attributedText
                    }
                    
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
                        default:
                            bottomStripeInset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    if strongSelf.textNode.attributedPlaceholderText == nil || !strongSelf.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.attributedPlaceholderText = attributedPlaceholderText
                    }
                    
                    strongSelf.textNode.keyboardAppearance = item.theme.keyboardAppearance
                    
                    strongSelf.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: params.width - leftInset - params.rightInset, height: textLayout.size.height))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width - leftInset - 16.0 - rightInset, height: textLayout.size.height + 1.0))
                    
                    let _ = limitTextApply()
                    strongSelf.limitTextNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 16.0 - limitTextLayout.size.width, y: layout.contentSize.height - 15.0 - limitTextLayout.size.height), size: limitTextLayout.size)
                    if limitTextString != nil {
                        if strongSelf.limitTextNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.limitTextNode)
                        }
                    } else if strongSelf.limitTextNode.supernode != nil {
                        strongSelf.limitTextNode.removeFromSupernode()
                    }
                    
                    if let inlineAction = item.inlineAction {
                        let inlineActionButtonNode: HighlightableButtonNode
                        if let currentInlineActionButtonNode = strongSelf.inlineActionButtonNode {
                            inlineActionButtonNode = currentInlineActionButtonNode
                        } else {
                            inlineActionButtonNode = HighlightableButtonNode()
                            inlineActionButtonNode.setImage(generateTintedImage(image: inlineAction.icon, color: item.theme.list.itemAccentColor), for: .normal)
                            inlineActionButtonNode.addTarget(strongSelf, action: #selector(strongSelf.inlineActionPressed), forControlEvents: .touchUpInside)
                            strongSelf.addSubnode(inlineActionButtonNode)
                            strongSelf.inlineActionButtonNode = inlineActionButtonNode
                        }
                        inlineActionButtonNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - inlineAction.icon.size.width - 11.0, y: 7.0), size: inlineAction.icon.size)
                    } else if let inlineActionButtonNode = strongSelf.inlineActionButtonNode {
                        inlineActionButtonNode.removeFromSupernode()
                        strongSelf.inlineActionButtonNode = nil
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
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        guard let params = self.layoutParams else {
            return
        }
        
        let separatorHeight = UIScreenPixel
        let insets = self.insets
        let contentSize = CGSize(width: params.width, height: max(1.0, currentValue - insets.top - insets.bottom))
        
        let leftInset = 16.0 + params.leftInset
        let textTopInset: CGFloat = 11.0
        let textBottomInset: CGFloat = 11.0
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
        self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: self.bottomStripeNode.frame.minX, y: contentSize.height), size: CGSize(width: self.bottomStripeNode.frame.size.width, height: separatorHeight))
        
        self.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: max(0.0, params.width - leftInset - params.rightInset), height: max(0.0, contentSize.height - textTopInset - textBottomInset)))
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.item?.updatedFocus?(true)
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.item?.updatedFocus?(false)
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
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
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let item = self.item {
            if let text = self.textNode.attributedText {
                let updatedText = text.string
                let updatedAttributedText = NSAttributedString(string: updatedText, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
                if text.string != updatedAttributedText.string {
                    self.textNode.attributedText = updatedAttributedText
                }
                item.textUpdated(updatedText)
            } else {
                item.textUpdated("")
            }
        }
    }
    
    func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool {
        if let _ = self.item {
            let text: String? = UIPasteboard.general.string
            if let _ = text {
                return true
            }
        }
        return false
    }
    
    func focus() {
        if !self.textNode.textView.isFirstResponder {
            self.textNode.textView.becomeFirstResponder()
        }
    }
    
    func animateError() {
        self.textNode.layer.addShakeAnimation()
    }
    
    @objc private func inlineActionPressed() {
        if let action = self.item?.inlineAction?.action {
            action()
        }
    }
}
