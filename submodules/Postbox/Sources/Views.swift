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
    
    public var hashValue: Int {
        switch self {
            case .itemCollectionInfos:
                return 0
            case .itemCollectionIds:
                return 1
            case let .peerChatState(peerId):
                return peerId.hashValue
            case let .itemCollectionInfo(id):
                return id.hashValue
            case let .orderedItemList(id):
                return id.hashValue
            case .preferences:
                return 3
            case .globalMessageTags:
                return 4
            case let .peer(peerId, _):
                return peerId.hashValue
            case let .pendingMessageActions(type):
                return type.hashValue
            case let .invalidatedMessageHistoryTagSummaries(tagMask, namespace):
                return tagMask.rawValue.hashValue ^ namespace.hashValue
            case let .pendingMessageActionsSummary(type, peerId, namespace):
                return type.hashValue ^ peerId.hashValue ^ namespace.hashValue
            case let .historyTagSummaryView(tag, peerId, namespace):
                return tag.rawValue.hashValue ^ peerId.hashValue ^ namespace.hashValue
            case let .cachedPeerData(peerId):
                return peerId.hashValue
            case .unreadCounts:
                return 5
            case .peerNotificationSettings:
                return 6
            case .pendingPeerNotificationSettings:
                return 7
            case let .messageOfInterestHole(location, namespace, count):
                return 8 &+ 31 &* location.hashValue &+ 31 &* namespace.hashValue &+ 31 &* count.hashValue
            case let .localMessageTag(tag):
                return tag.hashValue
            case .messages:
                return 10
            case .additionalChatListItems:
                return 11
            case let .cachedItem(id):
                return id.hashValue
            case .peerPresences:
                return 13
            case .synchronizeGroupMessageStats:
                return 14
            case .peerNotificationSettingsBehaviorTimestampView:
                return 15
            case let .peerChatInclusion(peerId):
                return peerId.hashValue
            case let .basicPeer(peerId):
                return peerId.hashValue
            case let .allChatListHoles(groupId):
                return groupId.hashValue
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
        }
    }
}

func postboxViewForKey(postbox: Postbox, key: PostboxViewKey) -> MutablePostboxView {
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
    }
}
