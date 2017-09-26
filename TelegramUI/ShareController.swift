import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

private func canSendMessagesToPeer(_ peer: Peer) -> Bool {
    if peer is TelegramUser || peer is TelegramGroup {
        return true
    } else if let peer = peer as? TelegramSecretChat {
        return peer.embeddedState == .active
    } else if let peer = peer as? TelegramChannel {
        switch peer.info {
            case .broadcast:
                return peer.hasAdminRights(.canPostMessages)
            case .group:
                return true
        }
    } else {
        return false
    }
}

public struct ShareControllerAction {
    let title: String
    let action: () -> Void
}

public enum ShareControllerSubject {
    case url(String)
    case message(Message)
}

public final class ShareController: ViewController {
    private var controllerNode: ShareControllerNode {
        return self.displayNode as! ShareControllerNode
    }
    
    private var animatedIn = false
    
    private let account: Account
    private var presentationData: PresentationData
    private let externalShare: Bool
    private let subject: ShareControllerSubject
    
    private let peers = Promise<[Peer]>()
    private let peersDisposable = MetaDisposable()
    
    private var defaultAction: ShareControllerAction?
    
    public var dismissed: (() -> Void)?
    
    public init(account: Account, subject: ShareControllerSubject, saveToCameraRoll: Bool = false ,externalShare: Bool = true) {
        self.account = account
        self.externalShare = externalShare
        self.subject = subject
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarTheme: nil)
        
        switch subject {
            case let .url(text):
                self.defaultAction = ShareControllerAction(title: self.presentationData.strings.Web_CopyLink, action: { [weak self] in
                    UIPasteboard.general.string = text
                    self?.controllerNode.cancel?()
                })
            case let .message(message):
                if saveToCameraRoll {
                    self.defaultAction = ShareControllerAction(title: self.presentationData.strings.Preview_SaveToCameraRoll, action: { [weak self] in
                        self?.saveToCameraRoll(message)
                    })
                } else if let chatPeer = message.peers[message.id.peerId] as? TelegramChannel {
                    if message.id.namespace == Namespaces.Message.Cloud, let addressName = chatPeer.addressName, !addressName.isEmpty {
                        self.defaultAction = ShareControllerAction(title: self.presentationData.strings.Web_CopyLink, action: { [weak self] in
                            UIPasteboard.general.string = "https://t.me/\(addressName)/\(message.id.id)"
                            self?.controllerNode.cancel?()
                        })
                    }
                }
        }
        
        self.peers.set(account.viewTracker.tailChatListView(count: 150) |> take(1) |> map { view -> [Peer] in
            var peers: [Peer] = []
            for entry in view.0.entries.reversed() {
                switch entry {
                    case let .MessageEntry(_, message, _, _, _, renderedPeer, _):
                        if let peer = renderedPeer.chatMainPeer {
                            if canSendMessagesToPeer(peer) {
                                peers.append(peer)
                            }
                        }
                    default:
                        break
                }
            }
            return peers
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.peersDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ShareControllerNode(account: self.account, defaultAction: self.defaultAction, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, externalShare: self.externalShare)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            self?.dismissed?()
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.share = { [weak self] text, peerIds in
            if let strongSelf = self {
                switch strongSelf.subject {
                    case let .url(url):
                        for peerId in peerIds {
                            var messages: [EnqueueMessage] = []
                            if !text.isEmpty {
                                messages.append(.message(text: text, attributes: [], media: nil, replyToMessageId: nil))
                            }
                            messages.append(.message(text: url, attributes: [], media: nil, replyToMessageId: nil))
                            let _ = enqueueMessages(account: strongSelf.account, peerId: peerId, messages: messages).start()
                        }
                    case let .message(message):
                        for peerId in peerIds {
                            var messages: [EnqueueMessage] = []
                            if !text.isEmpty {
                                messages.append(.message(text: text, attributes: [], media: nil, replyToMessageId: nil))
                            }
                            messages.append(.forward(source: message.id))
                            let _ = enqueueMessages(account: strongSelf.account, peerId: peerId, messages: messages).start()
                        }
                }
            }
            return .complete()
        }
        self.controllerNode.shareExternal = { [weak self] in
            if let strongSelf = self {
                var activityItems: [Any] = []
                switch strongSelf.subject {
                    case let .url(text):
                        if let url = URL(string: text) {
                            activityItems.append(url)
                        }
                    case let .message(message):
                        if let chatPeer = message.peers[message.id.peerId] as? TelegramChannel {
                            if message.id.namespace == Namespaces.Message.Cloud, let addressName = chatPeer.addressName, !addressName.isEmpty {
                                if let url = URL(string: "https://t.me/\(addressName)/\(message.id.id)") {
                                    activityItems.append("https://t.me/\(addressName)/\(message.id.id)" as NSString)
                                }
                            }
                        }
                }
                let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                if let window = strongSelf.view.window {
                    let legacyController = LegacyController(presentation: .modal(animateIn: false))
                    let navigationController = UINavigationController()
                    legacyController.bind(controller: navigationController)
                    strongSelf.present(legacyController, in: .window(.root))
                    navigationController.present(activityController, animated: true, completion: nil)
                    /*window.rootViewController?.present(activityController, animated: true, completion: {
                        
                    })*/
                }
            }
        }
        self.displayNodeDidLoad()
        self.peersDisposable.set((self.peers.get() |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(peers: next, defaultAction: strongSelf.defaultAction)
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
        
        self.statusBar.removeFromSupernode()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func saveToCameraRoll(_ message: Message) {
        if let media = message.media.first {
            self.controllerNode.transitionToProgress(signal: TelegramUI.saveToCameraRoll(postbox: self.account.postbox, media: media))
        }
    }
}
