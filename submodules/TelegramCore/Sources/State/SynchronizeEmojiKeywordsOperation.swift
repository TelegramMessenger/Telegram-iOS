import Foundation
import Postbox
import MurMurHash32


func addSynchronizeEmojiKeywordsOperation(transaction: Transaction, inputLanguageCode: String, languageCode: String?, fromVersion: Int32?) {
    let tag = OperationLogTags.SynchronizeEmojiKeywords
    let peerId = PeerId(namespace: PeerId.Namespace._internalFromInt32Value(1), id: PeerId.Id._internalFromInt64Value(Int64(abs(murMurHashString32(inputLanguageCode)))))
    
    var hasExistingOperation = false
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag) { entry -> Bool in
        hasExistingOperation = true
        return false
    }
    
    guard !hasExistingOperation else {
        return
    }
    let operationContents = SynchronizeEmojiKeywordsOperation(inputLanguageCode: inputLanguageCode, languageCode: languageCode, fromVersion: fromVersion)
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
