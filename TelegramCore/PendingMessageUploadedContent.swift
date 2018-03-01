import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

import TelegramCorePrivateModule

enum PendingMessageUploadedContent {
    case text(String)
    case media(Api.InputMedia, String)
    case forward(ForwardSourceInfoAttribute)
    case chatContextResult(OutgoingChatContextResultMessageAttribute)
    case secretMedia(Api.InputEncryptedFile, Int32, SecretFileEncryptionKey)
}

enum PendingMessageUploadedContentResult {
    case progress(Float)
    case content(PendingMessageUploadedContent)
}

enum PendingMessageUploadError {
    case generic
}

enum PendingMessageUploadContent {
    case ready(PendingMessageUploadedContent)
    case upload(Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>)
}

func messageContentToUpload(network: Network, postbox: Postbox, auxiliaryMethods: AccountAuxiliaryMethods, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, message: Message) -> PendingMessageUploadContent {
    return messageContentToUpload(network: network, postbox: postbox, auxiliaryMethods: auxiliaryMethods, transformOutgoingMessageMedia: transformOutgoingMessageMedia, peerId: message.id.peerId, messageId: message.id, attributes: message.attributes, text: message.text, media: message.media)
}

func messageContentToUpload(network: Network, postbox: Postbox, auxiliaryMethods: AccountAuxiliaryMethods, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, peerId: PeerId, messageId: MessageId?, attributes: [MessageAttribute], text: String, media: [Media]) -> PendingMessageUploadContent {
    var contextResult: OutgoingChatContextResultMessageAttribute?
    var autoremoveAttribute: AutoremoveTimeoutMessageAttribute?
    for attribute in attributes {
        if let attribute = attribute as? OutgoingChatContextResultMessageAttribute {
            if peerId.namespace != Namespaces.Peer.SecretChat {
                contextResult = attribute
            }
        } else if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
            autoremoveAttribute = attribute
        }
    }
    
    var forwardInfo: ForwardSourceInfoAttribute?
    for attribute in attributes {
        if let attribute = attribute as? ForwardSourceInfoAttribute {
            forwardInfo = attribute
        }
    }
    
    if let forwardInfo = forwardInfo {
        return .ready(.forward(forwardInfo))
    }
    
    if let forwardInfo = forwardInfo {
        return .ready(.forward(forwardInfo))
    } else if let contextResult = contextResult {
        return .ready(.chatContextResult(contextResult))
    } else if let media = media.first {
        if let image = media as? TelegramMediaImage, let _ = largestImageRepresentation(image.representations) {
            if let reference = image.reference, case let .cloud(id, accessHash) = reference {
                return .ready(.media(Api.InputMedia.inputMediaPhoto(flags: 0, id: Api.InputPhoto.inputPhoto(id: id, accessHash: accessHash), ttlSeconds: nil), text))
            } else {
                return .upload(uploadedMediaImageContent(network: network, postbox: postbox, peerId: peerId, image: image, text: text, autoremoveAttribute: autoremoveAttribute))
            }
        } else if let file = media as? TelegramMediaFile {
            if let resource = file.resource as? CloudDocumentMediaResource {
                if peerId.namespace == Namespaces.Peer.SecretChat {
                    return .upload(uploadedMediaFileContent(network: network, postbox: postbox, auxiliaryMethods: auxiliaryMethods, transformOutgoingMessageMedia: transformOutgoingMessageMedia, peerId: peerId, messageId: messageId, text: text, attributes: attributes, file: file))
                } else {
                    return .ready(.media(Api.InputMedia.inputMediaDocument(flags: 0, id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash), ttlSeconds: nil), text))
                }
            } else {
                return .upload(uploadedMediaFileContent(network: network, postbox: postbox, auxiliaryMethods: auxiliaryMethods, transformOutgoingMessageMedia: transformOutgoingMessageMedia, peerId: peerId, messageId: messageId, text: text, attributes: attributes, file: file))
            }
        } else if let contact = media as? TelegramMediaContact {
            let input = Api.InputMedia.inputMediaContact(phoneNumber: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName)
            return .ready(.media(input, text))
        } else if let map = media as? TelegramMediaMap {
            let input: Api.InputMedia
            if let liveBroadcastingTimeout = map.liveBroadcastingTimeout {
                input = .inputMediaGeoLive(geoPoint: Api.InputGeoPoint.inputGeoPoint(lat: map.latitude, long: map.longitude), period: liveBroadcastingTimeout)
            } else if let venue = map.venue {
                input = .inputMediaVenue(geoPoint: Api.InputGeoPoint.inputGeoPoint(lat: map.latitude, long: map.longitude), title: venue.title, address: venue.address ?? "", provider: venue.provider ?? "", venueId: venue.id ?? "", venueType: venue.type ?? "")
            } else {
                input = .inputMediaGeoPoint(geoPoint: Api.InputGeoPoint.inputGeoPoint(lat: map.latitude, long: map.longitude))
            }
            return .ready(.media(input, text))
        } else {
            return .ready(.text(text))
        }
    } else {
        return .ready(.text(text))
    }
}

