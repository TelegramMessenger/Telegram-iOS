import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

/// A medium on its way to becoming cloud media.
enum CloudUploadEvent {
    case progress(Float)
    /// Cloud media: a `TelegramMediaImage` with a `.cloud` reference, or a `TelegramMediaFile`
    /// backed by a `CloudDocumentMediaResource`.
    case done(Media)
}

/// Can this medium be pre-uploaded at all?
///
/// Excludes anything with no bytes (a location, a webpage) and anything already in the cloud —
/// an edit or paste round-trip carries media that needs no work.
/// `allowAlreadyCloud` is for the forced-re-upload path: the cloud reference has been rejected by the
/// server, so "already cloud" is no longer a reason to skip the work. The bytes are usually still on
/// disk under the cloud resource id (cloud promotion calls `moveResourceData` into it), so the
/// re-upload is local. See the residual gap noted in the pre-upload design doc, section 8.1.
func isPreuploadableMedia(_ media: Media, allowAlreadyCloud: Bool = false) -> Bool {
    if let image = media as? TelegramMediaImage {
        if !allowAlreadyCloud, let reference = image.reference, case .cloud = reference {
            return false
        }
        return largestImageRepresentation(image.representations) != nil
    }
    if let file = media as? TelegramMediaFile {
        if !allowAlreadyCloud, let resource = file.resource as? CloudDocumentMediaResource, resource.fileReference != nil {
            return false
        }
        return true
    }
    return false
}

/// Bytes -> `messages.uploadMedia` -> cloud `Media`, for one medium.
///
/// Byte transfer goes through `messageMediaPreuploadManager.upload(...)`, so where the resource has
/// a `localIdForResource` this shares a byte context with anything else uploading the same bytes.
func uploadMediaToCloud(
    network: Network,
    postbox: Postbox,
    messageMediaPreuploadManager: MessageMediaPreuploadManager,
    peerId: PeerId,
    media: Media
) -> Signal<CloudUploadEvent, PendingMessageUploadError> {
    if let image = media as? TelegramMediaImage {
        return uploadImageToCloud(network: network, postbox: postbox, messageMediaPreuploadManager: messageMediaPreuploadManager, peerId: peerId, image: image)
    }
    if let file = media as? TelegramMediaFile {
        return uploadFileToCloud(network: network, postbox: postbox, messageMediaPreuploadManager: messageMediaPreuploadManager, peerId: peerId, file: file)
    }
    return .fail(.generic)
}

private func uploadImageToCloud(
    network: Network,
    postbox: Postbox,
    messageMediaPreuploadManager: MessageMediaPreuploadManager,
    peerId: PeerId,
    image: TelegramMediaImage
) -> Signal<CloudUploadEvent, PendingMessageUploadError> {
    guard let largestRepresentation = largestImageRepresentation(image.representations) else {
        return .fail(.generic)
    }

    return maybePredownloadedImageResource(postbox: postbox, peerId: peerId, resource: largestRepresentation.resource, forceRefresh: false)
    |> mapToSignal { predownloaded -> Signal<CloudUploadEvent, PendingMessageUploadError> in
        var referenceKey: CachedSentMediaReferenceKey?
        switch predownloaded {
        case let .media(cachedMedia, key):
            // These exact bytes have been uploaded before: reuse the cloud media, no network at all.
            if let cachedImage = cachedMedia as? TelegramMediaImage, let reference = cachedImage.reference, case .cloud = reference {
                return .single(.progress(1.0)) |> then(.single(.done(cachedImage)))
            }
            referenceKey = key
        case let .localReference(key):
            referenceKey = key
        case .none:
            referenceKey = nil
        }

        let imageReference: AnyMediaReference = .standalone(media: image)
        let upload = messageMediaPreuploadManager.upload(
            network: network,
            postbox: postbox,
            source: .resource(imageReference.resourceReference(largestRepresentation.resource)),
            encrypt: false,
            tag: TelegramMediaResourceFetchTag(statsCategory: .image, userContentType: .image),
            hintFileSize: nil,
            hintFileIsLarge: false,
            forceNoBigParts: false
        )
        |> mapError { _ -> PendingMessageUploadError in
            return .generic
        }

        return upload
        |> mapToSignal { result -> Signal<CloudUploadEvent, PendingMessageUploadError> in
            switch result {
            case let .progress(value):
                return .single(.progress(value))
            case .inputSecretFile:
                return .fail(.generic)
            case let .inputFile(inputFile):
                return postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> mapError { _ -> PendingMessageUploadError in
                }
                |> mapToSignal { inputPeer -> Signal<CloudUploadEvent, PendingMessageUploadError> in
                    guard let inputPeer else {
                        return .fail(.generic)
                    }
                    return network.request(Api.functions.messages.uploadMedia(
                        flags: 0,
                        businessConnectionId: nil,
                        peer: inputPeer,
                        media: .inputMediaUploadedPhoto(.init(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil, video: nil))
                    ))
                    |> mapError { _ -> PendingMessageUploadError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<CloudUploadEvent, PendingMessageUploadError> in
                        guard case let .messageMediaPhoto(data) = result,
                              let photo = data.photo,
                              let cloudImage = telegramMediaImageFromApiPhoto(photo) else {
                            return .fail(.generic)
                        }
                        guard let referenceKey else {
                            return .single(.done(cloudImage))
                        }
                        // Content-hash dedup, so a later send of the same bytes short-circuits above.
                        return postbox.transaction { transaction -> CloudUploadEvent in
                            storeCachedSentMediaReference(transaction: transaction, key: referenceKey, media: cloudImage)
                            return .done(cloudImage)
                        }
                        |> mapError { _ -> PendingMessageUploadError in
                        }
                    }
                }
            }
        }
    }
}

