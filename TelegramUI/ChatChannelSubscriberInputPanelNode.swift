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

private func actionForPeer(peer: Peer, muteState: PeerMuteState) -> SubscriberAction? {
    if let channel = peer as? TelegramChannel {
        switch channel.participationStatus {
            case .kicked:
                return .kicked
            case .left:
                return .join
            case .member:
                if case .unmuted = muteState {
                    return .muteNotifications
                } else {
                    return .unmuteNotifications
                }
        }
    } else {
        return nil
    }
}

final class ChatChannelSubscriberInputPanelNode: ChatInputPanelNode {
    private let button: UIButton
    private let activityIndicator: UIActivityIndicatorView
    
    private var muteState: PeerMuteState = .unmuted
    private var action: SubscriberAction?
    
    private let actionDisposable = MetaDisposable()
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var notificationSettingsDisposable = MetaDisposable()
    
    private var layoutData: CGFloat?
    
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
        self.notificationSettingsDisposable.dispose()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        guard let account = self.account, let action = self.action, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.peer else {
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
            case .muteNotifications:
                if let account = self.account, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.peer {
                    let muteState: PeerMuteState = .muted(until: Int32.max)
                    self.actionDisposable.set(changePeerNotificationSettings(account: account, peerId: peer.id, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.bundledModern(id: 0))).start())
                }
            case .unmuteNotifications:
                if let account = self.account, let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.peer {
                    let muteState: PeerMuteState = .unmuted
                    self.actionDisposable.set(changePeerNotificationSettings(account: account, peerId: peer.id, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.bundledModern(id: 0))).start())
                }
        }
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        self.layoutData = width
        
        if self.presentationInterfaceState != interfaceState {
            let previousState = self.presentationInterfaceState
            self.presentationInterfaceState = interfaceState
            
            if let peer = interfaceState.peer, previousState?.peer == nil || !peer.isEqual(previousState!.peer!) || previousState?.theme !== interfaceState.theme || previousState?.strings !== interfaceState.strings {
                if let action = actionForPeer(peer: peer, muteState: self.muteState) {
                    self.action = action
                    let (title, color) = titleAndColorForAction(action, theme: interfaceState.theme, strings: interfaceState.strings)
                    self.button.setTitle(title, for: [])
                    self.button.setTitleColor(color, for: [.normal])
                    self.button.setTitleColor(color.withAlphaComponent(0.5), for: [.highlighted])
                    self.button.sizeToFit()
                } else {
                    self.action = nil
                }
                
                if let account = self.account {
                    self.notificationSettingsDisposable.set((account.postbox.peerView(id: peer.id) |> map { view -> PeerMuteState in
                        if let notificationSettings = view.notificationSettings as? TelegramPeerNotificationSettings {
                            return notificationSettings.muteState
                        } else {
                            return .unmuted
                        }
                    }
                    |> distinctUntilChanged |> deliverOnMainQueue).start(next: { [weak self] muteState in
                        if let strongSelf = self, let presentationInterfaceState = strongSelf.presentationInterfaceState, let peer = presentationInterfaceState.peer {
                            strongSelf.muteState = muteState
                            let action = actionForPeer(peer: peer, muteState: muteState)
                            if let layoutData = strongSelf.layoutData, action != strongSelf.action {
                                strongSelf.action = action
                                if let action = action {
                                    let (title, color) = titleAndColorForAction(action, theme: presentationInterfaceState.theme, strings: presentationInterfaceState.strings)
                                    strongSelf.button.setTitle(title, for: [])
                                    strongSelf.button.setTitleColor(color, for: [.normal])
                                    strongSelf.button.setTitleColor(color.withAlphaComponent(0.5), for: [.highlighted])
                                    strongSelf.button.sizeToFit()
                                }
                                
                                let _ = strongSelf.updateLayout(width: layoutData, transition: .immediate, interfaceState: presentationInterfaceState)
                            }
                        }
                    }))
                }
            }
        }
        
        let panelHeight: CGFloat = 47.0
        
        let buttonSize = self.button.bounds.size
        self.button.frame = CGRect(origin: CGPoint(x: floor((width - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        let indicatorSize = self.activityIndicator.bounds.size
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - indicatorSize.width - 12.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return 47.0
    }
}
