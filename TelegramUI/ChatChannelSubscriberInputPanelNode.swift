import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

private enum SubscriberAction {
    case join
    case kicked
    case muteNotifications
    case unmuteNotifications
}

private func titleAndColorForAction(_ action: SubscriberAction, theme: PresentationTheme, strings: PresentationStrings) -> (String, UIColor) {
    switch action {
        case .join:
            return (strings.Channel_JoinChannel, theme.chat.inputPanel.panelControlAccentColor)
        case .kicked:
            return (strings.Channel_JoinChannel, theme.chat.inputPanel.panelControlDisabledColor)
        case .muteNotifications:
            return (strings.Conversation_Mute, theme.chat.inputPanel.panelControlAccentColor)
        case .unmuteNotifications:
            return (strings.Conversation_Unmute, theme.chat.inputPanel.panelControlAccentColor)
    }
}

private func actionForPeer(peer: Peer, isMuted: Bool) -> SubscriberAction? {
    if let channel = peer as? TelegramChannel {
        switch channel.participationStatus {
            case .kicked:
                return .kicked
            case .left:
                return .join
            case .member:
                if isMuted {
                    return .unmuteNotifications
                } else {
                    return .muteNotifications
                }
        }
    } else {
        return nil
    }
}

final class ChatChannelSubscriberInputPanelNode: ChatInputPanelNode {
    private let button: UIButton
    private let activityIndicator: UIActivityIndicatorView
    
    private var action: SubscriberAction?
    
    private let actionDisposable = MetaDisposable()
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var layoutData: (CGFloat, CGFloat, CGFloat)?
    
    override init() {
        self.button = UIButton()
        self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.activityIndicator.isHidden = true
        
        super.init()
        
        self.view.addSubview(self.button)
        self.view.addSubview(self.activityIndicator)
        
        button.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        guard let account = self.account, let action = self.action, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        switch action {
            case .join:
                self.activityIndicator.isHidden = false
                self.activityIndicator.startAnimating()
                self.actionDisposable.set((joinChannel(account: account, peerId: peer.id)
                    |> afterDisposed { [weak self] in
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.activityIndicator.isHidden = true
                            strongSelf.activityIndicator.stopAnimating()
                        }
                    }
                }).start())
            case .kicked:
                break
            case .muteNotifications, .unmuteNotifications:
                if let account = self.account, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer {
                    self.actionDisposable.set(togglePeerMuted(account: account, peerId: peer.id).start())
                }
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        self.layoutData = (width, leftInset, rightInset)
        
        if self.presentationInterfaceState != interfaceState {
            let previousState = self.presentationInterfaceState
            self.presentationInterfaceState = interfaceState
            
            if let peer = interfaceState.renderedPeer?.peer, previousState?.renderedPeer?.peer == nil || !peer.isEqual(previousState!.renderedPeer!.peer!) || previousState?.theme !== interfaceState.theme || previousState?.strings !== interfaceState.strings || previousState?.peerIsMuted != interfaceState.peerIsMuted {
                if let action = actionForPeer(peer: peer, isMuted: interfaceState.peerIsMuted) {
                    self.action = action
                    let (title, color) = titleAndColorForAction(action, theme: interfaceState.theme, strings: interfaceState.strings)
                    self.button.setTitle(title, for: [])
                    self.button.setTitleColor(color, for: [.normal])
                    self.button.setTitleColor(color.withAlphaComponent(0.5), for: [.highlighted])
                    self.button.sizeToFit()
                } else {
                    self.action = nil
                }
            }
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        let buttonSize = self.button.bounds.size
        self.button.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        let indicatorSize = self.activityIndicator.bounds.size
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - rightInset - indicatorSize.width - 12.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
