import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import PhoneInputNode

private let textFont = Font.regular(17.0)

private func countryButtonBackground(color: UIColor, separatorColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 45.0, height: 44.0 + 6.0), rotatedContext: { size, context in
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
        
        context.setStrokeColor(separatorColor.cgColor)
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
    })?.stretchableImage(withLeftCapWidth: 46, topCapHeight: 1)
}

private func countryButtonHighlightedBackground(fillColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 45.0, height: 44.0 + 6.0), rotatedContext: { size, context in
        let arrowSize: CGFloat = 6.0
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(fillColor.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height - arrowSize)))
        context.move(to: CGPoint(x: size.width, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - arrowSize))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize, y: size.height))
        context.addLine(to: CGPoint(x: size.width - 1.0 - arrowSize - arrowSize, y: size.height - arrowSize))
        context.closePath()
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 46, topCapHeight: 2)
}

final class SecureIdValueFormPhoneItem: FormControllerItem {
    fileprivate let countryCode: String
    fileprivate let number: String
    fileprivate let countryName: String
    fileprivate let openCountrySelection: () -> Void
    fileprivate let updateCountryCode: (String) -> Void
    fileprivate let updateNumber: (String) -> Void
    
    init(countryCode: String, number: String, countryName: String, openCountrySelection: @escaping () -> Void, updateCountryCode: @escaping (String) -> Void, updateNumber: @escaping (String) -> Void) {
        self.countryCode = countryCode
        self.number = number
        self.countryName = countryName
        self.openCountrySelection = openCountrySelection
        self.updateCountryCode = updateCountryCode
        self.updateNumber = updateNumber
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return SecureIdValueFormPhoneItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? SecureIdValueFormPhoneItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class SecureIdValueFormPhoneItemNode: FormBlockItemNode<SecureIdValueFormPhoneItem> {
    private let countryButton: ASButtonNode
    private let phoneInputNode: PhoneInputNode
    
    private var item: SecureIdValueFormPhoneItem?
    private var theme: PresentationTheme?
    
    init() {
        self.countryButton = ASButtonNode()
        
        self.phoneInputNode = PhoneInputNode(fontSize: 17.0)
        
        super.init(selectable: false, topSeparatorInset: .regular)
        
        self.addSubnode(self.countryButton)
        self.addSubnode(self.phoneInputNode)
        
        self.phoneInputNode.countryCodeTextUpdated = { [weak self] value in
            self?.countryCodeTextUpdated(value)
        }
        
        self.phoneInputNode.numberTextUpdated = { [weak self] value in
            self?.numberTextUpdated(value)
        }
        
        self.countryButton.addTarget(self, action: #selector(self.countryButtonPressed), forControlEvents: .touchUpInside)
    }
    
    override func update(item: SecureIdValueFormPhoneItem, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        if self.theme !== theme {
            self.countryButton.setBackgroundImage(countryButtonBackground(color: theme.list.itemBlocksBackgroundColor, separatorColor: theme.list.itemBlocksSeparatorColor), for: [])
            self.countryButton.setBackgroundImage(countryButtonHighlightedBackground(fillColor: theme.list.itemHighlightedBackgroundColor), for: .highlighted)
            self.theme = theme
            
            self.phoneInputNode.countryCodeField.textField.textColor = theme.list.itemPrimaryTextColor
            self.phoneInputNode.numberField.textField.textColor = theme.list.itemPrimaryTextColor
            
            self.phoneInputNode.countryCodeField.textField.tintColor = theme.list.itemAccentColor
            self.phoneInputNode.numberField.textField.tintColor = theme.list.itemAccentColor
            
            self.phoneInputNode.countryCodeField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
            self.phoneInputNode.numberField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        }
        
        self.item = item
        
        return (FormControllerItemPreLayout(aligningInset: 0.0), { params in
            transition.updateFrame(node: self.countryButton, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: 44.0 + 6.0)))
            
            let buttonTitle: NSAttributedString
            if item.countryName.isEmpty {
                buttonTitle = NSAttributedString(string: strings.Login_CountryCode, font: Font.regular(17.0), textColor: theme.list.itemSecondaryTextColor)
            } else {
                buttonTitle = NSAttributedString(string: item.countryName, font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
            }
            self.countryButton.setAttributedTitle(buttonTitle, for: [])
            
            self.countryButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 10.0, right: 0.0)
            self.countryButton.contentHorizontalAlignment = .left
            
            self.phoneInputNode.numberField.textField.attributedPlaceholder = NSAttributedString(string: strings.Login_PhonePlaceholder, font: Font.regular(17.0), textColor: theme.list.itemSecondaryTextColor)
            
            let countryCodeFrame = CGRect(origin: CGPoint(x: 12.0, y: 44.0 + 1.0), size: CGSize(width: 45.0, height: 44.0))
            let numberFrame = CGRect(origin: CGPoint(x: 70.0, y: 44.0 + 1.0), size: CGSize(width: width - 70.0 - 8.0, height: 44.0))
            
            let phoneInputFrame = countryCodeFrame.union(numberFrame)
            
            self.phoneInputNode.countryCodeText = item.countryCode
            self.phoneInputNode.numberText = item.number
            
            transition.updateFrame(node: self.phoneInputNode, frame: phoneInputFrame)
            transition.updateFrame(node: self.phoneInputNode.countryCodeField, frame: countryCodeFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
            transition.updateFrame(node: self.phoneInputNode.numberField, frame: numberFrame.offsetBy(dx: -phoneInputFrame.minX, dy: -phoneInputFrame.minY))
            
            return 88.0
        })
    }
    
    @objc private func countryButtonPressed() {
        self.item?.openCountrySelection()
    }
    
    private func countryCodeTextUpdated(_ value: String) {
        self.item?.updateCountryCode(value)
    }
    
    private func numberTextUpdated(_ value: String) {
        self.item?.updateNumber(value)
    }
    
    func activate() {
        self.phoneInputNode.numberField.becomeFirstResponder()
    }
}
