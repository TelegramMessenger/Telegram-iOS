import Postbox

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
    case channelBanner = 21
    case audio = 22
    case kicker = 23
    case table = 24
    case details = 25
    case relatedArticles = 26
    case map = 27
}

private func decodeListItems(_ decoder: PostboxDecoder) -> [InstantPageListItem] {
    let legacyItems: [RichText] = decoder.decodeObjectArrayWithDecoderForKey("l") 
    if !legacyItems.isEmpty {
        var items: [InstantPageListItem] = []
        for item in legacyItems {
            items.append(.text(item, nil))
        }
        return items
    }
    return decoder.decodeObjectArrayWithDecoderForKey("ml")
}

private func decodeCaption(_ decoder: PostboxDecoder) -> InstantPageCaption {
    if let legacyCaption = decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as? RichText {
        return InstantPageCaption(text: legacyCaption, credit: .empty)
    }
    return decoder.decodeObjectForKey("mc", decoder: { InstantPageCaption(decoder: $0) }) as! InstantPageCaption
}

public indirect enum InstantPageBlock: PostboxCoding, Equatable {
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
    case list(items: [InstantPageListItem], ordered: Bool)
    case blockQuote(text: RichText, caption: RichText)
    case pullQuote(text: RichText, caption: RichText)
    case image(id: MediaId, caption: InstantPageCaption, url: String?, webpageId: MediaId?)
    case video(id: MediaId, caption: InstantPageCaption, autoplay: Bool, loop: Bool)
    case audio(id: MediaId, caption: InstantPageCaption)
    case cover(InstantPageBlock)
    case webEmbed(url: String?, html: String?, dimensions: PixelDimensions?, caption: InstantPageCaption, stretchToWidth: Bool, allowScrolling: Bool, coverId: MediaId?)
    case postEmbed(url: String, webpageId: MediaId?, avatarId: MediaId?, author: String, date: Int32, blocks: [InstantPageBlock], caption: InstantPageCaption)
    case collage(items: [InstantPageBlock], caption: InstantPageCaption)
    case slideshow(items: [InstantPageBlock], caption: InstantPageCaption)
    case channelBanner(TelegramChannel?)
    case kicker(RichText)
    case table(title: RichText, rows: [InstantPageTableRow], bordered: Bool, striped: Bool)
    case details(title: RichText, blocks: [InstantPageBlock], expanded: Bool)
    case relatedArticles(title: RichText, articles: [InstantPageRelatedArticle])
    case map(latitude: Double, longitude: Double, zoom: Int32, dimensions: PixelDimensions, caption: InstantPageCaption)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case InstantPageBlockType.unsupported.rawValue:
                self = .unsupported
            case InstantPageBlockType.title.rawValue:
                self = .title(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.subtitle.rawValue:
                self = .subtitle(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.authorDate.rawValue:
                self = .authorDate(author: decoder.decodeObjectForKey("a", decoder: { RichText(decoder: $0) }) as! RichText, date: decoder.decodeInt32ForKey("d", orElse: 0))
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
                self = .anchor(decoder.decodeStringForKey("s", orElse: ""))
            case InstantPageBlockType.list.rawValue:
                self = .list(items: decodeListItems(decoder), ordered: decoder.decodeOptionalInt32ForKey("o") != 0)
            case InstantPageBlockType.blockQuote.rawValue:
                self = .blockQuote(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.pullQuote.rawValue:
                self = .pullQuote(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.image.rawValue:
                var webpageId: MediaId?
                if let webpageIdNamespace = decoder.decodeOptionalInt32ForKey("wi.n"), let webpageIdId = decoder.decodeOptionalInt64ForKey("wi.i") {
                    webpageId = MediaId(namespace: webpageIdNamespace, id: webpageIdId)
                }
                self = .image(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), caption: decodeCaption(decoder), url: decoder.decodeOptionalStringForKey("u"), webpageId: webpageId)
            case InstantPageBlockType.video.rawValue:
                self = .video(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), caption: decodeCaption(decoder), autoplay: decoder.decodeInt32ForKey("ap", orElse: 0) != 0, loop: decoder.decodeInt32ForKey("lo", orElse: 0) != 0)
            case InstantPageBlockType.cover.rawValue:
                self = .cover(decoder.decodeObjectForKey("c", decoder: { InstantPageBlock(decoder: $0) }) as! InstantPageBlock)
            case InstantPageBlockType.webEmbed.rawValue:
                var coverId: MediaId?
                if let coverIdNamespace = decoder.decodeOptionalInt32ForKey("ci.n"), let coverIdId = decoder.decodeOptionalInt64ForKey("ci.i") {
                    coverId = MediaId(namespace: coverIdNamespace, id: coverIdId)
                }
                var dimensions: PixelDimensions?
                if let width = decoder.decodeOptionalInt32ForKey("sw"), let height = decoder.decodeOptionalInt32ForKey("sh") {
                    dimensions = PixelDimensions(width: width, height: height)
                }
                self = .webEmbed(url: decoder.decodeOptionalStringForKey("u"), html: decoder.decodeOptionalStringForKey("h"), dimensions: dimensions, caption: decodeCaption(decoder), stretchToWidth: decoder.decodeInt32ForKey("st", orElse: 0) != 0, allowScrolling: decoder.decodeInt32ForKey("as", orElse: 0) != 0, coverId: coverId)
            case InstantPageBlockType.postEmbed.rawValue:
                var avatarId: MediaId?
                let avatarIdNamespace: Int32? = decoder.decodeOptionalInt32ForKey("av.n")
                let avatarIdId: Int64? = decoder.decodeOptionalInt64ForKey("av.i")
                if let avatarIdNamespace = avatarIdNamespace, let avatarIdId = avatarIdId {
                    avatarId = MediaId(namespace: avatarIdNamespace, id: avatarIdId)
                }
                self = .postEmbed(url: decoder.decodeStringForKey("u", orElse: ""), webpageId: MediaId(namespace: decoder.decodeInt32ForKey("w.n", orElse: 0), id: decoder.decodeInt64ForKey("w.i", orElse: 0)), avatarId: avatarId, author: decoder.decodeStringForKey("a", orElse: ""), date: decoder.decodeInt32ForKey("d", orElse: 0), blocks: decoder.decodeObjectArrayWithDecoderForKey("b"), caption: decodeCaption(decoder))
            case InstantPageBlockType.collage.rawValue:
                self = .collage(items: decoder.decodeObjectArrayWithDecoderForKey("b"), caption: decodeCaption(decoder))
            case InstantPageBlockType.slideshow.rawValue:
                self = .slideshow(items: decoder.decodeObjectArrayWithDecoderForKey("b"), caption: decodeCaption(decoder))
            case InstantPageBlockType.channelBanner.rawValue:
                self = .channelBanner(decoder.decodeObjectForKey("c") as? TelegramChannel)
            case InstantPageBlockType.audio.rawValue:
                self = .audio(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), caption: decodeCaption(decoder))
            case InstantPageBlockType.kicker.rawValue:
                self = .kicker(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.table.rawValue:
                self = .table(title: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, rows: decoder.decodeObjectArrayWithDecoderForKey("r"), bordered: decoder.decodeInt32ForKey("b", orElse: 0) != 0, striped: decoder.decodeInt32ForKey("s", orElse: 0) != 0)
            case InstantPageBlockType.details.rawValue:
                self = .details(title: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, blocks: decoder.decodeObjectArrayWithDecoderForKey("b"), expanded: decoder.decodeInt32ForKey("o", orElse: 0) != 0)
            case InstantPageBlockType.relatedArticles.rawValue:
                self = .relatedArticles(title: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, articles: decoder.decodeObjectArrayWithDecoderForKey("a"))
            case InstantPageBlockType.map.rawValue:
                self = .map(latitude: decoder.decodeDoubleForKey("lat", orElse: 0.0), longitude: decoder.decodeDoubleForKey("lon", orElse: 0.0), zoom: decoder.decodeInt32ForKey("z", orElse: 0), dimensions: PixelDimensions(width: decoder.decodeInt32ForKey("sw", orElse: 0), height: decoder.decodeInt32ForKey("sh", orElse: 0)), caption: decodeCaption(decoder))
            default:
                self = .unsupported
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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
                encoder.encodeObjectArray(items, forKey: "ml")
                encoder.encodeInt32(ordered ? 1 : 0, forKey: "o")
            case let .blockQuote(text, caption):
                encoder.encodeInt32(InstantPageBlockType.blockQuote.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeObject(caption, forKey: "c")
            case let .pullQuote(text, caption):
                encoder.encodeInt32(InstantPageBlockType.pullQuote.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeObject(caption, forKey: "c")
            case let .image(id, caption, url, webpageId):
                encoder.encodeInt32(InstantPageBlockType.image.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "mc")
                if let url = url {
                    encoder.encodeString(url, forKey: "u")
                } else {
                    encoder.encodeNil(forKey: "u")
                }
                if let webpageId = webpageId {
                    encoder.encodeInt32(webpageId.namespace, forKey: "wi.n")
                    encoder.encodeInt64(webpageId.id, forKey: "wi.i")
                } else {
                    encoder.encodeNil(forKey: "wi.n")
                    encoder.encodeNil(forKey: "wi.i")
                }
            case let .video(id, caption, autoplay, loop):
                encoder.encodeInt32(InstantPageBlockType.video.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "mc")
                encoder.encodeInt32(autoplay ? 1 : 0, forKey: "ap")
                encoder.encodeInt32(loop ? 1 : 0, forKey: "lo")
            case let .cover(block):
                encoder.encodeInt32(InstantPageBlockType.cover.rawValue, forKey: "r")
                encoder.encodeObject(block, forKey: "c")
            case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling, coverId):
                encoder.encodeInt32(InstantPageBlockType.webEmbed.rawValue, forKey: "r")
                if let coverId = coverId {
                    encoder.encodeInt32(coverId.namespace, forKey: "ci.n")
                    encoder.encodeInt64(coverId.id, forKey: "ci.i")
                } else {
                    encoder.encodeNil(forKey: "ci.n")
                    encoder.encodeNil(forKey: "ci.i")
                }
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
                if let dimensions = dimensions {
                    encoder.encodeInt32(Int32(dimensions.width), forKey: "sw")
                    encoder.encodeInt32(Int32(dimensions.height), forKey: "sh")
                } else {
                    encoder.encodeNil(forKey: "sw")
                    encoder.encodeNil(forKey: "sh")
                }
                encoder.encodeObject(caption, forKey: "mc")
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
                encoder.encodeObject(caption, forKey: "mc")
            case let .collage(items, caption):
                encoder.encodeInt32(InstantPageBlockType.collage.rawValue, forKey: "r")
                encoder.encodeObjectArray(items, forKey: "b")
                encoder.encodeObject(caption, forKey: "mc")
            case let .slideshow(items, caption):
                encoder.encodeInt32(InstantPageBlockType.slideshow.rawValue, forKey: "r")
                encoder.encodeObjectArray(items, forKey: "b")
                encoder.encodeObject(caption, forKey: "mc")
            case let .channelBanner(channel):
                encoder.encodeInt32(InstantPageBlockType.channelBanner.rawValue, forKey: "r")
                if let channel = channel {
                    encoder.encodeObject(channel, forKey: "c")
                } else {
                    encoder.encodeNil(forKey: "c")
                }
            case let .audio(id, caption):
                encoder.encodeInt32(InstantPageBlockType.audio.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "mc")
            case let .kicker(text):
                encoder.encodeInt32(InstantPageBlockType.kicker.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .table(title, rows, bordered, striped):
                encoder.encodeInt32(InstantPageBlockType.table.rawValue, forKey: "r")
                encoder.encodeObject(title, forKey: "t")
                encoder.encodeObjectArray(rows, forKey: "r")
                encoder.encodeInt32(bordered ? 1 : 0, forKey: "b")
                encoder.encodeInt32(striped ? 1 : 0, forKey: "s")
            case let .details(title, blocks, expanded):
                encoder.encodeInt32(InstantPageBlockType.details.rawValue, forKey: "r")
                encoder.encodeObject(title, forKey: "t")
                encoder.encodeObjectArray(blocks, forKey: "b")
                encoder.encodeInt32(expanded ? 1 : 0, forKey: "o")
            case let .relatedArticles(title, articles):
                encoder.encodeInt32(InstantPageBlockType.relatedArticles.rawValue, forKey: "r")
                encoder.encodeObject(title, forKey: "t")
                encoder.encodeObjectArray(articles, forKey: "a")
            case let .map(latitude, longitude, zoom, dimensions, caption):
                encoder.encodeInt32(InstantPageBlockType.map.rawValue, forKey: "r")
                encoder.encodeDouble(latitude, forKey: "lat")
                encoder.encodeDouble(longitude, forKey: "lon")
                encoder.encodeInt32(zoom, forKey: "z")
                encoder.encodeInt32(Int32(dimensions.width), forKey: "sw")
                encoder.encodeInt32(Int32(dimensions.height), forKey: "sh")
                encoder.encodeObject(caption, forKey: "mc")
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
            case let .image(lhsId, lhsCaption, lhsUrl, lhsWebpageId):
                if case let .image(rhsId, rhsCaption, rhsUrl, rhsWebpageId) = rhs, lhsId == rhsId, lhsCaption == rhsCaption, lhsUrl == rhsUrl, lhsWebpageId == rhsWebpageId {
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
            case let .webEmbed(lhsUrl, lhsHtml, lhsDimensions, lhsCaption, lhsStretchToWidth, lhsAllowScrolling, lhsCoverId):
                if case let .webEmbed(rhsUrl, rhsHtml, rhsDimensions, rhsCaption, rhsStretchToWidth, rhsAllowScrolling, rhsCoverId) = rhs, lhsUrl == rhsUrl && lhsHtml == rhsHtml && lhsDimensions == rhsDimensions && lhsCaption == rhsCaption && lhsStretchToWidth == rhsStretchToWidth && lhsAllowScrolling == rhsAllowScrolling && lhsCoverId == rhsCoverId {
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
            case let .channelBanner(lhsChannel):
                if case let .channelBanner(rhsChannel) = rhs {
                    if let lhsChannel = lhsChannel, let rhsChannel = rhsChannel {
                        if !lhsChannel.isEqual(rhsChannel) {
                            return false
                        }
                    } else if (lhsChannel != nil) != (rhsChannel != nil) {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .audio(id, caption):
                if case .audio(id, caption) = rhs {
                    return true
                } else {
                    return false
                }
            case let .kicker(text):
                if case .kicker(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .table(lhsTitle, lhsRows, lhsBordered, lhsStriped):
                if case let .table(rhsTitle, rhsRows, rhsBordered, rhsStriped) = rhs, lhsTitle == rhsTitle, lhsRows == rhsRows, lhsBordered == rhsBordered, lhsStriped == rhsStriped {
                    return true
                } else {
                    return false
                }
            case let .details(lhsTitle, lhsBlocks, lhsExpanded):
                if case let .details(rhsTitle, rhsBlocks, rhsExpanded) = rhs, lhsTitle == rhsTitle, lhsBlocks == rhsBlocks, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .relatedArticles(lhsTitle, lhsArticles):
                if case let .relatedArticles(rhsTitle, rhsArticles) = rhs, lhsTitle == rhsTitle, lhsArticles == rhsArticles {
                    return true
                } else {
                    return false
                }
            case let .map(latitude, longitude, zoom, dimensions, caption):
                if case .map(latitude, longitude, zoom, dimensions, caption) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class InstantPageCaption: PostboxCoding, Equatable {
    public let text: RichText
    public let credit: RichText
    
    public init(text: RichText, credit: RichText) {
        self.text = text
        self.credit = credit
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText
        self.credit = decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.text, forKey: "t")
        encoder.encodeObject(self.credit, forKey: "c")
    }
    
    public static func ==(lhs: InstantPageCaption, rhs: InstantPageCaption) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.credit != rhs.credit {
            return false
        }
        return true
    }
}

private enum InstantPageListItemType: Int32 {
    case unknown = 0
    case text = 1
    case blocks = 2
}

public indirect enum InstantPageListItem: PostboxCoding, Equatable {
    case unknown
    case text(RichText, String?)
    case blocks([InstantPageBlock], String?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case InstantPageListItemType.text.rawValue:
                self = .text(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, decoder.decodeOptionalStringForKey("n"))
            case InstantPageListItemType.blocks.rawValue:
                self = .blocks(decoder.decodeObjectArrayWithDecoderForKey("b"), decoder.decodeOptionalStringForKey("n"))
            default:
                self = .unknown
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .text(text, num):
                encoder.encodeInt32(InstantPageListItemType.text.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                if let num = num {
                    encoder.encodeString(num, forKey: "n")
                } else {
                    encoder.encodeNil(forKey: "n")
                }
            case let .blocks(blocks, num):
                encoder.encodeInt32(InstantPageListItemType.blocks.rawValue, forKey: "r")
                encoder.encodeObjectArray(blocks, forKey: "b")
                if let num = num {
                    encoder.encodeString(num, forKey: "n")
                } else {
                    encoder.encodeNil(forKey: "n")
                }
            default:
                break
        }
    }
    
    public static func ==(lhs: InstantPageListItem, rhs: InstantPageListItem) -> Bool {
        switch lhs {
            case .unknown:
                if case .unknown = rhs {
                    return true
                } else {
                    return false
                }
            case let .text(lhsText, lhsNum):
                if case let .text(rhsText, rhsNum) = rhs, lhsText == rhsText, lhsNum == rhsNum {
                    return true
                } else {
                    return false
                }
            case let .blocks(lhsBlocks, lhsNum):
                if case let .blocks(rhsBlocks, rhsNum) = rhs, lhsBlocks == rhsBlocks, lhsNum == rhsNum {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum TableHorizontalAlignment: Int32 {
    case left = 0
    case center = 1
    case right = 2
}

public enum TableVerticalAlignment: Int32 {
    case top = 0
    case middle = 1
    case bottom = 2
}

public final class InstantPageTableCell: PostboxCoding, Equatable {
    public let text: RichText?
    public let header: Bool
    public let alignment: TableHorizontalAlignment
    public let verticalAlignment: TableVerticalAlignment
    public let colspan: Int32
    public let rowspan: Int32
    
    public init(text: RichText?, header: Bool, alignment: TableHorizontalAlignment, verticalAlignment: TableVerticalAlignment, colspan: Int32, rowspan: Int32) {
        self.text = text
        self.header = header
        self.alignment = alignment
        self.verticalAlignment = verticalAlignment
        self.colspan = colspan
        self.rowspan = rowspan
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as? RichText
        self.header = decoder.decodeInt32ForKey("h", orElse: 0) != 0
        self.alignment = TableHorizontalAlignment(rawValue: decoder.decodeInt32ForKey("ha", orElse: 0))!
        self.verticalAlignment = TableVerticalAlignment(rawValue: decoder.decodeInt32ForKey("va", orElse: 0))!
        self.colspan = decoder.decodeInt32ForKey("sc", orElse: 0)
        self.rowspan = decoder.decodeInt32ForKey("sr", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let text = self.text {
            encoder.encodeObject(text, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
        encoder.encodeInt32(self.header ? 1 : 0, forKey: "h")
        encoder.encodeInt32(self.alignment.rawValue, forKey: "ha")
        encoder.encodeInt32(self.verticalAlignment.rawValue, forKey: "va")
        encoder.encodeInt32(self.colspan, forKey: "sc")
        encoder.encodeInt32(self.rowspan, forKey: "sr")
    }
    
    public static func ==(lhs: InstantPageTableCell, rhs: InstantPageTableCell) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.header != rhs.header {
            return false
        }
        if lhs.alignment != rhs.alignment {
            return false
        }
        if lhs.verticalAlignment != rhs.verticalAlignment {
            return false
        }
        if lhs.colspan != rhs.colspan {
            return false
        }
        if lhs.rowspan != rhs.rowspan {
            return false
        }
        return true
    }
}

public final class InstantPageTableRow: PostboxCoding, Equatable {
    public let cells: [InstantPageTableCell]
    
    public init(cells: [InstantPageTableCell]) {
        self.cells = cells
    }
    
    public init(decoder: PostboxDecoder) {
        self.cells = decoder.decodeObjectArrayWithDecoderForKey("c")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.cells, forKey: "c")
    }
    
    public static func ==(lhs: InstantPageTableRow, rhs: InstantPageTableRow) -> Bool {
        return lhs.cells == rhs.cells
    }
}

public final class InstantPageRelatedArticle: PostboxCoding, Equatable {
    public let url: String
    public let webpageId: MediaId
    public let title: String?
    public let description: String?
    public let photoId: MediaId?
    public let author: String?
    public let date: Int32?
    
    public init(url: String, webpageId: MediaId, title: String?, description: String?, photoId: MediaId?, author: String?, date: Int32?) {
        self.url = url
        self.webpageId = webpageId
        self.title = title
        self.description = description
        self.photoId = photoId
        self.author = author
        self.date = date
    }
    
    public init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
        let webpageIdNamespace = decoder.decodeInt32ForKey("w.n", orElse: 0)
        let webpageIdId = decoder.decodeInt64ForKey("w.i", orElse: 0)
        self.webpageId = MediaId(namespace: webpageIdNamespace, id: webpageIdId)
        
        self.title = decoder.decodeOptionalStringForKey("t")
        self.description = decoder.decodeOptionalStringForKey("d")
        
        var photoId: MediaId?
        if let photoIdNamespace = decoder.decodeOptionalInt32ForKey("p.n"), let photoIdId = decoder.decodeOptionalInt64ForKey("p.i") {
            photoId = MediaId(namespace: photoIdNamespace, id: photoIdId)
        }
        self.photoId = photoId
        self.author = decoder.decodeOptionalStringForKey("a")
        self.date = decoder.decodeOptionalInt32ForKey("d")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
        encoder.encodeInt32(self.webpageId.namespace, forKey: "w.n")
        encoder.encodeInt64(self.webpageId.id, forKey: "w.i")
        if let title = self.title {
            encoder.encodeString(title, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
        if let description = self.description {
            encoder.encodeString(description, forKey: "d")
        } else {
            encoder.encodeNil(forKey: "d")
        }
        if let photoId = photoId {
            encoder.encodeInt32(photoId.namespace, forKey: "p.n")
            encoder.encodeInt64(photoId.id, forKey: "p.i")
        } else {
            encoder.encodeNil(forKey: "p.n")
            encoder.encodeNil(forKey: "p.i")
        }
        if let author = self.author {
            encoder.encodeString(author, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
        if let date = self.date {
            encoder.encodeInt32(date, forKey: "d")
        } else {
            encoder.encodeNil(forKey: "d")
        }
    }
    
    public static func ==(lhs: InstantPageRelatedArticle, rhs: InstantPageRelatedArticle) -> Bool {
        if lhs.url != rhs.url {
            return false
        }
        if lhs.webpageId != rhs.webpageId {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.description != rhs.description {
            return false
        }
        if lhs.photoId != rhs.photoId {
            return false
        }
        if lhs.author != rhs.author {
            return false
        }
        if lhs.date != rhs.date {
            return false
        }
        return true
    }
}

private final class MediaDictionary: PostboxCoding {
    let dict: [MediaId: Media]
    
    init(dict: [MediaId: Media]) {
        self.dict = dict
    }
    
    init(decoder: PostboxDecoder) {
        let idsBufer = decoder.decodeBytesForKey("i")!
        let mediaIds = MediaId.decodeArrayFromBuffer(idsBufer)
        let medias = decoder.decodeObjectArrayForKey("m")
        var dict: [MediaId: Media] = [:]
        assert(mediaIds.count == medias.count)
        for i in 0 ..< mediaIds.count {
            if let media = medias[i] as? Media {
                dict[mediaIds[i]] = media
            }
        }
        self.dict = dict
    }
    
    func encode(_ encoder: PostboxEncoder) {
        var mediaIds: [MediaId] = []
        var medias: [PostboxCoding] = []
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

public final class InstantPage: PostboxCoding, Equatable {
    public let blocks: [InstantPageBlock]
    public let media: [MediaId: Media]
    public let isComplete: Bool
    public let rtl: Bool
    public let url: String
    public let views: Int32?
    
    public init(blocks: [InstantPageBlock], media: [MediaId: Media], isComplete: Bool, rtl: Bool, url: String, views: Int32?) {
        self.blocks = blocks
        self.media = media
        self.isComplete = isComplete
        self.rtl = rtl
        self.url = url
        self.views = views
    }
    
    public init(decoder: PostboxDecoder) {
        self.blocks = decoder.decodeObjectArrayWithDecoderForKey("b")
        self.media = MediaDictionary(decoder: decoder).dict
        self.isComplete = decoder.decodeInt32ForKey("c", orElse: 0) != 0
        self.rtl = decoder.decodeInt32ForKey("r", orElse: 0) != 0
        self.url = decoder.decodeStringForKey("url", orElse: "")
        self.views = decoder.decodeOptionalInt32ForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.blocks, forKey: "b")
        MediaDictionary(dict: self.media).encode(encoder)
        encoder.encodeInt32(self.isComplete ? 1 : 0, forKey: "c")
        encoder.encodeInt32(self.rtl ? 1 : 0, forKey: "r")
        encoder.encodeString(self.url, forKey: "url")
        if let views = self.views {
            encoder.encodeInt32(views, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
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
                    if !lhsValue.isEqual(to: media) {
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
        if lhs.rtl != rhs.rtl {
            return false
        }
        if lhs.url != rhs.url {
            return false
        }
        if lhs.views != rhs.views {
            return false
        }
        return true
    }
}
