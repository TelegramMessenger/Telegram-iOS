import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

struct CreatePollOptionItemEditing {
    let editable: Bool
    let hasActiveRevealControls: Bool
}

class CreatePollOptionItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let id: Int
    let placeholder: String
    let value: String
    let maxLength: Int
    let editing: CreatePollOptionItemEditing
    let sectionId: ItemListSectionId
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    let updated: (String) -> Void
    let next: (() -> Void)?
    let delete: (Bool) -> Void
    let focused: () -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, id: Int, placeholder: String, value: String, maxLength: Int, editing: CreatePollOptionItemEditing, sectionId: ItemListSectionId, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void, updated: @escaping (String) -> Void, next: (() -> Void)?, delete: @escaping (Bool) -> Void, focused: @escaping () -> Void, tag: ItemListItemTag?) {
        self.theme = theme
        self.strings = strings
        self.id = id
        self.placeholder = placeholder
        self.value = value
        self.maxLength = maxLength
        self.editing = editing
        self.sectionId = sectionId
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.updated = updated
        self.next = next
        self.delete = delete
        self.focused = focused
        self.tag = tag
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CreatePollOptionItemNode()
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
            if let nodeValue = node() as? CreatePollOptionItemNode {
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

private let titleFont = Font.regular(15.0)

class CreatePollOptionItemNode: ItemListRevealOptionsItemNode, ItemListItemNode, ItemListItemFocusableNode, ASEditableTextNodeDelegate {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let textClippingNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let measureTextNode: TextNode
    
    private let textLimitNode: TextNode
    private let editableControlNode: ItemListEditableControlNode
    private let reorderControlNode: ItemListEditableReorderControlNode
    
    private var item: CreatePollOptionItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.editableControlNode = ItemListEditableControlNode()
        self.reorderControlNode = ItemListEditableReorderControlNode()
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        
        self.textNode = EditableTextNode()
        self.measureTextNode = TextNode()
        
        self.textLimitNode = TextNode()
        self.textLimitNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.clipsToBounds = true
        
        self.textClippingNode.addSubnode(self.textNode)
        self.addSubnode(self.textClippingNode)
        
        self.addSubnode(self.editableControlNode)
        self.addSubnode(self.reorderControlNode)
        self.addSubnode(self.textLimitNode)
        
        self.editableControlNode.tapped = { [weak self] in
            if let strongSelf = self {
                strongSelf.setRevealOptionsOpened(true, animated: true)
                strongSelf.revealOptionsInteractivelyOpened()
            }
        }
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
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.item?.focused()
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let item = self.item else {
            return false
        }
        if text.firstIndex(of: "\n") != nil {
            if text != "\n" {
                let currentText = editableTextNode.attributedText?.string ?? ""
                var updatedText = (currentText as NSString).replacingCharacters(in: range, with: text)
                updatedText = updatedText.replacingOccurrences(of: "\n", with: " ")
                if updatedText.count == 1 {
                    updatedText = ""
                }
                let updatedAttributedText = NSAttributedString(string: updatedText, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
                self.textNode.attributedText = updatedAttributedText
                self.editableTextNodeDidUpdateText(editableTextNode)
            }
            if let next = item.next {
                next()
            } else {
                editableTextNode.resignFirstResponder()
            }
            return false
        }
        return true
    }
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let item = self.item {
            let text = self.textNode.attributedText ?? NSAttributedString()
                
            var updatedText = text.string
            var hadReturn = false
            if updatedText.firstIndex(of: "\n") != nil {
                hadReturn = true
                updatedText = updatedText.replacingOccurrences(of: "\n", with: " ")
            }
            let updatedAttributedText = NSAttributedString(string: updatedText, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
            if text.string != updatedAttributedText.string {
                self.textNode.attributedText = updatedAttributedText
            }
            item.updated(updatedText)
            if hadReturn {
                if let next = item.next {
                    next()
                } else {
                    editableTextNode.resignFirstResponder()
                }
            }
        }
    }
    
    func editableTextNodeBackspaceWhileEmpty(_ editableTextNode: ASEditableTextNode) {
        self.item?.delete(editableTextNode.isFirstResponder())
    }
    
    func asyncLayout() -> (_ item: CreatePollOptionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        let makeTextLimitLayout = TextNode.asyncLayout(self.textLimitNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let controlSizeAndApply = editableControlLayout(item.theme, false)
            let reorderSizeAndApply = reorderControlLayout(item.theme)
            
            let separatorHeight = UIScreenPixel
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let leftInset: CGFloat = 60.0 + params.leftInset
            let rightInset: CGFloat = 44.0 + params.rightInset
            
            let textLength = item.value.count
            let displayTextLimit = textLength > item.maxLength * 70 / 100
            let remainingCount = item.maxLength - textLength
            
            let (textLimitLayout, textLimitApply) = makeTextLimitLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(remainingCount)", font: Font.regular(13.0), textColor: remainingCount < 0 ? item.theme.list.itemDestructiveColor : item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: .greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            var measureText = item.value
            if measureText.hasSuffix("\n") || measureText.isEmpty {
                measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            let attributedText = NSAttributedString(string: item.value, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedMeasureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.05, cutout: nil, insets: UIEdgeInsets()))
            
            let textTopInset: CGFloat = 11.0
            let textBottomInset: CGFloat = 11.0
            
            let contentSize = CGSize(width: params.width, height: textLayout.size.height + textTopInset + textBottomInset)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        
                        if strongSelf.isNodeLoaded {
                            strongSelf.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: item.theme.list.itemPrimaryTextColor]
                            strongSelf.textNode.tintColor = item.theme.list.itemAccentColor
                        }
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let capitalizationType: UITextAutocapitalizationType
                    let autocorrectionType: UITextAutocorrectionType
                    let keyboardType: UIKeyboardType
                    
                    capitalizationType = .sentences
                    autocorrectionType = .default
                    keyboardType = UIKeyboardType.default
                    
                    let _ = textApply()
                    if let currentText = strongSelf.textNode.attributedText {
                        if currentText.string !=  attributedText.string {
                            strongSelf.textNode.attributedText = attributedText
                        }
                    } else {
                        strongSelf.textNode.attributedText = attributedText
                    }
                    
                    if strongSelf.textNode.keyboardType != keyboardType {
                        strongSelf.textNode.keyboardType = keyboardType
                    }
                    if strongSelf.textNode.autocapitalizationType != capitalizationType {
                        strongSelf.textNode.autocapitalizationType = capitalizationType
                    }
                    if strongSelf.textNode.autocorrectionType != autocorrectionType {
                        strongSelf.textNode.autocorrectionType = autocorrectionType
                    }
                    let returnKeyType: UIReturnKeyType
                    if let _ = item.next {
                        returnKeyType = .next
                    } else {
                        returnKeyType = .done
                    }
                    if strongSelf.textNode.returnKeyType != returnKeyType {
                        strongSelf.textNode.returnKeyType = returnKeyType
                    }
                    
                    if strongSelf.textNode.attributedPlaceholderText == nil || !strongSelf.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.attributedPlaceholderText = attributedPlaceholderText
                    }
                    
                    strongSelf.textNode.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    
                    strongSelf.textClippingNode.frame = CGRect(origin: CGPoint(x: revealOffset + leftInset, y: textTopInset), size: CGSize(width: params.width - leftInset - params.rightInset, height: textLayout.size.height))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width - leftInset - rightInset, height: textLayout.size.height + 1.0))
                    
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
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layout.contentSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: layout.contentSize.width - bottomStripeInset, height: separatorHeight))
                    
                    let _ = controlSizeAndApply.1(layout.contentSize.height)
                    let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + 6.0 + revealOffset, y: 0.0), size: CGSize(width: controlSizeAndApply.0, height: contentSize.height))
                    strongSelf.editableControlNode.frame = editableControlFrame
                    
                    let _ = reorderSizeAndApply.1(layout.contentSize.height, displayTextLimit && layout.contentSize.height <= 44.0)
                    let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderSizeAndApply.0, y: 0.0), size: CGSize(width: reorderSizeAndApply.0, height: layout.contentSize.height))
                    strongSelf.reorderControlNode.frame = reorderControlFrame
                    
                    let _ = textLimitApply()
                    strongSelf.textLimitNode.frame = CGRect(origin: CGPoint(x: reorderControlFrame.minX + floor((reorderControlFrame.width - textLimitLayout.size.width) / 2.0) - 4.0 - UIScreenPixel, y: max(floor(reorderControlFrame.midY + 2.0), layout.contentSize.height - 15.0 - textLimitLayout.size.height)), size: textLimitLayout.size)
                    strongSelf.textLimitNode.isHidden = !displayTextLimit
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                }
            })
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams else {
            return
        }
        
        let revealOffset = offset
        
        let leftInset: CGFloat
        leftInset = 60.0 + params.leftInset
        
        var controlFrame = self.editableControlNode.frame
        controlFrame.origin.x = params.leftInset + 6.0 + revealOffset
        transition.updateFrame(node: self.editableControlNode, frame: controlFrame)
        
        var reorderFrame = self.reorderControlNode.frame
        reorderFrame.origin.x = params.width + revealOffset - params.rightInset - reorderFrame.width
        transition.updateFrame(node: self.reorderControlNode, frame: reorderFrame)
        
        var textClippingNodeFrame = self.textClippingNode.frame
        textClippingNodeFrame.origin.x = revealOffset + leftInset
        transition.updateFrame(node: self.textClippingNode, frame: textClippingNodeFrame)
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.layer.allowsGroupOpacity = true
        self.updateRevealOffsetInternal(offset: -self.bounds.width - 74.0, transition: .animated(duration: 0.2, curve: .spring), completion: { [weak self] in
            self?.layer.allowsGroupOpacity = false
        })
        self.item?.delete(self.textNode.isFirstResponder())
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        //self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        //self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    func focus() {
        self.textNode.becomeFirstResponder()
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        if self.reorderControlNode.frame.contains(point), !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        var separatorFrame = self.bottomStripeNode.frame
        separatorFrame.origin.y = currentValue - UIScreenPixel
        self.bottomStripeNode.frame = separatorFrame
    }
}
