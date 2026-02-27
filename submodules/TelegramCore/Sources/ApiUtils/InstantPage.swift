import Foundation
import Postbox
import TelegramApi


extension InstantPageCaption {
    convenience init(apiCaption: Api.PageCaption) {
        switch apiCaption {
            case let .pageCaption(pageCaptionData):
                let (text, credit) = (pageCaptionData.text, pageCaptionData.credit)
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
            case let .pageListItemText(pageListItemTextData):
                let text = pageListItemTextData.text
                self = .text(RichText(apiText: text), nil)
            case let .pageListItemBlocks(pageListItemBlocksData):
                let blocks = pageListItemBlocksData.blocks
                self = .blocks(blocks.map({ InstantPageBlock(apiBlock: $0) }), nil)
        }
    }
    
    init(apiListOrderedItem: Api.PageListOrderedItem) {
        switch apiListOrderedItem {
            case let .pageListOrderedItemText(pageListOrderedItemTextData):
                let (num, text) = (pageListOrderedItemTextData.num, pageListOrderedItemTextData.text)
                self = .text(RichText(apiText: text), num)
            case let .pageListOrderedItemBlocks(pageListOrderedItemBlocksData):
                let (num, blocks) = (pageListOrderedItemBlocksData.num, pageListOrderedItemBlocksData.blocks)
                self = .blocks(blocks.map({ InstantPageBlock(apiBlock: $0) }), num)
        }
    }
}

extension InstantPageTableCell {
    convenience init(apiTableCell: Api.PageTableCell) {
        switch apiTableCell {
            case let .pageTableCell(pageTableCellData):
                let (flags, text, colspan, rowspan) = (pageTableCellData.flags, pageTableCellData.text, pageTableCellData.colspan, pageTableCellData.rowspan)
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
            case let .pageTableRow(pageTableRowData):
                let cells = pageTableRowData.cells
                self.init(cells: cells.map({ InstantPageTableCell(apiTableCell: $0) }))
        }
    }
}

