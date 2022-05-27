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

public enum EngineAudioTranscriptionResult {
    public struct Success {
        public var id: Int64
        public var text: String
        
        public init(id: Int64, text: String) {
            self.id = id
            self.text = text
        }
    }
    
    case success(Success)
    case error
}

func _internal_transcribeAudio(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<EngineAudioTranscriptionResult, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<EngineAudioTranscriptionResult, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(.error)
        }
        return network.request(Api.functions.messages.transcribeAudio(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.TranscribedAudio?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<EngineAudioTranscriptionResult, NoError> in
            guard let result = result else {
                return .single(.error)
            }
            
            return postbox.transaction { transaction -> EngineAudioTranscriptionResult in
                switch result {
                case let .transcribedAudio(flags, transcriptionId, text):
                    transaction.updateMessage(messageId, update: { currentMessage in
                        let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                        var attributes = currentMessage.attributes.filter { !($0 is AudioTranscriptionMessageAttribute) }
                        
                        let isPending = (flags & (1 << 0)) != 0
                        
                        attributes.append(AudioTranscriptionMessageAttribute(id: transcriptionId, text: text, isPending: isPending))
                        
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                    
                    return .success(EngineAudioTranscriptionResult.Success(id: transcriptionId, text: text))
                }
            }
        }
    }
}

func _internal_rateAudioTranscription(postbox: Postbox, network: Network, messageId: MessageId, id: Int64, isGood: Bool) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        return network.request(Api.functions.messages.rateTranscribedAudio(peer: inputPeer, msgId: messageId.id, transcriptionId: id, good: isGood ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}
