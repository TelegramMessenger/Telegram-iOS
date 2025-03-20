import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

extension MediaResourceReference {
    var apiFileReference: Data? {
        if let resource = self.resource as? TelegramCloudMediaResourceWithFileReference {
            return resource.fileReference
        } else {
            return nil
        }
    }
}

public final class TelegramCloudMediaResourceFetchInfo: MediaResourceFetchInfo {
    public let reference: MediaResourceReference
    public let preferBackgroundReferenceRevalidation: Bool
    public let continueInBackground: Bool
    
    public init(reference: MediaResourceReference, preferBackgroundReferenceRevalidation: Bool, continueInBackground: Bool) {
        self.reference = reference
        self.preferBackgroundReferenceRevalidation = preferBackgroundReferenceRevalidation
        self.continueInBackground = continueInBackground
    }
}

public func fetchedMediaResource(
    mediaBox: MediaBox,
    userLocation: MediaResourceUserLocation,
    userContentType: MediaResourceUserContentType,
    reference: MediaResourceReference,
    range: (Range<Int64>, MediaBoxFetchPriority)? = nil,
    statsCategory: MediaResourceStatsCategory = .generic,
    reportResultStatus: Bool = false,
    preferBackgroundReferenceRevalidation: Bool = false,
    continueInBackground: Bool = false
) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(mediaBox: mediaBox, userLocation: userLocation, userContentType: userContentType, reference: reference, ranges: range.flatMap({ [$0] }), statsCategory: statsCategory, reportResultStatus: reportResultStatus, preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation, continueInBackground: continueInBackground)
}

public extension MediaResourceStorageLocation {
    convenience init?(userLocation: MediaResourceUserLocation, reference: MediaResourceReference) {
        switch reference {
        case let .media(media, _):
            switch media {
            case let .message(message, _):
                if let id = message.id {
                    self.init(peerId: id.peerId, messageId: id)
                    return
                }
            default:
                break
            }
        default:
            break
        }
        
        switch userLocation {
        case let .peer(id):
            self.init(peerId: id, messageId: nil)
        case .other:
            return nil
        }
    }
}

public enum MediaResourceUserLocation: Equatable {
    case peer(EnginePeer.Id)
    case other
}

public func fetchedMediaResource(
    mediaBox: MediaBox,
    userLocation: MediaResourceUserLocation,
    userContentType: MediaResourceUserContentType,
    reference: MediaResourceReference,
    ranges: [(Range<Int64>, MediaBoxFetchPriority)]?,
    statsCategory: MediaResourceStatsCategory = .generic,
    reportResultStatus: Bool = false,
    preferBackgroundReferenceRevalidation: Bool = false,
    continueInBackground: Bool = false
) -> Signal<FetchResourceSourceType, FetchResourceError> {
    var isRandomAccessAllowed = true
    switch reference {
    case let .media(media, _):
        if let file = media.media as? TelegramMediaFile {
            if file.fileId.namespace == Namespaces.Media.CloudSecretFile {
                isRandomAccessAllowed = false
            }
        }
    default:
        break
    }
    
    let location = MediaResourceStorageLocation(userLocation: userLocation, reference: reference)
    
    var ranges = ranges
    
    if let rangesValue = ranges, rangesValue.count == 1, rangesValue[0].0 == 0 ..< Int64.max {
        ranges = nil
    }
    
    if let ranges = ranges {
        let signals = ranges.map { (range, priority) -> Signal<Void, FetchResourceError> in
            return mediaBox.fetchedResourceData(reference.resource, in: range, priority: priority, parameters: MediaResourceFetchParameters(
                tag: TelegramMediaResourceFetchTag(statsCategory: statsCategory, userContentType: userContentType),
                info: TelegramCloudMediaResourceFetchInfo(reference: reference, preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation, continueInBackground: continueInBackground),
                location: location,
                contentType: userContentType,
                isRandomAccessAllowed: isRandomAccessAllowed
            ))
        }
        return combineLatest(signals)
        |> ignoreValues
        |> map { _ -> FetchResourceSourceType in }
        |> then(.single(.local))
    } else {
        return mediaBox.fetchedResource(reference.resource, parameters: MediaResourceFetchParameters(
            tag: TelegramMediaResourceFetchTag(statsCategory: statsCategory, userContentType: userContentType),
            info: TelegramCloudMediaResourceFetchInfo(reference: reference, preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation, continueInBackground: continueInBackground),
            location: location,
            contentType: userContentType,
            isRandomAccessAllowed: isRandomAccessAllowed
        ), implNext: reportResultStatus)
    }
}

enum RevalidateMediaReferenceError {
    case generic
}

