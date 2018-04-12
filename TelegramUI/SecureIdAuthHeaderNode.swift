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
    
    private let serviceAvatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    
    private var verificationState: SecureIdAuthControllerVerificationState?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.theme = theme
        self.strings = strings
        
        self.serviceAvatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.serviceAvatarNode)
        self.addSubnode(self.titleNode)
    }
    
    func updateState(formData: SecureIdEncryptedFormData, verificationState: SecureIdAuthControllerVerificationState) {
        self.serviceAvatarNode.setPeer(account: self.account, peer: formData.servicePeer)
        
        self.verificationState = verificationState
        
        let titleData = self.strings.SecureId_RequestTitle(formData.servicePeer.displayTitle)
        
        let titleString = NSMutableAttributedString()
        titleString.append(NSAttributedString(string: titleData.0, font: textFont, textColor: self.theme.list.freeTextColor))
        for (_, range) in titleData.1 {
            titleString.addAttribute(.font, value: titleFont, range: range)
        }
        self.titleNode.attributedText = titleString
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let avatarSize = CGSize(width: 70.0, height: 70.0)
        
        let serviceAvatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize.width) / 2.0), y: 0.0), size: avatarSize)
        transition.updateFrame(node: self.serviceAvatarNode, frame: serviceAvatarFrame)
        
        let avatarTitleSpacing: CGFloat = 20.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - 20.0, height: 1000.0))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: avatarSize.height + avatarTitleSpacing), size: titleSize)
        ContainedViewLayoutTransition.immediate.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let resultHeight: CGFloat = avatarSize.height + avatarTitleSpacing + titleSize.height
        return resultHeight
    }
}
