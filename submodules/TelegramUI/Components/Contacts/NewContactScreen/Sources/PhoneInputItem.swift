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
import ListItemComponentAdaptor
import ComponentFlow

private func generateCountryButtonBackground(strokeColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 75.0, height: 52.0 + 6.0), rotatedContext: { size, context in
        let arrowSize: CGFloat = 7.0
        let lineWidth = 1.0 - UIScreenPixel
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: CGPoint(x: 16.0, y: size.height - arrowSize - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: 16.0 + 21.0, y: size.height - arrowSize - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: 16.0 + 21.0 + arrowSize, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: 16.0 + 21.0 + arrowSize + arrowSize, y: size.height - arrowSize - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - 16.0, y: size.height - arrowSize - lineWidth / 2.0))
        context.strokePath()
    })?.resizableImage(withCapInsets: UIEdgeInsets(top: 1.0, left: 55.0, bottom: 1.0, right: 17.0), resizingMode: .stretch)
}

private func generateCountryButtonHighlightedBackground(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 52.0, height: 52.0 + 6.0), rotatedContext: { size, context in
        let arrowSize: CGFloat = 7.0
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
        context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
        context.closePath()
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 51, topCapHeight: 2)
}

private func generatePhoneInputBackground(strokeColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 79.0, height: 52.0), rotatedContext: { size, context in
        let lineWidth = 1.0 - UIScreenPixel
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: size.height - 16.0))
        context.addLine(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: 16.0))
        context.strokePath()
    })?.stretchableImage(withLeftCapWidth: 78, topCapHeight: 2)
}

final class PhoneInputItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    public enum Accessory {
        case check
        case activity
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: (Int32?, String?, String)
    let accessory: Accessory?
    let selectCountryCode: () -> Void
    let updated: (String, String) -> Void
    
    public init(theme: PresentationTheme, strings: PresentationStrings, value: (Int32?, String?, String), accessory: Accessory?, selectCountryCode: @escaping () -> Void, updated: @escaping (String, String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.accessory = accessory
        self.selectCountryCode = selectCountryCode
        self.updated = updated
    }
    
    let sectionId: ItemListSectionId = 0
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PhoneInputItemNode()
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
            if let nodeValue = node() as? PhoneInputItemNode {
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
    
    func item() -> ListViewItem {
        return self
    }
    
    static func ==(lhs: PhoneInputItem, rhs: PhoneInputItem) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.value.0 != rhs.value.0 {
            return false
        }
        if lhs.value.1 != rhs.value.1 {
            return false
        }
        if lhs.value.2 != rhs.value.2 {
            return false
        }
        if lhs.accessory != rhs.accessory {
            return false
        }
        return true
    }
}

final class PhoneInputItemNode: ListViewItemNode, ItemListItemNode {
    private let countryButton: ASButtonNode
    private let arrowNode: ASImageNode
    private let phoneBackground: ASImageNode
    private let phoneInputNode: PhoneInputNode
    
    private var item: PhoneInputItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var preferredCountryIdForCode: [String: String] = [:]
    
    private let checkNode: ASImageNode
    private var activityIndicatorView: UIActivityIndicatorView?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.countryButton = ASButtonNode()
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isLayerBacked = true
        
        self.phoneBackground = ASImageNode()
        self.phoneBackground.displaysAsynchronously = false
        self.phoneBackground.displayWithoutProcessing = true
        self.phoneBackground.isLayerBacked = true
        
        self.phoneInputNode = PhoneInputNode(fontSize: 17.0)
        
