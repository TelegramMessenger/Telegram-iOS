import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos
import TelegramPresentationData
import TextFormat
import AccountContext
import ShareController
import GalleryUI
import AppBundle

private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: .white)

private let textFont = Font.regular(16.0)

final class InstantPageGalleryFooterContentNode: GalleryFooterContentNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var shareMedia: AnyMediaReference?
    
    private let actionButton: UIButton
    private let textNode: ImmediateTextNode
    
    private var currentMessageText: NSAttributedString?
    
    var openUrl: ((InstantPageUrlItem) -> Void)?
    var openUrlOptions: ((InstantPageUrlItem) -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.actionButton = UIButton()
        
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 10
        self.textNode.insets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        self.textNode.linkHighlightColor = UIColor(rgb: 0x5ac8fa, alpha: 0.2)
        
        super.init()
        
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.textNode.tapAttributeAction = { [weak self] attributes, _ in
            if let strongSelf = self, let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
                strongSelf.openUrl?(url)
            }
        }
        self.textNode.longTapAttributeAction = { [weak self] attributes, _ in
            if let strongSelf = self, let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
                strongSelf.openUrlOptions?(url)
            }
        }
        
        self.view.addSubview(self.actionButton)
        self.addSubnode(self.textNode)
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
    }
    
    func setCaption(_ caption: NSAttributedString, credit: NSAttributedString) {
        if self.currentMessageText != caption {
            self.currentMessageText = caption
            
            var attributedText: NSMutableAttributedString?
            if caption.length > 0 {
                attributedText = NSMutableAttributedString(attributedString: caption)
            }
           
            if credit.length > 0 {
                if attributedText != nil {
                    attributedText?.append(NSAttributedString(string: "\n"))
                    attributedText?.append(credit)
                } else {
                    attributedText = NSMutableAttributedString(attributedString: credit)
                }
            }
            
            if let attributedText = attributedText {
                self.textNode.isHidden = false
                self.textNode.attributedText = attributedText
            } else {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            }
            
            self.requestLayout?(.immediate)
        }
    }
    
    func setShareMedia(_ shareMedia: AnyMediaReference?) {
        self.shareMedia = shareMedia
        self.actionButton.isHidden = shareMedia == nil
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let width = size.width
        var panelHeight: CGFloat = 44.0 + bottomInset + contentInset
        if !self.textNode.isHidden {
            let sideInset: CGFloat = leftInset + 8.0
            let topInset: CGFloat = 0.0
            let bottomInset: CGFloat = 0.0
            let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            
            var x = sideInset
            if let hasRTL = self.textNode.cachedLayout?.hasRTL, hasRTL {
                x = width - rightInset - 8.0 - textSize.width
            }
            
            panelHeight += textSize.height + topInset + bottomInset
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: x, y: topInset), size: textSize))
        }
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        transition.animatePositionAdditive(node: self.textNode, offset: CGPoint(x: 0.0, y: self.bounds.height - fromHeight))
        self.textNode.alpha = 1.0
        self.actionButton.alpha = 1.0
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateFrame(node: self.textNode, frame: self.textNode.frame.offsetBy(dx: 0.0, dy: self.bounds.height - toHeight))
        self.textNode.alpha = 0.0
        self.actionButton.alpha = 0.0
        self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
            completion()
        })
    }
    
    @objc func actionButtonPressed() {
        if let shareMedia = self.shareMedia {
            self.controllerInteraction?.presentController(ShareController(context: self.context, subject: .media(shareMedia), preferredAction: .saveToCameraRoll, showInChat: nil, externalShare: true, immediateExternalShare: false), nil)
        }
    }
}
