import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

final class ChatMessageSelectionInputPanelNode: ChatInputPanelNode {
    private let deleteButton: UIButton
    private let forwardButton: UIButton
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var theme: PresentationTheme
    
    var selectedMessageCount: Int = 0 {
        didSet {
            self.deleteButton.isEnabled = self.selectedMessageCount != 0
            self.forwardButton.isEnabled = self.selectedMessageCount != 0
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.deleteButton = UIButton()
        self.forwardButton = UIButton()
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlAccentColor), for: [.normal])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: theme.chat.inputPanel.panelControlDisabledColor), for: [.disabled])
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.forwardButton)
        
        self.forwardButton.isEnabled = false
        self.deleteButton.isEnabled = false
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), for: [.touchUpInside])
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
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
            
            var canDelete = false
            if let channel = interfaceState.peer as? TelegramChannel {
                switch channel.info {
                    case .broadcast:
                        canDelete = channel.hasAdminRights(.canDeleteMessages)
                    case .group:
                        canDelete = channel.hasAdminRights(.canDeleteMessages)
                }
            } else {
                canDelete = true
            }
            self.deleteButton.isHidden = !canDelete
        }
        
        self.deleteButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: 53.0, height: 47.0))
        self.forwardButton.frame = CGRect(origin: CGPoint(x: width - 57.0, y: 0.0), size: CGSize(width: 57.0, height: 47.0))
        
        return 47.0
    }
}
