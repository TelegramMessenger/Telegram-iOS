import AccountContext
import NGUtils
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
        return wrapped_detectInterlocutorLanguage(forChatWith: id, context: context)
        |> map { code -> String? in
            if let code {
                setLanguageCode(code, forChatWith: id)
            }
            return code
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