public func stickerPackFileReference(_ file: TelegramMediaFile) -> FileMediaReference {
    for attribute in file.attributes {
        if case let .Sticker(_, packReferenceValue, _) = attribute, let stickerPack = packReferenceValue {
            return .stickerPack(stickerPack: stickerPack, media: file)
        }
    }
    return .standalone(media: file)
}

private func areResourcesEqual(_ lhs: MediaResource, _ rhs: MediaResource) -> Bool {
    if let lhsResource = lhs as? CloudDocumentMediaResource, let rhsResource = rhs as? CloudDocumentMediaResource {
        if lhsResource.fileId == rhsResource.fileId {
            return true
        }
    } else if let lhsResource = lhs as? CloudDocumentSizeMediaResource, let rhsResource = rhs as? CloudDocumentSizeMediaResource {
        if lhsResource.documentId == rhsResource.documentId && lhsResource.sizeSpec == rhsResource.sizeSpec {
            return true
        }
    }
    return lhs.id == rhs.id
}

private func findMediaResource(media: Media, previousMedia: Media?, resource: MediaResource) -> TelegramMediaResource? {
    if let paidContent = media as? TelegramMediaPaidContent {
        for case let .full(fullMedia) in paidContent.extendedMedia {
            if let resource = findMediaResource(media: fullMedia, previousMedia: previousMedia, resource: resource) {
                return resource
            }
        }
    } else if let image = media as? TelegramMediaImage {
        for representation in image.representations {
            if let updatedResource = representation.resource as? CloudPhotoSizeMediaResource, let previousResource = resource as? CloudPhotoSizeMediaResource {
                if updatedResource.photoId == previousResource.photoId && updatedResource.sizeSpec == previousResource.sizeSpec {
                    return representation.resource
                }
            }
            if representation.resource.id == resource.id {
                return representation.resource
            }
        }
        for representation in image.videoRepresentations {
            if representation.resource.id == resource.id {
                return representation.resource
            }
        }
    } else if let file = media as? TelegramMediaFile {
        if areResourcesEqual(file.resource, resource) {
            return file.resource
        } else {
            if let videoCover = file.videoCover {
                if let resource = findMediaResource(media: videoCover, previousMedia: previousMedia, resource: resource) {
                    return resource
                }
            }
            for representation in file.previewRepresentations {
                if areResourcesEqual(representation.resource, resource) {
                    return representation.resource
                }
            }
            
            for alternativeRepresentation in file.alternativeRepresentations {
                if let result = findMediaResource(media: alternativeRepresentation, previousMedia: previousMedia, resource: resource) {
                    return result
                }
            }
        }
    } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content {
        if let image = content.image, let result = findMediaResource(media: image, previousMedia: previousMedia, resource: resource) {
            return result
        }
        if let file = content.file, let result = findMediaResource(media: file, previousMedia: previousMedia, resource: resource) {
            return result
        }
        if let instantPage = content.instantPage {
            for (_, pageMedia) in instantPage.media {
                if let result = findMediaResource(media: pageMedia._parse(), previousMedia: previousMedia, resource: resource) {
                    return result
                }
            }
        }
    } else if let game = media as? TelegramMediaGame {
        if let image = game.image, let result = findMediaResource(media: image, previousMedia: previousMedia, resource: resource) {
            return result
        }
        if let file = game.file, let result = findMediaResource(media: file, previousMedia: previousMedia, resource: resource) {
            return result
        }
    } else if let action = media as? TelegramMediaAction {
        switch action.action {
            case let .photoUpdated(image):
                if let image = image, let result = findMediaResource(media: image, previousMedia: previousMedia, resource: resource) {
                    return result
                }
            case let .suggestedProfilePhoto(image):
                if let image = image, let result = findMediaResource(media: image, previousMedia: previousMedia, resource: resource) {
                    return result
                }
            default:
                break
        }
    }
    return nil
}

public func findMediaResourceById(message: EngineMessage, resourceId: MediaResourceId) -> TelegramMediaResource? {
    for media in message.media {
        if let result = findMediaResourceById(media: media, resourceId: resourceId) {
            return result
        }
    }
    return nil
}

