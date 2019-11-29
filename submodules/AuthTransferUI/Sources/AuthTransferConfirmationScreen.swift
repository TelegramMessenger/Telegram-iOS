import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import AnimatedStickerNode
import TelegramPresentationData
import TelegramCore
import AccountContext

final class AuthTransferConfirmationNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let tokenInfo: AuthTransferTokenInfo

    private let containerNode: ASDisplayNode
    private let backgroundNode: ASImageNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let appNameNode: ImmediateTextNode
    private let locationInfoNode: ImmediateTextNode
    private let acceptButtonNode: SolidRoundedButtonNode
    private let cancelButtonNode: SolidRoundedButtonNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
  
    init(context: AccountContext, presentationData: PresentationData, tokenInfo: AuthTransferTokenInfo, accept: @escaping () -> Void, cancel: @escaping () -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.tokenInfo = tokenInfo
        
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 24.0, color: self.presentationData.theme.list.plainBackgroundColor)
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = UIImage(bundleImageName: "Settings/TransferAuthLaptop")
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.textAlignment = .center
        self.titleNode.maximumNumberOfLines = 2
        
        self.appNameNode = ImmediateTextNode()
        self.appNameNode.textAlignment = .center
        self.appNameNode.maximumNumberOfLines = 2
        
        self.locationInfoNode = ImmediateTextNode()
        self.locationInfoNode.textAlignment = .center
        self.locationInfoNode.maximumNumberOfLines = 0
        
        self.acceptButtonNode = SolidRoundedButtonNode(title: presentationData.strings.AuthSessions_AddDevice_ConfirmDevice, icon: nil, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemDestructiveColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.cancelButtonNode = SolidRoundedButtonNode(title: self.presentationData.strings.Common_Cancel, icon: nil, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.iconNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.appNameNode)
        self.containerNode.addSubnode(self.locationInfoNode)
        self.containerNode.addSubnode(self.acceptButtonNode)
        self.containerNode.addSubnode(self.cancelButtonNode)
    
        let titleFont = Font.bold(24.0)
        let subtitleFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        let seccondaryTextColor = self.presentationData.theme.list.itemSecondaryTextColor
        
        self.titleNode.attributedText = NSAttributedString(string: "\(tokenInfo.appName)", font: titleFont, textColor: textColor)
        
        self.appNameNode.attributedText = NSAttributedString(string: "\(tokenInfo.deviceModel), \(tokenInfo.platform) \(tokenInfo.systemVersion)", font: subtitleFont, textColor: seccondaryTextColor)
        
        self.locationInfoNode.attributedText = NSAttributedString(string: "\(tokenInfo.region)\nIP: \(tokenInfo.ip)", font: subtitleFont, textColor: seccondaryTextColor)
        
        self.acceptButtonNode.pressed = { [weak self] in
            accept()
        }
        self.cancelButtonNode.pressed = {
            cancel()
        }
    }

    override func didLoad() {
        super.didLoad()
    }
    
    func animateIn() {
        self.containerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: self.containerNode.bounds.height), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.containerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.containerNode.bounds.height), duration: 0.3, removeOnCompletion: false, additive: true, completion: { _ in
            completion()
        })
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [])
        let sideInset: CGFloat = 22.0
                
        let buttonSideInset: CGFloat = 16.0
        let bottomInset = insets.bottom + 10.0
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 20.0
        let contentButtonSpacing: CGFloat = 35.0
        let titleSpacing: CGFloat = 1.0
        let locationSpacing: CGFloat = 35.0
        let iconSpacing: CGFloat = 35.0
        let topInset: CGFloat = 35.0
        
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 10.0, height: 1.0)
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let appNameSize = self.appNameNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let locationSize = self.locationInfoNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        var contentHeight: CGFloat = 0.0
        contentHeight += topInset + iconSize.height
        contentHeight += iconSpacing + titleSize.height
        contentHeight += titleSpacing + appNameSize.height
        contentHeight += locationSpacing + locationSize.height
        contentHeight += contentButtonSpacing + bottomInset + buttonHeight + buttonSpacing + buttonHeight
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: topInset), size: iconSize)
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let appNameFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - appNameSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: appNameSize)
        transition.updateFrame(node: self.appNameNode, frame: appNameFrame)
        
        let locationFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - locationSize.width) / 2.0), y: appNameFrame.maxY + locationSpacing), size: locationSize)
        transition.updateFrame(node: self.locationInfoNode, frame: locationFrame)
        
        let cancelButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: contentHeight - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.cancelButtonNode, frame: cancelButtonFrame)
        self.cancelButtonNode.updateLayout(width: cancelButtonFrame.width, transition: transition)
        
        let acceptButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: cancelButtonFrame.minY - buttonSpacing - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.acceptButtonNode, frame: acceptButtonFrame)
        self.acceptButtonNode.updateLayout(width: acceptButtonFrame.width, transition: transition)
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - contentHeight), size: CGSize(width: layout.size.width, height: contentHeight)))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: contentHeight + 24.0)))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.cancelButtonNode.view.hitTest(self.view.convert(point, to: self.cancelButtonNode.view), with: event) {
            return result
        }
        if let result = self.acceptButtonNode.view.hitTest(self.view.convert(point, to: self.acceptButtonNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