private enum PredownloadedResource {
    case localReference(CachedSentMediaReferenceKey?)
    case media(Media)
    case none
}

private func maybePredownloadedImageResource(postbox: Postbox, peerId: PeerId, resource: MediaResource) -> Signal<PredownloadedResource, PendingMessageUploadError> {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        return .single(.none)
    }
    
    return Signal<Signal<PredownloadedResource, PendingMessageUploadError>, PendingMessageUploadError> { subscriber in
        let data = postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false)).start(next: { data in
            if data.complete {
                if data.size < 5 * 1024 * 1024, let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: .mappedRead) {
                    var ctx = CC_MD5_CTX()
                    CC_MD5_Init(&ctx)
                    fileData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                        var offset = 0
                        let bufferSize = 32 * 1024
                        
                        while offset < fileData.count {
                            let partSize = min(fileData.count - offset, bufferSize)
                            CC_MD5_Update(&ctx, bytes.advanced(by: offset), CC_LONG(partSize))
                            offset += bufferSize
                        }
                    }
                    
                    var res = Data()
                    res.count = Int(CC_MD5_DIGEST_LENGTH)
                    res.withUnsafeMutableBytes { mutableBytes -> Void in
                        CC_MD5_Final(mutableBytes, &ctx)
                    }
                    
                    let reference: CachedSentMediaReferenceKey = .image(hash: res)
                    
                    subscriber.putNext(cachedSentMediaReference(postbox: postbox, key: reference) |> mapError { _ -> PendingMessageUploadError in return .generic } |> map { media -> PredownloadedResource in
                        if let media = media {
                            return .media(media)
                        } else {
                            return .localReference(reference)
                        }
                    })
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(.single(.localReference(nil)))
                    subscriber.putCompletion()
                }
            }
        })
        let fetched = postbox.mediaBox.fetchedResource(resource, tag: nil).start()
        
        return ActionDisposable {
            data.dispose()
            fetched.dispose()
        }
    } |> switchToLatest
}

private func maybePredownloadedFileResource(postbox: Postbox, auxiliaryMethods: AccountAuxiliaryMethods, peerId: PeerId, resource: MediaResource) -> Signal<PredownloadedResource, PendingMessageUploadError> {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        return .single(.none)
    }
    
    return auxiliaryMethods.fetchResourceMediaReferenceHash(resource)
        |> mapToSignal { hash -> Signal<PredownloadedResource, NoError> in
            if let hash = hash {
                let reference: CachedSentMediaReferenceKey = .file(hash: hash)
                return cachedSentMediaReference(postbox: postbox, key: reference) |> map { media -> PredownloadedResource in
                    if let media = media {
                        return .media(media)
                    } else {
                        return .localReference(reference)
                    }
                }
            } else {
                return .single(.localReference(nil))
            }
        } |> mapError { _ -> PendingMessageUploadError in return .generic }
}

private func maybeCacheUploadedResource(postbox: Postbox, key: CachedSentMediaReferenceKey?, result: PendingMessageUploadedContentResult, media: Media) -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> {
    if let key = key {
        return postbox.modify { modifier -> PendingMessageUploadedContentResult in
            storeCachedSentMediaReference(modifier: modifier, key: key, media: media)
            return result
        } |> mapError { _ -> PendingMessageUploadError in return .generic }
    } else {
        return .single(result)
    }
}

