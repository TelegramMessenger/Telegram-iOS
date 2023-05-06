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

public enum UploadPeerPhotoMarkup {
    case emoji(fileId: Int64, backgroundColors: [Int32])
    case sticker(packReference: StickerPackReference, fileId: Int64, backgroundColors: [Int32])
}

func _internal_updateAccountPhoto(account: Account, resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, fallback: Bool, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    let photo: Signal<UploadedPeerPhotoData, NoError>?
    if videoResource == nil && markup != nil, let resource = resource {
        photo = .single(UploadedPeerPhotoData.withResource(resource))
    } else {
        photo = resource.flatMap({ _internal_uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: $0) })
    }
    return _internal_updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: account.peerId, photo: photo, video: videoResource.flatMap({ _internal_uploadedPeerVideo(postbox: account.postbox, network: account.network, messageMediaPreuploadManager: account.messageMediaPreuploadManager, resource: $0) |> map(Optional.init) }), videoStartTimestamp: videoStartTimestamp, markup: markup, fallback: fallback, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}

public enum SetCustomPeerPhotoMode {
    case custom
    case suggest
    case customAndSuggest
}

func _internal_updateContactPhoto(account: Account, peerId: PeerId, resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, mode: SetCustomPeerPhotoMode, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    let photo: Signal<UploadedPeerPhotoData, NoError>?
    if videoResource == nil && markup != nil, let resource = resource {
        photo = .single(UploadedPeerPhotoData.withResource(resource))
    } else {
        photo = resource.flatMap({ _internal_uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: $0) })
    }
    return _internal_updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: peerId, photo: photo, video: videoResource.flatMap({ _internal_uploadedPeerVideo(postbox: account.postbox, network: account.network, messageMediaPreuploadManager: account.messageMediaPreuploadManager, resource: $0) |> map(Optional.init) }), videoStartTimestamp: videoStartTimestamp, markup: markup, customPeerPhotoMode: mode, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}

public struct UploadedPeerPhotoData {
    fileprivate let resource: MediaResource
    fileprivate let content: UploadedPeerPhotoDataContent
    fileprivate let local: Bool
    
    public var isCompleted: Bool {
        if case let .result(result) = content, case .inputFile = result {
            return true
        } else {
            return false
        }
    }
    
    static func withResource(_ resource: MediaResource) -> UploadedPeerPhotoData {
        return UploadedPeerPhotoData(resource: resource, content: .result(.inputFile(.inputFile(id: 0, parts: 0, name: "", md5Checksum: ""))), local: true)
    }
}

enum UploadedPeerPhotoDataContent {
    case result(MultipartUploadResult)
    case error
}

func _internal_uploadedPeerPhoto(postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image, userContentType: .image), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
    |> map { result -> UploadedPeerPhotoData in
        return UploadedPeerPhotoData(resource: resource, content: .result(result), local: false)
    }
    |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
        return .single(UploadedPeerPhotoData(resource: resource, content: .error, local: false))
    }
}

func _internal_uploadedPeerVideo(postbox: Postbox, network: Network, messageMediaPreuploadManager: MessageMediaPreuploadManager?, resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
    if let messageMediaPreuploadManager = messageMediaPreuploadManager {
        return messageMediaPreuploadManager.upload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video), hintFileSize: nil, hintFileIsLarge: false)
        |> map { result -> UploadedPeerPhotoData in
            return UploadedPeerPhotoData(resource: resource, content: .result(result), local: false)
        }
        |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
            return .single(UploadedPeerPhotoData(resource: resource, content: .error, local: false))
        }
    } else {
        return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
       |> map { result -> UploadedPeerPhotoData in
           return UploadedPeerPhotoData(resource: resource, content: .result(result), local: false)
       }
       |> `catch` { _ -> Signal<UploadedPeerPhotoData, NoError> in
           return .single(UploadedPeerPhotoData(resource: resource, content: .error, local: false))
       }
    }
}

