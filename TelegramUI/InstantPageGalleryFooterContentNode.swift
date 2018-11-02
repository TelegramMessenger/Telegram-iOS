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
    private let textNode: ImmediateTextNode
    
    private var currentMessageText: NSAttributedString?
    
    var openUrl: ((InstantPageUrlItem) -> Void)?
    var openUrlOptions: ((InstantPageUrlItem) -> Void)?
    
    init(account: Account, presentationData: PresentationData) {
        self.account = account
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.actionButton = UIButton()
        
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 10
        self.textNode.insets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        self.textNode.linkHighlightColor = UIColor(white: 1.0, alpha: 0.4)
        
        super.init()
        
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.textNode.tapAttributeAction = { [weak self] attributes in
            if let strongSelf = self, let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
                strongSelf.openUrl?(url)
            }
        }
        self.textNode.longTapAttributeAction = { [weak self] attributes in
            if let strongSelf = self, let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
                strongSelf.openUrlOptions?(url)
            }
        }
        
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.textNode)
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
    }
    
    func setCaption(_ caption: NSAttributedString) {
        if self.currentMessageText != caption {
            self.currentMessageText = caption
            
            if caption.length == 0 {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = caption
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
            let topInset: CGFloat = 0.0
            let bottomInset: CGFloat = 0.0
            let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
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
