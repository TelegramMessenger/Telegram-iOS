import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AppBundle
import AccountContext

private let avatarFont = avatarPlaceholderFont(size: 26.0)
private let titleFont = Font.semibold(14.0)
private let textFont = Font.regular(14.0)

final class SecureIdAuthHeaderNode: ASDisplayNode {
    private let context: AccountContext
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let nameDisplayOrder: PresentationPersonNameOrder
    
    private let serviceAvatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    
    private var verificationState: SecureIdAuthControllerVerificationState?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        
        self.serviceAvatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Secure ID/ViewPassportIcon"), color: theme.list.freeMonoIconColor)
        
        super.init()
        
        self.addSubnode(self.serviceAvatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
    }
    
    func updateState(formData: SecureIdEncryptedFormData?, verificationState: SecureIdAuthControllerVerificationState) {
        if let formData = formData {
            self.serviceAvatarNode.setPeer(context: self.context, theme: self.theme, peer: EnginePeer(formData.servicePeer))
            let titleData = self.strings.Passport_RequestHeader(EnginePeer(formData.servicePeer).displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder))
            
            let titleString = NSMutableAttributedString()
            titleString.append(NSAttributedString(string: titleData.string, font: textFont, textColor: self.theme.list.freeTextColor))
            for range in titleData.ranges {
                titleString.addAttribute(.font, value: titleFont, range: range.range)
            }
            self.titleNode.attributedText = titleString
            self.iconNode.isHidden = true
        } else {
            self.iconNode.isHidden = false
            self.titleNode.isHidden = true
            self.serviceAvatarNode.isHidden = true
        }
        
        self.verificationState = verificationState
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> (compact: CGFloat, expanded: CGFloat, apply: (Bool) -> Void) {
        if !self.iconNode.isHidden {
            guard let image = self.iconNode.image else {
                return (1.0, 1.0, { _ in
                    
                })
            }
            
            return (image.size.height, image.size.height, { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: floor((width - image.size.width) / 2.0), y: 0.0), size: image.size)
            })
        } else {
            let avatarSize = CGSize(width: 70.0, height: 70.0)
            
            let avatarTitleSpacing: CGFloat = 20.0
            
            let titleSize = self.titleNode.updateLayout(CGSize(width: width - 20.0, height: 1000.0))
            
            if let verificationState = self.verificationState, case .noChallenge = verificationState {
                self.serviceAvatarNode.isHidden = true
            } else {
                self.serviceAvatarNode.isHidden = false
            }
            
            var expandedHeight: CGFloat = titleSize.height
            if !self.serviceAvatarNode.isHidden {
                 expandedHeight += avatarSize.height + avatarTitleSpacing
            }
            let compactHeight = titleSize.height
            
            return (compactHeight, expandedHeight, { [weak self] expanded in
                guard let strongSelf = self else {
                    return
                }
                transition.updateAlpha(node: strongSelf.serviceAvatarNode, alpha: expanded ? 1.0 : 0.0)
                
                var titleOffset: CGFloat = 0.0
                if expanded && !strongSelf.serviceAvatarNode.isHidden && !strongSelf.serviceAvatarNode.alpha.isZero {
                    titleOffset = avatarSize.height + avatarTitleSpacing
                }
                
                let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: titleOffset), size: titleSize)
                let previousTitleFrame = strongSelf.titleNode.frame
                ContainedViewLayoutTransition.immediate.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                transition.animatePositionAdditive(node: strongSelf.titleNode, offset: CGPoint(x: 0.0, y: previousTitleFrame.midY - titleFrame.midY))
                
                let serviceAvatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize.width) / 2.0), y: titleFrame.minY - avatarTitleSpacing - avatarSize.height), size: avatarSize)
                transition.updateFrame(node: strongSelf.serviceAvatarNode, frame: serviceAvatarFrame)
            })
        }
    }
}
