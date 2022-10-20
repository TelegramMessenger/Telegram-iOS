import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi


public enum UpdatePeerPhotoStatus {
    case progress(Float)
    case complete([TelegramMediaImageRepresentation])
}

public enum UploadPeerPhotoError {
    case generic
}

func _internal_updateAccountPhoto(account: Account, resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return _internal_updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: account.peerId, photo: resource.flatMap({ _internal_uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: $0) }), video: videoResource.flatMap({ _internal_uploadedPeerVideo(postbox: account.postbox, network: account.network, messageMediaPreuploadManager: account.messageMediaPreuploadManager, resource: $0) |> map(Optional.init) }), videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}

public struct UploadedPeerPhotoData {
    fileprivate let resource: MediaResource
    fileprivate let content: UploadedPeerPhotoDataContent
    
    public var isCompleted: Bool {
        if case let .result(result) = content, case .inputFile = result {
            return true
        } else {
            return false
        }
    }
}

enum UploadedPeerPhotoDataContent {
    case result(MultipartUploadResult)
    case error
}

func _internal_uploadedPeerPhoto(postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
    |> map { result -> UploadedPeerPhotoData in
        return UploadedPeerPhotoData(resource: resource, content: .result(result))
    }
    |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
        return .single(UploadedPeerPhotoData(resource: resource, content: .error))
    }
}

func _internal_uploadedPeerVideo(postbox: Postbox, network: Network, messageMediaPreuploadManager: MessageMediaPreuploadManager?, resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
    if let messageMediaPreuploadManager = messageMediaPreuploadManager {
        return messageMediaPreuploadManager.upload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .video), hintFileSize: nil, hintFileIsLarge: false)
        |> map { result -> UploadedPeerPhotoData in
            return UploadedPeerPhotoData(resource: resource, content: .result(result))
        }
        |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
            return .single(UploadedPeerPhotoData(resource: resource, content: .error))
        }
    } else {
        return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .video), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
       |> map { result -> UploadedPeerPhotoData in
           return UploadedPeerPhotoData(resource: resource, content: .result(result))
       }
       |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
           return .single(UploadedPeerPhotoData(resource: resource, content: .error))
       }
    }
}

