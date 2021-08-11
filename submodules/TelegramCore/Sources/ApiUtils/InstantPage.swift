import Foundation
import Postbox
import TelegramApi


extension InstantPageCaption {
    convenience init(apiCaption: Api.PageCaption) {
        switch apiCaption {
            case let .pageCaption(text, credit):
                self.init(text: RichText(apiText: text), credit: RichText(apiText: credit))
        }
    }
}

public extension InstantPageListItem {
    var num: String? {
        switch self {
            case let .text(_, num):
                return num
            case let .blocks(_, num):
                return num
            default:
                return nil
        }
    }
}

extension InstantPageListItem {
    init(apiListItem: Api.PageListItem) {
        switch apiListItem {
            case let .pageListItemText(text):
                self = .text(RichText(apiText: text), nil)
            case let .pageListItemBlocks(blocks):
                self = .blocks(blocks.map({ InstantPageBlock(apiBlock: $0) }), nil)
        }
    }
    
    init(apiListOrderedItem: Api.PageListOrderedItem) {
        switch apiListOrderedItem {
            case let .pageListOrderedItemText(num, text):
                self = .text(RichText(apiText: text), num)
            case let .pageListOrderedItemBlocks(num, blocks):
                self = .blocks(blocks.map({ InstantPageBlock(apiBlock: $0) }), num)
        }
    }
}

extension InstantPageTableCell {
    convenience init(apiTableCell: Api.PageTableCell) {
        switch apiTableCell {
            case let .pageTableCell(flags, text, colspan, rowspan):
                var alignment = TableHorizontalAlignment.left
                if (flags & (1 << 3)) != 0 {
                    alignment = .center
                } else if (flags & (1 << 4)) != 0 {
                    alignment = .right
                }
                var verticalAlignment = TableVerticalAlignment.top
                if (flags & (1 << 5)) != 0 {
                    verticalAlignment = .middle
                } else if (flags & (1 << 6)) != 0 {
                    verticalAlignment = .bottom
                }
                self.init(text: text != nil ? RichText(apiText: text!) : nil, header: (flags & (1 << 0)) != 0, alignment: alignment, verticalAlignment: verticalAlignment, colspan: colspan ?? 0, rowspan: rowspan ?? 0)
        }
    }
}

extension InstantPageTableRow {
    convenience init(apiTableRow: Api.PageTableRow) {
        switch apiTableRow {
            case let .pageTableRow(cells):
                self.init(cells: cells.map({ InstantPageTableCell(apiTableCell: $0) }))
        }
    }
}

extension InstantPageRelatedArticle {
    convenience init(apiRelatedArticle: Api.PageRelatedArticle) {
        switch apiRelatedArticle {
            case let .pageRelatedArticle(_, url, webpageId, title, description, photoId, author, publishedDate):
                var posterPhotoId: MediaId?
                if let photoId = photoId {
                    posterPhotoId = MediaId(namespace: Namespaces.Media.CloudImage, id: photoId)
                }
                self.init(url: url, webpageId: MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId), title: title, description: description, photoId: posterPhotoId, author: author, date: publishedDate)
        }
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
                self = .authorDate(author: RichText(apiText: author), date: publishedDate)
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
            case let .pageBlockBlockquote(text, caption):
                self = .blockQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPullquote(text, caption):
                self = .pullQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPhoto(flags, photoId, caption, url, webpageId):
                var webpageMediaId: MediaId?
                if (flags & (1 << 0)) != 0, let webpageId = webpageId, webpageId != 0 {
                    webpageMediaId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId)
                }
                self = .image(id: MediaId(namespace: Namespaces.Media.CloudImage, id: photoId), caption: InstantPageCaption(apiCaption: caption), url: url, webpageId: webpageMediaId)
            case let .pageBlockVideo(flags, videoId, caption):
                self = .video(id: MediaId(namespace: Namespaces.Media.CloudFile, id: videoId), caption: InstantPageCaption(apiCaption: caption), autoplay: (flags & (1 << 0)) != 0, loop: (flags & (1 << 1)) != 0)
            case let .pageBlockCover(cover):
                self = .cover(InstantPageBlock(apiBlock: cover))
            case let .pageBlockEmbed(flags, url, html, posterPhotoId, w, h, caption):
                var dimensions: PixelDimensions?
                if let w = w, let h = h {
                    dimensions = PixelDimensions(width: w, height: h)
                }
                self = .webEmbed(url: url, html: html, dimensions: dimensions, caption: InstantPageCaption(apiCaption: caption), stretchToWidth: (flags & (1 << 0)) != 0, allowScrolling: (flags & (1 << 3)) != 0, coverId: posterPhotoId.flatMap { MediaId(namespace: Namespaces.Media.CloudImage, id: $0) })
            case let .pageBlockEmbedPost(url, webpageId, authorPhotoId, author, date, blocks, caption):
                self = .postEmbed(url: url, webpageId: webpageId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId), avatarId: authorPhotoId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudImage, id: authorPhotoId), author: author, date: date, blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockCollage(items, caption):
                self = .collage(items: items.map({ InstantPageBlock(apiBlock: $0) }), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockSlideshow(items, caption):
                self = .slideshow(items: items.map({ InstantPageBlock(apiBlock: $0) }), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockChannel(channel: apiChat):
                self = .channelBanner(parseTelegramGroupOrChannel(chat: apiChat) as? TelegramChannel)
            case let .pageBlockAudio(audioId, caption):
                self = .audio(id: MediaId(namespace: Namespaces.Media.CloudFile, id: audioId), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockKicker(text):
                self = .kicker(RichText(apiText: text))
            case let .pageBlockTable(flags, title, rows):
                self = .table(title: RichText(apiText: title), rows: rows.map({ InstantPageTableRow(apiTableRow: $0) }), bordered: (flags & (1 << 0)) != 0, striped: (flags & (1 << 1)) != 0)
            case let .pageBlockList(items):
                self = .list(items: items.map({ InstantPageListItem(apiListItem: $0) }), ordered: false)
            case let .pageBlockOrderedList(items):
                self = .list(items: items.map({ InstantPageListItem(apiListOrderedItem: $0) }), ordered: true)
            case let .pageBlockDetails(flags, blocks, title):
                self = .details(title: RichText(apiText: title), blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), expanded: (flags & (1 << 0)) != 0)
            case let .pageBlockRelatedArticles(title, articles):
                self = .relatedArticles(title: RichText(apiText: title), articles: articles.map({ InstantPageRelatedArticle(apiRelatedArticle: $0) }))
            case let .pageBlockMap(geo, zoom, w, h, caption):
                switch geo {
                    case let .geoPoint(_, long, lat, _, _):
                        self = .map(latitude: lat, longitude: long, zoom: zoom, dimensions: PixelDimensions(width: w, height: h), caption: InstantPageCaption(apiCaption: caption))
                    default:
                        self = .unsupported
                }
        }
    }
}

extension InstantPage {
    convenience init(apiPage: Api.Page) {
        let blocks: [Api.PageBlock]
        let photos: [Api.Photo]
        let files: [Api.Document]
        let isComplete: Bool
        let rtl: Bool
        let url: String
        let views: Int32?
        switch apiPage {
            case let .page(flags, pageUrl, pageBlocks, pagePhotos, pageDocuments, pageViews):
                url = pageUrl
                blocks = pageBlocks
                photos = pagePhotos
                files = pageDocuments
                isComplete = (flags & (1 << 0)) == 0
                rtl = (flags & (1 << 1)) != 0
                views = pageViews
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
        self.init(blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), media: media, isComplete: isComplete, rtl: rtl, url: url, views: views)
    }
}
