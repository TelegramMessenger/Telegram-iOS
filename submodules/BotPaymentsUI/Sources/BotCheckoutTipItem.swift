import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting

class BotCheckoutTipItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let title: String
    let currency: String
    let value: String
    let numericValue: Int64
    let maxValue: Int64
    let availableVariants: [(String, Int64)]
    let updateValue: (Int64) -> Void
    let updatedFocus: (Bool) -> Void

    let sectionId: ItemListSectionId
    
    let requestsNoInset: Bool = true
    
    init(theme: PresentationTheme, strings: PresentationStrings, title: String, currency: String, value: String, numericValue: Int64, maxValue: Int64, availableVariants: [(String, Int64)], sectionId: ItemListSectionId, updateValue: @escaping (Int64) -> Void, updatedFocus: @escaping (Bool) -> Void) {
        self.theme = theme
        self.strings = strings
        self.title = title
        self.currency = currency
        self.value = value
        self.numericValue = numericValue
        self.maxValue = maxValue
        self.availableVariants = availableVariants
        self.updateValue = updateValue
        self.updatedFocus = updatedFocus
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BotCheckoutTipItemNode()
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
            if let nodeValue = node() as? BotCheckoutTipItemNode {
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
    
    let selectable: Bool = false
}

private let titleFont = Font.regular(17.0)
private let finalFont = Font.semibold(17.0)

private func priceItemInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
        case .otherSection:
            insets.top += 8.0
        case .none, .sameSection:
            break
    }
    switch neighbors.bottom {
        case .none, .otherSection:
            insets.bottom += 8.0
        case .sameSection:
            break
    }
    return insets
}

private final class TipValueNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let titleNode: ImmediateTextNode

    private let button: HighlightTrackingButtonNode

    private var currentBackgroundColor: UIColor?

    var action: (() -> Void)?

    override init() {
        self.backgroundNode = ASImageNode()
        self.titleNode = ImmediateTextNode()

        self.button = HighlightTrackingButtonNode()

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.button)
        self.button.addTarget(self, action:  #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }

    @objc private func buttonPressed() {
        self.action?()
    }

    func update(theme: PresentationTheme, text: String, isHighlighted: Bool, height: CGFloat) -> (CGFloat, (CGFloat) -> Void) {
        var updateBackground = false
        let backgroundColor = isHighlighted ? theme.list.paymentOption.activeFillColor : theme.list.paymentOption.inactiveFillColor
        if let currentBackgroundColor = self.currentBackgroundColor {
            if !currentBackgroundColor.isEqual(backgroundColor) {
                updateBackground = true
            }
        } else {
            updateBackground = true
        }
        if updateBackground {
            self.currentBackgroundColor = backgroundColor
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: backgroundColor)
        }

        self.titleNode.attributedText = NSAttributedString(string: text, font: Font.semibold(15.0), textColor: isHighlighted ? theme.list.paymentOption.activeForegroundColor : theme.list.paymentOption.inactiveForegroundColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: 200.0, height: height))

        let minWidth: CGFloat = 80.0

        let calculatedWidth = max(titleSize.width + 16.0 * 2.0, minWidth)

        return (calculatedWidth, { calculatedWidth in
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((calculatedWidth - titleSize.width) / 2.0), y: floor((height - titleSize.height) / 2.0)), size: titleSize)

            let size = CGSize(width: calculatedWidth, height: height)
            self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)

            self.button.frame = CGRect(origin: CGPoint(), size: size)
        })
    }
}

private final class FormatterImpl: NSObject, UITextFieldDelegate {
    private struct Representation {
        private let format: CurrencyFormat
        private var caretIndex: Int = 0
        private var wholePart: [Int] = []
        private var decimalPart: [Int] = []

        init(string: String, format: CurrencyFormat) {
            self.format = format

            var isDecimalPart = false
            for c in string {
                if c.isNumber {
                    if let value = Int(String(c)) {
                        if isDecimalPart {
                            self.decimalPart.append(value)
                        } else {
                            self.wholePart.append(value)
                        }
                    }
                } else if String(c) == format.decimalSeparator {
                    isDecimalPart = true
                }
            }

            while self.wholePart.count > 1 {
                if self.wholePart[0] != 0 {
                    break
                } else {
                    self.wholePart.removeFirst()
                }
            }
            if self.wholePart.isEmpty {
                self.wholePart = [0]
            }

            while self.decimalPart.count > 1 {
                if self.decimalPart[self.decimalPart.count - 1] != 0 {
                    break
                } else {
                    self.decimalPart.removeLast()
                }
            }
            while self.decimalPart.count < format.decimalDigits {
                self.decimalPart.append(0)
            }

            self.caretIndex = self.wholePart.count
        }

