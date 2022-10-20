import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

private let validIdentifierSet: CharacterSet = {
    var set = CharacterSet(charactersIn: "a".unicodeScalars.first! ... "z".unicodeScalars.first!)
    set.insert(charactersIn: "A".unicodeScalars.first! ... "Z".unicodeScalars.first!)
    set.insert(charactersIn: "0".unicodeScalars.first! ... "9".unicodeScalars.first!)
    set.insert("_")
    return set
}()

public enum ItemListSingleLineInputItemType: Equatable {
    case regular(capitalization: Bool, autocorrection: Bool)
    case password
    case email
    case number
    case decimal
    case username
}

public enum ItemListSingleLineInputClearType: Equatable {
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

public enum ItemListSingleLineInputAlignment {
    case `default`
    case right
}

public class ItemListSingleLineInputItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: NSAttributedString
    let text: String
    let placeholder: String
    let type: ItemListSingleLineInputItemType
    let returnKeyType: UIReturnKeyType
    let alignment: ItemListSingleLineInputAlignment
    let spacing: CGFloat
    let clearType: ItemListSingleLineInputClearType
    let maxLength: Int
    let enabled: Bool
    let selectAllOnFocus: Bool
    let secondaryStyle: Bool
    public let sectionId: ItemListSectionId
    let action: () -> Void
    let textUpdated: (String) -> Void
    let shouldUpdateText: (String) -> Bool
    let processPaste: ((String) -> String)?
    let updatedFocus: ((Bool) -> Void)?
    let cleared: (() -> Void)?
    public let tag: ItemListItemTag?
    
