import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

let countryCodeToName: [Int: String] = [
 1876: "Jamaica",
 1869: "Saint Kitts & Nevis",
 1868: "Trinidad & Tobago",
 1784: "Saint Vincent & the Grenadines",
 1767: "Dominica",
 1758: "Saint Lucia",
 1721: "Sint Maarten",
 1684: "American Samoa",
 1671: "Guam",
 1670: "Northern Mariana Islands",
 1664: "Montserrat",
 1649: "Turks & Caicos Islands",
 1473: "Grenada",
 1441: "Bermuda",
 1345: "Cayman Islands",
 1340: "US Virgin Islands",
 1284: "British Virgin Islands",
 1268: "Antigua & Barbuda",
 1264: "Anguilla",
 1246: "Barbados",
 1242: "Bahamas",
 998: "Uzbekistan",
 996: "Kyrgyzstan",
 995: "Georgia",
 994: "Azerbaijan",
 993: "Turkmenistan",
 992: "Tajikistan",
 977: "Nepal",
 976: "Mongolia",
 975: "Bhutan",
 974: "Qatar",
 973: "Bahrain",
 972: "Israel",
 971: "United Arab Emirates",
 970: "Palestine",
 968: "Oman",
 967: "Yemen",
 966: "Saudi Arabia",
 965: "Kuwait",
 964: "Iraq",
 963: "Syrian Arab Republic",
 962: "Jordan",
 961: "Lebanon",
 960: "Maldives",
 886: "Taiwan",
 880: "Bangladesh",
 856: "Laos",
 855: "Cambodia",
 853: "Macau",
 852: "Hong Kong",
 850: "North Korea",
 692: "Marshall Islands",
 691: "Micronesia",
 690: "Tokelau",
 689: "French Polynesia",
 688: "Tuvalu",
 687: "New Caledonia",
 686: "Kiribati",
 685: "Samoa",
 683: "Niue",
 682: "Cook Islands",
 681: "Wallis & Futuna",
 680: "Palau",
 679: "Fiji",
 678: "Vanuatu",
 677: "Solomon Islands",
 676: "Tonga",
 675: "Papua New Guinea",
 674: "Nauru",
 673: "Brunei Darussalam",
 672: "Norfolk Island",
 670: "Timor-Leste",
 599: "Bonaire, Sint Eustatius & Saba",
 //599: "Curaçao",
 598: "Uruguay",
 597: "Suriname",
 596: "Martinique",
 595: "Paraguay",
 594: "French Guiana",
 593: "Ecuador",
 592: "Guyana",
 591: "Bolivia",
 590: "Guadeloupe",
 509: "Haiti",
 508: "Saint Pierre & Miquelon",
 507: "Panama",
 506: "Costa Rica",
 505: "Nicaragua",
 504: "Honduras",
 503: "El Salvador",
 502: "Guatemala",
 501: "Belize",
 500: "Falkland Islands",
 423: "Liechtenstein",
 421: "Slovakia",
 420: "Czech Republic",
 389: "Macedonia",
 387: "Bosnia & Herzegovina",
 386: "Slovenia",
 385: "Croatia",
 382: "Montenegro",
 381: "Serbia",
 380: "Ukraine",
 378: "San Marino",
 377: "Monaco",
 376: "Andorra",
 375: "Belarus",
 374: "Armenia",
 373: "Moldova",
 372: "Estonia",
 371: "Latvia",
 370: "Lithuania",
 359: "Bulgaria",
 358: "Finland",
 357: "Cyprus",
 356: "Malta",
 355: "Albania",
 354: "Iceland",
 353: "Ireland",
 352: "Luxembourg",
 351: "Portugal",
 350: "Gibraltar",
 299: "Greenland",
 298: "Faroe Islands",
 297: "Aruba",
 291: "Eritrea",
 290: "Saint Helena",
 269: "Comoros",
 268: "Swaziland",
 267: "Botswana",
 266: "Lesotho",
 265: "Malawi",
 264: "Namibia",
 263: "Zimbabwe",
 262: "Réunion",
 261: "Madagascar",
 260: "Zambia",
 258: "Mozambique",
 257: "Burundi",
 256: "Uganda",
 255: "Tanzania",
 254: "Kenya",
 253: "Djibouti",
 252: "Somalia",
 251: "Ethiopia",
 250: "Rwanda",
 249: "Sudan",
 248: "Seychelles",
 247: "Saint Helena",
 246: "Diego Garcia",
 245: "Guinea-Bissau",
 244: "Angola",
 243: "Congo (Dem. Rep.)",
 242: "Congo (Rep.)",
 241: "Gabon",
 240: "Equatorial Guinea",
 239: "São Tomé & Príncipe",
 238: "Cape Verde",
 237: "Cameroon",
 236: "Central African Rep.",
 235: "Chad",
 234: "Nigeria",
 233: "Ghana",
 232: "Sierra Leone",
 231: "Liberia",
 230: "Mauritius",
 229: "Benin",
 228: "Togo",
 227: "Niger",
 226: "Burkina Faso",
 225: "Côte d`Ivoire",
 224: "Guinea",
 223: "Mali",
 222: "Mauritania",
 221: "Senegal",
 220: "Gambia",
 218: "Libya",
 216: "Tunisia",
 213: "Algeria",
 212: "Morocco",
 211: "South Sudan",
 98: "Iran",
 95: "Myanmar",
 94: "Sri Lanka",
 93: "Afghanistan",
 92: "Pakistan",
 91: "India",
 90: "Turkey",
 86: "China",
 84: "Vietnam",
 82: "South Korea",
 81: "Japan",
 66: "Thailand",
 65: "Singapore",
 64: "New Zealand",
 63: "Philippines",
 62: "Indonesia",
 61: "Australia",
 60: "Malaysia",
 58: "Venezuela",
 57: "Colombia",
 56: "Chile",
 55: "Brazil",
 54: "Argentina",
 53: "Cuba",
 52: "Mexico",
 51: "Peru",
 49: "Germany",
 48: "Poland",
 47: "Norway",
 46: "Sweden",
 45: "Denmark",
 44: "United Kingdom",
 43: "Austria",
 41: "Switzerland",
 40: "Romania",
 39: "Italy",
 36: "Hungary",
 34: "Spain",
 33: "France",
 32: "Belgium",
 31: "Netherlands",
 30: "Greece",
 27: "South Africa",
 20: "Egypt",
 7: "Russian Federation",
// 7: "Kazakhstan",
 1: "USA",
// 1: "Puerto Rico",
// 1: "Dominican Rep.",
// 1: "Canada"
]

