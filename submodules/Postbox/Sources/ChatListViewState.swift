
enum ChatListViewSpacePinned {
    case notPinned
    case includePinned
    case includePinnedAsUnpinned
    
    var include: Bool {
        switch self {
        case .notPinned:
            return false
        case .includePinned, .includePinnedAsUnpinned:
            return true
        }
    }
}

enum ChatListViewSpace: Hashable {
    case group(groupId: PeerGroupId, pinned: ChatListViewSpacePinned, predicate: ChatListFilterPredicate?)
    case peers(peerIds: [PeerId], asPinned: Bool)
    
    static func ==(lhs: ChatListViewSpace, rhs: ChatListViewSpace) -> Bool {
        switch lhs {
        case let .group(groupId, pinned, _):
            if case let .group(rhsGroupId, rhsPinned, _) = rhs {
                if groupId != rhsGroupId {
                    return false
                }
                if pinned != rhsPinned {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .peers(peerIds, asPinned):
            if case .peers(peerIds, asPinned) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .group(groupId, pinned, _):
            hasher.combine(groupId)
            hasher.combine(pinned)
        case let .peers(peerIds, asPinned):
            hasher.combine(peerIds)
            hasher.combine(asPinned)
        }
    }
}

private func mappedChatListFilterPredicate(postbox: PostboxImpl, currentTransaction: Transaction, groupId: PeerGroupId, predicate: ChatListFilterPredicate) -> (ChatListIntermediateEntry) -> Bool {
    let globalNotificationSettings = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
    return { entry in
        switch entry {
        case let .message(index, _):
            if let peer = postbox.peerTable.get(index.messageIndex.id.peerId) {
                var isUnread: Bool
                if postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                    isUnread = (postbox.peerThreadsSummaryTable.get(peerId: peer.id)?.effectiveUnreadCount ?? 0) > 0
                } else {
                    isUnread = postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId)?.isUnread ?? false
                }
                
                let notificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                let isContact = postbox.contactsTable.isContact(peerId: notificationsPeerId)
                let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettings, peer: peer, peerSettings: postbox.peerNotificationSettingsTable.getEffective(notificationsPeerId))
                let messageTagSummaryResult = resolveChatListMessageTagSummaryResultCalculation(postbox: postbox, peerId: peer.id, threadId: nil, calculation: predicate.messageTagSummary)
                
                if predicate.includes(peer: peer, groupId: groupId, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: messageTagSummaryResult) {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        case .hole:
            return true
        }
    }
}

private func updateMessagePeers(_ message: Message, updatedPeers: [PeerId: Peer]) -> Message? {
    var updated = false
    for (peerId, currentPeer) in message.peers {
        if let updatedPeer = updatedPeers[peerId], !arePeersEqual(currentPeer, updatedPeer) {
            updated = true
            break
        }
    }
    if updated {
        var peers = SimpleDictionary<PeerId, Peer>()
        for (peerId, currentPeer) in message.peers {
            if let updatedPeer = updatedPeers[peerId] {
                peers[peerId] = updatedPeer
            } else {
                peers[peerId] = currentPeer
            }
        }
        return Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds, associatedMedia: message.associatedMedia, associatedThreadInfo: message.associatedThreadInfo)
    }
    return nil
}

private func updatedRenderedPeer(postbox: PostboxImpl, renderedPeer: RenderedPeer, updatedPeers: [PeerId: Peer]) -> RenderedPeer? {
    var updated = false
    for (peerId, currentPeer) in renderedPeer.peers {
        if let updatedPeer = updatedPeers[peerId], !arePeersEqual(currentPeer, updatedPeer) {
            updated = true
            break
        }
    }
    if updated {
        var peers = SimpleDictionary<PeerId, Peer>()
        for (peerId, currentPeer) in renderedPeer.peers {
            if let updatedPeer = updatedPeers[peerId] {
                peers[peerId] = updatedPeer
            } else {
                peers[peerId] = currentPeer
            }
        }
        return RenderedPeer(peerId: renderedPeer.peerId, peers: peers, associatedMedia: renderAssociatedMediaForPeers(postbox: postbox, peers: peers))
    }
    return nil
}

private final class ChatListViewSpaceState {
    private let space: ChatListViewSpace
    private let anchorIndex: MutableChatListEntryIndex
    private let summaryComponents: ChatListEntrySummaryComponents
    private let halfLimit: Int
    
    var orderedEntries: OrderedChatListViewEntries
    
    init(postbox: PostboxImpl, currentTransaction: Transaction, space: ChatListViewSpace, anchorIndex: MutableChatListEntryIndex, summaryComponents: ChatListEntrySummaryComponents, halfLimit: Int) {
        self.space = space
        self.anchorIndex = anchorIndex
        self.summaryComponents = summaryComponents
        self.halfLimit = halfLimit
        self.orderedEntries = OrderedChatListViewEntries(anchorIndex: anchorIndex.index, lowerOrAtAnchor: [], higherThanAnchor: [])
        self.fillSpace(postbox: postbox, currentTransaction: currentTransaction)
        
        self.checkEntries(postbox: postbox)
    }
    
