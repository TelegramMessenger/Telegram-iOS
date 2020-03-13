import SwiftSignalKit
import Postbox

private func accountRecordIdPathName(_ id: AccountRecordId) -> String {
    return "account-\(UInt64(bitPattern: id.int64))"
}

public let telegramPostboxSeedConfiguration: SeedConfiguration = {
    var messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]] = [:]
    for peerNamespace in peerIdNamespacesWithInitialCloudMessageHoles {
        messageHoles[peerNamespace] = [
            Namespaces.Message.Cloud: Set(MessageTags.all)
        ]
    }
    
    var globalMessageIdsPeerIdNamespaces = Set<GlobalMessageIdsNamespace>()
    for peerIdNamespace in [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup] {
        globalMessageIdsPeerIdNamespaces.insert(GlobalMessageIdsNamespace(peerIdNamespace: peerIdNamespace, messageIdNamespace: Namespaces.Message.Cloud))
    }
    
    return SeedConfiguration(globalMessageIdsPeerIdNamespaces: globalMessageIdsPeerIdNamespaces, initializeChatListWithHole: (topLevel: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1)), groups: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1))), messageHoles: messageHoles, existingMessageTags: MessageTags.all, messageTagsWithSummary: MessageTags.unseenPersonalMessage, existingGlobalMessageTags: GlobalMessageTags.all, peerNamespacesRequiringMessageTextIndex: [Namespaces.Peer.SecretChat], peerSummaryCounterTags: { peer, isContact in
        if let peer = peer as? TelegramUser {
            if peer.botInfo != nil {
                return .bot
            } else if isContact {
                return .contact
            } else {
                return .nonContact
            }
        } else if let _ = peer as? TelegramGroup {
            return .group
        } else if let _ = peer as? TelegramSecretChat {
            return .nonContact
        } else if let channel = peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                return .channel
            case .group:
                if channel.username != nil {
                    return .group
                } else {
                    return .group
                }
            }
        } else {
            assertionFailure()
            return .nonContact
        }
    }, additionalChatListIndexNamespace: Namespaces.Message.Cloud, messageNamespacesRequiringGroupStatsValidation: [Namespaces.Message.Cloud], defaultMessageNamespaceReadStates: [Namespaces.Message.Local: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false)], chatMessagesNamespaces: Set([Namespaces.Message.Cloud, Namespaces.Message.Local, Namespaces.Message.SecretIncoming]), globalNotificationSettingsPreferencesKey: PreferencesKeys.globalNotifications, defaultGlobalNotificationSettings: GlobalNotificationSettings.defaultSettings)
}()

public func accountTransaction<T>(rootPath: String, id: AccountRecordId, encryptionParameters: ValueBoxEncryptionParameters, transaction: @escaping (Transaction) -> T) -> Signal<T, NoError> {
    let path = "\(rootPath)/\(accountRecordIdPathName(id))"
    let postbox = openPostbox(basePath: path + "/postbox", seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryptionParameters)
    return postbox
    |> mapToSignal { value -> Signal<T, NoError> in
        switch value {
            case let .postbox(postbox):
                return postbox.transaction(transaction)
            default:
                return .complete()
        }
    }
}

