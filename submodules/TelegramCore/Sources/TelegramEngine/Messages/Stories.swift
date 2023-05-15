import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum EngineStoryInputMedia {
    case image(dimensions: PixelDimensions, data: Data)
    case video(dimensions: PixelDimensions, duration: Int, resource: TelegramMediaResource)
}

public struct EngineStoryPrivacy: Equatable {
    public enum Base {
        case everyone
        case contacts
        case closeFriends
    }
    
    public var base: Base
    public var additionallyIncludePeers: [EnginePeer.Id]
    
    public init(base: Base, additionallyIncludePeers: [EnginePeer.Id]) {
        self.base = base
        self.additionallyIncludePeers = additionallyIncludePeers
    }
}

func _internal_uploadStory(account: Account, media: EngineStoryInputMedia, privacy: EngineStoryPrivacy) -> Signal<Never, NoError> {
    switch media {
    case let .image(dimensions, data):
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        
        let imageMedia = TelegramMediaImage(
            imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: MediaId.Id.random(in: MediaId.Id.min ... MediaId.Id.max)),
            representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
        
        let contentToUpload = messageContentToUpload(
            network: account.network,
            postbox: account.postbox,
            auxiliaryMethods: account.auxiliaryMethods,
            transformOutgoingMessageMedia: nil,
            messageMediaPreuploadManager: account.messageMediaPreuploadManager,
            revalidationContext: account.mediaReferenceRevalidationContext,
            forceReupload: true,
            isGrouped: false,
            peerId: account.peerId,
            messageId: nil,
            attributes: [],
            text: "",
            media: [imageMedia]
        )
        let contentSignal: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>
        switch contentToUpload {
        case let .immediate(result, _):
            contentSignal = .single(result)
        case let .signal(signal, _):
            contentSignal = signal
        }
        
        return contentSignal
        |> map(Optional.init)
        |> `catch` { _ -> Signal<PendingMessageUploadedContentResult?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> Signal<Never, NoError> in
                var privacyRules: [Api.InputPrivacyRule]
                switch privacy.base {
                case .everyone:
                    privacyRules = [.inputPrivacyValueAllowAll]
                case .contacts:
                    privacyRules = [.inputPrivacyValueAllowContacts]
                case .closeFriends:
                    privacyRules = [.inputPrivacyValueAllowCloseFriends]
                }
                var privacyUsers: [Api.InputUser] = []
                var privacyChats: [Int64] = []
                for peerId in privacy.additionallyIncludePeers {
                    if let peer = transaction.getPeer(peerId) {
                        if let _ = peer as? TelegramUser {
                            if let inputUser = apiInputUser(peer) {
                                privacyUsers.append(inputUser)
                            }
                        } else if peer is TelegramGroup || peer is TelegramChannel {
                            privacyChats.append(peer.id.id._internalGetInt64Value())
                        }
                    }
                }
                if !privacyUsers.isEmpty {
                    privacyRules.append(.inputPrivacyValueAllowUsers(users: privacyUsers))
                }
                if !privacyChats.isEmpty {
                    privacyRules.append(.inputPrivacyValueAllowChatParticipants(chats: privacyChats))
                }
                
                switch result {
                case let .content(content):
                    switch content.content {
                    case let .media(inputMedia, _):
                        return account.network.request(Api.functions.stories.sendStory(flags: 0, media: inputMedia, caption: nil, entities: nil, privacyRules: privacyRules))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                            return .single(nil)
                        }
                        |> mapToSignal { updates -> Signal<Never, NoError> in
                            if let updates = updates {
                                for update in updates.allUpdates {
                                    if case let .updateStories(stories) = update {
                                        switch stories {
                                        case .userStories(let userId, let apiStories), .userStoriesSlice(_, let userId, let apiStories):
                                            if PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)) == account.peerId, apiStories.count == 1 {
                                                switch apiStories[0] {
                                                case let .storyItem(_, _, _, _, _, media, _, _, _):
                                                    let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, account.peerId)
                                                    if let parsedMedia = parsedMedia {
                                                        applyMediaResourceChanges(from: imageMedia, to: parsedMedia, postbox: account.postbox, force: false)
                                                    }
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                account.stateManager.addUpdates(updates)
                            }
                            
                            return .complete()
                        }
                    default:
                        return .complete()
                    }
                default:
                    return .complete()
                }
            }
            |> switchToLatest
        }
    case let .video(dimensions, duration, resource):
        let fileMedia = TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: MediaId.Id.random(in: MediaId.Id.min ... MediaId.Id.max)),
            partialReference: nil,
            resource: resource,
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "video/mp4",
            size: nil,
            attributes: [
                TelegramMediaFileAttribute.Video(duration: duration, size: dimensions, flags: .supportsStreaming)
            ]
        )
        
        let contentToUpload = messageContentToUpload(
            network: account.network,
            postbox: account.postbox,
            auxiliaryMethods: account.auxiliaryMethods,
            transformOutgoingMessageMedia: nil,
            messageMediaPreuploadManager: account.messageMediaPreuploadManager,
            revalidationContext: account.mediaReferenceRevalidationContext,
            forceReupload: true,
            isGrouped: false,
            peerId: account.peerId,
            messageId: nil,
            attributes: [],
            text: "",
            media: [fileMedia]
        )
        let contentSignal: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>
        switch contentToUpload {
        case let .immediate(result, _):
            contentSignal = .single(result)
        case let .signal(signal, _):
            contentSignal = signal
        }
        
        return contentSignal
        |> map(Optional.init)
        |> `catch` { _ -> Signal<PendingMessageUploadedContentResult?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> Signal<Never, NoError> in
                var privacyRules: [Api.InputPrivacyRule]
                switch privacy.base {
                case .everyone:
                    privacyRules = [.inputPrivacyValueAllowAll]
                case .contacts:
                    privacyRules = [.inputPrivacyValueAllowContacts]
                case .closeFriends:
                    privacyRules = [.inputPrivacyValueAllowCloseFriends]
                }
                var privacyUsers: [Api.InputUser] = []
                var privacyChats: [Int64] = []
                for peerId in privacy.additionallyIncludePeers {
                    if let peer = transaction.getPeer(peerId) {
                        if let _ = peer as? TelegramUser {
                            if let inputUser = apiInputUser(peer) {
                                privacyUsers.append(inputUser)
                            }
                        } else if peer is TelegramGroup || peer is TelegramChannel {
                            privacyChats.append(peer.id.id._internalGetInt64Value())
                        }
                    }
                }
                if !privacyUsers.isEmpty {
                    privacyRules.append(.inputPrivacyValueAllowUsers(users: privacyUsers))
                }
                if !privacyChats.isEmpty {
                    privacyRules.append(.inputPrivacyValueAllowChatParticipants(chats: privacyChats))
                }
                
                switch result {
                case let .content(content):
                    switch content.content {
                    case let .media(inputMedia, _):
                        return account.network.request(Api.functions.stories.sendStory(flags: 0, media: inputMedia, caption: nil, entities: nil, privacyRules: privacyRules))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                            return .single(nil)
                        }
                        |> mapToSignal { updates -> Signal<Never, NoError> in
                            if let updates = updates {
                                for update in updates.allUpdates {
                                    if case let .updateStories(stories) = update {
                                        switch stories {
                                        case .userStories(let userId, let apiStories), .userStoriesSlice(_, let userId, let apiStories):
                                            if PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)) == account.peerId, apiStories.count == 1 {
                                                switch apiStories[0] {
                                                case let .storyItem(_, _, _, _, _, media, _, _, _):
                                                    let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, account.peerId)
                                                    if let parsedMedia = parsedMedia {
                                                        applyMediaResourceChanges(from: fileMedia, to: parsedMedia, postbox: account.postbox, force: true)
                                                    }
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                account.stateManager.addUpdates(updates)
                            }
                            
                            return .complete()
                        }
                    default:
                        return .complete()
                    }
                default:
                    return .complete()
                }
            }
            |> switchToLatest
        }
    }
}

func _internal_deleteStory(account: Account, id: Int32) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.stories.deleteStories(id: [id]))
    |> `catch` { _ -> Signal<[Int32], NoError> in
        return .single([])
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return .complete()
    }
}

func _internal_markStoryAsSeen(account: Account, peerId: PeerId, id: Int32) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser = inputUser else {
            return .complete()
        }
        
        account.stateManager.injectStoryUpdates(updates: [.read(peerId: peerId, maxId: id)])
        
        return account.network.request(Api.functions.stories.readStories(userId: inputUser, maxId: id))
        |> `catch` { _ -> Signal<[Int32], NoError> in
            return .single([])
        }
        |> ignoreValues
    }
}
