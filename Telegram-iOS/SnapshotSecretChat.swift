#if DEBUG

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramUI
    
private enum SnapshotMessage {
    case text(String, Bool)
    case timer(Int32, Bool)
    
    func storeMessage(_ postbox: Postbox, peerId: PeerId, userPeerId: PeerId, accountPeerId: PeerId, _ date: Int32) -> StoreMessage {
        switch self {
            case let .text(text, outgoing):
                var flags: StoreMessageFlags = []
                if !outgoing {
                    flags.insert(.Incoming)
                }
                return StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: date), globallyUniqueId: nil, groupingKey: nil, timestamp: date, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: outgoing ? accountPeerId : userPeerId, text: text, attributes: [], media: [])
            case let .timer(timeout, outgoing):
                var flags: StoreMessageFlags = []
                if !outgoing {
                    flags.insert(.Incoming)
                }
                return StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: date), globallyUniqueId: nil, groupingKey: nil, timestamp: date, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: outgoing ? accountPeerId : userPeerId, text: "", attributes: [], media: [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(timeout))])
        }
    }
}
    
private let messages: [SnapshotMessage] = [
    .text("Hey Eileen", true),
    .text("So, why is Telegram cool?", true),
    .text("Well, look. Telegram is superfast and you can use it on all your devices at the same time — phones, tablets, even desktops.", false),
    .text("😴", true),
    .text("And it has secret chats, like this one, with end-to-end encryption!", false),
    .text("End encryption to what end??", true),
    .text("Arrgh. Forget it. You can set a timer and send photos that will disappear when the time runs out. Yay!", false),
    .timer(15, false)
]

func snapshotSecretChat(application: UIApplication, mainWindow: UIWindow, window: Window1, statusBarHost: StatusBarHost) {
    let (account, _) = snapshotEnvironment(application: application, mainWindow: mainWindow, statusBarHost: statusBarHost, theme: .night)
    account.network.mockConnectionStatus = .online(proxyAddress: nil)
    
    let accountPeer = TelegramUser(id: account.peerId, accessHash: nil, firstName: "Alena", lastName: "Shy", username: "alenashy", phone: "44321456789", photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
    let userPeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 456), accessHash: nil, firstName: "Eileen", lastName: "Lockhard", username: nil, phone: "44321456789", photo: snapshotAvatar(account.postbox, 6), botInfo: nil, restrictionInfo: nil, flags: [])
    let secretPeer = TelegramSecretChat(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: 456), creationDate: 123, regularPeerId: userPeer.id, accessHash: 123, role: .creator, embeddedState: .active, messageAutoremoveTimeout: nil)
    
    let _ = (account.postbox.transaction { transaction -> Void in
        if let hole = account.postbox.seedConfiguration.initializeChatListWithHole.topLevel {
            transaction.replaceChatListHole(groupId: nil, index: hole.index, hole: nil)
        }
        
        transaction.updatePeersInternal([accountPeer, userPeer, secretPeer], update: { _, updated in
            return updated
        })
        
        transaction.updatePeerPresencesInternal([userPeer.id: TelegramUserPresence(status: .present(until: Int32.max - 1))])
        
        var date: Int32 = Int32(Date().timeIntervalSince1970) - 1000
        for message in messages {
            let _ = transaction.addMessages([message.storeMessage(account.postbox, peerId: secretPeer.id, userPeerId: userPeer.id, accountPeerId: account.peerId, date)], location: .UpperHistoryBlock)
            date += 10
        }
    }).start()
    
    let rootController = TelegramRootController(account: account)
    rootController.addRootControllers(showCallsTab: true)
    window.viewController = rootController
    navigateToChatController(navigationController: rootController, account: account, chatLocation: .peer(secretPeer.id), animated: false)
}

#endif