func _internal_updatePeerPhoto(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>? = nil, videoStartTimestamp: Double? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return _internal_updatePeerPhotoInternal(postbox: postbox, network: network, stateManager: stateManager, accountPeerId: accountPeerId, peer: postbox.loadedPeerWithId(peerId), photo: photo, video: video, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}
    
func _internal_updatePeerPhotoInternal(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peer: Signal<Peer, NoError>, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>?, videoStartTimestamp: Double?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return peer
    |> mapError { _ -> UploadPeerPhotoError in }
    |> mapToSignal { peer -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
        if let photo = photo {
            let mappedPhoto = photo
            |> take(until: { value in
                if case let .result(resultData) = value.content, case .inputFile = resultData {
                    return SignalTakeAction(passthrough: true, complete: true)
                } else {
                    return SignalTakeAction(passthrough: true, complete: false)
                }
            })
            
            let mappedVideo: Signal<UploadedPeerPhotoData?, NoError>
            if let video = video {
                mappedVideo = video
                |> take(until: { value in
                    if case let .result(resultData)? = value?.content, case .inputFile = resultData {
                        return SignalTakeAction(passthrough: true, complete: true)
                    } else {
                        return SignalTakeAction(passthrough: true, complete: false)
                    }
                })
            } else {
                mappedVideo = .single(nil)
            }
            
            return combineLatest(mappedPhoto, mappedVideo)
            |> mapError { _ -> UploadPeerPhotoError in }
            |> mapToSignal { photoResult, videoResult -> Signal<(UpdatePeerPhotoStatus, MediaResource?, MediaResource?), UploadPeerPhotoError> in
                switch photoResult.content {
                    case .error:
                        return .fail(.generic)
                    case let .result(resultData):
                        switch resultData {
                            case let .progress(progress):
                                var mappedProgress = progress
                                if let _ = videoResult {
                                    mappedProgress *= 0.2
                                }
                                return .single((.progress(mappedProgress), photoResult.resource, videoResult?.resource))
                            case let .inputFile(file):
                                var videoFile: Api.InputFile?
                                if let videoResult = videoResult {
                                    switch videoResult.content {
                                        case .error:
                                            return .fail(.generic)
                                        case let .result(resultData):
                                            switch resultData {
                                                case let .progress(progress):
                                                    let mappedProgress = 0.2 + progress * 0.8
                                                    return .single((.progress(mappedProgress), photoResult.resource, videoResult.resource))
                                                case let .inputFile(file):
                                                    videoFile = file
                                                    break
                                                default:
                                                    return .fail(.generic)
                                            }
                                    }
                                }
                                if peer is TelegramUser {
                                    var flags: Int32 = (1 << 0)
                                    if let _ = videoFile {
                                        flags |= (1 << 1)
                                        if let _ = videoStartTimestamp {
                                            flags |= (1 << 2)
                                        }
                                    }
                                    
                                    return network.request(Api.functions.photos.uploadProfilePhoto(flags: flags, file: file, video: videoFile, videoStartTs: videoStartTimestamp))
                                    |> mapError { _ in return UploadPeerPhotoError.generic }
                                    |> mapToSignal { photo -> Signal<(UpdatePeerPhotoStatus, MediaResource?, MediaResource?), UploadPeerPhotoError> in
                                        var representations: [TelegramMediaImageRepresentation] = []
                                        var videoRepresentations: [TelegramMediaImage.VideoRepresentation] = []
                                        switch photo {
                                        case let .photo(photo: apiPhoto, users: _):
                                            switch apiPhoto {
                                                case .photoEmpty:
                                                    break
                                                case let .photo(_, id, accessHash, fileReference, _, sizes, videoSizes, dcId):
                                                    var sizes = sizes
                                                    if sizes.count == 3 {
                                                        sizes.remove(at: 1)
                                                    }
                                                    for size in sizes {
                                                        switch size {
                                                            case let .photoSize(_, w, h, _):
                                                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: id, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: nil, localId: nil), progressiveSizes: [], immediateThumbnailData: nil))
                                                            case let .photoSizeProgressive(_, w, h, sizes):
                                                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: id, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: nil, localId: nil), progressiveSizes: sizes, immediateThumbnailData: nil))
                                                            default:
                                                                break
                                                        }
                                                    }
                                                    
                                                    if let videoSizes = videoSizes {
                                                        for size in videoSizes {
                                                            switch size {
                                                                case let .videoSize(_, type, w, h, size, videoStartTs):
                                                                    let resource: TelegramMediaResource
                                                                    resource = CloudPhotoSizeMediaResource(datacenterId: dcId, photoId: id, accessHash: accessHash, sizeSpec: type, size: Int64(size), fileReference: fileReference.makeData())
                                                                    
                                                                    videoRepresentations.append(TelegramMediaImage.VideoRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, startTimestamp: videoStartTs))
                                                            }
                                                        }
                                                    }
                                                    
                                                    for representation in representations {
                                                        postbox.mediaBox.copyResourceData(from: photoResult.resource.id, to: representation.resource.id)
                                                    }
                                                
                                                    if let resource = videoResult?.resource {
                                                        for representation in videoRepresentations {
                                                            postbox.mediaBox.copyResourceData(from: resource.id, to: representation.resource.id)
                                                        }
                                                    }
                                            }
                                        }
                                        return postbox.transaction { transaction -> (UpdatePeerPhotoStatus, MediaResource?, MediaResource?) in
                                            if let peer = transaction.getPeer(peer.id) {
                                                updatePeers(transaction: transaction, peers: [peer], update: { (_, peer) -> Peer? in
                                                    if let peer = peer as? TelegramUser {
                                                        return peer.withUpdatedPhoto(representations)
                                                    } else {
                                                        return peer
                                                    }
                                                })
                                            }
                                            return (.complete(representations), photoResult.resource, videoResult?.resource)
                                        } |> mapError { _ -> UploadPeerPhotoError in }
                                    }
                                } else {
                                    var flags: Int32 = (1 << 0)
                                    if let _ = videoFile {
                                        flags |= (1 << 1)
                                        if let _ = videoStartTimestamp {
                                            flags |= (1 << 2)
                                        }
                                    }
                                    
                                    let request: Signal<Api.Updates, MTRpcError>
                                    if let peer = peer as? TelegramGroup {
                                        request = network.request(Api.functions.messages.editChatPhoto(chatId: peer.id.id._internalGetInt64Value(), photo: .inputChatUploadedPhoto(flags: flags, file: file, video: videoFile, videoStartTs: videoStartTimestamp)))
                                    } else if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                                        request = network.request(Api.functions.channels.editPhoto(channel: inputChannel, photo: .inputChatUploadedPhoto(flags: flags, file: file, video: videoFile, videoStartTs: videoStartTimestamp)))
                                    } else {
                                        assertionFailure()
                                        request = .complete()
                                    }
                                    
                                    return request
                                    |> mapError {_ in return UploadPeerPhotoError.generic}
                                    |> mapToSignal { updates -> Signal<(UpdatePeerPhotoStatus, MediaResource?, MediaResource?), UploadPeerPhotoError> in
                                        guard let chat = updates.chats.first, chat.peerId == peer.id, let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) else {
                                            stateManager?.addUpdates(updates)
                                            return .fail(.generic)
                                        }
                                        
                                        return mapResourceToAvatarSizes(photoResult.resource, groupOrChannel.profileImageRepresentations)
                                        |> castError(UploadPeerPhotoError.self)
                                        |> mapToSignal { generatedData -> Signal<(UpdatePeerPhotoStatus, MediaResource?, MediaResource?), UploadPeerPhotoError> in
                                            stateManager?.addUpdates(updates)
                                            
                                            for (index, data) in generatedData {
                                                if index >= 0 && index < groupOrChannel.profileImageRepresentations.count {
                                                    postbox.mediaBox.storeResourceData(groupOrChannel.profileImageRepresentations[index].resource.id, data: data)
                                                } else {
                                                    assertionFailure()
                                                }
                                            }

                                            return postbox.transaction { transaction -> (UpdatePeerPhotoStatus, MediaResource?, MediaResource?) in
                                                updatePeers(transaction: transaction, peers: [groupOrChannel], update: { _, updated in
                                                    return updated
                                                })
                                                return (.complete(groupOrChannel.profileImageRepresentations), photoResult.resource, videoResult?.resource)
                                            }
                                            |> mapError { _ -> UploadPeerPhotoError in }
                                        }
                                    }
                                }
                            default:
                                return .fail(.generic)
                        }
                }
            }
            |> mapToSignal { result, resource, videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                if case .complete = result {
                    return _internal_fetchAndUpdateCachedPeerData(accountPeerId: accountPeerId, peerId: peer.id, network: network, postbox: postbox)
                    |> castError(UploadPeerPhotoError.self)
                    |> mapToSignal { status -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                        return postbox.transaction { transaction in
                            if let videoResource = videoResource {
                                let cachedData = transaction.getPeerCachedData(peerId: peer.id)
                                if let cachedData = cachedData as? CachedChannelData {
                                    if let photo = cachedData.photo {
                                        for representation in photo.videoRepresentations {
                                            postbox.mediaBox.copyResourceData(from: videoResource.id, to: representation.resource.id, synchronous: true)
                                        }
                                    }
                                } else if let cachedData = cachedData as? CachedGroupData {
                                    if let photo = cachedData.photo {
                                        for representation in photo.videoRepresentations {
                                            postbox.mediaBox.copyResourceData(from: videoResource.id, to: representation.resource.id, synchronous: true)
                                        }
                                    }
                                }
                            }
                            return result
                        }
                        |> castError(UploadPeerPhotoError.self)
                    }
                } else {
                    return .single(result)
                }
            }
        } else {
            if let _ = peer as? TelegramUser {
                let signal: Signal<Api.photos.Photo, UploadPeerPhotoError> = network.request(Api.functions.photos.updateProfilePhoto(id: Api.InputPhoto.inputPhotoEmpty))
                |> mapError { _ -> UploadPeerPhotoError in
                    return .generic
                }
                    
                return signal
                |> mapToSignal { _ -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                    return .single(.complete([]))
                }
            } else {
                let request: Signal<Api.Updates, MTRpcError>
                if let peer = peer as? TelegramGroup {
                    request = network.request(Api.functions.messages.editChatPhoto(chatId: peer.id.id._internalGetInt64Value(), photo: .inputChatPhotoEmpty))
                } else if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                    request = network.request(Api.functions.channels.editPhoto(channel: inputChannel, photo: .inputChatPhotoEmpty))
                } else {
                    assertionFailure()
                    request = .complete()
                }
                
                return request
                |> mapError {_ in return UploadPeerPhotoError.generic}
                |> mapToSignal { updates -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                    stateManager?.addUpdates(updates)
                    for chat in updates.chats {
                        if chat.peerId == peer.id {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                return postbox.transaction { transaction -> UpdatePeerPhotoStatus in
                                    updatePeers(transaction: transaction, peers: [groupOrChannel], update: { _, updated in
                                        return updated
                                    })
                                    
                                    transaction.updatePeerCachedData(peerIds: Set([peer.id]), update: { _, current in
                                        if let current = current as? CachedChannelData {
                                            return current.withUpdatedPhoto(nil)
                                        } else if let current = current as? CachedGroupData {
                                            return current.withUpdatedPhoto(nil)
                                        } else {
                                            return current
                                        }
                                    })
                                    
                                    return .complete(groupOrChannel.profileImageRepresentations)
                                }
                                |> mapError { _ -> UploadPeerPhotoError in }
                            }
                        }
                    }
                    
                    return .fail(.generic)
                }
            }
        }
    }
}