func findMediaResourceById(media: Media, resourceId: MediaResourceId) -> TelegramMediaResource? {
    if let image = media as? TelegramMediaImage {
        for representation in image.representations {
            if representation.resource.id == resourceId {
                return representation.resource
            }
        }
        for representation in image.videoRepresentations {
            if representation.resource.id == resourceId {
                return representation.resource
            }
        }
    } else if let file = media as? TelegramMediaFile {
        if file.resource.id == resourceId {
            return file.resource
        }
        
        for representation in file.previewRepresentations {
            if representation.resource.id == resourceId {
                return representation.resource
            }
        }
        
        for alternativeRepresentation in file.alternativeRepresentations {
            if let result = findMediaResourceById(media: alternativeRepresentation, resourceId: resourceId) {
                return result
            }
        }
    } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content {
        if let image = content.image, let result = findMediaResourceById(media: image, resourceId: resourceId) {
            return result
        }
        if let file = content.file, let result = findMediaResourceById(media: file, resourceId: resourceId) {
            return result
        }
        if let instantPage = content.instantPage {
            for (_, pageMedia) in instantPage.media {
                if let result = findMediaResourceById(media: pageMedia._parse(), resourceId: resourceId) {
                    return result
                }
            }
        }
    } else if let game = media as? TelegramMediaGame {
        if let image = game.image, let result = findMediaResourceById(media: image, resourceId: resourceId) {
            return result
        }
        if let file = game.file, let result = findMediaResourceById(media: file, resourceId: resourceId) {
            return result
        }
    } else if let action = media as? TelegramMediaAction {
        switch action.action {
        case let .photoUpdated(image):
            if let image = image, let result = findMediaResourceById(media: image, resourceId: resourceId) {
                return result
            }
        case let .suggestedProfilePhoto(image):
            if let image = image, let result = findMediaResourceById(media: image, resourceId: resourceId) {
                return result
            }
        default:
            break
        }
    }
    return nil
}

private func findUpdatedMediaResource(media: Media, previousMedia: Media?, resource: MediaResource) -> TelegramMediaResource? {
    if let foundResource = findMediaResource(media: media, previousMedia: previousMedia, resource: resource) {
        return foundResource
    } else {
        return nil
    }
}

private enum MediaReferenceRevalidationKey: Hashable {
    case message(message: MessageReference)
    case webPage(webPage: WebpageReference)
    case stickerPack(stickerPack: StickerPackReference)
    case savedGifs
    case savedStickers
    case recentStickers
    case peer(peer: PeerReference)
    case wallpaper(wallpaper: WallpaperReference)
    case wallpapers
    case themes
    case peerAvatars(peer: PeerReference)
    case attachBot(peer: PeerReference)
    case notificationSoundList
    case customEmoji(fileId: Int64)
    case story(peer: PeerReference, id: Int32)
    case starsTransaction(transaction: StarsTransactionReference)
}

private final class MediaReferenceRevalidationItemContext {
    let subscribers = Bag<(Any) -> Void>()
    let disposable: Disposable
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    var isEmpty: Bool {
        return self.subscribers.isEmpty
    }
    
    func addSubscriber(_ f: @escaping (Any) -> Void) -> Int {
        return self.subscribers.add(f)
    }
    
    func removeSubscriber(_ index: Int) {
        self.subscribers.remove(index)
    }
}

private struct MediaReferenceRevalidationKeyAndPlacement: Hashable {
    let key: MediaReferenceRevalidationKey
    let background: Bool
}

private final class MediaReferenceRevalidationContextImpl {
    let queue: Queue
    
    var itemContexts: [MediaReferenceRevalidationKeyAndPlacement: MediaReferenceRevalidationItemContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    func genericItem(key: MediaReferenceRevalidationKey, background: Bool, request: @escaping (@escaping (Any) -> Void, @escaping (RevalidateMediaReferenceError) -> Void) -> Disposable, _ f: @escaping (Any) -> Void) -> Disposable {
        let queue = self.queue
        
        let itemKey = MediaReferenceRevalidationKeyAndPlacement(key: key, background: background)
        
        let context: MediaReferenceRevalidationItemContext
        if let current = self.itemContexts[itemKey] {
            context = current
        } else {
            let disposable = MetaDisposable()
            context = MediaReferenceRevalidationItemContext(disposable: disposable)
            self.itemContexts[itemKey] = context
            disposable.set(request({ [weak self] result in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    if let current = strongSelf.itemContexts[itemKey], current === context {
                        strongSelf.itemContexts.removeValue(forKey: itemKey)
                        for subscriber in current.subscribers.copyItems() {
                            subscriber(result)
                        }
                    }
                }
            }, { _ in
            }))
        }
        
        let index = context.addSubscriber(f)
        
        return ActionDisposable { [weak self, weak context] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                if let current = strongSelf.itemContexts[itemKey], current === context {
                    current.removeSubscriber(index)
                    if current.isEmpty {
                        current.disposable.dispose()
                        strongSelf.itemContexts.removeValue(forKey: itemKey)
                    }
                }
            }
        }
    }
}

final class MediaReferenceRevalidationContext {
    private let queue: Queue
    private let impl: QueueLocalObject<MediaReferenceRevalidationContextImpl>
    
