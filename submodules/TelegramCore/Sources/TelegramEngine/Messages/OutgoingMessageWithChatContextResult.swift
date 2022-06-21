import Foundation
import Postbox
import SwiftSignalKit

func _internal_enqueueOutgoingMessageWithChatContextResult(account: Account, to peerId: PeerId, botId: PeerId, result: ChatContextResult, replyToMessageId: MessageId?, hideVia: Bool, silentPosting: Bool, scheduleTime: Int32?, correlationId: Int64?) -> Bool {
    guard let message = _internal_outgoingMessageWithChatContextResult(to: peerId, botId: botId, result: result, replyToMessageId: replyToMessageId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime, correlationId: correlationId) else {
        return false
    }
    let _ = enqueueMessages(account: account, peerId: peerId, messages: [message]).start()
    return true
}

func _internal_outgoingMessageWithChatContextResult(to peerId: PeerId, botId: PeerId, result: ChatContextResult, replyToMessageId: MessageId?, hideVia: Bool, silentPosting: Bool, scheduleTime: Int32?, correlationId: Int64?) -> EnqueueMessage? {
    var attributes: [MessageAttribute] = []
    attributes.append(OutgoingChatContextResultMessageAttribute(queryId: result.queryId, id: result.id, hideVia: hideVia))
    if !hideVia {
        attributes.append(InlineBotMessageAttribute(peerId: botId, title: nil))
    }
    if let scheduleTime = scheduleTime {
        attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime))
    }
    if silentPosting {
        attributes.append(NotificationInfoMessageAttribute(flags: .muted))
    }
    switch result.message {
        case let .auto(caption, entities, replyMarkup):
            if let entities = entities {
                attributes.append(entities)
            }
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            switch result {
                case let .internalReference(internalReference):
                    if internalReference.type == "game" {
                        if peerId.namespace == Namespaces.Peer.SecretChat {
                            let filteredAttributes = attributes.filter { attribute in
                                if let _ = attribute as? ReplyMarkupMessageAttribute {
                                    return false
                                }
                                return true
                            }
                            if let media: Media = internalReference.file ?? internalReference.image {
                                return .message(text: caption, attributes: filteredAttributes, mediaReference: .standalone(media: media), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                            } else {
                                return .message(text: caption, attributes: filteredAttributes, mediaReference: nil, replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                            }
                        } else {
                            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: TelegramMediaGame(gameId: 0, accessHash: 0, name: "", title: internalReference.title ?? "", description: internalReference.description ?? "", image: internalReference.image, file: internalReference.file)), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                        }
                    } else if let file = internalReference.file, internalReference.type == "gif" {
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: file), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                    } else if let image = internalReference.image {
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: image), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                    } else if let file = internalReference.file {
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: file), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                    } else {
                        return nil
                    }
                case let .externalReference(externalReference):
                    if externalReference.type == "photo" {
                        if let thumbnail = externalReference.thumbnail {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let thumbnailResource = thumbnail.resource
                            let imageDimensions = thumbnail.dimensions ?? PixelDimensions(width: 128, height: 128)
                            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: tmpImage), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                        } else {
                            return .message(text: caption, attributes: attributes, mediaReference: nil, replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                        }
                    } else if externalReference.type == "document" || externalReference.type == "gif" || externalReference.type == "audio" || externalReference.type == "voice" {
                        var videoThumbnails: [TelegramMediaFile.VideoThumbnail] = []
                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        if let thumbnail = externalReference.thumbnail {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let thumbnailResource = thumbnail.resource
                            
                            if thumbnail.mimeType.hasPrefix("video/") {
                                videoThumbnails.append(TelegramMediaFile.VideoThumbnail(dimensions: thumbnail.dimensions ?? PixelDimensions(width: 128, height: 128), resource: thumbnailResource))
                            } else {
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: thumbnail.dimensions ?? PixelDimensions(width: 128, height: 128), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil))
                            }
                        }
                        var fileName = "file"
                        if let content = externalReference.content {
                            var contentUrl: String?
                            if let resource = content.resource as? HttpReferenceMediaResource {
                                contentUrl = resource.url
                            } else if let resource = content.resource as? WebFileReferenceMediaResource {
                                contentUrl = resource.url
                            }
                            if let contentUrl = contentUrl, let url = URL(string: contentUrl) {
                                if !url.lastPathComponent.isEmpty {
                                    fileName = url.lastPathComponent
                                }
                            }
                        }
                        
                        var fileAttributes: [TelegramMediaFileAttribute] = []
                        fileAttributes.append(.FileName(fileName: fileName))
                        
                        if externalReference.type == "gif" {
                            fileAttributes.append(.Animated)
                        }
                        
                        if let dimensions = externalReference.content?.dimensions {
                            fileAttributes.append(.ImageSize(size: dimensions))
                            if externalReference.type == "gif" {
                                fileAttributes.append(.Video(duration: Int(Int32(externalReference.content?.duration ?? 0)), size: dimensions, flags: []))
                            }
                        }
                        
                        if externalReference.type == "audio" || externalReference.type == "voice" {
                            fileAttributes.append(.Audio(isVoice: externalReference.type == "voice", duration: Int(Int32(externalReference.content?.duration ?? 0)), title: externalReference.title, performer: externalReference.description, waveform: nil))
                        }
                        
                        var randomId: Int64 = 0
                        arc4random_buf(&randomId, 8)
                        
                        let resource: TelegramMediaResource
                        if peerId.namespace == Namespaces.Peer.SecretChat, let webResource = externalReference.content?.resource as? WebFileReferenceMediaResource {
                            resource = webResource
                        } else {
                            resource = EmptyMediaResource()
                        }
                        
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: videoThumbnails, immediateThumbnailData: nil, mimeType: externalReference.content?.mimeType ?? "application/binary", size: nil, attributes: fileAttributes)
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: file), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                    } else {
                        return .message(text: caption, attributes: attributes, mediaReference: nil, replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
                    }
            }
        case let .text(text, entities, _, replyMarkup):
            if let entities = entities {
                attributes.append(entities)
            }
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: text, attributes: attributes, mediaReference: nil, replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
        case let .mapLocation(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
        case let .contact(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
        case let .invoice(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: replyToMessageId, localGroupingKey: nil, correlationId: correlationId)
    }
}
