import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMessageSelectionInputPanelNode: ChatInputPanelNode {
    private let deleteButton: UIButton
    private let forwardButton: UIButton
    private let shareButton: UIButton
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var theme: PresentationTheme
    
    private let canDeleteMessagesDisposable = MetaDisposable()
    
    var selectedMessages = Set<MessageId>() {
        didSet {
            if oldValue != self.selectedMessages {
                self.forwardButton.isEnabled = self.selectedMessages.count != 0
                
                if self.selectedMessages.isEmpty {
                    self.canDeleteMessagesDisposable.set(nil)
                    self.deleteButton.isEnabled = false
                    self.shareButton.isEnabled = false
                } else if let account = self.account {
                    let isEmpty = self.selectedMessages.isEmpty
                    self.canDeleteMessagesDisposable.set((chatAvailableMessageActions(postbox: account.postbox, accountPeerId: account.peerId, messageIds: self.selectedMessages)
                        |> deliverOnMainQueue).start(next: { [weak self] actions in
                            if let strongSelf = self {
                                strongSelf.deleteButton.isEnabled = !actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty
                                strongSelf.shareButton.isEnabled = !actions.options.intersection([.forward]).isEmpty
                            }
                        }))
                }
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.deleteButton = UIButton()
        self.deleteButton.isEnabled = false
        self.forwardButton = UIButton()
        self.shareButton = UIButton()
        self.shareButton.isEnabled = false
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.shareButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.forwardButton)
        self.view.addSubview(self.shareButton)
        
        self.forwardButton.isEnabled = false
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), for: [.touchUpInside])
        self.shareButton.addTarget(self, action: #selector(self.shareButtonPressed), for: [.touchUpInside])
    }
    
    deinit {
        self.canDeleteMessagesDisposable.dispose()
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
            self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        }
    }
    
    @objc func deleteButtonPressed() {
        self.interfaceInteraction?.deleteSelectedMessages()
    }
    
    @objc func forwardButtonPressed() {
        self.interfaceInteraction?.forwardSelectedMessages()
    }
    
    @objc func shareButtonPressed() {
        self.interfaceInteraction?.shareSelectedMessages()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        self.deleteButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 53.0, height: 47.0))
        self.forwardButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 57.0, y: 0.0), size: CGSize(width: 57.0, height: 47.0))
        self.shareButton.frame = CGRect(origin: CGPoint(x: floor((width - rightInset - 57.0) / 2.0), y: 0.0), size: CGSize(width: 57.0, height: 47.0))
        
        return 47.0
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return 47.0
    }
}
