import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private enum InstantPageBlockType: Int32 {
    case unsupported = 0
    case title = 1
    case subtitle = 2
    case authorDate = 3
    case header = 4
    case subheader = 5
    case paragraph = 6
    case preformatted = 7
    case footer = 8
    case divider = 9
    case anchor = 10
    case list = 11
    case blockQuote = 12
    case pullQuote = 13
    case image = 14
    case video = 15
    case cover = 16
    case webEmbed = 17
    case postEmbed = 18
    case collage = 19
    case slideshow = 20
}

public indirect enum InstantPageBlock: Coding, Equatable {
    case unsupported
    case title(RichText)
    case subtitle(RichText)
    case authorDate(author: RichText, date: Int32)
    case header(RichText)
    case subheader(RichText)
    case paragraph(RichText)
    case preformatted(RichText)
    case footer(RichText)
    case divider
    case anchor(String)
    case list(items: [RichText], ordered: Bool)
    case blockQuote(text: RichText, caption: RichText)
    case pullQuote(text: RichText, caption: RichText)
    case image(id: MediaId, caption: RichText)
    case video(id: MediaId, caption: RichText, autoplay: Bool, loop: Bool)
    case cover(InstantPageBlock)
    case webEmbed(url: String?, html: String?, dimensions: CGSize, caption: RichText, stretchToWidth: Bool, allowScrolling: Bool)
    case postEmbed(url: String, webpageId: MediaId?, avatarId: MediaId?, author: String, date: Int32, blocks: [InstantPageBlock], caption: RichText)
    case collage(items: [InstantPageBlock], caption: RichText)
    case slideshow(items: [InstantPageBlock], caption: RichText)
    
    public init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case InstantPageBlockType.unsupported.rawValue:
                self = .unsupported
            case InstantPageBlockType.title.rawValue:
                self = .title(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.subtitle.rawValue:
                self = .subtitle(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.authorDate.rawValue:
                self = .authorDate(author: decoder.decodeObjectForKey("a", decoder: { RichText(decoder: $0) }) as! RichText, date: decoder.decodeInt32ForKey("d"))
            case InstantPageBlockType.header.rawValue:
                self = .header(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.subheader.rawValue:
                self = .subheader(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.paragraph.rawValue:
                self = .paragraph(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.preformatted.rawValue:
                self = .preformatted(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.footer.rawValue:
                self = .footer(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.divider.rawValue:
                self = .divider
            case InstantPageBlockType.anchor.rawValue:
                self = .anchor(decoder.decodeStringForKey("s"))
            case InstantPageBlockType.list.rawValue:
                self = .list(items: decoder.decodeObjectArrayWithDecoderForKey("l"), ordered: decoder.decodeInt32ForKey("o") != 0)
            case InstantPageBlockType.blockQuote.rawValue:
                self = .blockQuote(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.pullQuote.rawValue:
                self = .pullQuote(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.image.rawValue:
                self = .image(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt64ForKey("i.i")), caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.video.rawValue:
                self = .video(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt64ForKey("i.i")), caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText, autoplay: decoder.decodeInt32ForKey("ap") != 0, loop: decoder.decodeInt32ForKey("lo") != 0)
            case InstantPageBlockType.cover.rawValue:
                self = .cover(decoder.decodeObjectForKey("c", decoder: { InstantPageBlock(decoder: $0) }) as! InstantPageBlock)
            case InstantPageBlockType.webEmbed.rawValue:
                self = .webEmbed(url: decoder.decodeStringForKey("u"), html: decoder.decodeStringForKey("h"), dimensions: CGSize(width: CGFloat(decoder.decodeInt32ForKey("sw")), height: CGFloat(decoder.decodeInt32ForKey("sh"))), caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText, stretchToWidth: decoder.decodeInt32ForKey("st") != 0, allowScrolling: decoder.decodeInt32ForKey("as") != 0)
            case InstantPageBlockType.postEmbed.rawValue:
                var avatarId: MediaId?
                let avatarIdNamespace: Int32? = decoder.decodeInt32ForKey("av.n")
                let avatarIdId: Int64? = decoder.decodeInt64ForKey("av.i")
                if let avatarIdNamespace = avatarIdNamespace, let avatarIdId = avatarIdId {
                    avatarId = MediaId(namespace: avatarIdNamespace, id: avatarIdId)
                }
                self = .postEmbed(url: decoder.decodeStringForKey("u"), webpageId: MediaId(namespace: decoder.decodeInt32ForKey("w.n"), id: decoder.decodeInt64ForKey("w.i")), avatarId: avatarId, author: decoder.decodeStringForKey("a"), date: decoder.decodeInt32ForKey("d"), blocks: decoder.decodeObjectArrayWithDecoderForKey("b"), caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.collage.rawValue:
                self = .collage(items: decoder.decodeObjectArrayWithDecoderForKey("b"), caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.slideshow.rawValue:
                self = .slideshow(items: decoder.decodeObjectArrayWithDecoderForKey("b"), caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            default:
                self = .unsupported
        }
    }
    
    public func encode(_ encoder: Encoder) {
        switch self {
            case .unsupported:
                encoder.encodeInt32(InstantPageBlockType.unsupported.rawValue, forKey: "r")
            case let .title(text):
                encoder.encodeInt32(InstantPageBlockType.title.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .subtitle(text):
                encoder.encodeInt32(InstantPageBlockType.subtitle.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .authorDate(author, date):
                encoder.encodeInt32(InstantPageBlockType.authorDate.rawValue, forKey: "r")
                encoder.encodeObject(author, forKey: "a")
                encoder.encodeInt32(date, forKey: "d")
            case let .header(text):
                encoder.encodeInt32(InstantPageBlockType.header.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .subheader(text):
                encoder.encodeInt32(InstantPageBlockType.subheader.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .paragraph(text):
                encoder.encodeInt32(InstantPageBlockType.paragraph.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .preformatted(text):
                encoder.encodeInt32(InstantPageBlockType.preformatted.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .footer(text):
                encoder.encodeInt32(InstantPageBlockType.footer.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case .divider:
                encoder.encodeInt32(InstantPageBlockType.divider.rawValue, forKey: "r")
            case let .anchor(anchor):
                encoder.encodeInt32(InstantPageBlockType.anchor.rawValue, forKey: "r")
                encoder.encodeString(anchor, forKey: "s")
            case let .list(items, ordered):
                encoder.encodeInt32(InstantPageBlockType.list.rawValue, forKey: "r")
                encoder.encodeObjectArray(items, forKey: "l")
                encoder.encodeInt32(ordered ? 1 : 0, forKey: "o")
            case let .blockQuote(text, caption):
                encoder.encodeInt32(InstantPageBlockType.blockQuote.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeObject(caption, forKey: "c")
            case let .pullQuote(text, caption):
                encoder.encodeInt32(InstantPageBlockType.pullQuote.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeObject(caption, forKey: "c")
            case let .image(id, caption):
                encoder.encodeInt32(InstantPageBlockType.image.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "c")
            case let .video(id, caption, autoplay, loop):
                encoder.encodeInt32(InstantPageBlockType.video.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "c")
                encoder.encodeInt32(autoplay ? 1 : 0, forKey: "ap")
                encoder.encodeInt32(loop ? 1 : 0, forKey: "lo")
            case let .cover(block):
                encoder.encodeInt32(InstantPageBlockType.cover.rawValue, forKey: "r")
                encoder.encodeObject(block, forKey: "c")
            case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling):
                encoder.encodeInt32(InstantPageBlockType.webEmbed.rawValue, forKey: "r")
                if let url = url {
                    encoder.encodeString(url, forKey: "u")
                } else {
                    encoder.encodeNil(forKey: "u")
                }
                if let html = html {
                    encoder.encodeString(html, forKey: "h")
                } else {
                    encoder.encodeNil(forKey: "h")
                }
                encoder.encodeInt32(Int32(dimensions.width), forKey: "sw")
                encoder.encodeInt32(Int32(dimensions.height), forKey: "sh")
                encoder.encodeObject(caption, forKey: "c")
                encoder.encodeInt32(stretchToWidth ? 1 : 0, forKey: "st")
                encoder.encodeInt32(allowScrolling ? 1 : 0, forKey: "as")
            case let .postEmbed(url, webpageId, avatarId, author, date, blocks, caption):
                encoder.encodeInt32(InstantPageBlockType.postEmbed.rawValue, forKey: "r")
                if let avatarId = avatarId {
                    encoder.encodeInt32(avatarId.namespace, forKey: "av.n")
                    encoder.encodeInt64(avatarId.id, forKey: "av.i")
                } else {
                    encoder.encodeNil(forKey: "av.n")
                    encoder.encodeNil(forKey: "av.i")
                }
                encoder.encodeString(url, forKey: "u")
                if let webpageId = webpageId {
                    encoder.encodeInt32(webpageId.namespace, forKey: "w.n")
                    encoder.encodeInt64(webpageId.id, forKey: "w.i")
                } else {
                    encoder.encodeNil(forKey: "w.n")
                    encoder.encodeNil(forKey: "w.i")
                }
                encoder.encodeString(author, forKey: "a")
                encoder.encodeInt32(date, forKey: "d")
                encoder.encodeObjectArray(blocks, forKey: "b")
                encoder.encodeObject(caption, forKey: "c")
            case let .collage(items, caption):
                encoder.encodeInt32(InstantPageBlockType.collage.rawValue, forKey: "r")
                encoder.encodeObjectArray(items, forKey: "b")
                encoder.encodeObject(caption, forKey: "c")
            case let .slideshow(items, caption):
                encoder.encodeInt32(InstantPageBlockType.slideshow.rawValue, forKey: "r")
                encoder.encodeObjectArray(items, forKey: "b")
                encoder.encodeObject(caption, forKey: "c")
        }
    }
    
    public static func ==(lhs: InstantPageBlock, rhs: InstantPageBlock) -> Bool {
        switch lhs {
            case .unsupported:
                if case .unsupported = rhs {
                    return true
                } else {
                    return false
                }
            case let .title(text):
                if case .title(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .subtitle(text):
                if case .subtitle(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .authorDate(author, date):
                if case .authorDate(author, date) = rhs {
                    return true
                } else {
                    return false
                }
            case let .header(text):
                if case .header(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .subheader(text):
                if case .subheader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .paragraph(text):
                if case .paragraph(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .preformatted(text):
                if case .preformatted(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .footer(text):
                if case .footer(text) = rhs {
                    return true
                } else {
                    return false
                }
            case .divider:
                if case .divider = rhs {
                    return true
                } else {
                    return false
                }
            case let .anchor(anchor):
                if case .anchor(anchor) = rhs {
                    return true
                } else {
                    return false
                }
            case let .list(lhsItems, lhsOrdered):
                if case let .list(rhsItems, rhsOrdered) = rhs, lhsItems == rhsItems, lhsOrdered == rhsOrdered {
                    return true
                } else {
                    return false
                }
            case let .blockQuote(text, caption):
                if case .blockQuote(text, caption) = rhs {
                    return true
                } else {
                    return false
                }
            case let .pullQuote(text, caption):
                if case .pullQuote(text, caption) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(id, caption):
                if case .image(id, caption) = rhs {
                    return true
                } else {
                    return false
                }
            case let .video(id, caption, autoplay, loop):
                if case .video(id, caption, autoplay, loop) = rhs {
                    return true
                } else {
                    return false
                }
            case let .cover(block):
                if case .cover(block) = rhs {
                    return true
                } else {
                    return false
                }
            case let .webEmbed(lhsUrl, lhsHtml, lhsDimensions, lhsCaption, lhsStretchToWidth, lhsAllowScrolling):
                if case let .webEmbed(rhsUrl, rhsHtml, rhsDimensions, rhsCaption, rhsStretchToWidth, rhsAllowScrolling) = rhs, lhsUrl == rhsUrl && lhsHtml == rhsHtml && lhsDimensions == rhsDimensions && lhsCaption == rhsCaption && lhsStretchToWidth == rhsStretchToWidth && lhsAllowScrolling == rhsAllowScrolling {
                    return true
                } else {
                    return false
                }
            case let .postEmbed(lhsUrl, lhsWebpageId, lhsAvatarId, lhsAuthor, lhsDate, lhsBlocks, lhsCaption):
                if case let .postEmbed(rhsUrl, rhsWebpageId, rhsAvatarId, rhsAuthor, rhsDate, rhsBlocks, rhsCaption) = rhs, lhsUrl == rhsUrl && lhsWebpageId == rhsWebpageId && lhsAvatarId == rhsAvatarId && lhsAuthor == rhsAuthor && lhsDate == rhsDate && lhsBlocks == rhsBlocks && lhsCaption == rhsCaption {
                    return true
                } else {
                    return false
                }
            case let .collage(lhsItems, lhsCaption):
                if case let .collage(rhsItems, rhsCaption) = rhs, lhsItems == rhsItems && lhsCaption == rhsCaption {
                    return true
                } else {
                    return false
                }
            case let .slideshow(lhsItems, lhsCaption):
                if case let .slideshow(rhsItems, rhsCaption) = rhs, lhsItems == rhsItems && lhsCaption == rhsCaption {
                    return true
                } else {
                    return false
                }
            }
    }
}

private final class MediaDictionary: Coding {
    let dict: [MediaId: Media]
    
    init(dict: [MediaId: Media]) {
        self.dict = dict
    }
    
    init(decoder: Decoder) {
        let idsBufer = decoder.decodeBytesForKey("i")!
        let mediaIds = MediaId.decodeArrayFromBuffer(idsBufer)
        let medias = decoder.decodeObjectArrayForKey("m")
        var dict: [MediaId: Media] = [:]
        assert(mediaIds.count == medias.count)
        for i in 0 ..< mediaIds.count {
            dict[mediaIds[i]] = medias[i] as! Media
        }
        self.dict = dict
    }
    
    func encode(_ encoder: Encoder) {
        var mediaIds: [MediaId] = []
        var medias: [Coding] = []
        for mediaId in self.dict.keys {
            mediaIds.append(mediaId)
            medias.append(self.dict[mediaId]!)
        }
        let buffer = WriteBuffer()
        MediaId.encodeArrayToBuffer(mediaIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeGenericObjectArray(medias, forKey: "m")
    }
}

public final class InstantPage: Coding, Equatable {
    public let blocks: [InstantPageBlock]
    public let media: [MediaId: Media]
    public let isComplete: Bool
    
    init(blocks: [InstantPageBlock], media: [MediaId: Media], isComplete: Bool) {
        self.blocks = blocks
        self.media = media
        self.isComplete = isComplete
    }
    
    public init(decoder: Decoder) {
        self.blocks = decoder.decodeObjectArrayWithDecoderForKey("b")
        self.media = MediaDictionary(decoder: decoder).dict
        self.isComplete = decoder.decodeInt32ForKey("c") != 0
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObjectArray(self.blocks, forKey: "b")
        MediaDictionary(dict: self.media).encode(encoder)
        encoder.encodeInt32(self.isComplete ? 1 : 0, forKey: "c")
    }
    
    public static func ==(lhs: InstantPage, rhs: InstantPage) -> Bool {
        if lhs.blocks != rhs.blocks {
            return false
        }
        
        if lhs.media.count != rhs.media.count {
            return false
        } else {
            for (lhsKey, lhsValue) in lhs.media {
                if let media = rhs.media[lhsKey] {
                    if !lhsValue.isEqual(media) {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        
        if lhs.isComplete != rhs.isComplete {
            return false
        }
        return true
    }
}

extension InstantPageBlock {
    init(apiBlock: Api.PageBlock) {
        switch apiBlock {
            case .pageBlockUnsupported:
                self = .unsupported
            case let .pageBlockTitle(text):
                self = .title(RichText(apiText: text))
            case let .pageBlockSubtitle(text):
                self = .subtitle(RichText(apiText: text))
            case let .pageBlockAuthorDate(author, publishedDate):
                self = .authorDate(author: .plain(author), date: publishedDate)
            case let .pageBlockHeader(text):
                self = .header(RichText(apiText: text))
            case let .pageBlockSubheader(text):
                self = .subheader(RichText(apiText: text))
            case let .pageBlockParagraph(text):
                self = .paragraph(RichText(apiText: text))
            case let .pageBlockPreformatted(text, _):
                self = .preformatted(RichText(apiText: text))
            case let .pageBlockFooter(text):
                self = .footer(RichText(apiText: text))
            case .pageBlockDivider:
                self = .divider
            case let .pageBlockAnchor(name):
                self = .anchor(name)
            case let .pageBlockList(ordered, items):
                self = .list(items: items.map({ RichText(apiText: $0) }), ordered: ordered == .boolTrue)
            case let .pageBlockBlockquote(text, caption):
                self = .blockQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPullquote(text, caption):
                self = .pullQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPhoto(photoId, caption):
                self = .image(id: MediaId(namespace: Namespaces.Media.CloudImage, id: photoId), caption: RichText(apiText: caption))
            case let .pageBlockVideo(flags, videoId, caption):
                self = .video(id: MediaId(namespace: Namespaces.Media.CloudVideo, id: videoId), caption: RichText(apiText: caption), autoplay: (flags & (1 << 0)) != 0, loop: (flags & (1 << 1)) != 0)
            case let .pageBlockCover(cover):
                self = .cover(InstantPageBlock(apiBlock: cover))
            case let .pageBlockEmbed(flags, url, html, w, h, caption):
                self = .webEmbed(url: url, html: html, dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), caption: RichText(apiText: caption), stretchToWidth: (flags & (1 << 0)) != 0, allowScrolling: (flags & (1 << 3)) != 0)
            case let .pageBlockEmbedPost(url, webpageId, authorPhotoId, author, date, blocks, caption):
                self = .postEmbed(url: url, webpageId: webpageId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId), avatarId: authorPhotoId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudImage, id: authorPhotoId), author: author, date: date, blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), caption: RichText(apiText: caption))
            case let .pageBlockCollage(items, caption):
                self = .collage(items: items.map({ InstantPageBlock(apiBlock: $0) }), caption: RichText(apiText: caption))
            case let .pageBlockSlideshow(items, caption):
                self = .slideshow(items: items.map({ InstantPageBlock(apiBlock: $0) }), caption: RichText(apiText: caption))
        }
    }
}

extension InstantPage {
    convenience init(apiPage: Api.Page) {
        let blocks: [Api.PageBlock]
        let photos: [Api.Photo]
        let files: [Api.Document]
        let isComplete: Bool
        switch apiPage {
            case let .pageFull(apiBlocks, apiPhotos, apiVideos):
                blocks = apiBlocks
                photos = apiPhotos
                files = apiVideos
                isComplete = true
            case let .pagePart(apiBlocks, apiPhotos, apiVideos):
                blocks = apiBlocks
                photos = apiPhotos
                files = apiVideos
                isComplete = false
        }
        var media: [MediaId: Media] = [:]
        for photo in photos {
            if let image = telegramMediaImageFromApiPhoto(photo), let id = image.id {
                media[id] = image
            }
        }
        for file in files {
            if let file = telegramMediaFileFromApiDocument(file), let id = file.id {
                media[id] = file
            }
        }
        self.init(blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), media: media, isComplete: isComplete)
    }
}
