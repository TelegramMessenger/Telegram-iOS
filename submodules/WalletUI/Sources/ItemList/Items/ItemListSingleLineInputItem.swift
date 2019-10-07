import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

enum ItemListSingleLineInputItemType: Equatable {
    case regular(capitalization: Bool, autocorrection: Bool)
    case password
    case email
    case number
    case decimal
    case username
}

enum ItemListSingleLineInputClearType: Equatable {
    case none
    case always
    case onFocus
    
    var hasButton: Bool {
        switch self {
            case .none:
                return false
            case .always, .onFocus:
                return true
        }
    }
}

class ItemListSingleLineInputItem: ListViewItem, ItemListItem {
    let theme: WalletTheme
    let strings: WalletStrings
    let title: NSAttributedString
    let text: String
    let placeholder: String
    let type: ItemListSingleLineInputItemType
    let returnKeyType: UIReturnKeyType
    let spacing: CGFloat
    let clearType: ItemListSingleLineInputClearType
    let enabled: Bool
    let sectionId: ItemListSectionId
    let action: () -> Void
    let textUpdated: (String) -> Void
    let shouldUpdateText: (String) -> Bool
    let processPaste: ((String) -> String)?
    let updatedFocus: ((Bool) -> Void)?
    let tag: ItemListItemTag?
    
