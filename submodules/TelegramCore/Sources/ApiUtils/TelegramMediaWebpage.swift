
import Foundation
import Postbox
import TelegramApi


func telegramMediaWebpageAttributeFromApiWebpageAttribute(_ attribute: Api.WebPageAttribute) -> TelegramMediaWebpageAttribute? {
    switch attribute {
    case let .webPageAttributeTheme(_, documents, settings):
        var files: [TelegramMediaFile] = []
        if let documents = documents {
            files = documents.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
        }
        return .theme(TelegraMediaWebpageThemeAttribute(files: files, settings: settings.flatMap { TelegramThemeSettings(apiThemeSettings: $0) }))
    case let .webPageAttributeStickerSet(apiFlags, stickers):
        var flags = TelegramMediaWebpageStickerPackAttribute.Flags()
        if (apiFlags & (1 << 0)) != 0 {
            flags.insert(.isEmoji)
        }
        if (apiFlags & (1 << 1)) != 0 {
            flags.insert(.isTemplate)
        }
        var files: [TelegramMediaFile] = []
        files = stickers.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
        return .stickerPack(TelegramMediaWebpageStickerPackAttribute(flags: flags, files: files))
    case .webPageAttributeStory:
        return nil
    }
}

func telegramMediaWebpageFromApiWebpage(_ webpage: Api.WebPage) -> TelegramMediaWebpage? {
    switch webpage {
        case .webPageNotModified:
            return nil
        case let .webPagePending(flags, id, url, date):
            let _ = flags
            return TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), content: .Pending(date, url))
        case let .webPage(flags, id, url, displayUrl, hash, type, siteName, title, description, photo, embedUrl, embedType, embedWidth, embedHeight, duration, author, document, cachedPage, attributes):
            var embedSize: PixelDimensions?
            if let embedWidth = embedWidth, let embedHeight = embedHeight {
                embedSize = PixelDimensions(width: embedWidth, height: embedHeight)
            }
            var webpageDuration: Int?
            if let duration = duration {
                webpageDuration = Int(duration)
            }
            var image: TelegramMediaImage?
            if let photo = photo {
                image = telegramMediaImageFromApiPhoto(photo)
            }
            var file: TelegramMediaFile?
            if let document = document {
                file = telegramMediaFileFromApiDocument(document, altDocuments: [])
            }
            var story: TelegramMediaStory?
            var webpageAttributes: [TelegramMediaWebpageAttribute] = []
            if let attributes = attributes {
                webpageAttributes = attributes.compactMap(telegramMediaWebpageAttributeFromApiWebpageAttribute)
                for attribute in attributes {
                    if case let .webPageAttributeStory(_, peerId, id, _) = attribute {
                        story = TelegramMediaStory(storyId: StoryId(peerId: peerId.peerId, id: id), isMention: false)
                    }
                }
            }
        
            var instantPage: InstantPage?
            if let cachedPage = cachedPage {
                instantPage = InstantPage(apiPage: cachedPage)
            }
        
            let isMediaLargeByDefault = (flags & (1 << 13)) != 0
        
            return TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), content: .Loaded(TelegramMediaWebpageLoadedContent(url: url, displayUrl: displayUrl, hash: hash, type: type, websiteName: siteName, title: title, text: description, embedUrl: embedUrl, embedType: embedType, embedSize: embedSize, duration: webpageDuration, author: author, isMediaLargeByDefault: isMediaLargeByDefault, image: image, file: file, story: story, attributes: webpageAttributes, instantPage: instantPage)))
        case .webPageEmpty:
            return nil
    }
}

public class WebpagePreviewMessageAttribute: MessageAttribute, Equatable {
    public let associatedPeerIds: [PeerId] = []
    public let associatedMediaIds: [MediaId] = []
    
    public let leadingPreview: Bool
    public let forceLargeMedia: Bool?
    public let isManuallyAdded: Bool
    public let isSafe: Bool
    
    public init(leadingPreview: Bool, forceLargeMedia: Bool?, isManuallyAdded: Bool, isSafe: Bool) {
        self.leadingPreview = leadingPreview
        self.forceLargeMedia = forceLargeMedia
        self.isManuallyAdded = isManuallyAdded
        self.isSafe = isSafe
    }
    
    required public init(decoder: PostboxDecoder) {
        self.leadingPreview = decoder.decodeBoolForKey("lp", orElse: false)
        self.forceLargeMedia = decoder.decodeOptionalBoolForKey("lm")
        self.isManuallyAdded = decoder.decodeBoolForKey("ma", orElse: false)
        self.isSafe = decoder.decodeBoolForKey("sf", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.leadingPreview, forKey: "lp")
        if let forceLargeMedia = self.forceLargeMedia {
            encoder.encodeBool(forceLargeMedia, forKey: "lm")
        } else {
            encoder.encodeNil(forKey: "lm")
        }
        encoder.encodeBool(self.isManuallyAdded, forKey: "ma")
        encoder.encodeBool(self.isSafe, forKey: "sf")
    }
    
    public static func ==(lhs: WebpagePreviewMessageAttribute, rhs: WebpagePreviewMessageAttribute) -> Bool {
        if lhs.leadingPreview != rhs.leadingPreview {
            return false
        }
        if lhs.forceLargeMedia != rhs.forceLargeMedia {
            return false
        }
        if lhs.isManuallyAdded != rhs.isManuallyAdded {
            return false
        }
        if lhs.isSafe != rhs.isSafe {
            return false
        }
        return true
    }
}
