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
        if let channel = updated as? TelegramChannel {
            let previousGroupId = (previous as? TelegramChannel)?.peerGroupId
            if previousGroupId != channel.peerGroupId {
                transaction.updatePeerGroupId(peerId, groupId: channel.peerGroupId)
            }
        }
        return update(previous, updated)
    })
}

func updatePeerPresences(transaction: Transaction, accountPeerId: PeerId, peerPresences: [PeerId: PeerPresence]) {
    var peerPresences = peerPresences
    if peerPresences[accountPeerId] != nil {
        peerPresences.removeValue(forKey: accountPeerId)
    }
    transaction.updatePeerPresencesInternal(peerPresences)
}
