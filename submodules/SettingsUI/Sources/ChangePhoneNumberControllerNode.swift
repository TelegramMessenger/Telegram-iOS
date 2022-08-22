import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import CoreTelephony
import TelegramPresentationData
import PhoneInputNode
import CountrySelectionUI

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

final class ChangePhoneNumberControllerNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let countryButton: ASButtonNode
    private let phoneBackground: ASImageNode
    private let phoneInputNode: PhoneInputNode
    
    var currentNumber: String {
        return self.phoneInputNode.number
    }
    
    var codeAndNumber: (Int32?, String?, String) {
        get {
            return self.phoneInputNode.codeAndNumber
        } set(value) {
            self.phoneInputNode.codeAndNumber = value
        }
    }
    
    var preferredCountryIdForCode: [String: String] = [:]
    
    var selectCountryCode: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.phoneInputNode.enableEditing = !self.inProgress
            self.phoneInputNode.alpha = self.inProgress ? 0.6 : 1.0
            self.countryButton.isEnabled = !self.inProgress
        }
    }
    
    var presentationData: PresentationData
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChangePhoneNumberNumber_NewNumber, font: Font.regular(14.0), textColor: self.presentationData.theme.list.sectionHeaderTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChangePhoneNumberNumber_Help, font: Font.regular(14.0), textColor: self.presentationData.theme.list.freeTextColor)
        
        self.countryButton = ASButtonNode()
        self.countryButton.setBackgroundImage(generateCountryButtonBackground(color: self.presentationData.theme.list.itemBlocksBackgroundColor, strokeColor: self.presentationData.theme.list.itemBlocksSeparatorColor), for: [])
        self.countryButton.setBackgroundImage(generateCountryButtonHighlightedBackground(color: self.presentationData.theme.list.itemHighlightedBackgroundColor), for: .highlighted)
        
        self.phoneBackground = ASImageNode()
        self.phoneBackground.image = generatePhoneInputBackground(color: self.presentationData.theme.list.itemBlocksBackgroundColor, strokeColor: self.presentationData.theme.list.itemBlocksSeparatorColor)
        self.phoneBackground.displaysAsynchronously = false
        self.phoneBackground.displayWithoutProcessing = true
        self.phoneBackground.isLayerBacked = true
        
        self.phoneInputNode = PhoneInputNode(fontSize: 17.0)
        self.phoneInputNode.countryCodeField.textField.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        self.phoneInputNode.countryCodeField.textField.keyboardAppearance = self.presentationData.theme.rootController.keyboardColor.keyboardAppearance
        self.phoneInputNode.countryCodeField.textField.tintColor = self.presentationData.theme.list.itemAccentColor
        self.phoneInputNode.numberField.textField.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        self.phoneInputNode.numberField.textField.keyboardAppearance = self.presentationData.theme.rootController.keyboardColor.keyboardAppearance
        self.phoneInputNode.numberField.textField.tintColor = self.presentationData.theme.list.itemAccentColor
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.phoneBackground)
        self.addSubnode(self.countryButton)
        self.addSubnode(self.phoneInputNode)
        
        self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 4.0, right: 0.0)
        self.countryButton.contentHorizontalAlignment = .left
        
        self.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: self.presentationData.strings.Login_PhonePlaceholder, font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPlaceholderTextColor)
        
        self.countryButton.addTarget(self, action: #selector(self.countryPressed), forControlEvents: .touchUpInside)
        
        let processNumberChange: (String) -> Bool = { [weak self] number in
            guard let strongSelf = self else {
                return false
            }
            if let (country, _) = AuthorizationSequenceCountrySelectionController.lookupCountryIdByNumber(number, preferredCountries: strongSelf.preferredCountryIdForCode) {
                let flagString = emojiFlagForISOCountryCode(country.id)
                let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(country.id, strings: strongSelf.presentationData.strings) ?? country.name
                strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(17.0), with: strongSelf.presentationData.theme.list.itemPrimaryTextColor, for: [])
                
                let maskFont = Font.with(size: 20.0, design: .regular, traits: [.monospacedNumbers])
                if let mask = AuthorizationSequenceCountrySelectionController.lookupPatternByNumber(number, preferredCountries: strongSelf.preferredCountryIdForCode).flatMap({ NSAttributedString(string: $0, font: maskFont, textColor: strongSelf.presentationData.theme.list.itemPlaceholderTextColor) }) {
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = nil
                    strongSelf.phoneInputNode.mask = mask
                } else {
                    strongSelf.phoneInputNode.mask = nil
                    strongSelf.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strongSelf.presentationData.strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: strongSelf.presentationData.theme.list.itemPlaceholderTextColor)
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
            if let strongSelf = self {
                if let name = name {
                    strongSelf.preferredCountryIdForCode[code] = name
                }
                
                if processNumberChange(strongSelf.phoneInputNode.number) {
                } else if let code = Int(code), let name = name, let countryName = countryCodeAndIdToName[CountryCodeAndId(code: code, id: name)] {
                    let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(name, strings: strongSelf.presentationData.strings) ?? countryName
                    strongSelf.countryButton.setTitle(localizedName, with: Font.regular(17.0), with: strongSelf.presentationData.theme.list.itemPrimaryTextColor, for: [])
                } else if let code = Int(code), let (_, countryName) = countryCodeToIdAndName[code] {
                    strongSelf.countryButton.setTitle(countryName, with: Font.regular(17.0), with: strongSelf.presentationData.theme.list.itemPrimaryTextColor, for: [])
                } else {
                    strongSelf.countryButton.setTitle(strongSelf.presentationData.strings.Login_CountryCode, with: Font.regular(17.0), with: strongSelf.presentationData.theme.list.itemPrimaryTextColor, for: [])
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
    
    func updateCountryCode() {
        self.phoneInputNode.codeAndNumber = self.codeAndNumber
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar, .input])
        insets.left = layout.safeInsets.left
        insets.right = layout.safeInsets.right
        
        let countryButtonHeight: CGFloat = 44.0
        let inputFieldsHeight: CGFloat = 44.0
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - 28.0 - insets.left - insets .right, height: CGFloat.greatestFiniteMagnitude))
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 28.0 - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
        let navigationHeight: CGFloat = 97.0 + insets.top + navigationBarHeight
        
        let inputHeight = countryButtonHeight + inputFieldsHeight
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: 15.0 + insets.left, y: navigationHeight - titleSize.height - 8.0), size: titleSize))
        
        transition.updateFrame(node: self.countryButton, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: 44.0 + 6.0)))
        transition.updateFrame(node: self.phoneBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight + 44.0), size: CGSize(width: layout.size.width, height: 44.0)))
        
        let countryCodeFrame = CGRect(origin: CGPoint(x: 11.0, y: navigationHeight + 44.0 + 1.0), size: CGSize(width: 67.0, height: 44.0))
        let numberFrame = CGRect(origin: CGPoint(x: 92.0, y: navigationHeight + 44.0 + 1.0), size: CGSize(width: layout.size.width - 70.0 - 8.0, height: 44.0))
        let placeholderFrame = numberFrame.offsetBy(dx: 0.0, dy: 8.0)
        
        let phoneInputFrame = countryCodeFrame.union(numberFrame)
        
        transition.updateFrame(node: self.phoneInputNode, frame: phoneInputFrame)
        transition.updateFrame(node: self.phoneInputNode.countryCodeField, frame: countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
        transition.updateFrame(node: self.phoneInputNode.numberField, frame: numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
        transition.updateFrame(node: self.phoneInputNode.placeholderNode, frame: placeholderFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
        
        transition.updateFrame(node: self.noticeNode, frame: CGRect(origin: CGPoint(x: 15.0 + insets.left, y: navigationHeight + inputHeight + 8.0), size: noticeSize))
    }
    
    func activateInput() {
        self.phoneInputNode.numberField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.phoneInputNode.countryCodeField.layer.addShakeAnimation()
        self.phoneInputNode.numberField.layer.addShakeAnimation()
    }
    
    @objc func countryPressed() {
        self.selectCountryCode?()
    }
}
