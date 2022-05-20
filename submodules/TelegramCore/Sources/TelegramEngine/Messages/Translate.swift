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

public struct EngineAudioTranscriptionResult {
    public var id: Int64
    public var text: String
}

func _internal_transcribeAudio(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<EngineAudioTranscriptionResult?, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<EngineAudioTranscriptionResult?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        return network.request(Api.functions.messages.transcribeAudio(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.TranscribedAudio?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<EngineAudioTranscriptionResult?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            switch result {
            case let .transcribedAudio(transcriptionId, text):
                return .single(EngineAudioTranscriptionResult(id: transcriptionId, text: text))
            }
        }
    }
}