        var minCaretIndex: Int {
            for i in 0 ..< self.wholePart.count {
                if self.wholePart[i] != 0 {
                    return i
                }
            }
            return self.wholePart.count
        }

        mutating func moveCaret(offset: Int) {
            self.caretIndex = max(self.minCaretIndex, min(self.caretIndex + offset, self.wholePart.count + self.decimalPart.count))
        }

        mutating func normalize() {
            while self.wholePart.count > 1 {
                if self.wholePart[0] != 0 {
                    break
                } else {
                    self.wholePart.removeFirst()
                    self.moveCaret(offset: -1)
                }
            }
            if self.wholePart.isEmpty {
                self.wholePart = [0]
            }

            while self.decimalPart.count < format.decimalDigits {
                self.decimalPart.append(0)
            }
            while self.decimalPart.count > format.decimalDigits {
                self.decimalPart.removeLast()
            }

            self.caretIndex = max(self.minCaretIndex, min(self.caretIndex, self.wholePart.count + self.decimalPart.count))
        }

        mutating func backspace() {
            if self.caretIndex > self.wholePart.count {
                let decimalIndex = self.caretIndex - self.wholePart.count
                if decimalIndex > 0 {
                    self.decimalPart.remove(at: decimalIndex - 1)

                    self.moveCaret(offset: -1)
                    self.normalize()
                }
            } else {
                if self.caretIndex > 0 {
                    self.wholePart.remove(at: self.caretIndex - 1)

                    self.moveCaret(offset: -1)
                    self.normalize()
                }
            }
        }

        mutating func insert(letter: String) {
            if letter == "." || letter == "," {
                if self.caretIndex == self.wholePart.count {
                    return
                } else if self.caretIndex < self.wholePart.count {
                    for i in (self.caretIndex ..< self.wholePart.count).reversed() {
                        self.decimalPart.insert(self.wholePart[i], at: 0)
                        self.wholePart.remove(at: i)
                    }
                }

                self.normalize()
            } else if letter.count == 1 && letter[letter.startIndex].isNumber {
                if let value = Int(letter) {
                    if self.caretIndex <= self.wholePart.count {
                        self.wholePart.insert(value, at: self.caretIndex)
                    } else {
                        let decimalIndex = self.caretIndex - self.wholePart.count
                        self.decimalPart.insert(value, at: decimalIndex)
                    }
                    self.moveCaret(offset: 1)
                    self.normalize()
                }
            }
        }

        var string: String {
            var result = ""

            for digit in self.wholePart {
                result.append("\(digit)")
            }
            result.append(self.format.decimalSeparator)
            for digit in self.decimalPart {
                result.append("\(digit)")
            }

            return result
        }

        var stringCaretIndex: Int {
            var logicalIndex = 0
            var resolvedIndex = 0

            if logicalIndex == self.caretIndex {
                return resolvedIndex
            }

            for _ in self.wholePart {
                logicalIndex += 1
                resolvedIndex += 1

                if logicalIndex == self.caretIndex {
                    return resolvedIndex
                }
            }

            resolvedIndex += 1

            for _ in self.decimalPart {
                logicalIndex += 1
                resolvedIndex += 1

                if logicalIndex == self.caretIndex {
                    return resolvedIndex
                }
            }

            return resolvedIndex
        }

        var numericalValue: Int64 {
            var result: Int64 = 0

            for digit in self.wholePart {
                result *= 10
                result += Int64(digit)
            }
            for digit in self.decimalPart {
                result *= 10
                result += Int64(digit)
            }

            return result
        }
    }

    private let format: CurrencyFormat
    private let currency: String
    private let maxNumericalValue: Int64
    private let updated: (Int64) -> Void
    private let focusUpdated: (Bool) -> Void

    private var representation: Representation

    private var previousResolvedCaretIndex: Int = 0
    private var ignoreTextSelection: Bool = false
    private var enableTextSelectionProcessing: Bool = false

