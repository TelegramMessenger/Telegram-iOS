import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

final class ChatMessageSelectionInputPanelNode: ChatInputPanelNode {
    private let deleteButton: UIButton
    private let forwardButton: UIButton
    
    override var peer: Peer? {
        didSet {
            var canDelete = false
            if let channel = self.peer as? TelegramChannel {
                switch channel.info {
                    case .broadcast:
                        switch channel.role {
                            case .creator, .editor, .moderator:
                                canDelete = true
                            case .member:
                                canDelete = false
                        }
                    case .group:
                        switch channel.role {
                            case .creator, .editor, .moderator:
                                canDelete = true
                            case .member:
                                canDelete = false
                        }
                }
            } else {
                canDelete = true
            }
            self.deleteButton.isHidden = !canDelete
        }
    }
    
    var selectedMessageCount: Int = 0 {
        didSet {
            self.deleteButton.isEnabled = self.selectedMessageCount != 0
            self.forwardButton.isEnabled = self.selectedMessageCount != 0
        }
    }
    
    override init() {
        self.deleteButton = UIButton()
        self.forwardButton = UIButton()
        
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: UIColor(0x1195f2)), for: [.normal])
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: UIColor(0xdededf)), for: [.disabled])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: UIColor(0x1195f2)), for: [.normal])
        self.forwardButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionForward"), color: UIColor(0xdededf)), for: [.disabled])
        
        super.init()
        
        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.forwardButton)
        
        self.forwardButton.isEnabled = false
        self.deleteButton.isEnabled = false
        
        self.deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.forwardButton.addTarget(self, action: #selector(self.forwardButtonPressed), for: [.touchUpInside])
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.deleteButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: 53.0, height: 45.0))
        self.forwardButton.frame = CGRect(origin: CGPoint(x: bounds.size.width - 57.0, y: 0.0), size: CGSize(width: 57.0, height: 45.0))
    }
    
    @objc func deleteButtonPressed() {
        self.interfaceInteraction?.deleteSelectedMessages()
    }
    
    @objc func forwardButtonPressed() {
        self.interfaceInteraction?.forwardSelectedMessages()
    }
}
