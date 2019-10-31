import Foundation
import UIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramUIPreferences

public func freeMediaFileInteractiveFetched(account: Account, fileReference: FileMediaReference) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource))
}

public func freeMediaFileInteractiveFetched(fetchManager: FetchManager, fileReference: FileMediaReference, priority: FetchManagerPriority) -> Signal<Void, NoError> {
    let file = fileReference.media
    let mediaReference = AnyMediaReference.standalone(media: fileReference.media)
    return fetchManager.interactivelyFetched(category: fetchCategoryForFile(file), location: .chat(PeerId(namespace: 0, id: 0)), locationKey: .free, mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(file.resource), ranges: IndexSet(integersIn: 0 ..< Int(Int32.max) as Range<Int>), statsCategory: statsCategoryForFileWithAttributes(file.attributes), elevatedPriority: false, userInitiated: false, priority: priority, storeToDownloadsPeerType: nil)
}

public func freeMediaFileResourceInteractiveFetched(account: Account, fileReference: FileMediaReference, resource: MediaResource) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(resource))
}

public func cancelFreeMediaFileInteractiveFetch(account: Account, file: TelegramMediaFile) {
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
    return messageMediaFileInteractiveFetched(fetchManager: context.fetchManager, messageId: message.id, messageReference: MessageReference(message), file: file, userInitiated: userInitiated, priority: .userInitiated)
}

public func messageMediaFileInteractiveFetched(fetchManager: FetchManager, messageId: MessageId, messageReference: MessageReference, file: TelegramMediaFile, ranges: IndexSet = IndexSet(integersIn: 0 ..< Int(Int32.max) as Range<Int>), userInitiated: Bool, priority: FetchManagerPriority) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: messageReference, media: file)
    return fetchManager.interactivelyFetched(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(file.resource), ranges: ranges, statsCategory: statsCategoryForFileWithAttributes(file.attributes), elevatedPriority: false, userInitiated: userInitiated, priority: priority, storeToDownloadsPeerType: nil)
}

public func messageMediaFileCancelInteractiveFetch(context: AccountContext, messageId: MessageId, file: TelegramMediaFile) {
    context.fetchManager.cancelInteractiveFetches(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}

public func messageMediaImageInteractiveFetched(context: AccountContext, message: Message, image: TelegramMediaImage, resource: MediaResource, storeToDownloadsPeerType: MediaAutoDownloadPeerType?) -> Signal<Void, NoError> {
    return messageMediaImageInteractiveFetched(fetchManager: context.fetchManager, messageId: message.id, messageReference: MessageReference(message), image: image, resource: resource, userInitiated: true, priority: .userInitiated, storeToDownloadsPeerType: storeToDownloadsPeerType)
}

public func messageMediaImageInteractiveFetched(fetchManager: FetchManager, messageId: MessageId, messageReference: MessageReference, image: TelegramMediaImage, resource: MediaResource, userInitiated: Bool, priority: FetchManagerPriority, storeToDownloadsPeerType: MediaAutoDownloadPeerType?) -> Signal<Void, NoError> {
    let mediaReference = AnyMediaReference.message(message: messageReference, media: image)
    return fetchManager.interactivelyFetched(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), mediaReference: mediaReference, resourceReference: mediaReference.resourceReference(resource), ranges: FetchCompleteRange, statsCategory: .image, elevatedPriority: false, userInitiated: userInitiated, priority: priority, storeToDownloadsPeerType: storeToDownloadsPeerType)
}

public func messageMediaImageCancelInteractiveFetch(context: AccountContext, messageId: MessageId, image: TelegramMediaImage, resource: MediaResource) {
    context.fetchManager.cancelInteractiveFetches(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: resource)
}

public func messageMediaFileStatus(context: AccountContext, messageId: MessageId, file: TelegramMediaFile) -> Signal<MediaResourceStatus, NoError> {
    return context.fetchManager.fetchStatus(category: fetchCategoryForFile(file), location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: file.resource)
}
