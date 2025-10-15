import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import LocalizedPeerData
import ChatPresentationInterfaceState
import ChatInputPanelNode
import ComponentFlow
import MultilineTextComponent
import GlassBackgroundComponent

final class SecretChatHandshakeStatusInputPanelNode: ChatInputPanelNode {
    private let titleBackground: GlassBackgroundView
    private let title = ComponentView<Empty>()
    private let button: HighlightableButtonNode
    
    private var statusDisposable: Disposable?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.button = HighlightableButtonNode()
        self.button.isUserInteractionEnabled = false
        self.button.titleNode.maximumNumberOfLines = 2
        self.button.titleNode.truncationMode = .byTruncatingMiddle
        
        self.titleBackground = GlassBackgroundView()
        
        super.init()
        
        self.addSubnode(self.button)
        self.button.view.addSubview(self.titleBackground)
        
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
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        self.presentationInterfaceState = interfaceState
        
        var text: String?
        
        if let renderedPeer = interfaceState.renderedPeer, let peer = renderedPeer.peer as? TelegramSecretChat, let userPeer = renderedPeer.peers[peer.regularPeerId] {
            switch peer.embeddedState {
            case .handshake:
                switch peer.role {
                case .creator:
                    text = interfaceState.strings.DialogList_AwaitingEncryption(EnginePeer(userPeer).compactDisplayTitle).string
                case .participant:
                    text = interfaceState.strings.Conversation_EncryptionProcessing
                }
            case .active, .terminated:
                break
            }
        }
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: text ?? " ", font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.primaryTextColor, paragraphAlignment: .center))
            )),
            environment: {},
            containerSize: CGSize(width: width - 16.0 * 2.0, height: 100.0)
        )
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        let backgroundSize = CGSize(width: titleSize.width + 16.0 * 2.0, height: 40.0)
        let backgroundFrame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - backgroundSize.width) * 0.5), y: floor((panelHeight - backgroundSize.height) / 2.0)), size: backgroundSize)
        transition.updateFrame(node: self.button, frame: backgroundFrame)
        transition.updateFrame(view: self.titleBackground, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        self.titleBackground.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: .immediate)
        let titleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - titleSize.width) * 0.5), y: floor((backgroundFrame.height - titleSize.height) * 0.5)), size: titleSize)
        if let titleView = self.title.view {
            if titleView.superview == nil {
                titleView.setMonochromaticEffect(tintColor: interfaceState.theme.chat.inputPanel.primaryTextColor)
                self.titleBackground.contentView.addSubview(titleView)
            }
            titleView.frame = titleFrame
        }
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
