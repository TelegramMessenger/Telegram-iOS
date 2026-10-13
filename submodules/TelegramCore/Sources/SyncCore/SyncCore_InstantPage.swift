import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

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
    case heading = 28
    case formula = 29
    case thinking = 30
    case buttonRow = 31
    case document = 32
}

private func decodeListItems(_ decoder: PostboxDecoder) -> [InstantPageListItem] {
    let legacyItems: [RichText] = decoder.decodeObjectArrayWithDecoderForKey("l") 
    if !legacyItems.isEmpty {
        var items: [InstantPageListItem] = []
        for item in legacyItems {
            items.append(.text(item, nil, nil))
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
    case heading(text: RichText, level: Int32)
    case formula(latex: String)
    case paragraph(RichText)
    case preformatted(text: RichText, language: String?)
    case footer(RichText)
    case divider
    case anchor(String)
    case list(items: [InstantPageListItem], ordered: Bool)
    case blockQuote(blocks: [InstantPageBlock], caption: RichText, collapsed: Bool?)
    case pullQuote(text: RichText, caption: RichText)
    case image(id: MediaId, caption: InstantPageCaption, url: String?, webpageId: MediaId?, spoiler: Bool)
    case video(id: MediaId, caption: InstantPageCaption, autoplay: Bool, loop: Bool, spoiler: Bool)
    case audio(id: MediaId, caption: InstantPageCaption)
    /// A generic file. Its own case rather than a widened `.audio`, which renders a music player.
    case document(id: MediaId, caption: InstantPageCaption)
    /// A row of inline buttons, laid out across the width (max 8 per row per the schema).
    case buttonRow(alignment: InstantPageButtonRowAlignment, buttons: [InstantPageButton])
    case cover(InstantPageBlock)
    case webEmbed(url: String?, html: String?, dimensions: PixelDimensions?, caption: InstantPageCaption, stretchToWidth: Bool, allowScrolling: Bool, coverId: MediaId?)
    case postEmbed(url: String, webpageId: MediaId?, avatarId: MediaId?, author: String, date: Int32, blocks: [InstantPageBlock], caption: InstantPageCaption)
    case collage(items: [InstantPageBlock], caption: InstantPageCaption)
    case slideshow(items: [InstantPageBlock], caption: InstantPageCaption)
    case channelBanner(TelegramChannel?)
    case kicker(RichText)
    case thinking(RichText)
    case table(title: RichText, rows: [InstantPageTableRow], bordered: Bool, striped: Bool, compact: Bool)
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
            case InstantPageBlockType.heading.rawValue:
                self = .heading(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, level: decoder.decodeInt32ForKey("l", orElse: 3))
            case InstantPageBlockType.formula.rawValue:
                self = .formula(latex: decoder.decodeStringForKey("l", orElse: ""))
            case InstantPageBlockType.paragraph.rawValue:
                self = .paragraph(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.preformatted.rawValue:
                self = .preformatted(
                    text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText,
                    language: decoder.decodeOptionalStringForKey("l")
                )
            case InstantPageBlockType.footer.rawValue:
                self = .footer(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.divider.rawValue:
                self = .divider
            case InstantPageBlockType.anchor.rawValue:
                self = .anchor(decoder.decodeStringForKey("s", orElse: ""))
            case InstantPageBlockType.list.rawValue:
                self = .list(items: decodeListItems(decoder), ordered: decoder.decodeOptionalInt32ForKey("o") != 0)
            case InstantPageBlockType.blockQuote.rawValue:
                let caption = decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText
                let collapsed = decoder.decodeOptionalInt32ForKey("qcol").flatMap { $0 != 0 }
                if let legacyText = decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as? RichText {
                    self = .blockQuote(blocks: [.paragraph(legacyText)], caption: caption, collapsed: collapsed)
                } else {
                    let blocks: [InstantPageBlock] = decoder.decodeObjectArrayWithDecoderForKey("b")
                    self = .blockQuote(blocks: blocks, caption: caption, collapsed: collapsed)
                }
            case InstantPageBlockType.pullQuote.rawValue:
                self = .pullQuote(text: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, caption: decoder.decodeObjectForKey("c", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.image.rawValue:
                var webpageId: MediaId?
                if let webpageIdNamespace = decoder.decodeOptionalInt32ForKey("wi.n"), let webpageIdId = decoder.decodeOptionalInt64ForKey("wi.i") {
                    webpageId = MediaId(namespace: webpageIdNamespace, id: webpageIdId)
                }
                self = .image(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), caption: decodeCaption(decoder), url: decoder.decodeOptionalStringForKey("u"), webpageId: webpageId, spoiler: decoder.decodeInt32ForKey("sp", orElse: 0) != 0)
            case InstantPageBlockType.video.rawValue:
                self = .video(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), caption: decodeCaption(decoder), autoplay: decoder.decodeInt32ForKey("ap", orElse: 0) != 0, loop: decoder.decodeInt32ForKey("lo", orElse: 0) != 0, spoiler: decoder.decodeInt32ForKey("sp", orElse: 0) != 0)
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
            case InstantPageBlockType.document.rawValue:
                self = .document(id: MediaId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0)), caption: decodeCaption(decoder))
            case InstantPageBlockType.buttonRow.rawValue:
                self = .buttonRow(
                    alignment: InstantPageButtonRowAlignment(rawValue: decoder.decodeInt32ForKey("al", orElse: 0)) ?? .justify,
                    buttons: decoder.decodeObjectArrayWithDecoderForKey("btns") as [InstantPageButton]
                )
            case InstantPageBlockType.kicker.rawValue:
                self = .kicker(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.thinking.rawValue:
                self = .thinking(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText)
            case InstantPageBlockType.table.rawValue:
                self = .table(title: decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, rows: decoder.decodeObjectArrayWithDecoderForKey("r"), bordered: decoder.decodeInt32ForKey("b", orElse: 0) != 0, striped: decoder.decodeInt32ForKey("s", orElse: 0) != 0, compact: decoder.decodeInt32ForKey("c", orElse: 0) != 0)
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
            case let .heading(text, level):
                encoder.encodeInt32(InstantPageBlockType.heading.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeInt32(level, forKey: "l")
            case let .formula(latex):
                encoder.encodeInt32(InstantPageBlockType.formula.rawValue, forKey: "r")
                encoder.encodeString(latex, forKey: "l")
            case let .paragraph(text):
                encoder.encodeInt32(InstantPageBlockType.paragraph.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .preformatted(text, language):
                encoder.encodeInt32(InstantPageBlockType.preformatted.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                if let language {
                    encoder.encodeString(language, forKey: "l")
                } else {
                    encoder.encodeNil(forKey: "l")
                }
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
            case let .blockQuote(blocks, caption, collapsed):
                encoder.encodeInt32(InstantPageBlockType.blockQuote.rawValue, forKey: "r")
                encoder.encodeObjectArray(blocks, forKey: "b")
                encoder.encodeObject(caption, forKey: "c")
                if let collapsed = collapsed {
                    encoder.encodeInt32(collapsed ? 1 : 0, forKey: "qcol")
                }
            case let .pullQuote(text, caption):
                encoder.encodeInt32(InstantPageBlockType.pullQuote.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                encoder.encodeObject(caption, forKey: "c")
            case let .image(id, caption, url, webpageId, spoiler):
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
                encoder.encodeInt32(spoiler ? 1 : 0, forKey: "sp")
            case let .video(id, caption, autoplay, loop, spoiler):
                encoder.encodeInt32(InstantPageBlockType.video.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "mc")
                encoder.encodeInt32(autoplay ? 1 : 0, forKey: "ap")
                encoder.encodeInt32(loop ? 1 : 0, forKey: "lo")
                encoder.encodeInt32(spoiler ? 1 : 0, forKey: "sp")
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
            case let .document(id, caption):
                encoder.encodeInt32(InstantPageBlockType.document.rawValue, forKey: "r")
                encoder.encodeInt32(id.namespace, forKey: "i.n")
                encoder.encodeInt64(id.id, forKey: "i.i")
                encoder.encodeObject(caption, forKey: "mc")
            case let .buttonRow(alignment, buttons):
                encoder.encodeInt32(InstantPageBlockType.buttonRow.rawValue, forKey: "r")
                encoder.encodeInt32(alignment.rawValue, forKey: "al")
                encoder.encodeObjectArray(buttons, forKey: "btns")
            case let .kicker(text):
                encoder.encodeInt32(InstantPageBlockType.kicker.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .thinking(text):
                encoder.encodeInt32(InstantPageBlockType.thinking.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
            case let .table(title, rows, bordered, striped, compact):
                encoder.encodeInt32(InstantPageBlockType.table.rawValue, forKey: "r")
                encoder.encodeObject(title, forKey: "t")
                encoder.encodeObjectArray(rows, forKey: "r")
                encoder.encodeInt32(bordered ? 1 : 0, forKey: "b")
                encoder.encodeInt32(striped ? 1 : 0, forKey: "s")
                encoder.encodeInt32(compact ? 1 : 0, forKey: "c")
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
            case let .heading(lhsText, lhsLevel):
                if case let .heading(rhsText, rhsLevel) = rhs, lhsText == rhsText, lhsLevel == rhsLevel {
                    return true
                } else {
                    return false
                }
            case let .formula(lhsLatex):
                if case let .formula(rhsLatex) = rhs, lhsLatex == rhsLatex {
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
            case let .preformatted(lhsText, lhsLanguage):
                if case let .preformatted(rhsText, rhsLanguage) = rhs, lhsText == rhsText, lhsLanguage == rhsLanguage {
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
            case let .blockQuote(lhsBlocks, lhsCaption, lhsCollapsed):
                // `collapsed` is part of equality now that `pageBlockBlockquote` carries it on the wire.
                // While it was wire-invisible, excluding it only avoided diff churn; now excluding it would
                // pin a stale collapse state whenever it is the only thing that changed. The API layer
                // normalizes every cloud-received quote to a non-nil value, so a locally-composed `false`
                // matches the server echo on the pending→confirmed swap. `nil` survives only on rows
                // written before the field existed, which compare unequal once — a one-time re-render.
                if case let .blockQuote(rhsBlocks, rhsCaption, rhsCollapsed) = rhs, lhsBlocks == rhsBlocks, lhsCaption == rhsCaption, lhsCollapsed == rhsCollapsed {
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
            case let .image(lhsId, lhsCaption, lhsUrl, lhsWebpageId, lhsSpoiler):
                if case let .image(rhsId, rhsCaption, rhsUrl, rhsWebpageId, rhsSpoiler) = rhs, lhsId == rhsId, lhsCaption == rhsCaption, lhsUrl == rhsUrl, lhsWebpageId == rhsWebpageId, lhsSpoiler == rhsSpoiler {
                    return true
                } else {
                    return false
                }
            case let .video(id, caption, autoplay, loop, spoiler):
                if case .video(id, caption, autoplay, loop, spoiler) = rhs {
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
            case let .document(id, caption):
                if case .document(id, caption) = rhs {
                    return true
                } else {
                    return false
                }
            case let .buttonRow(alignment, buttons):
                if case .buttonRow(alignment, buttons) = rhs {
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
            case let .thinking(text):
                if case .thinking(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .table(lhsTitle, lhsRows, lhsBordered, lhsStriped, lhsCompact):
                if case let .table(rhsTitle, rhsRows, rhsBordered, rhsStriped, rhsCompact) = rhs, lhsTitle == rhsTitle, lhsRows == rhsRows, lhsBordered == rhsBordered, lhsStriped == rhsStriped, lhsCompact == rhsCompact {
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
    
    public init(flatBuffersObject: TelegramCore_InstantPageBlock) throws {
        switch flatBuffersObject.valueType {
        case .instantpageblockUnsupported:
            self = .unsupported
        case .instantpageblockTitle:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Title.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .title(try RichText(flatBuffersObject: value.text))
        case .instantpageblockSubtitle:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Subtitle.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .subtitle(try RichText(flatBuffersObject: value.text))
        case .instantpageblockAuthordate:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_AuthorDate.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .authorDate(author: try RichText(flatBuffersObject: value.author), date: value.date)
        case .instantpageblockHeader:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Header.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .header(try RichText(flatBuffersObject: value.text))
        case .instantpageblockSubheader:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Subheader.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .subheader(try RichText(flatBuffersObject: value.text))
        case .instantpageblockHeading:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Heading.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .heading(text: try RichText(flatBuffersObject: value.text), level: value.level)
        case .instantpageblockFormula:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Formula.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .formula(latex: value.latex)
        case .instantpageblockParagraph:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Paragraph.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .paragraph(try RichText(flatBuffersObject: value.text))
        case .instantpageblockPreformatted:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Preformatted.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .preformatted(text: try RichText(flatBuffersObject: value.text), language: value.language)
        case .instantpageblockFooter:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Footer.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .footer(try RichText(flatBuffersObject: value.text))
        case .instantpageblockDivider:
            self = .divider
        case .instantpageblockAnchor:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Anchor.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .anchor(value.name)
        case .instantpageblockList:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_List.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .list(items: try (0 ..< value.itemsCount).map { try InstantPageListItem(flatBuffersObject: value.items(at: $0)!) }, ordered: value.ordered)
        case .instantpageblockBlockquote:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_BlockQuote.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            let caption = try RichText(flatBuffersObject: value.caption)
            // Absent on payloads written before the field existed, which is exactly the model's `nil`.
            let collapsed = value.collapsed?.value
            if value.blocksCount > 0 {
                let blocks = try (0 ..< value.blocksCount).map { try InstantPageBlock(flatBuffersObject: value.blocks(at: $0)!) }
                self = .blockQuote(blocks: blocks, caption: caption, collapsed: collapsed)
            } else if let legacyText = value.text {
                self = .blockQuote(blocks: [.paragraph(try RichText(flatBuffersObject: legacyText))], caption: caption, collapsed: collapsed)
            } else {
                self = .blockQuote(blocks: [], caption: caption, collapsed: collapsed)
            }
        case .instantpageblockPullquote:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_PullQuote.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .pullQuote(text: try RichText(flatBuffersObject: value.text), caption: try RichText(flatBuffersObject: value.caption))
        case .instantpageblockImage:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Image.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .image(id: MediaId(value.id), caption: try InstantPageCaption(flatBuffersObject: value.caption), url: value.url, webpageId: value.webpageId.flatMap(MediaId.init), spoiler: value.spoiler)
        case .instantpageblockVideo:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Video.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .video(id: MediaId(value.id), caption: try InstantPageCaption(flatBuffersObject: value.caption), autoplay: value.autoplay, loop: value.loop, spoiler: value.spoiler)
        case .instantpageblockAudio:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Audio.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .audio(id: MediaId(value.id), caption: try InstantPageCaption(flatBuffersObject: value.caption))
        case .instantpageblockDocument:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Document.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .document(id: MediaId(value.id), caption: try InstantPageCaption(flatBuffersObject: value.caption))
        case .instantpageblockButtonrow:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_ButtonRow.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .buttonRow(
                alignment: InstantPageButtonRowAlignment(rawValue: value.alignment) ?? .justify,
                buttons: try (0 ..< value.buttonsCount).map { try InstantPageButton(flatBuffersObject: value.buttons(at: $0)!) }
            )
        case .instantpageblockCover:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Cover.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .cover(try InstantPageBlock(flatBuffersObject: value.block))
        case .instantpageblockWebembed:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_WebEmbed.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .webEmbed(url: value.url, html: value.html, dimensions: value.dimensions.flatMap(PixelDimensions.init), caption: try InstantPageCaption(flatBuffersObject: value.caption), stretchToWidth: value.stretchToWidth, allowScrolling: value.allowScrolling, coverId: value.coverId.flatMap(MediaId.init))
        case .instantpageblockPostembed:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_PostEmbed.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .postEmbed(url: value.url, webpageId: value.webpageId.flatMap(MediaId.init), avatarId: value.avatarId.flatMap(MediaId.init), author: value.author, date: value.date, blocks: try (0 ..< value.blocksCount).map { try InstantPageBlock(flatBuffersObject: value.blocks(at: $0)!) }, caption: try InstantPageCaption(flatBuffersObject: value.caption))
        case .instantpageblockCollage:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Collage.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .collage(items: try (0 ..< value.itemsCount).map { try InstantPageBlock(flatBuffersObject: value.items(at: $0)!) }, caption: try InstantPageCaption(flatBuffersObject: value.caption))
        case .instantpageblockSlideshow:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Slideshow.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .slideshow(items: try (0 ..< value.itemsCount).map { try InstantPageBlock(flatBuffersObject: value.items(at: $0)!) }, caption: try InstantPageCaption(flatBuffersObject: value.caption))
        case .instantpageblockChannelbanner:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_ChannelBanner.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            let channel = try value.channel.flatMap { try TelegramChannel(flatBuffersObject: $0) }
            self = .channelBanner(channel)
        case .instantpageblockKicker:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Kicker.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .kicker(try RichText(flatBuffersObject: value.text))
        case .instantpageblockThinking:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Thinking.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .thinking(try RichText(flatBuffersObject: value.text))
        case .instantpageblockTable:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Table.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .table(title: try RichText(flatBuffersObject: value.title), rows: try (0 ..< value.rowsCount).map { try InstantPageTableRow(flatBuffersObject: value.rows(at: $0)!) }, bordered: value.bordered, striped: value.striped, compact: value.compact)
        case .instantpageblockDetails:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Details.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .details(title: try RichText(flatBuffersObject: value.title), blocks: try (0 ..< value.blocksCount).map { try InstantPageBlock(flatBuffersObject: value.blocks(at: $0)!) }, expanded: value.expanded)
        case .instantpageblockRelatedarticles:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_RelatedArticles.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .relatedArticles(title: try RichText(flatBuffersObject: value.title), articles: try (0 ..< value.articlesCount).map { try InstantPageRelatedArticle(flatBuffersObject: value.articles(at: $0)!) })
        case .instantpageblockMap:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageBlock_Map.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .map(latitude: value.latitude, longitude: value.longitude, zoom: value.zoom, dimensions: PixelDimensions(value.dimensions), caption: try InstantPageCaption(flatBuffersObject: value.caption))
        case .none_:
            throw FlatBuffersError.missingRequiredField()
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_InstantPageBlock_Value
        let offset: Offset
        
        switch self {
        case .unsupported:
            valueType = .instantpageblockUnsupported
            let start = TelegramCore_InstantPageBlock_Unsupported.startInstantPageBlock_Unsupported(&builder)
            offset = TelegramCore_InstantPageBlock_Unsupported.endInstantPageBlock_Unsupported(&builder, start: start)
        case let .title(text):
            valueType = .instantpageblockTitle
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Title.startInstantPageBlock_Title(&builder)
            TelegramCore_InstantPageBlock_Title.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Title.endInstantPageBlock_Title(&builder, start: start)
        case let .subtitle(text):
            valueType = .instantpageblockSubtitle
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Subtitle.startInstantPageBlock_Subtitle(&builder)
            TelegramCore_InstantPageBlock_Subtitle.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Subtitle.endInstantPageBlock_Subtitle(&builder, start: start)
        case let .authorDate(author, date):
            valueType = .instantpageblockAuthordate
            let authorOffset = author.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_AuthorDate.startInstantPageBlock_AuthorDate(&builder)
            TelegramCore_InstantPageBlock_AuthorDate.add(author: authorOffset, &builder)
            TelegramCore_InstantPageBlock_AuthorDate.add(date: date, &builder)
            offset = TelegramCore_InstantPageBlock_AuthorDate.endInstantPageBlock_AuthorDate(&builder, start: start)
        case let .header(text):
            valueType = .instantpageblockHeader
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Header.startInstantPageBlock_Header(&builder)
            TelegramCore_InstantPageBlock_Header.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Header.endInstantPageBlock_Header(&builder, start: start)
        case let .subheader(text):
            valueType = .instantpageblockSubheader
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Subheader.startInstantPageBlock_Subheader(&builder)
            TelegramCore_InstantPageBlock_Subheader.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Subheader.endInstantPageBlock_Subheader(&builder, start: start)
        case let .heading(text, level):
            valueType = .instantpageblockHeading
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Heading.startInstantPageBlock_Heading(&builder)
            TelegramCore_InstantPageBlock_Heading.add(text: textOffset, &builder)
            TelegramCore_InstantPageBlock_Heading.add(level: level, &builder)
            offset = TelegramCore_InstantPageBlock_Heading.endInstantPageBlock_Heading(&builder, start: start)
        case let .formula(latex):
            valueType = .instantpageblockFormula
            let latexOffset = builder.create(string: latex)
            let start = TelegramCore_InstantPageBlock_Formula.startInstantPageBlock_Formula(&builder)
            TelegramCore_InstantPageBlock_Formula.add(latex: latexOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Formula.endInstantPageBlock_Formula(&builder, start: start)
        case let .paragraph(text):
            valueType = .instantpageblockParagraph
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Paragraph.startInstantPageBlock_Paragraph(&builder)
            TelegramCore_InstantPageBlock_Paragraph.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Paragraph.endInstantPageBlock_Paragraph(&builder, start: start)
        case let .preformatted(text, language):
            valueType = .instantpageblockPreformatted
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let languageOffset = language.flatMap { builder.create(string: $0) }
            let start = TelegramCore_InstantPageBlock_Preformatted.startInstantPageBlock_Preformatted(&builder)
            TelegramCore_InstantPageBlock_Preformatted.add(text: textOffset, &builder)
            if let languageOffset {
                TelegramCore_InstantPageBlock_Preformatted.add(language: languageOffset, &builder)
            }
            offset = TelegramCore_InstantPageBlock_Preformatted.endInstantPageBlock_Preformatted(&builder, start: start)
        case let .footer(text):
            valueType = .instantpageblockFooter
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Footer.startInstantPageBlock_Footer(&builder)
            TelegramCore_InstantPageBlock_Footer.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Footer.endInstantPageBlock_Footer(&builder, start: start)
        case .divider:
            valueType = .instantpageblockDivider
            let start = TelegramCore_InstantPageBlock_Divider.startInstantPageBlock_Divider(&builder)
            offset = TelegramCore_InstantPageBlock_Divider.endInstantPageBlock_Divider(&builder, start: start)
        case let .anchor(name):
            valueType = .instantpageblockAnchor
            let nameOffset = builder.create(string: name)
            let start = TelegramCore_InstantPageBlock_Anchor.startInstantPageBlock_Anchor(&builder)
            TelegramCore_InstantPageBlock_Anchor.add(name: nameOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Anchor.endInstantPageBlock_Anchor(&builder, start: start)
        case let .list(items, ordered):
            valueType = .instantpageblockList
            let itemsOffsets = items.map { $0.encodeToFlatBuffers(builder: &builder) }
            let itemsOffset = builder.createVector(ofOffsets: itemsOffsets, len: itemsOffsets.count)
            let start = TelegramCore_InstantPageBlock_List.startInstantPageBlock_List(&builder)
            TelegramCore_InstantPageBlock_List.addVectorOf(items: itemsOffset, &builder)
            TelegramCore_InstantPageBlock_List.add(ordered: ordered, &builder)
            offset = TelegramCore_InstantPageBlock_List.endInstantPageBlock_List(&builder, start: start)
        case let .blockQuote(blocks, caption, collapsed):
            valueType = .instantpageblockBlockquote
            let blocksOffsets = blocks.map { $0.encodeToFlatBuffers(builder: &builder) }
            let blocksOffset = builder.createVector(ofOffsets: blocksOffsets, len: blocksOffsets.count)
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_BlockQuote.startInstantPageBlock_BlockQuote(&builder)
            TelegramCore_InstantPageBlock_BlockQuote.addVectorOf(blocks: blocksOffset, &builder)
            TelegramCore_InstantPageBlock_BlockQuote.add(caption: captionOffset, &builder)
            if let collapsed = collapsed {
                TelegramCore_InstantPageBlock_BlockQuote.add(collapsed: TelegramCore_OptionalBool(value: collapsed), &builder)
            }
            offset = TelegramCore_InstantPageBlock_BlockQuote.endInstantPageBlock_BlockQuote(&builder, start: start)
        case let .pullQuote(text, caption):
            valueType = .instantpageblockPullquote
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_PullQuote.startInstantPageBlock_PullQuote(&builder)
            TelegramCore_InstantPageBlock_PullQuote.add(text: textOffset, &builder)
            TelegramCore_InstantPageBlock_PullQuote.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_PullQuote.endInstantPageBlock_PullQuote(&builder, start: start)
        case let .image(id, caption, url, webpageId, spoiler):
            valueType = .instantpageblockImage
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let urlOffset = url.flatMap { builder.create(string: $0) }
            let start = TelegramCore_InstantPageBlock_Image.startInstantPageBlock_Image(&builder)
            TelegramCore_InstantPageBlock_Image.add(id: id.asFlatBuffersObject(), &builder)
            TelegramCore_InstantPageBlock_Image.add(caption: captionOffset, &builder)
            if let urlOffset {
                TelegramCore_InstantPageBlock_Image.add(url: urlOffset, &builder)
            }
            if let webpageId {
                TelegramCore_InstantPageBlock_Image.add(webpageId: webpageId.asFlatBuffersObject(), &builder)
            }
            TelegramCore_InstantPageBlock_Image.add(spoiler: spoiler, &builder)
            offset = TelegramCore_InstantPageBlock_Image.endInstantPageBlock_Image(&builder, start: start)
        case let .video(id, caption, autoplay, loop, spoiler):
            valueType = .instantpageblockVideo
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Video.startInstantPageBlock_Video(&builder)
            TelegramCore_InstantPageBlock_Video.add(id: id.asFlatBuffersObject(), &builder)
            TelegramCore_InstantPageBlock_Video.add(caption: captionOffset, &builder)
            TelegramCore_InstantPageBlock_Video.add(autoplay: autoplay, &builder)
            TelegramCore_InstantPageBlock_Video.add(loop: loop, &builder)
            TelegramCore_InstantPageBlock_Video.add(spoiler: spoiler, &builder)
            offset = TelegramCore_InstantPageBlock_Video.endInstantPageBlock_Video(&builder, start: start)
        case let .audio(id, caption):
            valueType = .instantpageblockAudio
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Audio.startInstantPageBlock_Audio(&builder)
            TelegramCore_InstantPageBlock_Audio.add(id: id.asFlatBuffersObject(), &builder)
            TelegramCore_InstantPageBlock_Audio.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Audio.endInstantPageBlock_Audio(&builder, start: start)
        case let .document(id, caption):
            valueType = .instantpageblockDocument
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Document.startInstantPageBlock_Document(&builder)
            TelegramCore_InstantPageBlock_Document.add(id: id.asFlatBuffersObject(), &builder)
            TelegramCore_InstantPageBlock_Document.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Document.endInstantPageBlock_Document(&builder, start: start)
        case let .buttonRow(alignment, buttons):
            valueType = .instantpageblockButtonrow
            let buttonOffsets = buttons.map { $0.encodeToFlatBuffers(builder: &builder) }
            let buttonsOffset = builder.createVector(ofOffsets: buttonOffsets)
            let start = TelegramCore_InstantPageBlock_ButtonRow.startInstantPageBlock_ButtonRow(&builder)
            TelegramCore_InstantPageBlock_ButtonRow.addVectorOf(buttons: buttonsOffset, &builder)
            TelegramCore_InstantPageBlock_ButtonRow.add(alignment: alignment.rawValue, &builder)
            offset = TelegramCore_InstantPageBlock_ButtonRow.endInstantPageBlock_ButtonRow(&builder, start: start)
        case let .cover(block):
            valueType = .instantpageblockCover
            let blockOffset = block.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Cover.startInstantPageBlock_Cover(&builder)
            TelegramCore_InstantPageBlock_Cover.add(block: blockOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Cover.endInstantPageBlock_Cover(&builder, start: start)
        case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling, coverId):
            valueType = .instantpageblockWebembed
            let urlOffset = url.flatMap { builder.create(string: $0) }
            let htmlOffset = html.flatMap { builder.create(string: $0) }
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_WebEmbed.startInstantPageBlock_WebEmbed(&builder)
            if let urlOffset {
                TelegramCore_InstantPageBlock_WebEmbed.add(url: urlOffset, &builder)
            }
            if let htmlOffset {
                TelegramCore_InstantPageBlock_WebEmbed.add(html: htmlOffset, &builder)
            }
            if let dimensions {
                TelegramCore_InstantPageBlock_WebEmbed.add(dimensions: dimensions.asFlatBuffersObject(), &builder)
            }
            TelegramCore_InstantPageBlock_WebEmbed.add(caption: captionOffset, &builder)
            TelegramCore_InstantPageBlock_WebEmbed.add(stretchToWidth: stretchToWidth, &builder)
            TelegramCore_InstantPageBlock_WebEmbed.add(allowScrolling: allowScrolling, &builder)
            if let coverId {
                TelegramCore_InstantPageBlock_WebEmbed.add(coverId: coverId.asFlatBuffersObject(), &builder)
            }
            offset = TelegramCore_InstantPageBlock_WebEmbed.endInstantPageBlock_WebEmbed(&builder, start: start)
        case let .postEmbed(url, webpageId, avatarId, author, date, blocks, caption):
            valueType = .instantpageblockPostembed
            let urlOffset = builder.create(string: url)
            let authorOffset = builder.create(string: author)
            let blocksOffsets = blocks.map { $0.encodeToFlatBuffers(builder: &builder) }
            let blocksOffset = builder.createVector(ofOffsets: blocksOffsets, len: blocksOffsets.count)
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_PostEmbed.startInstantPageBlock_PostEmbed(&builder)
            TelegramCore_InstantPageBlock_PostEmbed.add(url: urlOffset, &builder)
            if let webpageId {
                TelegramCore_InstantPageBlock_PostEmbed.add(webpageId: webpageId.asFlatBuffersObject(), &builder)
            }
            if let avatarId {
                TelegramCore_InstantPageBlock_PostEmbed.add(avatarId: avatarId.asFlatBuffersObject(), &builder)
            }
            TelegramCore_InstantPageBlock_PostEmbed.add(author: authorOffset, &builder)
            TelegramCore_InstantPageBlock_PostEmbed.add(date: date, &builder)
            TelegramCore_InstantPageBlock_PostEmbed.addVectorOf(blocks: blocksOffset, &builder)
            TelegramCore_InstantPageBlock_PostEmbed.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_PostEmbed.endInstantPageBlock_PostEmbed(&builder, start: start)
        case let .collage(items, caption):
            valueType = .instantpageblockCollage
            let itemsOffsets = items.map { $0.encodeToFlatBuffers(builder: &builder) }
            let itemsOffset = builder.createVector(ofOffsets: itemsOffsets, len: itemsOffsets.count)
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Collage.startInstantPageBlock_Collage(&builder)
            TelegramCore_InstantPageBlock_Collage.addVectorOf(items: itemsOffset, &builder)
            TelegramCore_InstantPageBlock_Collage.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Collage.endInstantPageBlock_Collage(&builder, start: start)
        case let .slideshow(items, caption):
            valueType = .instantpageblockSlideshow
            let itemsOffsets = items.map { $0.encodeToFlatBuffers(builder: &builder) }
            let itemsOffset = builder.createVector(ofOffsets: itemsOffsets, len: itemsOffsets.count)
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Slideshow.startInstantPageBlock_Slideshow(&builder)
            TelegramCore_InstantPageBlock_Slideshow.addVectorOf(items: itemsOffset, &builder)
            TelegramCore_InstantPageBlock_Slideshow.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Slideshow.endInstantPageBlock_Slideshow(&builder, start: start)
        case let .channelBanner(channel):
            valueType = .instantpageblockChannelbanner
            let channelOffset = channel.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
            let start = TelegramCore_InstantPageBlock_ChannelBanner.startInstantPageBlock_ChannelBanner(&builder)
            if let channelOffset {
                TelegramCore_InstantPageBlock_ChannelBanner.add(channel: channelOffset, &builder)
            }
            offset = TelegramCore_InstantPageBlock_ChannelBanner.endInstantPageBlock_ChannelBanner(&builder, start: start)
        case let .kicker(text):
            valueType = .instantpageblockKicker
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Kicker.startInstantPageBlock_Kicker(&builder)
            TelegramCore_InstantPageBlock_Kicker.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Kicker.endInstantPageBlock_Kicker(&builder, start: start)
        case let .thinking(text):
            valueType = .instantpageblockThinking
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Thinking.startInstantPageBlock_Thinking(&builder)
            TelegramCore_InstantPageBlock_Thinking.add(text: textOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Thinking.endInstantPageBlock_Thinking(&builder, start: start)
        case let .table(title, rows, bordered, striped, compact):
            valueType = .instantpageblockTable
            let titleOffset = title.encodeToFlatBuffers(builder: &builder)
            let rowsOffsets = rows.map { $0.encodeToFlatBuffers(builder: &builder) }
            let rowsOffset = builder.createVector(ofOffsets: rowsOffsets, len: rowsOffsets.count)
            let start = TelegramCore_InstantPageBlock_Table.startInstantPageBlock_Table(&builder)
            TelegramCore_InstantPageBlock_Table.add(title: titleOffset, &builder)
            TelegramCore_InstantPageBlock_Table.addVectorOf(rows: rowsOffset, &builder)
            TelegramCore_InstantPageBlock_Table.add(bordered: bordered, &builder)
            TelegramCore_InstantPageBlock_Table.add(striped: striped, &builder)
            TelegramCore_InstantPageBlock_Table.add(compact: compact, &builder)
            offset = TelegramCore_InstantPageBlock_Table.endInstantPageBlock_Table(&builder, start: start)
        case let .details(title, blocks, expanded):
            valueType = .instantpageblockDetails
            let titleOffset = title.encodeToFlatBuffers(builder: &builder)
            let blocksOffsets = blocks.map { $0.encodeToFlatBuffers(builder: &builder) }
            let blocksOffset = builder.createVector(ofOffsets: blocksOffsets, len: blocksOffsets.count)
            let start = TelegramCore_InstantPageBlock_Details.startInstantPageBlock_Details(&builder)
            TelegramCore_InstantPageBlock_Details.add(title: titleOffset, &builder)
            TelegramCore_InstantPageBlock_Details.addVectorOf(blocks: blocksOffset, &builder)
            TelegramCore_InstantPageBlock_Details.add(expanded: expanded, &builder)
            offset = TelegramCore_InstantPageBlock_Details.endInstantPageBlock_Details(&builder, start: start)
        case let .relatedArticles(title, articles):
            valueType = .instantpageblockRelatedarticles
            let titleOffset = title.encodeToFlatBuffers(builder: &builder)
            let articlesOffsets = articles.map { $0.encodeToFlatBuffers(builder: &builder) }
            let articlesOffset = builder.createVector(ofOffsets: articlesOffsets, len: articlesOffsets.count)
            let start = TelegramCore_InstantPageBlock_RelatedArticles.startInstantPageBlock_RelatedArticles(&builder)
            TelegramCore_InstantPageBlock_RelatedArticles.add(title: titleOffset, &builder)
            TelegramCore_InstantPageBlock_RelatedArticles.addVectorOf(articles: articlesOffset, &builder)
            offset = TelegramCore_InstantPageBlock_RelatedArticles.endInstantPageBlock_RelatedArticles(&builder, start: start)
        case let .map(latitude, longitude, zoom, dimensions, caption):
            valueType = .instantpageblockMap
            let captionOffset = caption.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_InstantPageBlock_Map.startInstantPageBlock_Map(&builder)
            TelegramCore_InstantPageBlock_Map.add(latitude: latitude, &builder)
            TelegramCore_InstantPageBlock_Map.add(longitude: longitude, &builder)
            TelegramCore_InstantPageBlock_Map.add(zoom: zoom, &builder)
            TelegramCore_InstantPageBlock_Map.add(dimensions: dimensions.asFlatBuffersObject(), &builder)
            TelegramCore_InstantPageBlock_Map.add(caption: captionOffset, &builder)
            offset = TelegramCore_InstantPageBlock_Map.endInstantPageBlock_Map(&builder, start: start)
        }
        
        return TelegramCore_InstantPageBlock.createInstantPageBlock(&builder, valueType: valueType, valueOffset: offset)
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
    
    public init(flatBuffersObject: TelegramCore_InstantPageCaption) throws {
        self.text = try RichText(flatBuffersObject: flatBuffersObject.text)
        self.credit = try RichText(flatBuffersObject: flatBuffersObject.credit)
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let textOffset = self.text.encodeToFlatBuffers(builder: &builder)
        let creditOffset = self.credit.encodeToFlatBuffers(builder: &builder)
        let start = TelegramCore_InstantPageCaption.startInstantPageCaption(&builder)
        TelegramCore_InstantPageCaption.add(text: textOffset, &builder)
        TelegramCore_InstantPageCaption.add(credit: creditOffset, &builder)
        let offset = TelegramCore_InstantPageCaption.endInstantPageCaption(&builder, start: start)
        return offset
    }
}

private enum InstantPageListItemType: Int32 {
    case unknown = 0
    case text = 1
    case blocks = 2
}

public indirect enum InstantPageListItem: PostboxCoding, Equatable {
    case unknown
    case text(RichText, String?, Bool?)
    case blocks([InstantPageBlock], String?, Bool?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case InstantPageListItemType.text.rawValue:
                self = .text(decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText, decoder.decodeOptionalStringForKey("n"), InstantPageListItem.checkedFromTriState(decoder.decodeInt32ForKey("ck", orElse: 0)))
            case InstantPageListItemType.blocks.rawValue:
                self = .blocks(decoder.decodeObjectArrayWithDecoderForKey("b"), decoder.decodeOptionalStringForKey("n"), InstantPageListItem.checkedFromTriState(decoder.decodeInt32ForKey("ck", orElse: 0)))
            default:
                self = .unknown
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .text(text, num, checked):
                encoder.encodeInt32(InstantPageListItemType.text.rawValue, forKey: "r")
                encoder.encodeObject(text, forKey: "t")
                if let num = num {
                    encoder.encodeString(num, forKey: "n")
                } else {
                    encoder.encodeNil(forKey: "n")
                }
                if let triState = InstantPageListItem.triState(fromChecked: checked) {
                    encoder.encodeInt32(triState, forKey: "ck")
                } else {
                    encoder.encodeNil(forKey: "ck")
                }
            case let .blocks(blocks, num, checked):
                encoder.encodeInt32(InstantPageListItemType.blocks.rawValue, forKey: "r")
                encoder.encodeObjectArray(blocks, forKey: "b")
                if let num = num {
                    encoder.encodeString(num, forKey: "n")
                } else {
                    encoder.encodeNil(forKey: "n")
                }
                if let triState = InstantPageListItem.triState(fromChecked: checked) {
                    encoder.encodeInt32(triState, forKey: "ck")
                } else {
                    encoder.encodeNil(forKey: "ck")
                }
            default:
                break
        }
    }
    
    static func checkedFromTriState(_ value: Int32) -> Bool? {
        switch value {
        case 1: return false
        case 2: return true
        default: return nil
        }
    }

    /// Returns the persisted tri-state (1 = unchecked, 2 = checked) or nil when not a checkbox item.
    static func triState(fromChecked checked: Bool?) -> Int32? {
        switch checked {
        case .some(false): return 1
        case .some(true): return 2
        case .none: return nil
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
            case let .text(lhsText, lhsNum, lhsChecked):
                if case let .text(rhsText, rhsNum, rhsChecked) = rhs, lhsText == rhsText, lhsNum == rhsNum, lhsChecked == rhsChecked {
                    return true
                } else {
                    return false
                }
            case let .blocks(lhsBlocks, lhsNum, lhsChecked):
                if case let .blocks(rhsBlocks, rhsNum, rhsChecked) = rhs, lhsBlocks == rhsBlocks, lhsNum == rhsNum, lhsChecked == rhsChecked {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public init(flatBuffersObject: TelegramCore_InstantPageListItem) throws {
        switch flatBuffersObject.valueType {
        case .instantpagelistitemText:
            guard let textValue = flatBuffersObject.value(type: TelegramCore_InstantPageListItem_Text.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .text(try RichText(flatBuffersObject: textValue.text), textValue.number, InstantPageListItem.checkedFromTriState(textValue.checkState))
            
        case .instantpagelistitemBlocks:
            guard let blocksValue = flatBuffersObject.value(type: TelegramCore_InstantPageListItem_Blocks.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            let blocks = try (0 ..< blocksValue.blocksCount).map { i in
                return try InstantPageBlock(flatBuffersObject: blocksValue.blocks(at: i)!)
            }
            self = .blocks(blocks, blocksValue.number, InstantPageListItem.checkedFromTriState(blocksValue.checkState))
        case .instantpagelistitemUnknown:
            self = .unknown
        case .none_:
            throw FlatBuffersError.missingRequiredField()
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_InstantPageListItem_Value
        let offset: Offset
        
        switch self {
        case let .text(text, number, checked):
            valueType = .instantpagelistitemText
            let textOffset = text.encodeToFlatBuffers(builder: &builder)
            let numberOffset = number.map { builder.create(string: $0) } ?? Offset()

            let start = TelegramCore_InstantPageListItem_Text.startInstantPageListItem_Text(&builder)
            TelegramCore_InstantPageListItem_Text.add(text: textOffset, &builder)
            if let _ = number {
                TelegramCore_InstantPageListItem_Text.add(number: numberOffset, &builder)
            }
            if let triState = InstantPageListItem.triState(fromChecked: checked) {
                TelegramCore_InstantPageListItem_Text.add(checkState: triState, &builder)
            }
            offset = TelegramCore_InstantPageListItem_Text.endInstantPageListItem_Text(&builder, start: start)
        case let .blocks(blocks, number, checked):
            valueType = .instantpagelistitemBlocks
            let blocksOffsets = blocks.map { $0.encodeToFlatBuffers(builder: &builder) }
            let blocksOffset = builder.createVector(ofOffsets: blocksOffsets, len: blocksOffsets.count)
            let numberOffset = number.map { builder.create(string: $0) } ?? Offset()

            let start = TelegramCore_InstantPageListItem_Blocks.startInstantPageListItem_Blocks(&builder)
            TelegramCore_InstantPageListItem_Blocks.addVectorOf(blocks: blocksOffset, &builder)
            if let _ = number {
                TelegramCore_InstantPageListItem_Blocks.add(number: numberOffset, &builder)
            }
            if let triState = InstantPageListItem.triState(fromChecked: checked) {
                TelegramCore_InstantPageListItem_Blocks.add(checkState: triState, &builder)
            }
            offset = TelegramCore_InstantPageListItem_Blocks.endInstantPageListItem_Blocks(&builder, start: start)
        case .unknown:
            valueType = .instantpagelistitemUnknown
            let start = TelegramCore_InstantPageListItem_Unknown.startInstantPageListItem_Unknown(&builder)
            offset = TelegramCore_InstantPageListItem_Unknown.endInstantPageListItem_Unknown(&builder, start: start)
        }
        
        let start = TelegramCore_InstantPageListItem.startInstantPageListItem(&builder)
        TelegramCore_InstantPageListItem.add(valueType: valueType, &builder)
        TelegramCore_InstantPageListItem.add(value: offset, &builder)
        return TelegramCore_InstantPageListItem.endInstantPageListItem(&builder, start: start)
    }
}

/// Horizontal placement of a `pageBlockButtonRow`'s pills, from the block's three schema flag bits
/// (`align_left:flags.0`, `align_center:flags.1`, `align_right:flags.2`).
///
/// `justify == 0` is load-bearing. A page cached before this field existed decodes as 0 in both
/// codecs, and 0 is exactly the stretch-to-fill layout those pages were rendered with — so honouring
/// the bits needs no cache migration.
public enum InstantPageButtonRowAlignment: Int32 {
    case justify = 0
    case left = 1
    case center = 2
    case right = 3
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
    
    public init(flatBuffersObject: TelegramCore_InstantPageTableCell) throws {
        self.text = try flatBuffersObject.text.map { try RichText(flatBuffersObject: $0) }
        self.header = flatBuffersObject.header
        self.alignment = TableHorizontalAlignment(rawValue: flatBuffersObject.alignment) ?? .left
        self.verticalAlignment = TableVerticalAlignment(rawValue: flatBuffersObject.verticalAlignment) ?? .top
        self.colspan = flatBuffersObject.colspan
        self.rowspan = flatBuffersObject.rowspan
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let textOffset = text.map { $0.encodeToFlatBuffers(builder: &builder) } ?? Offset()
        
        let start = TelegramCore_InstantPageTableCell.startInstantPageTableCell(&builder)
        if let _ = text {
            TelegramCore_InstantPageTableCell.add(text: textOffset, &builder)
        }
        TelegramCore_InstantPageTableCell.add(header: header, &builder)
        TelegramCore_InstantPageTableCell.add(alignment: alignment.rawValue, &builder)
        TelegramCore_InstantPageTableCell.add(verticalAlignment: verticalAlignment.rawValue, &builder)
        TelegramCore_InstantPageTableCell.add(colspan: colspan, &builder)
        TelegramCore_InstantPageTableCell.add(rowspan: rowspan, &builder)
        return TelegramCore_InstantPageTableCell.endInstantPageTableCell(&builder, start: start)
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
    
    public init(flatBuffersObject: TelegramCore_InstantPageTableRow) throws {
        self.cells = try (0 ..< flatBuffersObject.cellsCount).map { i in
            return try InstantPageTableCell(flatBuffersObject: flatBuffersObject.cells(at: i)!)
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let cellsOffsets = cells.map { $0.encodeToFlatBuffers(builder: &builder) }
        let cellsOffset = builder.createVector(ofOffsets: cellsOffsets, len: cellsOffsets.count)
        
        let start = TelegramCore_InstantPageTableRow.startInstantPageTableRow(&builder)
        TelegramCore_InstantPageTableRow.addVectorOf(cells: cellsOffset, &builder)
        return TelegramCore_InstantPageTableRow.endInstantPageTableRow(&builder, start: start)
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
    
    public init(flatBuffersObject: TelegramCore_InstantPageRelatedArticle) throws {
        self.url = flatBuffersObject.url
        self.webpageId = MediaId(flatBuffersObject.webpageId)
        self.title = flatBuffersObject.title
        self.description = flatBuffersObject.description
        self.photoId = flatBuffersObject.photoId.flatMap(MediaId.init)
        self.author = flatBuffersObject.author
        self.date = flatBuffersObject.date == Int32.min ? nil : flatBuffersObject.date
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let urlOffset = builder.create(string: url)
        let titleOffset = title.map { builder.create(string: $0) }
        let descriptionOffset = description.map { builder.create(string: $0) }
        let authorOffset = author.map { builder.create(string: $0) }
        
        let start = TelegramCore_InstantPageRelatedArticle.startInstantPageRelatedArticle(&builder)
        TelegramCore_InstantPageRelatedArticle.add(url: urlOffset, &builder)
        TelegramCore_InstantPageRelatedArticle.add(webpageId: webpageId.asFlatBuffersObject(), &builder)
        if let titleOffset {
            TelegramCore_InstantPageRelatedArticle.add(title: titleOffset, &builder)
        }
        if let descriptionOffset {
            TelegramCore_InstantPageRelatedArticle.add(description: descriptionOffset, &builder)
        }
        if let photoId {
            TelegramCore_InstantPageRelatedArticle.add(photoId: photoId.asFlatBuffersObject(), &builder)
        }
        if let authorOffset {
            TelegramCore_InstantPageRelatedArticle.add(author: authorOffset, &builder)
        }
        if let date {
            TelegramCore_InstantPageRelatedArticle.add(date: date, &builder)
        } else {
            TelegramCore_InstantPageRelatedArticle.add(date: Int32.min, &builder)
        }
        return TelegramCore_InstantPageRelatedArticle.endInstantPageRelatedArticle(&builder, start: start)
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
        
        #if DEBUG && false
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = self.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        let serializedData = builder.data
        var byteBuffer = ByteBuffer(data: serializedData)
        let deserializedValue = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_InstantPage
        let parsedValue = try! InstantPage(flatBuffersObject: deserializedValue)
        assert(self == parsedValue)
        #endif
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
    
    public init(flatBuffersObject: TelegramCore_InstantPage) throws {
        self.blocks = try (0 ..< flatBuffersObject.blocksCount).map { i in
            return try InstantPageBlock(flatBuffersObject: flatBuffersObject.blocks(at: i)!)
        }
        
        var media: [MediaId: Media] = [:]
        for i in 0 ..< flatBuffersObject.mediaCount {
            let parsedMedia = try TelegramMedia_parse(flatBuffersObject: flatBuffersObject.media(at: i)!)
            if let id = parsedMedia.id {
                media[id] = parsedMedia
            }
        }
        self.media = media
        
        self.isComplete = flatBuffersObject.isComplete
        self.rtl = flatBuffersObject.rtl
        self.url = flatBuffersObject.url
        self.views = flatBuffersObject.views == Int32.min ? nil : flatBuffersObject.views
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let blocksOffsets = self.blocks.map { block in
            return block.encodeToFlatBuffers(builder: &builder)
        }
        let blocksOffset = builder.createVector(ofOffsets: blocksOffsets, len: blocksOffsets.count)
        
        var mediaOffsets: [Offset] = []
        for (_, media) in self.media.sorted(by: { $0.key < $1.key }) {
            if let offset = TelegramMedia_serialize(media: media, flatBuffersBuilder: &builder) {
                mediaOffsets.append(offset)
            }
        }
        
        let mediaOffset = builder.createVector(ofOffsets: mediaOffsets, len: mediaOffsets.count)
        
        let urlOffset = builder.create(string: self.url)
        
        let start = TelegramCore_InstantPage.startInstantPage(&builder)
        
        TelegramCore_InstantPage.addVectorOf(blocks: blocksOffset, &builder)
        TelegramCore_InstantPage.addVectorOf(media: mediaOffset, &builder)
        TelegramCore_InstantPage.add(isComplete: self.isComplete, &builder)
        TelegramCore_InstantPage.add(rtl: self.rtl, &builder)
        TelegramCore_InstantPage.add(url: urlOffset, &builder)
        TelegramCore_InstantPage.add(views: self.views ?? Int32.min, &builder)
        
        return TelegramCore_InstantPage.endInstantPage(&builder, start: start)
    }
}

public extension InstantPage {
    /// A plain-text projection of the page's text-bearing blocks, used as the
    /// old-client text fallback when a draft is carried as an `InstantPage`.
    ///
    /// Only `.paragraph`, `.preformatted` and `.blockQuote` contribute text;
    /// every other block (drafts never contain them) is treated as empty.
    /// Empty pieces are skipped before joining so there are no leading,
    /// trailing or doubled `"\n"` separators.
    var plainText: String {
        return InstantPage.blocksPlainText(self.blocks)
    }

    private static func blocksPlainText(_ blocks: [InstantPageBlock]) -> String {
        var pieces: [String] = []
        for block in blocks {
            let text: String
            switch block {
            case let .paragraph(t):
                text = t.plainText
            case let .preformatted(t, _):
                text = t.plainText
            case let .blockQuote(blocks, _, _):
                text = blocksPlainText(blocks)
            default:
                text = ""
            }
            if !text.isEmpty {
                pieces.append(text)
            }
        }
        return pieces.joined(separator: "\n")
    }
}

private extension InstantPageBlock {
    func allMedia(mediaDict: [MediaId: Media]) -> [Media] {
        switch self {
        case let .audio(id, _), let .document(id, _):
            // NOTE: this switch ends in `default:`, so omitting .document here would compile and
            // then silently stop the page from fetching the file.
            if let file = mediaDict[id] {
                return [file]
            } else {
                return []
            }
        case let .collage(items, _):
            var result: [Media] = []
            for item in items {
                result.append(contentsOf: item.allMedia(mediaDict: mediaDict))
            }
            return result
        case let .cover(block):
            return block.allMedia(mediaDict: mediaDict)
        case let .details(_, blocks, _):
            var result: [Media] = []
            for item in blocks {
                result.append(contentsOf: item.allMedia(mediaDict: mediaDict))
            }
            return result
        case let .image(id, _, _, _, _):
            if let image = mediaDict[id] {
                return [image]
            } else {
                return []
            }
        case let .list(items, _):
            for item in items {
                switch item {
                case let .blocks(blocks, _, _):
                    var result: [Media] = []
                    for block in blocks {
                        result.append(contentsOf: block.allMedia(mediaDict: mediaDict))
                    }
                    return result
                case .text, .unknown:
                    break
                }
            }
            return []
        case let .slideshow(items, _):
            var result: [Media] = []
            for item in items {
                result.append(contentsOf: item.allMedia(mediaDict: mediaDict))
            }
            return result
        case let .video(id, _, _, _, _):
            if let video = mediaDict[id] {
                return [video]
            } else {
                return []
            }
        default:
            return []
        }
    }
}

public extension InstantPage {
    func allMedia() -> [Media] {
        if self.media.isEmpty {
            return []
        }
        var result: [Media] = []
        for block in self.blocks {
            result.append(contentsOf: block.allMedia(mediaDict: self.media))
        }
        return result
    }
}

public extension InstantPage {
    struct Accessor: Equatable {
        let _wrappedInstantPage: InstantPage?
        let _wrapped: TelegramCore_InstantPage?
        let _wrappedData: Data?
        
        public init(_ wrapped: TelegramCore_InstantPage, _ _wrappedData: Data) {
            self._wrapped = wrapped
            self._wrappedData = _wrappedData
            self._wrappedInstantPage = nil
        }
        
        public init(_ wrapped: InstantPage) {
            self._wrapped = nil
            self._wrappedData = nil
            self._wrappedInstantPage = wrapped
        }
        
        public func _parse() -> InstantPage {
            if let _wrappedInstantPage = self._wrappedInstantPage {
                return _wrappedInstantPage
            } else {
                return try! InstantPage(flatBuffersObject: self._wrapped!)
            }
        }
        
        public static func ==(lhs: InstantPage.Accessor, rhs: InstantPage.Accessor) -> Bool {
            if let lhsWrappedInstantPage = lhs._wrappedInstantPage, let rhsWrappedInstantPage = rhs._wrappedInstantPage {
                return lhsWrappedInstantPage == rhsWrappedInstantPage
            } else if let lhsWrappedData = lhs._wrappedData, let rhsWrappedData = rhs._wrappedData {
                return lhsWrappedData == rhsWrappedData
            } else {
                return lhs._parse() == rhs._parse()
            }
        }
    }
}

public extension InstantPage.Accessor {
    struct MediaIterator: Sequence, IteratorProtocol {
        private let accessor: InstantPage.Accessor
        private var wrappedInstantPageIterator: Dictionary<MediaId, Media>.Iterator?
        private var wrappedCurrentIndex: Int32 = 0
        
        init(_ accessor: InstantPage.Accessor) {
            self.accessor = accessor
            
            if let wrappedInstantPage = accessor._wrappedInstantPage {
                self.wrappedInstantPageIterator = wrappedInstantPage.media.makeIterator()
            } else {
                self.wrappedInstantPageIterator = nil
            }
        }

        mutating public func next() -> (MediaId, TelegramMedia.Accessor)? {
            if self.wrappedInstantPageIterator != nil {
                guard let (id, value) = self.wrappedInstantPageIterator!.next() else {
                    return nil
                }
                return (id, TelegramMedia.Accessor(value))
            }
            
            if self.wrappedCurrentIndex >= self.accessor._wrapped!.mediaCount {
                return nil
            }
            let index = self.wrappedCurrentIndex
            self.wrappedCurrentIndex += 1
            let media = self.accessor._wrapped!.media(at: index)!
            let parsedMedia = TelegramMedia.Accessor(media)
            if let id = parsedMedia.id {
                return (id, parsedMedia)
            } else {
                return nil
            }
        }
    }
    
    var isComplete: Bool {
        if let wrappedInstantPage = self._wrappedInstantPage {
            return wrappedInstantPage.isComplete
        }
        
        return self._wrapped!.isComplete
    }
    
    var media: MediaIterator {
        return MediaIterator(self)
    }
    
    var views: Int32? {
        if let wrappedInstantPage = self._wrappedInstantPage {
            return wrappedInstantPage.views
        }
        
        return self._wrapped!.views == Int32.min ? nil : self._wrapped!.views
    }
    
    var url: String {
        if let wrappedInstantPage = self._wrappedInstantPage {
            return wrappedInstantPage.url
        }
        
        return self._wrapped!.url
    }
    
    var rtl: Bool {
        if let wrappedInstantPage = self._wrappedInstantPage {
            return wrappedInstantPage.rtl
        }
        
        return self._wrapped!.rtl
    }
}
