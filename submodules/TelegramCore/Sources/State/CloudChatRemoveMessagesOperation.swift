import Postbox

func cloudChatAddRemoveMessagesOperation(transaction: Transaction, peerId: PeerId, messageIds: [MessageId], type: CloudChatRemoveMessagesType) {
    transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatRemoveMessagesOperation(messageIds: messageIds, type: type))
}

func cloudChatAddRemoveChatOperation(transaction: Transaction, peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool) {
    transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatRemoveChatOperation(peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible, topMessageId: transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)))
}

func cloudChatAddClearHistoryOperation(transaction: Transaction, peerId: PeerId, explicitTopMessageId: MessageId?, minTimestamp: Int32?, maxTimestamp: Int32?, type: CloudChatClearHistoryType) {
    if type == .scheduledMessages {
        var messageIds: [MessageId] = []
        transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.ScheduledCloud) { message -> Bool in
            messageIds.append(message.id)
            return true
        }
        cloudChatAddRemoveMessagesOperation(transaction: transaction, peerId: peerId, messageIds: messageIds, type: .forLocalPeer)
    } else {
        let topMessageId: MessageId?
        if let explicitTopMessageId = explicitTopMessageId {
            topMessageId = explicitTopMessageId
        } else {
            topMessageId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)
        }
        if let topMessageId = topMessageId {
            transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatClearHistoryOperation(peerId: peerId, topMessageId: topMessageId, minTimestamp: minTimestamp, maxTimestamp: maxTimestamp, type: type))
        }
    }
}
