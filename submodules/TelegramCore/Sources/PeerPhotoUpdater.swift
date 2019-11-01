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

public func updateAccountPhoto(account: Account, resource: MediaResource?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: account.peerId, photo: resource.flatMap({ uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: $0) }), mapResourceToAvatarSizes: mapResourceToAvatarSizes)
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

public func updatePeerPhoto(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return updatePeerPhotoInternal(postbox: postbox, network: network, stateManager: stateManager, accountPeerId: accountPeerId, peer: postbox.loadedPeerWithId(peerId), photo: photo, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}
    
public func updatePeerPhotoInternal(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peer: Signal<Peer, NoError>, photo: Signal<UploadedPeerPhotoData, NoError>?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return peer
    |> mapError { _ in return .generic }
    |> mapToSignal { peer -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
        if let photo = photo {
            return photo
            |> take(until: { value in
                if case let .result(resultData) = value.content, case .inputFile = resultData {
                    return SignalTakeAction(passthrough: true, complete: true)
                } else {
                    return SignalTakeAction(passthrough: true, complete: false)
                }
            })
            |> mapError { _ -> UploadPeerPhotoError in return .generic }
            |> mapToSignal { result -> Signal<(UpdatePeerPhotoStatus, MediaResource?), UploadPeerPhotoError> in
                switch result.content {
                    case .error:
                        return .fail(.generic)
                    case let .result(resultData):
                        switch resultData {
                            case let .progress(progress):
                                return .single((.progress(progress), result.resource))
                            case let .inputFile(file):
                                if peer is TelegramUser {
                                    return network.request(Api.functions.photos.uploadProfilePhoto(file: file))
                                    |> mapError { _ in return UploadPeerPhotoError.generic }
                                    |> mapToSignal { photo -> Signal<(UpdatePeerPhotoStatus, MediaResource?), UploadPeerPhotoError> in
                                        var representations: [TelegramMediaImageRepresentation] = []
                                        switch photo {
                                        case let .photo(photo: apiPhoto, users: _):
                                            switch apiPhoto {
                                                case .photoEmpty:
                                                    break
                                                case let .photo(_, _, _, _, _, sizes, dcId):
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
                                                    
                                                    if let resource = result.resource as? LocalFileReferenceMediaResource {
                                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.localFilePath)) {
                                                            for representation in representations {
                                                                postbox.mediaBox.storeResourceData(representation.resource.id, data: data)
                                                            }
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
                                            return (.complete(representations), result.resource)
                                            
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
                                        
                                        return mapResourceToAvatarSizes(result.resource, groupOrChannel.profileImageRepresentations)
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
                                                return (.complete(groupOrChannel.profileImageRepresentations), result.resource)
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
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.localFilePath)) {
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
