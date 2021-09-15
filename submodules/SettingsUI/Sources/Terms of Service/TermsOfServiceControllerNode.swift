import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TextFormat
import UndoUI

final class TermsOfServiceControllerNode: ViewControllerTracingNode {
    private let presentationData: PresentationData
    private let text: String
    private let entities: [MessageTextEntity]
    private let ageConfirmation: Int32?
    private let leftAction: () -> Void
    private let rightAction: () -> Void
    private let openUrl: (String) -> Void
    private let present: (ViewController, Any?) -> Void
    
    private let scrollNode: ASScrollNode
    private let contentBackgroundNode: ASDisplayNode
    private let contentTextNode: ImmediateTextNode
    private let toolbarNode: ASDisplayNode
    private let toolbarSeparatorNode: ASDisplayNode
    private let leftActionNode: HighlightableButtonNode
    private let leftActionTextNode: ImmediateTextNode
    private let rightActionNode: HighlightableButtonNode
    private let rightActionTextNode: ImmediateTextNode
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress != oldValue {
                self.leftActionTextNode.alpha = self.inProgress ? 0.5 : 1.0
                self.rightActionTextNode.alpha = self.inProgress ? 0.5 : 1.0
                self.leftActionNode.isEnabled = !self.inProgress
                self.rightActionNode.isEnabled = !self.inProgress
            }
        }
    }
    
    init(presentationData: PresentationData, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?, leftAction: @escaping () -> Void, rightAction: @escaping () -> Void, openUrl: @escaping (String) -> Void, present: @escaping (ViewController, Any?) -> Void, setToProcceedBot:@escaping(String)->Void) {
        self.presentationData = presentationData
        self.text = text
        self.entities = entities
        self.ageConfirmation = ageConfirmation
        self.leftAction = leftAction
        self.rightAction = rightAction
        self.openUrl = openUrl
        self.present = present
        
        self.scrollNode = ASScrollNode()
        self.contentBackgroundNode = ASDisplayNode()
        self.contentTextNode = ImmediateTextNode()
        self.contentTextNode.displaysAsynchronously = false
        self.contentTextNode.maximumNumberOfLines = 0
        
        let fontSize = floor(presentationData.listsFontSize.baseDisplaySize * 15.0 / 17.0)
        
        self.contentTextNode.attributedText = stringWithAppliedEntities(text, entities: entities, baseColor: presentationData.theme.list.itemPrimaryTextColor, linkColor: presentationData.theme.list.itemAccentColor, baseFont: Font.regular(fontSize), linkFont: Font.regular(fontSize), boldFont: Font.semibold(fontSize), italicFont: Font.italic(fontSize), boldItalicFont: Font.semiboldItalic(fontSize), fixedFont: Font.monospace(fontSize), blockQuoteFont: Font.regular(fontSize))
        
        self.toolbarNode = ASDisplayNode()
        self.toolbarSeparatorNode = ASDisplayNode()
        self.leftActionNode = HighlightableButtonNode()
        self.leftActionTextNode = ImmediateTextNode()
        self.leftActionTextNode.displaysAsynchronously = false
        self.leftActionTextNode.isUserInteractionEnabled = false
        self.leftActionTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.PrivacyPolicy_Decline, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: self.presentationData.theme.list.itemAccentColor)
        self.rightActionNode = HighlightableButtonNode()
        self.rightActionTextNode = ImmediateTextNode()
        self.rightActionTextNode.displaysAsynchronously = false
        self.rightActionTextNode.isUserInteractionEnabled = false
        self.rightActionTextNode.attributedText = NSAttributedString(string: self.presentationData.strings.PrivacyPolicy_Accept, font: Font.semibold(presentationData.listsFontSize.baseDisplaySize), textColor: self.presentationData.theme.list.itemAccentColor)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.toolbarNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        self.toolbarSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.contentBackgroundNode.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.contentBackgroundNode)
        self.scrollNode.addSubnode(self.contentTextNode)
        self.addSubnode(self.toolbarNode)
        self.addSubnode(self.toolbarSeparatorNode)
        self.addSubnode(self.leftActionTextNode)
        self.addSubnode(self.leftActionNode)
        self.addSubnode(self.rightActionTextNode)
        self.addSubnode(self.rightActionNode)
        
        self.leftActionNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.leftActionTextNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.leftActionTextNode.alpha = 0.4
            } else {
                strongSelf.leftActionTextNode.alpha = 1.0
                strongSelf.leftActionTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.rightActionNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.rightActionTextNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.rightActionTextNode.alpha = 0.4
            } else {
                strongSelf.rightActionTextNode.alpha = 1.0
                strongSelf.rightActionTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.leftActionNode.addTarget(self, action: #selector(self.leftActionPressed), forControlEvents: .touchUpInside)
        self.rightActionNode.addTarget(self, action: #selector(self.rightActionPressed), forControlEvents: .touchUpInside)
        
        self.contentTextNode.linkHighlightColor = self.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.5)
        self.contentTextNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        
        let showMentionActionSheet:(String) -> Void = { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: strongSelf.presentationData.strings.Login_TermsOfService_ProceedBot(mention).string),
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.PrivacyPolicy_Accept, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    setToProcceedBot(mention)
                    rightAction()
                })
            ]), ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })])])
            strongSelf.present(actionSheet, nil)
        }
        
        self.contentTextNode.tapAttributeAction = { [weak self] attributes, _ in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                strongSelf.openUrl(url)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                showMentionActionSheet(mention.mention)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                showMentionActionSheet(mention)
            }
        }
        self.contentTextNode.longTapAttributeAction = { [weak self] attributes, _ in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: url),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.openUrl(url)
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet, weak self] in
                        actionSheet?.dismissAnimated()
                        UIPasteboard.general.string = url
                        
                        if let strongSelf = self {
                            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .linkCopied(text: strongSelf.presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                        }
                    })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.present(actionSheet, nil)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                showMentionActionSheet(mention.mention)
            } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                showMentionActionSheet(mention)
            }
        }
    }
    
    deinit {
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [])
        insets.top += navigationBarHeight
        
        let toolbarHeight: CGFloat = 44.0
        insets.bottom += layout.safeInsets.bottom
        
        let toolbarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - toolbarHeight), size: CGSize(width: layout.size.width, height: insets.bottom + toolbarHeight))
        
        insets.bottom += toolbarHeight
        
        transition.updateFrame(node: self.toolbarNode, frame: toolbarFrame)
        transition.updateFrame(node: self.toolbarSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: toolbarFrame.minY), size: CGSize(width: toolbarFrame.width, height: UIScreenPixel)))
        
        let leftActionSize = self.leftActionTextNode.updateLayout(CGSize(width: floor(layout.size.width / 2.0), height: CGFloat.greatestFiniteMagnitude))
        let rightActionSize = self.rightActionTextNode.updateLayout(CGSize(width: floor(layout.size.width / 2.0), height: CGFloat.greatestFiniteMagnitude))
        let leftActionTextFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left + 15.0, y: toolbarFrame.minY + floor((toolbarHeight - leftActionSize.height) / 2.0)), size: leftActionSize)
        let rightActionTextFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - 15.0 - rightActionSize.width, y: toolbarFrame.minY + floor((toolbarHeight - rightActionSize.height) / 2.0)), size: rightActionSize)
        transition.updateFrame(node: self.leftActionTextNode, frame: leftActionTextFrame)
        transition.updateFrame(node: self.rightActionTextNode, frame: rightActionTextFrame)
        self.leftActionNode.frame = CGRect(origin: CGPoint(x: 0.0, y: toolbarFrame.minY), size: CGSize(width: leftActionTextFrame.maxX + 15.0, height: toolbarHeight))
        self.rightActionNode.frame = CGRect(origin: CGPoint(x: rightActionTextFrame.minX - 15.0, y: toolbarFrame.minY), size: CGSize(width: layout.size.width - (rightActionTextFrame.minX - 15.0), height: toolbarHeight))
        
        let scrollFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom))
        transition.updateFrame(node: self.scrollNode, frame: scrollFrame)
        
        let containerInset: CGFloat = 32.0
        let contentInsets = UIEdgeInsets(top: 15.0, left: 15.0 + layout.safeInsets.left, bottom: 15.0, right: 15.0 + layout.safeInsets.right)
        let contentSize = self.contentTextNode.updateLayout(CGSize(width: layout.size.width - contentInsets.left - contentInsets.right, height: CGFloat.greatestFiniteMagnitude))
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: layout.size.width, height: contentSize.height + contentInsets.top + contentInsets.bottom))
        self.contentTextNode.frame = CGRect(origin: CGPoint(x: contentFrame.minX + contentInsets.left, y: contentFrame.minY + contentInsets.top), size: contentSize)
        self.contentBackgroundNode.frame = contentFrame
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: containerInset + contentFrame.height + containerInset)
    }
    
    func scrollToTop() {
        self.scrollNode.view.scrollRectToVisible(CGRect(origin: CGPoint(), size: CGSize()), animated: true)
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    @objc private func leftActionPressed() {
        self.leftAction()
    }
    
    @objc private func rightActionPressed() {
        self.rightAction()
    }
}
