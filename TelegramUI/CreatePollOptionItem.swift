import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

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
    let editing: CreatePollOptionItemEditing
    let sectionId: ItemListSectionId
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    let updated: (String) -> Void
    let delete: () -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, id: Int, placeholder: String, value: String, editing: CreatePollOptionItemEditing, sectionId: ItemListSectionId, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void, updated: @escaping (String) -> Void, delete: @escaping () -> Void, tag: ItemListItemTag?) {
        self.theme = theme
        self.strings = strings
        self.id = id
        self.placeholder = placeholder
        self.value = value
        self.editing = editing
        self.sectionId = sectionId
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.updated = updated
        self.delete = delete
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

class CreatePollOptionItemNode: ItemListRevealOptionsItemNode, ItemListItemNode, ItemListItemFocusableNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let textNode: TextFieldNode
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
        
        self.editableControlNode = ItemListEditableControlNode()
        self.reorderControlNode = ItemListEditableReorderControlNode()
        
        self.textNode = TextFieldNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.editableControlNode)
        self.addSubnode(self.reorderControlNode)
        
        self.editableControlNode.tapped = { [weak self] in
            if let strongSelf = self {
                strongSelf.setRevealOptionsOpened(true, animated: true)
                strongSelf.revealOptionsInteractivelyOpened()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textNode.textField.typingAttributes = [NSAttributedStringKey.font.rawValue: Font.regular(17.0)]
        self.textNode.textField.font = Font.regular(17.0)
        if let item = self.item {
            self.textNode.textField.textColor = item.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = item.theme.chatList.searchBarKeyboardColor.keyboardAppearance
        }
        self.textNode.clipsToBounds = true
        self.textNode.textField.delegate = self
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    @objc private func textFieldTextChanged(_ textField: UITextField) {
        if let item = self.item {
            item.updated(self.textNode.textField.text ?? "")
        }
    }
    
    func asyncLayout() -> (_ item: CreatePollOptionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let controlSizeAndApply = editableControlLayout(44.0, item.theme, false)
            let reorderSizeAndApply = reorderControlLayout(44.0, item.theme)
            
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: params.width, height: 44.0)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        
                        strongSelf.textNode.textField.textColor = item.theme.list.itemPrimaryTextColor
                        strongSelf.textNode.textField.keyboardAppearance = item.theme.chatList.searchBarKeyboardColor.keyboardAppearance
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let leftInset: CGFloat
                    leftInset = 60.0 + params.leftInset
                    let rightInset: CGFloat = 44.0
                    
                    let secureEntry: Bool
                    let capitalizationType: UITextAutocapitalizationType
                    let autocorrectionType: UITextAutocorrectionType
                    let keyboardType: UIKeyboardType
                    
                    secureEntry = false
                    capitalizationType = .sentences
                    autocorrectionType = .default
                    keyboardType = UIKeyboardType.default
                    
                    if strongSelf.textNode.textField.isSecureTextEntry != secureEntry {
                        strongSelf.textNode.textField.isSecureTextEntry = secureEntry
                    }
                    if strongSelf.textNode.textField.keyboardType != keyboardType {
                        strongSelf.textNode.textField.keyboardType = keyboardType
                    }
                    if strongSelf.textNode.textField.autocapitalizationType != capitalizationType {
                        strongSelf.textNode.textField.autocapitalizationType = capitalizationType
                    }
                    if strongSelf.textNode.textField.autocorrectionType != autocorrectionType {
                        strongSelf.textNode.textField.autocorrectionType = autocorrectionType
                    }
                    /*if strongSelf.textNode.textField.returnKeyType != item.returnKeyType {
                        strongSelf.textNode.textField.returnKeyType = item.returnKeyType
                    }*/
                    
                    if let currentText = strongSelf.textNode.textField.text {
                        if currentText != item.value {
                            strongSelf.textNode.textField.text = item.value
                        }
                    } else {
                        strongSelf.textNode.textField.text = item.value
                    }
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: revealOffset + leftInset, y: floor((layout.contentSize.height - 40.0) / 2.0)), size: CGSize(width: max(1.0, params.width - (leftInset + rightInset)), height: 40.0))
                    
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
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                        default:
                            bottomStripeInset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    if strongSelf.textNode.textField.attributedPlaceholder == nil || !strongSelf.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.textField.attributedPlaceholder = attributedPlaceholderText
                    }
                    
                    let _ = controlSizeAndApply.1()
                    let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + 6.0 + revealOffset, y: 0.0), size: controlSizeAndApply.0)
                    strongSelf.editableControlNode.frame = editableControlFrame
                    
                    let _ = reorderSizeAndApply.1()
                    let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderSizeAndApply.0.width, y: 0.0), size: reorderSizeAndApply.0)
                    strongSelf.reorderControlNode.frame = reorderControlFrame
                    
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
        
        var textNodeFrame = self.textNode.frame
        textNodeFrame.origin.x = revealOffset + leftInset
        transition.updateFrame(node: self.textNode, frame: textNodeFrame)
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.item?.delete()
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    func focus() {
        self.textNode.textField.becomeFirstResponder()
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        if self.reorderControlNode.frame.contains(point), !self.isDisplayingRevealedOptions {
            return true
        }
        return false
    }
}
