import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import Photos
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import AccountContext
import GalleryUI
import AppBundle

private let deleteImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: .white)
private let actionImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: .white)

private let nameFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

enum AvatarGalleryItemFooterContent {
    case info
    case own(Bool)
}

final class AvatarGalleryItemFooterContentNode: GalleryFooterContentNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let deleteButton: UIButton
    private let actionButton: UIButton
    private let nameNode: ASTextNode
    private let dateNode: ASTextNode
    private let mainNode: ASTextNode
    private let setMainButton: HighlightableButtonNode
    
    private var currentNameText: String?
    private var currentDateText: String?
    private var currentTypeText: String?
    
    private var validLayout: (CGSize, LayoutMetrics, CGFloat, CGFloat, CGFloat, CGFloat)?
    
    var delete: (() -> Void)? {
        didSet {
            self.deleteButton.isHidden = self.delete == nil
        }
    }
    
    var share: ((GalleryControllerInteraction) -> Void)?
    
    var setMain: (() -> Void)?
    
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
        
        self.setMainButton = HighlightableButtonNode()
        self.setMainButton.isHidden = true
        
        self.mainNode = ASTextNode()
        self.mainNode.maximumNumberOfLines = 1
        self.mainNode.isUserInteractionEnabled = false
        self.mainNode.displaysAsynchronously = false
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.actionButton)
        
        self.addSubnode(self.nameNode)
        self.addSubnode(self.dateNode)
        self.addSubnode(self.setMainButton)
        self.addSubnode(self.mainNode)
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), for: [.touchUpInside])
        self.setMainButton.addTarget(self, action: #selector(self.setMainButtonPressed), forControlEvents: .touchUpInside)
    }
        
    func setEntry(_ entry: AvatarGalleryEntry, content: AvatarGalleryItemFooterContent) {
        var nameText: String?
        var dateText: String?
        var typeText: String?
        var buttonText: String?
        var canShare = true
        switch entry {
            case let .image(_, _, _, videoRepresentations, peer, date, _, _, _, _):
                nameText = peer.flatMap(EnginePeer.init)?.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder) ?? ""
                if let date = date {
                    dateText = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: date).string
                }
                
                if (!videoRepresentations.isEmpty) {
                    typeText = self.strings.ProfilePhoto_MainVideo
                    buttonText = self.strings.ProfilePhoto_SetMainVideo
                } else {
                    typeText = self.strings.ProfilePhoto_MainPhoto
                    buttonText = self.strings.ProfilePhoto_SetMainPhoto
                }
            
                if let peer = peer {
                    canShare = !peer.isCopyProtectionEnabled
                }
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
        
        if self.currentTypeText != typeText {
            self.currentTypeText = typeText
            
            self.mainNode.attributedText = NSAttributedString(string: typeText ?? "", font: Font.regular(17.0), textColor: UIColor(rgb: 0x808080))
            self.setMainButton.setAttributedTitle(NSAttributedString(string: buttonText ?? "", font: Font.regular(17.0), textColor: .white), for: .normal)
            
            if let validLayout = self.validLayout {
                let _ = self.updateLayout(size: validLayout.0, metrics: validLayout.1, leftInset: validLayout.2, rightInset: validLayout.3, bottomInset: validLayout.4, contentInset: validLayout.5, transition: .immediate)
            }
        }
        
        self.actionButton.isHidden = !canShare
        
        switch content {
            case .info:
                self.nameNode.isHidden = false
                self.dateNode.isHidden = false
                self.mainNode.isHidden = true
                self.setMainButton.isHidden = true
            case let .own(isMainPhoto):
                self.nameNode.isHidden = true
                self.dateNode.isHidden = true
                self.mainNode.isHidden = !isMainPhoto
                self.setMainButton.isHidden = isMainPhoto
        }
    }
    
    override func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (size, metrics, leftInset, rightInset, bottomInset, contentInset)
        
        let width = size.width
        var panelHeight: CGFloat = 44.0 + bottomInset
        panelHeight += contentInset
        
        self.actionButton.frame = CGRect(origin: CGPoint(x: leftInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        self.deleteButton.frame = CGRect(origin: CGPoint(x: width - 44.0 - rightInset, y: panelHeight - bottomInset - 44.0), size: CGSize(width: 44.0, height: 44.0))
        
        let constrainedSize = CGSize(width: width - 44.0 * 2.0 - 8.0 * 2.0 - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude)
        let nameSize = self.nameNode.measure(constrainedSize)
        let dateSize = self.dateNode.measure(constrainedSize)
        
        if nameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 0.0
            self.nameNode.frame = CGRect(origin: CGPoint(x: floor((width - nameSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - nameSize.height - labelsSpacing) / 2.0)), size: nameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((width - dateSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - dateSize.height - nameSize.height - labelsSpacing) / 2.0) + nameSize.height + labelsSpacing), size: dateSize)
        }
        
        let mainSize = self.mainNode.measure(constrainedSize)
        self.mainNode.frame = CGRect(origin: CGPoint(x: floor((width - mainSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - mainSize.height) / 2.0)), size: mainSize)
        
        let mainButtonSize = self.setMainButton.measure(constrainedSize)
        self.setMainButton.frame = CGRect(origin: CGPoint(x: floor((width - mainButtonSize.width) / 2.0), y: panelHeight - bottomInset - 44.0 + floor((44.0 - mainButtonSize.height) / 2.0)), size: mainButtonSize)
        
        return panelHeight
    }
    
    override func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
        self.deleteButton.alpha = 1.0
        self.actionButton.alpha = 1.0
        self.nameNode.alpha = 1.0
        self.dateNode.alpha = 1.0
        self.setMainButton.alpha = 1.0
    }
    
    override func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.deleteButton.alpha = 0.0
        self.actionButton.alpha = 0.0
        self.nameNode.alpha = 0.0
        self.dateNode.alpha = 0.0
        self.setMainButton.alpha = 0.0
        completion()
    }
    
    @objc private func deleteButtonPressed() {
        self.delete?()
    }
    
    @objc private func actionButtonPressed() {
        if let controllerInteraction = self.controllerInteraction {
            self.share?(controllerInteraction)
        }
    }
    
    @objc private func setMainButtonPressed() {
        self.setMain?()
    }
}
