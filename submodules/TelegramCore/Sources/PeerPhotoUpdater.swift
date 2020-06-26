import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi

import SyncCore

public enum UpdatePeerPhotoStatus {
    case progress(Float)
    case complete([TelegramMediaImageRepresentation])
}

public enum UploadPeerPhotoError {
    case generic
}

public func updateAccountPhoto(account: Account, resource: MediaResource?, videoResource: MediaResource?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: account.peerId, photo: resource.flatMap({ uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: $0) }), video: videoResource.flatMap({ uploadedPeerVideo(postbox: account.postbox, network: account.network, messageMediaPreuploadManager: account.messageMediaPreuploadManager, resource: $0) |> map(Optional.init) }), mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}

public struct UploadedPeerPhotoData {
    fileprivate let resource: MediaResource
    fileprivate let content: UploadedPeerPhotoDataContent
}

private enum UploadedPeerPhotoDataContent {
    case result(MultipartUploadResult)
    case error
}

public func uploadedPeerPhoto(postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false)
    |> map { result -> UploadedPeerPhotoData in
        return UploadedPeerPhotoData(resource: resource, content: .result(result))
    }
    |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
        return .single(UploadedPeerPhotoData(resource: resource, content: .error))
    }
}

public func uploadedPeerVideo(postbox: Postbox, network: Network, messageMediaPreuploadManager: MessageMediaPreuploadManager, resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
    return messageMediaPreuploadManager.upload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .video), hintFileSize: nil, hintFileIsLarge: false)
    |> map { result -> UploadedPeerPhotoData in
        return UploadedPeerPhotoData(resource: resource, content: .result(result))
    }
    |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
        return .single(UploadedPeerPhotoData(resource: resource, content: .error))
    }
}

