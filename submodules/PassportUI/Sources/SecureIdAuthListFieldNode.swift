import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import PhoneNumberFormat

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

private func fieldsText(_ fields: [String]) -> String {
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

private func fieldTitleAndText(field: SecureIdAuthListContentField, strings: PresentationStrings, values: [SecureIdValueWithContext]) -> (String, String) {
    let title: String
    let placeholder: String
    var text: String = ""
    
    switch field {
        case .identity:
            title = strings.Passport_FieldIdentity
            placeholder = strings.Passport_FieldIdentityDetailsHelp
            
            let keyList: [(SecureIdValueKey, String)] = [
                (.personalDetails, strings.Passport_Identity_TypePersonalDetails),
                (.passport, strings.Passport_Identity_TypePassport),
                (.idCard, strings.Passport_Identity_TypeIdentityCard),
                (.driversLicense, strings.Passport_Identity_TypeDriversLicense),
                (.internalPassport, strings.Passport_Identity_TypeInternalPassport)
            ]
            
            var fields: [String] = []
            for (key, valueTitle) in keyList {
                if findValue(values, key: key) != nil {
                    fields.append(valueTitle)
                }
            }
            
            if !fields.isEmpty {
                text = fieldsText(fields)
            }
        case .address:
            title = strings.Passport_FieldAddress
            placeholder = strings.Passport_FieldAddressHelp
            
            let keyList: [(SecureIdValueKey, String)] = [
                (.address, strings.Passport_Address_TypeResidentialAddress),
                (.utilityBill, strings.Passport_Address_TypeUtilityBill),
                (.bankStatement, strings.Passport_Address_TypeBankStatement),
                (.rentalAgreement, strings.Passport_Address_TypeRentalAgreement),
                (.passportRegistration, strings.Passport_Address_TypePassportRegistration),
                (.temporaryRegistration, strings.Passport_Address_TypeTemporaryRegistration)
            ]
            
            var fields: [String] = []
            for (key, valueTitle) in keyList {
                if findValue(values, key: key) != nil {
                    fields.append(valueTitle)
                }
            }
            
            if !fields.isEmpty {
                text = fieldsText(fields)
            }
        case .phone:
            title = strings.Passport_FieldPhone
            placeholder = strings.Passport_FieldPhoneHelp
            
            if let value = findValue(values, key: .phone), case let .phone(phoneValue) = value.1.value {
                if !text.isEmpty {
                    text.append(", ")
                }
                text = formatPhoneNumber(phoneValue.phone)
            }
        case .email:
            title = strings.Passport_FieldEmail
            placeholder = strings.Passport_FieldEmailHelp
            
            if let value = findValue(values, key: .email), case let .email(emailValue) = value.1.value {
                if !text.isEmpty {
                    text.append(", ")
                }
                text = formatPhoneNumber(emailValue.email)
            }
    }
    
    return (title, text.isEmpty ? placeholder : text)
}

enum SecureIdAuthListContentField {
    case identity
    case address
    case phone
    case email
}

final class SecureIdAuthListFieldNode: ASDisplayNode {
    private let selected: () -> Void
    
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let disclosureNode: ASImageNode
    
    private let buttonNode: HighlightableButtonNode
    
    private var validLayout: (CGFloat, Bool, Bool)?
    
    private let field: SecureIdAuthListContentField
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings, field: SecureIdAuthListContentField, values: [SecureIdValueWithContext], selected: @escaping () -> Void) {
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
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.maximumNumberOfLines = 1
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.maximumNumberOfLines = 4
        
        self.disclosureNode = ASImageNode()
        self.disclosureNode.isLayerBacked = true
        self.disclosureNode.displayWithoutProcessing = true
        self.disclosureNode.displaysAsynchronously = false
        self.disclosureNode.image = PresentationResourcesItemList.disclosureArrowImage(theme)
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.disclosureNode)
        self.addSubnode(self.buttonNode)
        
        self.updateValues(values)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    strongSelf.view.superview?.bringSubviewToFront(strongSelf.view)
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateValues(_ values: [SecureIdValueWithContext]) {
        let (title, text) = fieldTitleAndText(field: self.field, strings: self.strings, values: values)
        let textColor = self.theme.list.itemSecondaryTextColor
        self.titleNode.attributedText = NSAttributedString(string: title, font: titleFont, textColor: self.theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: textColor)
        
        self.disclosureNode.isHidden = false
        
        if let (width, hasPrevious, hasNext) = self.validLayout {
            let _ = self.updateLayout(width: width, hasPrevious: hasPrevious, hasNext: hasNext, transition: .immediate)
        }
    }
    
    func updateLayout(width: CGFloat, hasPrevious: Bool, hasNext: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, hasPrevious, hasNext)
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        
        let rightTextInset = rightInset + 24.0
        let titleTextSpacing: CGFloat = 5.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        let height = max(64.0, 11.0 + titleSize.height + titleTextSpacing + textSize.height + 11.0)
        
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
            self.disclosureNode.frame = CGRect(origin: CGPoint(x: width - 7.0 - image.size.width, y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        return height
    }
    
    @objc private func buttonPressed() {
        self.selected()
    }
}