    private func fillSpace(postbox: PostboxImpl, currentTransaction: Transaction) {
        switch self.space {
        case let .group(groupId, pinned, filterPredicate):
            let lowerBound: MutableChatListEntryIndex
            let upperBound: MutableChatListEntryIndex
            if pinned.include {
                upperBound = .absoluteUpperBound
                lowerBound = MutableChatListEntryIndex(index: ChatListIndex.pinnedLowerBound, isMessage: true)
            } else {
                upperBound = MutableChatListEntryIndex(index: ChatListIndex.pinnedLowerBound.predecessor, isMessage: true)
                lowerBound = .absoluteLowerBound
            }
            let resolvedAnchorIndex = min(upperBound, max(self.anchorIndex, lowerBound))
            
            var lowerOrAtAnchorMessages: [MutableChatListEntry] = self.orderedEntries.lowerOrAtAnchor.reversed()
            var higherThanAnchorMessages: [MutableChatListEntry] = self.orderedEntries.higherThanAnchor
            
            func mapEntry(_ entry: ChatListIntermediateEntry) -> MutableChatListEntry {
                switch entry {
                case let .message(index, messageIndex):
                    var updatedIndex = index
                    if case .includePinnedAsUnpinned = pinned {
                        updatedIndex = ChatListIndex(pinningIndex: nil, messageIndex: index.messageIndex)
                    }
                    return .IntermediateMessageEntry(index: updatedIndex, messageIndex: messageIndex)
                case let .hole(hole):
                    return .HoleEntry(hole)
                }
            }
            
            if case .includePinnedAsUnpinned = pinned {
                let unpinnedLowerBound: MutableChatListEntryIndex
                let unpinnedUpperBound: MutableChatListEntryIndex
                unpinnedUpperBound = .absoluteUpperBound
                unpinnedLowerBound = MutableChatListEntryIndex(index: ChatListIndex.absoluteLowerBound, isMessage: true)
                let resolvedUnpinnedAnchorIndex = min(unpinnedUpperBound, max(self.anchorIndex, unpinnedLowerBound))
                
                if lowerOrAtAnchorMessages.count < self.halfLimit || higherThanAnchorMessages.count < self.halfLimit {
                    let loadedMessages = postbox.chatListTable.entries(groupId: groupId, from: (ChatListIndex.pinnedLowerBound, true), to: (ChatListIndex.absoluteUpperBound, true), peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable, count: self.halfLimit * 2, predicate: filterPredicate.flatMap { mappedChatListFilterPredicate(postbox: postbox, currentTransaction: currentTransaction, groupId: groupId, predicate: $0) }).map(mapEntry).sorted(by: { $0.entryIndex < $1.entryIndex })
                    
                    if lowerOrAtAnchorMessages.count < self.halfLimit {
                        var nextLowerIndex: MutableChatListEntryIndex
                        if let lastMessage = lowerOrAtAnchorMessages.min(by: { $0.entryIndex < $1.entryIndex }) {
                            nextLowerIndex = lastMessage.entryIndex.predecessor
                        } else {
                            nextLowerIndex = min(resolvedUnpinnedAnchorIndex, self.anchorIndex)
                        }
                        var loadedLowerMessages = Array(loadedMessages.filter({ $0.entryIndex <= nextLowerIndex }).reversed())
                        let lowerLimit = self.halfLimit - lowerOrAtAnchorMessages.count
                        if loadedLowerMessages.count > lowerLimit {
                            loadedLowerMessages.removeLast(loadedLowerMessages.count - lowerLimit)
                        }
                        lowerOrAtAnchorMessages.append(contentsOf: loadedLowerMessages)
                    }
                    if higherThanAnchorMessages.count < self.halfLimit {
                        var nextHigherIndex: MutableChatListEntryIndex
                        if let lastMessage = higherThanAnchorMessages.max(by: { $0.entryIndex < $1.entryIndex }) {
                            nextHigherIndex = lastMessage.entryIndex.successor
                        } else {
                            nextHigherIndex = max(resolvedUnpinnedAnchorIndex, self.anchorIndex.successor)
                        }
                        var loadedHigherMessages = loadedMessages.filter({ $0.entryIndex > nextHigherIndex })
                        let higherLimit = self.halfLimit - higherThanAnchorMessages.count
                        if loadedHigherMessages.count > higherLimit {
                            loadedHigherMessages.removeLast(loadedHigherMessages.count - higherLimit)
                        }
                        higherThanAnchorMessages.append(contentsOf: loadedHigherMessages)
                    }
                }
            } else {
                if lowerOrAtAnchorMessages.count < self.halfLimit {
                    var nextLowerIndex: MutableChatListEntryIndex
                    if let lastMessage = lowerOrAtAnchorMessages.min(by: { $0.entryIndex < $1.entryIndex }) {
                        nextLowerIndex = lastMessage.entryIndex
                    } else {
                        nextLowerIndex = resolvedAnchorIndex.successor
                    }
                    let loadedLowerMessages = postbox.chatListTable.entries(groupId: groupId, from: (nextLowerIndex.index, nextLowerIndex.isMessage), to: (lowerBound.index, lowerBound.isMessage), peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable, count: self.halfLimit - lowerOrAtAnchorMessages.count, predicate: filterPredicate.flatMap { mappedChatListFilterPredicate(postbox: postbox, currentTransaction: currentTransaction, groupId: groupId, predicate: $0) }).map(mapEntry)
                    lowerOrAtAnchorMessages.append(contentsOf: loadedLowerMessages)
                }
                if higherThanAnchorMessages.count < self.halfLimit {
                    var nextHigherIndex: MutableChatListEntryIndex
                    if let lastMessage = higherThanAnchorMessages.max(by: { $0.entryIndex < $1.entryIndex }) {
                        nextHigherIndex = lastMessage.entryIndex
                    } else {
                        nextHigherIndex = resolvedAnchorIndex
                    }
                    let loadedHigherMessages = postbox.chatListTable.entries(groupId: groupId, from: (nextHigherIndex.index, nextHigherIndex.isMessage), to: (upperBound.index, upperBound.isMessage), peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable, count: self.halfLimit - higherThanAnchorMessages.count, predicate: filterPredicate.flatMap { mappedChatListFilterPredicate(postbox: postbox, currentTransaction: currentTransaction, groupId: groupId, predicate: $0) }).map(mapEntry)
                    higherThanAnchorMessages.append(contentsOf: loadedHigherMessages)
                }
            }
            
            lowerOrAtAnchorMessages.reverse()
            
            assert(lowerOrAtAnchorMessages.count <= self.halfLimit)
            assert(higherThanAnchorMessages.count <= self.halfLimit)
            
            let allIndices = (lowerOrAtAnchorMessages + higherThanAnchorMessages).map { $0.entryIndex }
            let allEntityIds = (lowerOrAtAnchorMessages + higherThanAnchorMessages).map { $0.entityId }
            if Set(allIndices).count != allIndices.count {
                var debugRepeatedIndices = Set<MutableChatListEntryIndex>()
                var existingIndices = Set<MutableChatListEntryIndex>()
                for i in (0 ..< lowerOrAtAnchorMessages.count).reversed() {
                    if !existingIndices.contains(lowerOrAtAnchorMessages[i].entryIndex) {
                        existingIndices.insert(lowerOrAtAnchorMessages[i].entryIndex)
                    } else {
                        debugRepeatedIndices.insert(lowerOrAtAnchorMessages[i].entryIndex)
                        lowerOrAtAnchorMessages.remove(at: i)
                    }
                }
                for i in (0 ..< higherThanAnchorMessages.count).reversed() {
                    if !existingIndices.contains(higherThanAnchorMessages[i].entryIndex) {
                        existingIndices.insert(higherThanAnchorMessages[i].entryIndex)
                    } else {
                        debugRepeatedIndices.insert(higherThanAnchorMessages[i].entryIndex)
                        higherThanAnchorMessages.remove(at: i)
                    }
                }
                postboxLog("allIndices not unique, repeated: \(debugRepeatedIndices)")
                
                assert(false)
                //preconditionFailure()
            }
            if Set(allEntityIds).count != allEntityIds.count {
                var existingEntityIds = Set<MutableChatListEntryEntityId>()
                for i in (0 ..< lowerOrAtAnchorMessages.count).reversed() {
                    if !existingEntityIds.contains(lowerOrAtAnchorMessages[i].entityId) {
                        existingEntityIds.insert(lowerOrAtAnchorMessages[i].entityId)
                    } else {
                        lowerOrAtAnchorMessages.remove(at: i)
                    }
                }
                for i in (0 ..< higherThanAnchorMessages.count).reversed() {
                    if !existingEntityIds.contains(higherThanAnchorMessages[i].entityId) {
                        existingEntityIds.insert(higherThanAnchorMessages[i].entityId)
                    } else {
                        higherThanAnchorMessages.remove(at: i)
                    }
                }
                
                postboxLog("existingEntityIds not unique: \(allEntityIds)")
                postboxLog("allIndices: \(allIndices)")
                assert(false)
                //preconditionFailure()
            }
            
            assert(allIndices.sorted() == allIndices)
            
            let entries = OrderedChatListViewEntries(anchorIndex: self.anchorIndex.index, lowerOrAtAnchor: lowerOrAtAnchorMessages, higherThanAnchor: higherThanAnchorMessages)
            self.orderedEntries = entries
        case let .peers(peerIds, asPinned):
            var lowerOrAtAnchorMessages: [MutableChatListEntry] = self.orderedEntries.lowerOrAtAnchor.reversed()
            var higherThanAnchorMessages: [MutableChatListEntry] = self.orderedEntries.higherThanAnchor
            
            let unpinnedLowerBound: MutableChatListEntryIndex
            let unpinnedUpperBound: MutableChatListEntryIndex
            unpinnedUpperBound = .absoluteUpperBound
            unpinnedLowerBound = MutableChatListEntryIndex(index: ChatListIndex.absoluteLowerBound, isMessage: true)
            let resolvedUnpinnedAnchorIndex = min(unpinnedUpperBound, max(self.anchorIndex, unpinnedLowerBound))
            
            if lowerOrAtAnchorMessages.count < self.halfLimit || higherThanAnchorMessages.count < self.halfLimit {
                func mapEntry(_ entry: ChatListIntermediateEntry, pinningIndex: UInt16?) -> MutableChatListEntry {
                    switch entry {
                    case let .message(index, messageIndex):
                        var updatedIndex = index
                        updatedIndex = ChatListIndex(pinningIndex: pinningIndex, messageIndex: index.messageIndex)
                        return .IntermediateMessageEntry(index: updatedIndex, messageIndex: messageIndex)
                    case let .hole(hole):
                        return .HoleEntry(hole)
                    }
                }
                
                var loadedMessages: [MutableChatListEntry] = []
                for i in 0 ..< peerIds.count {
                    let peerId = peerIds[i]
                    if let entry = postbox.chatListTable.getEntry(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable) {
                        loadedMessages.append(mapEntry(entry, pinningIndex: asPinned ? UInt16(i) : nil))
                    }
                }
                loadedMessages.sort(by: { $0.entryIndex < $1.entryIndex })
                
                if lowerOrAtAnchorMessages.count < self.halfLimit {
                    var nextLowerIndex: MutableChatListEntryIndex
                    if let lastMessage = lowerOrAtAnchorMessages.min(by: { $0.entryIndex < $1.entryIndex }) {
                        nextLowerIndex = lastMessage.entryIndex.predecessor
                    } else {
                        nextLowerIndex = min(resolvedUnpinnedAnchorIndex, self.anchorIndex)
                    }
                    var loadedLowerMessages = Array(loadedMessages.filter({ $0.entryIndex <= nextLowerIndex }).reversed())
                    let lowerLimit = self.halfLimit - lowerOrAtAnchorMessages.count
                    if loadedLowerMessages.count > lowerLimit {
                        loadedLowerMessages.removeLast(loadedLowerMessages.count - lowerLimit)
                    }
                    lowerOrAtAnchorMessages.append(contentsOf: loadedLowerMessages)
                }
                if higherThanAnchorMessages.count < self.halfLimit {
                    var nextHigherIndex: MutableChatListEntryIndex
                    if let lastMessage = higherThanAnchorMessages.max(by: { $0.entryIndex < $1.entryIndex }) {
                        nextHigherIndex = lastMessage.entryIndex.successor
                    } else {
                        nextHigherIndex = max(resolvedUnpinnedAnchorIndex, self.anchorIndex.successor)
                    }
                    var loadedHigherMessages = loadedMessages.filter({ $0.entryIndex > nextHigherIndex })
                    let higherLimit = self.halfLimit - higherThanAnchorMessages.count
                    if loadedHigherMessages.count > higherLimit {
                        loadedHigherMessages.removeLast(loadedHigherMessages.count - higherLimit)
                    }
                    higherThanAnchorMessages.append(contentsOf: loadedHigherMessages)
                }
                
                lowerOrAtAnchorMessages.reverse()
                
                assert(lowerOrAtAnchorMessages.count <= self.halfLimit)
                assert(higherThanAnchorMessages.count <= self.halfLimit)
                
                let allIndices = (lowerOrAtAnchorMessages + higherThanAnchorMessages).map { $0.entryIndex }
                assert(Set(allIndices).count == allIndices.count)
                assert(allIndices.sorted() == allIndices)
                
                let entries = OrderedChatListViewEntries(anchorIndex: self.anchorIndex.index, lowerOrAtAnchor: lowerOrAtAnchorMessages, higherThanAnchor: higherThanAnchorMessages)
                self.orderedEntries = entries
            }
        }
        
        assert(self.orderedEntries.lowerOrAtAnchor.count <= self.halfLimit)
        assert(self.orderedEntries.higherThanAnchor.count <= self.halfLimit)
    }
    
