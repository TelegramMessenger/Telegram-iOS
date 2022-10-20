import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import CheckNode

struct CreatePollOptionItemEditing {
    let editable: Bool
    let hasActiveRevealControls: Bool
}

class CreatePollOptionItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let id: Int
    let placeholder: String
    let value: String
    let isSelected: Bool?
    let maxLength: Int
    let editing: CreatePollOptionItemEditing
    let sectionId: ItemListSectionId
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    let updated: (String, Bool) -> Void
    let next: (() -> Void)?
    let delete: (Bool) -> Void
    let canDelete: Bool
    let canMove: Bool
    let focused: (Bool) -> Void
    let toggleSelected: () -> Void
    let tag: ItemListItemTag?
    
    init(presentationData: ItemListPresentationData, id: Int, placeholder: String, value: String, isSelected: Bool?, maxLength: Int, editing: CreatePollOptionItemEditing, sectionId: ItemListSectionId, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void, updated: @escaping (String, Bool) -> Void, next: (() -> Void)?, delete: @escaping (Bool) -> Void, canDelete: Bool, canMove: Bool, focused: @escaping (Bool) -> Void, toggleSelected: @escaping () -> Void, tag: ItemListItemTag?) {
        self.presentationData = presentationData
        self.id = id
        self.placeholder = placeholder
        self.value = value
        self.isSelected = isSelected
        self.maxLength = maxLength
        self.editing = editing
        self.sectionId = sectionId
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.updated = updated
        self.next = next
        self.delete = delete
        self.canDelete = canDelete
        self.canMove = canMove
        self.focused = focused
        self.toggleSelected = toggleSelected
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
                    return (nil, { _ in apply(.None) })
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
                            apply(animation)
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
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var checkNode: InteractiveCheckNode?
    
    private let textClippingNode: ASDisplayNode
    private let textNode: EditableTextNode
    private let measureTextNode: TextNode
    
    private let textLimitNode: TextNode
    private let reorderControlNode: ItemListEditableReorderControlNode
    
    private var item: CreatePollOptionItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }
    
    var checkNodeFrame: CGRect? {
        guard let _ = self.layoutParams, let checkNode = self.checkNode else {
            return nil
        }
        return checkNode.frame
    }
    
    init() {
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.reorderControlNode = ItemListEditableReorderControlNode()
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        
        self.textNode = EditableTextNode()
        self.measureTextNode = TextNode()
        
        self.textLimitNode = TextNode()
        self.textLimitNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.containerNode)
        
        self.textClippingNode.addSubnode(self.textNode)
        self.containerNode.addSubnode(self.textClippingNode)
        
        self.containerNode.addSubnode(self.reorderControlNode)
        self.containerNode.addSubnode(self.textLimitNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        var textColor: UIColor = .black
        if let item = self.item {
            textColor = item.presentationData.theme.list.itemPrimaryTextColor
        }
        self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: textColor]
        self.textNode.clipsToBounds = true
        self.textNode.delegate = self
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.item?.focused(true)
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.internalEditableTextNodeDidUpdateText(editableTextNode, isLosingFocus: true)
        self.item?.focused(false)
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
                let updatedAttributedText = NSAttributedString(string: updatedText, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
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
        self.internalEditableTextNodeDidUpdateText(editableTextNode, isLosingFocus: false)
    }
        
    private func internalEditableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode, isLosingFocus: Bool) {
        if let item = self.item {
            let text = self.textNode.attributedText ?? NSAttributedString()
                
            var updatedText = text.string
            var hadReturn = false
            if updatedText.firstIndex(of: "\n") != nil {
                hadReturn = true
                updatedText = updatedText.replacingOccurrences(of: "\n", with: " ")
            }
            let updatedAttributedText = NSAttributedString(string: updatedText, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            if text.string != updatedAttributedText.string {
                self.textNode.attributedText = updatedAttributedText
            }
            item.updated(updatedText, !isLosingFocus && editableTextNode.isFirstResponder())
            if hadReturn {
                if let next = item.next {
                    next()
                } else if !isLosingFocus {
                    editableTextNode.resignFirstResponder()
                }
            }
        }
    }
    
    func editableTextNodeBackspaceWhileEmpty(_ editableTextNode: ASEditableTextNode) {
        self.item?.delete(editableTextNode.isFirstResponder())
    }
    
    func asyncLayout() -> (_ item: CreatePollOptionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        let makeTextLimitLayout = TextNode.asyncLayout(self.textLimitNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let reorderSizeAndApply = reorderControlLayout(item.presentationData.theme)
            
            let separatorHeight = UIScreenPixel
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let leftInset: CGFloat = params.leftInset + (item.isSelected != nil ? 60.0 : 16.0)
            let rightInset: CGFloat = 44.0 + params.rightInset
            
            let textLength = item.value.count
            let displayTextLimit = textLength > item.maxLength * 70 / 100
            let remainingCount = item.maxLength - textLength
            
            let (textLimitLayout, textLimitApply) = makeTextLimitLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(remainingCount)", font: Font.regular(13.0), textColor: remainingCount < 0 ? item.presentationData.theme.list.itemDestructiveColor : item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: .greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            var measureText = item.value
            if measureText.hasSuffix("\n") || measureText.isEmpty {
                measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            let attributedText = NSAttributedString(string: item.value, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedMeasureText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, lineSpacing: 0.05, cutout: nil, insets: UIEdgeInsets()))
            
            let textTopInset: CGFloat = 11.0
            let textBottomInset: CGFloat = 11.0
            
            let contentSize = CGSize(width: params.width, height: textLayout.size.height + textTopInset + textBottomInset)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] animation in
                if let strongSelf = self {
                    let transition: ContainedViewLayoutTransition
                    switch animation {
                    case .System:
                        transition = .animated(duration: 0.3, curve: .spring)
                    default:
                        transition = .immediate
                    }
                    
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        
                        if strongSelf.isNodeLoaded {
                            strongSelf.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: item.presentationData.theme.list.itemPrimaryTextColor]
                            strongSelf.textNode.tintColor = item.presentationData.theme.list.itemAccentColor
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
                        if currentText.string != attributedText.string || updatedTheme != nil {
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
                    
                    strongSelf.textNode.keyboardAppearance = item.presentationData.theme.rootController.keyboardColor.keyboardAppearance
                    
                    let checkSize = CGSize(width: 22.0, height: 22.0)
                    let checkFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset + 16.0, y: floor((layout.contentSize.height - checkSize.height) / 2.0)), size: checkSize)
                    if let isSelected = item.isSelected {
                        if let checkNode = strongSelf.checkNode {
                            transition.updateFrame(node: checkNode, frame: checkFrame)
                            checkNode.setSelected(isSelected, animated: true)
                        } else {
                            let checkNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: item.presentationData.theme.list.itemSwitchColors.positiveColor, strokeColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, borderColor: item.presentationData.theme.list.itemCheckColors.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false))
                            checkNode.setSelected(isSelected, animated: false)
                            checkNode.valueChanged = { [weak self] value in
                                self?.item?.toggleSelected()
                            }
                            strongSelf.checkNode = checkNode
                            strongSelf.containerNode.addSubnode(checkNode)
                            checkNode.frame = checkFrame
                            transition.animatePositionAdditive(node: checkNode, offset: CGPoint(x: -checkFrame.maxX, y: 0.0))
                        }
                        
                        if let checkNode = strongSelf.checkNode {
                            transition.updateAlpha(node: checkNode, alpha: strongSelf.textNode.textView.text.isEmpty && item.placeholder == item.presentationData.strings.CreatePoll_AddOption ? 0.0 : 1.0)
                        }
                    } else if let checkNode = strongSelf.checkNode {
                        strongSelf.checkNode = nil
                        transition.updateFrame(node: checkNode, frame: checkFrame.offsetBy(dx: -checkFrame.maxX, dy: 0.0), completion: { [weak checkNode] _ in
                            checkNode?.removeFromSupernode()
                        })
                    }
                    
                    transition.updateFrame(node: strongSelf.textClippingNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset, y: textTopInset), size: CGSize(width: params.width - leftInset - params.rightInset, height: textLayout.size.height)))
                    transition.updateFrame(node: strongSelf.textNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: params.width - leftInset - rightInset, height: textLayout.size.height + 1.0)))
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.containerNode.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    let bottomStripeWasHidden = strongSelf.bottomStripeNode.isHidden
                    
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
                    
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layout.contentSize.width, height: separatorHeight))
                    if strongSelf.animationForKey("apparentHeight") == nil {
                        strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        let previousX = strongSelf.bottomStripeNode.frame.minX
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: layout.contentSize.width, height: separatorHeight))
                        if !bottomStripeWasHidden {
                            transition.animatePositionAdditive(node: strongSelf.bottomStripeNode, offset: CGPoint(x: previousX - strongSelf.bottomStripeNode.frame.minX, y: 0.0))
                        }
                    } else {
                        let previousX = strongSelf.bottomStripeNode.frame.minX
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: strongSelf.bottomStripeNode.frame.minY), size: CGSize(width: layout.contentSize.width, height: separatorHeight))
                        if !bottomStripeWasHidden {
                            transition.animatePositionAdditive(node: strongSelf.bottomStripeNode, offset: CGPoint(x: previousX - strongSelf.bottomStripeNode.frame.minX, y: 0.0))
                        }
                    }
                    
                    let _ = reorderSizeAndApply.1(layout.contentSize.height, displayTextLimit, transition)
                    let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderSizeAndApply.0, y: 0.0), size: CGSize(width: reorderSizeAndApply.0, height: layout.contentSize.height))
                    strongSelf.reorderControlNode.frame = reorderControlFrame
                    strongSelf.reorderControlNode.isHidden = !item.canMove
                    
                    let _ = textLimitApply()
                    strongSelf.textLimitNode.frame = CGRect(origin: CGPoint(x: reorderControlFrame.minX + floor((reorderControlFrame.width - textLimitLayout.size.width) / 2.0) - 4.0 - UIScreenPixel, y: max(floor(reorderControlFrame.midY + 2.0), layout.contentSize.height - 15.0 - textLimitLayout.size.height)), size: textLimitLayout.size)
                    strongSelf.textLimitNode.isHidden = !displayTextLimit
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: [], right: item.canDelete ? [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)] : []))
                }
            })
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        guard let params = self.layoutParams, let item = self.item else {
            return
        }
        
        let revealOffset = offset
        
        let leftInset: CGFloat
        leftInset = params.leftInset + (item.isSelected != nil ? 60.0 : 16.0)
        
        if let checkNode = self.checkNode {
            var checkNodeFrame = checkNode.frame
            checkNodeFrame.origin.x = params.leftInset + 11.0 + revealOffset
            transition.updateFrame(node: checkNode, frame: checkNodeFrame)
        }
        
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
        if self.reorderControlNode.frame.contains(point), !self.reorderControlNode.isHidden, !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        var separatorFrame = self.bottomStripeNode.frame
        separatorFrame.origin.y = currentValue - UIScreenPixel
        self.bottomStripeNode.frame = separatorFrame
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.containerNode.bounds.width, height: currentValue))
        
        let insets = self.insets
        let separatorHeight = UIScreenPixel
        guard let params = self.layoutParams else {
            return
        }
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: self.containerNode.bounds.width, height: currentValue + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
        self.maskNode.frame = self.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
    }
}
