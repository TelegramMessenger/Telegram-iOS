import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import LocalizedPeerData
import ChatPresentationInterfaceState

final class SecretChatHandshakeStatusInputPanelNode: ChatInputPanelNode {
    private let button: HighlightableButtonNode
    
    private var statusDisposable: Disposable?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.button = HighlightableButtonNode()
        self.button.isUserInteractionEnabled = false
        self.button.titleNode.maximumNumberOfLines = 2
        self.button.titleNode.truncationMode = .byTruncatingMiddle
        
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
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
            
            if let renderedPeer = interfaceState.renderedPeer, let peer = renderedPeer.peer as? TelegramSecretChat, let userPeer = renderedPeer.peers[peer.regularPeerId] {
                switch peer.embeddedState {
                    case .handshake:
                        let text: String
                        switch peer.role {
                            case .creator:
                                text = interfaceState.strings.DialogList_AwaitingEncryption(EnginePeer(userPeer).compactDisplayTitle).string
                            case .participant:
                                text = interfaceState.strings.Conversation_EncryptionProcessing
                        }
                        self.button.setAttributedTitle(NSAttributedString(string: text, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.primaryTextColor, paragraphAlignment: .center), for: [])
                    case .active, .terminated:
                        break
                }
            }
        }
        
        let buttonSize = self.button.measure(CGSize(width: width - 10.0, height: 100.0))
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        self.button.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
