import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextFormat
import Markdown

private func roundCorners(diameter: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}

final class AuthorizationSequenceSignUpControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let addPhoto: () -> Void
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    private let termsNode: ImmediateTextNode
    
    private let firstNameField: TextFieldNode
    private let lastNameField: TextFieldNode
    private let firstSeparatorNode: ASDisplayNode
    private let lastSeparatorNode: ASDisplayNode
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var currentName: (String, String) {
        return (self.firstNameField.textField.text ?? "", self.lastNameField.textField.text ?? "")
    }
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                self.currentPhotoNode.image = generateImage(CGSize(width: 110.0, height: 110.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    context.draw(currentPhoto.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.destinationOut)
                    context.draw(roundCorners(diameter: size.width).cgImage!, in: CGRect(origin: CGPoint(), size: size))
                })
            } else {
                self.currentPhotoNode.image = nil
            }
        }
    }
    
    var signUpWithName: ((String, String) -> Void)?
    var openTermsOfService: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.firstNameField.alpha = self.inProgress ? 0.6 : 1.0
            self.lastNameField.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, addPhoto: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_InfoTitle, font: Font.light(30.0), textColor: theme.list.itemPrimaryTextColor)
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(string: self.strings.Login_InfoHelp, font: Font.regular(16.0), textColor: theme.list.itemPlaceholderTextColor, paragraphAlignment: .center)
        
        self.termsNode = ImmediateTextNode()
        self.termsNode.textAlignment = .center
        self.termsNode.maximumNumberOfLines = 0
        self.termsNode.displaysAsynchronously = false
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.termsNode.attributedText = parseMarkdownIntoAttributedString(strings.Login_TermsOfServiceLabel.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.firstSeparatorNode = ASDisplayNode()
        self.firstSeparatorNode.isLayerBacked = true
        self.firstSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.lastSeparatorNode = ASDisplayNode()
        self.lastSeparatorNode.isLayerBacked = true
        self.lastSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.firstNameField = TextFieldNode()
        self.firstNameField.textField.font = Font.regular(20.0)
        self.firstNameField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.firstNameField.textField.textAlignment = .natural
        self.firstNameField.textField.returnKeyType = .next
        self.firstNameField.textField.attributedPlaceholder = NSAttributedString(string: self.strings.UserInfo_FirstNamePlaceholder, font: self.firstNameField.textField.font, textColor: self.theme.list.itemPlaceholderTextColor)
        self.firstNameField.textField.autocapitalizationType = .words
        self.firstNameField.textField.autocorrectionType = .no
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.firstNameField.textField.textContentType = .givenName
        }
        self.firstNameField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.firstNameField.textField.tintColor = theme.list.itemAccentColor
        
        self.lastNameField = TextFieldNode()
        self.lastNameField.textField.font = Font.regular(20.0)
        self.lastNameField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.lastNameField.textField.textAlignment = .natural
        self.lastNameField.textField.returnKeyType = .done
        self.lastNameField.textField.attributedPlaceholder = NSAttributedString(string: strings.UserInfo_LastNamePlaceholder, font: self.lastNameField.textField.font, textColor: self.theme.list.itemPlaceholderTextColor)
        self.lastNameField.textField.autocapitalizationType = .words
        self.lastNameField.textField.autocorrectionType = .no
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.lastNameField.textField.textContentType = .familyName
        }
        self.lastNameField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.lastNameField.textField.tintColor = theme.list.itemAccentColor
        
        self.currentPhotoNode = ASImageNode()
        self.currentPhotoNode.isUserInteractionEnabled = false
        self.currentPhotoNode.displaysAsynchronously = false
        self.currentPhotoNode.displayWithoutProcessing = true
        
        self.addPhotoButton = HighlightableButtonNode()
        self.addPhotoButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: self.theme.list.itemPlaceholderTextColor), for: .normal)
        self.addPhotoButton.setBackgroundImage(generateCircleImage(diameter: 110.0, lineWidth: 1.0, color: self.theme.list.itemPlaceholderTextColor), for: .normal)
        
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.addPhotoButton.allowsGroupOpacity = true
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.firstNameField.textField.delegate = self
        self.lastNameField.textField.delegate = self
        
        self.addSubnode(self.firstSeparatorNode)
        self.addSubnode(self.lastSeparatorNode)
        self.addSubnode(self.firstNameField)
        self.addSubnode(self.lastNameField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.termsNode)
        self.termsNode.isHidden = true
        self.addSubnode(self.addPhotoButton)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        
        self.termsNode.linkHighlightColor = self.theme.list.itemAccentColor.withAlphaComponent(0.5)
        self.termsNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.termsNode.tapAttributeAction = { [weak self] attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                self?.openTermsOfService?()
            }
        }
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        self.termsNode.isHidden = !hasTermsOfService
        self.firstNameField.textField.attributedText = NSAttributedString(string: firstName, font: Font.regular(20.0), textColor: self.theme.list.itemPlaceholderTextColor)
        self.lastNameField.textField.attributedText = NSAttributedString(string: lastName, font: Font.regular(20.0), textColor: self.theme.list.itemPlaceholderTextColor)
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar])
        if let inputHeight = layout.inputHeight {
            insets.bottom += max(inputHeight, layout.standardInputHeight)
        }
        
        let availableHeight = max(1.0, layout.size.height - insets.top - insets.bottom)
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_InfoTitle, font: Font.light(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_InfoTitle, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let additionalTitleSpacing: CGFloat
        if titleSize.width > layout.size.width - 160.0 {
            additionalTitleSpacing = 44.0
        } else {
            additionalTitleSpacing = 0.0
        }
        
        let minimalTitleSpacing: CGFloat = 10.0
        let maxTitleSpacing: CGFloat = 22.0
        let fieldHeight: CGFloat = 57.0
        let inputFieldsHeight: CGFloat = fieldHeight * 2.0
        let leftInset: CGFloat = 130.0
        
        let minimalNoticeSpacing: CGFloat = 11.0
        let maxNoticeSpacing: CGFloat = 35.0
        let noticeSize = self.currentOptionNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let termsSize = self.termsNode.updateLayout(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeHeight: CGFloat = noticeSize.height + (self.termsNode.isHidden ? 0.0 : (termsSize.height + 4.0))
        
        let minimalTermsOfServiceSpacing: CGFloat = 6.0
        let maxTermsOfServiceSpacing: CGFloat = 20.0
        let minTrailingSpacing: CGFloat = 10.0
        
        let inputHeight = inputFieldsHeight
        let essentialHeight = additionalTitleSpacing + titleSize.height + minimalTitleSpacing + inputHeight + minimalNoticeSpacing + noticeHeight
        let additionalHeight = minimalTermsOfServiceSpacing + minTrailingSpacing
        
        let navigationHeight: CGFloat
        if essentialHeight + additionalHeight > availableHeight || availableHeight * 0.66 - inputHeight < additionalHeight {
            navigationHeight = min(floor(availableHeight * 0.3), availableHeight - inputFieldsHeight)
        } else {
            navigationHeight = floor(availableHeight * 0.3)
        }
        
        let titleOffset: CGFloat
        if navigationHeight * 0.5 < titleSize.height + minimalTitleSpacing {
            titleOffset = max(navigationBarHeight, floor((navigationHeight - titleSize.height) / 2.0))
        } else {
            titleOffset = max(navigationBarHeight, max(navigationHeight * 0.5, navigationHeight - maxTitleSpacing - titleSize.height))
        }
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: titleOffset), size: titleSize))
        
        let addPhotoButtonFrame = CGRect(origin: CGPoint(x: 10.0, y: navigationHeight + 10.0), size: CGSize(width: 110.0, height: 110.0))
        transition.updateFrame(node: self.addPhotoButton, frame: addPhotoButtonFrame)
        self.currentPhotoNode.frame = CGRect(origin: CGPoint(), size: addPhotoButtonFrame.size)
        
        let firstFieldFrame = CGRect(origin: CGPoint(x: leftInset, y: navigationHeight + 3.0), size: CGSize(width: layout.size.width - leftInset, height: fieldHeight))
        transition.updateFrame(node: self.firstNameField, frame: firstFieldFrame)
        
        let lastFieldFrame = CGRect(origin: CGPoint(x: firstFieldFrame.minX, y: firstFieldFrame.maxY), size: CGSize(width: firstFieldFrame.size.width, height: fieldHeight))
        transition.updateFrame(node: self.lastNameField, frame: lastFieldFrame)
        
        transition.updateFrame(node: self.firstSeparatorNode, frame: CGRect(origin: CGPoint(x: leftInset, y: firstFieldFrame.maxY), size: CGSize(width: layout.size.width - leftInset, height: UIScreenPixel)))
        transition.updateFrame(node: self.lastSeparatorNode, frame: CGRect(origin: CGPoint(x: leftInset, y: lastFieldFrame.maxY), size: CGSize(width: layout.size.width - leftInset, height: UIScreenPixel)))
        
        let additionalAvailableHeight = max(1.0, availableHeight - lastFieldFrame.maxY)
        let additionalAvailableSpacing = max(1.0, additionalAvailableHeight - noticeHeight)
        let noticeSpacingFactor = maxNoticeSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        let termsOfServiceSpacingFactor = maxTermsOfServiceSpacing / (maxNoticeSpacing + maxTermsOfServiceSpacing + minTrailingSpacing)
        
        let noticeSpacing: CGFloat
        let termsOfServiceSpacing: CGFloat
        if additionalAvailableHeight <= maxNoticeSpacing + noticeHeight + maxTermsOfServiceSpacing + minTrailingSpacing {
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
            noticeSpacing = floor((additionalAvailableHeight - termsOfServiceSpacing - noticeHeight) / 2.0)
        } else {
            noticeSpacing = min(floor(noticeSpacingFactor * additionalAvailableSpacing), maxNoticeSpacing)
            termsOfServiceSpacing = min(floor(termsOfServiceSpacingFactor * additionalAvailableSpacing), maxTermsOfServiceSpacing)
        }
        
        let currentOptionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - noticeSize.width) / 2.0), y: lastFieldFrame.maxY + max(0.0, noticeSpacing)), size: noticeSize)
        transition.updateFrame(node: self.currentOptionNode, frame: currentOptionFrame)
        let termsFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - termsSize.width) / 2.0), y: layout.size.height - insets.bottom - termsSize.height - 4.0), size: termsSize)
        transition.updateFrame(node: self.termsNode, frame: termsFrame)
    }
    
    func activateInput() {
        self.firstNameField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        if self.firstNameField.textField.text == nil || self.firstNameField.textField.text!.isEmpty {
            self.firstNameField.layer.addShakeAnimation()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === self.firstNameField.textField {
            self.lastNameField.textField.becomeFirstResponder()
        } else {
            let name = self.currentName
            self.signUpWithName?(name.0, name.1)
        }
        return false
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
}
