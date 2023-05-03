import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum EngineStoryInputMedia {
    case image(dimensions: PixelDimensions, data: Data)
}

func _internal_uploadStory(account: Account, media: EngineStoryInputMedia) -> Signal<Never, NoError> {
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
            switch result {
            case let .content(content):
                switch content.content {
                case let .media(inputMedia, _):
                    return account.network.request(Api.functions.stories.sendStory(media: inputMedia, privacyRules: [.inputPrivacyValueAllowAll]))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { updates -> Signal<Never, NoError> in
                        if let updates = updates {
                            for update in updates.allUpdates {
                                if case let .updateStories(stories) = update {
                                    switch stories {
                                    case .userStories(let userId, let apiStories), .userStoriesShort(let userId, let apiStories, _):
                                        if PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)) == account.peerId, apiStories.count == 1 {
                                            switch apiStories[0] {
                                            case let .storyItem(_, _, media):
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
    }
}

func _internal_deleteStory(account: Account, id: Int64) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.stories.deleteStory(id: id))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return .complete()
    }
}
