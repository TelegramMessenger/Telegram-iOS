import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let avatarFont: UIFont = UIFont(name: "ArialRoundedMTBold", size: 26.0)!
private let titleFont: UIFont = Font.semibold(16.0)
private let textFont: UIFont = Font.regular(16.0)

final class SecureIdAuthHeaderNode: ASDisplayNode {
    private let account: Account
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let accountAvatarContainerNode: ASDisplayNode
    private let accountAvatarNode: AvatarNode
    private let serviceAvatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var verificationState: SecureIdAuthControllerVerificationState?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.theme = theme
        self.strings = strings
        
        self.accountAvatarContainerNode = ASDisplayNode()
        self.accountAvatarNode = AvatarNode(font: avatarFont)
        self.serviceAvatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        
        super.init()
        
        self.accountAvatarContainerNode.addSubnode(self.accountAvatarNode)
        
        self.addSubnode(self.accountAvatarContainerNode)
        self.addSubnode(self.serviceAvatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    func updateState(formData: SecureIdEncryptedFormData, verificationState: SecureIdAuthControllerVerificationState) {
        self.accountAvatarNode.setPeer(account: self.account, peer: formData.accountPeer)
        self.serviceAvatarNode.setPeer(account: self.account, peer: formData.servicePeer)
        
        self.verificationState = verificationState
        
        self.titleNode.attributedText = NSAttributedString(string: self.strings.SecureId_RequestTitle(formData.servicePeer.displayTitle, formData.servicePeer.displayTitle).0, font: titleFont, textColor: self.theme.list.freeTextColor)
        
        var scopeText = ""
        for i in 0 ..< formData.form.requestedFields.count {
            if !scopeText.isEmpty {
                if i == formData.form.requestedFields.count - 1 {
                    scopeText.append(self.strings.SecureId_RequestScopeLastJoiner)
                } else {
                    scopeText.append(", ")
                }
            }
            switch formData.form.requestedFields[i] {
                case .identity:
                    scopeText.append(self.strings.SecureId_RequestScopeIdentity)
                case .address:
                    scopeText.append(self.strings.SecureId_RequestScopeAddress)
                case .phone:
                    scopeText.append(self.strings.SecureId_RequestScopePhone)
                case .email:
                    scopeText.append(self.strings.SecureId_RequestScopeEmail)
            }
        }
        
        self.textNode.attributedText = NSAttributedString(string: self.strings.SecureId_RequestText(scopeText).0, font: textFont, textColor: self.theme.list.freeTextColor)
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var isVerified = false
        if let verificationState = self.verificationState, case .verified = verificationState {
            isVerified = true
        }
        
        let avatarSize = CGSize(width: 70.0, height: 70.0)
        
        if isVerified {
            transition.updateAlpha(node: self.accountAvatarContainerNode, alpha: 0.0)
            transition.updateSublayerTransformScale(node: self.accountAvatarContainerNode, scale: 0.3)
            transition.updateFrame(node: self.accountAvatarNode, frame: CGRect(origin: CGPoint(), size: avatarSize))
            let serviceAvatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize.width) / 2.0), y: 0.0), size: avatarSize)
            transition.updateFrame(node: self.serviceAvatarNode, frame: serviceAvatarFrame)
            transition.updateFrame(node: self.accountAvatarContainerNode, frame: serviceAvatarFrame)
        } else {
            transition.updateAlpha(node: self.accountAvatarContainerNode, alpha: 1.0)
            transition.updateSublayerTransformScale(node: self.accountAvatarContainerNode, scale: 1.0)
            
            let avatarSeparation: CGFloat = 44.0
            let avatarsWidth = avatarSize.width * 2.0 + avatarSeparation
            
            transition.updateFrame(node: self.accountAvatarContainerNode, frame: CGRect(origin: CGPoint(x: floor((width - avatarsWidth) / 2.0), y: 0.0), size: avatarSize))
            transition.updateFrame(node: self.accountAvatarNode, frame: CGRect(origin: CGPoint(), size: avatarSize))
            transition.updateFrame(node: self.serviceAvatarNode, frame: CGRect(origin: CGPoint(x: floor((width - avatarsWidth) / 2.0 + avatarSize.width + avatarSeparation), y: 0.0), size: avatarSize))
        }
        
        let avatarTitleSpacing: CGFloat = 27.0
        let titleTextSpacing: CGFloat = 8.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - 20.0, height: 1000.0))
        let textSize = self.textNode.updateLayout(CGSize(width: width - 20.0, height: 1000.0))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: avatarSize.height + avatarTitleSpacing), size: titleSize)
        ContainedViewLayoutTransition.immediate.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: titleFrame.maxY + titleTextSpacing), size: textSize)
        ContainedViewLayoutTransition.immediate.updateFrame(node: self.textNode, frame: textFrame)
        
        var resultHeight: CGFloat = avatarSize.height + avatarTitleSpacing + titleSize.height
        if isVerified {
            transition.updateAlpha(node: self.textNode, alpha: 0.0)
        } else {
            transition.updateAlpha(node: self.textNode, alpha: 1.0)
            resultHeight += titleTextSpacing + textSize.height
        }
        
        return resultHeight
    }
}
