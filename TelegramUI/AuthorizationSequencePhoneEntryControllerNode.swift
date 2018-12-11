import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

private func emojiFlagForISOCountryCode(_ countryCode: NSString) -> String {
    if countryCode.length != 2 {
        return ""
    }
    
    let base: UInt32 = 127462 - 65
    let first: UInt32 = base + UInt32(countryCode.character(at: 0))
    let second: UInt32 = base + UInt32(countryCode.character(at: 1))
    
    var data = Data()
    data.count = 8
    data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt32>) -> Void in
        bytes[0] = first
        bytes[1] = second
    }
    return String(data: data, encoding: String.Encoding.utf32LittleEndian) ?? ""
}

private final class PhoneAndCountryNode: ASDisplayNode {
    let strings: PresentationStrings
    let countryButton: ASButtonNode
    let phoneBackground: ASImageNode
    let phoneInputNode: PhoneInputNode
    
    var selectCountryCode: (() -> Void)?
    var checkPhone: (() -> Void)?
    
    init(strings: PresentationStrings, theme: AuthorizationTheme) {
        self.strings = strings
        
        let countryButtonBackground = generateImage(CGSize(width: 61.0, height: 67.0), rotatedContext: { size, context in
            let arrowSize: CGFloat = 10.0
            let lineWidth = UIScreenPixel
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.separatorColor.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: 15.0, y: lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width, y: lineWidth / 2.0))
            context.strokePath()
            
            context.move(to: CGPoint(x: size.width, y: size.height - arrowSize - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: 15.0, y: size.height - arrowSize - lineWidth / 2.0))
            context.strokePath()
        })?.stretchableImage(withLeftCapWidth: 61, topCapHeight: 1)
        
        let countryButtonHighlightedBackground = generateImage(CGSize(width: 60.0, height: 67.0), rotatedContext: { size, context in
            let arrowSize: CGFloat = 10.0
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.itemHighlightedBackgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
            context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
            context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
            context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
            context.closePath()
            context.fillPath()
        })?.stretchableImage(withLeftCapWidth: 61, topCapHeight: 2)
        
        let phoneInputBackground = generateImage(CGSize(width: 85.0, height: 57.0), rotatedContext: { size, context in
            let lineWidth = UIScreenPixel
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.separatorColor.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: 15.0, y: size.height - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth / 2.0))
            context.strokePath()
            context.move(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: size.height - lineWidth / 2.0))
            context.addLine(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: 0.0))
            context.strokePath()
        })?.stretchableImage(withLeftCapWidth: 84, topCapHeight: 2)
        
        self.countryButton = ASButtonNode()
        self.countryButton.displaysAsynchronously = false
        self.countryButton.setBackgroundImage(countryButtonBackground, for: [])
        self.countryButton.titleNode.maximumNumberOfLines = 1
        self.countryButton.titleNode.truncationMode = .byTruncatingTail
        self.countryButton.setBackgroundImage(countryButtonHighlightedBackground, for: .highlighted)
        
        self.phoneBackground = ASImageNode()
        self.phoneBackground.image = phoneInputBackground
        self.phoneBackground.displaysAsynchronously = false
        self.phoneBackground.displayWithoutProcessing = true
        self.phoneBackground.isLayerBacked = true
        
        self.phoneInputNode = PhoneInputNode()
        
        super.init()
        
        self.addSubnode(self.phoneBackground)
        self.addSubnode(self.countryButton)
        self.addSubnode(self.phoneInputNode)
        
        self.phoneInputNode.countryCodeField.textField.keyboardAppearance = theme.keyboardAppearance
        self.phoneInputNode.numberField.textField.keyboardAppearance = theme.keyboardAppearance
        self.phoneInputNode.countryCodeField.textField.textColor = theme.primaryColor
        self.phoneInputNode.numberField.textField.textColor = theme.primaryColor
        
        self.phoneInputNode.countryCodeField.textField.tintColor = theme.accentColor
        self.phoneInputNode.numberField.textField.tintColor = theme.accentColor
        
        self.phoneInputNode.countryCodeField.textField.disableAutomaticKeyboardHandling = [.forward]
        self.phoneInputNode.numberField.textField.disableAutomaticKeyboardHandling = [.forward]
        
        
        self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 10.0, right: 0.0)
        self.countryButton.contentHorizontalAlignment = .left
        
        self.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_PhonePlaceholder, font: Font.regular(20.0), textColor: theme.textPlaceholderColor)
        
        self.countryButton.addTarget(self, action: #selector(self.countryPressed), forControlEvents: .touchUpInside)
        
        self.phoneInputNode.countryCodeUpdated = { [weak self] code, name in
            if let strongSelf = self {
                if let code = Int(code), let name = name, let countryName = countryCodeAndIdToName[CountryCodeAndId(code: code, id: name)] {
                    let flagString = emojiFlagForISOCountryCode(name as NSString)
                    let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(name, strings: strongSelf.strings) ?? countryName
                    strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(20.0), with: theme.primaryColor, for: [])
                } else if let code = Int(code), let (countryId, countryName) = countryCodeToIdAndName[code] {
                    let flagString = emojiFlagForISOCountryCode(countryId as NSString)
                    let localizedName: String = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(countryId, strings: strongSelf.strings) ?? countryName
                    strongSelf.countryButton.setTitle("\(flagString) \(localizedName)", with: Font.regular(20.0), with: theme.primaryColor, for: [])
                } else {
                    strongSelf.countryButton.setTitle(strings.Login_SelectCountry_Title, with: Font.regular(20.0), with: theme.textPlaceholderColor, for: [])
                }
            }
        }
        
        self.phoneInputNode.number = "+1"
        self.phoneInputNode.returnAction = { [weak self] in
            self?.checkPhone?()
        }
    }
    
    @objc func countryPressed() {
        self.selectCountryCode?()
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.countryButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 67.0))
        self.phoneBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - 57.0), size: CGSize(width: size.width, height: 57.0))
        
        let countryCodeFrame = CGRect(origin: CGPoint(x: 18.0, y: size.height - 57.0), size: CGSize(width: 60.0, height: 57.0))
        let numberFrame = CGRect(origin: CGPoint(x: 96.0, y: size.height - 57.0), size: CGSize(width: size.width - 96.0 - 8.0, height: 57.0))
        
        let phoneInputFrame = countryCodeFrame.union(numberFrame)
        
        self.phoneInputNode.frame = phoneInputFrame
        self.phoneInputNode.countryCodeField.frame = countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
        self.phoneInputNode.numberField.frame = numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY)
    }
}