func _internal_updatePeerPhotoExisting(network: Network, reference: TelegramMediaImageReference) -> Signal<TelegramMediaImage?, NoError> {
    switch reference {
        case let .cloud(imageId, accessHash, fileReference):
            return network.request(Api.functions.photos.updateProfilePhoto(id: .inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference))))
            |> `catch` { _ -> Signal<Api.photos.Photo, NoError> in
                return .complete()
            }
            |> mapToSignal { photo -> Signal<TelegramMediaImage?, NoError> in
                if case let .photo(photo, _) = photo {
                    return .single(telegramMediaImageFromApiPhoto(photo))
                } else {
                    return .complete()
                }
            }
    }
}

func _internal_removeAccountPhoto(network: Network, reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
    if let reference = reference {
        switch reference {
        case let .cloud(imageId, accessHash, fileReference):
            if let fileReference = fileReference {
                return network.request(Api.functions.photos.deletePhotos(id: [.inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference))]))
                |> `catch` { _ -> Signal<[Int64], NoError> in
                    return .single([])
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else {
                return .complete()
            }
        }
    } else {
        let api = Api.functions.photos.updateProfilePhoto(id: Api.InputPhoto.inputPhotoEmpty)
        return network.request(api) |> map { _ in } |> retryRequest
    }
}