private let countryButtonBackground = generateImage(CGSize(width: 61.0, height: 67.0), rotatedContext: { size, context in
    let arrowSize: CGFloat = 10.0
    let lineWidth = UIScreenPixel
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0xbcbbc1).cgColor)
    context.setLineWidth(lineWidth)
    context.move(to: CGPoint(x: size.width, y: size.height - arrowSize - lineWidth / 2.0))
    context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize - lineWidth / 2.0))
    context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height - lineWidth / 2.0))
    context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize - lineWidth / 2.0))
    context.addLine(to: CGPoint(x: 15.0, y: size.height - arrowSize - lineWidth / 2.0))
    context.strokePath()
})?.stretchableImage(withLeftCapWidth: 61, topCapHeight: 1)

private let countryButtonHighlightedBackground = generateImage(CGSize(width: 60.0, height: 67.0), rotatedContext: { size, context in
    let arrowSize: CGFloat = 10.0
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(0xbcbbc1).cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
    context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
    context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
    context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
    context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
    context.closePath()
    context.fillPath()
})?.stretchableImage(withLeftCapWidth: 61, topCapHeight: 2)

private let phoneInputBackground = generateImage(CGSize(width: 85.0, height: 57.0), rotatedContext: { size, context in
    let arrowSize: CGFloat = 10.0
    let lineWidth = UIScreenPixel
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0xbcbbc1).cgColor)
    context.setLineWidth(lineWidth)
    context.move(to: CGPoint(x: 15.0, y: size.height - lineWidth / 2.0))
    context.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth / 2.0))
    context.strokePath()
    context.move(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: size.height - lineWidth / 2.0))
    context.addLine(to: CGPoint(x: size.width - 2.0 + lineWidth / 2.0, y: 0.0))
    context.strokePath()
})?.stretchableImage(withLeftCapWidth: 84, topCapHeight: 2)

