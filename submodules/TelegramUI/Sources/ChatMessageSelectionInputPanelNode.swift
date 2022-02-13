import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import ChatPresentationInterfaceState

final class ChatMessageSelectionInputPanelNode: ChatInputPanelNode {
    private let deleteButton: HighlightableButtonNode
    private let reportButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let shareButton: HighlightableButtonNode
    private let separatorNode: ASDisplayNode
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, metrics: LayoutMetrics, isSecondary: Bool)?
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    private var actions: ChatAvailableMessageActions?
    
    private var theme: PresentationTheme
    private let peerMedia: Bool
    
    private let canDeleteMessagesDisposable = MetaDisposable()
    
    var selectedMessages = Set<MessageId>() {
        didSet {
            if oldValue != self.selectedMessages {
                self.forwardButton.isEnabled = self.selectedMessages.count != 0
                
                if self.selectedMessages.isEmpty {
                    self.actions = nil
                    if let (width, leftInset, rightInset, additionalSideInsets, maxHeight, metrics, isSecondary) = self.validLayout, let interfaceState = self.presentationInterfaceState {
                        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: interfaceState, metrics: metrics)
                    }
                    self.canDeleteMessagesDisposable.set(nil)
                } else if let context = self.context {
                    self.canDeleteMessagesDisposable.set((context.sharedContext.chatAvailableMessageActions(postbox: context.account.postbox, accountPeerId: context.account.peerId, messageIds: self.selectedMessages)
                    |> deliverOnMainQueue).start(next: { [weak self] actions in
                        if let strongSelf = self {
                            strongSelf.actions = actions
                            if let (width, leftInset, rightInset, additionalSideInsets, maxHeight, metrics, isSecondary) = strongSelf.validLayout, let interfaceState = strongSelf.presentationInterfaceState {
                                let _ = strongSelf.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: interfaceState, metrics: metrics)
                            }
                        }
                    }))
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, peerMedia: Bool = false) {
        self.theme = theme
        self.peerMedia = peerMedia
        
        self.deleteButton = HighlightableButtonNode(pointerStyle: .default)
        self.deleteButton.isEnabled = false
        self.deleteButton.isAccessibilityElement = true
        self.deleteButton.accessibilityLabel = strings.VoiceOver_MessageContextDelete
        
        self.reportButton = HighlightableButtonNode(pointerStyle: .default)
        self.reportButton.isEnabled = false
        self.reportButton.isAccessibilityElement = true
        self.reportButton.accessibilityLabel = strings.VoiceOver_MessageContextReport
        
        self.forwardButton = HighlightableButtonNode(pointerStyle: .default)
        self.forwardButton.isAccessibilityElement = true
        self.forwardButton.accessibilityLabel = strings.VoiceOver_MessageContextForward
        
        self.shareButton = HighlightableButtonNode(pointerStyle: .default)
        self.shareButton.isAccessibilityElement = true
        self.shareButton.accessibilityLabel = strings.VoiceOver_MessageContextShare
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        
        super.init()
        
        self.addSubnode(self.deleteButton)
        self.addSubnode(self.reportButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.shareButton)
        self.addSubnode(self.separatorNode)
        
        self.forwardButton.isImplicitlyDisabled = true
        self.shareButton.isImplicitlyDisabled = true
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), forControlEvents: .touchUpInside)
        self.reportButton.addTarget(self, action: #selector(self.reportButtonPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), forControlEvents: .touchUpInside)
        self.shareButton.addTarget(self, action: #selector(self.shareButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.canDeleteMessagesDisposable.dispose()
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.reportButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionReport"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            
            self.separatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
        }
    }
    
    @objc func deleteButtonPressed() {
        self.interfaceInteraction?.deleteSelectedMessages()
    }
    
    @objc func reportButtonPressed() {
        self.interfaceInteraction?.reportSelectedMessages()
    }
    
    @objc func forwardButtonPressed() {
        if let _ = self.presentationInterfaceState?.renderedPeer?.peer as? TelegramSecretChat {
            return
        }
        if let actions = self.actions, actions.isCopyProtected {
            self.interfaceInteraction?.displayCopyProtectionTip(self.forwardButton, false)
        } else {
            self.interfaceInteraction?.forwardSelectedMessages()
        }
    }
    
    @objc func shareButtonPressed() {
        if let _ = self.presentationInterfaceState?.renderedPeer?.peer as? TelegramSecretChat {
            return
        }
        if let actions = self.actions, actions.isCopyProtected {
            self.interfaceInteraction?.displayCopyProtectionTip(self.shareButton, true)
        } else {
            self.interfaceInteraction?.shareSelectedMessages()
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, additionalSideInsets, maxHeight, metrics, isSecondary)
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        if let actions = self.actions {
            self.deleteButton.isEnabled = false
            self.reportButton.isEnabled = false
            self.forwardButton.isImplicitlyDisabled = !actions.options.contains(.forward)
            
            if self.peerMedia {
                self.deleteButton.isEnabled = !actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty
            } else {
                self.deleteButton.isEnabled = !actions.disableDelete
            }
            self.shareButton.isImplicitlyDisabled = actions.options.intersection([.forward]).isEmpty
            self.reportButton.isEnabled = !actions.options.intersection([.report]).isEmpty
            
            if self.peerMedia {
                self.deleteButton.isHidden = !self.deleteButton.isEnabled
            } else {
                self.deleteButton.isHidden = false
            }
            self.reportButton.isHidden = !self.reportButton.isEnabled
        } else {
            self.deleteButton.isEnabled = false
            self.deleteButton.isHidden = self.peerMedia
            self.reportButton.isEnabled = false
            self.reportButton.isHidden = true
            self.forwardButton.isImplicitlyDisabled = true
            self.shareButton.isImplicitlyDisabled = true
        }
        
        if self.reportButton.isHidden || (self.peerMedia && self.deleteButton.isHidden && self.reportButton.isHidden) {
            if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = peer.info {
                self.reportButton.isHidden = false
            } else if self.peerMedia {
                self.deleteButton.isHidden = false
            }
        }
        
        var width = width
        if additionalSideInsets.right > 0.0 {
            width -= additionalSideInsets.right
        }
        
        if self.reportButton.isHidden {
            self.deleteButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
            self.forwardButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 57.0, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
            self.shareButton.frame = CGRect(origin: CGPoint(x: floor((width - rightInset - 57.0) / 2.0), y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        } else if !self.deleteButton.isHidden {
            let buttons: [HighlightableButtonNode] = [
                self.deleteButton,
                self.reportButton,
                self.shareButton,
                self.forwardButton
            ]
            let buttonSize = CGSize(width: 57.0, height: panelHeight)
            
            let availableWidth = width - leftInset - rightInset
            let spacing: CGFloat = floor((availableWidth - buttonSize.width * CGFloat(buttons.count)) / CGFloat(buttons.count - 1))
            var offset: CGFloat = leftInset
            for i in 0 ..< buttons.count {
                let button = buttons[i]
                if i == buttons.count - 1 {
                    button.frame = CGRect(origin: CGPoint(x: width - rightInset - buttonSize.width, y: 0.0), size: buttonSize)
                } else {
                    button.frame = CGRect(origin: CGPoint(x: offset, y: 0.0), size: buttonSize)
                }
                offset += buttonSize.width + spacing
            }
        } else {
            self.deleteButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 53.0, height: panelHeight))
            self.forwardButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 57.0, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
            self.reportButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 53.0, height: 47.0))
            self.shareButton.frame = CGRect(origin: CGPoint(x: floor((width - rightInset - 57.0) / 2.0), y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        }
        
        transition.updateAlpha(node: self.separatorNode, alpha: isSecondary ? 1.0 : 0.0)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: panelHeight), size: CGSize(width: width, height: UIScreenPixel))
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
