import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

final class TermsOfServiceControllerNode: ViewControllerTracingNode {
    private let theme: TermsOfServiceControllerTheme
    private let strings: PresentationStrings
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
    
    init(theme: TermsOfServiceControllerTheme, strings: PresentationStrings, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?, leftAction: @escaping () -> Void, rightAction: @escaping () -> Void, openUrl: @escaping (String) -> Void, present: @escaping (ViewController, Any?) -> Void, setToProcceedBot:@escaping(String)->Void) {
        self.theme = theme
        self.strings = strings
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
        self.contentTextNode.attributedText = stringWithAppliedEntities(text, entities: entities, baseColor: theme.primary, linkColor: theme.accent, baseFont: Font.regular(15.0), linkFont: Font.regular(15.0), boldFont: Font.semibold(15.0), italicFont: Font.italic(15.0), boldItalicFont: Font.semiboldItalic(15.0), fixedFont: Font.monospace(15.0), blockQuoteFont: Font.regular(15.0))
        
        self.toolbarNode = ASDisplayNode()
        self.toolbarSeparatorNode = ASDisplayNode()
        self.leftActionNode = HighlightableButtonNode()
        self.leftActionTextNode = ImmediateTextNode()
        self.leftActionTextNode.displaysAsynchronously = false
        self.leftActionTextNode.isUserInteractionEnabled = false
        self.leftActionTextNode.attributedText = NSAttributedString(string: self.strings.PrivacyPolicy_Decline, font: Font.regular(17.0), textColor: self.theme.accent)
        self.rightActionNode = HighlightableButtonNode()
        self.rightActionTextNode = ImmediateTextNode()
        self.rightActionTextNode.displaysAsynchronously = false
        self.rightActionTextNode.isUserInteractionEnabled = false
        self.rightActionTextNode.attributedText = NSAttributedString(string: self.strings.PrivacyPolicy_Accept, font: Font.semibold(17.0), textColor: self.theme.accent)
        
        super.init()
        
        self.backgroundColor = self.theme.listBackground
        self.toolbarNode.backgroundColor = self.theme.navigationBackground
        self.toolbarSeparatorNode.backgroundColor = self.theme.navigationSeparator
        
        self.contentBackgroundNode.backgroundColor = self.theme.itemBackground
        
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
        
        self.contentTextNode.linkHighlightColor = self.theme.accent.withAlphaComponent(0.5)
        self.contentTextNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)
            } else if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] {
                return NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)
            } else if let _ = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] {
                return NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        
        let showMentionActionSheet:(String) -> Void = { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            let theme: PresentationTheme = strongSelf.theme.presentationTheme
            let actionSheet = ActionSheetController(presentationTheme: theme)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: strongSelf.strings.Login_TermsOfService_ProceedBot(mention).0),
                ActionSheetButtonItem(title: strongSelf.strings.PrivacyPolicy_Accept, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    setToProcceedBot(mention)
                    rightAction()
                })
                ]), ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })])])
            strongSelf.present(actionSheet, nil)
        }
        
        self.contentTextNode.tapAttributeAction = { [weak self] attributes in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
                strongSelf.openUrl(url)
            } else if let mention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                showMentionActionSheet(mention.mention)
            } else if let mention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                showMentionActionSheet(mention)
            }
        }
        self.contentTextNode.longTapAttributeAction = { [weak self] attributes in
            guard let strongSelf = self else {
                return
            }
            if let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
                let theme: PresentationTheme = strongSelf.theme.presentationTheme
                let actionSheet = ActionSheetController(presentationTheme: theme)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: url),
                    ActionSheetButtonItem(title: strongSelf.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.openUrl(url)
                    }),
                    ActionSheetButtonItem(title: strongSelf.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        UIPasteboard.general.string = url
                    })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.present(actionSheet, nil)
            } else if let mention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                showMentionActionSheet(mention.mention)
            } else if let mention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
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
        let contentSize = self.contentTextNode.updateLayout(CGSize(width: layout.size.width - contentInsets.left, height: CGFloat.greatestFiniteMagnitude))
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
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
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
