import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

// Applies a stop to the live draft at `peerAndThreadId`. Shared by the incoming
// sendMessageStopDraftAction update and by the local Stop button, which cannot wait for a
// server echo: the initiating session does not receive one.
//
// A non-matching randomId is ignored — it refers to a draft that has already been replaced.
func applyTypingDraftStop(transaction: Transaction, peerAndThreadId: PeerAndThreadId, randomId: Int64) {
    guard let current = transaction.getCurrentTypingDraft(location: peerAndThreadId), current.id == randomId else {
        return
    }
    let keepOnStop = typingDraftKeepOnStop(current.attributes)

    // A draft in a thread is stored under both its own key and the peer-wide one, the way
    // AddPeerLiveTypingDraftUpdate writes it. Stopping only one would leave a live copy.
    var locations = Set<PeerAndThreadId>()
    locations.insert(peerAndThreadId)
    if peerAndThreadId.threadId != nil {
        locations.insert(PeerAndThreadId(peerId: peerAndThreadId.peerId, threadId: nil))
    }

    transaction.combineTypingDrafts(locations: locations, update: { _, current in
        guard let current, current.id == randomId else {
            return current
        }
        if !keepOnStop {
            return nil
        }
        // Same random_id, so combineTypingDrafts keeps the stableId and only bumps the
        // version: the bubble stays put and nothing re-animates.
        return stoppedTypingDraft(current)
    })
}

func typingDraftKeepOnStop(_ attributes: [MessageAttribute]) -> Bool {
    for attribute in attributes {
        if let attribute = attribute as? TypingDraftMessageAttribute {
            return attribute.keepOnStop
        }
    }
    return false
}

// Rewrites a draft tuple as stopped: the Stop button goes away (canStop), it stops gating
// outgoing messages and stops expiring (isStopped).
func stoppedTypingDraft(_ value: (id: Int64, namespace: MessageId.Namespace, threadId: Int64?, authorId: PeerId, timestamp: Int32, text: String, attributes: [MessageAttribute], isStopped: Bool)) -> (id: Int64, namespace: MessageId.Namespace, threadId: Int64?, authorId: PeerId, timestamp: Int32, text: String, attributes: [MessageAttribute], isStopped: Bool) {
    var attributes: [MessageAttribute] = []
    for attribute in value.attributes {
        if let attribute = attribute as? TypingDraftMessageAttribute {
            attributes.append(TypingDraftMessageAttribute(randomId: attribute.randomId, canStop: false, keepOnStop: attribute.keepOnStop, isStopped: true))
        } else {
            attributes.append(attribute)
        }
    }
    return (value.id, value.namespace, value.threadId, value.authorId, value.timestamp, value.text, attributes, true)
}

func _internal_stopIncomingTypingDraft(postbox: Postbox, network: Network, peerId: PeerId, threadId: Int64?) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> (Api.InputPeer, Int64)? in
        let peerAndThreadId = PeerAndThreadId(peerId: peerId, threadId: threadId)
        guard let current = transaction.getCurrentTypingDraft(location: peerAndThreadId) else {
            return nil
        }
        var canStop = false
        for attribute in current.attributes {
            if let attribute = attribute as? TypingDraftMessageAttribute {
                canStop = attribute.canStop
                break
            }
        }
        guard canStop else {
            return nil
        }
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }

        // Optimistic: the server does not echo this update back to the initiating session,
        // so the local store is the only thing that can hide the button and the draft. No
        // revert on failure — the draft is ephemeral, and resurrecting content the user
        // just dismissed is worse than a stop the server never heard about.
        applyTypingDraftStop(transaction: transaction, peerAndThreadId: peerAndThreadId, randomId: current.id)

        return (inputPeer, current.id)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let (inputPeer, randomId) = result else {
            return .complete()
        }
        var flags: Int32 = 0
        let topMessageId = threadId.flatMap { Int32(clamping: $0) }
        if topMessageId != nil {
            flags |= 1 << 0
        }
        return network.request(Api.functions.messages.setTyping(flags: flags, peer: inputPeer, topMsgId: topMessageId, action: .sendMessageStopDraftAction(.init(randomId: randomId))))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}