    init?(textField: UITextField, currency: String, maxNumericalValue: Int64, initialValue: String, updated: @escaping (Int64) -> Void, focusUpdated: @escaping (Bool) -> Void) {
        guard let format = CurrencyFormat(currency: currency) else {
            return nil
        }
        self.format = format
        self.currency = currency
        self.maxNumericalValue = maxNumericalValue
        self.updated = updated
        self.focusUpdated = focusUpdated

        self.representation = Representation(string: initialValue, format: format)

        super.init()

        textField.text = self.representation.string
        self.previousResolvedCaretIndex = self.representation.stringCaretIndex
    }

    func reset(textField: UITextField, initialValue: String) {
        self.representation = Representation(string: initialValue, format: self.format)
        self.resetFromRepresentation(textField: textField, notifyUpdated: false)
    }

    private func resetFromRepresentation(textField: UITextField, notifyUpdated: Bool) {
        self.ignoreTextSelection = true

        if self.representation.numericalValue > self.maxNumericalValue {
            self.representation = Representation(string: formatCurrencyAmountCustom(self.maxNumericalValue, currency: self.currency).0, format: self.format)
        }

        textField.text = self.representation.string
        self.previousResolvedCaretIndex = self.representation.stringCaretIndex

        if self.enableTextSelectionProcessing {
            let stringCaretIndex = self.representation.stringCaretIndex
            if let caretPosition = textField.position(from: textField.beginningOfDocument, offset: stringCaretIndex) {
                textField.selectedTextRange = textField.textRange(from: caretPosition, to: caretPosition)
            }
        }
        self.ignoreTextSelection = false

        if notifyUpdated {
            self.updated(self.representation.numericalValue)
        }
    }

    @objc public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.count == 1 {
            self.representation.insert(letter: string)
            self.resetFromRepresentation(textField: textField, notifyUpdated: true)
        } else if string.count == 0 {
            self.representation.backspace()
            self.resetFromRepresentation(textField: textField, notifyUpdated: true)
        }

        return false
    }

    @objc public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }

    @objc public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.enableTextSelectionProcessing = true
        self.focusUpdated(true)

        let stringCaretIndex = self.representation.stringCaretIndex
        self.previousResolvedCaretIndex = stringCaretIndex
        if let caretPosition = textField.position(from: textField.beginningOfDocument, offset: stringCaretIndex) {
            self.ignoreTextSelection = true
            textField.selectedTextRange = textField.textRange(from: caretPosition, to: caretPosition)
            DispatchQueue.main.async {
                textField.selectedTextRange = textField.textRange(from: caretPosition, to: caretPosition)
                self.ignoreTextSelection = false
            }
        }
    }

    @objc public func textFieldDidChangeSelection(_ textField: UITextField) {
        if self.ignoreTextSelection {
            return
        }
        if !self.enableTextSelectionProcessing {
            return
        }

        if let selectedTextRange = textField.selectedTextRange {
            let index = textField.offset(from: textField.beginningOfDocument, to: selectedTextRange.end)
            if self.previousResolvedCaretIndex != index {
                self.representation.moveCaret(offset: self.previousResolvedCaretIndex < index ? 1 : -1)

                let stringCaretIndex = self.representation.stringCaretIndex
                self.previousResolvedCaretIndex = stringCaretIndex
                if let caretPosition = textField.position(from: textField.beginningOfDocument, offset: stringCaretIndex) {
                        textField.selectedTextRange = textField.textRange(from: caretPosition, to: caretPosition)
                }
            }
        }
    }

    @objc public func textFieldDidEndEditing(_ textField: UITextField) {
        self.enableTextSelectionProcessing = false
        self.focusUpdated(false)
    }
}

