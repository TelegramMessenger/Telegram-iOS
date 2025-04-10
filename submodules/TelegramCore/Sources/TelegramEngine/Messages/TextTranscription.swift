//
//  TextTranscription.swift
//  Telegram
//
//  Created by Dmitry Bolonikov on 7.04.25.
//

import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum EngineTextTranscriptionResult {
    case transcribing
    case finished
}

private enum InternalTextTranscriptionResult {
    case alreadyTranscribed(TextTranscriptionMessageAttribute)
    case startTranscribing(TextTranscriptionMessageAttribute)
    case transcribed(TextTranscriptionMessageAttribute)
    case error
}

func _internal_transcribeText(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<EngineTextTranscriptionResult, NoError> {
    return postbox.transaction { transaction -> Message? in
        transaction.getMessage(messageId)
    }
    |> mapToSignal { message -> Signal<InternalTextTranscriptionResult, NoError> in
        guard let message else {
            return .single(.error)
        }
        
        if let attribute = message.attributes.first(where: { $0 is TextTranscriptionMessageAttribute }) as? TextTranscriptionMessageAttribute {
            return .single(.alreadyTranscribed(attribute))
        }
        
        return Signal { subscriber in
            
            let fileId = Int64.random(in: Int64.min...Int64.max)
            let resource = LocalFileMediaResource(fileId: fileId)
            
            let mediaId = MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min...Int64.max))
            
            let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: nil)]
            
            let file = TelegramMediaFile(
                fileId: mediaId,
                partialReference: nil,
                resource: resource,
                previewRepresentations: [],
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: "audio/ogg",
                size: 1,
                attributes: voiceAttributes,
                alternativeRepresentations: [])
            
            let attributeId = Int64.random(in: Int64.min...Int64.max)
            let attribute = TextTranscriptionMessageAttribute(id: attributeId,
                                                              visible: true,
                                                              downloading: true,
                                                              file: file)
            
            subscriber.putNext(.startTranscribing(attribute))
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 5) {
                guard let fileUrl = Bundle.main.url(forResource: "TextToVoiceFeature", withExtension: "ogg"),
                      let data = try? Data(contentsOf: fileUrl) else {
                    subscriber.putNext(.error)
                    subscriber.putCompletion()
                    return
                }
                                
                postbox.mediaBox.storeResourceData(resource.id, data: data)
                                
                // TODO: Fetch duration, waveform from response
                let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
                
                let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: Data(base64Encoded: waveformBase64)!)]
                
                let file = TelegramMediaFile(
                    fileId: mediaId,
                    partialReference: nil,
                    resource: resource,
                    previewRepresentations: [],
                    videoThumbnails: [],
                    immediateThumbnailData: nil,
                    mimeType: "audio/ogg",
                    size: Int64(data.count),
                    attributes: voiceAttributes,
                    alternativeRepresentations: [])
                
                let attributeId = Int64.random(in: Int64.min...Int64.max)
                let attribute = TextTranscriptionMessageAttribute(id: attributeId,
                                                                  visible: true,
                                                                  downloading: false,
                                                                  file: file)
                
                subscriber.putNext(.transcribed(attribute))
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
    }
    |> mapToSignal { result -> Signal<EngineTextTranscriptionResult, NoError> in
        return postbox.transaction { transaction -> EngineTextTranscriptionResult in
            transaction.updateMessage(messageId, update: { currentMessage in
                var attributes = currentMessage.attributes.filter { !($0 is TextTranscriptionMessageAttribute) }
                
                switch result {
                case .transcribed(let attribute):
                    attributes.append(attribute)
                    
                case .startTranscribing(let attribute):
                    attributes.append(attribute)
                case .alreadyTranscribed(let attribute):
                    let updatedAttribute = TextTranscriptionMessageAttribute(id: attribute.id, visible: true, downloading: attribute.downloading, file: attribute.file)
                    guard updatedAttribute != attribute else {
                        return .skip
                    }
                    attributes.append(updatedAttribute)
                default:
                    return .skip
                }
                
                let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                
                return .update(StoreMessage(
                    id: currentMessage.id,
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
                    media: currentMessage.media))
            })
            
            switch result {
            case .startTranscribing:
                return .transcribing
            default:
                return .finished
            }
        }
    }
}
