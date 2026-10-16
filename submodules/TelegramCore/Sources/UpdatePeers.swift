import Foundation
import Postbox
internal import TelegramApi

func isPeerHiddenByCollapsedCommunity(transaction: Transaction, peerId: PeerId, peer: Peer? = nil) -> Bool {
    if let channel = (peer ?? transaction.getPeer(peerId)) as? TelegramChannel, let linkedCommunityId = channel.linkedCommunityId {
        if let community = transaction.getPeer(linkedCommunityId) as? TelegramCommunity, community.collapsedInDialogs == true {
            return true
        }
    }

    return false
}

/// Membership decides, not `in_news`. A joined channel appears everywhere, in News or not. A channel marked
/// `in_news` without being joined is a light join (joinChannel for_news): it is followed in News and, like any
/// channel the user is not a member of, stays out of Chats.
func channelShouldBeExcludedFromChatList(_ channel: TelegramChannel, isHiddenByCollapsedCommunity: () -> Bool) -> Bool {
    switch channel.participationStatus {
    case .member:
        return isHiddenByCollapsedCommunity()
    default:
        return true
    }
}

func shouldExcludePeerFromChatList(transaction: Transaction, peerId: PeerId, peer: Peer? = nil) -> Bool {
    guard let peer = peer ?? transaction.getPeer(peerId) else {
        return false
    }

    if let group = peer as? TelegramGroup {
        if group.flags.contains(.deactivated) {
            return true
        }
        switch group.membership {
        case .Member:
            return false
        default:
            return true
        }
    } else if let channel = peer as? TelegramChannel {
        return channelShouldBeExcludedFromChatList(channel, isHiddenByCollapsedCommunity: {
            return isPeerHiddenByCollapsedCommunity(transaction: transaction, peerId: peerId, peer: channel)
        })
    } else if let community = peer as? TelegramCommunity {
        return community.participationStatus != .member || community.collapsedInDialogs != true
    } else {
        return false
    }
}

func updatePeerChatInclusionWithMinTimestamp(transaction: Transaction, id: PeerId, minTimestamp: Int32, forceRootGroupIfNotExists: Bool, peer: Peer? = nil) {
    if shouldExcludePeerFromChatList(transaction: transaction, peerId: id, peer: peer) {
        transaction.updatePeerChatListInclusion(id, inclusion: .notIncluded)
        return
    }
    
    let currentInclusion = transaction.getPeerChatListInclusion(id)
    var updatedInclusion: PeerChatListInclusion?
    switch currentInclusion {
        case let .ifHasMessagesOrOneOf(groupId, pinningIndex, currentMinTimestamp):
            let updatedMinTimestamp: Int32
            if let currentMinTimestamp = currentMinTimestamp {
                if minTimestamp > currentMinTimestamp {
                    updatedMinTimestamp = minTimestamp
                } else {
                    updatedMinTimestamp = currentMinTimestamp
                }
            } else {
                updatedMinTimestamp = minTimestamp
            }
            updatedInclusion = .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: pinningIndex, minTimestamp: updatedMinTimestamp)
        default:
            if forceRootGroupIfNotExists {
                updatedInclusion = .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: minTimestamp)
            }
    }
    if let updatedInclusion = updatedInclusion {
        transaction.updatePeerChatListInclusion(id, inclusion: updatedInclusion)
    }
}

func minTimestampForPeerInclusion(_ peer: Peer) -> Int32? {
    if let group = peer as? TelegramGroup {
        return group.creationDate
    } else if let channel = peer as? TelegramChannel {
        return channel.creationDate
    } else if let community = peer as? TelegramCommunity {
        return community.creationDate
    } else {
        return nil
    }
}

