import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

enum PendingMessageUploadedContent {
    case text(String)
    case media(Api.InputMedia)
    case forward(ForwardSourceInfoAttribute)
    case chatContextResult(OutgoingChatContextResultMessageAttribute)
    case secretMedia(Api.InputEncryptedFile, Int32, SecretFileEncryptionKey)
}

enum PendingMessageUploadedContentResult {
    case progress(Float)
    case content(Message, PendingMessageUploadedContent)
}

enum PendingMessageUploadContent {
    case ready(Message, PendingMessageUploadedContent)
    case upload(Signal<PendingMessageUploadedContentResult, NoError>)
}

func messageContentToUpload(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, message: Message) -> PendingMessageUploadContent {
    var outgoingChatContextResultAttribute: OutgoingChatContextResultMessageAttribute?
    for attribute in message.attributes {
        if let attribute = attribute as? OutgoingChatContextResultMessageAttribute {
            outgoingChatContextResultAttribute = attribute
        }
    }
    
    if let _ = message.forwardInfo {
        var forwardSourceInfo: ForwardSourceInfoAttribute?
        for attribute in message.attributes {
            if let attribute = attribute as? ForwardSourceInfoAttribute {
                forwardSourceInfo = attribute
            }
        }
        if let forwardSourceInfo = forwardSourceInfo {
            return .ready(message, .forward(forwardSourceInfo))
        } else {
            assertionFailure()
            return .ready(message, .text(message.text))
        }
    } else if let outgoingChatContextResultAttribute = outgoingChatContextResultAttribute {
        return .ready(message, .chatContextResult(outgoingChatContextResultAttribute))
    } else if let media = message.media.first {
        if let image = media as? TelegramMediaImage, let _ = largestImageRepresentation(image.representations) {
            return .upload(uploadedMediaImageContent(network: network, postbox: postbox, image: image, message: message))
        } else if let file = media as? TelegramMediaFile {
            if let resource = file.resource as? CloudDocumentMediaResource {
                return .ready(message, .media(Api.InputMedia.inputMediaDocument(id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash), caption: message.text)))
            } else {
                return .upload(uploadedMediaFileContent(network: network, postbox: postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, file: file, message: message))
            }
        } else if let contact = media as? TelegramMediaContact {
            let input = Api.InputMedia.inputMediaContact(phoneNumber: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName)
            return .ready(message, .media(input))
        } else {
            return .ready(message, .text(message.text))
        }
    } else {
        return .ready(message, .text(message.text))
    }
}

func uploadedMessageContent(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, message: Message) -> Signal<PendingMessageUploadedContentResult, NoError> {
    var outgoingChatContextResultAttribute: OutgoingChatContextResultMessageAttribute?
    for attribute in message.attributes {
        if let attribute = attribute as? OutgoingChatContextResultMessageAttribute {
            outgoingChatContextResultAttribute = attribute
        }
    }
    
    if let _ = message.forwardInfo {
        var forwardSourceInfo: ForwardSourceInfoAttribute?
        for attribute in message.attributes {
            if let attribute = attribute as? ForwardSourceInfoAttribute {
                forwardSourceInfo = attribute
            }
        }
        if let forwardSourceInfo = forwardSourceInfo {
            return .single(.content(message, .forward(forwardSourceInfo)))
        } else {
            assertionFailure()
            return .never()
        }
    } else if let outgoingChatContextResultAttribute = outgoingChatContextResultAttribute {
        return .single(.content(message, .chatContextResult(outgoingChatContextResultAttribute)))
    } else if let media = message.media.first {
        if let image = media as? TelegramMediaImage, let _ = largestImageRepresentation(image.representations) {
            return uploadedMediaImageContent(network: network, postbox: postbox, image: image, message: message)
        } else if let file = media as? TelegramMediaFile {
            if let resource = file.resource as? CloudDocumentMediaResource {
                return .single(.content(message, .media(Api.InputMedia.inputMediaDocument(id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash), caption: message.text))))
            } else {
                return uploadedMediaFileContent(network: network, postbox: postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, file: file, message: message)
            }
        } else if let contact = media as? TelegramMediaContact {
            let input = Api.InputMedia.inputMediaContact(phoneNumber: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName)
            return .single(.content(message, .media(input)))
        } else {
            return .single(.content(message, .text(message.text)))
        }
    } else {
        return .single(.content(message, .text(message.text)))
    }
}

