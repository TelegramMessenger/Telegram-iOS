import AccountContext
import Postbox
import TelegramCore

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
    
    func textToTranslate() -> String {
        return (transcribedText() ?? "")
            .appending("\n")
            .appending(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func transcribedText() -> String? {
        for attribute in attributes {
            if let attribute = attribute as? AudioTranscriptionMessageAttribute {
                if !attribute.text.isEmpty {
                    return attribute.text
                } else {
                    return nil
                }
            }
        }
        return nil
    }
    
    func updateAudioTranscriptionAttribute(text: String, error: Error?, context: AccountContext) {
        updateAudioTranscriptionMessageAttribute(message: self, text: text, error: error, context: context)
    }
}

private func updateAudioTranscriptionMessageAttribute(message: Message, text: String, error: Error?, context: AccountContext) {
    let updatedAttribute = AudioTranscriptionMessageAttribute(id: 0, text: text, isPending: false, didRate: false, error: (error != nil) ? .generic : nil)
    
    let _ = (context.account.postbox.transaction { transaction -> Void in
        transaction.updateMessage(message.id, update: { currentMessage in
            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
            var attributes = currentMessage.attributes.filter { !($0 is AudioTranscriptionMessageAttribute) }
            
            attributes.append(updatedAttribute)
            
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }).start()
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