final class AuthorizationSequencePhoneEntryControllerNode: ASDisplayNode {
    private let navigationBackgroundNode: ASDisplayNode
    private let stripeNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let termsOfServiceNode: ASTextNode
    private let countryButton: ASButtonNode
    private let phoneBackground: ASImageNode
    private let phoneInputNode: PhoneInputNode
    
    var currentNumber: String {
        return self.phoneInputNode.number
    }
    
    var codeAndNumber: (Int32?, String) {
        get {
            return self.phoneInputNode.codeAndNumber
        } set(value) {
            self.phoneInputNode.codeAndNumber = value
        }
    }
    
    var selectCountryCode: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.phoneInputNode.enableEditing = !self.inProgress
            self.phoneInputNode.alpha = self.inProgress ? 0.6 : 1.0
            self.countryButton.isEnabled = !self.inProgress
        }
    }
    
    override init() {
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.isLayerBacked = true
        self.navigationBackgroundNode.backgroundColor = UIColor(0xefefef)
        
        self.stripeNode = ASDisplayNode()
        self.stripeNode.isLayerBacked = true
        self.stripeNode.backgroundColor = UIColor(0xbcbbc1)
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: "Your Phone", font: Font.light(30.0), textColor: UIColor.black)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isLayerBacked = true
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.attributedText = NSAttributedString(string: "Please confirm your country code and enter your phone number.", font: Font.regular(16.0), textColor: UIColor(0x878787), paragraphAlignment: .center)
        
        self.termsOfServiceNode = ASTextNode()
        self.termsOfServiceNode.isLayerBacked = true
        self.termsOfServiceNode.displaysAsynchronously = false
        let termsString = NSMutableAttributedString()
        termsString.append(NSAttributedString(string: "By signing up,\nyou agree to the ", font: Font.regular(16.0), textColor: UIColor.black))
        termsString.append(NSAttributedString(string: "Terms of Service", font: Font.regular(16.0), textColor: UIColor(0x007ee5)))
        termsString.append(NSAttributedString(string: ".", font: Font.regular(16.0), textColor: UIColor.black))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        termsString.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(0, termsString.length))
        self.termsOfServiceNode.attributedText = termsString
        
        self.countryButton = ASButtonNode()
        self.countryButton.setBackgroundImage(countryButtonBackground, for: [])
        self.countryButton.setBackgroundImage(countryButtonHighlightedBackground, for: .highlighted)
        
        self.phoneBackground = ASImageNode()
        self.phoneBackground.image = phoneInputBackground
        self.phoneBackground.displaysAsynchronously = false
        self.phoneBackground.displayWithoutProcessing = true
        self.phoneBackground.isLayerBacked = true
        
        self.phoneInputNode = PhoneInputNode()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor.white
        
        self.addSubnode(self.navigationBackgroundNode)
        self.addSubnode(self.stripeNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.termsOfServiceNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.phoneBackground)
        self.addSubnode(self.countryButton)
        self.addSubnode(self.phoneInputNode)
        
        self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 10.0, right: 0.0)
        self.countryButton.contentHorizontalAlignment = .left
        
        self.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: "Your phone number", font: Font.regular(20.0), textColor: UIColor(0xbcbcc3))
        
        self.countryButton.addTarget(self, action: #selector(self.countryPressed), forControlEvents: .touchUpInside)
        
        self.phoneInputNode.countryCodeUpdated = { [weak self] code in
            if let strongSelf = self {
                if let code = Int(code), let countryName = countryCodeToName[code] {
                    strongSelf.countryButton.setTitle(countryName, with: Font.regular(20.0), with: .black, for: [])
                } else {
                    strongSelf.countryButton.setTitle("Select Country", with: Font.regular(20.0), with: .black, for: [])
                }
            }
        }
        
        self.phoneInputNode.number = "+1"
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let insets = layout.insets(options: [.statusBar, .input])
        let availableHeight = max(1.0, layout.size.height - insets.top - insets.bottom)
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: "Your Phone", font: Font.light(40.0), textColor: UIColor.black)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: "Your Phone", font: Font.light(30.0), textColor: UIColor.black)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let minimalTitleSpacing: CGFloat = 10.0
        let maxTitleSpacing: CGFloat = 28.0
        let countryButtonHeight: CGFloat = 57.0
        let inputFieldsHeight: CGFloat = 57.0
        
        let minimalNoticeSpacing: CGFloat = 11.0
        let maxNoticeSpacing: CGFloat = 35.0
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let minimalTermsOfServiceSpacing: CGFloat = 6.0
        let maxTermsOfServiceSpacing: CGFloat = 20.0
        let termsOfServiceSize = self.termsOfServiceNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let minTrailingSpacing: CGFloat = 10.0
        
        let inputHeight = countryButtonHeight + inputFieldsHeight
        let essentialHeight = titleSize.height + minimalTitleSpacing + inputHeight
        let additionalHeight = minimalNoticeSpacing + noticeSize.height + minimalTermsOfServiceSpacing + termsOfServiceSize.height + minTrailingSpacing
        
        let navigationHeight: CGFloat
        if essentialHeight + additionalHeight > availableHeight || availableHeight * 0.66 - inputHeight < additionalHeight {
            transition.updateAlpha(node: self.noticeNode, alpha: 0.0)
            transition.updateAlpha(node: self.termsOfServiceNode, alpha: 0.0)
            navigationHeight = min(floor(availableHeight * 0.3), availableHeight - countryButtonHeight - inputFieldsHeight)
        } else {
            transition.updateAlpha(node: self.noticeNode, alpha: 1.0)
            transition.updateAlpha(node: self.termsOfServiceNode, alpha: 1.0)
            navigationHeight = floor(availableHeight * 0.3)
        }
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight)))
        transition.updateFrame(node: self.stripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        let titleOffset: CGFloat
        if navigationHeight * 0.5 < titleSize.height + minimalTitleSpacing {
            titleOffset = floor((navigationHeight - titleSize.height) / 2.0)
        } else {
            titleOffset = max(navigationHeight * 0.5, navigationHeight - maxTitleSpacing - titleSize.height)
        }
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: titleOffset), size: titleSize))
        
        transition.updateFrame(node: self.countryButton, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: 67.0)))
        transition.updateFrame(node: self.phoneBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight + 57.0), size: CGSize(width: layout.size.width, height: 57.0)))
        
        let countryCodeFrame = CGRect(origin: CGPoint(x: 18.0, y: navigationHeight + 58.0), size: CGSize(width: 60.0, height: 57.0))
        let numberFrame = CGRect(origin: CGPoint(x: 96.0, y: navigationHeight + 58.0), size: CGSize(width: layout.size.width - 96.0 - 8.0, height: 57.0))
        
        let phoneInputFrame = countryCodeFrame.union(numberFrame)
        
        transition.updateFrame(node: self.phoneInputNode, frame: phoneInputFrame)
        transition.updateFrame(node: self.phoneInputNode.countryCodeField, frame: countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
        transition.updateFrame(node: self.phoneInputNode.numberField, frame: numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
        
        let additionalAvailableHeight = max(1.0, availableHeight - phoneInputFrame.maxY)
        let additionalAvailableSpacing = max(1.0, additionalAvailableHeight - noticeSize.height - termsOfServiceSize.height)
        let noticeSpacingFactor = maxNoticeSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        let termsOfServiceSpacingFactor = maxTermsOfServiceSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        
        let noticeSpacing: CGFloat
        let termsOfServiceSpacing: CGFloat
        if additionalAvailableHeight <= maxNoticeSpacing + noticeSize.height + maxTermsOfServiceSpacing + termsOfServiceSize.height + minTrailingSpacing {
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
            noticeSpacing = floor((additionalAvailableHeight - termsOfServiceSpacing - noticeSize.height - termsOfServiceSize.height) / 2.0)
        } else {
            noticeSpacing = min(floor(noticeSpacingFactor * additionalAvailableSpacing), maxNoticeSpacing)
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
        }
        
        let noticeFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - noticeSize.width) / 2.0), y: phoneInputFrame.maxY + noticeSpacing), size: noticeSize)
        let termsOfServiceFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - termsOfServiceSize.width) / 2.0), y: noticeFrame.maxY + termsOfServiceSpacing), size: termsOfServiceSize)
        
        transition.updateFrame(node: self.noticeNode, frame: noticeFrame)
        transition.updateFrame(node: self.termsOfServiceNode, frame: termsOfServiceFrame)
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