private func uploadedMediaImageContent(network: Network, postbox: Postbox, image: TelegramMediaImage, message: Message) -> Signal<PendingMessageUploadedContentResult, NoError> {
    if let largestRepresentation = largestImageRepresentation(image.representations) {
        return multipartUpload(network: network, postbox: postbox, resource: largestRepresentation.resource, encrypt: message.id.peerId.namespace == Namespaces.Peer.SecretChat)
            |> map { next -> PendingMessageUploadedContentResult in
                switch next {
                    case let .progress(progress):
                        return .progress(progress)
                    case let .inputFile(file):
                        return .content(message, .media(Api.InputMedia.inputMediaUploadedPhoto(flags: 0, file: file, caption: message.text, stickers: nil)))
                    case let .inputSecretFile(file, size, key):
                        return .content(message, .secretMedia(file, size, key))
                }
            }
    } else {
        return .single(.content(message, .text(message.text)))
    }
}

private func inputDocumentAttributesFromFile(_ file: TelegramMediaFile) -> [Api.DocumentAttribute] {
    var attributes: [Api.DocumentAttribute] = []
    for attribute in file.attributes {
        switch attribute {
            case .Animated:
                attributes.append(.documentAttributeAnimated)
            case let .FileName(fileName):
                attributes.append(.documentAttributeFilename(fileName: fileName))
            case let .ImageSize(size):
                attributes.append(.documentAttributeImageSize(w: Int32(size.width), h: Int32(size.height)))
            case let .Sticker(displayText, packReference):
                var stickerSet: Api.InputStickerSet = .inputStickerSetEmpty
                let flags: Int32 = 0
                if let packReference = packReference {
                    switch packReference {
                        case let .id(id, accessHash):
                            stickerSet = .inputStickerSetID(id: id, accessHash: accessHash)
                        case let .name(name):
                            stickerSet = .inputStickerSetShortName(shortName: name)
                    }
                }
                attributes.append(.documentAttributeSticker(flags: flags, alt: displayText, stickerset: stickerSet, maskCoords: nil))
            case .HasLinkedStickers:
                attributes.append(.documentAttributeHasStickers)
            case let .Video(duration, size):
                attributes.append(.documentAttributeVideo(duration: Int32(duration), w: Int32(size.width), h: Int32(size.height)))
            case let .Audio(isVoice, duration, title, performer, waveform):
                var flags: Int32 = 0
                if isVoice {
                    flags |= Int32(1 << 10)
                }
                if let _ = title {
                    flags |= Int32(1 << 0)
                }
                if let _ = performer {
                    flags |= Int32(1 << 1)
                }
                var waveformBuffer: Buffer?
                if let waveform = waveform {
                    flags |= Int32(1 << 2)
                    waveformBuffer = Buffer(data: waveform.makeData())
                }
                attributes.append(.documentAttributeAudio(flags: flags, duration: Int32(duration), title: title, performer: performer, waveform: waveformBuffer))
        }
    }
    return attributes
}

private enum UploadedMediaTransform {
    case pending
    case done(Media?)
}

private enum UploadedMediaThumbnail {
    case pending
    case done(Api.InputFile?)
}

private func uploadedThumbnail(network: Network, postbox: Postbox, image: TelegramMediaImageRepresentation) -> Signal<Api.InputFile?, NoError> {
    return multipartUpload(network: network, postbox: postbox, resource: image.resource, encrypt: false)
        |> mapToSignal { result -> Signal<Api.InputFile?, NoError> in
            switch result {
                case .progress:
                    return .complete()
                case let .inputFile(inputFile):
                    return .single(inputFile)
                case .inputSecretFile:
                    return .single(nil)
            }
        }
}

