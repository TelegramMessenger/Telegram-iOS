#if DEBUG
    
import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramUI
    
private enum SnapshotPeerAvatar {
    case none
    case id(Int32)
}
    
private func avatarImages(_ postbox: Postbox, _ value: SnapshotPeerAvatar) -> [TelegramMediaImageRepresentation] {
    switch value {
        case .none:
            return []
        case let .id(id):
            return snapshotAvatar(postbox, id)
    }
}

private enum SnapshotPeer {
    case user(Int32, SnapshotPeerAvatar, String?, String?)
    case secretChat(Int32, Int32, SnapshotPeerAvatar, String?, String?)
    case channel(Int32, SnapshotPeerAvatar, String)
    
    func additionalPeer(_ postbox: Postbox) -> Peer? {
        switch self {
            case .user:
                return nil
            case let .secretChat(_, userId, avatar, first, last):
                return TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), accessHash: nil, firstName: first, lastName: last, username: nil, phone: nil, photo: avatarImages(postbox, avatar), botInfo: nil, restrictionInfo: nil, flags: [])
            case .channel:
                return nil
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .user(id, _, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudUser, id: id)
            case let .secretChat(id, _, _, _, _):
                return PeerId(namespace: Namespaces.Peer.SecretChat, id: id)
            case let .channel(id, _, _):
                return PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
        }
    }
    
    func peer(_ postbox: Postbox) -> Peer {
        switch self {
            case let .user(id, avatar, first, last):
                return TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: id), accessHash: nil, firstName: first, lastName: last, username: nil, phone: nil, photo: avatarImages(postbox, avatar), botInfo: nil, restrictionInfo: nil, flags: [])
            case let .secretChat(id, userId, _, _, _):
                return TelegramSecretChat(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: id), creationDate: 123, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), accessHash: 123, role: .creator, embeddedState: .active, messageAutoremoveTimeout: nil)
            case let .channel(id, avatar, title):
                return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: 123, title: title, username: nil, photo: avatarImages(postbox, avatar), creationDate: 123, version: 0, participationStatus: .member, info: .broadcast(TelegramChannelBroadcastInfo(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil)
        }
    }
}

private struct SnapshotMessage {
    let date: Int32
    let peer: SnapshotPeer
    let text: String
    let outgoing: Bool
    
    init(_ date: Int32, _ peer: SnapshotPeer, _ text: String, _ outgoing: Bool) {
        self.date = date
        self.peer = peer
        self.text = text
        self.outgoing = outgoing
    }
    
    func storeMessage(_ accountPeerId: PeerId, _ baseDate: Int32) -> StoreMessage {
        var flags: StoreMessageFlags = []
        if !self.outgoing {
            flags.insert(.Incoming)
        }
        return StoreMessage(id: MessageId(peerId: self.peer.peerId, namespace: Namespaces.Message.Cloud, id: self.date), globallyUniqueId: nil, groupingKey: nil, timestamp: baseDate + self.date, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: outgoing ? accountPeerId : self.peer.peerId, text: self.text, attributes: [], media: [])
    }
}

private struct SnapshotChat {
    let message: SnapshotMessage
    let unreadCount: Int32
    let isPinned: Bool
    let isMuted: Bool
    
    init(_ message: SnapshotMessage, unreadCount: Int32 = 0, isPinned: Bool = false, isMuted: Bool = false) {
        self.message = message
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
    }
}

private let chatList: [SnapshotChat] = [
    .init(.init(100, .user(1, .id(7), "Jane", ""), "Well I do help animals. Maybe I'll have a few cats in my new luxury apartment. 😊", false), isPinned: true),
    .init(.init(90, .user(3, .none, "Tyrion", "Lannister"), "Sometimes posession is an abstract concept. They took my purse, but the gold is still mine.", false), unreadCount: 1),
    .init(.init(80, .user(2, .id(1), "Alena", "Shy"), "😍 Sticker", true)),
    .init(.init(70, .secretChat(4, 4, .id(8), "Heisenberg", ""), "Thanks, Telegram helps me a lot. You have my financial support if you need more servers.", false)),
    .init(.init(60, .user(5, .id(9), "Bender", ""), "I looove new iPhones! In fact, they invited me to a focus group.", false)),
    .init(.init(50, .channel(6, .id(10), "World News Today"), "LaserBlastSafetyGuide.pdf", false), unreadCount: 1, isMuted: true),
    .init(.init(40, .user(7, .id(11), "EVE", ""), "LaserBlastSafetyGuide.pdf", true)),
    .init(.init(30, .user(8, .id(12), "Nick", ""), "It's impossible", false))
]

func snapshotChatList(application: UIApplication, mainWindow: UIWindow, window: Window1, statusBarHost: StatusBarHost) {
    let (context, _) = snapshotEnvironment(application: application, mainWindow: mainWindow, statusBarHost: statusBarHost, theme: .night)
    context.account.network.mockConnectionStatus = .online(proxyAddress: nil)
    
    let _ = (context.account.postbox.transaction { transaction -> Void in
        if let hole = context.account.postbox.seedConfiguration.initializeChatListWithHole.topLevel {
            transaction.replaceChatListHole(groupId: nil, index: hole.index, hole: nil)
        }
        
        let accountPeer = TelegramUser(id: context.account.peerId, accessHash: nil, firstName: "Alena", lastName: "Shy", username: "alenashy", phone: "44321456789", photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        transaction.updatePeersInternal([accountPeer], update: { _, updated in
            return updated
        })
        
        let baseDate: Int32 = Int32(Date().timeIntervalSince1970) - 10000
        for item in chatList {
            let peer = item.message.peer.peer(context.account.postbox)
            
            transaction.updatePeersInternal([peer], update: { _, updated in
                return updated
            })
            if let additionalPeer = item.message.peer.additionalPeer(context.account.postbox) {
                transaction.updatePeersInternal([additionalPeer], update: { _, updated in
                    return updated
                })
            }
            transaction.updatePeerChatListInclusion(peer.id, inclusion: .ifHasMessages)
            let _ = transaction.addMessages([item.message.storeMessage(context.account.peerId, baseDate)], location: .UpperHistoryBlock)
            transaction.resetIncomingReadStates([peer.id: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: Int32.max - 1, maxOutgoingReadId: Int32.max - 1, maxKnownId: Int32.max - 1, count: item.unreadCount, markedUnread: false)]])
            if item.isMuted {
                transaction.updateCurrentPeerNotificationSettings([peer.id: TelegramPeerNotificationSettings.defaultSettings.withUpdatedMuteState(.muted(until: Int32.max - 1))])
            } else {
                transaction.updateCurrentPeerNotificationSettings([peer.id: TelegramPeerNotificationSettings.defaultSettings])
            }
        }
        transaction.setPinnedItemIds(chatList.filter{ $0.isPinned }.map{ .peer($0.message.peer.peerId) })
    }).start()
    
    let rootController = TelegramRootController(context: context)
    rootController.addRootControllers(showCallsTab: true)
    window.viewController = rootController
    rootController.rootTabController!.selectedIndex = 0
    rootController.rootTabController!.selectedIndex = 2
}

#endif
