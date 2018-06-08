import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func applyMaxReadIndexInteractively(postbox: Postbox, stateManager: AccountStateManager, index: MessageIndex) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        applyMaxReadIndexInteractively(modifier: modifier, stateManager: stateManager, index: index)
    }
}
    
func applyMaxReadIndexInteractively(modifier: Modifier, stateManager: AccountStateManager, index: MessageIndex)  {
    let messageIds = modifier.applyInteractiveReadMaxIndex(index)
    if index.id.peerId.namespace == Namespaces.Peer.SecretChat {
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        for id in messageIds {
            if let message = modifier.getMessage(id) {
                for attribute in message.attributes {
                    if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                        if (attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0) && !message.containsSecretMedia {
                            modifier.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                                }
                                let updatedAttributes = currentMessage.attributes.map({ currentAttribute -> MessageAttribute in
                                    if let currentAttribute = currentAttribute as? AutoremoveTimeoutMessageAttribute {
                                        return AutoremoveTimeoutMessageAttribute(timeout: currentAttribute.timeout, countdownBeginTime: timestamp)
                                    } else {
                                        return currentAttribute
                                    }
                                })
                                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                            })
                            modifier.addTimestampBasedMessageAttribute(tag: 0, timestamp: timestamp + attribute.timeout, messageId: id)
                        }
                        break
                    }
                }
            }
        }
    } else if index.id.peerId.namespace == Namespaces.Peer.CloudUser || index.id.peerId.namespace == Namespaces.Peer.CloudGroup || index.id.peerId.namespace == Namespaces.Peer.CloudChannel {
        stateManager.notifyAppliedIncomingReadMessages([index.id])
    }
}

func applyOutgoingReadMaxIndex(modifier: Modifier, index: MessageIndex, beginCountdownAt timestamp: Int32) {
    let messageIds = modifier.applyOutgoingReadMaxIndex(index)
    if index.id.peerId.namespace == Namespaces.Peer.SecretChat {
        for id in messageIds {
            applySecretOutgoingMessageReadActions(modifier: modifier, id: id, beginCountdownAt: timestamp)
        }
    }
}

func maybeReadSecretOutgoingMessage(modifier: Modifier, index: MessageIndex) {
    guard index.id.peerId.namespace == Namespaces.Peer.SecretChat else {
        assertionFailure()
        return
    }
    guard index.id.namespace == Namespaces.Message.Local else {
        assertionFailure()
        return
    }
    
    guard let combinedState = modifier.getCombinedPeerReadState(index.id.peerId) else {
        return
    }
    
    if combinedState.isOutgoingMessageIndexRead(index) {
        applySecretOutgoingMessageReadActions(modifier: modifier, id: index.id, beginCountdownAt: index.timestamp)
    }
}

func applySecretOutgoingMessageReadActions(modifier: Modifier, id: MessageId, beginCountdownAt timestamp: Int32) {
    guard id.peerId.namespace == Namespaces.Peer.SecretChat else {
        assertionFailure()
        return
    }
    guard id.namespace == Namespaces.Message.Local else {
        assertionFailure()
        return
    }
    
    if let message = modifier.getMessage(id), !message.flags.contains(.Incoming) {
        if message.flags.intersection([.Unsent, .Sending, .Failed]).isEmpty {
            for attribute in message.attributes {
                if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                    if (attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0) && !message.containsSecretMedia {
                        modifier.updateMessage(message.id, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                            }
                            let updatedAttributes = currentMessage.attributes.map({ currentAttribute -> MessageAttribute in
                                if let currentAttribute = currentAttribute as? AutoremoveTimeoutMessageAttribute {
                                    return AutoremoveTimeoutMessageAttribute(timeout: currentAttribute.timeout, countdownBeginTime: timestamp)
                                } else {
                                    return currentAttribute
                                }
                            })
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                        })
                        modifier.addTimestampBasedMessageAttribute(tag: 0, timestamp: timestamp + attribute.timeout, messageId: id)
                    }
                    break
                }
            }
        }
    }
}

public func togglePeerUnreadMarkInteractively(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        let namespace: MessageId.Namespace
        if peerId.namespace == Namespaces.Peer.SecretChat {
            namespace = Namespaces.Message.SecretIncoming
        } else {
            namespace = Namespaces.Message.Cloud
        }
        if let states = modifier.getPeerReadStates(peerId) {
            for i in 0 ..< states.count {
                if states[i].0 == namespace {
                    if states[i].1.isUnread {
                        let _ = modifier.applyInteractiveReadMaxIndex(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 1), timestamp: 1))
                    } else {
                        modifier.applyMarkUnread(peerId: peerId, namespace: namespace, value: true, interactive: true)
                    }
                }
            }
        }
    }
}