    init() {
        self.queue = Queue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return MediaReferenceRevalidationContextImpl(queue: queue)
        })
    }
    
    private func genericItem(key: MediaReferenceRevalidationKey, background: Bool, request: @escaping (@escaping (Any) -> Void, @escaping (RevalidateMediaReferenceError) -> Void) -> Disposable) -> Signal<Any, RevalidateMediaReferenceError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.genericItem(key: key, background: background, request: request, { result in
                    subscriber.putNext(result)
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    func message(accountPeerId: PeerId, postbox: Postbox, network: Network, background: Bool, message: MessageReference) -> Signal<Message, RevalidateMediaReferenceError> {
        return self.genericItem(key: .message(message: message), background: background, request: { next, error in
            let source: Signal<FetchMessageHistoryHoleSource, NoError>
            if background {
                source = network.background()
                |> map(FetchMessageHistoryHoleSource.download)
            } else {
                source = .single(.network(network))
            }
            let signal = source
            |> mapToSignal { source -> Signal<Message?, NoError> in
                return fetchRemoteMessage(accountPeerId: accountPeerId, postbox: postbox, source: source, message: message)
            }
            return signal.start(next: { value in
                if let value = value {
                    next(value)
                } else {
                    error(.generic)
                }
            })
        }) |> mapToSignal { next -> Signal<Message, RevalidateMediaReferenceError> in
            if let next = next as? Message {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func stickerPack(postbox: Postbox, network: Network, background: Bool, stickerPack: StickerPackReference) -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem]), RevalidateMediaReferenceError> {
        return self.genericItem(key: .stickerPack(stickerPack: stickerPack), background: background, request: { next, error in
            return (updatedRemoteStickerPack(postbox: postbox, network: network, reference: stickerPack)
            |> mapError { _ -> RevalidateMediaReferenceError in
            }).start(next: { value in
                if let value = value {
                    next(value)
                } else {
                    error(.generic)
                }
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem]), RevalidateMediaReferenceError> in
            if let next = next as? (StickerPackCollectionInfo, [ItemCollectionItem]) {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func customEmoji(postbox: Postbox, network: Network, background: Bool, fileId: Int64) -> Signal<TelegramMediaFile, RevalidateMediaReferenceError> {
        return network.request(Api.functions.messages.getCustomEmojiDocuments(documentId: [fileId]))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Api.Document]?, NoError> in
            return .single(nil)
        }
        |> castError(RevalidateMediaReferenceError.self)
        |> mapToSignal { result -> Signal<TelegramMediaFile, RevalidateMediaReferenceError> in
            guard let result = result else {
                return .fail(.generic)
            }
            for document in result {
                if let file = telegramMediaFileFromApiDocument(document, altDocuments: []) {
                    return .single(file)
                }
            }
            return .fail(.generic)
        }
    }
    
    func webPage(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network, background: Bool, webPage: WebpageReference) -> Signal<TelegramMediaWebpage, RevalidateMediaReferenceError> {
        return self.genericItem(key: .webPage(webPage: webPage), background: background, request: { next, error in
            return (updatedRemoteWebpage(postbox: postbox, network: network, accountPeerId: accountPeerId, webPage: webPage)
            |> mapError { _ -> RevalidateMediaReferenceError in
            }).start(next: { value in
                if let value = value {
                    next(value)
                } else {
                    error(.generic)
                }
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<TelegramMediaWebpage, RevalidateMediaReferenceError> in
            if let next = next as? TelegramMediaWebpage {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func savedGifs(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramMediaFile.Accessor], RevalidateMediaReferenceError> {
        return self.genericItem(key: .savedGifs, background: background, request: { next, error in
            let loadRecentGifs: Signal<[TelegramMediaFile.Accessor], NoError> = postbox.transaction { transaction -> [TelegramMediaFile.Accessor] in
                return transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap({ item -> TelegramMediaFile.Accessor? in
                    if let contents = item.contents.get(RecentMediaItem.self) {
                        let file = contents.media
                        return file
                    }
                    return nil
                })
            }
            return (managedRecentGifs(postbox: postbox, network: network, forceFetch: true)
            |> mapToSignal { _ -> Signal<[TelegramMediaFile.Accessor], NoError> in
                return .complete()
            }
            |> then(loadRecentGifs)
            |> castError(RevalidateMediaReferenceError.self)).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramMediaFile.Accessor], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramMediaFile.Accessor] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func savedStickers(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramMediaFile.Accessor], RevalidateMediaReferenceError> {
        return self.genericItem(key: .savedStickers, background: background, request: { next, error in
            let loadSavedStickers: Signal<[TelegramMediaFile.Accessor], NoError> = postbox.transaction { transaction -> [TelegramMediaFile.Accessor] in
                return transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers).compactMap({ item -> TelegramMediaFile.Accessor? in
                    if let contents = item.contents.get(SavedStickerItem.self) {
                        let file = contents.file
                        return file
                    }
                    return nil
                })
            }
            return (managedSavedStickers(postbox: postbox, network: network, forceFetch: true)
            |> mapToSignal { _ -> Signal<[TelegramMediaFile.Accessor], NoError> in
                return .complete()
            }
            |> then(loadSavedStickers)
            |> castError(RevalidateMediaReferenceError.self)).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramMediaFile.Accessor], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramMediaFile.Accessor] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func recentStickers(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramMediaFile.Accessor], RevalidateMediaReferenceError> {
        return self.genericItem(key: .recentStickers, background: background, request: { next, error in
            let loadRecentStickers: Signal<[TelegramMediaFile.Accessor], NoError> = postbox.transaction { transaction -> [TelegramMediaFile.Accessor] in
                return transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers).compactMap({ item -> TelegramMediaFile.Accessor? in
                    if let contents = item.contents.get(RecentMediaItem.self) {
                        let file = contents.media
                        return file
                    }
                    return nil
                })
            }
            return (managedRecentStickers(postbox: postbox, network: network, forceFetch: true)
            |> mapToSignal { _ -> Signal<[TelegramMediaFile.Accessor], NoError> in
                return .complete()
            }
            |> then(loadRecentStickers)
            |> castError(RevalidateMediaReferenceError.self)).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramMediaFile.Accessor], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramMediaFile.Accessor] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func peer(accountPeerId: PeerId, postbox: Postbox, network: Network, background: Bool, peer: PeerReference) -> Signal<Peer, RevalidateMediaReferenceError> {
        return self.genericItem(key: .peer(peer: peer), background: background, request: { next, error in
            return (_internal_updatedRemotePeer(accountPeerId: accountPeerId, postbox: postbox, network: network, peer: peer)
            |> mapError { _ -> RevalidateMediaReferenceError in
                return .generic
            }).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<Peer, RevalidateMediaReferenceError> in
            if let next = next as? Peer {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func wallpapers(postbox: Postbox, network: Network, background: Bool, wallpaper: WallpaperReference?) -> Signal<[TelegramWallpaper], RevalidateMediaReferenceError> {
        let key: MediaReferenceRevalidationKey
        if let wallpaper = wallpaper {
            key = .wallpaper(wallpaper: wallpaper)
        } else {
            key = .wallpapers
        }
        return self.genericItem(key: key, background: background, request: { next, error in
            let signal: Signal<[TelegramWallpaper]?, RevalidateMediaReferenceError>
            if let wallpaper = wallpaper, case let .slug(slug) = wallpaper {
                signal = getWallpaper(network: network, slug: slug)
                |> mapError { _ -> RevalidateMediaReferenceError in
                    return .generic
                }
                |> map { [$0] }
            } else {
                signal = telegramWallpapers(postbox: postbox, network: network, forceUpdate: true)
                |> last
                |> mapError { _ -> RevalidateMediaReferenceError in
                }
            }
            return (signal
            ).start(next: { value in
                if let value = value {
                    next(value)
                } else {
                    error(.generic)
                }
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramWallpaper], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramWallpaper] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func themes(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramTheme], RevalidateMediaReferenceError> {
        return self.genericItem(key: .themes, background: background, request: { next, error in
            return (telegramThemes(postbox: postbox, network: network, accountManager: nil, forceUpdate: true)
            |> take(1)
            |> mapError { _ -> RevalidateMediaReferenceError in
            }).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramTheme], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramTheme] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func peerAvatars(accountPeerId: PeerId, postbox: Postbox, network: Network, background: Bool, peer: PeerReference) -> Signal<[TelegramPeerPhoto], RevalidateMediaReferenceError> {
        return self.genericItem(key: .peerAvatars(peer: peer), background: background, request: { next, error in
            return (_internal_requestPeerPhotos(accountPeerId: accountPeerId, postbox: postbox, network: network, peerId: peer.id)
            |> mapError { _ -> RevalidateMediaReferenceError in
            }).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramPeerPhoto], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramPeerPhoto] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func attachBot(accountPeerId: PeerId, postbox: Postbox, network: Network, background: Bool, peer: PeerReference) -> Signal<AttachMenuBot, RevalidateMediaReferenceError> {
        return self.genericItem(key: .attachBot(peer: peer), background: background, request: { next, error in
            return (_internal_getAttachMenuBot(accountPeerId: accountPeerId, postbox: postbox, network: network, botId: peer.id, cached: false)
            |> mapError { _ -> RevalidateMediaReferenceError in
                return .generic
            }).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<AttachMenuBot, RevalidateMediaReferenceError> in
            if let next = next as? AttachMenuBot {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func story(accountPeerId: PeerId, postbox: Postbox, network: Network, background: Bool, peer: PeerReference, id: Int32) -> Signal<Stories.StoredItem, RevalidateMediaReferenceError> {
        return self.genericItem(key: .story(peer: peer, id: id), background: background, request: { next, error in
            return (_internal_getStoriesById(accountPeerId: accountPeerId, postbox: postbox, network: network, peer: peer, ids: [id])
            |> castError(RevalidateMediaReferenceError.self)
            |> mapToSignal { result -> Signal<Stories.StoredItem, RevalidateMediaReferenceError> in
                if let item = result.first {
                    return .single(item)
                } else {
                    return .fail(.generic)
                }
            }).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        })
        |> mapToSignal { next -> Signal<Stories.StoredItem, RevalidateMediaReferenceError> in
            if let next = next as? Stories.StoredItem {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func starsTransaction(accountPeerId: PeerId, postbox: Postbox, network: Network, background: Bool, transaction: StarsTransactionReference) -> Signal<StarsContext.State.Transaction, RevalidateMediaReferenceError> {
        return self.genericItem(key: .starsTransaction(transaction: transaction), background: background, request: { next, error in
            return (_internal_getStarsTransaction(accountPeerId: accountPeerId, postbox: postbox, network: network, transactionReference: transaction)
            |> castError(RevalidateMediaReferenceError.self)
            |> mapToSignal { result -> Signal<StarsContext.State.Transaction, RevalidateMediaReferenceError> in
                if let result {
                    return .single(result)
                } else {
                    return .fail(.generic)
                }
            }).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<StarsContext.State.Transaction, RevalidateMediaReferenceError> in
            if let next = next as? StarsContext.State.Transaction {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func notificationSoundList(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramMediaFile], RevalidateMediaReferenceError> {
        return self.genericItem(key: .notificationSoundList, background: background, request: { next, error in
            return (requestNotificationSoundList(network: network, hash: 0)
            |> map { result -> [TelegramMediaFile] in
                guard let result = result else {
                    return []
                }
                return result.sounds.map(\.file)
            }).start(next: next)
        }) |> mapToSignal { next -> Signal<[TelegramMediaFile], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramMediaFile] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
}

struct RevalidatedMediaResource {
    let updatedResource: TelegramMediaResource
    let updatedReference: MediaResourceReference?
}

func revalidateMediaResourceReference(accountPeerId: PeerId, postbox: Postbox, network: Network, revalidationContext: MediaReferenceRevalidationContext, info: TelegramCloudMediaResourceFetchInfo, resource: MediaResource) -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> {
    var updatedReference = info.reference
    if case let .media(media, resource) = updatedReference {
        if case let .message(messageReference, mediaValue) = media {
            if let file = mediaValue as? TelegramMediaFile {
                if let partialReference = file.partialReference {
                    updatedReference = partialReference.mediaReference(media.media).resourceReference(resource)
                }
                
                var revalidateWithStickerpack = false
                if file.isSticker {
                    if messageReference.isSecret == true {
                        revalidateWithStickerpack = true
                    } else if case .none = messageReference.content {
                        revalidateWithStickerpack = true
                    }
                }
                
                if revalidateWithStickerpack {
                    var stickerPackReference: StickerPackReference?
                    for attribute in file.attributes {
                        if case let .Sticker(_, packReferenceValue, _) = attribute {
                            if let packReference = packReferenceValue {
                                stickerPackReference = packReference
                            }
                        }
                    }
                    if let stickerPackReference = stickerPackReference {
                        updatedReference = .media(media: .stickerPack(stickerPack: stickerPackReference, media: mediaValue), resource: resource)
                    }
                }
            } else if let image = mediaValue as? TelegramMediaImage {
                if let partialReference = image.partialReference {
                    updatedReference = partialReference.mediaReference(media.media).resourceReference(resource)
                }
            }
        }
    }
    
    switch updatedReference {
        case let .media(media, _):
            switch media {
                case let .message(message, previousMedia):
                    return revalidationContext.message(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, message: message)
                    |> mapToSignal { message -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for media in message.media {
                            if let updatedResource = findUpdatedMediaResource(media: media, previousMedia: previousMedia, resource: resource) {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        }
                        return .fail(.generic)
                    }
                case let .stickerPack(stickerPack, media):
                    return revalidationContext.stickerPack(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, stickerPack: stickerPack)
                    |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for item in result.1 {
                            if let item = item as? StickerPackItem {
                                if media.id != nil && item.file.id == media.id {
                                    let itemFile = item.file._parse()
                                    if let updatedResource = findUpdatedMediaResource(media: itemFile, previousMedia: media, resource: resource) {
                                        return postbox.transaction { transaction -> RevalidatedMediaResource in
                                            if let id = media.id {
                                                var attributes = itemFile.attributes
                                                if !attributes.contains(where: { attribute in
                                                    if case .hintIsValidated = attribute {
                                                        return true
                                                    } else {
                                                        return false
                                                    }
                                                }) {
                                                    attributes.append(.hintIsValidated)
                                                }
                                                let file = itemFile.withUpdatedAttributes(attributes)
                                                updateMessageMedia(transaction: transaction, id: id, media: file)
                                            }
                                            return RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil)
                                        }
                                        |> castError(RevalidateMediaReferenceError.self)
                                    }
                                }
                            }
                        }
                        return .fail(.generic)
                    }
                case let .webPage(webPage, previousMedia):
                    return revalidationContext.webPage(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, webPage: webPage)
                    |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        if let updatedResource = findUpdatedMediaResource(media: result, previousMedia: previousMedia, resource: resource) {
                            return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                        }
                        return .fail(.generic)
                    }
                case let .savedGif(media):
                    return revalidationContext.savedGifs(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation)
                    |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for file in result {
                            if media.id != nil && file.id == media.id {
                                if let updatedResource = findUpdatedMediaResource(media: file._parse(), previousMedia: media, resource: resource) {
                                    return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                }
                            }
                        }
                        return .fail(.generic)
                    }
                case let .savedSticker(media):
                    return revalidationContext.savedStickers(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation)
                    |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for file in result {
                            if media.id != nil && file.id == media.id {
                                if let updatedResource = findUpdatedMediaResource(media: file._parse(), previousMedia: media, resource: resource) {
                                    return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                }
                            }
                        }
                        return .fail(.generic)
                    }
                case let .recentSticker(media):
                    return revalidationContext.recentStickers(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation)
                    |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for file in result {
                            if media.id != nil && file.id == media.id {
                                if let updatedResource = findUpdatedMediaResource(media: file._parse(), previousMedia: media, resource: resource) {
                                    return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                }
                            }
                        }
                        return .fail(.generic)
                    }
                case let .avatarList(peer, media):
                    return revalidationContext.peerAvatars(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, peer: peer)
                    |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for photo in result {
                            if let updatedResource = findUpdatedMediaResource(media: photo.image, previousMedia: media, resource: resource) {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        }
                        return .fail(.generic)
                    }
                case let .attachBot(peer, _):
                    return revalidationContext.attachBot(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, peer: peer)
                    |> mapToSignal { attachBot -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for (_, icon) in attachBot.icons {
                            if let updatedResource = findUpdatedMediaResource(media: icon, previousMedia: nil, resource: resource) {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        }
                        return .fail(.generic)
                    }
                case let .story(peer, id, _):
                    return revalidationContext.story(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, peer: peer, id: id)
                    |> mapToSignal { storyItem -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        guard case let .item(item) = storyItem, let media = item.media else {
                            return .fail(.generic)
                        }
                        if let updatedResource = findUpdatedMediaResource(media: media, previousMedia: nil, resource: resource) {
                            return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                        } else {
                            for alternativeMediaValue in item.alternativeMediaList {
                                if let updatedResource = findUpdatedMediaResource(media: alternativeMediaValue, previousMedia: nil, resource: resource) {
                                    return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                }
                            }
                            return .fail(.generic)
                        }
                    }
                case let .starsTransaction(transaction, _):
                    return revalidationContext.starsTransaction(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, transaction: transaction)
                    |> mapToSignal { transaction -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                        for transactionMedia in transaction.media {
                            if let updatedResource = findUpdatedMediaResource(media: transactionMedia, previousMedia: nil, resource: resource) {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        }
                        return .fail(.generic)
                    }
                case let .standalone(media):
                    if let file = media as? TelegramMediaFile {
                        for attribute in file.attributes {
                            if case let .Sticker(_, packReferenceValue, _) = attribute, let stickerPack = packReferenceValue {
                                return revalidationContext.stickerPack(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, stickerPack: stickerPack)
                                |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                                    for item in result.1 {
                                        if let item = item as? StickerPackItem {
                                            if media.id != nil && item.file.id == media.id {
                                                if let updatedResource = findUpdatedMediaResource(media: item.file._parse(), previousMedia: media,  resource: resource) {
                                                    return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                                }
                                            }
                                        }
                                    }
                                    return .fail(.generic)
                                }
                            }
                        }
                    }
                    return .fail(.generic)
                case let .customEmoji(media):
                    if let file = media as? TelegramMediaFile {
                        return revalidationContext.customEmoji(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, fileId: file.fileId.id)
                        |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                            if let updatedResource = findUpdatedMediaResource(media: result, previousMedia: media, resource: resource) {
                                return postbox.transaction { transaction -> RevalidatedMediaResource in
                                    if let id = media.id {
                                        var attributes = result.attributes
                                        if !attributes.contains(where: { attribute in
                                            if case .hintIsValidated = attribute {
                                                return true
                                            } else {
                                                return false
                                            }
                                        }) {
                                            attributes.append(.hintIsValidated)
                                        }
                                        let file = result.withUpdatedAttributes(attributes)
                                        updateMessageMedia(transaction: transaction, id: id, media: file)
                                    }
                                    return RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil)
                                }
                                |> castError(RevalidateMediaReferenceError.self)
                            } else {
                                return .fail(.generic)
                            }
                        }
                    } else {
                        return .fail(.generic)
                    }
                }
        case let .avatar(peer, _):
            return revalidationContext.peer(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, peer: peer)
            |> mapToSignal { updatedPeer -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for representation in updatedPeer.profileImageRepresentations {
                    if let updatedResource = representation.resource as? CloudPeerPhotoSizeMediaResource, let previousResource = resource as? CloudPeerPhotoSizeMediaResource {
                        if updatedResource.sizeSpec == previousResource.sizeSpec {
                            return .single(RevalidatedMediaResource(updatedResource: representation.resource, updatedReference: nil))
                        }
                    }
                    if representation.resource.id == resource.id {
                        return .single(RevalidatedMediaResource(updatedResource: representation.resource, updatedReference: nil))
                    }
                }
                return .fail(.generic)
            }
        case let .avatarList(peer, _):
            return revalidationContext.peerAvatars(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, peer: peer)
            |> mapToSignal { updatedPeerAvatars -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for photo in updatedPeerAvatars {
                    if let updatedResource = findUpdatedMediaResource(media: photo.image, previousMedia: nil, resource: resource) {
                        return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                    }
                }
                return .fail(.generic)
            }
        case let .messageAuthorAvatar(message, _):
            return revalidationContext.message(accountPeerId: accountPeerId, postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, message: message)
            |> mapToSignal { updatedMessage -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                guard let author = updatedMessage.author, let authorReference = PeerReference(author) else {
                    return .fail(.generic)
                }
                for representation in author.profileImageRepresentations {
                    if representation.resource.id == resource.id {
                        return .single(RevalidatedMediaResource(updatedResource: representation.resource, updatedReference: .avatar(peer: authorReference, resource: representation.resource)))
                    }
                }
                if let legacyResource = resource as? CloudFileMediaResource {
                    for representation in author.profileImageRepresentations {
                        if let updatedResource = representation.resource as? CloudPeerPhotoSizeMediaResource {
                            if updatedResource.localId == legacyResource.localId && updatedResource.volumeId == legacyResource.volumeId {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: .avatar(peer: authorReference, resource: updatedResource)))
                            }
                        }
                    }
                }
                return .fail(.generic)
            }
        case let .wallpaper(wallpaper, _):
            return revalidationContext.wallpapers(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, wallpaper: wallpaper)
            |> mapToSignal { wallpapers -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for wallpaper in wallpapers {
                    switch wallpaper {
                        case let .image(representations, _):
                            for representation in representations {
                                if representation.resource.id == resource.id {
                                    return .single(RevalidatedMediaResource(updatedResource: representation.resource, updatedReference: nil))
                                }
                            }
                        case let .file(file):
                            if let updatedResource = findUpdatedMediaResource(media: file.file, previousMedia: nil, resource: resource) {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        default:
                            break
                    }
                }
                return .fail(.generic)
            }
        case let .stickerPackThumbnail(packReference, resource):
            return revalidationContext.stickerPack(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, stickerPack: packReference)
            |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                if let thumbnail = result.0.thumbnail {
                    if thumbnail.resource.id == resource.id {
                        return .single(RevalidatedMediaResource(updatedResource: thumbnail.resource, updatedReference: nil))
                    }
                    if let _ = thumbnail.resource as? CloudStickerPackThumbnailMediaResource, let _ = resource as? CloudStickerPackThumbnailMediaResource {
                        return .single(RevalidatedMediaResource(updatedResource: thumbnail.resource, updatedReference: nil))
                    }
                }
                return .fail(.generic)
            }
        case let .theme(_, resource):
            return revalidationContext.themes(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation)
            |> mapToSignal { themes -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for theme in themes {
                    if let file = theme.file, file.resource.id == resource.id  {
                        return .single(RevalidatedMediaResource(updatedResource: file.resource, updatedReference: nil))
                    }
                }
                return .fail(.generic)
            }
        case let .soundList(resource):
            return revalidationContext.notificationSoundList(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation)
            |> mapToSignal { files -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for file in files {
                    if file.resource.id == resource.id  {
                        return .single(RevalidatedMediaResource(updatedResource: file.resource, updatedReference: nil))
                    }
                }
                return .fail(.generic)
            }
        case .standalone:
            return .fail(.generic)
    }
}
