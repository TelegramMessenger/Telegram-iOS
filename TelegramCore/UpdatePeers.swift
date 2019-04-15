import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

func updatePeerChatInclusionWithMinTimestamp(transaction: Transaction, id: PeerId, minTimestamp: Int32) {
    let currentInclusion = transaction.getPeerChatListInclusion(id)
    var updatedInclusion: PeerChatListInclusion?
    switch currentInclusion {
        case .ifHasMessages, .ifHasMessagesOrOneOf:
            updatedInclusion = currentInclusion.withSetIfHasMessagesOrMaxMinTimestamp(minTimestamp)
        default:
            break
    }
    if let updatedInclusion = updatedInclusion {
        transaction.updatePeerChatListInclusion(id, inclusion: updatedInclusion)
    }
}

func updatePeerChatInclousionWithNewMessages(transaction: Transaction, id: PeerId) {
    let currentInclusion = transaction.getPeerChatListInclusion(id)
    var updatedInclusion: PeerChatListInclusion?
    switch currentInclusion {
        case .notSpecified:
            updatedInclusion = .ifHasMessages
        default:
            break
    }
    if let updatedInclusion = updatedInclusion {
        transaction.updatePeerChatListInclusion(id, inclusion: updatedInclusion)
    }
}

public func updatePeers(transaction: Transaction, peers: [Peer], update: (Peer?, Peer) -> Peer?) {
    transaction.updatePeersInternal(peers, update: { previous, updated in
        let peerId = updated.id
        
        let currentInclusion = transaction.getPeerChatListInclusion(peerId)
        var updatedInclusion: PeerChatListInclusion?
        switch peerId.namespace {
            case Namespaces.Peer.CloudUser:
                if currentInclusion == .notSpecified {
                    updatedInclusion = .ifHasMessages
                }
            case Namespaces.Peer.CloudGroup:
                if let group = updated as? TelegramGroup {
                    if group.flags.contains(.deactivated) {
                        updatedInclusion = .never
                    } else {
                        switch group.membership {
                            case .Member:
                                if group.creationDate != 0 {
                                    updatedInclusion = currentInclusion.withSetIfHasMessagesOrMaxMinTimestamp(group.creationDate)
                                } else {
                                    if currentInclusion == .notSpecified {
                                        updatedInclusion = .ifHasMessages
                                    }
                                }
                            default:
                                if currentInclusion == .notSpecified {
                                    updatedInclusion = .never
                                }
                        }
                    }
                } else {
                    assertionFailure()
                }
            case Namespaces.Peer.CloudChannel:
                if let channel = updated as? TelegramChannel {
                    switch channel.participationStatus {
                        case .member:
                            if channel.creationDate != 0 {
                                updatedInclusion = currentInclusion.withSetIfHasMessagesOrMaxMinTimestamp(channel.creationDate)
                            } else {
                                if currentInclusion == .notSpecified {
                                    updatedInclusion = .ifHasMessages
                                }
                            }
                        case .left:
                            updatedInclusion = .never
                        case .kicked where channel.creationDate == 0:
                            updatedInclusion = .never
                        default:
                            if currentInclusion == .notSpecified {
                                updatedInclusion = .never
                            }
                    }
                } else {
                    assertionFailure()
                }
            case Namespaces.Peer.SecretChat:
                if let secretChat = updated as? TelegramSecretChat {
                    if currentInclusion == .notSpecified {
                        updatedInclusion = currentInclusion.withSetIfHasMessagesOrMaxMinTimestamp(secretChat.creationDate)
                    }
                } else {
                    assertionFailure()
                }
            default:
                assertionFailure()
                break
        }
        if let updatedInclusion = updatedInclusion {
            transaction.updatePeerChatListInclusion(peerId, inclusion: updatedInclusion)
        }
        return update(previous, updated)
    })
}

func updatePeerPresences(transaction: Transaction, accountPeerId: PeerId, peerPresences: [PeerId: PeerPresence]) {
    var peerPresences = peerPresences
    if peerPresences[accountPeerId] != nil {
        peerPresences.removeValue(forKey: accountPeerId)
    }
    transaction.updatePeerPresencesInternal(presences: peerPresences, merge: { previous, updated in
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
