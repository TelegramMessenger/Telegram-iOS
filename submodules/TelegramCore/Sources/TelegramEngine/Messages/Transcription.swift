import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum EngineAudioTranscriptionResult {
    case success
    case error
}

private enum InternalAudioTranscriptionResult {
    case success(Api.messages.TranscribedAudio)
    case error(AudioTranscriptionMessageAttribute.TranscriptionError)
    case limitExceeded(Int32)
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
        |> map { result -> InternalAudioTranscriptionResult in
            return .success(result)
        }
        |> `catch` { error -> Signal<InternalAudioTranscriptionResult, NoError> in
            let mappedError: AudioTranscriptionMessageAttribute.TranscriptionError
            if error.errorDescription.hasPrefix("FLOOD_WAIT_") {
                if let range = error.errorDescription.range(of: "_", options: .backwards) {
                    if let value = Int32(error.errorDescription[range.upperBound...]) {
                        return .single(.limitExceeded(value))
                    }
                }
                mappedError = .generic
            } else if error.errorDescription == "MSG_VOICE_TOO_LONG" {
                mappedError = .tooLong
            } else {
                mappedError = .generic
            }
            return .single(.error(mappedError))
        }
        |> mapToSignal { result -> Signal<EngineAudioTranscriptionResult, NoError> in
            return postbox.transaction { transaction -> EngineAudioTranscriptionResult in
                let updatedAttribute: AudioTranscriptionMessageAttribute
                switch result {
                case let .success(transcribedAudio):
                    switch transcribedAudio {
                    case let .transcribedAudio(flags, transcriptionId, text, trialRemainingCount, trialUntilDate):
                        let isPending = (flags & (1 << 0)) != 0
                        updatedAttribute = AudioTranscriptionMessageAttribute(id: transcriptionId, text: text, isPending: isPending, didRate: false, error: nil)
                        
                        _internal_updateAudioTranscriptionTrialState(transaction: transaction) { current in
                            var updated = current
                            if let trialRemainingCount = trialRemainingCount, trialRemainingCount > 0 {
                                updated = updated.withUpdatedRemainingCount(trialRemainingCount)
                            } else if let trialUntilDate = trialUntilDate {
                                updated = updated.withUpdatedCooldownUntilTime(trialUntilDate)
                            } else {
                                updated = updated.withUpdatedCooldownUntilTime(nil)
                            }
                            return updated
                        }
                    }
                case let .error(error):
                    updatedAttribute = AudioTranscriptionMessageAttribute(id: 0, text: "", isPending: false, didRate: false, error: error)
                case let .limitExceeded(timeout):
                    let cooldownTime = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) + timeout
                    _internal_updateAudioTranscriptionTrialState(transaction: transaction) { current in
                        var updated = current
                        updated = updated.withUpdatedCooldownUntilTime(cooldownTime)
                        return updated
                    }
                    return .error
                }
                    
                transaction.updateMessage(messageId, update: { currentMessage in
                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                    var attributes = currentMessage.attributes.filter { !($0 is AudioTranscriptionMessageAttribute) }
                    
                    attributes.append(updatedAttribute)
                    
                    return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
                
                if updatedAttribute.error == nil {
                    return .success
                } else {
                    return .error
                }
            }
        }
    }
}

func _internal_rateAudioTranscription(postbox: Postbox, network: Network, messageId: MessageId, id: Int64, isGood: Bool) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        transaction.updateMessage(messageId, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            for i in 0 ..< attributes.count {
                if let attribute = attributes[i] as? AudioTranscriptionMessageAttribute {
                    attributes[i] = attribute.withDidRate()
                }
            }
            return .update(StoreMessage(
                id: currentMessage.id,
                customStableId: nil,
                globallyUniqueId: currentMessage.globallyUniqueId,
                groupingKey: currentMessage.groupingKey,
                threadId: currentMessage.threadId,
                timestamp: currentMessage.timestamp,
                flags: StoreMessageFlags(currentMessage.flags),
                tags: currentMessage.tags,
                globalTags: currentMessage.globalTags,
                localTags: currentMessage.localTags,
                forwardInfo: storeForwardInfo,
                authorId: currentMessage.author?.id,
                text: currentMessage.text,
                attributes: attributes,
                media: currentMessage.media
            ))
        })
        
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

public enum AudioTranscription {
    public struct TrialState: Equatable, Codable {
        public let cooldownUntilTime: Int32?
        public let remainingCount: Int32
        
        func withUpdatedCooldownUntilTime(_ time: Int32?) -> AudioTranscription.TrialState {
            return AudioTranscription.TrialState(cooldownUntilTime: time, remainingCount: time != nil ? 0 : max(1, self.remainingCount))
        }
        
        func withUpdatedRemainingCount(_ remainingCount: Int32) -> AudioTranscription.TrialState {
            return AudioTranscription.TrialState(remainingCount: remainingCount)
        }
        
        public init(cooldownUntilTime: Int32? = nil, remainingCount: Int32) {
            self.cooldownUntilTime = cooldownUntilTime
            self.remainingCount = remainingCount
        }
        
        public static var defaultValue: AudioTranscription.TrialState {
            return AudioTranscription.TrialState(
                cooldownUntilTime: nil,
                remainingCount: 1
            )
        }
    }
}

func _internal_updateAudioTranscriptionTrialState(transaction: Transaction, _ f: (AudioTranscription.TrialState) -> AudioTranscription.TrialState) {
    let current = transaction.getPreferencesEntry(key: PreferencesKeys.audioTranscriptionTrialState)?.get(AudioTranscription.TrialState.self) ?? .defaultValue
    transaction.setPreferencesEntry(key: PreferencesKeys.audioTranscriptionTrialState, value: PreferencesEntry(f(current)))
}