    init(theme: WalletTheme, strings: WalletStrings, title: NSAttributedString, text: String, placeholder: String, type: ItemListSingleLineInputItemType = .regular(capitalization: true, autocorrection: true), returnKeyType: UIReturnKeyType = .`default`, spacing: CGFloat = 0.0, clearType: ItemListSingleLineInputClearType = .none, enabled: Bool = true, tag: ItemListItemTag? = nil, sectionId: ItemListSectionId, textUpdated: @escaping (String) -> Void, shouldUpdateText: @escaping (String) -> Bool = { _ in return true }, processPaste: ((String) -> String)? = nil, updatedFocus: ((Bool) -> Void)? = nil, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.type = type
        self.returnKeyType = returnKeyType
        self.spacing = spacing
        self.clearType = clearType
        self.enabled = enabled
        self.tag = tag
        self.sectionId = sectionId
        self.textUpdated = textUpdated
        self.shouldUpdateText = shouldUpdateText
        self.processPaste = processPaste
        self.updatedFocus = updatedFocus
        self.action = action
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListSingleLineInputItemNode()
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
            if let nodeValue = node() as? ItemListSingleLineInputItemNode {
            
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

class ItemListSingleLineInputItemNode: ListViewItemNode, UITextFieldDelegate, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: TextNode
    private let textNode: TextFieldNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    
    private var item: ItemListSingleLineInputItem?
    
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
        
        self.titleNode = TextNode()
        self.textNode = TextFieldNode()
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        
        self.clearButtonNode = HighlightableButtonNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        
        self.clearButtonNode.addTarget(self, action: #selector(self.clearButtonPressed), forControlEvents: .touchUpInside)
        self.clearButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconNode.alpha = 0.4
                } else {
                    strongSelf.clearIconNode.alpha = 1.0
                    strongSelf.clearIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(17.0)]
        self.textNode.textField.font = Font.regular(17.0)
        if let item = self.item {
            self.textNode.textField.textColor = item.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = item.theme.keyboardAppearance
            self.textNode.textField.tintColor = item.theme.list.itemAccentColor
            self.textNode.textField.accessibilityHint = item.placeholder
        }
        self.textNode.clipsToBounds = true
        self.textNode.textField.delegate = self
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func asyncLayout() -> (_ item: ItemListSingleLineInputItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: WalletTheme?
            
            var updatedClearIcon: UIImage?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                updatedClearIcon = itemListClearInputIcon(item.theme)
            }
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            var rightInset: CGFloat = 16.0 + params.rightInset
            
            if item.clearType.hasButton {
                rightInset += 32.0
            }
            
            let titleString = NSMutableAttributedString(attributedString: item.title)
            titleString.removeAttribute(NSAttributedString.Key.font, range: NSMakeRange(0, titleString.length))
            titleString.addAttributes([NSAttributedString.Key.font: Font.regular(17.0)], range: NSMakeRange(0, titleString.length))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - 32.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: params.width, height: 44.0)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        
                        strongSelf.textNode.textField.textColor = item.theme.list.itemPrimaryTextColor
                        strongSelf.textNode.textField.keyboardAppearance = item.theme.keyboardAppearance
                        strongSelf.textNode.textField.tintColor = item.theme.list.itemAccentColor
                    }
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((layout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    
                    let secureEntry: Bool
                    let capitalizationType: UITextAutocapitalizationType
                    let autocorrectionType: UITextAutocorrectionType
                    let keyboardType: UIKeyboardType
                    
                    switch item.type {
                        case let .regular(capitalization, autocorrection):
                            secureEntry = false
                            capitalizationType = capitalization ? .sentences : .none
                            autocorrectionType = autocorrection ? .default : .no
                            keyboardType = .default
                        case .email:
                            secureEntry = false
                            capitalizationType = .none
                            autocorrectionType = .no
                            keyboardType = .emailAddress
                        case .password:
                            secureEntry = true
                            capitalizationType = .none
                            autocorrectionType = .no
                            keyboardType = .default
                        case .number:
                            secureEntry = false
                            capitalizationType = .none
                            autocorrectionType = .no
                            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                                keyboardType = .asciiCapableNumberPad
                            } else {
                                keyboardType = .numberPad
                            }
                        case .decimal:
                            secureEntry = false
                            capitalizationType = .none
                            autocorrectionType = .no
                            keyboardType = .decimalPad
                        case .username:
                            secureEntry = false
                            capitalizationType = .none
                            autocorrectionType = .no
                            keyboardType = .asciiCapable
                    }
                    
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
                    if strongSelf.textNode.textField.returnKeyType != item.returnKeyType {
                        strongSelf.textNode.textField.returnKeyType = item.returnKeyType
                    }
                    
                    if let currentText = strongSelf.textNode.textField.text {
                        if currentText != item.text {
                            strongSelf.textNode.textField.text = item.text
                        }
                    } else {
                        strongSelf.textNode.textField.text = item.text
                    }
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + item.spacing, y: floor((layout.contentSize.height - 40.0) / 2.0)), size: CGSize(width: max(1.0, params.width - (leftInset + rightInset + titleLayout.size.width + item.spacing)), height: 40.0))
                    
                    if let image = updatedClearIcon {
                        strongSelf.clearIconNode.image = image
                    }
                    
                    let buttonSize = CGSize(width: 38.0, height: layout.contentSize.height)
                    strongSelf.clearButtonNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - buttonSize.width, y: 0.0), size: buttonSize)
                    if let image = strongSelf.clearIconNode.image {
                        strongSelf.clearIconNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((layout.contentSize.height - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    strongSelf.updateClearButtonVisibility()
                    
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
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    if strongSelf.textNode.textField.attributedPlaceholder == nil || !strongSelf.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.textField.attributedPlaceholder = attributedPlaceholderText
                        strongSelf.textNode.textField.accessibilityHint = attributedPlaceholderText.string
                    }
                    
                    strongSelf.textNode.isUserInteractionEnabled = item.enabled
                    strongSelf.textNode.alpha = item.enabled ? 1.0 : 0.4
                    
                    strongSelf.clearButtonNode.accessibilityLabel = item.strings.Wallet_VoiceOver_Editing_ClearText
                }
            })
        }
    }
    
    private func updateClearButtonVisibility() {
        guard let item = self.item else {
            return
        }
        let isHidden: Bool
        switch item.clearType {
            case .none:
                isHidden = true
            case .always:
                isHidden = item.text.isEmpty
            case .onFocus:
                isHidden = !self.textNode.textField.isFirstResponder || item.text.isEmpty
        }
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc private func textFieldTextChanged(_ textField: UITextField) {
        self.textUpdated(self.textNode.textField.text ?? "")
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
        if let item = self.item {
            let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            if !item.shouldUpdateText(newText) {
                return false
            }
        }
        
        if string.count > 1, let item = self.item, let processPaste = item.processPaste {
            let result = processPaste(string)
            if result != string {
                var text = textField.text ?? ""
                text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: result)
                textField.text = text
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
        return true
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.item?.action()
        return false
    }
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        self.item?.updatedFocus?(true)
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        self.item?.updatedFocus?(false)
        self.updateClearButtonVisibility()
    }
    
    func animateError() {
        self.textNode.layer.addShakeAnimation()
    }
}
