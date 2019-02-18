import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

public func freeMediaFileInteractiveFetched(account: Account, fileReference: FileMediaReference) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(fileReference.media.resource))
}

func freeMediaFileResourceInteractiveFetched(account: Account, fileReference: FileMediaReference, resource: MediaResource) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(resource))
}

func cancelFreeMediaFileInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
}

private func fetchCategoryForFile(_ file: TelegramMediaFile) -> FetchManagerCategory {
    if file.isVoice || file.isInstantVideo {
        return .voice
    } else if file.isAnimated {
        return .animation
    } else {
        return .file
    }
}

public func messageMediaFileInteractiveFetched(context: AccountContext, message: Message, file: TelegramMediaFile, userInitiated: Bool) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: MessageReference(message), media: file)
    return context.fetchManager.interactivelyFetched(category: fetchCategoryForFile(file), location: .chat(message.id.peerId), locationKey: .messageId(message.id), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(file.resource), statsCategory: statsCategoryForFileWithAttributes(file.attributes), elevatedPriority: false, userInitiated: userInitiated)
}

func messageMediaFileCancelInteractiveFetch(context: AccountContext, messageId: MessageId, file: TelegramMediaFile) {
    context.fetchManager.cancelInteractiveFetches(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}

public func messageMediaImageInteractiveFetched(context: AccountContext, message: Message, image: TelegramMediaImage, resource: MediaResource, storeToDownloadsPeerType: MediaAutoDownloadPeerType?) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: MessageReference(message), media: image)
    return context.fetchManager.interactivelyFetched(category: .image, location: .chat(message.id.peerId), locationKey: .messageId(message.id), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(resource), statsCategory: .image, elevatedPriority: false, userInitiated: true, storeToDownloadsPeerType: storeToDownloadsPeerType)
}

func messageMediaImageCancelInteractiveFetch(context: AccountContext, messageId: MessageId, image: TelegramMediaImage, resource: MediaResource) {
    context.fetchManager.cancelInteractiveFetches(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: resource)
}

func messageMediaFileStatus(context: AccountContext, messageId: MessageId, file: TelegramMediaFile) -> Signal<MediaResourceStatus, NoError> {
    return context.fetchManager.fetchStatus(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}