        self.checkNode = ASImageNode()
        self.checkNode.displaysAsynchronously = false
        self.checkNode.isLayerBacked = true
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.phoneBackground)
        self.addSubnode(self.countryButton)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.phoneInputNode)
        self.addSubnode(self.checkNode)
        
        self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 4.0, right: 0.0)
        self.countryButton.contentHorizontalAlignment = .left
        
        self.countryButton.addTarget(self, action: #selector(self.countryPressed), forControlEvents: .touchUpInside)
        
        self.phoneInputNode.numberTextUpdated = { [weak self] number in
            if let self {
                let _ = self.processNumberChange(self.phoneInputNode.number)
            }
        }
        
        self.phoneInputNode.countryCodeUpdated = { [weak self] code, name in
            guard let self, let item = self.item else {
                return
            }
            if let name = name {
                self.preferredCountryIdForCode[code] = name
            }
            
            if self.processNumberChange(self.phoneInputNode.number) {
            } else if let code = Int(code), let name = name, let countryName = countryCodeAndIdToName[CountryCodeAndId(code: code, id: name)] {
                let flagString = emojiFlagForISOCountryCode(name)
                var localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(name, strings: item.strings) ?? countryName
                if name == "FT" {
                    localizedName = item.strings.Login_AnonymousNumbers
                }
                self.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
            } else if let code = Int(code), let (countryId, countryName) = countryCodeToIdAndName[code] {
                let flagString = emojiFlagForISOCountryCode(countryId)
                var localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(countryId, strings: item.strings) ?? countryName
                if countryId == "FT" {
                    localizedName = item.strings.Login_AnonymousNumbers
                }
                self.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
            } else {
                self.countryButton.setTitle(item.strings.Login_SelectCountry, with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
            }
        }
        
        self.phoneInputNode.customFormatter = { number in
            if let (_, code) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: [:]) {
                return code.code
            } else {
                return nil
            }
        }
        
        let countryId = (Locale.current as NSLocale).object(forKey: .countryCode) as? String
   
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
    
    func processNumberChange(_ number: String) -> Bool {
        guard let item = self.item else {
            return false
        }
        if let (country, _) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: self.preferredCountryIdForCode) {
            let flagString = emojiFlagForISOCountryCode(country.id)
            let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(country.id, strings: item.strings) ?? country.name
            self.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(17.0), with: item.theme.list.itemPrimaryTextColor, for: [])
            
            let maskFont = Font.with(size: 17.0, design: .regular, traits: [.monospacedNumbers])
            var rawMask = ""
            if let mask = AuthorizationSequenceCountrySelectionController.lookupPatternByNumber(number, preferredCountries: self.preferredCountryIdForCode) {
                self.phoneInputNode.numberField.textField.attributedPlaceholder = nil
                self.phoneInputNode.mask = NSAttributedString(string: mask, font: maskFont, textColor: item.theme.list.itemPlaceholderTextColor)
                
                let rawCountryCode = self.codeNumberAndFullNumber.0.replacingOccurrences(of: "+", with: "")
                rawMask = mask.replacingOccurrences(of: " ", with: "")
                for _ in 0 ..< rawCountryCode.count {
                    rawMask.insert("X", at: rawMask.startIndex)
                }
            } else {
                self.phoneInputNode.mask = nil
                self.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: item.strings.Login_PhonePlaceholder, font: Font.regular(17.0), textColor: item.theme.list.itemPlaceholderTextColor)
            }
            item.updated(number, rawMask)
            
            return true
        } else {
            return false
        }
    }
    
    @objc private func countryPressed() {
        if let item = self.item {
            item.selectCountryCode()
        }
    }
    
    var phoneNumber: String {
        return self.phoneInputNode.number
    }
    
    var codeNumberAndFullNumber: (String, String, String) {
        return self.phoneInputNode.codeNumberAndFullNumber
    }
    
    func updateCountryCode() {
        self.phoneInputNode.codeAndNumber = self.phoneInputNode.codeAndNumber
    }
    
    func updateCountryCode(code: Int32, name: String) {
        self.phoneInputNode.codeAndNumber = (code, name, self.phoneInputNode.codeAndNumber.2)
        let _ = self.processNumberChange(self.phoneInputNode.number)
    }
    
    func activateInput() {
        self.phoneInputNode.numberField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.phoneInputNode.countryCodeField.layer.addShakeAnimation()
        self.phoneInputNode.numberField.layer.addShakeAnimation()
    }
    
    func asyncLayout() -> (_ item: PhoneInputItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedCountryButtonBackground: UIImage?
            var updatedCountryButtonHighlightedBackground: UIImage?
            var updatedPhoneBackground: UIImage?
            var updatedArrowImage: UIImage?
            var updatedCheckImage: UIImage?
            
            if currentItem?.theme !== item.theme {
                updatedCountryButtonBackground = generateCountryButtonBackground(strokeColor: item.theme.list.itemBlocksSeparatorColor.withMultipliedAlpha(0.5))
                updatedCountryButtonHighlightedBackground = generateCountryButtonHighlightedBackground(color: item.theme.list.itemHighlightedBackgroundColor)
                updatedPhoneBackground = generatePhoneInputBackground(strokeColor: item.theme.list.itemBlocksSeparatorColor.withMultipliedAlpha(0.5))
                updatedArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                updatedCheckImage = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Check"), color: item.theme.list.itemAccentColor)
            }
            
            let contentSize: CGSize
            var insets: UIEdgeInsets
            
            let countryButtonHeight: CGFloat = 52.0
            let inputFieldHeight: CGFloat = 52.0
            
            contentSize = CGSize(width: params.width, height: countryButtonHeight + inputFieldHeight)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
                        
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    if let updatedCountryButtonBackground = updatedCountryButtonBackground {
                        strongSelf.countryButton.setBackgroundImage(updatedCountryButtonBackground, for: [])
                    }
                    if let updatedCountryButtonHighlightedBackground = updatedCountryButtonHighlightedBackground {
                        strongSelf.countryButton.setBackgroundImage(updatedCountryButtonHighlightedBackground, for: .highlighted)
                    }
                    if let updatedPhoneBackground = updatedPhoneBackground {
                        strongSelf.phoneBackground.image = updatedPhoneBackground
                    }
                    if let updatedArrowImage {
                        strongSelf.arrowNode.image = updatedArrowImage
                    }
                    if let updatedCheckImage {
                        strongSelf.checkNode.image = updatedCheckImage
                    }
                    
                    strongSelf.phoneInputNode.countryCodeField.textField.textColor = item.theme.list.itemPrimaryTextColor
                    strongSelf.phoneInputNode.countryCodeField.textField.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    strongSelf.phoneInputNode.countryCodeField.textField.tintColor = item.theme.list.itemAccentColor
                    strongSelf.phoneInputNode.numberField.textField.textColor = item.theme.list.itemPrimaryTextColor
                    strongSelf.phoneInputNode.numberField.textField.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    strongSelf.phoneInputNode.numberField.textField.tintColor = item.theme.list.itemAccentColor
                    
                    strongSelf.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 15.0, bottom: 4.0, right: 0.0)
                    
                    strongSelf.countryButton.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: 52.0 + 6.0))
                    
                    if let arrowImage = strongSelf.arrowNode.image {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - arrowImage.size.width - 8.0, y: floorToScreenPixels((countryButtonHeight - arrowImage.size.height) / 2.0)), size: arrowImage.size)
                    }
                    
                    strongSelf.phoneBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: 52.0), size: CGSize(width: params.width, height: 52.0))
                    
                    let countryCodeFrame = CGRect(origin: CGPoint(x: 7.0, y: 52.0), size: CGSize(width: 67.0, height: 52.0))
                    let numberFrame = CGRect(origin: CGPoint(x: 88.0, y: 52.0), size: CGSize(width: layout.size.width - 70.0 - 8.0, height: 52.0))
                    let placeholderFrame = numberFrame.offsetBy(dx: 0.0, dy: 8.0)
                    
                    let phoneInputFrame = countryCodeFrame.union(numberFrame)
                    
                    strongSelf.phoneInputNode.frame = phoneInputFrame
                    strongSelf.phoneInputNode.countryCodeField.frame = countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
                    strongSelf.phoneInputNode.numberField.frame = numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
                    strongSelf.phoneInputNode.placeholderNode.frame = placeholderFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY + 8.0 + UIScreenPixel)
                    
                    if case .check = item.accessory {
                        strongSelf.checkNode.isHidden = false
                    } else {
                        strongSelf.checkNode.isHidden = true
                    }
                    if let checkImage = strongSelf.checkNode.image {
                        strongSelf.checkNode.frame = CGRect(origin: CGPoint(x: params.width - checkImage.size.width - 10.0, y: countryButtonHeight + floorToScreenPixels((inputFieldHeight - checkImage.size.height) / 2.0)), size: checkImage.size)
                    }
                    
                    if case .activity = item.accessory {
                        let activityIndicatorView: UIActivityIndicatorView
                        let activityIndicatorTransition = ComponentTransition.immediate
                        if let current = strongSelf.activityIndicatorView {
                            activityIndicatorView = current
                        } else {
                            if #available(iOS 13.0, *) {
                                activityIndicatorView = UIActivityIndicatorView(style: .medium)
                            } else {
                                activityIndicatorView = UIActivityIndicatorView(style: .gray)
                            }
                            strongSelf.activityIndicatorView = activityIndicatorView
                            strongSelf.view.addSubview(activityIndicatorView)
                            activityIndicatorView.sizeToFit()
                        }
                        
                        let activityIndicatorSize = activityIndicatorView.bounds.size
                        let activityIndicatorFrame = CGRect(origin: CGPoint(x: params.width - 16.0 - activityIndicatorSize.width, y: countryButtonHeight + floor((inputFieldHeight - activityIndicatorSize.height) * 0.5)), size: activityIndicatorSize)
                        
                        activityIndicatorView.tintColor = item.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.5)
                        
                        activityIndicatorTransition.setFrame(view: activityIndicatorView, frame: activityIndicatorFrame)
                        
                        if !activityIndicatorView.isAnimating {
                            activityIndicatorView.startAnimating()
                        }
                    } else {
                        if let activityIndicatorView = strongSelf.activityIndicatorView {
                            strongSelf.activityIndicatorView = nil
                            activityIndicatorView.removeFromSuperview()
                        }
                    }
                }
            })
        }
    }
}
