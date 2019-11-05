import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public struct MessageReference: PostboxCoding, Hashable, Equatable {
    let content: MessageReferenceContent
    
    public var peer: PeerReference? {
        switch content {
            case .none:
                return nil
            case let .message(peer, _, _, _, _):
                return peer
        }
    }
    
    public var timestamp: Int32? {
        switch content {
            case .none:
                return nil
            case let .message(_, _, timestamp, _, _):
                return timestamp
        }
    }
    
    public var isIncoming: Bool? {
        switch content {
            case .none:
                return nil
            case let .message(_, _, _, incoming, _):
                return incoming
        }
    }
    
    public var isSecret: Bool? {
        switch content {
            case .none:
                return nil
            case let .message(_, _, _, _, secret):
                return secret
        }
    }
    
    public init(_ message: Message) {
        if message.id.namespace != Namespaces.Message.Local, let peer = message.peers[message.id.peerId], let inputPeer = PeerReference(peer) {
            self.content = .message(peer: inputPeer, id: message.id, timestamp: message.timestamp, incoming: message.flags.contains(.Incoming), secret: message.containsSecretMedia)
        } else {
            self.content = .none
        }
    }
    
    public init(peer: Peer, id: MessageId, timestamp: Int32, incoming: Bool, secret: Bool) {
        if let inputPeer = PeerReference(peer) {
            self.content = .message(peer: inputPeer, id: id, timestamp: timestamp, incoming: incoming, secret: secret)
        } else {
            self.content = .none
        }
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { MessageReferenceContent(decoder: $0) }) as! MessageReferenceContent
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

enum MessageReferenceContent: PostboxCoding, Hashable, Equatable {
    case none
    case message(peer: PeerReference, id: MessageId, timestamp: Int32, incoming: Bool, secret: Bool)
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_r", orElse: 0) {
            case 0:
                self = .none
            case 1:
                self = .message(peer: decoder.decodeObjectForKey("p", decoder: { PeerReference(decoder: $0) }) as! PeerReference, id: MessageId(peerId: PeerId(decoder.decodeInt64ForKey("i.p", orElse: 0)), namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt32ForKey("i.i", orElse: 0)), timestamp: 0, incoming: false, secret: false)
            default:
                assertionFailure()
                self = .none
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "_r")
            case let .message(peer, id, _, _, _):
                encoder.encodeInt32(1, forKey: "_r")
                encoder.encodeObject(peer, forKey: "p")
                encoder.encodeInt64(id.peerId.toInt64(), forKey: "i.p")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt32(id.id, forKey: "i.i")
        }
    }
}

public struct WebpageReference: PostboxCoding, Hashable, Equatable {
    let content: WebpageReferenceContent
    
    public init(_ webPage: TelegramMediaWebpage) {
        if case let .Loaded(content) = webPage.content {
            self.content = .webPage(id: webPage.webpageId.id, url: content.url)
        } else {
            self.content = .none
        }
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { WebpageReferenceContent(decoder: $0) }) as! WebpageReferenceContent
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

enum WebpageReferenceContent: PostboxCoding, Hashable, Equatable {
    case none
    case webPage(id: Int64, url: String)
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_r", orElse: 0) {
            case 0:
                self = .none
            case 1:
                self = .webPage(id: decoder.decodeInt64ForKey("i", orElse: 0), url: decoder.decodeStringForKey("u", orElse: ""))
            default:
                assertionFailure()
                self = .none
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "_r")
            case let .webPage(id, url):
                encoder.encodeInt32(1, forKey: "_r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeString(url, forKey: "u")
        }
    }
}

public enum AnyMediaReference: Equatable {
    case standalone(media: Media)
    case message(message: MessageReference, media: Media)
    case webPage(webPage: WebpageReference, media: Media)
    case stickerPack(stickerPack: StickerPackReference, media: Media)
    case savedGif(media: Media)
    
