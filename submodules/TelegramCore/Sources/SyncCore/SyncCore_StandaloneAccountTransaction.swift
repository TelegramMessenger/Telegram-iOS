import Foundation
import SwiftSignalKit
import Postbox

public let telegramPostboxSeedConfiguration: SeedConfiguration = {
    var messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]] = [:]
    for peerNamespace in peerIdNamespacesWithInitialCloudMessageHoles {
        messageHoles[peerNamespace] = [
            Namespaces.Message.Cloud: Set(MessageTags.all)
        ]
    }
    
    var messageThreadHoles: [PeerId.Namespace: [MessageId.Namespace]] = [:]
    for peerNamespace in peerIdNamespacesWithInitialCloudMessageHoles {
        messageThreadHoles[peerNamespace] = [
            Namespaces.Message.Cloud
        ]
    }
    
    // To avoid upgrading the database, **new** tags can be added here
    // Uninitialized peers will fill the info using messageHoles
    var upgradedMessageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]] = [:]
    for peerNamespace in peerIdNamespacesWithInitialCloudMessageHoles {
        upgradedMessageHoles[peerNamespace] = [
            Namespaces.Message.Cloud: Set([
                MessageTags.gif,
                MessageTags.pinned
            ])
        ]
    }
    
    var globalMessageIdsPeerIdNamespaces = Set<GlobalMessageIdsNamespace>()
    for peerIdNamespace in [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup] {
        globalMessageIdsPeerIdNamespaces.insert(GlobalMessageIdsNamespace(peerIdNamespace: peerIdNamespace, messageIdNamespace: Namespaces.Message.Cloud))
    }
    
    return SeedConfiguration(
        globalMessageIdsPeerIdNamespaces: globalMessageIdsPeerIdNamespaces,
        initializeChatListWithHole: (
            topLevel: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1)),
            groups: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1))
        ),
        messageHoles: messageHoles,
        upgradedMessageHoles: upgradedMessageHoles,
        messageThreadHoles: messageThreadHoles,
        existingMessageTags: MessageTags.all,
        messageTagsWithSummary: [.unseenPersonalMessage, .pinned, .video, .photo, .gif, .music, .voiceOrInstantVideo, .webPage, .file, .unseenReaction],
        messageTagsWithThreadSummary: [.unseenPersonalMessage, .unseenReaction],
        existingGlobalMessageTags: GlobalMessageTags.all,
        peerNamespacesRequiringMessageTextIndex: [Namespaces.Peer.SecretChat],
        peerSummaryCounterTags: { peer, isContact in
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
                    return .group
                }
            } else {
                assertionFailure()
                return .nonContact
            }
        },
        peerSummaryIsThreadBased: { peer, associatedPeer in
            if let channel = peer as? TelegramChannel {
                if channel.flags.contains(.isForum) {
                    if channel.flags.contains(.displayForumAsTabs) {
                        return (false, false)
                    } else {
                        return (true, false)
                    }
                } else if channel.flags.contains(.isMonoforum) {
                    if let associatedPeer = associatedPeer as? TelegramChannel, associatedPeer.hasPermission(.sendSomething) {
                        return (true, true)
                    } else {
                        return (false, false)
                    }
                } else {
                    return (false, false)
                }
            } else {
                return (false, false)
            }
        },
        additionalChatListIndexNamespace: Namespaces.Message.Cloud,
        messageNamespacesRequiringGroupStatsValidation: [Namespaces.Message.Cloud],
        defaultMessageNamespaceReadStates: [Namespaces.Message.Local: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false)],
        chatMessagesNamespaces: Set([Namespaces.Message.Cloud, Namespaces.Message.Local, Namespaces.Message.SecretIncoming]),
        getGlobalNotificationSettings: { transaction -> PostboxGlobalNotificationSettings? in
            (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications)?.get(GlobalNotificationSettings.self)).flatMap { settings in
                return PostboxGlobalNotificationSettings(defaultIncludePeer: { peer in
                    return settings.defaultIncludePeer(peer: peer)
                })
            }
        },
        defaultGlobalNotificationSettings: PostboxGlobalNotificationSettings(defaultIncludePeer: { peer in
            return GlobalNotificationSettings.defaultSettings.defaultIncludePeer(peer: peer)
        }),
        mergeMessageAttributes: { previous, updated in
            if previous.isEmpty {
                return
            }
            var audioTranscription: AudioTranscriptionMessageAttribute?
            for attribute in previous {
                if let attribute = attribute as? AudioTranscriptionMessageAttribute {
                    audioTranscription = attribute
                    break
                }
            }
            var previousDerivedData: DerivedDataMessageAttribute?
            for attribute in previous {
                if let attribute = attribute as? DerivedDataMessageAttribute {
                    previousDerivedData = attribute
                    break
                }
            }
            
            if let audioTranscription = audioTranscription {
                var found = false
                for i in 0 ..< updated.count {
                    if let attribute = updated[i] as? AudioTranscriptionMessageAttribute {
                        updated[i] = attribute.merge(withPrevious: audioTranscription)
                        found = true
                        break
                    }
                }
                if !found {
                    updated.append(audioTranscription)
                }
            }
            if let previousDerivedData {
                var found = false
                for i in 0 ..< updated.count {
                    if let _ = updated[i] as? DerivedDataMessageAttribute {
                        found = true
                        break
                    }
                }
                if !found {
                    updated.append(previousDerivedData)
                }
            }
        },
        decodeMessageThreadInfo: { entry in
            guard let data = entry.get(MessageHistoryThreadData.self) else {
                return nil
            }
            return Message.AssociatedThreadInfo(title: data.info.title, icon: data.info.icon, iconColor: data.info.iconColor, isClosed: data.isClosed)
        },
        decodeAutoremoveTimeout: { cachedData in
            if let cachedData = cachedData as? CachedUserData {
                if case let .known(value) = cachedData.autoremoveTimeout {
                    return value?.effectiveValue
                }
            } else if let cachedData = cachedData as? CachedGroupData {
                if case let .known(value) = cachedData.autoremoveTimeout {
                    return value?.effectiveValue
                }
            } else if let cachedData = cachedData as? CachedChannelData {
                if case let .known(value) = cachedData.autoremoveTimeout {
                    return value?.effectiveValue
                }
            }
            return nil
        },
        decodeDisplayPeerAsRegularChat: { cachedData in
            if let cachedData = cachedData as? CachedChannelData {
                if case let .known(value) = cachedData.viewForumAsMessages {
                    return value
                }
            }
            return false
        },
        isPeerUpgradeMessage: { message in
            for media in message.media {
                if let action = media as? TelegramMediaAction {
                    switch action.action {
                    case .groupMigratedToChannel, .channelMigratedFromGroup:
                        return true
                    default:
                        break
                    }
                }
            }
            return false
        },
        automaticThreadIndexInfo: { peerId, _ in
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return StoredMessageHistoryThreadInfo(data: CodableEntry(data: Data()), summary: StoredMessageHistoryThreadInfo.Summary(totalUnreadCount: 0, isMarkedUnread: false, mutedUntil: nil, maxOutgoingReadId: 0))
            } else {
                return nil
            }
        },
        customTagsFromAttributes: { attributes in
            var isTags = false
            
            for attribute in attributes {
                if let attribute = attribute as? PendingReactionsMessageAttribute, attribute.isTags {
                    isTags = true
                    break
                } else if let attribute = attribute as? ReactionsMessageAttribute, attribute.isTags {
                    isTags = true
                    break
                }
            }
            
            if !isTags {
                return []
            }
            
            guard let reactions = mergedMessageReactions(attributes: attributes, isTags: isTags), !reactions.reactions.isEmpty else {
                return []
            }
            
            var result: [MemoryBuffer] = []
            
            for reaction in reactions.reactions {
                if reaction.isSelected {
                    let tag = ReactionsMessageAttribute.messageTag(reaction: reaction.value)
                    if !result.contains(tag) {
                        result.append(tag)
                    }
                }
            }
            
            if !result.isEmpty {
                result.sort()
            }
            
            return result
        },
        displaySavedMessagesAsTopicListPreferencesKey: PreferencesKeys.displaySavedChatsAsTopics()
    )
}()

public enum AccountTransactionError {
    case couldNotOpen
}

public func accountTransaction<T>(rootPath: String, id: AccountRecordId, encryptionParameters: ValueBoxEncryptionParameters, isReadOnly: Bool, useCopy: Bool = false, useCaches: Bool = true, removeDatabaseOnError: Bool = true, transaction: @escaping (Postbox, Transaction) -> T) -> Signal<T, AccountTransactionError> {
    let path = "\(rootPath)/\(accountRecordIdPathName(id))"
    let postbox = openPostbox(basePath: path + "/postbox", seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryptionParameters, timestampForAbsoluteTimeBasedOperations: Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970), isMainProcess: false, isTemporary: true, isReadOnly: isReadOnly, useCopy: useCopy, useCaches: useCaches, removeDatabaseOnError: removeDatabaseOnError)
    return postbox
    |> castError(AccountTransactionError.self)
    |> mapToSignal { value -> Signal<T, AccountTransactionError> in
        switch value {
        case let .postbox(postbox):
            return postbox.transaction { t in
                transaction(postbox, t)
            }
            |> castError(AccountTransactionError.self)
        case .error:
            return .fail(.couldNotOpen)
        default:
            return .complete()
        }
    }
}
