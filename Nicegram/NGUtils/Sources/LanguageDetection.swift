import AccountContext
import NaturalLanguage
import Postbox
import SwiftSignalKit
import TelegramCore

public func wrapped_detectInterlocutorLanguage(forChatWith id: PeerId, context: AccountContext) -> Signal<String?, NoError> {
    if #available(iOS 12.0, *) {
        return detectInterlocutorLanguage(forChatWith: id, context: context)
    } else {
        return .single(nil)
    }
}

@available(iOS 12.0, *)
public func detectInterlocutorLanguage(forChatWith id: PeerId, context: AccountContext) -> Signal<String?, NoError> {
    let userId = context.account.peerId
    return context.engine.messages.allMessages(peerId: id, namespace: Namespaces.Message.Cloud)
    |> map { messages -> String? in
        let messages = messages
            .filter { $0.author?.id != userId}
            .sorted(by: { $0.timestamp > $1.timestamp })
        
        guard let message = messages.first(where: { $0.text.count >= 16 }) ?? messages.first(where: { !$0.text.isEmpty }) else { return nil }
        
        let messageText = message
            .text
            .prefix(64)
            .toString()
        
        if let languageCode = NLLanguageRecognizer.dominantLanguage(for: messageText)?.rawValue {
            return languageCode
        } else {
            return nil
        }
    }
}

private extension String.SubSequence {
    func toString() -> String {
        return String(self)
    }
}
