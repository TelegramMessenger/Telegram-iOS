import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle

private let titleFont = Font.regular(14.0)
private let buttonFont = Font.regular(17.0)

final class SecureIdAuthPasswordSetupContentNode: ASDisplayNode, SecureIdAuthContentNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let setupPassword: () -> Void
    
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let buttonTopSeparatorNode: ASDisplayNode
    private let buttonBackgroundNode: ASDisplayNode
    private let buttonBottomSeparatorNode: ASDisplayNode
    private let buttonHighlightedBackgroundNode: ASDisplayNode
    private let buttonTextNode: ImmediateTextNode
    private let buttonNode: HighlightableButtonNode
    
    private var currentPendingConfirmation = false
    private var validLayout: CGFloat?
    
    init(theme: PresentationTheme, strings: PresentationStrings, setupPassword: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.setupPassword = setupPassword
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Secure ID/EmptyPasswordIcon"), color: theme.list.freeMonoIconColor)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.attributedText = NSAttributedString(string: strings.Passport_PasswordDescription, font: Font.regular(14.0), textColor: theme.list.freeTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.buttonTopSeparatorNode = ASDisplayNode()
        self.buttonTopSeparatorNode.isLayerBacked = true
        self.buttonTopSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        self.buttonBottomSeparatorNode = ASDisplayNode()
        self.buttonBottomSeparatorNode.isLayerBacked = true
        self.buttonBottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        self.buttonBackgroundNode = ASDisplayNode()
        self.buttonBackgroundNode.isLayerBacked = true
        self.buttonBackgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.buttonHighlightedBackgroundNode = ASDisplayNode()
        self.buttonHighlightedBackgroundNode.isLayerBacked = true
        self.buttonHighlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.buttonHighlightedBackgroundNode.alpha = 0.0
        self.buttonTextNode = ImmediateTextNode()
        self.buttonTextNode.attributedText = NSAttributedString(string: strings.Passport_PasswordCreate, font: buttonFont, textColor: theme.list.itemAccentColor)
        self.buttonTextNode.maximumNumberOfLines = 1
        self.buttonTextNode.textAlignment = .center
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.buttonBackgroundNode)
        self.addSubnode(self.buttonTopSeparatorNode)
        self.addSubnode(self.buttonBottomSeparatorNode)
        self.addSubnode(self.buttonHighlightedBackgroundNode)
        self.addSubnode(self.buttonTextNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonHighlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonHighlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.buttonHighlightedBackgroundNode.alpha = 0.0
                    strongSelf.buttonHighlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updatePendingConfirmation(_ pendingConfirmation: Bool) {
        if pendingConfirmation != self.currentPendingConfirmation {
            self.currentPendingConfirmation = pendingConfirmation
        }
        if !pendingConfirmation {
            self.buttonTextNode.attributedText = NSAttributedString(string: self.strings.Passport_PasswordCreate, font: buttonFont, textColor: self.theme.list.itemAccentColor)
        } else {
            self.buttonTextNode.attributedText = NSAttributedString(string: self.strings.Passport_PasswordCompleteSetup, font: buttonFont, textColor: self.theme.list.itemAccentColor)
        }
        if let width = self.validLayout {
            let _ = self.updateLayout(width: width, transition: .immediate)
        }
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> SecureIdAuthContentLayout {
        let transition = self.validLayout == nil ? .immediate : transition
        self.validLayout = width
        
        var iconSize = self.iconNode.image?.size ?? CGSize()
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((width - iconSize.width) / 2.0), y: -50.0), size: iconSize))
        iconSize.height = max(0.0, iconSize.height - 100.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        
        let buttonTitleSize = self.buttonTextNode.updateLayout(CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        
        let buttonSize = CGSize(width: width, height: 44.0)
        
        let iconSpacing: CGFloat = 30.0
        let titleSpacing: CGFloat = 24.0
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: iconSize.height + iconSpacing), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let buttonFrame = CGRect(origin: CGPoint(x: 0.0, y: titleFrame.maxY + titleSpacing), size: buttonSize)
        
        transition.updateFrame(node: self.buttonTopSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: buttonFrame.minY), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateFrame(node: self.buttonBottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: buttonFrame.maxY - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonHighlightedBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonTextNode, frame: CGRect(origin: CGPoint(x: floor((buttonSize.width - buttonTitleSize.width) / 2.0), y: buttonFrame.minY + floor((buttonSize.height - buttonTitleSize.height) / 2.0)), size: buttonTitleSize))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        
        let contentHeight = buttonFrame.maxY
        
        return SecureIdAuthContentLayout(height: contentHeight, centerOffset: floor(contentHeight / 2.0))
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func didAppear() {
    }
    
    func willDisappear() {
    }
    
    @objc private func buttonPressed() {
        self.setupPassword()
    }
}