func _internal_updatePeerPhoto(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>? = nil, videoStartTimestamp: Double? = nil, markup: UploadPeerPhotoMarkup? = nil, fallback: Bool = false, customPeerPhotoMode: SetCustomPeerPhotoMode? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return _internal_updatePeerPhotoInternal(postbox: postbox, network: network, stateManager: stateManager, accountPeerId: accountPeerId, peer: postbox.loadedPeerWithId(peerId), photo: photo, video: video, videoStartTimestamp: videoStartTimestamp, markup: markup, fallback: fallback, customPeerPhotoMode: customPeerPhotoMode, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
}
    
func _internal_updatePeerPhotoInternal(postbox: Postbox, network: Network, stateManager: AccountStateManager?, accountPeerId: PeerId, peer: Signal<Peer, NoError>, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup? = nil, fallback: Bool = false, customPeerPhotoMode: SetCustomPeerPhotoMode? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
    return peer
    |> mapError { _ -> UploadPeerPhotoError in }
    |> mapToSignal { peer -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
        var videoEmojiMarkup: Api.VideoSize?
        if let markup = markup {
            switch markup {
            case let .emoji(fileId, backgroundColors):
                videoEmojiMarkup = .videoSizeEmojiMarkup(emojiId: fileId, backgroundColors: backgroundColors)
            case let .sticker(packReference, fileId, backgroundColors):
                videoEmojiMarkup = .videoSizeStickerMarkup(stickerset: packReference.apiInputStickerSet, stickerId: fileId, backgroundColors: backgroundColors)
            }
        }
        
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
                            
                                var photoFile: Api.InputFile?
                                if !photoResult.local {
                                    photoFile = file
                                }

                                if peer is TelegramUser {
                                    var flags: Int32 = 0
                                    if let _ = photoFile {
                                        flags = (1 << 0)
                                    }
                                    if let _ = videoFile {
                                        flags |= (1 << 1)
                                        if let _ = videoStartTimestamp {
                                            flags |= (1 << 2)
                                        }
                                    }
                                                                        
                                    let request: Signal<Api.photos.Photo, MTRpcError>
                                    if peer.id == accountPeerId {
                                        if fallback {
                                            flags |= (1 << 3)
                                        }
                                        if let _ = videoEmojiMarkup {
                                            flags |= (1 << 4)
                                        }
                                        request = network.request(Api.functions.photos.uploadProfilePhoto(flags: flags, bot: nil, file: photoFile, video: videoFile, videoStartTs: videoStartTimestamp, videoEmojiMarkup: videoEmojiMarkup))
                                    } else if let user = peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit), let inputUser = apiInputUser(peer) {
                                        if fallback {
                                            flags |= (1 << 3)
                                        }
                                        if let _ = videoEmojiMarkup {
                                            flags |= (1 << 4)
                                        }
                                        flags |= (1 << 5)
                                        request = network.request(Api.functions.photos.uploadProfilePhoto(flags: flags, bot: inputUser, file: photoFile, video: videoFile, videoStartTs: videoStartTimestamp, videoEmojiMarkup: videoEmojiMarkup))
                                    } else if let inputUser = apiInputUser(peer) {
                                        if let customPeerPhotoMode = customPeerPhotoMode {
                                            switch customPeerPhotoMode {
                                            case .custom:
                                                flags |= (1 << 4)
                                            case .suggest:
                                                flags |= (1 << 3)
                                            case .customAndSuggest:
                                                flags |= (1 << 3)
                                                flags |= (1 << 4)
                                            }
                                        }
                                        if let _ = videoEmojiMarkup {
                                            flags |= (1 << 5)
                                        }
                                        request = network.request(Api.functions.photos.uploadContactProfilePhoto(flags: flags, userId: inputUser, file: photoFile, video: videoFile, videoStartTs: videoStartTimestamp, videoEmojiMarkup: videoEmojiMarkup))
                                    } else {
                                        request = .complete()
                                    }
                                    
                                    return request
                                    |> mapError { _ in return UploadPeerPhotoError.generic }
                                    |> mapToSignal { photo -> Signal<(UpdatePeerPhotoStatus, MediaResource?, MediaResource?), UploadPeerPhotoError> in
                                        var representations: [TelegramMediaImageRepresentation] = []
                                        var videoRepresentations: [TelegramMediaImage.VideoRepresentation] = []
                                        var image: TelegramMediaImage?
                                        switch photo {
                                        case let .photo(apiPhoto, _):
                                            image = telegramMediaImageFromApiPhoto(apiPhoto)
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
                                                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: id, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: nil, localId: nil), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                                            case let .photoSizeProgressive(_, w, h, sizes):
                                                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: id, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: nil, localId: nil), progressiveSizes: sizes, immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
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
                                                            case .videoSizeEmojiMarkup, .videoSizeStickerMarkup:
                                                                break
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
                                                        if customPeerPhotoMode == .suggest || fallback {
                                                            return peer
                                                        } else {
                                                            return peer.withUpdatedPhoto(representations)
                                                        }
                                                    } else {
                                                        return peer
                                                    }
                                                })
                                                
                                                if fallback {
                                                    transaction.updatePeerCachedData(peerIds: Set([peer.id])) { peerId, cachedPeerData in
                                                        if let cachedPeerData = cachedPeerData as? CachedUserData {
                                                            return cachedPeerData.withUpdatedFallbackPhoto(.known(image))
                                                        } else {
                                                            return nil
                                                        }
                                                    }
                                                } else if let customPeerPhotoMode = customPeerPhotoMode, case .custom = customPeerPhotoMode {
                                                    transaction.updatePeerCachedData(peerIds: Set([peer.id])) { peerId, cachedPeerData in
                                                        if let cachedPeerData = cachedPeerData as? CachedUserData {
                                                            return cachedPeerData.withUpdatedPersonalPhoto(.known(image))
                                                        } else {
                                                            return nil
                                                        }
                                                    }
                                                } else if peer.id == accountPeerId && customPeerPhotoMode == nil {
                                                    transaction.updatePeerCachedData(peerIds: Set([peer.id])) { peerId, cachedPeerData in
                                                        if let cachedPeerData = cachedPeerData as? CachedUserData {
                                                            return cachedPeerData.withUpdatedPhoto(.known(image))
                                                        } else {
                                                            return nil
                                                        }
                                                    }
                                                }
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
                                    
                                    if let _ = videoEmojiMarkup {
                                        flags |= (1 << 3)
                                    }
                                                                        
                                    let request: Signal<Api.Updates, MTRpcError>
                                    if let peer = peer as? TelegramGroup {
                                        request = network.request(Api.functions.messages.editChatPhoto(chatId: peer.id.id._internalGetInt64Value(), photo: .inputChatUploadedPhoto(flags: flags, file: file, video: videoFile, videoStartTs: videoStartTimestamp, videoEmojiMarkup: videoEmojiMarkup)))
                                    } else if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                                        request = network.request(Api.functions.channels.editPhoto(channel: inputChannel, photo: .inputChatUploadedPhoto(flags: flags, file: file, video: videoFile, videoStartTs: videoStartTimestamp, videoEmojiMarkup: videoEmojiMarkup)))
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
                    |> mapToSignal { _ -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                        return .complete()
                    }
                    |> then(
                        postbox.transaction { transaction in
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
                    )
                } else {
                    return .single(result)
                }
            }
        } else {
            if let user = peer as? TelegramUser {
                let request: Signal<Api.photos.Photo, MTRpcError>
                if peer.id == accountPeerId {
                    var flags: Int32 = 0
                    if fallback {
                        flags |= (1 << 0)
                    }
                    request = network.request(Api.functions.photos.updateProfilePhoto(flags: flags, bot: nil, id: Api.InputPhoto.inputPhotoEmpty))
                } else if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit), let inputUser = apiInputUser(peer) {
                    var flags: Int32 = (1 << 1)
                    if fallback {
                        flags |= (1 << 0)
                    }
                    request = network.request(Api.functions.photos.updateProfilePhoto(flags: flags, bot: inputUser, id: Api.InputPhoto.inputPhotoEmpty))
                } else if let inputUser = apiInputUser(peer) {
                    let flags: Int32 = (1 << 4)
                    request = network.request(Api.functions.photos.uploadContactProfilePhoto(flags: flags, userId: inputUser, file: nil, video: nil, videoStartTs: nil, videoEmojiMarkup: nil))
                } else {
                    request = .complete()
                }
                
                return request
                |> mapError { _ -> UploadPeerPhotoError in
                    return .generic
                }
                |> mapToSignal { photo -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                    if peer.id == accountPeerId {
                        var updatedImage: TelegramMediaImage?
                        var representations: [TelegramMediaImageRepresentation] = []
                        switch photo {
                        case let .photo(apiPhoto, _):
                            updatedImage = telegramMediaImageFromApiPhoto(apiPhoto)
                            switch apiPhoto {
                                case .photoEmpty:
                                    break
                                case let .photo(_, id, _, _, _, sizes, _, dcId):
                                    var sizes = sizes
                                    if sizes.count == 3 {
                                        sizes.remove(at: 1)
                                    }
                                    for size in sizes {
                                        switch size {
                                            case let .photoSize(_, w, h, _):
                                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: id, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: nil, localId: nil), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                            case let .photoSizeProgressive(_, w, h, sizes):
                                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: id, sizeSpec: w <= 200 ? .small : .fullSize, volumeId: nil, localId: nil), progressiveSizes: sizes, immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                            default:
                                                break
                                        }
                                    }
                            }
                        }
                        return postbox.transaction { transaction -> UpdatePeerPhotoStatus in
                            if let peer = transaction.getPeer(peer.id) {
                                updatePeers(transaction: transaction, peers: [peer], update: { (_, peer) -> Peer? in
                                    if let peer = peer as? TelegramUser {
                                        if customPeerPhotoMode == .suggest || fallback {
                                            return peer
                                        } else {
                                            return peer.withUpdatedPhoto(representations)
                                        }
                                    } else {
                                        return peer
                                    }
                                })
                                transaction.updatePeerCachedData(peerIds: Set([peer.id])) { peerId, cachedPeerData in
                                    if let cachedPeerData = cachedPeerData as? CachedUserData {
                                        return cachedPeerData.withUpdatedPersonalPhoto(.known(updatedImage))
                                    } else {
                                        return nil
                                    }
                                }
                            }
                            return .complete([])
                        } |> mapError { _ -> UploadPeerPhotoError in }
                    } else {
                        var updatedUsers: [TelegramUser] = []
                        switch photo {
                        case let .photo(_, apiUsers):
                            updatedUsers = apiUsers.map { TelegramUser(user: $0) }
                        }
                        return postbox.transaction { transaction -> UpdatePeerPhotoStatus in
                            updatePeers(transaction: transaction, peers: updatedUsers, update: { (_, updatedPeer) -> Peer? in
                                return updatedPeer
                            })
                            if fallback {
                                transaction.updatePeerCachedData(peerIds: Set([peer.id])) { peerId, cachedPeerData in
                                    if let cachedPeerData = cachedPeerData as? CachedUserData {
                                        return cachedPeerData.withUpdatedFallbackPhoto(.known(nil))
                                    } else {
                                        return nil
                                    }
                                }
                            } else if let customPeerPhotoMode = customPeerPhotoMode, case .custom = customPeerPhotoMode {
                                transaction.updatePeerCachedData(peerIds: Set([peer.id])) { peerId, cachedPeerData in
                                    if let cachedPeerData = cachedPeerData as? CachedUserData {
                                        return cachedPeerData.withUpdatedPersonalPhoto(.known(nil))
                                    } else {
                                        return nil
                                    }
                                }
                            }
                            return .complete([])
                        } |> mapError { _ -> UploadPeerPhotoError in }
                    }
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
        return network.request(Api.functions.photos.updateProfilePhoto(flags: 0, bot: nil, id: .inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference))))
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

func _internal_removeAccountPhoto(account: Account, reference: TelegramMediaImageReference?, fallback: Bool) -> Signal<Void, NoError> {
    if let reference = reference {
        switch reference {
        case let .cloud(imageId, accessHash, fileReference):
            if let fileReference = fileReference {
                return account.network.request(Api.functions.photos.deletePhotos(id: [.inputPhoto(id: imageId, accessHash: accessHash, fileReference: Buffer(data: fileReference))]))
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
        var flags: Int32 = 0
        if fallback {
            flags |= (1 << 0)
        }
        let api = Api.functions.photos.updateProfilePhoto(flags: flags, bot: nil, id: Api.InputPhoto.inputPhotoEmpty)
        return account.network.request(api)
        |> map { _ in }
        |> retryRequest
        |> mapToSignal { _ -> Signal<Void, NoError> in
            if fallback {
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
                        if let current = current as? CachedUserData {
                            return current.withUpdatedFallbackPhoto(.known(nil))
                        } else {
                            return current
                        }
                    })
                    return Void()
                }
            } else {
                return .complete()
            }
        }
    }
}
