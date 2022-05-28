import Foundation

public enum PostboxViewKey: Hashable {
    case itemCollectionInfos(namespaces: [ItemCollectionId.Namespace])
    case itemCollectionIds(namespaces: [ItemCollectionId.Namespace])
    case itemCollectionInfo(id: ItemCollectionId)
    case peerChatState(peerId: PeerId)
    case orderedItemList(id: Int32)
    case preferences(keys: Set<ValueBoxKey>)
    case globalMessageTags(globalTag: GlobalMessageTags, position: MessageIndex, count: Int, groupingPredicate: ((Message, Message) -> Bool)?)
    case peer(peerId: PeerId, components: PeerViewComponents)
    case pendingMessageActions(type: PendingMessageActionType)
    case invalidatedMessageHistoryTagSummaries(tagMask: MessageTags, namespace: MessageId.Namespace)
    case pendingMessageActionsSummary(type: PendingMessageActionType, peerId: PeerId, namespace: MessageId.Namespace)
    case historyTagSummaryView(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace)
    case cachedPeerData(peerId: PeerId)
    case unreadCounts(items: [UnreadMessageCountsItem])
    case combinedReadState(peerId: PeerId)
    case peerNotificationSettings(peerIds: Set<PeerId>)
    case pendingPeerNotificationSettings
    case messageOfInterestHole(location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int)
    case localMessageTag(LocalMessageTags)
    case messages(Set<MessageId>)
    case additionalChatListItems
    case cachedItem(ItemCacheEntryId)
    case peerPresences(peerIds: Set<PeerId>)
    case synchronizeGroupMessageStats
    case peerNotificationSettingsBehaviorTimestampView
    case peerChatInclusion(PeerId)
    case basicPeer(PeerId)
    case allChatListHoles(PeerGroupId)
    case historyTagInfo(peerId: PeerId, tag: MessageTags)
    case topChatMessage(peerIds: [PeerId])
    case contacts(accountPeerId: PeerId?, includePresences: Bool)
    case deletedMessages(peerId: PeerId)
    case notice(key: NoticeEntryKey)
    case messageGroup(id: MessageId)
    case isContact(id: PeerId)
    case chatListIndex(id: PeerId)

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .itemCollectionInfos:
            hasher.combine(0)
        case .itemCollectionIds:
            hasher.combine(1)
        case let .peerChatState(peerId):
            hasher.combine(peerId)
        case let .itemCollectionInfo(id):
            hasher.combine(id)
        case let .orderedItemList(id):
            hasher.combine(id)
        case .preferences:
            hasher.combine(3)
        case .globalMessageTags:
            hasher.combine(4)
        case let .peer(peerId, _):
            hasher.combine(peerId)
        case let .pendingMessageActions(type):
            hasher.combine(type)
        case let .invalidatedMessageHistoryTagSummaries(tagMask, namespace):
            hasher.combine(tagMask)
            hasher.combine(namespace)
        case let .pendingMessageActionsSummary(type, peerId, namespace):
            hasher.combine(type)
            hasher.combine(peerId)
            hasher.combine(namespace)
        case let .historyTagSummaryView(tag, peerId, namespace):
            hasher.combine(tag)
            hasher.combine(peerId)
            hasher.combine(namespace)
        case let .cachedPeerData(peerId):
            hasher.combine(peerId)
        case .unreadCounts:
            hasher.combine(5)
        case .combinedReadState:
            hasher.combine(16)
        case .peerNotificationSettings:
            hasher.combine(6)
        case .pendingPeerNotificationSettings:
            hasher.combine(7)
        case let .messageOfInterestHole(location, namespace, count):
            hasher.combine(8)
            hasher.combine(location)
            hasher.combine(namespace)
            hasher.combine(count)
        case let .localMessageTag(tag):
            hasher.combine(tag)
        case .messages:
            hasher.combine(10)
        case .additionalChatListItems:
            hasher.combine(11)
        case let .cachedItem(id):
            hasher.combine(id)
        case .peerPresences:
            hasher.combine(13)
        case .synchronizeGroupMessageStats:
            hasher.combine(14)
        case .peerNotificationSettingsBehaviorTimestampView:
            hasher.combine(15)
        case let .peerChatInclusion(peerId):
            hasher.combine(peerId)
        case let .basicPeer(peerId):
            hasher.combine(peerId)
        case let .allChatListHoles(groupId):
            hasher.combine(groupId)
        case let .historyTagInfo(peerId, tag):
            hasher.combine(peerId)
            hasher.combine(tag)
        case let .topChatMessage(peerIds):
            hasher.combine(peerIds)
        case .contacts:
            hasher.combine(16)
        case let .deletedMessages(peerId):
            hasher.combine(peerId)
        case let .notice(key):
            hasher.combine(key)
        case let .messageGroup(id):
            hasher.combine(id)
        case let .isContact(id):
            hasher.combine(id)
        case let .chatListIndex(id):
            hasher.combine(id)
        }
    }
    
    public static func ==(lhs: PostboxViewKey, rhs: PostboxViewKey) -> Bool {
        switch lhs {
        case let .itemCollectionInfos(lhsNamespaces):
            if case let .itemCollectionInfos(rhsNamespaces) = rhs, lhsNamespaces == rhsNamespaces {
                return true
            } else {
                return false
            }
        case let .itemCollectionIds(lhsNamespaces):
            if case let .itemCollectionIds(rhsNamespaces) = rhs, lhsNamespaces == rhsNamespaces {
                return true
            } else {
                return false
            }
        case let .itemCollectionInfo(id):
            if case .itemCollectionInfo(id) = rhs {
                return true
            } else {
                return false
            }
        case let .peerChatState(peerId):
            if case .peerChatState(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .orderedItemList(id):
            if case .orderedItemList(id) = rhs {
                return true
            } else {
                return false
            }
        case let .preferences(lhsKeys):
            if case let .preferences(rhsKeys) = rhs, lhsKeys == rhsKeys {
                return true
            } else {
                return false
            }
        case let .globalMessageTags(globalTag, position, count, _):
            if case .globalMessageTags(globalTag, position, count, _) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(peerId, components):
            if case .peer(peerId, components) = rhs {
                return true
            } else {
                return false
            }
        case let .pendingMessageActions(type):
            if case .pendingMessageActions(type) = rhs {
                return true
            } else {
                return false
            }
        case .invalidatedMessageHistoryTagSummaries:
            if case .invalidatedMessageHistoryTagSummaries = rhs {
                return true
            } else {
                return false
            }
        case let .pendingMessageActionsSummary(type, peerId, namespace):
            if case .pendingMessageActionsSummary(type, peerId, namespace) = rhs {
                return true
            } else {
                return false
            }
        case let .historyTagSummaryView(tag, peerId, namespace):
            if case .historyTagSummaryView(tag, peerId, namespace) = rhs {
                return true
            } else {
                return false
            }
        case let .cachedPeerData(peerId):
            if case .cachedPeerData(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .unreadCounts(lhsItems):
            if case let .unreadCounts(rhsItems) = rhs, lhsItems == rhsItems {
                return true
            } else {
                return false
            }
        case let .combinedReadState(peerId):
            if case .combinedReadState(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .peerNotificationSettings(peerIds):
            if case .peerNotificationSettings(peerIds) = rhs {
                return true
            } else {
                return false
            }
        case .pendingPeerNotificationSettings:
            if case .pendingPeerNotificationSettings = rhs {
                return true
            } else {
                return false
            }
        case let .messageOfInterestHole(peerId, namespace, count):
            if case .messageOfInterestHole(peerId, namespace, count) = rhs {
                return true
            } else {
                return false
            }
        case let .localMessageTag(tag):
            if case .localMessageTag(tag) = rhs {
                return true
            } else {
                return false
            }
        case let .messages(ids):
            if case .messages(ids) = rhs {
                return true
            } else {
                return false
            }
        case .additionalChatListItems:
            if case .additionalChatListItems = rhs {
                return true
            } else {
                return false
            }
        case let .cachedItem(id):
            if case .cachedItem(id) = rhs {
                return true
            } else {
                return false
            }
        case let .peerPresences(ids):
            if case .peerPresences(ids) = rhs {
                return true
            } else {
                return false
            }
        case .synchronizeGroupMessageStats:
            if case .synchronizeGroupMessageStats = rhs {
                return true
            } else {
                return false
            }
        case .peerNotificationSettingsBehaviorTimestampView:
            if case .peerNotificationSettingsBehaviorTimestampView = rhs {
                return true
            } else {
                return false
            }
        case let .peerChatInclusion(id):
            if case .peerChatInclusion(id) = rhs {
                return true
            } else {
                return false
            }
        case let .basicPeer(id):
            if case .basicPeer(id) = rhs {
                return true
            } else {
                return false
            }
        case let .allChatListHoles(groupId):
            if case .allChatListHoles(groupId) = rhs {
                return true
            } else {
                return false
            }
        case let .historyTagInfo(peerId, tag):
            if case .historyTagInfo(peerId, tag) = rhs {
                return true
            } else {
                return false
            }
        case let .topChatMessage(peerIds):
            if case .topChatMessage(peerIds) = rhs {
                return true
            } else {
                return false
            }
        case let .contacts(accountPeerId, includePresences):
            if case .contacts(accountPeerId, includePresences) = rhs {
                return true
            } else {
                return false
            }
        case let .deletedMessages(peerId):
            if case .deletedMessages(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .notice(key):
            if case .notice(key) = rhs {
                return true
            } else {
                return false
            }
        case let .messageGroup(id):
            if case .messageGroup(id) = rhs {
                return true
            } else {
                return false
            }
        case let .isContact(id):
            if case .isContact(id) = rhs {
                return true
            } else {
                return false
            }
        case let .chatListIndex(id):
            if case .chatListIndex(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

func postboxViewForKey(postbox: PostboxImpl, key: PostboxViewKey) -> MutablePostboxView {
    switch key {
    case let .itemCollectionInfos(namespaces):
        return MutableItemCollectionInfosView(postbox: postbox, namespaces: namespaces)
    case let .itemCollectionIds(namespaces):
        return MutableItemCollectionIdsView(postbox: postbox, namespaces: namespaces)
    case let .itemCollectionInfo(id):
        return MutableItemCollectionInfoView(postbox: postbox, id: id)
    case let .peerChatState(peerId):
        return MutablePeerChatStateView(postbox: postbox, peerId: peerId)
    case let .orderedItemList(id):
        return MutableOrderedItemListView(postbox: postbox, collectionId: id)
    case let .preferences(keys):
        return MutablePreferencesView(postbox: postbox, keys: keys)
    case let .globalMessageTags(globalTag, position, count, groupingPredicate):
        return MutableGlobalMessageTagsView(postbox: postbox, globalTag: globalTag, position: position, count: count, groupingPredicate: groupingPredicate)
    case let .peer(peerId, components):
        return MutablePeerView(postbox: postbox, peerId: peerId, components: components)
    case let .pendingMessageActions(type):
        return MutablePendingMessageActionsView(postbox: postbox, type: type)
    case let .invalidatedMessageHistoryTagSummaries(tagMask, namespace):
        return MutableInvalidatedMessageHistoryTagSummariesView(postbox: postbox, tagMask: tagMask, namespace: namespace)
    case let .pendingMessageActionsSummary(type, peerId, namespace):
        return MutablePendingMessageActionsSummaryView(postbox: postbox, type: type, peerId: peerId, namespace: namespace)
    case let .historyTagSummaryView(tag, peerId, namespace):
        return MutableMessageHistoryTagSummaryView(postbox: postbox, tag: tag, peerId: peerId, namespace: namespace)
    case let .cachedPeerData(peerId):
        return MutableCachedPeerDataView(postbox: postbox, peerId: peerId)
    case let .unreadCounts(items):
        return MutableUnreadMessageCountsView(postbox: postbox, items: items)
    case let .combinedReadState(peerId):
        return MutableCombinedReadStateView(postbox: postbox, peerId: peerId)
    case let .peerNotificationSettings(peerIds):
        return MutablePeerNotificationSettingsView(postbox: postbox, peerIds: peerIds)
    case .pendingPeerNotificationSettings:
        return MutablePendingPeerNotificationSettingsView(postbox: postbox)
    case let .messageOfInterestHole(location, namespace, count):
        return MutableMessageOfInterestHolesView(postbox: postbox, location: location, namespace: namespace, count: count)
    case let .localMessageTag(tag):
        return MutableLocalMessageTagsView(postbox: postbox, tag: tag)
    case let .messages(ids):
        return MutableMessagesView(postbox: postbox, ids: ids)
    case .additionalChatListItems:
        return MutableAdditionalChatListItemsView(postbox: postbox)
    case let .cachedItem(id):
        return MutableCachedItemView(postbox: postbox, id: id)
    case let .peerPresences(ids):
        return MutablePeerPresencesView(postbox: postbox, ids: ids)
    case .synchronizeGroupMessageStats:
        return MutableSynchronizeGroupMessageStatsView(postbox: postbox)
    case .peerNotificationSettingsBehaviorTimestampView:
        return MutablePeerNotificationSettingsBehaviorTimestampView(postbox: postbox)
    case let .peerChatInclusion(peerId):
        return MutablePeerChatInclusionView(postbox: postbox, peerId: peerId)
    case let .basicPeer(peerId):
        return MutableBasicPeerView(postbox: postbox, peerId: peerId)
    case let .allChatListHoles(groupId):
        return MutableAllChatListHolesView(postbox: postbox, groupId: groupId)
    case let .historyTagInfo(peerId, tag):
        return MutableHistoryTagInfoView(postbox: postbox, peerId: peerId, tag: tag)
    case let .topChatMessage(peerIds):
        return MutableTopChatMessageView(postbox: postbox, peerIds: Set(peerIds))
    case let .contacts(accountPeerId, includePresences):
        return MutableContactPeersView(postbox: postbox, accountPeerId: accountPeerId, includePresences: includePresences)
    case let .deletedMessages(peerId):
        return MutableDeletedMessagesView(peerId: peerId)
    case let .notice(key):
        return MutableLocalNoticeEntryView(postbox: postbox, key: key)
    case let .messageGroup(id):
        return MutableMessageGroupView(postbox: postbox, id: id)
    case let .isContact(id):
        return MutableIsContactView(postbox: postbox, id: id)
    case let .chatListIndex(id):
        return MutableChatListIndexView(postbox: postbox, id: id)
    }
}
