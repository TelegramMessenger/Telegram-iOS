import Foundation

public enum PostboxViewKey: Hashable {
    case itemCollectionInfos(namespaces: [ItemCollectionId.Namespace])
    case itemCollectionIds(namespaces: [ItemCollectionId.Namespace])
    case itemCollectionInfo(id: ItemCollectionId)
    case peerChatState(peerId: PeerId)
    case orderedItemList(id: Int32)
    case accessChallengeData
    case preferences(keys: Set<ValueBoxKey>)
    case globalMessageTags(globalTag: GlobalMessageTags, position: MessageIndex, count: Int, groupingPredicate: ((Message, Message) -> Bool)?)
    case peer(peerId: PeerId)
    case pendingMessageActions(type: PendingMessageActionType)
    case invalidatedMessageHistoryTagSummaries(tagMask: MessageTags, namespace: MessageId.Namespace)
    case pendingMessageActionsSummary(type: PendingMessageActionType, peerId: PeerId, namespace: MessageId.Namespace)
    case historyTagSummaryView(tag: MessageTags, peerId: PeerId, namespace: MessageId.Namespace)
    case cachedPeerData(peerId: PeerId)
    case unreadCounts(items: [UnreadMessageCountsItem])
    case peerNotificationSettings(peerId: PeerId)
    case pendingPeerNotificationSettings
    case messageOfInterestHole(peerId: PeerId, namespace: MessageId.Namespace, count: Int)
    
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
            case .accessChallengeData:
                return 2
            case .preferences:
                return 3
            case .globalMessageTags:
                return 4
            case let .peer(peerId):
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
            case let .peerNotificationSettings(peerId):
                return 6 &+ 31 &* peerId.hashValue
            case .pendingPeerNotificationSettings:
                return 7
            case let .messageOfInterestHole(peerId, namespace, count):
                return 8 &+ 31 &* peerId.hashValue &+ 31 &* namespace.hashValue &+ 31 &* count.hashValue
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
            case .accessChallengeData:
                if case .accessChallengeData = rhs {
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
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
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
            case let .peerNotificationSettings(peerId):
                if case .peerNotificationSettings(peerId) = rhs {
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
        case .accessChallengeData:
            return MutableAccessChallengeDataView(postbox: postbox)
        case let .preferences(keys):
            return MutablePreferencesView(postbox: postbox, keys: keys)
        case let .globalMessageTags(globalTag, position, count, groupingPredicate):
            return MutableGlobalMessageTagsView(postbox: postbox, globalTag: globalTag, position: position, count: count, groupingPredicate: groupingPredicate)
        case let .peer(peerId):
            return MutablePeerView(postbox: postbox, peerId: peerId)
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
        case let .peerNotificationSettings(peerId):
            return MutablePeerNotificationSettingsView(postbox: postbox, peerId: peerId)
        case .pendingPeerNotificationSettings:
            return MutablePendingPeerNotificationSettingsView(postbox: postbox)
        case let .messageOfInterestHole(peerId, namespace, count):
            return MutableMessageOfInterestHolesView(postbox: postbox, peerId: peerId, namespace: namespace, count: count)
    }
}
