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

class BotCheckoutTipItemNode: ListViewItemNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    let titleNode: TextNode
    let labelNode: TextNode
    let tipMeasurementNode: ImmediateTextNode
    let tipCurrencyNode: ImmediateTextNode
    private let textNode: TextFieldNode

    private let scrollNode: ASScrollNode
    private var valueNodes: [TipValueNode] = []
    
    private var item: BotCheckoutTipItem?

    private var formatterDelegate: CurrencyUITextFieldDelegate?
    
    init() {
        self.backgroundNode = ASDisplayNode()

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

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

                    if strongSelf.formatterDelegate == nil {
                        strongSelf.formatterDelegate = CurrencyUITextFieldDelegate(formatter: CurrencyFormatter(currency: item.currency, { formatter in
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

                        strongSelf.textNode.clipsToBounds = true
                        strongSelf.textNode.textField.delegate = strongSelf.formatterDelegate

                        /*let toolbar: UIToolbar = UIToolbar()
                        toolbar.tintColor = item.theme.rootController.navigationBar.accentTextColor
                        toolbar.barTintColor = item.theme.rootController.navigationBar.backgroundColor
                        toolbar.barStyle = .default
                        toolbar.items = [
                            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
                            UIBarButtonItem(title: item.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.dismissKeyboard))
                        ]
                        toolbar.sizeToFit()

                        strongSelf.textNode.textField.inputAccessoryView = toolbar*/
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
                        strongSelf.textNode.textField.text = currencyText.0
                        strongSelf.labelNode.isHidden = !currencyText.0.isEmpty
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
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.item?.updateValue(variantValue)
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
        self.labelNode.isHidden = !text.isEmpty

        guard let item = self.item else {
            return
        }

        if text.isEmpty {
            item.updateValue(0)
            return
        }

        var cleanText = ""
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
        }
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