    public static func ==(lhs: AnyMediaReference, rhs: AnyMediaReference) -> Bool {
        switch lhs {
            case let .standalone(lhsMedia):
                if case let .standalone(rhsMedia) = rhs, lhsMedia.isEqual(to: rhsMedia) {
                    return true
                } else {
                    return false
                }
            case let .message(lhsMessage, lhsMedia):
                if case let .message(rhsMessage, rhsMedia) = rhs, lhsMessage == rhsMessage, lhsMedia.isEqual(to: rhsMedia) {
                    return true
                } else {
                    return false
                }
            case let .webPage(lhsWebPage, lhsMedia):
                if case let .webPage(rhsWebPage, rhsMedia) = rhs, lhsWebPage == rhsWebPage, lhsMedia.isEqual(to: rhsMedia) {
                    return true
                } else {
                    return false
                }
            case let .stickerPack(lhsStickerPack, lhsMedia):
                if case let .stickerPack(rhsStickerPack, rhsMedia) = rhs, lhsStickerPack == rhsStickerPack, lhsMedia.isEqual(to: rhsMedia) {
                    return true
                } else {
                    return false
                }
            case let .savedGif(lhsMedia):
                if case let .savedGif(rhsMedia) = rhs, lhsMedia.isEqual(to: rhsMedia) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var partial: PartialMediaReference? {
        switch self {
            case .standalone:
                return nil
            case let .message(message, _):
                return .message(message: message)
            case let .webPage(webPage, _):
                return .webPage(webPage: webPage)
            case let .stickerPack(stickerPack, _):
                return .stickerPack(stickerPack: stickerPack)
            case .savedGif:
                return .savedGif
        }
    }
    
    public func concrete<T: Media>(_ type: T.Type) -> MediaReference<T>? {
        switch self {
            case let .standalone(media):
                if let media = media as? T {
                    return .standalone(media: media)
                }
            case let .message(message, media):
                if let media = media as? T {
                    return .message(message: message, media: media)
                }
            case let .webPage(webPage, media):
                if let media = media as? T {
                    return .webPage(webPage: webPage, media: media)
                }
            case let .stickerPack(stickerPack, media):
                if let media = media as? T {
                    return .stickerPack(stickerPack: stickerPack, media: media)
                }
            case let .savedGif(media):
                if let media = media as? T {
                    return .savedGif(media: media)
                }
        }
        return nil
    }
    
    public var media: Media {
        switch self {
            case let .standalone(media):
                return media
            case let .message(_, media):
                return media
            case let .webPage(_, media):
                return media
            case let .stickerPack(_, media):
                return media
            case let .savedGif(media):
                return media
        }
    }
    
    public func resourceReference(_ resource: MediaResource) -> MediaResourceReference {
        return .media(media: self, resource: resource)
    }
}

public enum PartialMediaReference: Equatable {
    private enum CodingCase: Int32 {
        case message
        case webPage
        case stickerPack
        case savedGif
    }
    
    case message(message: MessageReference)
    case webPage(webPage: WebpageReference)
    case stickerPack(stickerPack: StickerPackReference)
    case savedGif
    
    init?(decoder: PostboxDecoder) {
        guard let caseIdValue = decoder.decodeOptionalInt32ForKey("_r"), let caseId = CodingCase(rawValue: caseIdValue) else {
            return nil
        }
        switch caseId {
            case .message:
                let message = decoder.decodeObjectForKey("msg", decoder: { MessageReference(decoder: $0) }) as! MessageReference
                self = .message(message: message)
            case .webPage:
                let webPage = decoder.decodeObjectForKey("wpg", decoder: { WebpageReference(decoder: $0) }) as! WebpageReference
                self = .webPage(webPage: webPage)
            case .stickerPack:
                let stickerPack = decoder.decodeObjectForKey("spk", decoder: { StickerPackReference(decoder: $0) }) as! StickerPackReference
                self = .stickerPack(stickerPack: stickerPack)
            case .savedGif:
                self = .savedGif
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .message(message):
                encoder.encodeInt32(CodingCase.message.rawValue, forKey: "_r")
                encoder.encodeObject(message, forKey: "msg")
            case let .webPage(webPage):
                encoder.encodeInt32(CodingCase.webPage.rawValue, forKey: "_r")
                encoder.encodeObject(webPage, forKey: "wpg")
            case let .stickerPack(stickerPack):
                encoder.encodeInt32(CodingCase.stickerPack.rawValue, forKey: "_r")
                encoder.encodeObject(stickerPack, forKey: "spk")
            case .savedGif:
                encoder.encodeInt32(CodingCase.savedGif.rawValue, forKey: "_r")
        }
    }
    
    func mediaReference(_ media: Media) -> AnyMediaReference {
        switch self {
            case let .message(message):
                return .message(message: message, media: media)
            case let .webPage(webPage):
                return .webPage(webPage: webPage, media: media)
            case let .stickerPack(stickerPack):
                return .stickerPack(stickerPack: stickerPack, media: media)
            case .savedGif:
                return .savedGif(media: media)
        }
    }
}

public enum MediaReference<T: Media> {
    private enum CodingCase: Int32 {
        case standalone
        case message
        case webPage
        case stickerPack
        case savedGif
    }
    
    case standalone(media: T)
    case message(message: MessageReference, media: T)
    case webPage(webPage: WebpageReference, media: T)
    case stickerPack(stickerPack: StickerPackReference, media: T)
    case savedGif(media: T)
    
    init?(decoder: PostboxDecoder) {
        guard let caseIdValue = decoder.decodeOptionalInt32ForKey("_r"), let caseId = CodingCase(rawValue: caseIdValue) else {
            return nil
        }
        switch caseId {
            case .standalone:
                guard let media = decoder.decodeObjectForKey("m") as? T else {
                    return nil
                }
                self = .standalone(media: media)
            case .message:
                let message = decoder.decodeObjectForKey("msg", decoder: { MessageReference(decoder: $0) }) as! MessageReference
                guard let media = decoder.decodeObjectForKey("m") as? T else {
                    return nil
                }
                self = .message(message: message, media: media)
            case .webPage:
                let webPage = decoder.decodeObjectForKey("wpg", decoder: { WebpageReference(decoder: $0) }) as! WebpageReference
                guard let media = decoder.decodeObjectForKey("m") as? T else {
                    return nil
                }
                self = .webPage(webPage: webPage, media: media)
            case .stickerPack:
                let stickerPack = decoder.decodeObjectForKey("spk", decoder: { StickerPackReference(decoder: $0) }) as! StickerPackReference
                guard let media = decoder.decodeObjectForKey("m") as? T else {
                    return nil
                }
                self = .stickerPack(stickerPack: stickerPack, media: media)
            case .savedGif:
                guard let media = decoder.decodeObjectForKey("m") as? T else {
                    return nil
                }
                self = .savedGif(media: media)
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .standalone(media):
                encoder.encodeInt32(CodingCase.standalone.rawValue, forKey: "_r")
                encoder.encodeObject(media, forKey: "m")
            case let .message(message, media):
                encoder.encodeInt32(CodingCase.message.rawValue, forKey: "_r")
                encoder.encodeObject(message, forKey: "msg")
                encoder.encodeObject(media, forKey: "m")
            case let .webPage(webPage, media):
                encoder.encodeInt32(CodingCase.webPage.rawValue, forKey: "_r")
                encoder.encodeObject(webPage, forKey: "wpg")
                encoder.encodeObject(media, forKey: "m")
            case let .stickerPack(stickerPack, media):
                encoder.encodeInt32(CodingCase.stickerPack.rawValue, forKey: "_r")
                encoder.encodeObject(stickerPack, forKey: "spk")
                encoder.encodeObject(media, forKey: "m")
            case let .savedGif(media):
                encoder.encodeInt32(CodingCase.savedGif.rawValue, forKey: "_r")
                encoder.encodeObject(media, forKey: "m")
        }
    }
    
    public var abstract: AnyMediaReference {
        switch self {
            case let .standalone(media):
                return .standalone(media: media)
            case let .message(message, media):
                return .message(message: message, media: media)
            case let .webPage(webPage, media):
                return .webPage(webPage: webPage, media: media)
            case let .stickerPack(stickerPack, media):
                return .stickerPack(stickerPack: stickerPack, media: media)
            case let .savedGif(media):
                return .savedGif(media: media)
        }
    }
    
    public var partial: PartialMediaReference? {
        return self.abstract.partial
    }
    
    public var media: T {
        switch self {
            case let .standalone(media):
                return media
            case let .message(_, media):
                return media
            case let .webPage(_, media):
                return media
            case let .stickerPack(_, media):
                return media
            case let .savedGif(media):
                return media
        }
    }
    
    public func resourceReference(_ resource: MediaResource) -> MediaResourceReference {
        return .media(media: self.abstract, resource: resource)
    }
}

public typealias FileMediaReference = MediaReference<TelegramMediaFile>
public typealias ImageMediaReference = MediaReference<TelegramMediaImage>

public enum MediaResourceReference: Equatable {
    case media(media: AnyMediaReference, resource: MediaResource)
    case standalone(resource: MediaResource)
    case avatar(peer: PeerReference, resource: MediaResource)
    case messageAuthorAvatar(message: MessageReference, resource: MediaResource)
    case wallpaper(resource: MediaResource)
    case stickerPackThumbnail(stickerPack: StickerPackReference, resource: MediaResource)
    
    public var resource: MediaResource {
        switch self {
            case let .media(_, resource):
                return resource
            case let .standalone(resource):
                return resource
            case let .avatar(_, resource):
                return resource
            case let .messageAuthorAvatar(_, resource):
                return resource
            case let .wallpaper(resource):
                return resource
            case let .stickerPackThumbnail(_, resource):
                return resource
        }
    }
    
    public static func ==(lhs: MediaResourceReference, rhs: MediaResourceReference) -> Bool {
        switch lhs {
            case let .media(lhsMedia, lhsResource):
                if case let .media(rhsMedia, rhsResource) = rhs, lhsMedia == rhsMedia, lhsResource.isEqual(to: rhsResource) {
                    return true
                } else {
                    return false
                }
            case let .standalone(lhsResource):
                if case let .standalone(rhsResource) = rhs, lhsResource.isEqual(to: rhsResource) {
                    return true
                } else {
                    return false
                }
            case let .avatar(lhsPeer, lhsResource):
                if case let .avatar(rhsPeer, rhsResource) = rhs, lhsPeer == rhsPeer, lhsResource.isEqual(to: rhsResource) {
                    return true
                } else {
                    return false
                }
            case let .messageAuthorAvatar(lhsMessage, lhsResource):
                if case let .messageAuthorAvatar(rhsMessage, rhsResource) = rhs, lhsMessage == rhsMessage, lhsResource.isEqual(to: rhsResource) {
                    return true
                } else {
                    return false
                }
            case let .wallpaper(lhsResource):
                if case let .wallpaper(rhsResource) = rhs, lhsResource.isEqual(to: rhsResource) {
                    return true
                } else {
                    return false
                }
            case let .stickerPackThumbnail(lhsStickerPack, lhsResource):
                if case let .stickerPackThumbnail(rhsStickerPack, rhsResource) = rhs, lhsStickerPack == rhsStickerPack, lhsResource.isEqual(to: rhsResource) {
                    return true
                } else {
                    return false
                }
        }
    }
}

extension MediaResourceReference {
    var apiFileReference: Data? {
        if let resource = self.resource as? TelegramCloudMediaResourceWithFileReference {
            return resource.fileReference
        } else {
            return nil
        }
    }
}

final class TelegramCloudMediaResourceFetchInfo: MediaResourceFetchInfo {
    let reference: MediaResourceReference
    let preferBackgroundReferenceRevalidation: Bool
    let continueInBackground: Bool
    
    init(reference: MediaResourceReference, preferBackgroundReferenceRevalidation: Bool, continueInBackground: Bool) {
        self.reference = reference
        self.preferBackgroundReferenceRevalidation = preferBackgroundReferenceRevalidation
        self.continueInBackground = continueInBackground
    }
}

public func fetchedMediaResource(mediaBox: MediaBox, reference: MediaResourceReference, range: (Range<Int>, MediaBoxFetchPriority)? = nil, statsCategory: MediaResourceStatsCategory = .generic, reportResultStatus: Bool = false, preferBackgroundReferenceRevalidation: Bool = false, continueInBackground: Bool = false) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(mediaBox: mediaBox, reference: reference, ranges: range.flatMap({ [$0] }), statsCategory: statsCategory, reportResultStatus: reportResultStatus, preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation, continueInBackground: continueInBackground)
}

public func fetchedMediaResource(mediaBox: MediaBox, reference: MediaResourceReference, ranges: [(Range<Int>, MediaBoxFetchPriority)]?, statsCategory: MediaResourceStatsCategory = .generic, reportResultStatus: Bool = false, preferBackgroundReferenceRevalidation: Bool = false, continueInBackground: Bool = false) -> Signal<FetchResourceSourceType, FetchResourceError> {
    if let ranges = ranges {
        let signals = ranges.map { (range, priority) -> Signal<Void, FetchResourceError> in
            return mediaBox.fetchedResourceData(reference.resource, in: range, priority: priority, parameters: MediaResourceFetchParameters(tag: TelegramMediaResourceFetchTag(statsCategory: statsCategory), info: TelegramCloudMediaResourceFetchInfo(reference: reference, preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation, continueInBackground: continueInBackground)))
        }
        return combineLatest(signals)
        |> ignoreValues
        |> map { _ -> FetchResourceSourceType in .local }
        |> then(.single(.local))
    } else {
        return mediaBox.fetchedResource(reference.resource, parameters: MediaResourceFetchParameters(tag: TelegramMediaResourceFetchTag(statsCategory: statsCategory), info: TelegramCloudMediaResourceFetchInfo(reference: reference, preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation, continueInBackground: continueInBackground)), implNext: reportResultStatus)
    }
}

enum RevalidateMediaReferenceError {
    case generic
}

public func stickerPackFileReference(_ file: TelegramMediaFile) -> FileMediaReference {
    for attribute in file.attributes {
        if case let .Sticker(sticker) = attribute, let stickerPack = sticker.packReference {
            return .stickerPack(stickerPack: stickerPack, media: file)
        }
    }
    return .standalone(media: file)
}

private func findMediaResource(media: Media, previousMedia: Media?, resource: MediaResource) -> TelegramMediaResource? {
    if let image = media as? TelegramMediaImage {
        for representation in image.representations {
            if representation.resource.id.isEqual(to: resource.id) {
                return representation.resource
            }
        }
        if let legacyResource = resource as? CloudFileMediaResource {
            for representation in image.representations {
                if let updatedResource = representation.resource as? CloudPhotoSizeMediaResource {
                    if updatedResource.localId == legacyResource.localId && updatedResource.volumeId == legacyResource.volumeId {
                        return representation.resource
                    }
                }
            }
        }
    } else if let file = media as? TelegramMediaFile {
        if file.resource.id.isEqual(to: resource.id) {
            return file.resource
        } else {
            for representation in file.previewRepresentations {
                if representation.resource.id.isEqual(to: resource.id) {
                    return representation.resource
                }
            }
            if let legacyResource = resource as? CloudFileMediaResource {
                for representation in file.previewRepresentations {
                    if let updatedResource = representation.resource as? CloudDocumentSizeMediaResource {
                        if updatedResource.localId == legacyResource.localId && updatedResource.volumeId == legacyResource.volumeId {
                            return representation.resource
                        }
                    }
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
            for pageMedia in instantPage.media.values {
                if let result = findMediaResource(media: pageMedia, previousMedia: previousMedia, resource: resource) {
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
    case peer(peer: PeerReference)
    case wallpapers
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
    
    func message(postbox: Postbox, network: Network, background: Bool, message: MessageReference) -> Signal<Message, RevalidateMediaReferenceError> {
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
                return fetchRemoteMessage(postbox: postbox, source: source, message: message)
            }
            return signal.start(next: { value in
                if let value = value {
                    next(value)
                } else {
                    error(.generic)
                }
            }, error: { _ in
                error(.generic)
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
                return .generic
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
    
    func webPage(postbox: Postbox, network: Network, background: Bool, webPage: WebpageReference) -> Signal<TelegramMediaWebpage, RevalidateMediaReferenceError> {
        return self.genericItem(key: .webPage(webPage: webPage), background: background, request: { next, error in
            return (updatedRemoteWebpage(postbox: postbox, network: network, webPage: webPage)
            |> mapError { _ -> RevalidateMediaReferenceError in
                return .generic
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
    
    func savedGifs(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramMediaFile], RevalidateMediaReferenceError> {
        return self.genericItem(key: .savedGifs, background: background, request: { next, error in
            let loadRecentGifs: Signal<[TelegramMediaFile], NoError> = postbox.transaction { transaction -> [TelegramMediaFile] in
                return transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap({ item -> TelegramMediaFile? in
                    if let contents = item.contents as? RecentMediaItem, let file = contents.media as? TelegramMediaFile {
                        return file
                    }
                    return nil
                })
            }
            return (managedRecentGifs(postbox: postbox, network: network, forceFetch: true)
            |> mapToSignal { _ -> Signal<[TelegramMediaFile], NoError> in
                return .complete()
            }
            |> then(loadRecentGifs)
            |> introduceError(RevalidateMediaReferenceError.self)).start(next: { value in
                next(value)
            }, error: { _ in
                error(.generic)
            })
        }) |> mapToSignal { next -> Signal<[TelegramMediaFile], RevalidateMediaReferenceError> in
            if let next = next as? [TelegramMediaFile] {
                return .single(next)
            } else {
                return .fail(.generic)
            }
        }
    }
    
    func peer(postbox: Postbox, network: Network, background: Bool, peer: PeerReference) -> Signal<Peer, RevalidateMediaReferenceError> {
        return self.genericItem(key: .peer(peer: peer), background: background, request: { next, error in
            return (updatedRemotePeer(postbox: postbox, network: network, peer: peer)
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
    
    func wallpapers(postbox: Postbox, network: Network, background: Bool) -> Signal<[TelegramWallpaper], RevalidateMediaReferenceError> {
        return self.genericItem(key: .wallpapers, background: background, request: { next, error in
            return (telegramWallpapers(postbox: postbox, network: network, forceUpdate: true)
            |> last
            |> mapError { _ -> RevalidateMediaReferenceError in
                return .generic
            }).start(next: { value in
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
}

struct RevalidatedMediaResource {
    let updatedResource: TelegramMediaResource
    let updatedReference: MediaResourceReference?
}

func revalidateMediaResourceReference(postbox: Postbox, network: Network, revalidationContext: MediaReferenceRevalidationContext, info: TelegramCloudMediaResourceFetchInfo, resource: MediaResource) -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> {
    var updatedReference = info.reference
    if case let .media(media, resource) = updatedReference {
        if case let .message(_, mediaValue) = media {
            if let file = mediaValue as? TelegramMediaFile {
                if let partialReference = file.partialReference {
                    updatedReference = partialReference.mediaReference(media.media).resourceReference(resource)
                }
                if file.isSticker {
                    var stickerPackReference: StickerPackReference?
                    for attribute in file.attributes {
                        if case let .Sticker(sticker) = attribute {
                            if let packReference = sticker.packReference {
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
                    return revalidationContext.message(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, message: message)
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
                                    if let updatedResource = findUpdatedMediaResource(media: item.file, previousMedia: media, resource: resource) {
                                        return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                    }
                                }
                            }
                        }
                        return .fail(.generic)
                    }
                case let .webPage(webPage, previousMedia):
                    return revalidationContext.webPage(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, webPage: webPage)
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
                                if let updatedResource = findUpdatedMediaResource(media: file, previousMedia: media, resource: resource) {
                                    return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                                }
                            }
                        }
                        return .fail(.generic)
                    }
                case let .standalone(media):
                    if let file = media as? TelegramMediaFile {
                        for attribute in file.attributes {
                            if case let .Sticker(sticker) = attribute, let stickerPack = sticker.packReference {
                                return revalidationContext.stickerPack(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, stickerPack: stickerPack)
                                |> mapToSignal { result -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                                    for item in result.1 {
                                        if let item = item as? StickerPackItem {
                                            if media.id != nil && item.file.id == media.id {
                                                if let updatedResource = findUpdatedMediaResource(media: item.file, previousMedia: media,  resource: resource) {
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
            }
        case let .avatar(peer, _):
            return revalidationContext.peer(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, peer: peer)
            |> mapToSignal { updatedPeer -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for representation in updatedPeer.profileImageRepresentations {
                    if representation.resource.id.isEqual(to: resource.id) {
                        return .single(RevalidatedMediaResource(updatedResource: representation.resource, updatedReference: nil))
                    }
                }
                if let legacyResource = resource as? CloudFileMediaResource {
                    for representation in updatedPeer.profileImageRepresentations {
                        if let updatedResource = representation.resource as? CloudPeerPhotoSizeMediaResource {
                            if updatedResource.localId == legacyResource.localId && updatedResource.volumeId == legacyResource.volumeId {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        }
                    }
                }
                return .fail(.generic)
            }
        case let .messageAuthorAvatar(message, _):
            return revalidationContext.message(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation, message: message)
            |> mapToSignal { updatedMessage -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                guard let author = updatedMessage.author, let authorReference = PeerReference(author) else {
                    return .fail(.generic)
                }
                for representation in author.profileImageRepresentations {
                    if representation.resource.id.isEqual(to: resource.id) {
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
        case .wallpaper:
            return revalidationContext.wallpapers(postbox: postbox, network: network, background: info.preferBackgroundReferenceRevalidation)
            |> mapToSignal { wallpapers -> Signal<RevalidatedMediaResource, RevalidateMediaReferenceError> in
                for wallpaper in wallpapers {
                    switch wallpaper {
                        case let .image(representations, _):
                            for representation in representations {
                                if representation.resource.id.isEqual(to: resource.id) {
                                    return .single(RevalidatedMediaResource(updatedResource: representation.resource, updatedReference: nil))
                                }
                            }
                        case let .file(_, _, _, _, _, _, _, file, _):
                            if let updatedResource = findUpdatedMediaResource(media: file, previousMedia: nil, resource: resource) {
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
                    if thumbnail.resource.id.isEqual(to: resource.id) {
                        return .single(RevalidatedMediaResource(updatedResource: thumbnail.resource, updatedReference: nil))
                    }
                    if let legacyResource = resource as? CloudFileMediaResource {
                        if let updatedResource = thumbnail.resource as? CloudStickerPackThumbnailMediaResource {
                            if updatedResource.localId == legacyResource.localId && updatedResource.volumeId == legacyResource.volumeId {
                                return .single(RevalidatedMediaResource(updatedResource: updatedResource, updatedReference: nil))
                            }
                        }
                    }
                }
                return .fail(.generic)
            }
        case .standalone:
            return .fail(.generic)
    }
}