private func uploadedMediaImageContent(network: Network, postbox: Postbox, peerId: PeerId, image: TelegramMediaImage, text: String, autoremoveAttribute: AutoremoveTimeoutMessageAttribute?) -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> {
    if let largestRepresentation = largestImageRepresentation(image.representations) {
        let predownloadedResource: Signal<PredownloadedResource, PendingMessageUploadError> = maybePredownloadedImageResource(postbox: postbox, peerId: peerId, resource: largestRepresentation.resource)
        return predownloadedResource
            |> mapToSignal { result -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                var referenceKey: CachedSentMediaReferenceKey?
                switch result {
                    case let .media(media):
                        if let image = media as? TelegramMediaImage, let reference = image.reference, case let .cloud(id, accessHash) = reference {
                            var flags: Int32 = 0
                            var ttlSeconds: Int32?
                            if let autoremoveAttribute = autoremoveAttribute {
                                flags |= 1 << 1
                                ttlSeconds = autoremoveAttribute.timeout
                            }
                            return .single(.progress(1.0)) |> then(.single(.content(.media(.inputMediaPhoto(flags: flags, id: .inputPhoto(id: id, accessHash: accessHash), ttlSeconds: ttlSeconds), text))))
                        }
                    case let .localReference(key):
                        referenceKey = key
                    case .none:
                        referenceKey = nil
                }
                return multipartUpload(network: network, postbox: postbox, source: .resource(largestRepresentation.resource), encrypt: peerId.namespace == Namespaces.Peer.SecretChat, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false)
                    |> mapError { _ -> PendingMessageUploadError in return .generic }
                    |> mapToSignal { next -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                        switch next {
                            case let .progress(progress):
                                return .single(.progress(progress))
                            case let .inputFile(file):
                                var flags: Int32 = 0
                                var ttlSeconds: Int32?
                                if let autoremoveAttribute = autoremoveAttribute {
                                    flags |= 1 << 1
                                    ttlSeconds = autoremoveAttribute.timeout
                                }
                                return postbox.modify { modifier -> Api.InputPeer? in
                                    return modifier.getPeer(peerId).flatMap(apiInputPeer)
                                }
                                |> mapError { _ -> PendingMessageUploadError in return .generic }
                                |> mapToSignal { inputPeer -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                                    if let inputPeer = inputPeer {
                                        if autoremoveAttribute != nil {
                                            return .single(.content(.media(.inputMediaUploadedPhoto(flags: flags, file: file, stickers: nil, ttlSeconds: ttlSeconds), text)))
                                        }
                                        
                                        return network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: Api.InputMedia.inputMediaUploadedPhoto(flags: flags, file: file, stickers: nil, ttlSeconds: ttlSeconds)))
                                            |> mapError { _ -> PendingMessageUploadError in return .generic }
                                            |> mapToSignal { result -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                                                switch result {
                                                    case let .messageMediaPhoto(_, photo, _):
                                                        if let photo = photo, let mediaImage = telegramMediaImageFromApiPhoto(photo), let reference = mediaImage.reference, case let .cloud(id, accessHash) = reference {
                                                            var flags: Int32 = 0
                                                            var ttlSeconds: Int32?
                                                            if let autoremoveAttribute = autoremoveAttribute {
                                                                flags |= 1 << 1
                                                                ttlSeconds = autoremoveAttribute.timeout
                                                            }
                                                            return maybeCacheUploadedResource(postbox: postbox, key: referenceKey, result: .content(.media(.inputMediaPhoto(flags: flags, id: .inputPhoto(id: id, accessHash: accessHash), ttlSeconds: ttlSeconds), text)), media: mediaImage)
                                                        }
                                                    default:
                                                        break
                                                }
                                                return .fail(.generic)
                                            }
                                    } else {
                                        return .fail(.generic)
                                    }
                                }
                            case let .inputSecretFile(file, size, key):
                                return .single(.content(.secretMedia(file, size, key)))
                        }
                    }
            }
    } else {
        return .single(.content(.text(text)))
    }
}

