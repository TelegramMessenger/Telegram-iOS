
import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public enum UpdatePeerPhotoStatus {
    case progress(Float)
    case complete([TelegramMediaImageRepresentation])
}

public enum UploadPeerPhotoError {
    case generic
}

public func updateAccountPhoto(account:Account, resource:MediaResource) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return updatePeerPhoto(account: account, peerId: account.peerId, resource: resource)
}

public func updatePeerPhoto(account:Account, peerId:PeerId, resource:MediaResource) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
     return account.postbox.loadedPeerWithId(peerId) |> mapError {_ in return .generic} |> mapToSignal { peer in
        return multipartUpload(network: account.network, postbox: account.postbox, resource: resource, encrypt: false)
            |> mapError {_ in return .generic}
            |> mapToSignal { result -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                switch result {
                case let .progress(progress):
                    return .single(.progress(progress))
                case let .inputFile(file):
                    if peer is TelegramUser {
                        return account.network.request(Api.functions.photos.uploadProfilePhoto(file: file))
                            |> mapError {_ in return UploadPeerPhotoError.generic}
                            |> mapToSignal { photo -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                                
                                let representations:[TelegramMediaImageRepresentation]
                                switch photo {
                                case let .photo(photo: apiPhoto, users: _):
                                    switch apiPhoto {
                                    case .photoEmpty:
                                        representations = []
                                    case let .photo(flags: _, id: _, accessHash: _, date: _, sizes: sizes):
                                        var sizes = sizes
                                        if sizes.count == 3 {
                                            sizes.remove(at: 1)
                                        }
                                        representations = telegramMediaImageRepresentationsFromApiSizes(sizes)
                                        if let resource = resource as? LocalFileReferenceMediaResource {
                                            if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.localFilePath)) {
                                                for representation in representations {
                                                    account.postbox.mediaBox.storeResourceData(representation.resource.id, data: data)
                                                }
                                            }
                                        }
                                       
                                    }
                                }
                                return account.postbox.modify { modifier -> UpdatePeerPhotoStatus in
                                    if let peer = modifier.getPeer(peer.id) {
                                        updatePeers(modifier: modifier, peers: [peer], update: { (_, peer) -> Peer? in
                                            if let peer = peer as? TelegramUser {
                                                return peer.withUpdatedPhoto(representations)
                                            } else {
                                                return peer
                                            }
                                        })
                                    }
                                    return .complete(representations)
                                    
                                } |> mapError {_ in return UploadPeerPhotoError.generic}
                        }
                    } else  {
                        let request:Signal<Api.Updates, MTRpcError>
                        if let peer = peer as? TelegramGroup {
                            request = account.network.request(Api.functions.messages.editChatPhoto(chatId: peer.id.id, photo: .inputChatUploadedPhoto(file: file)))
                        } else if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                            request = account.network.request(Api.functions.channels.editPhoto(channel: inputChannel, photo: .inputChatUploadedPhoto(file: file)))
                        } else {
                            assertionFailure()
                            request = .complete()
                        }
                        
                        return request |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { updates -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                            account.stateManager.addUpdates(updates)
                            for chat in updates.chats {
                                if chat.peerId == peerId {
                                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                        return .single(.complete(groupOrChannel.profileImageRepresentations))
                                    }
                                }
                            }
                            
                            return .fail(.generic)
                        }
                    }
                    
                default:
                    return .fail(.generic)
                }
        }
    } |> map { result in
        
        switch result {
        case let .complete(representations):
            if let resource = resource as? LocalFileReferenceMediaResource {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.localFilePath)) {
                    for representation in representations {
                        account.postbox.mediaBox.storeResourceData(representation.resource.id, data: data)
                    }
                }
            }
        default:
            break
        }
        
        return result
    }
}
