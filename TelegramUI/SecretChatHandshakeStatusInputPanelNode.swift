import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class SecretChatHandshakeStatusInputPanelNode: ChatInputPanelNode {
    private let button: HighlightableButtonNode
    
    private var statusDisposable: Disposable?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.button = HighlightableButtonNode()
        self.button.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.button)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button.view
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.unblockPeer()
    }
    
    override func updateLayout(width: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
            
            if let peer = interfaceState.peer as? TelegramSecretChat {
                switch peer.embeddedState {
                    case .handshake:
                        self.button.setAttributedTitle(NSAttributedString(string: interfaceState.strings.Conversation_EncryptionProcessing, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.primaryTextColor), for: [])
                    case .active, .terminated:
                        break
                }
            }
        }
        
        let buttonSize = self.button.measure(CGSize(width: width - 10.0, height: 100.0))
        
        let panelHeight: CGFloat = 47.0
        
        self.button.frame = CGRect(origin: CGPoint(x: floor((width - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        return panelHeight
    }
}