class BotCheckoutTipItemNode: ListViewItemNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    let titleNode: TextNode
    let labelNode: TextNode
    let tipMeasurementNode: ImmediateTextNode
    let tipCurrencyNode: ImmediateTextNode
    private let textNode: TextFieldNode

    private let scrollNode: ASScrollNode
    private var valueNodes: [TipValueNode] = []
    
    private var item: BotCheckoutTipItem?
    private var formatter: FormatterImpl?
    
    init() {
        self.backgroundNode = ASDisplayNode()

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.isHidden = true

        self.tipMeasurementNode = ImmediateTextNode()
        self.tipCurrencyNode = ImmediateTextNode()

        self.textNode = TextFieldNode()

        self.scrollNode = ASScrollNode()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false)

        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.tipCurrencyNode)
        self.addSubnode(self.scrollNode)

        self.textNode.clipsToBounds = true
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func asyncLayout() -> (_ item: BotCheckoutTipItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, params, neighbors in
            //let rightInset: CGFloat = 16.0 + params.rightInset

            let labelsContentHeight: CGFloat = 34.0
            
            var contentSize = CGSize(width: params.width, height: labelsContentHeight)
            if !item.availableVariants.isEmpty {
                contentSize.height += 75.0
            }

            let insets = priceItemInsets(neighbors)
            
            let textFont: UIFont
            let textColor: UIColor

            textFont = titleFont
            textColor = item.theme.list.itemSecondaryTextColor
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Checkout_OptionalTipItemPlaceholder, font: textFont, textColor: textColor.withMultipliedAlpha(0.8)), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    
                    let leftInset: CGFloat = 16.0 + params.leftInset
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((labelsContentHeight - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - labelLayout.size.width, y: floor((labelsContentHeight - labelLayout.size.height) / 2.0)), size: labelLayout.size)

                    if strongSelf.formatter == nil {
                        strongSelf.formatter = FormatterImpl(textField: strongSelf.textNode.textField, currency: item.currency, maxNumericalValue: item.maxValue, initialValue: item.value, updated: { value in
                            guard let strongSelf = self, let item = strongSelf.item else {
                                return
                            }
                            if item.numericValue != value {
                                item.updateValue(value)
                            }
                        }, focusUpdated: { value in
                            guard let strongSelf = self else {
                                return
                            }
                            if value {
                                strongSelf.item?.updatedFocus(true)
                            }
                        })
                        strongSelf.textNode.textField.delegate = strongSelf.formatter

                        /*strongSelf.formatterDelegate = CurrencyUITextFieldDelegate(formatter: CurrencyFormatter(currency: item.currency, { formatter in
                            formatter.maxValue = currencyToFractionalAmount(value: item.maxValue, currency: item.currency) ?? 10000.0
                            formatter.minValue = 0.0
                            formatter.hasDecimals = true
                        }))
                        strongSelf.formatterDelegate?.passthroughDelegate = strongSelf

                        strongSelf.formatterDelegate?.textUpdated = {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.textFieldTextChanged(strongSelf.textNode.textField)
                        }

                        strongSelf.textNode.textField.delegate = strongSelf.formatterDelegate*/

                        strongSelf.textNode.clipsToBounds = true
                        //strongSelf.textNode.textField.delegate = strongSelf
                    }

                    strongSelf.textNode.textField.typingAttributes = [NSAttributedString.Key.font: titleFont]
                    strongSelf.textNode.textField.font = titleFont

                    strongSelf.textNode.textField.textColor = textColor
                    strongSelf.textNode.textField.textAlignment = .right
                    strongSelf.textNode.textField.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    strongSelf.textNode.textField.keyboardType = .decimalPad
                    strongSelf.textNode.textField.returnKeyType = .next
                    strongSelf.textNode.textField.tintColor = item.theme.list.itemAccentColor

                    var textInputFrame = CGRect(origin: CGPoint(x: params.width - leftInset - 150.0, y: -2.0), size: CGSize(width: 150.0, height: labelsContentHeight))

                    let currencyText: (String, String, Bool) = formatCurrencyAmountCustom(item.numericValue, currency: item.currency)

                    let currencySymbolOnTheLeft = currencyText.2
                    //let currencySymbolOnTheLeft = true

                    if strongSelf.textNode.textField.text ?? "" != currencyText.0 {
                        strongSelf.formatter?.reset(textField: strongSelf.textNode.textField, initialValue: currencyText.0)
                    }

                    strongSelf.tipMeasurementNode.attributedText = NSAttributedString(string: currencyText.0, font: titleFont, textColor: textColor)
                    let inputTextSize = strongSelf.tipMeasurementNode.updateLayout(textInputFrame.size)

                    let spaceRect = NSAttributedString(string: " ", font: titleFont, textColor: textColor).boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)

                    strongSelf.tipCurrencyNode.attributedText = NSAttributedString(string: "\(currencyText.1)", font: titleFont, textColor: textColor)
                    let currencySize = strongSelf.tipCurrencyNode.updateLayout(CGSize(width: 100.0, height: .greatestFiniteMagnitude))
                    if currencySymbolOnTheLeft {
                        strongSelf.tipCurrencyNode.frame = CGRect(origin: CGPoint(x: textInputFrame.maxX - currencySize.width - inputTextSize.width - spaceRect.width, y: floor((labelsContentHeight - currencySize.height) / 2.0) - 1.0), size: currencySize)
                    } else {
                        strongSelf.tipCurrencyNode.frame = CGRect(origin: CGPoint(x: textInputFrame.maxX - currencySize.width, y: floor((labelsContentHeight - currencySize.height) / 2.0) - 1.0), size: currencySize)
                        textInputFrame.origin.x -= currencySize.width + spaceRect.width
                    }

                    strongSelf.textNode.frame = textInputFrame

                    let valueHeight: CGFloat = 52.0
                    let valueY: CGFloat = labelsContentHeight + 9.0

                    var index = 0
                    var variantLayouts: [(CGFloat, (CGFloat) -> Void)] = []
                    var totalMinWidth: CGFloat = 0.0
                    for (variantText, variantValue) in item.availableVariants {
                        let valueNode: TipValueNode
                        if strongSelf.valueNodes.count > index {
                            valueNode = strongSelf.valueNodes[index]
                        } else {
                            valueNode = TipValueNode()
                            strongSelf.valueNodes.append(valueNode)
                            strongSelf.scrollNode.addSubnode(valueNode)
                        }
                        let (nodeMinWidth, nodeApply) = valueNode.update(theme: item.theme, text: variantText, isHighlighted: item.value == variantText, height: valueHeight)
                        valueNode.action = {
                            guard let strongSelf = self, let item = strongSelf.item else {
                                return
                            }
                            if item.numericValue == variantValue {
                                item.updateValue(0)
                            } else {
                                item.updateValue(variantValue)
                            }
                        }
                        totalMinWidth += nodeMinWidth
                        variantLayouts.append((nodeMinWidth, nodeApply))
                        index += 1
                    }

                    let sideInset: CGFloat = params.leftInset + 16.0
                    var scaleFactor: CGFloat = 1.0
                    let availableWidth = params.width - sideInset * 2.0 - CGFloat(max(0, item.availableVariants.count - 1)) * 12.0
                    if totalMinWidth < availableWidth {
                        scaleFactor = availableWidth / totalMinWidth
                    }

                    var variantsOffset: CGFloat = sideInset
                    for index in 0 ..< item.availableVariants.count {
                        if index != 0 {
                            variantsOffset += 12.0
                        }

                        let valueNode: TipValueNode = strongSelf.valueNodes[index]
                        let (minWidth, nodeApply) = variantLayouts[index]

                        let nodeWidth = floor(scaleFactor * minWidth)

                        var valueFrame = CGRect(origin: CGPoint(x: variantsOffset, y: 0.0), size: CGSize(width: nodeWidth, height: valueHeight))
                        if scaleFactor > 1.0 && index == item.availableVariants.count - 1 {
                            valueFrame.size.width = params.width - sideInset - valueFrame.minX
                        }

                        valueNode.frame = valueFrame
                        nodeApply(nodeWidth)
                        variantsOffset += nodeWidth
                    }

                    variantsOffset += 16.0

                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: valueY), size: CGSize(width: params.width, height: max(0.0, contentSize.height - valueY)))
                    strongSelf.scrollNode.view.contentSize = CGSize(width: variantsOffset, height: strongSelf.scrollNode.frame.height)

                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: contentSize.height))
                }
            })
        }
    }

    @objc private func dismissKeyboard() {
        self.textNode.textField.resignFirstResponder()
    }

    @objc private func textFieldTextChanged(_ textField: UITextField) {
        let text = textField.text ?? ""
        //self.labelNode.isHidden = !text.isEmpty

        guard let item = self.item else {
            return
        }

        if text.isEmpty {
            item.updateValue(0)
            return
        }

        /*var cleanText = ""
        for c in text {
            if c.isNumber {
                cleanText.append(c)
            } else if c == "," {
                cleanText.append(".")
            }
        }

        guard let doubleValue = Double(cleanText) else {
            return
        }

        if var value = fractionalToCurrencyAmount(value: doubleValue, currency: item.currency) {
            if value > item.maxValue {
                value = item.maxValue

                let currencyText = formatCurrencyAmountCustom(value, currency: item.currency)
                if self.textNode.textField.text ?? "" != currencyText.0 {
                    self.textNode.textField.text = currencyText.0
                }
            }
            item.updateValue(value)
        }*/
    }

    @objc public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }

    @objc public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }

    @objc public func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)

        self.item?.updatedFocus(true)
    }

    @objc public func textFieldDidChangeSelection(_ textField: UITextField) {
        textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
    }

    @objc public func textFieldDidEndEditing(_ textField: UITextField) {
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
