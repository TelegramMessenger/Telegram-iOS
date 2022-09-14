import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import TextFormat
import ObjCRuntimeUtils
import TextInputMenu

public enum CreatePollTextInputItemTextLimitMode {
    case characters
    case bytes
}

public struct CreatePollTextInputItemTextLimit {
    public let value: Int
    public let display: Bool
    public let mode: CreatePollTextInputItemTextLimitMode
    
    public init(value: Int, display: Bool, mode: CreatePollTextInputItemTextLimitMode = .characters) {
        self.value = value
        self.display = display
        self.mode = mode
    }
}

public struct ItemListMultilineInputInlineAction {
    public let icon: UIImage
    public let action: (() -> Void)?
    
    public init(icon: UIImage, action: (() -> Void)?) {
        self.icon = icon
        self.action = action
    }
}

public class CreatePollTextInputItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let text: NSAttributedString
    let placeholder: String
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let capitalization: Bool
    let autocorrection: Bool
    let returnKeyType: UIReturnKeyType
    let action: (() -> Void)?
    let textUpdated: (NSAttributedString) -> Void
    let shouldUpdateText: (String) -> Bool
    let processPaste: ((String) -> Void)?
    let updatedFocus: ((Bool) -> Void)?
    let maxLength: CreatePollTextInputItemTextLimit?
    let minimalHeight: CGFloat?
    let inlineAction: ItemListMultilineInputInlineAction?
    public let tag: ItemListItemTag?
    
    public init(presentationData: ItemListPresentationData, text: NSAttributedString, placeholder: String, maxLength: CreatePollTextInputItemTextLimit?, sectionId: ItemListSectionId, style: ItemListStyle, capitalization: Bool = true, autocorrection: Bool = true, returnKeyType: UIReturnKeyType = .default, minimalHeight: CGFloat? = nil, textUpdated: @escaping (NSAttributedString) -> Void, shouldUpdateText: @escaping (String) -> Bool = { _ in return true }, processPaste: ((String) -> Void)? = nil, updatedFocus: ((Bool) -> Void)? = nil, tag: ItemListItemTag? = nil, action: (() -> Void)? = nil, inlineAction: ItemListMultilineInputInlineAction? = nil) {
        self.presentationData = presentationData
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
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CreatePollTextInputItemNode()
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
            if let nodeValue = node() as? CreatePollTextInputItemNode {
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

public class CreatePollTextInputItemNode: ListViewItemNode, ASEditableTextNodeDelegate, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let textClippingNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let measureTextNode: TextNode
    
    private let limitTextNode: TextNode
    private var inlineActionButtonNode: HighlightableButtonNode?
    
    private var item: CreatePollTextInputItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    private let inputMenu = TextInputMenu()
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init() {
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
    
    public func asyncLayout() -> (_ item: CreatePollTextInputItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        let makeLimitTextLayout = TextNode.asyncLayout(self.limitTextNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            let leftInset = 16.0 + params.rightInset
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
            }
            
            var limitTextString: NSAttributedString?
            var rightInset: CGFloat = params.rightInset
            
            if let maxLength = item.maxLength, maxLength.display {
                let textLength: Int
                switch maxLength.mode {
                case .characters:
                    textLength = item.text.string.count
                case .bytes:
                    textLength = item.text.string.data(using: .utf8, allowLossyConversion: true)?.count ?? 0
                }
                let displayTextLimit = textLength > maxLength.value * 70 / 100
                let remainingCount = maxLength.value - textLength
                if displayTextLimit {
                    limitTextString = NSAttributedString(string: "\(remainingCount)", font: Font.regular(13.0), textColor: remainingCount < 0 ? item.presentationData.theme.list.itemDestructiveColor : item.presentationData.theme.list.itemSecondaryTextColor)
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
            
            let itemText = textAttributedStringForStateText(item.text, fontSize: 17.0, textColor: item.presentationData.theme.chat.inputPanel.primaryTextColor, accentTextColor: item.presentationData.theme.chat.inputPanel.panelControlAccentColor, writingDirection: nil, spoilersRevealed: false, availableEmojis: Set(), emojiViewProvider: nil)
            let measureText = NSMutableAttributedString(attributedString: itemText)
            let measureRawString = measureText.string
            if measureRawString.hasSuffix("\n") || measureRawString.isEmpty {
                measureText.append(NSAttributedString(string: "|", font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: .black))
            }
            let attributedText = itemText
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: measureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - 16.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let textTopInset: CGFloat = 11.0
            let textBottomInset: CGFloat = 11.0
            
            var contentHeight: CGFloat = textLayout.size.height + textTopInset + textBottomInset
            if let minimalHeight = item.minimalHeight {
                contentHeight = max(minimalHeight, contentHeight)
            }
            
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        
                        if strongSelf.isNodeLoaded {
                            strongSelf.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), NSAttributedString.Key.foregroundColor.rawValue: item.presentationData.theme.list.itemPrimaryTextColor]
                            strongSelf.textNode.tintColor = item.presentationData.theme.list.itemAccentColor
                        }
                        
                        if let inlineAction = item.inlineAction {
                            strongSelf.inlineActionButtonNode?.setImage(generateTintedImage(image: inlineAction.icon, color: item.presentationData.theme.list.itemAccentColor), for: .normal)
                        }
                        
                        strongSelf.inputMenu.updateStrings(item.presentationData.strings)
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
                            refreshGenericTextInputAttributes(strongSelf.textNode, theme: item.presentationData.theme, baseFontSize: 17.0, availableEmojis: Set(), emojiViewProvider: nil)
                        }
                    } else {
                        strongSelf.textNode.attributedText = attributedText
                        refreshGenericTextInputAttributes(strongSelf.textNode, theme: item.presentationData.theme, baseFontSize: 17.0, availableEmojis: Set(), emojiViewProvider: nil)
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
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    if strongSelf.textNode.attributedPlaceholderText == nil || !strongSelf.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.attributedPlaceholderText = attributedPlaceholderText
                    }
                    
                    strongSelf.textNode.keyboardAppearance = item.presentationData.theme.rootController.keyboardColor.keyboardAppearance
                    
                    if strongSelf.animationForKey("apparentHeight") == nil {
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: params.width - leftInset - params.rightInset, height: textLayout.size.height))
                    }
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
                            inlineActionButtonNode.setImage(generateTintedImage(image: inlineAction.icon, color: item.presentationData.theme.list.itemAccentColor), for: .normal)
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
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
        self.maskNode.frame = self.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
        self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: self.bottomStripeNode.frame.minX, y: contentSize.height), size: CGSize(width: self.bottomStripeNode.frame.size.width, height: separatorHeight))
        
        self.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: max(0.0, params.width - leftInset - params.rightInset), height: max(0.0, contentSize.height - textTopInset - textBottomInset)))
    }
    
    public func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.item?.updatedFocus?(true)
        self.inputMenu.activate()
    }
    
    public func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.item?.updatedFocus?(false)
        self.inputMenu.deactivate()
    }
    
    public func editableTextNodeTarget(forAction action: Selector) -> ASEditableTextNodeTargetForAction? {
       if action == makeSelectorFromString("_showTextStyleOptions:") {
           if #available(iOS 16.0, *) {
               return ASEditableTextNodeTargetForAction(target: nil)
           } else {
               if case .general = self.inputMenu.state {
                   if self.textNode.attributedText == nil || self.textNode.attributedText!.length == 0 || self.textNode.selectedRange.length == 0 {
                       return ASEditableTextNodeTargetForAction(target: nil)
                   }
                   return ASEditableTextNodeTargetForAction(target: self)
               } else {
                   return ASEditableTextNodeTargetForAction(target: nil)
               }
           }
        } else if action == #selector(self.formatAttributesBold(_:)) || action == #selector(self.formatAttributesItalic(_:)) || action == #selector(self.formatAttributesMonospace(_:)) || action == #selector(self.formatAttributesLink(_:)) || action == #selector(self.formatAttributesStrikethrough(_:)) || action == #selector(self.formatAttributesUnderline(_:)) {
            if case .format = self.inputMenu.state {
                return ASEditableTextNodeTargetForAction(target: self)
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        }
        if case .format = self.inputMenu.state {
            return ASEditableTextNodeTargetForAction(target: nil)
        }
        return nil
    }
    
    @objc func _showTextStyleOptions(_ sender: Any) {
        self.inputMenu.format(view: self.textNode.view, rect: self.textNode.selectionRect.offsetBy(dx: 0.0, dy: -self.textNode.textView.contentOffset.y).insetBy(dx: 0.0, dy: -1.0))
    }
    
    @available(iOS 16.0, *)
    public func editableTextNodeMenu(_ editableTextNode: ASEditableTextNode, forTextRange textRange: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu {
        var actions = suggestedActions
        
        if editableTextNode.attributedText == nil || editableTextNode.attributedText!.length == 0 || editableTextNode.selectedRange.length == 0 {
            
        } else if let strings = self.item?.presentationData.strings {
            let children: [UIAction] = [
                UIAction(title: strings.TextFormat_Bold, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesBold(strongSelf)
                    }
                },
                UIAction(title: strings.TextFormat_Italic, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesItalic(strongSelf)
                    }
                },
                UIAction(title: strings.TextFormat_Monospace, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesMonospace(strongSelf)
                    }
                },
                UIAction(title: strings.TextFormat_Link, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesLink(strongSelf)
                    }
                },
                UIAction(title: strings.TextFormat_Strikethrough, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesStrikethrough(strongSelf)
                    }
                },
                UIAction(title: strings.TextFormat_Underline, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesUnderline(strongSelf)
                    }
                },
                UIAction(title: strings.TextFormat_Spoiler, image: nil) { [weak self] (action) in
                    if let strongSelf = self {
                        strongSelf.formatAttributesSpoiler(strongSelf)
                    }
                }
            ]
            
            let formatMenu = UIMenu(title: strings.TextFormat_Format, image: nil, children: children)
            actions.insert(formatMenu, at: 3)
        }
        
        return UIMenu(children: actions)
    }
    
    @objc func formatAttributesBold(_ sender: Any) {
        self.inputMenu.back()
        if let item = self.item {
            chatTextInputAddFormattingAttribute(item: item, textNode: self.textNode, theme: item.presentationData.theme, attribute: ChatTextInputAttributes.bold)
        }
    }
    
    @objc func formatAttributesItalic(_ sender: Any) {
        self.inputMenu.back()
        if let item = self.item {
            chatTextInputAddFormattingAttribute(item: item, textNode: self.textNode, theme: item.presentationData.theme, attribute: ChatTextInputAttributes.italic)
        }
    }
    
    @objc func formatAttributesMonospace(_ sender: Any) {
        self.inputMenu.back()
        if let item = self.item {
            chatTextInputAddFormattingAttribute(item: item, textNode: self.textNode, theme: item.presentationData.theme, attribute: ChatTextInputAttributes.monospace)
        }
    }
    
    @objc func formatAttributesLink(_ sender: Any) {
        self.inputMenu.back()
        //self.interfaceInteraction?.openLinkEditing()
    }
    
    @objc func formatAttributesStrikethrough(_ sender: Any) {
        self.inputMenu.back()
        if let item = self.item {
            chatTextInputAddFormattingAttribute(item: item, textNode: self.textNode, theme: item.presentationData.theme, attribute: ChatTextInputAttributes.strikethrough)
        }
    }
    
    @objc func formatAttributesUnderline(_ sender: Any) {
        self.inputMenu.back()
        if let item = self.item {
            chatTextInputAddFormattingAttribute(item: item, textNode: self.textNode, theme: item.presentationData.theme, attribute: ChatTextInputAttributes.underline)
        }
    }
    
    @objc func formatAttributesSpoiler(_ sender: Any) {
        self.inputMenu.back()
        if let item = self.item {
            chatTextInputAddFormattingAttribute(item: item, textNode: self.textNode, theme: item.presentationData.theme, attribute: ChatTextInputAttributes.spoiler)
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
            if let _ = self.textNode.attributedText {
                refreshGenericTextInputAttributes(editableTextNode, theme: item.presentationData.theme, baseFontSize: 17.0, availableEmojis: Set(), emojiViewProvider: nil)
                let updatedText = stateAttributedStringForText(self.textNode.attributedText!)
                item.textUpdated(updatedText)
            } else {
                item.textUpdated(NSAttributedString(string: ""))
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
    
    public func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool) {
        /*if !dueToEditing && !self.updatingInputState {
        }*/
        
        if let item = self.item {
            if case .format = self.inputMenu.state {
                self.inputMenu.deactivate()
                UIMenuController.shared.update()
            }
            
            refreshChatTextInputTypingAttributes(editableTextNode, theme: item.presentationData.theme, baseFontSize: 17.0)
            refreshGenericTextInputAttributes(editableTextNode, theme: item.presentationData.theme, baseFontSize: 17.0, availableEmojis: Set(), emojiViewProvider: nil)
        }
    }
    
    public func focus() {
        if !self.textNode.textView.isFirstResponder {
            self.textNode.textView.becomeFirstResponder()
        }
    }
    
    public func animateError() {
        self.textNode.layer.addShakeAnimation()
    }
    
    @objc private func inlineActionPressed() {
        if let action = self.item?.inlineAction?.action {
            action()
        }
    }
}

private func chatTextInputAddFormattingAttribute(item: CreatePollTextInputItem, textNode: EditableTextNode, theme: PresentationTheme, attribute: NSAttributedString.Key) {
    if let currentText = textNode.attributedText, textNode.selectedRange.length > 0 {
        let nsRange = NSRange(location: textNode.selectedRange.location, length: textNode.selectedRange.length)
        var addAttribute = true
        var attributesToRemove: [NSAttributedString.Key] = []
        currentText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
            for (key, _) in attributes {
                if key == attribute && range == nsRange {
                    addAttribute = false
                    attributesToRemove.append(key)
                }
            }
        }
        
        let result = NSMutableAttributedString(attributedString: currentText)
        for attribute in attributesToRemove {
            result.removeAttribute(attribute, range: nsRange)
        }
        if addAttribute {
            result.addAttribute(attribute, value: true as Bool, range: nsRange)
        }
        
        textNode.attributedText = result
        textNode.selectedRange = nsRange
        
        refreshChatTextInputTypingAttributes(textNode, theme: theme, baseFontSize: 17.0)
        refreshGenericTextInputAttributes(textNode, theme: theme, baseFontSize: 17.0, availableEmojis: Set(), emojiViewProvider: nil)
        
        let updatedText = stateAttributedStringForText(textNode.attributedText!)
        item.textUpdated(updatedText)
    }
}
