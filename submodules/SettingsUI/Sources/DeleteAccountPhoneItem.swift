import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import PhoneInputNode
import CountrySelectionUI
import CoreTelephony

private func generateCountryButtonBackground(color: UIColor, strokeColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 56, height: 44.0 + 6.0), rotatedContext: { size, context in
        let arrowSize: CGFloat = 6.0
        let lineWidth = UIScreenPixel
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
        context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
        context.closePath()
        context.fillPath()
        
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(lineWidth)
        
        context.move(to: CGPoint(x: size.width, y: size.height - arrowSize - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: 15.0, y: size.height - arrowSize - lineWidth / 2.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 0.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width, y: lineWidth / 2.0))
        context.strokePath()
    })?.stretchableImage(withLeftCapWidth: 55, topCapHeight: 1)
}

private func generateCountryButtonHighlightedBackground(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 56.0, height: 44.0 + 6.0), rotatedContext: { size, context in
        let arrowSize: CGFloat = 6.0
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
        context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
        context.closePath()
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 55, topCapHeight: 2)
}

private func generatePhoneInputBackground(color: UIColor, strokeColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 82.0, height: 44.0), rotatedContext: { size, context in
        let lineWidth = UIScreenPixel
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: CGPoint(x: 0.0, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth / 2.0))
        context.strokePath()
        context.move(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: 0.0))
        context.strokePath()
    })?.stretchableImage(withLeftCapWidth: 81, topCapHeight: 2)
}


class DeleteAccountPhoneItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: (Int32?, String?, String)
    let sectionId: ItemListSectionId
    let selectCountryCode: () -> Void
    let updated: (Int) -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, value: (Int32?, String?, String), sectionId: ItemListSectionId, selectCountryCode: @escaping () -> Void, updated: @escaping (Int) -> Void) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.sectionId = sectionId
        self.selectCountryCode = selectCountryCode
        self.updated = updated
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = DeleteAccountPhoneItemNode()
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
            if let nodeValue = node() as? DeleteAccountPhoneItemNode {
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

class DeleteAccountPhoneItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let countryButton: ASButtonNode
    private let phoneBackground: ASImageNode
    private let phoneInputNode: PhoneInputNode
    
    private var item: DeleteAccountPhoneItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var preferredCountryIdForCode: [String: String] = [:]
    
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
        self.maskNode.isUserInteractionEnabled = false
        
        self.countryButton = ASButtonNode()
        
        self.phoneBackground = ASImageNode()
        self.phoneBackground.displaysAsynchronously = false
        self.phoneBackground.displayWithoutProcessing = true
        self.phoneBackground.isLayerBacked = true
        
        self.phoneInputNode = PhoneInputNode(fontSize: 17.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.phoneBackground)
        self.addSubnode(self.countryButton)
        self.addSubnode(self.phoneInputNode)
        
        self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 4.0, right: 0.0)
        self.countryButton.contentHorizontalAlignment = .left
        
        self.countryButton.addTarget(self, action: #selector(self.countryPressed), forControlEvents: .touchUpInside)
        
        let processNumberChange: (String) -> Bool = { [weak self] number in
            guard let strongSelf = self, let item = strongSelf.item else {
                return false
            }
            if let (country, _) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: strongSelf.preferredCountryIdForCode) {
                let flagString = emojiFlagForISOCountryCode(country.id)
                let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(country.id, strings: item.strings) ?? country.name
                strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
                
                let maskFont = Font.with(size: 20.0, design: .regular, traits: [.monospacedNumbers])
                if let mask = AuthorizationSequenceCountrySelectionController.lookupPatternByNumber(number, preferredCountries: strongSelf.preferredCountryIdForCode).flatMap({ NSAttributedString(string: $0, font: maskFont, textColor: item.theme.list.itemPlaceholderTextColor) }) {
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = nil
                    strongSelf.phoneInputNode.mask = mask
                } else {
                    strongSelf.phoneInputNode.mask = nil
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: item.strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: item.theme.list.itemPlaceholderTextColor)
                }
                return true
            } else {
                return false
            }
        }
        
        self.phoneInputNode.numberTextUpdated = { [weak self] number in
            if let strongSelf = self {
                let _ = processNumberChange(strongSelf.phoneInputNode.number)
            }
        }
        
        self.phoneInputNode.countryCodeUpdated = { [weak self] code, name in
            if let strongSelf = self, let item = strongSelf.item {
                if let name = name {
                    strongSelf.preferredCountryIdForCode[code] = name
                }
                
                if processNumberChange(strongSelf.phoneInputNode.number) {
                } else if let code = Int(code), let name = name, let countryName = countryCodeAndIdToName[CountryCodeAndId(code: code, id: name)] {
                    let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(name, strings: item.strings) ?? countryName
                    strongSelf.countryButton.setTitle(localizedName, with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
                } else if let code = Int(code), let (_, countryName) = countryCodeToIdAndName[code] {
                    strongSelf.countryButton.setTitle(countryName, with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
                } else {
                    strongSelf.countryButton.setTitle(item.strings.Login_CountryCode, with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
                }
            }
        }
        
        self.phoneInputNode.customFormatter = { number in
            if let (_, code) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: [:]) {
                return code.code
            } else {
                return nil
            }
        }
        
        var countryId: String? = nil
        let networkInfo = CTTelephonyNetworkInfo()
        if let carrier = networkInfo.subscriberCellularProvider {
            countryId = carrier.isoCountryCode
        }
        
        if countryId == nil {
            countryId = (Locale.current as NSLocale).object(forKey: .countryCode) as? String
        }
        
        var countryCodeAndId: (Int32, String) = (1, "US")
        
        if let countryId = countryId {
            let normalizedId = countryId.uppercased()
            for (code, idAndName) in countryCodeToIdAndName {
                if idAndName.0 == normalizedId {
                    countryCodeAndId = (Int32(code), idAndName.0.uppercased())
                    break
                }
            }
        }
        
        self.phoneInputNode.number = "+\(countryCodeAndId.0)"
    }
    
    @objc private func countryPressed() {
        if let item = self.item {
            item.selectCountryCode()
        }
    }
    
    var phoneNumber: String {
        return self.phoneInputNode.number
    }
    
    func updateCountryCode() {
        self.phoneInputNode.codeAndNumber = self.phoneInputNode.codeAndNumber
    }
    
    func updateCountryCode(code: Int32, name: String) {
        self.phoneInputNode.codeAndNumber = (code, name, self.phoneInputNode.codeAndNumber.2)
    }
    
    func activateInput() {
        self.phoneInputNode.numberField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.phoneInputNode.countryCodeField.layer.addShakeAnimation()
        self.phoneInputNode.numberField.layer.addShakeAnimation()
    }
    
    func asyncLayout() -> (_ item: DeleteAccountPhoneItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedCountryButtonBackground: UIImage?
            var updatedCountryButtonHighlightedBackground: UIImage?
            var updatedPhoneBackground: UIImage?
            
            if currentItem?.theme !== item.theme {
                updatedCountryButtonBackground = generateCountryButtonBackground(color: item.theme.list.itemBlocksBackgroundColor, strokeColor: item.theme.list.itemBlocksSeparatorColor)
                updatedCountryButtonHighlightedBackground = generateCountryButtonHighlightedBackground(color: item.theme.list.itemHighlightedBackgroundColor)
                updatedPhoneBackground = generatePhoneInputBackground(color: item.theme.list.itemBlocksBackgroundColor, strokeColor: item.theme.list.itemBlocksSeparatorColor)
            }
            
            let contentSize: CGSize
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let countryButtonHeight: CGFloat = 44.0
            let inputFieldsHeight: CGFloat = 44.0
            
            contentSize = CGSize(width: params.width, height: countryButtonHeight + inputFieldsHeight)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
                        
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                                        
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
                        strongSelf.addSubnode(strongSelf.maskNode)
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
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    if let updatedCountryButtonBackground = updatedCountryButtonBackground {
                        strongSelf.countryButton.setBackgroundImage(updatedCountryButtonBackground, for: [])
                    }
                    if let updatedCountryButtonHighlightedBackground = updatedCountryButtonHighlightedBackground {
                        strongSelf.countryButton.setBackgroundImage(updatedCountryButtonHighlightedBackground, for: .highlighted)
                    }
                    if let updatedPhoneBackground = updatedPhoneBackground {
                        strongSelf.phoneBackground.image = updatedPhoneBackground
                    }
                    
                    strongSelf.phoneInputNode.countryCodeField.textField.textColor = item.theme.list.itemPrimaryTextColor
                    strongSelf.phoneInputNode.countryCodeField.textField.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    strongSelf.phoneInputNode.countryCodeField.textField.tintColor = item.theme.list.itemAccentColor
                    strongSelf.phoneInputNode.numberField.textField.textColor = item.theme.list.itemPrimaryTextColor
                    strongSelf.phoneInputNode.numberField.textField.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    strongSelf.phoneInputNode.numberField.textField.tintColor = item.theme.list.itemAccentColor
                    
                    strongSelf.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 15.0, bottom: 4.0, right: 0.0)
                    
                    strongSelf.countryButton.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: 44.0 + 6.0))
                    strongSelf.phoneBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: 44.0), size: CGSize(width: params.width, height: 44.0))
                    
                    let countryCodeFrame = CGRect(origin: CGPoint(x: 11.0, y: 44.0), size: CGSize(width: 67.0, height: 44.0))
                    let numberFrame = CGRect(origin: CGPoint(x: 92.0, y: 44.0), size: CGSize(width: layout.size.width - 70.0 - 8.0, height: 44.0))
                    let placeholderFrame = numberFrame.offsetBy(dx: 0.0, dy: 8.0)
                    
                    let phoneInputFrame = countryCodeFrame.union(numberFrame)
                    
                    strongSelf.phoneInputNode.frame = phoneInputFrame
                    strongSelf.phoneInputNode.countryCodeField.frame = countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
                    strongSelf.phoneInputNode.numberField.frame = numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
                    strongSelf.phoneInputNode.placeholderNode.frame = placeholderFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
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
}