func updateCommunityChatListInclusion(transaction: Transaction, communityId: EnginePeer.Id, collapsedInDialogs: Bool, minTimestamp: Int32?) {
    if !collapsedInDialogs {
        if transaction.getPeerChatListInclusion(communityId) != .notIncluded {
            transaction.updatePeerChatListInclusion(communityId, inclusion: .notIncluded)
        }
        return
    }
    
    guard let community = transaction.getPeer(communityId) else {
        return
    }

    let currentInclusion = transaction.getPeerChatListInclusion(communityId)
    let effectiveMinTimestamp = minTimestamp ?? minTimestampForPeerInclusion(community)
    guard let effectiveMinTimestamp else {
        return
    }
    switch currentInclusion {
    case let .ifHasMessagesOrOneOf(groupId, pinningIndex, currentMinTimestamp):
        let updatedMinTimestamp: Int32
        if let currentMinTimestamp = currentMinTimestamp {
            if effectiveMinTimestamp > currentMinTimestamp {
                updatedMinTimestamp = effectiveMinTimestamp
            } else {
                updatedMinTimestamp = currentMinTimestamp
            }
        } else {
            updatedMinTimestamp = effectiveMinTimestamp
        }
        transaction.updatePeerChatListInclusion(communityId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: pinningIndex, minTimestamp: updatedMinTimestamp))
    default:
        transaction.updatePeerChatListInclusion(communityId, inclusion: .ifHasMessagesOrOneOf(
            groupId: .root,
            pinningIndex: transaction.getPeerChatListIndex(communityId)?.1.pinningIndex,
            minTimestamp: effectiveMinTimestamp
        ))
    }
}

func shouldKeepUserStoriesInFeed(peerId: PeerId, isContactOrMember: Bool) -> Bool {
    if peerId.namespace == Namespaces.Peer.CloudUser && (peerId.id._internalGetInt64Value() == 777000 || peerId.id._internalGetInt64Value() == 333000) {
        return true
    }
    return isContactOrMember
}

func updatePeers(transaction: Transaction, accountPeerId: PeerId, peers: AccumulatedPeers) {
    var parsedPeers: [Peer] = []
    for (_, user) in peers.users {
        if let telegramUser = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
            parsedPeers.append(telegramUser)
            switch user {
            case let .user(userData):
                let (flags, flags2, storiesMaxId) = (userData.flags, userData.flags2, userData.storiesMaxId)
                let isMin = (flags & (1 << 20)) != 0
                let storiesUnavailable = (flags2 & (1 << 4)) != 0
                
                if let storiesMaxId {
                    switch storiesMaxId {
                    case let .recentStory(recentStoryData):
                        let (flags, maxId) = (recentStoryData.flags, recentStoryData.maxId)
                        if let maxId {
                            transaction.setStoryItemsInexactMaxId(peerId: user.peerId, id: maxId, hasLiveItems: (flags & (1 << 0)) != 0)
                        } else {
                            if !isMin && storiesUnavailable {
                                transaction.clearStoryItemsInexactMaxId(peerId: user.peerId)
                            }
                        }
                    }
                } else if !isMin && storiesUnavailable {
                    transaction.clearStoryItemsInexactMaxId(peerId: user.peerId)
                }
                
                if !isMin {
                    let isContact = (flags & (1 << 11)) != 0
                    _internal_updatePeerIsContact(transaction: transaction, user: telegramUser, isContact: isContact)
                }
            case .userEmpty:
                break
            }
        }
    }
    for (_, chat) in peers.chats {
        switch chat {
        case let .channel(channelData):
            let (flags, flags2, storiesMaxId) = (channelData.flags, channelData.flags2, channelData.storiesMaxId)
            let isMin = (flags & (1 << 12)) != 0
            let storiesUnavailable = (flags2 & (1 << 3)) != 0
            
            if let storiesMaxId {
                switch storiesMaxId {
                case let .recentStory(recentStoryData):
                    let (flags, maxId) = (recentStoryData.flags, recentStoryData.maxId)
                    if let maxId {
                        transaction.setStoryItemsInexactMaxId(peerId: chat.peerId, id: maxId, hasLiveItems: (flags & (1 << 0)) != 0)
                    } else {
                        if !isMin && storiesUnavailable {
                            transaction.clearStoryItemsInexactMaxId(peerId: chat.peerId)
                        }
                    }
                }
            } else if !isMin && storiesUnavailable {
                transaction.clearStoryItemsInexactMaxId(peerId: chat.peerId)
            }
            
            if let pinnedUpdate = cachedPinnedMessageIdUpdate(chat: chat) {
                transaction.updatePeerCachedData(peerIds: [chat.peerId], update: { peerId, current in
                    return cachedChannelData(applying: pinnedUpdate, peerId: peerId, to: current)
                })
            }
        default:
            break
        }
    }
    let now = CFAbsoluteTimeGetCurrent()
    for (_, peer) in peers.peers {
        if let channel = peer as? TelegramChannel {
            // A server channel keeps the client's own recent Add to News / Remove from News (ChannelInNewsLocalChanges).
            parsedPeers.append(channelApplyingLocalInNews(channel, localInNews: ChannelInNewsLocalChanges.shared.localInNews(accountPeerId: accountPeerId, channelId: channel.id, at: now)))
        } else {
            parsedPeers.append(peer)
        }
    }
    updatePeersCustom(transaction: transaction, peers: parsedPeers, update: { _, updated in updated })
    
    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peers.users)
}