public func updatePeerPhoto(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return updatePeerPhotoInternal(postbox: postbox, network: network, stateManager: stateManager, accountPeerId: accountPeerId, peer: postbox.loadedPeerWithId(peerId), photo: photo, video: video, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}
    
public func updatePeerPhotoInternal(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peer: Signal<Peer, NoError>, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return peer
    |> mapError { _ in return .generic }
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
            |> mapError { _ -> UploadPeerPhotoError in return .generic }
            |> mapToSignal { photoResult, videoResult -> Signal<(UpdatePeerPhotoStatus, MediaResource?), UploadPeerPhotoError> in
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
                                return .single((.progress(mappedProgress), photoResult.resource))
                            case let .inputFile(file):
                                if peer is TelegramUser {
                                    var videoFile: Api.InputFile?
                                    if let videoResult = videoResult {
                                        switch videoResult.content {
                                            case .error:
                                                return .fail(.generic)
                                            case let .result(resultData):
                                                switch resultData {
                                                    case let .progress(progress):
                                                        let mappedProgress = 0.2 + progress * 0.8
                                                        return .single((.progress(mappedProgress), photoResult.resource))
                                                    case let .inputFile(file):
                                                        videoFile = file
                                                        break
                                                    default:
                                                        return .fail(.generic)
                                                }
                                        }
                                    }
                                    
                                    var flags: Int32 = 0
                                    if let _ = videoFile {
                                        flags |= (1 << 0)
                                    }
                                    
                                    return network.request(Api.functions.photos.uploadProfilePhoto(flags: flags, file: file, video: videoFile))
                                    |> mapError { _ in return UploadPeerPhotoError.generic }
                                    |> mapToSignal { photo -> Signal<(UpdatePeerPhotoStatus, MediaResource?), UploadPeerPhotoError> in
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
                                                            case let .photoSize(_, location, w, h, _):
                                                                switch location {
                                                                    case let .fileLocationToBeDeprecated(volumeId, localId):
                                                                        representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: volumeId, localId: localId)))
                                                                }
                                                            default:
                                                                break
                                                        }
                                                    }
                                                    
                                                    if let videoSizes = videoSizes {
                                                        for size in videoSizes {
                                                            switch size {
                                                                case let .videoSize(type, location, w, h, size):
                                                                    let resource: TelegramMediaResource
                                                                    switch location {
                                                                        case let .fileLocationToBeDeprecated(volumeId, localId):
                                                                            resource = CloudPhotoSizeMediaResource(datacenterId: dcId, photoId: id, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, size: Int(size), fileReference: fileReference.makeData())
                                                                    }
                                                                    
                                                                    videoRepresentations.append(TelegramMediaImage.VideoRepresentation(
                                                                        dimensions: PixelDimensions(width: w, height: h),
                                                                        resource: resource))
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
                                        return postbox.transaction { transaction -> (UpdatePeerPhotoStatus, MediaResource?) in
                                            if let peer = transaction.getPeer(peer.id) {
                                                updatePeers(transaction: transaction, peers: [peer], update: { (_, peer) -> Peer? in
                                                    if let peer = peer as? TelegramUser {
                                                        return peer.withUpdatedPhoto(representations)
                                                    } else {
                                                        return peer
                                                    }
                                                })
                                            }
                                            return (.complete(representations), photoResult.resource)
                                        } |> mapError {_ in return UploadPeerPhotoError.generic}
                                    }
                                } else {
                                    let request: Signal<Api.Updates, MTRpcError>
                                    if let peer = peer as? TelegramGroup {
                                        request = network.request(Api.functions.messages.editChatPhoto(chatId: peer.id.id, photo: .inputChatUploadedPhoto(file: file)))
                                    } else if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                                        request = network.request(Api.functions.channels.editPhoto(channel: inputChannel, photo: .inputChatUploadedPhoto(file: file)))
                                    } else {
                                        assertionFailure()
                                        request = .complete()
                                    }
                                    
                                    return request
                                    |> mapError {_ in return UploadPeerPhotoError.generic}
                                    |> mapToSignal { updates -> Signal<(UpdatePeerPhotoStatus, MediaResource?), UploadPeerPhotoError> in
                                        guard let chat = updates.chats.first, chat.peerId == peer.id, let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) else {
                                            stateManager?.addUpdates(updates)
                                            return .fail(.generic)
                                        }
                                        
                                        return mapResourceToAvatarSizes(photoResult.resource, groupOrChannel.profileImageRepresentations)
                                        |> castError(UploadPeerPhotoError.self)
                                        |> mapToSignal { generatedData -> Signal<(UpdatePeerPhotoStatus, MediaResource?), UploadPeerPhotoError> in
                                            stateManager?.addUpdates(updates)
                                            
                                            for (index, data) in generatedData {
                                                if index >= 0 && index < groupOrChannel.profileImageRepresentations.count {
                                                    postbox.mediaBox.storeResourceData(groupOrChannel.profileImageRepresentations[index].resource.id, data: data)
                                                } else {
                                                    assertionFailure()
                                                }
                                            }
                                            
                                            return postbox.transaction { transaction -> (UpdatePeerPhotoStatus, MediaResource?) in
                                                updatePeers(transaction: transaction, peers: [groupOrChannel], update: { _, updated in
                                                    return updated
                                                })
                                                return (.complete(groupOrChannel.profileImageRepresentations), photoResult.resource)
                                            }
                                            |> mapError { _ in return .generic }
                                        }
                                    }
                                }
                            default:
                                return .fail(.generic)
                        }
                }
            }
            |> map { result, resource -> UpdatePeerPhotoStatus in
                switch result {
                    case let .complete(representations):
                        if let resource = resource as? LocalFileReferenceMediaResource {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.localFilePath), options: [.mappedRead] ) {
                                for representation in representations {
                                    postbox.mediaBox.storeResourceData(representation.resource.id, data: data)
                                }
                            }
                        }
                    default:
                        break
                }
                return result
            }
        } else {
            if let _ = peer as? TelegramUser {
                return network.request(Api.functions.photos.updateProfilePhoto(id: Api.InputPhoto.inputPhotoEmpty))
                |> `catch` { _ -> Signal<Api.UserProfilePhoto, UploadPeerPhotoError> in
                    return .fail(.generic)
                }
                |> mapToSignal { _ -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                    return .single(.complete([]))
                }
            } else {
                let request: Signal<Api.Updates, MTRpcError>
                if let peer = peer as? TelegramGroup {
                    request = network.request(Api.functions.messages.editChatPhoto(chatId: peer.id.id, photo: .inputChatPhotoEmpty))
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
                                    return .complete(groupOrChannel.profileImageRepresentations)
                                }
                                |> mapError { _ in return .generic }
                            }
                        }
                    }
                    
                    return .fail(.generic)
                }
            }
        }
    }
}

public func updatePeerPhotoExisting(network: Network, reference: TelegramMediaImageReference) -> Signal<Void, NoError> {
    switch reference {
        case let .cloud(imageId, accessHash, fileReference):
            return network.request(Api.functions.photos.updateProfilePhoto(id: .inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference))))
            |> `catch` { _ -> Signal<Api.UserProfilePhoto, NoError> in
                return .complete()
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
    }
}

public func removeAccountPhoto(network: Network, reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
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
