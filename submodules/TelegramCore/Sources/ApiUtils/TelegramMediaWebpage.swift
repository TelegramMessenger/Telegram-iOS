
import Foundation
import Postbox
import TelegramApi


func telegramMediaWebpageAttributeFromApiWebpageAttribute(_ attribute: Api.WebPageAttribute) -> TelegramMediaWebpageAttribute? {
    switch attribute {
    case let .webPageAttributeTheme(webPageAttributeThemeData):
        let (_, documents, settings) = (webPageAttributeThemeData.flags, webPageAttributeThemeData.documents, webPageAttributeThemeData.settings)
        var files: [TelegramMediaFile] = []
        if let documents = documents {
            files = documents.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
        }
        return .theme(TelegraMediaWebpageThemeAttribute(files: files, settings: settings.flatMap { TelegramThemeSettings(apiThemeSettings: $0) }))
    case let .webPageAttributeStickerSet(webPageAttributeStickerSetData):
        let (apiFlags, stickers) = (webPageAttributeStickerSetData.flags, webPageAttributeStickerSetData.stickers)
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
    case let .webPageAttributeUniqueStarGift(webPageAttributeUniqueStarGiftData):
        let gift = webPageAttributeUniqueStarGiftData.gift
        if let starGift = StarGift(apiStarGift: gift) {
            return .starGift(TelegramMediaWebpageStarGiftAttribute(gift: starGift))
        }
        return nil
    case let .webPageAttributeStarGiftCollection(webPageAttributeStarGiftCollectionData):
        let icons = webPageAttributeStarGiftCollectionData.icons
        var files: [TelegramMediaFile] = []
        files = icons.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
        return .giftCollection(TelegramMediaWebpageGiftCollectionAttribute(files: files))
    case let .webPageAttributeStarGiftAuction(webPageAttributeStarGiftAuctionData):
        let (apiGift, endDate) = (webPageAttributeStarGiftAuctionData.gift, webPageAttributeStarGiftAuctionData.endDate)
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return .giftAuction(TelegramMediaWebpageGiftAuctionAttribute(gift: gift, endDate: endDate))
    case .webPageAttributeStory:
        return nil
    }
}

func telegramMediaWebpageFromApiWebpage(_ webpage: Api.WebPage) -> TelegramMediaWebpage? {
    switch webpage {
        case .webPageNotModified:
            return nil
        case let .webPagePending(webPagePendingData):
            let (flags, id, url, date) = (webPagePendingData.flags, webPagePendingData.id, webPagePendingData.url, webPagePendingData.date)
            let _ = flags
            return TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), content: .Pending(date, url))
        case let .webPage(webPageData):
            let (flags, id, url, displayUrl, hash, type, siteName, title, description, photo, embedUrl, embedType, embedWidth, embedHeight, duration, author, document, cachedPage, attributes) = (webPageData.flags, webPageData.id, webPageData.url, webPageData.displayUrl, webPageData.hash, webPageData.type, webPageData.siteName, webPageData.title, webPageData.description, webPageData.photo, webPageData.embedUrl, webPageData.embedType, webPageData.embedWidth, webPageData.embedHeight, webPageData.duration, webPageData.author, webPageData.document, webPageData.cachedPage, webPageData.attributes)
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
                    if case let .webPageAttributeStory(webPageAttributeStoryData) = attribute {
                        let (_, peerId, id, _) = (webPageAttributeStoryData.flags, webPageAttributeStoryData.peer, webPageAttributeStoryData.id, webPageAttributeStoryData.story)
                        story = TelegramMediaStory(storyId: StoryId(peerId: peerId.peerId, id: id), isMention: false)
                    }
                }
            }

            var instantPage: InstantPage?
            if let cachedPage = cachedPage {
                instantPage = InstantPage(apiPage: cachedPage)
            }

            let isMediaLargeByDefault = (flags & (1 << 13)) != 0
            let imageIsVideoCover = (flags & (1 << 14)) != 0

            return TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), content: .Loaded(TelegramMediaWebpageLoadedContent(url: url, displayUrl: displayUrl, hash: hash, type: type, websiteName: siteName, title: title, text: description, embedUrl: embedUrl, embedType: embedType, embedSize: embedSize, duration: webpageDuration, author: author, isMediaLargeByDefault: isMediaLargeByDefault, imageIsVideoCover: imageIsVideoCover, image: image, file: file, story: story, attributes: webpageAttributes, instantPage: instantPage)))
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