func _internal_updatePeerIsContact(transaction: Transaction, user: TelegramUser, isContact: Bool) {
    let previousValue = shouldKeepUserStoriesInFeed(peerId: user.id, isContactOrMember: transaction.isPeerContact(peerId: user.id))
    let updatedValue = shouldKeepUserStoriesInFeed(peerId: user.id, isContactOrMember: isContact)
    
    if previousValue != updatedValue, let storiesHidden = user.storiesHidden {
        if updatedValue {
            if storiesHidden {
                if transaction.storySubscriptionsContains(key: .filtered, peerId: user.id) {
                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                    peerIds.removeAll(where: { $0 == user.id })
                    transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                }
                if !transaction.storySubscriptionsContains(key: .hidden, peerId: user.id) {
                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                    if !peerIds.contains(user.id) {
                        peerIds.append(user.id)
                        transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                    }
                }
            } else {
                if transaction.storySubscriptionsContains(key: .hidden, peerId: user.id) {
                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                    peerIds.removeAll(where: { $0 == user.id })
                    transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                }
                if !transaction.storySubscriptionsContains(key: .filtered, peerId: user.id) {
                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                    if !peerIds.contains(user.id) {
                        peerIds.append(user.id)
                        transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                    }
                }
            }
        } else {
            if transaction.storySubscriptionsContains(key: .filtered, peerId: user.id) {
                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                peerIds.removeAll(where: { $0 == user.id })
                transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
            }
            if transaction.storySubscriptionsContains(key: .hidden, peerId: user.id) {
                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                peerIds.removeAll(where: { $0 == user.id })
                transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
            }
        }
    }
}

private func _internal_updateChannelMembership(transaction: Transaction, channel: TelegramChannel, isMember: Bool, justJoined: Bool) {
    if isMember, let storiesHidden = channel.storiesHidden {
        if storiesHidden {
            if transaction.storySubscriptionsContains(key: .filtered, peerId: channel.id) {
                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                peerIds.removeAll(where: { $0 == channel.id })
                transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
            }
            if !transaction.storySubscriptionsContains(key: .hidden, peerId: channel.id) {
                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                if !peerIds.contains(channel.id) {
                    peerIds.append(channel.id)
                    transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                }
            }
        } else {
            if transaction.storySubscriptionsContains(key: .hidden, peerId: channel.id) {
                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                peerIds.removeAll(where: { $0 == channel.id })
                transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
            }
            if !transaction.storySubscriptionsContains(key: .filtered, peerId: channel.id) {
                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                if !peerIds.contains(channel.id) {
                    peerIds.append(channel.id)
                    transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                }
            }
        }
        
        if justJoined {
            _internal_addSynchronizePeerStoriesOperation(peerId: channel.id, transaction: transaction)
        }
    } else {
        if transaction.storySubscriptionsContains(key: .filtered, peerId: channel.id) {
            var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
            peerIds.removeAll(where: { $0 == channel.id })
            transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
        }
        if transaction.storySubscriptionsContains(key: .hidden, peerId: channel.id) {
            var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
            peerIds.removeAll(where: { $0 == channel.id })
            transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
        }
    }
}

