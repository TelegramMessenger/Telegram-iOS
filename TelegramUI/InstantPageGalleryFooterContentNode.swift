import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos

private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: .white)

private let textFont = Font.regular(16.0)

final class InstantPageGalleryFooterContentNode: GalleryFooterContentNode {
    private let account: Account
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var shareMedia: AnyMediaReference?
    
    private let actionButton: UIButton
    private let textNode: ASTextNode
    
    private var currentMessageText: String?
    
    init(account: Account, presentationData: PresentationData) {
        self.account = account
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.actionButton = UIButton()
        
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.textNode = ASTextNode()
        
        super.init()
        
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.textNode)
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
    }
    
    func setCaption(_ caption: String) {
        if self.currentMessageText != caption {
            self.currentMessageText = caption
            
            if caption.isEmpty {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = NSAttributedString(string: caption, font: textFont, textColor: .white)
            }
            
            self.requestLayout?(.immediate)
        }
    }
    
    func setShareMedia(_ shareMedia: AnyMediaReference?) {
        self.shareMedia = shareMedia
        self.actionButton.isHidden = shareMedia == nil
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var panelHeight: CGFloat = 44.0 + bottomInset + contentInset
        if !self.textNode.isHidden {
            let sideInset: CGFloat = leftInset + 8.0
            let topInset: CGFloat = 8.0
            let bottomInset: CGFloat = 8.0
            let textSize = self.textNode.measure(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            panelHeight += textSize.height + topInset + bottomInset
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: sideInset, y: topInset), size: textSize))
        }
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        return panelHeight
    }
    
    @objc func actionButtonPressed() {
        if let shareMedia = self.shareMedia {
            self.controllerInteraction?.presentController(ShareController(account: self.account, subject: .media(shareMedia), preferredAction: .saveToCameraRoll, showInChat: nil, externalShare: true, immediateExternalShare: false), nil)
        }
    }
}
