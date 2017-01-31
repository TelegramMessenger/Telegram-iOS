import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public func updatePeers(modifier: Modifier, peers: [Peer], update: (Peer?, Peer) -> Peer?) {
    modifier.updatePeersInternal(peers, update: { previous, updated in
        let peerId = updated.id
        
        let currentInclusion = modifier.getPeerChatListInclusion(peerId)
        var updatedInclusion: PeerChatListInclusion?
        switch peerId.namespace {
            case Namespaces.Peer.CloudUser:
                if currentInclusion == .notSpecified {
                    updatedInclusion = .ifHasMessages
                }
            case Namespaces.Peer.CloudGroup:
                if let group = updated as? TelegramGroup {
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
            modifier.updatePeerChatListInclusion(peerId, inclusion: updatedInclusion)
        }
        return update(previous, updated)
    })
}
