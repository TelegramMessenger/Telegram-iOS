import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

func freeMediaFileInteractiveFetched(account: Account, fileReference: FileMediaReference) -> Signal<FetchResourceSourceType, NoError> {
    return fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(fileReference.media.resource))
}

func cancelFreeMediaFileInteractiveFetch(account: Account, file: TelegramMediaFile) {
    account.postbox.mediaBox.cancelInteractiveResourceFetch(file.resource)
}

func messageMediaFileInteractiveFetched(account: Account, message: Message, file: TelegramMediaFile) -> Signal<Void, NoError> {
    return account.telegramApplicationContext.fetchManager.interactivelyFetched(category: .file, location: .chat(message.id.peerId), locationKey: .messageId(message.id), resourceReference: AnyMediaReference.message(message: MessageReference(message), media: file).resourceReference(file.resource), statsCategory: statsCategoryForFileWithAttributes(file.attributes), elevatedPriority: false, userInitiated: true)
}

func messageMediaFileCancelInteractiveFetch(account: Account, messageId: MessageId, file: TelegramMediaFile) {
    account.telegramApplicationContext.fetchManager.cancelInteractiveFetches(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}

func messageMediaImageInteractiveFetched(account: Account, message: Message, image: TelegramMediaImage, resource: MediaResource) -> Signal<Void, NoError> {
    return account.telegramApplicationContext.fetchManager.interactivelyFetched(category: .image, location: .chat(message.id.peerId), locationKey: .messageId(message.id), resourceReference: AnyMediaReference.message(message: MessageReference(message), media: image).resourceReference(resource), statsCategory: .image, elevatedPriority: false, userInitiated: true)
}

func messageMediaImageCancelInteractiveFetch(account: Account, messageId: MessageId, image: TelegramMediaImage, resource: MediaResource) {
    account.telegramApplicationContext.fetchManager.cancelInteractiveFetches(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: resource)
}

func messageMediaFileStatus(account: Account, messageId: MessageId, file: TelegramMediaFile) -> Signal<MediaResourceStatus, NoError> {
    return account.telegramApplicationContext.fetchManager.fetchStatus(category: .file, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}