public func updatePeersCustom(transaction: Transaction, peers: [Peer], update: (Peer?, Peer) -> Peer?) {
    transaction.updatePeersInternal(peers, update: { previous, updated in
        let peerId = updated.id
        
        var updated = updated
        
        if let previous = previous as? TelegramUser, let updatedUser = updated as? TelegramUser {
            updated = TelegramUser.merge(lhs: previous, rhs: updatedUser)
        }
        
        if let updatedChannel = updated as? TelegramChannel {
            var wasMember = false
            var wasHidden: Bool?
            if let previous = previous as? TelegramChannel {
                wasMember = previous.participationStatus == .member
                wasHidden = previous.storiesHidden
                updated = mergeChannel(lhs: previous, rhs: updatedChannel)
            }
            
            if let updated = updated as? TelegramChannel {
                let isMember = updated.participationStatus == .member
                if isMember != wasMember || updated.storiesHidden != wasHidden {
                    _internal_updateChannelMembership(transaction: transaction, channel: updated, isMember: isMember, justJoined: previous == nil || wasHidden == nil)
                }
                // The channel still holds the read state it had as a non-member
                // (NonMemberChannelReadState.swift), and the join may not fetch the dialog.
                if channelJoinNeedsServerReadState(previous: previous, updated: updated) {
                    transaction.setNeedsIncomingReadStateSynchronization(peerId)
                }
            }
        }
        if let updatedCommunity = updated as? TelegramCommunity {
            updated = mergeCommunity(lhs: previous as? TelegramCommunity, rhs: updatedCommunity)
        }
        
        switch peerId.namespace {
            case Namespaces.Peer.CloudUser:
                if let updated = updated as? TelegramUser, let previous = previous as? TelegramUser {
                    if let storiesHidden = updated.storiesHidden, storiesHidden != previous.storiesHidden {
                        if storiesHidden {
                            if transaction.storySubscriptionsContains(key: .filtered, peerId: updated.id) {
                                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                                peerIds.removeAll(where: { $0 == updated.id })
                                transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                                
                                if !transaction.storySubscriptionsContains(key: .hidden, peerId: updated.id) {
                                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                                    if !peerIds.contains(updated.id) {
                                        peerIds.append(updated.id)
                                        transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                                    }
                                }
                            }
                        } else {
                            if transaction.storySubscriptionsContains(key: .hidden, peerId: updated.id) {
                                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                                peerIds.removeAll(where: { $0 == updated.id })
                                transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                                
                                if !transaction.storySubscriptionsContains(key: .filtered, peerId: updated.id) {
                                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                                    if !peerIds.contains(updated.id) {
                                        peerIds.append(updated.id)
                                        transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                                    }
                                }
                            }
                        }
                    }
                }
            case Namespaces.Peer.CloudGroup:
                if let group = updated as? TelegramGroup {
                    if group.flags.contains(.deactivated) {
                        transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                    } else {
                        switch group.membership {
                            case .Member:
                                updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: group.creationDate, forceRootGroupIfNotExists: false, peer: group)
                            default:
                                transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        }
                    }
                } else {
                    assertionFailure()
                }
            case Namespaces.Peer.CloudChannel:
                if let channel = updated as? TelegramChannel {
                    if case .personal = channel.accessHash {
                        switch channel.participationStatus {
                        case .member:
                            updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: channel.creationDate, forceRootGroupIfNotExists: true, peer: channel)
                        case .left:
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        case .kicked where channel.creationDate == 0:
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        default:
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        }
                    }
                } else if let community = updated as? TelegramCommunity {
                    if case .personal = community.accessHash {
                        switch community.participationStatus {
                        case .member:
                            break
                        case .left:
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        case .kicked where community.creationDate == 0:
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        default:
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        }
                    }
                } else {
                    assertionFailure()
                }
            case Namespaces.Peer.SecretChat:
                if let secretChat = updated as? TelegramSecretChat {
                    let isActive: Bool
                    switch secretChat.embeddedState {
                        case .active, .handshake:
                            isActive = true
                        case .terminated:
                            isActive = false
                    }
                    updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: secretChat.creationDate, forceRootGroupIfNotExists: isActive, peer: secretChat)
                } else {
                    assertionFailure()
                }
            default:
                assertionFailure()
                break
        }
        
        return update(previous, updated)
    })
}