private func uploadedMediaFileContent(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, file: TelegramMediaFile, message: Message) -> Signal<PendingMessageUploadedContentResult, NoError> {
    let upload = multipartUpload(network: network, postbox: postbox, resource: file.resource, encrypt: message.id.peerId.namespace == Namespaces.Peer.SecretChat, hintFileSize: file.size)
        /*|> map { next -> UploadedMediaFileContent in
            switch next {
                case let .progress(progress):
                    return .progress(progress)
                case let .inputFile(inputFile):
                    return .content(message, .media(Api.InputMedia.inputMediaUploadedDocument(flags: 0, file: inputFile, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFile(file), caption: message.text, stickers: nil)))
                case let .inputSecretFile(file, size, key):
                    return .content(message, .secretMedia(file, size, key))
            }
        }*/
    var alreadyTransformed = false
    for attribute in message.attributes {
        if let attribute = attribute as? OutgoingMessageInfoAttribute {
            if attribute.flags.contains(.transformedMedia) {
                alreadyTransformed = true
            }
            break
        }
    }
    
    let transform: Signal<UploadedMediaTransform, Void>
    if let transformOutgoingMessageMedia = transformOutgoingMessageMedia, !alreadyTransformed {
        transform = .single(.pending) |> then(transformOutgoingMessageMedia(postbox, network, file, false)
            |> mapToSignal { media -> Signal<UploadedMediaTransform, NoError> in
                return postbox.modify { modifier -> UploadedMediaTransform in
                    if let media = media {
                        if let id = media.id {
                            modifier.updateMedia(id, update: media)
                            modifier.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                }
                                var updatedAttributes = currentMessage.attributes
                                if let index = updatedAttributes.index(where: { $0 is OutgoingMessageInfoAttribute }){
                                    let attribute = updatedAttributes[index] as! OutgoingMessageInfoAttribute
                                    updatedAttributes[index] = attribute.withUpdatedFlags(attribute.flags.union([.transformedMedia]))
                                } else {
                                    updatedAttributes.append(OutgoingMessageInfoAttribute(uniqueId: arc4random64(), flags: [.transformedMedia]))
                                }
                                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                            })
                        }
                        return .done(media)
                    } else {
                        return .done(file)
                    }
                }
            })
    } else {
        transform = .single(.done(file))
    }
    
    let thumbnail: Signal<UploadedMediaThumbnail, NoError> = .single(.pending) |> then(transform
        |> mapToSignal { media -> Signal<UploadedMediaThumbnail, NoError> in
            switch media {
                case .pending:
                    return .single(.pending)
                case let .done(media):
                    if let media = media as? TelegramMediaFile, let smallestThumbnail = smallestImageRepresentation(media.previewRepresentations) {
                        return uploadedThumbnail(network: network, postbox: postbox, image: smallestThumbnail)
                            |> map { result in
                                return .done(result)
                            }
                    } else {
                        return .single(.done(nil))
                    }
            }
        })
    
    return combineLatest(upload, thumbnail)
        |> mapToSignal { content, media -> Signal<PendingMessageUploadedContentResult, NoError> in
            switch content {
                case let .progress(progress):
                    return .single(.progress(progress))
                case let .inputFile(inputFile):
                    if case let .done(thumbnail) = media {
                        let inputMedia: Api.InputMedia
                        if let thumbnail = thumbnail {
                            inputMedia = Api.InputMedia.inputMediaUploadedThumbDocument(flags: 0, file: inputFile, thumb: thumbnail, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFile(file), caption: message.text, stickers: nil)
                        } else {
                            inputMedia = Api.InputMedia.inputMediaUploadedDocument(flags: 0, file: inputFile, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFile(file), caption: message.text, stickers: nil)
                        }
                        return .single(.content(message, .media(inputMedia)))
                    } else {
                        return .complete()
                    }
                case let .inputSecretFile(file, size, key):
                    if case .done = media {
                        return .single(.content(message, .secretMedia(file, size, key)))
                    } else {
                        return .complete()
                    }
            }
    }
}