extension InstantPageRelatedArticle {
    convenience init(apiRelatedArticle: Api.PageRelatedArticle) {
        switch apiRelatedArticle {
            case let .pageRelatedArticle(pageRelatedArticleData):
                let (url, webpageId, title, description, photoId, author, publishedDate) = (pageRelatedArticleData.url, pageRelatedArticleData.webpageId, pageRelatedArticleData.title, pageRelatedArticleData.description, pageRelatedArticleData.photoId, pageRelatedArticleData.author, pageRelatedArticleData.publishedDate)
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
            case let .pageBlockTitle(pageBlockTitleData):
                let text = pageBlockTitleData.text
                self = .title(RichText(apiText: text))
            case let .pageBlockSubtitle(pageBlockSubtitleData):
                let text = pageBlockSubtitleData.text
                self = .subtitle(RichText(apiText: text))
            case let .pageBlockAuthorDate(pageBlockAuthorDateData):
                let (author, publishedDate) = (pageBlockAuthorDateData.author, pageBlockAuthorDateData.publishedDate)
                self = .authorDate(author: RichText(apiText: author), date: publishedDate)
            case let .pageBlockHeader(pageBlockHeaderData):
                let text = pageBlockHeaderData.text
                self = .header(RichText(apiText: text))
            case let .pageBlockSubheader(pageBlockSubheaderData):
                let text = pageBlockSubheaderData.text
                self = .subheader(RichText(apiText: text))
            case let .pageBlockParagraph(pageBlockParagraphData):
                let text = pageBlockParagraphData.text
                self = .paragraph(RichText(apiText: text))
            case let .pageBlockPreformatted(pageBlockPreformattedData):
                let text = pageBlockPreformattedData.text
                self = .preformatted(RichText(apiText: text))
            case let .pageBlockFooter(pageBlockFooterData):
                let text = pageBlockFooterData.text
                self = .footer(RichText(apiText: text))
            case .pageBlockDivider:
                self = .divider
            case let .pageBlockAnchor(pageBlockAnchorData):
                let name = pageBlockAnchorData.name
                self = .anchor(name)
            case let .pageBlockBlockquote(pageBlockBlockquoteData):
                let (text, caption) = (pageBlockBlockquoteData.text, pageBlockBlockquoteData.caption)
                self = .blockQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPullquote(pageBlockPullquoteData):
                let (text, caption) = (pageBlockPullquoteData.text, pageBlockPullquoteData.caption)
                self = .pullQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPhoto(pageBlockPhotoData):
                let (flags, photoId, caption, url, webpageId) = (pageBlockPhotoData.flags, pageBlockPhotoData.photoId, pageBlockPhotoData.caption, pageBlockPhotoData.url, pageBlockPhotoData.webpageId)
                var webpageMediaId: MediaId?
                if (flags & (1 << 0)) != 0, let webpageId = webpageId, webpageId != 0 {
                    webpageMediaId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId)
                }
                self = .image(id: MediaId(namespace: Namespaces.Media.CloudImage, id: photoId), caption: InstantPageCaption(apiCaption: caption), url: url, webpageId: webpageMediaId)
            case let .pageBlockVideo(pageBlockVideoData):
                let (flags, videoId, caption) = (pageBlockVideoData.flags, pageBlockVideoData.videoId, pageBlockVideoData.caption)
                self = .video(id: MediaId(namespace: Namespaces.Media.CloudFile, id: videoId), caption: InstantPageCaption(apiCaption: caption), autoplay: (flags & (1 << 0)) != 0, loop: (flags & (1 << 1)) != 0)
            case let .pageBlockCover(pageBlockCoverData):
                let cover = pageBlockCoverData.cover
                self = .cover(InstantPageBlock(apiBlock: cover))
            case let .pageBlockEmbed(pageBlockEmbedData):
                let (flags, url, html, posterPhotoId, w, h, caption) = (pageBlockEmbedData.flags, pageBlockEmbedData.url, pageBlockEmbedData.html, pageBlockEmbedData.posterPhotoId, pageBlockEmbedData.w, pageBlockEmbedData.h, pageBlockEmbedData.caption)
                var dimensions: PixelDimensions?
                if let w = w, let h = h {
                    dimensions = PixelDimensions(width: w, height: h)
                }
                self = .webEmbed(url: url, html: html, dimensions: dimensions, caption: InstantPageCaption(apiCaption: caption), stretchToWidth: (flags & (1 << 0)) != 0, allowScrolling: (flags & (1 << 3)) != 0, coverId: posterPhotoId.flatMap { MediaId(namespace: Namespaces.Media.CloudImage, id: $0) })
            case let .pageBlockEmbedPost(pageBlockEmbedPostData):
                let (url, webpageId, authorPhotoId, author, date, blocks, caption) = (pageBlockEmbedPostData.url, pageBlockEmbedPostData.webpageId, pageBlockEmbedPostData.authorPhotoId, pageBlockEmbedPostData.author, pageBlockEmbedPostData.date, pageBlockEmbedPostData.blocks, pageBlockEmbedPostData.caption)
                self = .postEmbed(url: url, webpageId: webpageId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId), avatarId: authorPhotoId == 0 ? nil : MediaId(namespace: Namespaces.Media.CloudImage, id: authorPhotoId), author: author, date: date, blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockCollage(pageBlockCollageData):
                let (items, caption) = (pageBlockCollageData.items, pageBlockCollageData.caption)
                self = .collage(items: items.map({ InstantPageBlock(apiBlock: $0) }), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockSlideshow(pageBlockSlideshowData):
                let (items, caption) = (pageBlockSlideshowData.items, pageBlockSlideshowData.caption)
                self = .slideshow(items: items.map({ InstantPageBlock(apiBlock: $0) }), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockChannel(pageBlockChannelData):
                let apiChat = pageBlockChannelData.channel
                self = .channelBanner(parseTelegramGroupOrChannel(chat: apiChat) as? TelegramChannel)
            case let .pageBlockAudio(pageBlockAudioData):
                let (audioId, caption) = (pageBlockAudioData.audioId, pageBlockAudioData.caption)
                self = .audio(id: MediaId(namespace: Namespaces.Media.CloudFile, id: audioId), caption: InstantPageCaption(apiCaption: caption))
            case let .pageBlockKicker(pageBlockKickerData):
                let text = pageBlockKickerData.text
                self = .kicker(RichText(apiText: text))
            case let .pageBlockTable(pageBlockTableData):
                let (flags, title, rows) = (pageBlockTableData.flags, pageBlockTableData.title, pageBlockTableData.rows)
                self = .table(title: RichText(apiText: title), rows: rows.map({ InstantPageTableRow(apiTableRow: $0) }), bordered: (flags & (1 << 0)) != 0, striped: (flags & (1 << 1)) != 0)
            case let .pageBlockList(pageBlockListData):
                let items = pageBlockListData.items
                self = .list(items: items.map({ InstantPageListItem(apiListItem: $0) }), ordered: false)
            case let .pageBlockOrderedList(pageBlockOrderedListData):
                let items = pageBlockOrderedListData.items
                self = .list(items: items.map({ InstantPageListItem(apiListOrderedItem: $0) }), ordered: true)
            case let .pageBlockDetails(pageBlockDetailsData):
                let (flags, blocks, title) = (pageBlockDetailsData.flags, pageBlockDetailsData.blocks, pageBlockDetailsData.title)
                self = .details(title: RichText(apiText: title), blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), expanded: (flags & (1 << 0)) != 0)
            case let .pageBlockRelatedArticles(pageBlockRelatedArticlesData):
                let (title, articles) = (pageBlockRelatedArticlesData.title, pageBlockRelatedArticlesData.articles)
                self = .relatedArticles(title: RichText(apiText: title), articles: articles.map({ InstantPageRelatedArticle(apiRelatedArticle: $0) }))
            case let .pageBlockMap(pageBlockMapData):
                let (geo, zoom, w, h, caption) = (pageBlockMapData.geo, pageBlockMapData.zoom, pageBlockMapData.w, pageBlockMapData.h, pageBlockMapData.caption)
                switch geo {
                    case let .geoPoint(geoPointData):
                        let (long, lat) = (geoPointData.long, geoPointData.lat)
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
            case let .page(pageData):
                let (flags, pageUrl, pageBlocks, pagePhotos, pageDocuments, pageViews) = (pageData.flags, pageData.url, pageData.blocks, pageData.photos, pageData.documents, pageData.views)
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
            if let file = telegramMediaFileFromApiDocument(file, altDocuments: []), let id = file.id {
                media[id] = file
            }
        }
        self.init(blocks: blocks.map({ InstantPageBlock(apiBlock: $0) }), media: media, isComplete: isComplete, rtl: rtl, url: url, views: views)
    }
}