    func replay(postbox: PostboxImpl, currentTransaction: Transaction, transaction: PostboxTransaction) -> Bool {
        var hasUpdates = false
        var hadRemovals = false
        var globalNotificationSettings: PostboxGlobalNotificationSettings?
        for (groupId, operations) in transaction.chatListOperations {
            inner: for operation in operations {
                switch operation {
                case let .InsertEntry(index, messageIndex):
                    switch self.space {
                    case let .group(spaceGroupId, pinned, filterPredicate):
                        let matchesGroup = groupId == spaceGroupId && (index.pinningIndex != nil) == pinned.include
                        if !matchesGroup {
                            continue inner
                        }
                        
                        var updatedIndex = index
                        if case .includePinnedAsUnpinned = pinned {
                            updatedIndex = ChatListIndex(pinningIndex: nil, messageIndex: index.messageIndex)
                        }
                        if let filterPredicate = filterPredicate {
                            if let peer = postbox.peerTable.get(updatedIndex.messageIndex.id.peerId) {
                                let notificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                                let globalNotificationSettingsValue: PostboxGlobalNotificationSettings
                                if let current = globalNotificationSettings {
                                    globalNotificationSettingsValue = current
                                } else {
                                    globalNotificationSettingsValue = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
                                    globalNotificationSettings = globalNotificationSettingsValue
                                }
                                
                                let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: peer, peerSettings: postbox.peerNotificationSettingsTable.getEffective(notificationsPeerId))
                                
                                let messageTagSummaryResult = resolveChatListMessageTagSummaryResultCalculation(postbox: postbox, peerId: peer.id, threadId: nil, calculation: filterPredicate.messageTagSummary)
                                
                                var isUnread: Bool
                                if postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                                    isUnread = (postbox.peerThreadsSummaryTable.get(peerId: peer.id)?.effectiveUnreadCount ?? 0) > 0
                                } else {
                                    isUnread = postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId)?.isUnread ?? false
                                }
                                
                                if !filterPredicate.includes(peer: peer, groupId: groupId, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, isUnread: isUnread, isContact: postbox.contactsTable.isContact(peerId: notificationsPeerId), messageTagSummaryResult: messageTagSummaryResult) {
                                    continue inner
                                }
                            } else {
                                continue inner
                            }
                        }
                        if self.add(entry: .IntermediateMessageEntry(index: updatedIndex, messageIndex: messageIndex)) {
                            hasUpdates = true
                        } else {
                            hasUpdates = true
                            hadRemovals = true
                        }
                    case let .peers(peerIds, asPinned):
                        if let peerIndex = peerIds.firstIndex(of: index.messageIndex.id.peerId) {
                            var updatedIndex = index
                            if asPinned {
                                updatedIndex = ChatListIndex(pinningIndex: UInt16(peerIndex), messageIndex: index.messageIndex)
                            }
                            if self.add(entry: .IntermediateMessageEntry(index: updatedIndex, messageIndex: messageIndex)) {
                                hasUpdates = true
                            } else {
                                hasUpdates = true
                                hadRemovals = true
                            }
                        } else {
                            continue inner
                        }
                    }
                case let .InsertHole(hole):
                    switch self.space {
                    case let .group(spaceGroupId, pinned, _):
                        if spaceGroupId == groupId && !pinned.include {
                            if self.add(entry: .HoleEntry(hole)) {
                                hasUpdates = true
                            } else {
                                hasUpdates = true
                                hadRemovals = true
                            }
                        }
                    case .peers:
                        break
                    }
                case let .RemoveEntry(indices):
                    switch self.space {
                    case let .group(spaceGroupId, pinned, _):
                        if spaceGroupId == groupId {
                            for index in indices {
                                var updatedIndex = index
                                if case .includePinnedAsUnpinned = pinned {
                                    updatedIndex = ChatListIndex(pinningIndex: nil, messageIndex: index.messageIndex)
                                }
                                
                                if self.orderedEntries.remove(index: MutableChatListEntryIndex(index: updatedIndex, isMessage: true)) {
                                    hasUpdates = true
                                    hadRemovals = true
                                }
                            }
                        }
                    case let .peers(peerIds, asPinned):
                        for index in indices {
                            if let peerIndex = peerIds.firstIndex(of: index.messageIndex.id.peerId) {
                                var updatedIndex = index
                                if asPinned {
                                    updatedIndex = ChatListIndex(pinningIndex: UInt16(peerIndex), messageIndex: index.messageIndex)
                                }
                                
                                if self.orderedEntries.remove(index: MutableChatListEntryIndex(index: updatedIndex, isMessage: true)) {
                                    hasUpdates = true
                                    hadRemovals = true
                                }
                            }
                        }
                    }
                case let .RemoveHoles(indices):
                    switch self.space {
                    case let .group(spaceGroupId, pinned, _):
                        if spaceGroupId == groupId && !pinned.include {
                            for index in indices {
                                if self.orderedEntries.remove(index: MutableChatListEntryIndex(index: index, isMessage: false)) {
                                    hasUpdates = true
                                    hadRemovals = true
                                }
                            }
                        }
                    case .peers:
                        break
                    }
                }
            }
        }
        
        if (!transaction.currentUpdatedPeerNotificationSettings.isEmpty || !transaction.updatedPeerThreadsSummaries.isEmpty), case let .group(groupId, pinned, maybeFilterPredicate) = self.space, let filterPredicate = maybeFilterPredicate {
            var removeEntryIndices: [MutableChatListEntryIndex] = []
            let _ = self.orderedEntries.mutableScan { entry -> MutableChatListEntry? in
                let entryPeer: Peer
                let entryNotificationsPeerId: PeerId
                switch entry {
                case let .MessageEntry(_, _, _, _, _, _, renderedPeer, _, _, _, _, _):
                    if let peer = renderedPeer.peer {
                        entryPeer = peer
                        entryNotificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                    } else {
                        return nil
                    }
                case let .IntermediateMessageEntry(index, _):
                    if let peer = postbox.peerTable.get(index.messageIndex.id.peerId) {
                        entryPeer = peer
                        entryNotificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                    } else {
                        return nil
                    }
                case .HoleEntry:
                    return nil
                }
                
                let settingsChange = transaction.currentUpdatedPeerNotificationSettings[entryNotificationsPeerId]
                if settingsChange != nil || transaction.updatedPeerThreadsSummaries.contains(entryNotificationsPeerId) {
                    var isUnread: Bool
                    if postbox.seedConfiguration.peerSummaryIsThreadBased(entryPeer) {
                        isUnread = (postbox.peerThreadsSummaryTable.get(peerId: entryPeer.id)?.effectiveUnreadCount ?? 0) > 0
                    } else {
                        isUnread = postbox.readStateTable.getCombinedState(entryPeer.id)?.isUnread ?? false
                    }
                    
                    let globalNotificationSettingsValue: PostboxGlobalNotificationSettings
                    if let current = globalNotificationSettings {
                        globalNotificationSettingsValue = current
                    } else {
                        globalNotificationSettingsValue = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
                        globalNotificationSettings = globalNotificationSettingsValue
                    }
                    
                    let nowRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: entryPeer, peerSettings: settingsChange?.1 ?? postbox.peerNotificationSettingsTable.getEffective(entryNotificationsPeerId))
                    
                    let messageTagSummaryResult = resolveChatListMessageTagSummaryResultCalculation(postbox: postbox, peerId: entryPeer.id, threadId: nil, calculation: filterPredicate.messageTagSummary)
                    
                    let isIncluded = filterPredicate.includes(peer: entryPeer, groupId: groupId, isRemovedFromTotalUnreadCount: nowRemovedFromTotalUnreadCount, isUnread: isUnread, isContact: postbox.contactsTable.isContact(peerId: entryNotificationsPeerId), messageTagSummaryResult: messageTagSummaryResult)
                    if !isIncluded {
                        removeEntryIndices.append(entry.entryIndex)
                    }
                }
                return nil
            }
            if !removeEntryIndices.isEmpty {
                hasUpdates = true
                hadRemovals = true
                for index in removeEntryIndices {
                    let _ = self.orderedEntries.remove(index: index)
                }
            }
            
            for peerId in transaction.updatedPeerThreadsSummaries.union(transaction.currentUpdatedPeerNotificationSettings.keys) {
                if let mainPeer = postbox.peerTable.get(peerId) {
                    var peers: [Peer] = [mainPeer]
                    for associatedId in postbox.reverseAssociatedPeerTable.get(peerId: mainPeer.id) {
                        if let associatedPeer = postbox.peerTable.get(associatedId) {
                            peers.append(associatedPeer)
                        }
                    }
                    assert(Set(peers.map { $0.id }).count == peers.count)
                    
                    var isUnread: Bool
                    if postbox.seedConfiguration.peerSummaryIsThreadBased(mainPeer) {
                        isUnread = (postbox.peerThreadsSummaryTable.get(peerId: peerId)?.effectiveUnreadCount ?? 0) > 0
                    } else {
                        isUnread = postbox.readStateTable.getCombinedState(peerId)?.isUnread ?? false
                    }
                    
                    let globalNotificationSettingsValue: PostboxGlobalNotificationSettings
                    if let current = globalNotificationSettings {
                        globalNotificationSettingsValue = current
                    } else {
                        globalNotificationSettingsValue = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
                        globalNotificationSettings = globalNotificationSettingsValue
                    }
                    
                    let nowRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: mainPeer, peerSettings: transaction.currentUpdatedPeerNotificationSettings[mainPeer.id]?.1 ?? postbox.peerNotificationSettingsTable.getEffective(mainPeer.id))
                    
                    let messageTagSummaryResult = resolveChatListMessageTagSummaryResultCalculation(postbox: postbox, peerId: peerId, threadId: nil, calculation: filterPredicate.messageTagSummary)
                    
                    let isIncluded = filterPredicate.includes(peer: mainPeer, groupId: groupId, isRemovedFromTotalUnreadCount: nowRemovedFromTotalUnreadCount, isUnread: isUnread, isContact: postbox.contactsTable.isContact(peerId: peerId), messageTagSummaryResult: messageTagSummaryResult)
                    if isIncluded && self.orderedEntries.indicesForPeerId(mainPeer.id) == nil {
                        for peer in peers {
                            let tableEntry = postbox.chatListTable.getEntry(groupId: groupId, peerId: peer.id, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable)
                            if let entry = tableEntry {
                                if pinned.include == (entry.index.pinningIndex != nil) {
                                    if self.orderedEntries.indicesForPeerId(peer.id) == nil {
                                        switch entry {
                                        case let .message(index, messageIndex):
                                            if self.add(entry: .IntermediateMessageEntry(index: index, messageIndex: messageIndex)) {
                                                hasUpdates = true
                                            } else {
                                                hasUpdates = true
                                                hadRemovals = true
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if !transaction.currentUpdatedPeerNotificationSettings.isEmpty {
            let globalNotificationSettings = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
            
            if self.orderedEntries.mutableScan({ entry in
                switch entry {
                case let .MessageEntry(index, messages, readState, _, _, embeddedInterfaceState, renderedPeer, presence, tagSummaryInfo, forumTopicData, hasFailedMessages, isContact):
                    if let peer = renderedPeer.peer {
                        let notificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                        if let (_, updated) = transaction.currentUpdatedPeerNotificationSettings[notificationsPeerId] {
                            let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettings, peer: peer, peerSettings: updated)
                            
                            return .MessageEntry(index: index, messages: messages, readState: readState, notificationSettings: updated, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, embeddedInterfaceState: embeddedInterfaceState, renderedPeer: renderedPeer, presence: presence, tagSummaryInfo: tagSummaryInfo, forumTopicData: forumTopicData, hasFailedMessages: hasFailedMessages, isContact: isContact)
                        } else {
                            return nil
                        }
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }) {
                hasUpdates = true
            }
        }
        
        if !transaction.updatedFailedMessagePeerIds.isEmpty {
            if self.orderedEntries.mutableScan({ entry in
                switch entry {
                case let .MessageEntry(index, messages, readState, notificationSettings, isRemovedFromTotalUnreadCount, embeddedInterfaceState, renderedPeer, presence, tagSummaryInfo, forumTopicData, _, isContact):
                    if transaction.updatedFailedMessagePeerIds.contains(index.messageIndex.id.peerId) {
                        return .MessageEntry(
                            index: index,
                            messages: messages,
                            readState: readState,
                            notificationSettings: notificationSettings,
                            isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                            embeddedInterfaceState: embeddedInterfaceState,
                            renderedPeer: renderedPeer,
                            presence: presence,
                            tagSummaryInfo: tagSummaryInfo,
                            forumTopicData: forumTopicData,
                            hasFailedMessages: postbox.messageHistoryFailedTable.contains(peerId: index.messageIndex.id.peerId),
                            isContact: isContact
                        )
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }) {
                hasUpdates = true
            }
        }
        
        if !transaction.currentUpdatedPeers.isEmpty {
            if self.orderedEntries.mutableScan({ entry in
                switch entry {
                case let .MessageEntry(index, messages, readState, notificationSettings, isRemovedFromTotalUnreadCount, embeddedInterfaceState, entryRenderedPeer, presence, tagSummaryInfo, forumTopicData, hasFailedMessages, isContact):
                    var updatedMessages: [Message] = messages
                    var hasUpdatedMessages = false
                    for i in 0 ..< updatedMessages.count {
                        if let updatedMessage = updateMessagePeers(updatedMessages[i], updatedPeers: transaction.currentUpdatedPeers) {
                            updatedMessages[i] = updatedMessage
                            hasUpdatedMessages = true
                        }
                    }
                    let renderedPeer = updatedRenderedPeer(postbox: postbox, renderedPeer: entryRenderedPeer, updatedPeers: transaction.currentUpdatedPeers)
                    
                    if hasUpdatedMessages || renderedPeer != nil {
                        return .MessageEntry(
                            index: index,
                            messages: updatedMessages,
                            readState: readState,
                            notificationSettings: notificationSettings,
                            isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                            embeddedInterfaceState: embeddedInterfaceState,
                            renderedPeer: renderedPeer ?? entryRenderedPeer,
                            presence: presence,
                            tagSummaryInfo: tagSummaryInfo,
                            forumTopicData: forumTopicData,
                            hasFailedMessages: hasFailedMessages,
                            isContact: isContact)
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }) {
                hasUpdates = true
            }
        }
        
        if !transaction.currentUpdatedPeerPresences.isEmpty {
            if self.orderedEntries.mutableScan({ entry in
                switch entry {
                case let .MessageEntry(index, messages, readState, notificationSettings, isRemovedFromTotalUnreadCount, embeddedInterfaceState, entryRenderedPeer, _, tagSummaryInfo, forumTopicData, hasFailedMessages, isContact):
                    var presencePeerId = entryRenderedPeer.peerId
                    if let peer = entryRenderedPeer.peers[entryRenderedPeer.peerId], let associatedPeerId = peer.associatedPeerId {
                        presencePeerId = associatedPeerId
                    }
                    if let presence = transaction.currentUpdatedPeerPresences[presencePeerId] {
                        return .MessageEntry(
                            index: index,
                            messages: messages,
                            readState: readState,
                            notificationSettings: notificationSettings,
                            isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                            embeddedInterfaceState: embeddedInterfaceState,
                            renderedPeer: entryRenderedPeer,
                            presence: presence,
                            tagSummaryInfo: tagSummaryInfo,
                            forumTopicData: forumTopicData,
                            hasFailedMessages: hasFailedMessages,
                            isContact: isContact
                        )
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }) {
                hasUpdates = true
            }
        }
        
        if !transaction.currentUpdatedMessageTagSummaries.isEmpty || !transaction.currentUpdatedMessageActionsSummaries.isEmpty, case let .group(groupId, pinned, maybeFilterPredicate) = self.space, let filterPredicate = maybeFilterPredicate, let filterMessageTagSummary = filterPredicate.messageTagSummary {
            var removeEntryIndices: [MutableChatListEntryIndex] = []
            let _ = self.orderedEntries.mutableScan { entry -> MutableChatListEntry? in
                let entryPeer: Peer
                let entryNotificationsPeerId: PeerId
                switch entry {
                case let .MessageEntry(_, _, _, _, _, _, entryRenderedPeer, _, _, _, _, _):
                    if let peer = entryRenderedPeer.peer {
                        entryPeer = peer
                        entryNotificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                    } else {
                        return nil
                    }
                case let .IntermediateMessageEntry(index, _):
                    if let peer = postbox.peerTable.get(index.messageIndex.id.peerId) {
                        entryPeer = peer
                        entryNotificationsPeerId = peer.notificationSettingsPeerId ?? peer.id
                    } else {
                        return nil
                    }
                case .HoleEntry:
                    return nil
                }
                
                let updatedMessageSummary = transaction.currentUpdatedMessageTagSummaries[MessageHistoryTagsSummaryKey(tag: filterMessageTagSummary.addCount.tag, peerId: entryPeer.id, threadId: nil, namespace: filterMessageTagSummary.addCount.namespace)]
                let updatedActionsSummary = transaction.currentUpdatedMessageActionsSummaries[PendingMessageActionsSummaryKey(type: filterMessageTagSummary.subtractCount.type, peerId: entryPeer.id, namespace: filterMessageTagSummary.subtractCount.namespace)]
                
                if updatedMessageSummary != nil || updatedActionsSummary != nil {
                    var isUnread: Bool
                    if postbox.seedConfiguration.peerSummaryIsThreadBased(entryPeer) {
                        isUnread = (postbox.peerThreadsSummaryTable.get(peerId: entryPeer.id)?.effectiveUnreadCount ?? 0) > 0
                    } else {
                        isUnread = postbox.readStateTable.getCombinedState(entryPeer.id)?.isUnread ?? false
                    }
                    
                    let globalNotificationSettingsValue: PostboxGlobalNotificationSettings
                    if let current = globalNotificationSettings {
                        globalNotificationSettingsValue = current
                    } else {
                        globalNotificationSettingsValue = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
                        globalNotificationSettings = globalNotificationSettingsValue
                    }
                    
                    let nowRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: entryPeer, peerSettings: postbox.peerNotificationSettingsTable.getEffective(entryPeer.id))
                    
                    let messageTagSummaryResult = resolveChatListMessageTagSummaryResultCalculation(postbox: postbox, peerId: entryPeer.id, threadId: nil, calculation: filterPredicate.messageTagSummary)
                    
                    let isIncluded = filterPredicate.includes(peer: entryPeer, groupId: groupId, isRemovedFromTotalUnreadCount: nowRemovedFromTotalUnreadCount, isUnread: isUnread, isContact: postbox.contactsTable.isContact(peerId: entryNotificationsPeerId), messageTagSummaryResult: messageTagSummaryResult)
                    if !isIncluded {
                        removeEntryIndices.append(entry.entryIndex)
                    }
                }
                return nil
            }
            if !removeEntryIndices.isEmpty {
                hasUpdates = true
                hadRemovals = true
                for index in removeEntryIndices {
                    let _ = self.orderedEntries.remove(index: index)
                }
            }
            var changedPeerIds = Set<PeerId>()
            for key in transaction.currentUpdatedMessageTagSummaries.keys {
                changedPeerIds.insert(key.peerId)
            }
            for key in transaction.currentUpdatedMessageTagSummaries.keys {
                changedPeerIds.insert(key.peerId)
            }
            for peerId in changedPeerIds {
                if let mainPeer = postbox.peerTable.get(peerId) {
                    var peers: [Peer] = [mainPeer]
                    for associatedId in postbox.reverseAssociatedPeerTable.get(peerId: mainPeer.id) {
                        if let associatedPeer = postbox.peerTable.get(associatedId) {
                            peers.append(associatedPeer)
                        }
                    }
                    assert(Set(peers.map { $0.id }).count == peers.count)
                    
                    var isUnread: Bool
                    if postbox.seedConfiguration.peerSummaryIsThreadBased(mainPeer) {
                        isUnread = (postbox.peerThreadsSummaryTable.get(peerId: peerId)?.effectiveUnreadCount ?? 0) > 0
                    } else {
                        isUnread = postbox.readStateTable.getCombinedState(peerId)?.isUnread ?? false
                    }
                    
                    let globalNotificationSettingsValue: PostboxGlobalNotificationSettings
                    if let current = globalNotificationSettings {
                        globalNotificationSettingsValue = current
                    } else {
                        globalNotificationSettingsValue = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
                        globalNotificationSettings = globalNotificationSettingsValue
                    }
                    
                    let nowRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: mainPeer, peerSettings: postbox.peerNotificationSettingsTable.getEffective(mainPeer.id))
                    
                    let messageTagSummaryResult = resolveChatListMessageTagSummaryResultCalculation(postbox: postbox, peerId: peerId, threadId: nil, calculation: filterPredicate.messageTagSummary)
                    
                    let isIncluded = filterPredicate.includes(peer: mainPeer, groupId: groupId, isRemovedFromTotalUnreadCount: nowRemovedFromTotalUnreadCount, isUnread: isUnread, isContact: postbox.contactsTable.isContact(peerId: peerId), messageTagSummaryResult: messageTagSummaryResult)
                    if isIncluded && self.orderedEntries.indicesForPeerId(mainPeer.id) == nil {
                        for peer in peers {
                            let tableEntry = postbox.chatListTable.getEntry(groupId: groupId, peerId: peer.id, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable)
                            if let entry = tableEntry {
                                if pinned.include == (entry.index.pinningIndex != nil) {
                                    if self.orderedEntries.indicesForPeerId(peer.id) == nil {
                                        switch entry {
                                        case let .message(index, messageIndex):
                                            if self.add(entry: .IntermediateMessageEntry(index: index, messageIndex: messageIndex)) {
                                                hasUpdates = true
                                            } else {
                                                hasUpdates = true
                                                hadRemovals = true
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if !transaction.currentUpdatedMessageTagSummaries.isEmpty || !transaction.currentUpdatedMessageActionsSummaries.isEmpty || !transaction.updatedPeerThreadsSummaries.isEmpty {
            if self.orderedEntries.mutableScan({ entry in
                switch entry {
                case let .MessageEntry(index, messages, readState, notificationSettings, isRemovedFromTotalUnreadCount, embeddedInterfaceState, entryRenderedPeer, presence, tagSummaryInfo, forumTopicData, hasFailedMessages, isContact):
                    var updatedChatListMessageTagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo] = tagSummaryInfo
                    var didUpdateSummaryInfo = false
                    
                    for (key, component) in self.summaryComponents.components {
                        var updatedTagSummaryCount: Int32?
                        if let tagSummary = component.tagSummary {
                            let key = MessageHistoryTagsSummaryKey(tag: key.tag, peerId: index.messageIndex.id.peerId, threadId: nil, namespace: tagSummary.namespace)
                            if let summary = transaction.currentUpdatedMessageTagSummaries[key] {
                                updatedTagSummaryCount = summary.count
                            }
                        }
                        
                        var updatedActionsSummaryCount: Int32?
                        if let actionsSummary = component.actionsSummary {
                            let key = PendingMessageActionsSummaryKey(type: key.actionType, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                            if let count = transaction.currentUpdatedMessageActionsSummaries[key] {
                                updatedActionsSummaryCount = count
                            }
                        }
                        
                        if updatedTagSummaryCount != nil || updatedActionsSummaryCount != nil {
                            updatedChatListMessageTagSummaryInfo[key] = ChatListMessageTagSummaryInfo(
                                tagSummaryCount: updatedTagSummaryCount ?? updatedChatListMessageTagSummaryInfo[key]?.tagSummaryCount,
                                actionsSummaryCount: updatedActionsSummaryCount ?? updatedChatListMessageTagSummaryInfo[key]?.actionsSummaryCount
                            )
                            didUpdateSummaryInfo = true
                        }
                    }
                    
                    var updatedReadState = readState
                    if let peer = postbox.peerTable.get(index.messageIndex.id.peerId), postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                        let summary = postbox.peerThreadsSummaryTable.get(peerId: peer.id)
                        
                        var count: Int32 = 0
                        var isMuted: Bool = false
                        if let summary = summary {
                            count = summary.totalUnreadCount
                            if count > 0 {
                                isMuted = !summary.hasUnmutedUnread
                            }
                        }
                        
                        updatedReadState = ChatListViewReadState(state: CombinedPeerReadState(states: [(0, .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: count, markedUnread: false))]), isMuted: isMuted)
                    } else {
                        updatedReadState = postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId).flatMap { state in
                            return ChatListViewReadState(state: state, isMuted: false)
                        }
                    }
                    
                    if updatedReadState != readState {
                        didUpdateSummaryInfo = true
                    }
                    
                    if didUpdateSummaryInfo {
                        return .MessageEntry(
                            index: index,
                            messages: messages,
                            readState: updatedReadState,
                            notificationSettings: notificationSettings,
                            isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                            embeddedInterfaceState: embeddedInterfaceState,
                            renderedPeer: entryRenderedPeer,
                            presence: presence,
                            tagSummaryInfo: updatedChatListMessageTagSummaryInfo,
                            forumTopicData: forumTopicData,
                            hasFailedMessages: hasFailedMessages,
                            isContact: isContact
                        )
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }) {
                hasUpdates = true
            }
        }
        
        if true || hadRemovals {
            self.fillSpace(postbox: postbox, currentTransaction: currentTransaction)
        }
        
        self.checkEntries(postbox: postbox)
        self.checkReplayEntries(postbox: postbox)
        
        return hasUpdates
    }
    
    private func checkEntries(postbox: PostboxImpl) {
        #if DEBUG
        if case .group(.root, .notPinned, nil) = self.space {
            let allEntries = self.orderedEntries.lowerOrAtAnchor + self.orderedEntries.higherThanAnchor
            if !allEntries.isEmpty {
                assert(allEntries.sorted(by: { $0.index < $1.index }) == allEntries)
                
                func mapEntry(_ entry: ChatListIntermediateEntry) -> MutableChatListEntry {
                    switch entry {
                    case let .message(index, messageIndex):
                        return .IntermediateMessageEntry(index: index, messageIndex: messageIndex)
                    case let .hole(hole):
                        return .HoleEntry(hole)
                    }
                }
                
                //let loadedEntries = postbox.chatListTable.entries(groupId: .root, from: (allEntries[0].index.predecessor, true), to: (allEntries[allEntries.count - 1].index.successor, true), peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable, count: 1000, predicate: nil).map(mapEntry)
                
                //assert(loadedEntries.map({ $0.index }) == allEntries.map({ $0.index }))
            }
        }
        #endif
    }
    
    private func checkReplayEntries(postbox: PostboxImpl) {
        #if DEBUG
        //let cleanState = ChatListViewSpaceState(postbox: postbox, space: self.space, anchorIndex: self.anchorIndex, summaryComponents: self.summaryComponents, halfLimit: self.halfLimit)
        //assert(self.orderedEntries.lowerOrAtAnchor.map { $0.index } == cleanState.orderedEntries.lowerOrAtAnchor.map { $0.index })
        //assert(self.orderedEntries.higherThanAnchor.map { $0.index } == cleanState.orderedEntries.higherThanAnchor.map { $0.index })
        #endif
    }
    
    private func add(entry: MutableChatListEntry) -> Bool {
        if self.anchorIndex >= entry.entryIndex {
            let insertionIndex = binaryInsertionIndex(self.orderedEntries.lowerOrAtAnchor, extract: { $0.entryIndex }, searchItem: entry.entryIndex)
            
            if insertionIndex < self.orderedEntries.lowerOrAtAnchor.count {
                if self.orderedEntries.lowerOrAtAnchor[insertionIndex].entryIndex == entry.entryIndex {
                    assertionFailure("Inserting an existing index is not allowed")
                    self.orderedEntries.setLowerOrAtAnchorAtArrayIndex(insertionIndex, to: entry)
                    return true
                }
            }
            
            if insertionIndex == 0 {
                return false
            }
            self.orderedEntries.insertLowerOrAtAnchorAtArrayIndex(insertionIndex, value: entry)
            if self.orderedEntries.lowerOrAtAnchor.count > self.halfLimit {
                self.orderedEntries.removeLowerOrAtAnchorAtArrayIndex(0)
            }
            return true
        } else {
            let insertionIndex = binaryInsertionIndex(orderedEntries.higherThanAnchor, extract: { $0.entryIndex }, searchItem: entry.entryIndex)
            
            if insertionIndex < self.orderedEntries.higherThanAnchor.count {
                if self.orderedEntries.higherThanAnchor[insertionIndex].entryIndex == entry.entryIndex {
                    assertionFailure("Inserting an existing index is not allowed")
                    self.orderedEntries.setHigherThanAnchorAtArrayIndex(insertionIndex, to: entry)
                    return true
                }
            }
            
            if insertionIndex == self.orderedEntries.higherThanAnchor.count {
                return false
            }
            self.orderedEntries.insertHigherThanAnchorAtArrayIndex(insertionIndex, value: entry)
            if self.orderedEntries.higherThanAnchor.count > self.halfLimit {
                self.orderedEntries.removeHigherThanAnchorAtArrayIndex(self.orderedEntries.higherThanAnchor.count - 1)
            }
            return true
        }
    }
}

private struct MutableChatListEntryIndex: Hashable, Comparable {
    var index: ChatListIndex
    var isMessage: Bool
    
    var predecessor: MutableChatListEntryIndex {
        return MutableChatListEntryIndex(index: self.index.predecessor, isMessage: self.isMessage)
    }
    
    var successor: MutableChatListEntryIndex {
        return MutableChatListEntryIndex(index: self.index.successor, isMessage: self.isMessage)
    }
    
    static let absoluteLowerBound = MutableChatListEntryIndex(index: .absoluteLowerBound, isMessage: true)
    static let absoluteUpperBound = MutableChatListEntryIndex(index: .absoluteUpperBound, isMessage: true)
    
    static func <(lhs: MutableChatListEntryIndex, rhs: MutableChatListEntryIndex) -> Bool {
        if lhs.index != rhs.index {
            return lhs.index < rhs.index
        } else if lhs.isMessage != rhs.isMessage {
            return lhs.isMessage
        } else {
            return false
        }
    }
}

private enum MutableChatListEntryEntityId: Hashable {
    case hole(MessageIndex)
    case peer(PeerId)
}

private extension MutableChatListEntry {
    var messagePeerId: PeerId? {
        switch self {
        case let .IntermediateMessageEntry(index, _):
            return index.messageIndex.id.peerId
        case let .MessageEntry(index, _, _, _, _, _, _, _, _, _, _, _):
            return index.messageIndex.id.peerId
        case .HoleEntry:
            return nil
        }
    }
    
    var entryIndex: MutableChatListEntryIndex {
        switch self {
        case let .IntermediateMessageEntry(index, _):
            return MutableChatListEntryIndex(index: index, isMessage: true)
        case let .MessageEntry(index, _, _, _, _, _, _, _, _, _, _, _):
            return MutableChatListEntryIndex(index: index, isMessage: true)
        case let .HoleEntry(hole):
            return MutableChatListEntryIndex(index: ChatListIndex(pinningIndex: nil, messageIndex: hole.index), isMessage: false)
        }
    }
    
    var entityId: MutableChatListEntryEntityId {
        switch self {
        case let .IntermediateMessageEntry(index, _):
            return .peer(index.messageIndex.id.peerId)
        case let .MessageEntry(index, _, _, _, _, _, _, _, _, _, _, _):
            return .peer(index.messageIndex.id.peerId)
        case let .HoleEntry(hole):
            return .hole(hole.index)
        }
    }
}

private struct OrderedChatListViewEntries {
    private let anchorIndex: ChatListIndex
    
    private(set) var lowerOrAtAnchor: [MutableChatListEntry]
    private(set) var higherThanAnchor: [MutableChatListEntry]
    
    private(set) var reverseIndices: [PeerId: [MutableChatListEntryIndex]] = [:]
    
    fileprivate init(anchorIndex: ChatListIndex, lowerOrAtAnchor: [MutableChatListEntry], higherThanAnchor: [MutableChatListEntry]) {
        self.anchorIndex = anchorIndex
        assert(!lowerOrAtAnchor.contains(where: { $0.index > anchorIndex }))
        assert(!higherThanAnchor.contains(where: { $0.index <= anchorIndex }))
        
        self.lowerOrAtAnchor = lowerOrAtAnchor
        self.higherThanAnchor = higherThanAnchor
        
        for entry in lowerOrAtAnchor {
            if let peerId = entry.messagePeerId {
                if self.reverseIndices[peerId] == nil {
                    self.reverseIndices[peerId] = [entry.entryIndex]
                } else {
                    self.reverseIndices[peerId]!.append(entry.entryIndex)
                }
            }
        }
        for entry in higherThanAnchor {
            if let peerId = entry.messagePeerId {
                if self.reverseIndices[peerId] == nil {
                    self.reverseIndices[peerId] = [entry.entryIndex]
                } else {
                    self.reverseIndices[peerId]!.append(entry.entryIndex)
                }
            }
        }
    }
    
    mutating func setLowerOrAtAnchorAtArrayIndex(_ index: Int, to value: MutableChatListEntry) {
        assert(value.index <= self.anchorIndex)
        
        let previousIndex = self.lowerOrAtAnchor[index].entryIndex
        let updatedIndex = value.entryIndex
        let previousPeerId = self.lowerOrAtAnchor[index].messagePeerId
        let updatedPeerId = value.messagePeerId
        
        self.lowerOrAtAnchor[index] = value
        
        if previousPeerId != updatedPeerId {
            if let previousPeerId = previousPeerId {
                self.reverseIndices[previousPeerId]?.removeAll(where: { $0 == previousIndex })
                if let isEmpty = self.reverseIndices[previousPeerId]?.isEmpty, isEmpty {
                    self.reverseIndices.removeValue(forKey: previousPeerId)
                }
            }
            if let updatedPeerId = updatedPeerId {
                if self.reverseIndices[updatedPeerId] == nil {
                    self.reverseIndices[updatedPeerId] = [updatedIndex]
                } else {
                    self.reverseIndices[updatedPeerId]!.append(updatedIndex)
                }
            }
        }
    }
    
    mutating func setHigherThanAnchorAtArrayIndex(_ index: Int, to value: MutableChatListEntry) {
        assert(value.index > self.anchorIndex)
        
        let previousIndex = self.higherThanAnchor[index].entryIndex
        let updatedIndex = value.entryIndex
        let previousPeerId = self.higherThanAnchor[index].messagePeerId
        let updatedPeerId = value.messagePeerId
        
        self.higherThanAnchor[index] = value
        
        if previousPeerId != updatedPeerId {
            if let previousPeerId = previousPeerId {
                self.reverseIndices[previousPeerId]?.removeAll(where: { $0 == previousIndex })
                if let isEmpty = self.reverseIndices[previousPeerId]?.isEmpty, isEmpty {
                    self.reverseIndices.removeValue(forKey: previousPeerId)
                }
            }
            if let updatedPeerId = updatedPeerId {
                if self.reverseIndices[updatedPeerId] == nil {
                    self.reverseIndices[updatedPeerId] = [updatedIndex]
                } else {
                    self.reverseIndices[updatedPeerId]!.append(updatedIndex)
                }
            }
        }
    }
    
    mutating func insertLowerOrAtAnchorAtArrayIndex(_ index: Int, value: MutableChatListEntry) {
        assert(value.index <= self.anchorIndex)
        self.lowerOrAtAnchor.insert(value, at: index)
        
        if let peerId = value.messagePeerId {
            if self.reverseIndices[peerId] == nil {
                self.reverseIndices[peerId] = [value.entryIndex]
            } else {
                self.reverseIndices[peerId]!.append(value.entryIndex)
            }
        }
    }
    
    mutating func insertHigherThanAnchorAtArrayIndex(_ index: Int, value: MutableChatListEntry) {
        assert(value.index > self.anchorIndex)
        self.higherThanAnchor.insert(value, at: index)
        
        if let peerId = value.messagePeerId {
            if self.reverseIndices[peerId] == nil {
                self.reverseIndices[peerId] = [value.entryIndex]
            } else {
                self.reverseIndices[peerId]!.append(value.entryIndex)
            }
        }
    }
    
    mutating func removeLowerOrAtAnchorAtArrayIndex(_ index: Int) {
        let previousIndex = self.lowerOrAtAnchor[index].entryIndex
        if let peerId = self.lowerOrAtAnchor[index].messagePeerId {
            self.reverseIndices[peerId]?.removeAll(where: { $0 == previousIndex })
            if let isEmpty = self.reverseIndices[peerId]?.isEmpty, isEmpty {
                self.reverseIndices.removeValue(forKey: peerId)
            }
        }
        
        self.lowerOrAtAnchor.remove(at: index)
    }
    
    mutating func removeHigherThanAnchorAtArrayIndex(_ index: Int) {
        let previousIndex = self.higherThanAnchor[index].entryIndex
        if let peerId = self.higherThanAnchor[index].messagePeerId {
            self.reverseIndices[peerId]?.removeAll(where: { $0 == previousIndex })
            if let isEmpty = self.reverseIndices[peerId]?.isEmpty, isEmpty {
                self.reverseIndices.removeValue(forKey: peerId)
            }
        }
        
        self.higherThanAnchor.remove(at: index)
    }
    
    func find(index: MutableChatListEntryIndex) -> MutableChatListEntry? {
        if let entryIndex = binarySearch(self.lowerOrAtAnchor, extract: { $0.entryIndex }, searchItem: index) {
            return self.lowerOrAtAnchor[entryIndex]
        } else if let entryIndex = binarySearch(self.higherThanAnchor, extract: { $0.entryIndex }, searchItem: index) {
            return self.higherThanAnchor[entryIndex]
        } else {
            return nil
        }
    }
    
    func indicesForPeerId(_ peerId: PeerId) -> [MutableChatListEntryIndex]? {
        return self.reverseIndices[peerId]
    }
    
    var first: MutableChatListEntry? {
        return self.lowerOrAtAnchor.first ?? self.higherThanAnchor.first
    }
    
    mutating func mutableScan(_ f: (MutableChatListEntry) -> MutableChatListEntry?) -> Bool {
        var anyUpdated = false
        for i in 0 ..< self.lowerOrAtAnchor.count {
            if let updated = f(self.lowerOrAtAnchor[i]) {
                self.setLowerOrAtAnchorAtArrayIndex(i, to: updated)
                anyUpdated = true
            }
        }
        for i in 0 ..< self.higherThanAnchor.count {
            if let updated = f(self.higherThanAnchor[i]) {
                self.setHigherThanAnchorAtArrayIndex(i, to: updated)
                anyUpdated = true
            }
        }
        return anyUpdated
    }
    
    mutating func update(index: MutableChatListEntryIndex, _ f: (MutableChatListEntry) -> MutableChatListEntry?) -> Bool {
        if let entryIndex = binarySearch(self.lowerOrAtAnchor, extract: { $0.entryIndex }, searchItem: index) {
            if let updated = f(self.lowerOrAtAnchor[entryIndex]) {
                assert(updated.index == self.lowerOrAtAnchor[entryIndex].index)
                self.setLowerOrAtAnchorAtArrayIndex(entryIndex, to: updated)
                return true
            }
        } else if let entryIndex = binarySearch(self.higherThanAnchor, extract: { $0.entryIndex }, searchItem: index) {
            if let updated = f(self.higherThanAnchor[entryIndex]) {
                assert(updated.index == self.lowerOrAtAnchor[entryIndex].index)
                self.setHigherThanAnchorAtArrayIndex(entryIndex, to: updated)
                return true
            }
        }
        return false
    }
    
    mutating func remove(index: MutableChatListEntryIndex) -> Bool {
        if let entryIndex = binarySearch(self.lowerOrAtAnchor, extract: { $0.entryIndex }, searchItem: index) {
            self.removeLowerOrAtAnchorAtArrayIndex(entryIndex)
            return true
        } else if let entryIndex = binarySearch(self.higherThanAnchor, extract: { $0.entryIndex }, searchItem: index) {
            self.removeHigherThanAnchorAtArrayIndex(entryIndex)
            return true
        } else {
            return false
        }
    }
}

final class ChatListViewSample {
    let entries: [MutableChatListEntry]
    let lower: MutableChatListEntry?
    let upper: MutableChatListEntry?
    let anchorIndex: ChatListIndex
    let hole: (PeerGroupId, ChatListHole)?
    
    fileprivate init(entries: [MutableChatListEntry], lower: MutableChatListEntry?, upper: MutableChatListEntry?, anchorIndex: ChatListIndex, hole: (PeerGroupId, ChatListHole)?) {
        self.entries = entries
        self.lower = lower
        self.upper = upper
        self.anchorIndex = anchorIndex
        self.hole = hole
    }
}

struct ChatListViewState {
    private let anchorIndex: MutableChatListEntryIndex
    private let summaryComponents: ChatListEntrySummaryComponents
    private let halfLimit: Int
    private var stateBySpace: [ChatListViewSpace: ChatListViewSpaceState] = [:]
    
    init(postbox: PostboxImpl, currentTransaction: Transaction, spaces: [ChatListViewSpace], anchorIndex: ChatListIndex, summaryComponents: ChatListEntrySummaryComponents, halfLimit: Int) {
        self.anchorIndex = MutableChatListEntryIndex(index: anchorIndex, isMessage: true)
        self.summaryComponents = summaryComponents
        self.halfLimit = halfLimit
        
        for space in spaces {
            self.stateBySpace[space] = ChatListViewSpaceState(postbox: postbox, currentTransaction: currentTransaction, space: space, anchorIndex: self.anchorIndex, summaryComponents: summaryComponents, halfLimit: halfLimit)
        }
    }
    
    func replay(postbox: PostboxImpl, currentTransaction: Transaction, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for (_, state) in self.stateBySpace {
            if state.replay(postbox: postbox, currentTransaction: currentTransaction, transaction: transaction) {
                updated = true
            }
        }
        return updated
    }
    
    private func sampleIndices() -> (lowerOrAtAnchor: [(ChatListViewSpace, Int)], higherThanAnchor: [(ChatListViewSpace, Int)]) {
        var previousAnchorIndices: [ChatListViewSpace: Int] = [:]
        var nextAnchorIndices: [ChatListViewSpace: Int] = [:]
        for (space, state) in self.stateBySpace {
            previousAnchorIndices[space] = state.orderedEntries.lowerOrAtAnchor.count - 1
            nextAnchorIndices[space] = 0
        }
        
        var backwardsResult: [(ChatListViewSpace, Int)] = []
        var backwardsResultIndices: [ChatListIndex] = []
        var result: [(ChatListViewSpace, Int)] = []
        var resultIndices: [ChatListIndex] = []
        
        while true {
            var minSpace: ChatListViewSpace?
            for (space, value) in previousAnchorIndices {
                if value != -1 {
                    if let minSpaceValue = minSpace {
                        if self.stateBySpace[space]!.orderedEntries.lowerOrAtAnchor[value].entryIndex > self.stateBySpace[minSpaceValue]!.orderedEntries.lowerOrAtAnchor[previousAnchorIndices[minSpaceValue]!].entryIndex {
                            minSpace = space
                        }
                    } else {
                        minSpace = space
                    }
                }
            }
            if let minSpace = minSpace {
                backwardsResult.append((minSpace, previousAnchorIndices[minSpace]!))
                backwardsResultIndices.append(self.stateBySpace[minSpace]!.orderedEntries.lowerOrAtAnchor[previousAnchorIndices[minSpace]!].index)
                previousAnchorIndices[minSpace]! -= 1
                if backwardsResult.count == self.halfLimit {
                    break
                }
            }
            
            if minSpace == nil {
                break
            }
        }
        
        while true {
            var maxSpace: ChatListViewSpace?
            for (space, value) in nextAnchorIndices {
                if value != self.stateBySpace[space]!.orderedEntries.higherThanAnchor.count {
                    if let maxSpaceValue = maxSpace {
                        if self.stateBySpace[space]!.orderedEntries.higherThanAnchor[value].entryIndex < self.stateBySpace[maxSpaceValue]!.orderedEntries.higherThanAnchor[nextAnchorIndices[maxSpaceValue]!].entryIndex {
                            maxSpace = space
                        }
                    } else {
                        maxSpace = space
                    }
                }
            }
            if let maxSpace = maxSpace {
                result.append((maxSpace, nextAnchorIndices[maxSpace]!))
                resultIndices.append(self.stateBySpace[maxSpace]!.orderedEntries.higherThanAnchor[nextAnchorIndices[maxSpace]!].index)
                nextAnchorIndices[maxSpace]! += 1
                if result.count == self.halfLimit {
                    break
                }
            }
            
            if maxSpace == nil {
                break
            }
        }
        
        backwardsResultIndices.reverse()
        assert(backwardsResultIndices.sorted() == backwardsResultIndices)
        assert(resultIndices.sorted() == resultIndices)
        let combinedIndices = (backwardsResultIndices + resultIndices)
        assert(combinedIndices.sorted() == combinedIndices)
        
        return (backwardsResult.reversed(), result)
    }
    
    func sample(postbox: PostboxImpl, currentTransaction: Transaction) -> ChatListViewSample {
        let combinedSpacesAndIndicesByDirection = self.sampleIndices()
        
        var result: [(ChatListViewSpace, MutableChatListEntry)] = []
        
        var sampledHoleIndices: [Int] = []
        var sampledAnchorBoundaryIndex: Int?
        
        var sampledHoleChatListIndices = Set<ChatListIndex>()
        
        let directions = [combinedSpacesAndIndicesByDirection.lowerOrAtAnchor, combinedSpacesAndIndicesByDirection.higherThanAnchor]
        for directionIndex in 0 ..< directions.count {
            outer: for i in 0 ..< directions[directionIndex].count {
                let (space, listIndex) = directions[directionIndex][i]
                
                let entry: MutableChatListEntry
                if directionIndex == 0 {
                    entry = self.stateBySpace[space]!.orderedEntries.lowerOrAtAnchor[listIndex]
                } else {
                    entry = self.stateBySpace[space]!.orderedEntries.higherThanAnchor[listIndex]
                }
                
                if entry.entryIndex >= self.anchorIndex {
                    sampledAnchorBoundaryIndex = result.count
                }
                
                switch entry {
                case let .IntermediateMessageEntry(index, messageIndex):
                    var peers = SimpleDictionary<PeerId, Peer>()
                    var notificationsPeerId = index.messageIndex.id.peerId
                    var presence: PeerPresence?
                    if let peer = postbox.peerTable.get(index.messageIndex.id.peerId) {
                        peers[peer.id] = peer
                        if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                            notificationsPeerId = notificationSettingsPeerId
                        }
                        if let associatedPeerId = peer.associatedPeerId {
                            if let associatedPeer = postbox.peerTable.get(associatedPeerId) {
                                peers[associatedPeer.id] = associatedPeer
                            }
                            presence = postbox.peerPresenceTable.get(associatedPeerId)
                        } else {
                            presence = postbox.peerPresenceTable.get(index.messageIndex.id.peerId)
                        }
                    }
                    let renderedPeer = RenderedPeer(peerId: index.messageIndex.id.peerId, peers: peers, associatedMedia: renderAssociatedMediaForPeers(postbox: postbox, peers: peers))
                    
                    var tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo] = [:]
                    for (key, component) in self.summaryComponents.components {
                        var tagSummaryCount: Int32?
                        var actionsSummaryCount: Int32?
                        
                        if let tagSummary = component.tagSummary {
                            let key = MessageHistoryTagsSummaryKey(tag: key.tag, peerId: index.messageIndex.id.peerId, threadId: nil, namespace: tagSummary.namespace)
                            if let summary = postbox.messageHistoryTagsSummaryTable.get(key) {
                                tagSummaryCount = summary.count
                            }
                        }
                        
                        if let actionsSummary = component.actionsSummary {
                            let key = PendingMessageActionsSummaryKey(type: key.actionType, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                            actionsSummaryCount = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(key.peerId, key.namespace, key.type))
                        }
                        
                        tagSummaryInfo[key] = ChatListMessageTagSummaryInfo(
                            tagSummaryCount: tagSummaryCount,
                            actionsSummaryCount: actionsSummaryCount
                        )
                    }
                    
                    let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(notificationsPeerId)
                    
                    let isRemovedFromTotalUnreadCount: Bool
                    if let peer = renderedPeer.peers[notificationsPeerId] {
                        isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: postbox.getGlobalNotificationSettings(transaction: currentTransaction), peer: peer, peerSettings: notificationSettings)
                    } else {
                        isRemovedFromTotalUnreadCount = false
                    }
                    
                    var renderedMessages: [Message] = []
                    if let messageIndex = messageIndex {
                        if let messageGroup = postbox.messageHistoryTable.getMessageGroup(at: messageIndex, limit: 10) {
                            renderedMessages.append(contentsOf: messageGroup.compactMap(postbox.renderIntermediateMessage))
                        }
                    }
                    
                    var forumTopicData: StoredMessageHistoryThreadInfo?
                    if let message = renderedMessages.first, let threadId = message.threadId {
                        forumTopicData = postbox.messageHistoryThreadIndexTable.get(peerId: message.id.peerId, threadId: threadId)
                    }
                    
                    let readState: ChatListViewReadState?
                    if let peer = postbox.peerTable.get(index.messageIndex.id.peerId), postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                        let summary = postbox.peerThreadsSummaryTable.get(peerId: peer.id)
                        
                        var count: Int32 = 0
                        var isMuted: Bool = false
                        if let summary = summary {
                            count = summary.totalUnreadCount
                            if count > 0 {
                                isMuted = !summary.hasUnmutedUnread
                            }
                        }
                        
                        readState = ChatListViewReadState(state: CombinedPeerReadState(states: [(0, .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: count, markedUnread: false))]), isMuted: isMuted)
                    } else {
                        readState = postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId).flatMap { state in
                            return ChatListViewReadState(state: state, isMuted: false)
                        }
                    }
                    
                    let updatedEntry: MutableChatListEntry = .MessageEntry(index: index, messages: renderedMessages, readState: readState, notificationSettings: notificationSettings, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, embeddedInterfaceState: postbox.peerChatInterfaceStateTable.get(index.messageIndex.id.peerId), renderedPeer: renderedPeer, presence: presence, tagSummaryInfo: tagSummaryInfo, forumTopicData: forumTopicData, hasFailedMessages: false, isContact: postbox.contactsTable.isContact(peerId: index.messageIndex.id.peerId))
                    if directionIndex == 0 {
                        self.stateBySpace[space]!.orderedEntries.setLowerOrAtAnchorAtArrayIndex(listIndex, to: updatedEntry)
                    } else {
                        self.stateBySpace[space]!.orderedEntries.setHigherThanAnchorAtArrayIndex(listIndex, to: updatedEntry)
                    }
                    result.append((space, updatedEntry))
                case .MessageEntry:
                    result.append((space, entry))
                case .HoleEntry:
                    if !sampledHoleChatListIndices.contains(entry.index) {
                        sampledHoleChatListIndices.insert(entry.index)
                        sampledHoleIndices.append(result.count)
                        
                        result.append((space, entry))
                    }
                }
            }
        }
        
        let allIndices = result.map { $0.1.entryIndex }
        let allIndicesSorted = allIndices.sorted()
        for i in 0 ..< allIndicesSorted.count {
            assert(allIndicesSorted[i] == allIndices[i])
        }
        
        if Set(allIndices).count != allIndices.count {
            var seenIndices = Set<MutableChatListEntryIndex>()
            var updatedResult: [(ChatListViewSpace, MutableChatListEntry)] = []
            for item in result {
                if !seenIndices.contains(item.1.entryIndex) {
                    seenIndices.insert(item.1.entryIndex)
                    updatedResult.append(item)
                }
            }
            result = updatedResult
            
            let allIndices = result.map { $0.1.entryIndex }
            let allIndicesSorted = allIndices.sorted()
            for i in 0 ..< allIndicesSorted.count {
                assert(allIndicesSorted[i] == allIndices[i])
            }
            assert(Set(allIndices).count == allIndices.count)
            
            assert(false)
        }
        
        var sampledHoleIndex: Int?
        if !sampledHoleIndices.isEmpty {
            if let sampledAnchorBoundaryIndex = sampledAnchorBoundaryIndex {
                var found = false
                for i in 0 ..< sampledHoleIndices.count {
                    if i >= sampledAnchorBoundaryIndex {
                        sampledHoleIndex = sampledHoleIndices[i]
                        found = true
                        break
                    }
                }
                if !found {
                    sampledHoleIndex = sampledHoleIndices.first
                }
            } else if let index = sampledHoleIndices.first {
                sampledHoleIndex = index
            }
        }
        
        var sampledHole: (ChatListViewSpace, ChatListHole)?
        if let index = sampledHoleIndex {
            let (space, entry) = result[index]
            if case let .HoleEntry(hole) = entry {
                sampledHole = (space, hole)
            } else {
                assertionFailure()
            }
        }
        
        var lower: MutableChatListEntry?
        if combinedSpacesAndIndicesByDirection.lowerOrAtAnchor.count >= self.halfLimit {
            lower = result[0].1
            result.removeFirst()
        }
        
        var upper: MutableChatListEntry?
        if combinedSpacesAndIndicesByDirection.higherThanAnchor.count >= self.halfLimit {
            upper = result.last?.1
            result.removeLast()
        }
        
        return ChatListViewSample(entries: result.map { $0.1 }, lower: lower, upper: upper, anchorIndex: self.anchorIndex.index, hole: sampledHole.flatMap { space, hole in
            switch space {
            case let .group(groupId, _, _):
                return (groupId, hole)
            case .peers:
                return nil
            }
        })
    }
}
