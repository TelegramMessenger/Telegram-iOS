import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

enum SecureIdRequestedIdentityDocument: Int32 {
    case passport
    case driversLicense
    case idCard
    
    var valueKey: SecureIdValueKey {
        switch self {
            case .passport:
                return .passport
            case .driversLicense:
                return .driversLicense
            case .idCard:
                return .idCard
        }
    }
}

enum SecureIdRequestedAddressDocument: Int32 {
    case bankStatement
    case utilityBill
    case rentalAgreement
    
    var valueKey: SecureIdValueKey {
        switch self {
            case .bankStatement:
                return .bankStatement
            case .utilityBill:
                return .utilityBill
            case .rentalAgreement:
                return .rentalAgreement
        }
    }
}

enum SecureIdParsedRequestedFormField {
    case identity(personalDetails: Bool, document: Set<SecureIdRequestedIdentityDocument>, selfie: Bool)
    case address(addressDetails: Bool, document: Set<SecureIdRequestedAddressDocument>)
    case phone
    case email
}

func parseRequestedFormFields(_ types: [SecureIdRequestedFormField]) -> [SecureIdParsedRequestedFormField] {
    var identity: (Bool, Set<SecureIdRequestedIdentityDocument>, Bool) = (false, Set(), false)
    var address: (Bool, Set<SecureIdRequestedAddressDocument>) = (false, Set())
    var phone: Bool = false
    var email: Bool = false
    
    for type in types {
        switch type {
            case .personalDetails:
                identity.0 = true
            case let .passport(selfie):
                identity.1.insert(.passport)
                identity.2 = identity.2 || selfie
            case let .driversLicense(selfie):
                identity.1.insert(.driversLicense)
                identity.2 = identity.2 || selfie
            case let .idCard(selfie):
                identity.1.insert(.idCard)
                identity.2 = identity.2 || selfie
            case .address:
                address.0 = true
            case .bankStatement:
                address.1.insert(.bankStatement)
            case .utilityBill:
                address.1.insert(.utilityBill)
            case .rentalAgreement:
                address.1.insert(.rentalAgreement)
            case .phone:
                phone = true
            case .email:
                email = true
        }
    }
    
    var result: [SecureIdParsedRequestedFormField] = []
    if identity.0 || !identity.1.isEmpty {
        result.append(.identity(personalDetails: identity.0, document: identity.1, selfie: identity.2))
    }
    if address.0 || !address.1.isEmpty {
        result.append(.address(addressDetails: address.0, document: address.1))
    }
    if phone {
        result.append(.phone)
    }
    if email {
        result.append(.email)
    }
    
    return result
}

private let titleFont = Font.regular(17.0)
private let textFont = Font.regular(15.0)

private func fieldsText(_ fields: String...) -> String {
    var result = ""
    for field in fields {
        if !field.isEmpty {
            if !result.isEmpty {
                result.append(", ")
            }
            result.append(field)
        }
    }
    return result
}

private func countryName(code: String, strings: PresentationStrings) -> String {
    return AuthorizationSequenceCountrySelectionController.lookupCountryNameById(code, strings: strings) ?? ""
}

private func fieldTitleAndText(field: SecureIdParsedRequestedFormField, strings: PresentationStrings, values: [SecureIdValueWithContext]) -> (String, String) {
    let title: String
    let placeholder: String
    var text: String = ""
    
    switch field {
        case let .identity(personalDetails, documents, selfie):
            title = strings.SecureId_FormFieldIdentity
            placeholder = strings.SecureId_FormFieldIdentityPlaceholder
            
            if personalDetails {
                if let value = findValue(values, key: .personalDetails), case let .personalDetails(personalDetailsValue) = value.1 {
                    if !text.isEmpty {
                        text.append(", ")
                    }
                    text.append(fieldsText(personalDetailsValue.firstName, personalDetailsValue.lastName, countryName(code: personalDetailsValue.countryCode, strings: strings)))
                }
            }
            
            if !documents.isEmpty {
                for documentType in Array(documents).sorted(by: { $0.rawValue < $1.rawValue }) {
                    let key: SecureIdValueKey
                    switch documentType {
                        case .passport:
                            key = .passport
                        case .driversLicense:
                            key = .driversLicense
                        case .idCard:
                            key = .idCard
                    }
                    if let value = findValue(values, key: key)?.1 {
                        switch value {
                            case let .passport(passport):
                                break
                            case let .driversLicense(driversLicense):
                                break
                            case let .idCard(idCard):
                                break
                            default:
                                break
                        }
                    }
                }
            }
        case let .address(addressDetails, documents):
            title = strings.SecureId_FormFieldAddress
            placeholder = strings.SecureId_FormFieldAddressPlaceholder
            
            if addressDetails {
                if let value = findValue(values, key: .address), case let .address(addressValue) = value.1 {
                    if !text.isEmpty {
                        text.append(", ")
                    }
                    text.append(fieldsText(addressValue.postcode, addressValue.street1, addressValue.street2, addressValue.city))
                }
            }
        case .phone:
            title = strings.SecureId_FormFieldPhone
            placeholder = strings.SecureId_FormFieldPhonePlaceholder
            
            if let value = findValue(values, key: .phone), case let .phone(phoneValue) = value.1 {
                if !text.isEmpty {
                    text.append(", ")
                }
                text = formatPhoneNumber(phoneValue.phone)
            }
        case .email:
            title = strings.SecureId_FormFieldEmail
            placeholder = strings.SecureId_FormFieldEmailPlaceholder
        
            if let value = findValue(values, key: .email), case let .email(emailValue) = value.1 {
                if !text.isEmpty {
                    text.append(", ")
                }
                text = formatPhoneNumber(emailValue.email)
            }
    }
    
    return (title, text.isEmpty ? placeholder : text)
}

