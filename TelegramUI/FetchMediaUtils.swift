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

public func messageMediaFileInteractiveFetched(account: Account, message: Message, file: TelegramMediaFile, userInitiated: Bool) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: MessageReference(message), media: file)
    return account.telegramApplicationContext.fetchManager.interactivelyFetched(category: fetchCategoryForFile(file), location: .chat(message.id.peerId), locationKey: .messageId(message.id), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(file.resource), statsCategory: statsCategoryForFileWithAttributes(file.attributes), elevatedPriority: false, userInitiated: userInitiated)
}

func messageMediaFileCancelInteractiveFetch(account: Account, messageId: MessageId, file: TelegramMediaFile) {
    account.telegramApplicationContext.fetchManager.cancelInteractiveFetches(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}

public func messageMediaImageInteractiveFetched(account: Account, message: Message, image: TelegramMediaImage, resource: MediaResource, storeToDownloadsPeerType: AutomaticMediaDownloadPeerType?) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: MessageReference(message), media: image)
    return account.telegramApplicationContext.fetchManager.interactivelyFetched(category: .image, location: .chat(message.id.peerId), locationKey: .messageId(message.id), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(resource), statsCategory: .image, elevatedPriority: false, userInitiated: true, storeToDownloadsPeerType: storeToDownloadsPeerType)
}

func messageMediaImageCancelInteractiveFetch(account: Account, messageId: MessageId, image: TelegramMediaImage, resource: MediaResource) {
    account.telegramApplicationContext.fetchManager.cancelInteractiveFetches(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: resource)
}

func messageMediaFileStatus(account: Account, messageId: MessageId, file: TelegramMediaFile) -> Signal<MediaResourceStatus, NoError> {
    return account.telegramApplicationContext.fetchManager.fetchStatus(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}
