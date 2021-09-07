import Postbox

func addSynchronizeConsumeMessageContentsOperation(transaction: Transaction, messageIds: [MessageId]) {
    for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(messageIds)) {
        let updateLocalIndex: Int32? = nil
        /*transaction.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SynchronizeConsumeMessageContents, { entry in
            updateLocalIndex = entry.tagLocalIndex
            return false
        })*/
        let operationContents = SynchronizeConsumeMessageContentsOperation(messageIds: messageIds)
        if let updateLocalIndex = updateLocalIndex {
            let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SynchronizeConsumeMessageContents, tagLocalIndex: updateLocalIndex)
        }
        transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SynchronizeConsumeMessageContents, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
    }
}
