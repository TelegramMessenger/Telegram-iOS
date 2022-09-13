import AccountContext
import NaturalLanguage
import Postbox
import SwiftSignalKit
import TelegramCore
import FileStorage

class ChatLanguageStorage {
    
    //  MARK: - Dependencies
    
    private let fileStorage = FileStorage<[Int64: String]>(path: "chat-language")
    
    
    //  MARK: - Public Functions

    func langCode(forChatWith id: PeerId) -> String? {
        return fileStorage.read()?[id.id._internalGetInt64Value()]
    }
    
    func setLangCode(_ code: String, forChatWith id: PeerId) {
        var dict = fileStorage.read() ?? [:]
        dict[id.id._internalGetInt64Value()] = code
        fileStorage.save(dict)
    }
}

public enum TranslateEnteredTextError: Error {
    case toLanguageNotFound
    case translate
}

private let chatLanguageStorage = ChatLanguageStorage()

public func translateEnteredText(text: String, chatId: PeerId?, context: AccountContext) -> Signal<String, TranslateEnteredTextError> {
    return getLanguageCode(forChatWith: chatId, context: context)
    |> castError(TranslateEnteredTextError.self)
    |> mapToSignal { code -> Signal<String, TranslateEnteredTextError> in
        guard let code = code else {
            return .fail(.toLanguageNotFound)
        }
        return gtranslate(text, code)
        |> mapError {_ in .translate}
    }
}

public func getLanguageCode(forChatWith id: PeerId?, context: AccountContext) -> Signal<String?, NoError> {
    guard let id = id else {
        return .single(nil)
    }
    if let code = getCachedLanguageCode(forChatWith: id) {
        return .single(code)
    } else {
        if #available(iOS 12.0, *) {
            return detectLanguageCode(forChatWith: id, context: context)
        } else {
            return .single(nil)
        }
    }
}

public func getCachedLanguageCode(forChatWith id: PeerId?) -> String? {
    guard let id = id else { return nil }
    return chatLanguageStorage.langCode(forChatWith: id)
}

public func setLanguageCode(_ code: String, forChatWith id: PeerId?) {
    guard let id = id else { return }
    chatLanguageStorage.setLangCode(code, forChatWith: id)
}

@available(iOS 12.0, *)
private func detectLanguageCode(forChatWith id: PeerId, context: AccountContext) -> Signal<String?, NoError> {
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
            setLanguageCode(languageCode, forChatWith: id)
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