func updatePeerPresences(transaction: Transaction, accountPeerId: PeerId, peerPresences: [PeerId: Api.User]) {
    var parsedPresences: [PeerId: PeerPresence] = [:]
    for (peerId, user) in peerPresences {
        guard let presence = TelegramUserPresence(apiUser: user) else {
            continue
        }
        switch presence.status {
        case .present:
            parsedPresences[peerId] = presence
        default:
            switch user {
            case let .user(userData):
                let flags = userData.flags
                let isMin = (flags & (1 << 20)) != 0
                if isMin, let _ = transaction.getPeerPresence(peerId: peerId) {
                } else {
                    parsedPresences[peerId] = presence
                }
            default:
                break
            }
        }
    }
        
    parsedPresences.removeValue(forKey: accountPeerId)
        
    transaction.updatePeerPresencesInternal(presences: parsedPresences, merge: { previous, updated in
        if let previous = previous as? TelegramUserPresence, let updated = updated as? TelegramUserPresence, previous.lastActivity != updated.lastActivity {
            return TelegramUserPresence(status: updated.status, lastActivity: max(previous.lastActivity, updated.lastActivity))
        }
        return updated
    })
}

func updatePeerPresencesClean(transaction: Transaction, accountPeerId: PeerId, peerPresences: [PeerId: UpdatedApiPresence]) {
    var parsedPresences: [PeerId: PeerPresence] = [:]
    for (peerId, status) in peerPresences {
        let presence = TelegramUserPresence(apiStatus: status.status)
        switch presence.status {
        case .present:
            parsedPresences[peerId] = presence
        default:
            if status.isMin, let _ = transaction.getPeerPresence(peerId: peerId) {
            } else {
                parsedPresences[peerId] = presence
            }
        }
    }
    
    if parsedPresences[accountPeerId] != nil {
        parsedPresences.removeValue(forKey: accountPeerId)
    }
    
    transaction.updatePeerPresencesInternal(presences: parsedPresences, merge: { previous, updated in
        if let previous = previous as? TelegramUserPresence, let updated = updated as? TelegramUserPresence, previous.lastActivity != updated.lastActivity {
            return TelegramUserPresence(status: updated.status, lastActivity: max(previous.lastActivity, updated.lastActivity))
        }
        return updated
    })
}

func updatePeerPresenceLastActivities(transaction: Transaction, accountPeerId: PeerId, activities: [PeerId: Int32]) {
    var activities = activities
    if activities[accountPeerId] != nil {
        activities.removeValue(forKey: accountPeerId)
    }
    for (peerId, timestamp) in activities {
        transaction.updatePeerPresenceInternal(peerId: peerId, update: { previous in
            if let previous = previous as? TelegramUserPresence, previous.lastActivity < timestamp {
                var updatedStatus = previous.status
                switch updatedStatus {
                    case let .present(until):
                        if until < timestamp {
                            updatedStatus = .present(until: timestamp)
                        }
                    default:
                        break
                }
                return TelegramUserPresence(status: updatedStatus, lastActivity: timestamp)
            }
            return previous
        })
    }
}

func updateContacts(transaction: Transaction, apiUsers: [Api.User]) {
    if apiUsers.isEmpty {
        return
    }
    var contactIds = transaction.getContactPeerIds()
    var updated = false
    for user in apiUsers {
        var isContact: Bool?
        switch user {
        case let .user(userData):
            let flags = userData.flags
            if (flags & (1 << 20)) == 0 {
                isContact = (flags & (1 << 11)) != 0
            }
        case .userEmpty:
            isContact = false
        }
        if let isContact = isContact {
            if isContact {
                if !contactIds.contains(user.peerId) {
                    contactIds.insert(user.peerId)
                    updated = true
                }
            } else {
                if contactIds.contains(user.peerId) {
                    contactIds.remove(user.peerId)
                    updated = true
                }
            }
        }
    }
    if updated {
        transaction.replaceContactPeerIds(contactIds)
    }
}