func inputDocumentAttributesFromFileAttributes(_ fileAttributes: [TelegramMediaFileAttribute]) -> [Api.DocumentAttribute] {
    var attributes: [Api.DocumentAttribute] = []
    for attribute in fileAttributes {
        switch attribute {
            case .Animated:
                attributes.append(.documentAttributeAnimated)
            case let .FileName(fileName):
                attributes.append(.documentAttributeFilename(fileName: fileName))
            case let .ImageSize(size):
                attributes.append(.documentAttributeImageSize(w: Int32(size.width), h: Int32(size.height)))
            case let .Sticker(displayText, packReference, maskCoords):
                var stickerSet: Api.InputStickerSet = .inputStickerSetEmpty
                var flags: Int32 = 0
                if let packReference = packReference {
                    switch packReference {
                        case let .id(id, accessHash):
                            stickerSet = .inputStickerSetID(id: id, accessHash: accessHash)
                        case let .name(name):
                            stickerSet = .inputStickerSetShortName(shortName: name)
                    }
                }
                var inputMaskCoords: Api.MaskCoords?
                if let maskCoords = maskCoords {
                    flags |= 1 << 0
                    inputMaskCoords = .maskCoords(n: maskCoords.n, x: maskCoords.x, y: maskCoords.y, zoom: maskCoords.zoom)
                }
                attributes.append(.documentAttributeSticker(flags: flags, alt: displayText, stickerset: stickerSet, maskCoords: inputMaskCoords))
            case .HasLinkedStickers:
                attributes.append(.documentAttributeHasStickers)
            case let .Video(duration, size, videoFlags):
                var flags: Int32 = 0
                if videoFlags.contains(.instantRoundVideo) {
                    flags |= (1 << 0)
                }
                
                attributes.append(.documentAttributeVideo(flags: flags, duration: Int32(duration), w: Int32(size.width), h: Int32(size.height)))
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

private enum UploadedMediaThumbnailResult {
    case file(Api.InputFile)
    case none
}

private enum UploadedMediaThumbnail {
    case pending
    case done(UploadedMediaThumbnailResult)
}

private func uploadedThumbnail(network: Network, postbox: Postbox, image: TelegramMediaImageRepresentation) -> Signal<Api.InputFile?, PendingMessageUploadError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(image.resource), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false)
        |> mapError { _ -> PendingMessageUploadError in return .generic }
        |> mapToSignal { result -> Signal<Api.InputFile?, PendingMessageUploadError> in
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

public func statsCategoryForFileWithAttributes(_ attributes: [TelegramMediaFileAttribute]) -> MediaResourceStatsCategory {
    for attribute in attributes {
        switch attribute {
            case .Audio:
                return .audio
            case .Video:
                return .video
            default:
                break
        }
    }
    return .file
}

private func uploadedMediaFileContent(network: Network, postbox: Postbox, auxiliaryMethods: AccountAuxiliaryMethods, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, peerId: PeerId, messageId: MessageId?, text: String, attributes: [MessageAttribute], file: TelegramMediaFile) -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> {
    return maybePredownloadedFileResource(postbox: postbox, auxiliaryMethods: auxiliaryMethods, peerId: peerId, resource: file.resource) |> mapToSignal { result -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
        var referenceKey: CachedSentMediaReferenceKey?
        switch result {
            case let .media(media):
                if let file = media as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                    return .single(.progress(1.0)) |> then(.single(.content(.media(Api.InputMedia.inputMediaDocument(flags: 0, id: Api.InputDocument.inputDocument(id: resource.fileId, accessHash: resource.accessHash), ttlSeconds: nil), text))))
                }
            case let .localReference(key):
                referenceKey = key
            case .none:
                referenceKey = nil
        }
        
        var hintFileIsLarge = false
        var hintSize: Int?
        if let size = file.size {
            hintSize = size
        } else if let resource = file.resource as? LocalFileReferenceMediaResource, let size = resource.size {
            hintSize = Int(size)
        }
        if file.resource.headerSize != 0 {
            hintFileIsLarge = true
        }
        let upload = multipartUpload(network: network, postbox: postbox, source: .resource(file.resource), encrypt: peerId.namespace == Namespaces.Peer.SecretChat, tag: TelegramMediaResourceFetchTag(statsCategory: statsCategoryForFileWithAttributes(file.attributes)), hintFileSize: hintSize, hintFileIsLarge: hintFileIsLarge)
            |> mapError { _ -> PendingMessageUploadError in return .generic }
        var alreadyTransformed = false
        for attribute in attributes {
            if let attribute = attribute as? OutgoingMessageInfoAttribute {
                if attribute.flags.contains(.transformedMedia) {
                    alreadyTransformed = true
                }
            }
        }
    
        let transform: Signal<UploadedMediaTransform, Void>
        if let transformOutgoingMessageMedia = transformOutgoingMessageMedia, let messageId = messageId, !alreadyTransformed {
            transform = .single(.pending) |> then(transformOutgoingMessageMedia(postbox, network, file, false)
                |> mapToSignal { media -> Signal<UploadedMediaTransform, NoError> in
                    return postbox.modify { modifier -> UploadedMediaTransform in
                        if let media = media {
                            if let id = media.id {
                                modifier.updateMedia(id, update: media)
                                modifier.updateMessage(messageId, update: { currentMessage in
                                    var storeForwardInfo: StoreMessageForwardInfo?
                                    if let forwardInfo = currentMessage.forwardInfo {
                                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: nil)
                                    }
                                    var updatedAttributes = currentMessage.attributes
                                    if let index = updatedAttributes.index(where: { $0 is OutgoingMessageInfoAttribute }){
                                        let attribute = updatedAttributes[index] as! OutgoingMessageInfoAttribute
                                        updatedAttributes[index] = attribute.withUpdatedFlags(attribute.flags.union([.transformedMedia]))
                                    } else {
                                        updatedAttributes.append(OutgoingMessageInfoAttribute(uniqueId: arc4random64(), flags: [.transformedMedia]))
                                    }
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
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
    
        let thumbnail: Signal<UploadedMediaThumbnail, PendingMessageUploadError> = .single(.pending) |> then(transform
            |> mapToSignalPromotingError { media -> Signal<UploadedMediaThumbnail, PendingMessageUploadError> in
                switch media {
                    case .pending:
                        return .single(.pending)
                    case let .done(media):
                        if let media = media as? TelegramMediaFile, let smallestThumbnail = smallestImageRepresentation(media.previewRepresentations) {
                            if peerId.namespace == Namespaces.Peer.SecretChat {
                                return .single(.done(.none))
                            } else {
                                return uploadedThumbnail(network: network, postbox: postbox, image: smallestThumbnail)
                                    |> mapError { _ -> PendingMessageUploadError in return .generic }
                                    |> map { result in
                                        if let result = result {
                                            return .done(.file(result))
                                        } else {
                                            return .done(.none)
                                        }
                                    }
                            }
                        } else {
                            return .single(.done(.none))
                        }
                }
            })
    
        return combineLatest(upload, thumbnail)
            |> mapToSignal { content, thumbnailResult -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                switch content {
                    case let .progress(progress):
                        return .single(.progress(progress))
                    case let .inputFile(inputFile):
                        if case let .done(thumbnail) = thumbnailResult {
                            var flags: Int32 = 0
                            
                            var thumbnailFile: Api.InputFile?
                            if case let .file(file) = thumbnail {
                                thumbnailFile = file
                            }
                            
                            if let thumbnailFile = thumbnailFile {
                                flags |= 1 << 2
                            }
                            
                            var ttlSeconds: Int32?
                            for attribute in attributes {
                                if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                                    flags |= 1 << 1
                                    ttlSeconds = attribute.timeout
                                }
                            }
                            
                            if ttlSeconds != nil  {
                                return .single(.content(.media(.inputMediaUploadedDocument(flags: flags, file: inputFile, thumb: thumbnailFile, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFileAttributes(file.attributes), stickers: nil, ttlSeconds: ttlSeconds), text)))
                            }
                            
                            return postbox.modify { modifier -> Api.InputPeer? in
                                return modifier.getPeer(peerId).flatMap(apiInputPeer)
                            }
                            |> mapError { _ -> PendingMessageUploadError in return .generic }
                            |> mapToSignal { inputPeer -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                                if let inputPeer = inputPeer {
                                    return network.request(Api.functions.messages.uploadMedia(peer: inputPeer, media: .inputMediaUploadedDocument(flags: flags, file: inputFile, thumb: thumbnailFile, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFileAttributes(file.attributes), stickers: nil, ttlSeconds: ttlSeconds)))
                                        |> mapError { _ -> PendingMessageUploadError in return .generic }
                                        |> mapToSignal { result -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError> in
                                            switch result {
                                                case let .messageMediaDocument(_, document, _):
                                                    if let document = document, let mediaFile = telegramMediaFileFromApiDocument(document), let resource = mediaFile.resource as? CloudDocumentMediaResource {
                                                        return maybeCacheUploadedResource(postbox: postbox, key: referenceKey, result: .content(.media(.inputMediaDocument(flags: 0, id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash), ttlSeconds: nil), text)), media: mediaFile)
                                                    }
                                                default:
                                                    break
                                            }
                                            return .fail(.generic)
                                        }
                                } else {
                                    return .fail(.generic)
                                }
                            }
                        } else {
                            return .complete()
                        }
                    case let .inputSecretFile(file, size, key):
                        if case .done = thumbnailResult {
                            return .single(.content(.secretMedia(file, size, key)))
                        } else {
                            return .complete()
                        }
                }
        }
    }
}
