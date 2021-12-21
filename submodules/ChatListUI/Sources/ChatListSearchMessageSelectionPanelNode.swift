import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle

final class ChatListSearchMessageSelectionPanelNode: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    
    private let deleteMessages: () -> Void
    private let shareMessages: () -> Void
    private let forwardMessages: () -> Void
    private let displayCopyProtectionTip: (ASDisplayNode, Bool) -> Void
    
    private let separatorNode: ASDisplayNode
    private let backgroundNode: NavigationBackgroundNode
    private let deleteButton: HighlightableButtonNode
    private let forwardButton: HighlightableButtonNode
    private let shareButton: HighlightableButtonNode
    
    private var actions: ChatAvailableMessageActions?
    
    private let canDeleteMessagesDisposable = MetaDisposable()
    
    private var validLayout: ContainerViewLayout?
    
    var chatAvailableMessageActions: ((Set<MessageId>) -> Signal<ChatAvailableMessageActions, NoError>)?
    var selectedMessages = Set<MessageId>() {
        didSet {
            if oldValue != self.selectedMessages {
                self.forwardButton.isEnabled = self.selectedMessages.count != 0
                
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                if self.selectedMessages.isEmpty {
                    self.actions = nil
                    if let layout = self.validLayout {
                        let _ = self.update(layout: layout, presentationData: presentationData, transition: .immediate)
                    }
                    self.canDeleteMessagesDisposable.set(nil)
                } else {
                    if let chatAvailableMessageActions = self.chatAvailableMessageActions {
                        self.canDeleteMessagesDisposable.set((chatAvailableMessageActions(self.selectedMessages)
                        |> deliverOnMainQueue).start(next: { [weak self] actions in
                            if let strongSelf = self {
                                strongSelf.actions = actions
                                if let layout = strongSelf.validLayout {
                                    let _ = strongSelf.update(layout: layout, presentationData: presentationData, transition: .immediate)
                                }
                            }
                        }))
                    }
                }
            }
        }
    }
    
    init(context: AccountContext, deleteMessages: @escaping () -> Void, shareMessages: @escaping () -> Void, forwardMessages: @escaping () -> Void, displayCopyProtectionTip: @escaping (ASDisplayNode, Bool) -> Void) {
        self.context = context
        self.deleteMessages = deleteMessages
        self.shareMessages = shareMessages
        self.forwardMessages = forwardMessages
        self.displayCopyProtectionTip = displayCopyProtectionTip
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.theme = presentationData.theme
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.chat.inputPanel.panelSeparatorColor
        
        self.backgroundNode = NavigationBackgroundNode(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
        
        self.deleteButton = HighlightableButtonNode(pointerStyle: .default)
        self.deleteButton.isAccessibilityElement = true
        self.deleteButton.accessibilityLabel = presentationData.strings.VoiceOver_MessageContextDelete
        
        self.forwardButton = HighlightableButtonNode(pointerStyle: .default)
        self.forwardButton.isAccessibilityElement = true
        self.forwardButton.accessibilityLabel = presentationData.strings.VoiceOver_MessageContextForward
        
        self.shareButton = HighlightableButtonNode(pointerStyle: .default)
        self.shareButton.isAccessibilityElement = true
        self.shareButton.accessibilityLabel = presentationData.strings.VoiceOver_MessageContextShare
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: presentationData.theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: presentationData.theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: presentationData.theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
    
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.deleteButton)
        self.addSubnode(self.forwardButton)
        self.addSubnode(self.shareButton)
        self.addSubnode(self.separatorNode)
        
        self.deleteButton.isEnabled = false
        self.forwardButton.isImplicitlyDisabled = true
        self.shareButton.isImplicitlyDisabled = true
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), forControlEvents: .touchUpInside)
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), forControlEvents: .touchUpInside)
        self.shareButton.addTarget(self, action: #selector(self.shareButtonPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.canDeleteMessagesDisposable.dispose()
    }
    
    func update(layout: ContainerViewLayout, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        if presentationData.theme !== self.theme {
            self.theme = presentationData.theme
            
            self.backgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
            self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
            
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: presentationData.theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: presentationData.theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: presentationData.theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: presentationData.theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        }
       
        let width = layout.size.width
        let insets = layout.insets(options: [])
        let leftInset = insets.left + layout.safeInsets.left
        let rightInset = insets.right + layout.safeInsets.right
       
        let panelHeight: CGFloat
        if case .regular = layout.metrics.widthClass, case .regular = layout.metrics.heightClass {
            panelHeight = 49.0
        } else {
            panelHeight = 45.0
        }
        
        if let actions = self.actions {
            self.deleteButton.isEnabled = false
            self.forwardButton.isImplicitlyDisabled = !actions.options.contains(.forward)
            

            self.deleteButton.isEnabled = !actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty
            self.shareButton.isImplicitlyDisabled = actions.options.intersection([.forward]).isEmpty
        } else {
            self.deleteButton.isEnabled = false
            self.forwardButton.isImplicitlyDisabled = true
            self.shareButton.isImplicitlyDisabled = true
        }
        
        self.deleteButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        self.forwardButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 57.0, y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        self.shareButton.frame = CGRect(origin: CGPoint(x: floor((width - rightInset - 57.0) / 2.0), y: 0.0), size: CGSize(width: 57.0, height: panelHeight))
        
        let panelHeightWithInset = panelHeight + layout.intrinsicInsets.bottom
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: panelHeightWithInset)))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
    
        return panelHeightWithInset
    }
    
    @objc func deleteButtonPressed() {
        self.deleteMessages()
    }
    
    @objc func forwardButtonPressed() {
        if let actions = self.actions, actions.isCopyProtected {
            self.displayCopyProtectionTip(self.forwardButton, false)
        } else {
            self.forwardMessages()
        }
    }
    
    @objc func shareButtonPressed() {
        if let actions = self.actions, actions.isCopyProtected {
            self.displayCopyProtectionTip(self.shareButton, true)
        } else {
            self.shareMessages()
        }
    }
}
