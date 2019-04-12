import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public enum EarliestUnseenPersonalMentionMessageResult {
    case loading
    case result(MessageId?)
}

public func earliestUnseenPersonalMentionMessage(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
    return earliestUnseenPersonalMentionMessage(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, locally: false)
}

private func earliestUnseenPersonalMentionMessage(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, locally: Bool) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
    return postbox.transaction { transaction -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
        var resultMessage: Message?
        var resultHole: MessageHistoryViewPeerHole?
        transaction.scanMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage, { message in
            for attribute in message.attributes {
                if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                    resultMessage = message
                    return false
                }
            }
            return true
        })
        
        if let resultMessage = resultMessage {
            var invalidateHistoryPts: Int32?
            
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                if let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
                    if let invalidatedPts = channelState.invalidatedPts {
                        var messagePts: Int32?
                        for attribute in resultMessage.attributes {
                            if let attribute = attribute as? ChannelMessageStateVersionAttribute {
                                messagePts = attribute.pts
                                break
                            }
                        }
                        
                        if let messagePts = messagePts {
                            if messagePts < invalidatedPts {
                                invalidateHistoryPts = invalidatedPts
                            }
                        } else {
                            invalidateHistoryPts = invalidatedPts
                        }
                    }
                }
            }
            
            if !locally, let _ = invalidateHistoryPts {
                let validateSignal = fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(network), postbox: postbox, peerId: peerId, namespace: Namespaces.Message.Cloud, direction: .range(start: MessageId(peerId: resultMessage.id.peerId, namespace: resultMessage.id.namespace, id: resultMessage.id.id - 1), end: MessageId(peerId: resultMessage.id.peerId, namespace: resultMessage.id.namespace, id: Int32.max - 1)), space: .tag(.unseenPersonalMessage), limit: 100)
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
                |> mapToSignal { _ -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
                    return .complete()
                }
                |> then(
                    earliestUnseenPersonalMentionMessage(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, locally: true)
                )
                return .single(.loading) |> then(validateSignal)
            } else {
                return .single(.result(resultMessage.id))
            }
        } else if let resultHole = resultHole, !locally {
            let holeRange = 1 ... Int32(resultHole.indices[resultHole.indices.endIndex] - 1)
            let validateSignal = fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(network), postbox: postbox, peerId: peerId, namespace: Namespaces.Message.Cloud, direction: .range(start: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), end: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32.max - 1)), space: .tag(.unseenPersonalMessage))
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
            |> mapToSignal { _ -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
                return .complete()
            }
            |> then(
                earliestUnseenPersonalMentionMessage(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, locally: true)
            )
            return .single(.loading) |> then(validateSignal)
        } else if let summary = transaction.getMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), summary.count > 0 {
            transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: 0, maxId: summary.range.maxId)
        }
        
        return .single(.result(nil))
    } |> switchToLatest
}
