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

private func titleAndColorForAction(_ action: SubscriberAction) -> (String, UIColor) {
    switch action {
        case .join:
            return ("Join", UIColor(0x1195f2))
        case .kicked:
            return ("Join", UIColor.gray)
        case .muteNotifications:
            return ("Mute", UIColor(0x1195f2))
        case .unmuteNotifications:
            return ("Unmute", UIColor(0x1195f2))
    }
}

private func actionForPeer(_ peer: Peer) -> SubscriberAction? {
    if let channel = peer as? TelegramChannel {
        switch channel.participationStatus {
            case .kicked:
                return .kicked
            case .left:
                return .join
            case .member:
                return .muteNotifications
        }
        return .join
    } else {
        return nil
    }
}

final class ChatChannelSubscriberInputPanelNode: ChatInputPanelNode {
    private let button: UIButton
    private let activityIndicator: UIActivityIndicatorView
    
    private var action: SubscriberAction?
    
    private let actionDisposable = MetaDisposable()
    
    override var peer: Peer? {
        didSet {
            if let peer = self.peer, oldValue == nil || !peer.isEqual(oldValue!) {
                if let action = actionForPeer(peer) {
                    self.action = action
                    let (title, color) = titleAndColorForAction(action)
                    self.button.setTitle(title, for: [])
                    self.button.setTitleColor(color, for: [.normal])
                    self.button.setTitleColor(color.withAlphaComponent(0.5), for: [.highlighted])
                    self.button.sizeToFit()
                    self.setNeedsLayout()
                } else {
                    self.action = nil
                }
            }
        }
    }
    
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
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let buttonSize = self.button.bounds.size
        self.button.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - buttonSize.width) / 2.0), y: floor((bounds.size.height - buttonSize.height) / 2.0)), size: buttonSize)
        
        //_activityIndicator.frame = CGRectMake(self.frame.size.width - _activityIndicator.frame.size.width - 12.0f, CGFloor((self.frame.size.height - _activityIndicator.frame.size.height) / 2.0f), _activityIndicator.frame.size.width, _activityIndicator.frame.size.height);
        let indicatorSize = self.activityIndicator.bounds.size
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: bounds.size.width - indicatorSize.width - 12.0, y: floor((bounds.size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        guard let account = self.account, let action = self.action, let peer = self.peer else {
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
                break
            case .unmuteNotifications:
                break
        }
    }
}
