import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_translate(network: Network, text: String, fromLang: String?, toLang: String) -> Signal<String?, NoError> {
    var flags: Int32 = 0
    flags |= (1 << 1)
    if let _ = fromLang {
        flags |= (1 << 2)
    }
    
    return network.request(Api.functions.messages.translateText(flags: flags, peer: nil, msgId: nil, text: text, fromLang: fromLang, toLang: toLang))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.TranslatedText?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<String?, NoError> in
        guard let result = result else {
            return .complete()
        }
        switch result {
            case .translateNoResult:
                return .single(nil)
            case let .translateResultText(text):
                return .single(text)
        }
    }
}
