import AccountContext
import Postbox

private let speechToTextSeparator = "🗨 Speech2Text\n"
private let speechToTextLoading = "Loading..."

public extension Message {
    func setSpeechToTextTranslation(_ translation: String, context: AccountContext) {
        updateMessageText(message: self, newMessageText: text.appendingSpeechToText(translation: translation), context: context)
    }
    
    func setSpeechToTextLoading(context: AccountContext) {
        updateMessageText(message: self, newMessageText: text.appendingSpeechToTextLoading(), context: context)
    }
    
    func removeSpeechToTextMeta(context: AccountContext) {
        updateMessageText(message: self, newMessageText: text.removingSpeechToTextMeta(), context: context)
    }
    
    func isSpeechToTextDone() -> Bool {
        return text.contains(speechToTextSeparator)
    }
    
    func isSpeechToTextLoading() -> Bool {
        return text.contains(speechToTextLoading)
    }
}

private func updateMessageText(message: Message, newMessageText: String, context: AccountContext) {
    let _ = (context.account.postbox.transaction { transaction -> Void in
        transaction.updateMessage(message.id, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }

            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId:  currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: newMessageText, attributes: currentMessage.attributes, media: currentMessage.media))
        })
    }).start()
}

private extension String {
    func appendingSpeechToTextLoading() -> String {
        return self.removingSpeechToTextMeta() + "\(speechToTextSeparator)\(speechToTextLoading)"
    }
    
    func appendingSpeechToText(translation: String) -> String {
        return self.removingSpeechToTextMeta() + "\(speechToTextSeparator)\(translation)"
    }
    
    func removingSpeechToTextMeta() -> String {
        if let dotRange = self.range(of: speechToTextSeparator) {
            return replacingCharacters(in: dotRange.lowerBound..<self.endIndex, with: "")
        } else {
            return self
        }
    }
}
