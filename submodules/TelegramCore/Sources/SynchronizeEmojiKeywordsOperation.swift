import Foundation
import Postbox

import SyncCore

func addSynchronizeEmojiKeywordsOperation(transaction: Transaction, inputLanguageCode: String, languageCode: String?, fromVersion: Int32?) {
    let tag = OperationLogTags.SynchronizeEmojiKeywords
    let peerId = PeerId(emojiKeywordColletionIdForCode(inputLanguageCode).id)
    
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