/// Shared by the pre-upload path and by `uploadedMediaPhotoVideoContent`.
func uploadFileToCloud(
    network: Network,
    postbox: Postbox,
    messageMediaPreuploadManager: MessageMediaPreuploadManager,
    peerId: PeerId,
    file: TelegramMediaFile
) -> Signal<CloudUploadEvent, PendingMessageUploadError> {
    var hintFileIsLarge = false
    var hintSize: Int64?
    if let size = file.size {
        hintSize = size
    } else if let resource = file.resource as? LocalFileReferenceMediaResource, let size = resource.size {
        hintSize = size
    }
    loop: for attribute in file.attributes {
        switch attribute {
        case .hintFileIsLarge:
            hintFileIsLarge = true
            break loop
        default:
            break
        }
    }

    let fileReference: AnyMediaReference
    if let partialReference = file.partialReference {
        fileReference = partialReference.mediaReference(file)
    } else {
        fileReference = .standalone(media: file)
    }

    return messageMediaPreuploadManager.upload(
        network: network,
        postbox: postbox,
        source: .resource(fileReference.resourceReference(file.resource)),
        encrypt: false,
        tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
        hintFileSize: hintSize,
        hintFileIsLarge: hintFileIsLarge,
        forceNoBigParts: false
    )
    |> mapError { _ -> PendingMessageUploadError in
        return .generic
    }
    |> mapToSignal { result -> Signal<CloudUploadEvent, PendingMessageUploadError> in
        switch result {
        case let .progress(value):
            return .single(.progress(value))
        case .inputSecretFile:
            return .fail(.generic)
        case let .inputFile(inputFile):
            return postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapError { _ -> PendingMessageUploadError in
            }
            |> mapToSignal { inputPeer -> Signal<CloudUploadEvent, PendingMessageUploadError> in
                guard let inputPeer else {
                    return .fail(.generic)
                }
                return network.request(Api.functions.messages.uploadMedia(
                    flags: 0,
                    businessConnectionId: nil,
                    peer: inputPeer,
                    media: .inputMediaUploadedDocument(.init(
                        flags: 0,
                        file: inputFile,
                        thumb: nil,
                        mimeType: file.mimeType,
                        attributes: inputDocumentAttributesFromFileAttributes(file.attributes),
                        stickers: nil,
                        videoCover: nil,
                        videoTimestamp: nil,
                        ttlSeconds: nil
                    ))
                ))
                |> mapError { _ -> PendingMessageUploadError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<CloudUploadEvent, PendingMessageUploadError> in
                    guard case let .messageMediaDocument(data) = result,
                          let document = data.document,
                          let cloudFile = telegramMediaFileFromApiDocument(document, altDocuments: data.altDocuments) else {
                        return .fail(.generic)
                    }
                    return .single(.done(cloudFile))
                }
            }
        }
    }
}
