import Postbox

public struct MessageReference: PostboxCoding, Hashable, Equatable {
    public let content: MessageReferenceContent
    
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

public enum MessageReferenceContent: PostboxCoding, Hashable, Equatable {
    case none
    case message(peer: PeerReference, id: MessageId, timestamp: Int32, incoming: Bool, secret: Bool)
    
    public init(decoder: PostboxDecoder) {
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
    
    public func encode(_ encoder: PostboxEncoder) {
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
    public let content: WebpageReferenceContent
    
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

public enum WebpageReferenceContent: PostboxCoding, Hashable, Equatable {
    case none
    case webPage(id: Int64, url: String)
    
    public init(decoder: PostboxDecoder) {
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
    
    public func encode(_ encoder: PostboxEncoder) {
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

public enum ThemeReference: PostboxCoding, Hashable, Equatable {
    case slug(String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .slug(decoder.decodeStringForKey("s", orElse: ""))
            default:
                self = .slug("")
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .slug(slug):
                encoder.encodeInt32(0, forKey: "r")
                encoder.encodeString(slug, forKey: "s")
        }
    }
    
    public static func ==(lhs: ThemeReference, rhs: ThemeReference) -> Bool {
        switch lhs {
            case let .slug(slug):
                if case .slug(slug) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum WallpaperReference: PostboxCoding, Hashable, Equatable {
    case slug(String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case 0:
                self = .slug(decoder.decodeStringForKey("s", orElse: ""))
            default:
                self = .slug("")
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .slug(slug):
                encoder.encodeInt32(0, forKey: "r")
                encoder.encodeString(slug, forKey: "s")
        }
    }
    
    public static func ==(lhs: WallpaperReference, rhs: WallpaperReference) -> Bool {
        switch lhs {
            case let .slug(slug):
                if case .slug(slug) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum AnyMediaReference: Equatable {
    case standalone(media: Media)
    case message(message: MessageReference, media: Media)
    case webPage(webPage: WebpageReference, media: Media)
    case stickerPack(stickerPack: StickerPackReference, media: Media)
    case savedGif(media: Media)
    case avatarList(peer: PeerReference, media: Media)
    
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
            case let .avatarList(lhsPeer, lhsMedia):
                if case let .avatarList(rhsPeer, rhsMedia) = rhs, lhsPeer == rhsPeer, lhsMedia.isEqual(to: rhsMedia) {
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
            case let .avatarList(peer, media):
                return nil
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
            case let .avatarList(peer, media):
                if let media = media as? T {
                    return .avatarList(peer: peer, media: media)
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
            case let .avatarList(_, media):
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
    
    public init?(decoder: PostboxDecoder) {
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
    
    public func encode(_ encoder: PostboxEncoder) {
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
    
    public func mediaReference(_ media: Media) -> AnyMediaReference {
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
        case avatarList
    }
    
    case standalone(media: T)
    case message(message: MessageReference, media: T)
    case webPage(webPage: WebpageReference, media: T)
    case stickerPack(stickerPack: StickerPackReference, media: T)
    case savedGif(media: T)
    case avatarList(peer: PeerReference, media: T)
    
    public init?(decoder: PostboxDecoder) {
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
            case .avatarList:
                let peer = decoder.decodeObjectForKey("pr", decoder: { StickerPackReference(decoder: $0) }) as! PeerReference
                guard let media = decoder.decodeObjectForKey("m") as? T else {
                    return nil
                }
                self = .avatarList(peer: peer, media: media)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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
            case let .avatarList(peer, media):
                encoder.encodeInt32(CodingCase.avatarList.rawValue, forKey: "_r")
                encoder.encodeObject(peer, forKey: "pr")
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
            case let .avatarList(peer, media):
                return .avatarList(peer: peer, media: media)
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
            case let .avatarList(_, media):
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
    case avatarList(peer: PeerReference, resource: MediaResource)
    case messageAuthorAvatar(message: MessageReference, resource: MediaResource)
    case wallpaper(wallpaper: WallpaperReference?, resource: MediaResource)
    case stickerPackThumbnail(stickerPack: StickerPackReference, resource: MediaResource)
    case theme(theme: ThemeReference, resource: MediaResource)
    
    public var resource: MediaResource {
        switch self {
            case let .media(_, resource):
                return resource
            case let .standalone(resource):
                return resource
            case let .avatar(_, resource):
                return resource
            case let .avatarList(_, resource):
                return resource
            case let .messageAuthorAvatar(_, resource):
                return resource
            case let .wallpaper(_, resource):
                return resource
            case let .stickerPackThumbnail(_, resource):
                return resource
            case let .theme(_, resource):
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
        case let .avatarList(lhsPeer, lhsResource):
            if case let .avatarList(rhsPeer, rhsResource) = rhs, lhsPeer == rhsPeer, lhsResource.isEqual(to: rhsResource) {
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
        case let .wallpaper(lhsWallpaper, lhsResource):
            if case let .wallpaper(rhsWallpaper, rhsResource) = rhs, lhsWallpaper == rhsWallpaper, lhsResource.isEqual(to: rhsResource) {
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
        case let .theme(lhsTheme, lhsResource):
            if case let .theme(rhsTheme, rhsResource) = rhs, lhsTheme == rhsTheme, lhsResource.isEqual(to: rhsResource) {
                return true
            } else {
                return false
            }
        }
    }
}
