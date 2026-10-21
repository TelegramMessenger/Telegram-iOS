import Foundation
import Postbox
import SwiftSignalKit

/// A widget message to insert locally (Debug Settings: the conformance set and the corpus into Saved Messages): the
/// widget's HTML, its size anchors and caption, and the reference pictures posted after it.
public struct EngineLocalWidgetPost: Equatable {
    public struct Photo: Equatable {
        public var png: Data
        public var width: Int32
        public var height: Int32

        public init(png: Data, width: Int32, height: Int32) {
            self.png = png
            self.width = width
            self.height = height
        }
    }

    public var html: String
    public var width: Int32
    public var height: Int32
    public var caption: String
    public var photos: [Photo]

    public init(html: String, width: Int32, height: Int32, caption: String, photos: [Photo]) {
        self.html = html
        self.width = width
        self.height = height
        self.caption = caption
        self.photos = photos
    }
}

/// One message per post (text = caption, media = the widget gzipped as the server does), then one per photo (a local
/// image over `photoResources[post][photo]`), in order, timestamps one second apart ending at `lastTimestamp`. Local,
/// outgoing, by the account; in Saved Messages, in the account's own thread (My Notes).
func _internal_localWidgetStoreMessages(posts: [EngineLocalWidgetPost], photoResources: [[LocalFileMediaResource]], peerId: PeerId, accountPeerId: PeerId, lastTimestamp: Int32) -> [StoreMessage] {
    var contents: [(text: String, media: Media)] = []
    for (postIndex, post) in posts.enumerated() {
        guard let widget = TelegramMediaWidget(html: post.html, width: post.width, height: post.height) else {
            continue
        }
        contents.append((post.caption, widget))
        let resources = postIndex < photoResources.count ? photoResources[postIndex] : []
        for (photo, resource) in zip(post.photos, resources) {
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: photo.width, height: photo.height), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
            let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            contents.append(("", image))
        }
    }
    let threadId: Int64? = peerId == accountPeerId ? accountPeerId.toInt64() : nil
    let firstTimestamp = lastTimestamp - Int32(max(0, contents.count - 1))
    return contents.enumerated().map { index, content in
        // Tagged as a sent message is (`EnqueueMessage`), so a picture opens in the gallery and shows in the Media tab.
        let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: [], media: [content.media], textEntities: nil, isPinned: false)
        return StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: Int64.random(in: Int64.min ... Int64.max), groupingKey: nil, threadId: threadId, timestamp: firstTimestamp + Int32(index), flags: [], tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: accountPeerId, text: content.text, attributes: [], media: [content.media])
    }
}

func _internal_debugInsertLocalWidgetMessages(account: Account, peerId: PeerId, posts: [EngineLocalWidgetPost]) -> Signal<Int, NoError> {
    let timestamp = Int32(account.network.context.globalTime())
    let photoResources: [[LocalFileMediaResource]] = posts.map { post in
        return post.photos.map { photo in
            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(photo.png.count))
            account.postbox.mediaBox.storeResourceData(resource.id, data: photo.png, synchronous: true)
            return resource
        }
    }
    return account.postbox.transaction { transaction -> Int in
        let messages = _internal_localWidgetStoreMessages(posts: posts, photoResources: photoResources, peerId: peerId, accountPeerId: account.peerId, lastTimestamp: timestamp)
        let ids = transaction.addMessages(messages, location: .Random)
        if !messages.isEmpty {
            updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: timestamp, forceRootGroupIfNotExists: true)
        }
        return ids.count
    }
}