    public init(presentationData: ItemListPresentationData, title: NSAttributedString, text: String, placeholder: String, type: ItemListSingleLineInputItemType = .regular(capitalization: true, autocorrection: true), returnKeyType: UIReturnKeyType = .`default`, alignment: ItemListSingleLineInputAlignment = .default, spacing: CGFloat = 0.0, clearType: ItemListSingleLineInputClearType = .none, maxLength: Int = 0, enabled: Bool = true, selectAllOnFocus: Bool = false, secondaryStyle: Bool = false, tag: ItemListItemTag? = nil, sectionId: ItemListSectionId, textUpdated: @escaping (String) -> Void, shouldUpdateText: @escaping (String) -> Bool = { _ in return true }, processPaste: ((String) -> String)? = nil, updatedFocus: ((Bool) -> Void)? = nil, action: @escaping () -> Void, cleared: (() -> Void)? = nil) {
        self.presentationData = presentationData
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.type = type
        self.returnKeyType = returnKeyType
        self.alignment = alignment
        self.spacing = spacing
        self.clearType = clearType
        self.maxLength = maxLength
        self.enabled = enabled
        self.selectAllOnFocus = selectAllOnFocus
        self.secondaryStyle = secondaryStyle
        self.tag = tag
        self.sectionId = sectionId
        self.textUpdated = textUpdated
        self.shouldUpdateText = shouldUpdateText
        self.processPaste = processPaste
        self.updatedFocus = updatedFocus
        self.action = action
        self.cleared = cleared
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
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

public class ItemListSingleLineInputItemNode: ListViewItemNode, UITextFieldDelegate, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let titleNode: TextNode
    private let measureTitleSizeNode: TextNode
    private let textNode: TextFieldNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    
    private var item: ItemListSingleLineInputItem?
    
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
        
        self.titleNode = TextNode()
        self.measureTitleSizeNode = TextNode()
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
    
    override public func didLoad() {
        super.didLoad()
        
        if let item = self.item {
            self.textNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize)]
            self.textNode.textField.font = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            self.textNode.textField.textColor = item.secondaryStyle ? item.presentationData.theme.list.itemSecondaryTextColor : item.presentationData.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = item.presentationData.theme.rootController.keyboardColor.keyboardAppearance
            self.textNode.textField.tintColor = item.presentationData.theme.list.itemAccentColor
            self.textNode.textField.accessibilityHint = item.placeholder
        } else {
            self.textNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(17.0)]
            self.textNode.textField.font = Font.regular(17.0)
        }
        
        self.textNode.clipsToBounds = true
        self.textNode.textField.delegate = self
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    public func asyncLayout() -> (_ item: ItemListSingleLineInputItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeMeasureTitleSizeLayout = TextNode.asyncLayout(self.measureTitleSizeNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            var updatedClearIcon: UIImage?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedClearIcon = PresentationResourcesItemList.itemListClearInputIcon(item.presentationData.theme)
            }
            
            var fontUpdated = false
            if currentItem?.presentationData.fontSize != item.presentationData.fontSize {
                fontUpdated = true
            }
            
            var styleUpdated = false
            if currentItem?.secondaryStyle != item.secondaryStyle {
                styleUpdated = true
            }
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            var rightInset: CGFloat = 16.0 + params.rightInset
            
            if item.clearType.hasButton {
                rightInset += 32.0
            }
            
            let titleString = NSMutableAttributedString(attributedString: item.title)
            titleString.removeAttribute(NSAttributedString.Key.font, range: NSMakeRange(0, titleString.length))
            titleString.addAttributes([NSAttributedString.Key.font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize)], range: NSMakeRange(0, titleString.length))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - 32.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (measureTitleLayout, measureTitleSizeApply) = makeMeasureTitleSizeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "A", font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize)), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - 32.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: params.width, height: max(titleLayout.size.height, measureTitleLayout.size.height) + 22.0)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        
                        strongSelf.textNode.textField.textColor = item.secondaryStyle ? item.presentationData.theme.list.itemSecondaryTextColor : item.presentationData.theme.list.itemPrimaryTextColor
                        strongSelf.textNode.textField.keyboardAppearance = item.presentationData.theme.rootController.keyboardColor.keyboardAppearance
                        strongSelf.textNode.textField.tintColor = item.presentationData.theme.list.itemAccentColor
                    }
                    
                    if fontUpdated {
                        strongSelf.textNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize)]
                    }
                    
                    if styleUpdated {
                        strongSelf.textNode.textField.textColor = item.secondaryStyle ? item.presentationData.theme.list.itemSecondaryTextColor : item.presentationData.theme.list.itemPrimaryTextColor
                    }
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((layout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    
                    let _ = measureTitleSizeApply()
                    
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
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + item.spacing, y: 0.0), size: CGSize(width: max(1.0, params.width - (leftInset + rightInset + titleLayout.size.width + item.spacing)), height: layout.contentSize.height - 2.0))
                    
                    switch item.alignment {
                        case .default:
                            strongSelf.textNode.textField.textAlignment = .natural
                        case .right:
                            strongSelf.textNode.textField.textAlignment = .right
                    }
                    
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
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
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
                    
                    strongSelf.clearButtonNode.accessibilityLabel = item.presentationData.strings.VoiceOver_Editing_ClearText
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc private func textFieldTextChanged(_ textField: UITextField) {
        self.textUpdated(self.textNode.textField.text ?? "")
    }
    
    @objc private func clearButtonPressed() {
        self.textNode.textField.text = ""
        self.textUpdated("")
        self.item?.cleared?()
    }
    
    private func textUpdated(_ text: String) {
        self.item?.textUpdated(text)
    }
    
    public func focus() {
        if !self.textNode.textField.isFirstResponder {
            self.textNode.textField.becomeFirstResponder()
        }
    }
    
    @objc public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let item = self.item {
            let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            if !item.shouldUpdateText(newText) {
                return false
            }
            if item.maxLength != 0 && newText.count > item.maxLength {
                self.textNode.layer.addShakeAnimation()
                let hapticFeedback = HapticFeedback()
                hapticFeedback.error()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                    let _ = hapticFeedback
                })
                return false
            }
        }
        
        if string.count > 1, let item = self.item, let processPaste = item.processPaste {
            let result = processPaste(string)
            if result != string {
                var text = textField.text ?? ""
                text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: result)
                textField.text = text
                if case .username = item.type {
                    text = text.folding(options: .diacriticInsensitive, locale: .current).replacingOccurrences(of: " ", with: "_")
                    textField.text = text
                }
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
        
        if let item = self.item, case .username = item.type {
            var cleanString = string.folding(options: .diacriticInsensitive, locale: .current).replacingOccurrences(of: " ", with: "_")
            
            let filtered = cleanString.unicodeScalars.filter { validIdentifierSet.contains($0) }
            let filteredString = String(String.UnicodeScalarView(filtered))
            
            if cleanString != filteredString {
                cleanString = filteredString
                
                self.textNode.layer.addShakeAnimation()
                let hapticFeedback = HapticFeedback()
                hapticFeedback.error()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                    let _ = hapticFeedback
                })
            }
            
            if cleanString != string {
                var text = textField.text ?? ""
                text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: cleanString)
                textField.text = text
                if let startPosition = textField.position(from: textField.beginningOfDocument, offset: range.lowerBound + cleanString.count) {
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
    
    @objc public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.item?.action()
        return false
    }
    
    @objc public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.item?.updatedFocus?(true)
        if self.item?.selectAllOnFocus == true {
            DispatchQueue.main.async {
                let startPosition = self.textNode.textField.beginningOfDocument
                let endPosition = self.textNode.textField.endOfDocument
                self.textNode.textField.selectedTextRange = self.textNode.textField.textRange(from: startPosition, to: endPosition)
            }
        }
        self.updateClearButtonVisibility()
    }
    
    @objc public func textFieldDidEndEditing(_ textField: UITextField) {
        self.item?.updatedFocus?(false)
        self.updateClearButtonVisibility()
    }
    
    public func animateError() {
        self.textNode.layer.addShakeAnimation()
    }
}
