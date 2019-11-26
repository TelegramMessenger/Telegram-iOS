import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Photos
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import AccountContext
import GalleryUI
import AppBundle

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: .white)

private let nameFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

final class AvatarGalleryItemFooterContentNode: GalleryFooterContentNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    private let nameNode: ASTextNode
    private let dateNode: ASTextNode
    
    private var currentNameText: String?
    private var currentDateText: String?
    
    var delete: (() -> Void)? {
        didSet {
            self.deleteButton.isHidden = self.delete == nil
        }
    }
    
    var share: ((GalleryControllerInteraction) -> Void)?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.deleteButton = UIButton()
        self.deleteButton.isHidden = true
        self.actionButton = UIButton()
        
        self.deleteButton.setImage(deleteImage, for: [.normal])
        self.actionButton.setImage(actionImage, for: [.normal])
        
        self.nameNode = ASTextNode()
        self.nameNode.maximumNumberOfLines = 1
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.displaysAsynchronously = false
        
        self.dateNode = ASTextNode()
        self.dateNode.maximumNumberOfLines = 1
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = false
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        
        self.addSubnode(self.nameNode)
        self.addSubnode(self.dateNode)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
    }
    
    deinit {
    }
    
    func setEntry(_ entry: AvatarGalleryEntry) {
        var nameText: String?
        var dateText: String?
        switch entry {
            case let .image(_, _, peer, date, _, _):
                nameText = peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
                dateText = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: date)
            default:
                break
        }
        
        if self.currentNameText != nameText || self.currentDateText != dateText {
            self.currentNameText = nameText
            self.currentDateText = dateText
            
            if let nameText = nameText {
                self.nameNode.attributedText = NSAttributedString(string: nameText, font: nameFont, textColor: .white)
            } else {
                self.nameNode.attributedText = nil
            }
            
            if let dateText = dateText {
                self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
            } else {
                self.dateNode.attributedText = nil
            }
        }
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let width = size.width
        var panelHeight: CGFloat = 44.0 + bottomInset
        panelHeight += contentInset
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let nameSize = self.nameNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        if nameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 0.0
            self.nameNode.frame = CGRect(origin: CGPoint(x: floor((width - nameSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - nameSize.height - labelsSpacing) / 2.0)), size: nameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - nameSize.height - labelsSpacing) / 2.0) + nameSize.height + labelsSpacing), size: dateSize)
        }
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        self.deleteButton.alpha = 1.0
        self.actionButton.alpha = 1.0
        self.nameNode.alpha = 1.0
        self.dateNode.alpha = 1.0
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.deleteButton.alpha = 0.0
        self.actionButton.alpha = 0.0
        self.nameNode.alpha = 0.0
        self.dateNode.alpha = 0.0
        completion()
    }
    
    @objc private func deleteButtonPressed() {
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
    
    @objc private func actionButtonPressed() {
        if let controllerInteraction = self.controllerInteraction {
            self.share?(controllerInteraction)
        }
    }
}