final class AuthorizationSequencePhoneEntryControllerNode: ASDisplayNode {
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let phoneAndCountryNode: PhoneAndCountryNode
    private let termsOfServiceNode: ImmediateTextNode
    
    var currentNumber: String {
        return self.phoneAndCountryNode.phoneInputNode.number
    }
    
    var codeAndNumber: (Int32?, String?, String) {
        get {
            return self.phoneAndCountryNode.phoneInputNode.codeAndNumber
        } set(value) {
            self.phoneAndCountryNode.phoneInputNode.codeAndNumber = value
        }
    }
    
    var selectCountryCode: (() -> Void)?
    var checkPhone: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.phoneAndCountryNode.phoneInputNode.enableEditing = !self.inProgress
            self.phoneAndCountryNode.phoneInputNode.alpha = self.inProgress ? 0.6 : 1.0
            self.phoneAndCountryNode.countryButton.isEnabled = !self.inProgress
        }
    }
    
    init(strings: PresentationStrings, theme: AuthorizationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.Login_PhoneTitle, font: Font.light(30.0), textColor: theme.primaryColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.attributedText = NSAttributedString(string: strings.Login_PhoneAndCountryHelp, font: Font.regular(16.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        self.termsOfServiceNode = ImmediateTextNode()
        self.termsOfServiceNode.maximumNumberOfLines = 0
        self.termsOfServiceNode.textAlignment = .center
        self.termsOfServiceNode.displaysAsynchronously = false
        
        let termsOfServiceAttributes = MarkdownAttributeSet(font: Font.regular(16.0), textColor: self.theme.primaryColor)
        let termsOfServiceLinkAttributes = MarkdownAttributeSet(font: Font.regular(16.0), textColor: self.theme.accentColor, additionalAttributes: [NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue as NSNumber, TelegramTextAttributes.URL: ""])
        
        let termsString = parseMarkdownIntoAttributedString(self.strings.Login_TermsOfServiceLabel.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: termsOfServiceAttributes, bold: termsOfServiceAttributes, link: termsOfServiceLinkAttributes, linkAttribute: { _ in
            return nil
        }), textAlignment: .center)
        self.termsOfServiceNode.attributedText = termsString
        
        self.phoneAndCountryNode = PhoneAndCountryNode(strings: strings, theme: theme)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.titleNode)
        //self.addSubnode(self.termsOfServiceNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.phoneAndCountryNode)
        
        self.phoneAndCountryNode.selectCountryCode = { [weak self] in
            self?.selectCountryCode?()
        }
        self.phoneAndCountryNode.checkPhone = { [weak self] in
            self?.checkPhone?()
        }
        
        self.termsOfServiceNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.termsOfServiceNode.tapAttributeAction = { attributes in
            if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
            }
        }
        self.termsOfServiceNode.linkHighlightColor = theme.accentColor.withAlphaComponent(0.5)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [])
        insets.top = navigationBarHeight
        
        if let inputHeight = layout.inputHeight {
            if inputHeight.isEqual(to: layout.standardInputHeight - 44.0) {
                insets.bottom += layout.standardInputHeight
            } else {
                insets.bottom += inputHeight
            }
        }
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: strings.Login_PhoneTitle, font: Font.light(40.0), textColor: self.theme.primaryColor)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: strings.Login_PhoneTitle, font: Font.light(30.0), textColor: self.theme.primaryColor)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let noticeSize = self.noticeNode.measure(CGSize(width: min(274.0, layout.size.width - 28.0), height: CGFloat.greatestFiniteMagnitude))
        
        var items: [AuthorizationLayoutItem] = [
            AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.phoneAndCountryNode, size: CGSize(width: layout.size.width, height: 115.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 44.0, maxValue: 44.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0))
        ]
        
        if layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 10.0)), items: items, transition: transition, failIfDoesNotFit: true) {
            self.termsOfServiceNode.isHidden = false
        } else {
            items.removeLast()
            let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 10.0)), items: items, transition: transition, failIfDoesNotFit: false)
            self.termsOfServiceNode.isHidden = true
        }
    }
    
    func activateInput() {
        self.phoneAndCountryNode.phoneInputNode.numberField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.phoneAndCountryNode.phoneInputNode.countryCodeField.layer.addShakeAnimation()
        self.phoneAndCountryNode.phoneInputNode.numberField.layer.addShakeAnimation()
    }
}
