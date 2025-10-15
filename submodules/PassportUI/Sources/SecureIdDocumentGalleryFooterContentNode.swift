import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos
import TelegramPresentationData
import AccountContext
import GalleryUI
import AppBundle

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: .white)

private let textFont = Font.regular(16.0)
private let titleFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

final class SecureIdDocumentGalleryFooterContentNode: GalleryFooterContentNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let deleteButton: UIButton
    private let textNode: ASTextNode
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    
    private var currentDateText: String?
    private var currentMessageText: String?
    private var currentDocument: SecureIdVerificationDocument?
    
    var delete: (() -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        self.strings = strings
        
        self.deleteButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.authorNameNode = ASTextNode()
        self.authorNameNode.maximumNumberOfLines = 1
        self.authorNameNode.isUserInteractionEnabled = false
        self.authorNameNode.displaysAsynchronously = false
        self.dateNode = ASTextNode()
        self.dateNode.maximumNumberOfLines = 1
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.addSubnode(self.textNode)
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
    }
    
    deinit {
    }
    
    func setup(caption: String) {
        let dateText: String? = nil// = origin?.timestamp.flatMap { humanReadableStringForTimestamp(strings: self.strings, timeFormat: .regular, timestamp: $0) }
        
        if self.currentMessageText != caption || self.currentDateText != dateText {
            self.currentMessageText = caption
            
            if caption.isEmpty {
                self.textNode.isHidden = true
                self.textNode.attributedText = nil
            } else {
                self.textNode.isHidden = false
                self.textNode.attributedText = NSAttributedString(string: caption, font: textFont, textColor: UIColor(rgb: 0xcf3030))
            }
            
            self.authorNameNode.attributedText = nil
            if let dateText = dateText {
                self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            } else {
                self.dateNode.attributedText = nil
            }
            
            self.requestLayout?(.immediate)
        }
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let width = size.width
        var panelHeight: CGFloat = 44.0 + bottomInset
        panelHeight += contentInset
        if !self.textNode.isHidden {
            let sideInset: CGFloat = 8.0 + leftInset
            let topInset: CGFloat = 8.0
            let textBottomInset: CGFloat = 8.0 + contentInset
            let textSize = self.textNode.measure(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            panelHeight += textSize.height + topInset + textBottomInset
            self.textNode.frame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: textSize)
        }
        
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        if authorNameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 0.0
            self.authorNameNode.frame = CGRect(origin: CGPoint(x: floor((width - authorNameSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize)
        }
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        transition.animatePositionAdditive(node: self.textNode, offset: CGPoint(x: 0.0, y: self.bounds.size.height - fromHeight))
        self.textNode.alpha = 1.0
        self.dateNode.alpha = 1.0
        self.authorNameNode.alpha = 1.0
        self.deleteButton.alpha = 1.0
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateFrame(node: self.textNode, frame: self.textNode.frame.offsetBy(dx: 0.0, dy: self.bounds.height - toHeight))
        self.textNode.alpha = 0.0
        self.dateNode.alpha = 0.0
        self.authorNameNode.alpha = 0.0
        self.deleteButton.alpha = 0.0
        self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { _ in
            completion()
        })
    }
    
    @objc func deleteButtonPressed() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let items: [ActionSheetItem] = [
            ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                self?.delete?()
            })
        ]
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                                   ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                    ])
            ])
        self.controllerInteraction?.presentController(actionSheet, nil)
    }
}