final class SecureIdAuthFormFieldNode: ASDisplayNode {
    private let selected: () -> Void
    
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let disclosureNode: ASImageNode
    private let checkNode: ASImageNode
    
    private let buttonNode: HighlightableButtonNode
    
    private var validLayout: (CGFloat, Bool, Bool)?
    
    private let field: SecureIdParsedRequestedFormField
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings, field: SecureIdParsedRequestedFormField, values: [SecureIdValueWithContext], errors: [SecureIdErrorKey: [String]], selected: @escaping () -> Void) {
        self.field = field
        self.theme = theme
        self.strings = strings
        self.selected = selected
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isLayerBacked = true
        self.titleNode.maximumNumberOfLines = 1
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isLayerBacked = true
        self.textNode.maximumNumberOfLines = 1
        
        self.disclosureNode = ASImageNode()
        self.disclosureNode.isLayerBacked = true
        self.disclosureNode.displayWithoutProcessing = true
        self.disclosureNode.displaysAsynchronously = false
        self.disclosureNode.image = PresentationResourcesItemList.disclosureArrowImage(theme)
        
        self.checkNode = ASImageNode()
        self.checkNode.isLayerBacked = true
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.displaysAsynchronously = false
        self.checkNode.image = PresentationResourcesItemList.checkIconImage(theme)
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.disclosureNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.buttonNode)
        
        self.updateValues(values, errors: errors)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    strongSelf.view.superview?.bringSubview(toFront: strongSelf.view)
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateValues(_ values: [SecureIdValueWithContext], errors: [SecureIdErrorKey: [String]]) {
        var (title, text) = fieldTitleAndText(field: self.field, strings: self.strings, values: values)
        var textColor = self.theme.list.itemSecondaryTextColor
        switch self.field {
            case .identity:
                if let error = errors[.personalDetails]?.first {
                    text = error
                    textColor = self.theme.list.itemDestructiveColor
                }
            default:
                break
        }
        self.titleNode.attributedText = NSAttributedString(string: title, font: titleFont, textColor: self.theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: textColor)
        
        var filled = true
        switch self.field {
            case let .identity(personalDetails, document, selfie):
                if personalDetails {
                    if findValue(values, key: .personalDetails) == nil {
                        filled = false
                    }
                }
                if !document.isEmpty {
                    var anyDocument = false
                    for type in document {
                        if findValue(values, key: type.valueKey) == nil {
                            anyDocument = true
                        }
                    }
                    if !anyDocument {
                        filled = false
                    }
                }
            case let .address(addressDetails, document):
                if addressDetails {
                    if findValue(values, key: .address) == nil {
                        filled = false
                    }
                }
                if !document.isEmpty {
                    var anyDocument = false
                    for type in document {
                        if findValue(values, key: type.valueKey) == nil {
                            anyDocument = true
                        }
                    }
                    if !anyDocument {
                        filled = false
                    }
                }
            case .phone:
                if findValue(values, key: .phone) == nil {
                    filled = false
                }
            case .email:
                if findValue(values, key: .email) == nil {
                    filled = false
                }
        }
        
        self.checkNode.isHidden = !filled
        self.disclosureNode.isHidden = filled
        
        if let (width, hasPrevious, hasNext) = self.validLayout {
            let _ = self.updateLayout(width: width, hasPrevious: hasPrevious, hasNext: hasNext, transition: .immediate)
        }
    }
    
    func updateLayout(width: CGFloat, hasPrevious: Bool, hasNext: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, hasPrevious, hasNext)
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        let height: CGFloat = 64.0
        
        let rightTextInset = rightInset + 24.0
        
        let titleTextSpacing: CGFloat = 5.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        
        let textOrigin = floor((height - titleSize.height - titleTextSpacing - textSize.height) / 2.0)
        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: textOrigin), size: titleSize)
        self.titleNode.frame = titleFrame
        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleTextSpacing), size: textSize)
        self.textNode.frame = textFrame
        
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateAlpha(node: self.topSeparatorNode, alpha: hasPrevious ? 0.0 : 1.0)
        let bottomSeparatorInset: CGFloat = hasNext ? leftInset : 0.0
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: bottomSeparatorInset, y: height - UIScreenPixel), size: CGSize(width: width - bottomSeparatorInset, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height)))
        transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -(hasPrevious ? UIScreenPixel : 0.0)), size: CGSize(width: width, height: height + (hasPrevious ? UIScreenPixel : 0.0))))
        
        if let image = self.disclosureNode.image {
            self.disclosureNode.frame = CGRect(origin: CGPoint(x: width - 15.0 - image.size.width, y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        if let image = self.checkNode.image {
            self.checkNode.frame = CGRect(origin: CGPoint(x: width - 15.0 - image.size.width, y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        return height
    }
    
    @objc private func buttonPressed() {
        self.selected()
    }
}
