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
            case let .text(_, num, _):
                return num
            case let .blocks(_, num, _):
                return num
            default:
                return nil
        }
    }

    var checked: Bool? {
        switch self {
            case let .text(_, _, checked):
                return checked
            case let .blocks(_, _, checked):
                return checked
            default:
                return nil
        }
    }

    static func checkedFromApiFlags(_ flags: Int32) -> Bool? {
        guard (flags & (1 << 0)) != 0 else {
            return nil
        }
        return (flags & (1 << 1)) != 0
    }

    static func apiFlags(fromChecked checked: Bool?) -> Int32 {
        guard let checked else {
            return 0
        }
        var flags: Int32 = 1 << 0
        if checked {
            flags |= (1 << 1)
        }
        return flags
    }
}

extension InstantPageListItem {
    init(apiListItem: Api.PageListItem) {
        switch apiListItem {
            case let .pageListItemText(pageListItemTextData):
                let text = pageListItemTextData.text
                self = .text(RichText(apiText: text), nil, InstantPageListItem.checkedFromApiFlags(pageListItemTextData.flags))
            case let .pageListItemBlocks(pageListItemBlocksData):
                let blocks = pageListItemBlocksData.blocks
                self = .blocks(blocks.map({ InstantPageBlock(apiBlock: $0) }), nil, InstantPageListItem.checkedFromApiFlags(pageListItemBlocksData.flags))
        }
    }
    
    init(apiListOrderedItem: Api.PageListOrderedItem) {
        switch apiListOrderedItem {
            case let .pageListOrderedItemText(pageListOrderedItemTextData):
                let (num, text) = (pageListOrderedItemTextData.num, pageListOrderedItemTextData.text)
                self = .text(RichText(apiText: text), num, InstantPageListItem.checkedFromApiFlags(pageListOrderedItemTextData.flags))
            case let .pageListOrderedItemBlocks(pageListOrderedItemBlocksData):
                let (num, blocks) = (pageListOrderedItemBlocksData.num, pageListOrderedItemBlocksData.blocks)
                self = .blocks(blocks.map({ InstantPageBlock(apiBlock: $0) }), num, InstantPageListItem.checkedFromApiFlags(pageListOrderedItemBlocksData.flags))
        }
    }
    
    func apiInputPageListItem() -> Api.PageListItem {
        switch self {
        case let .text(value, _, checked):
            return .pageListItemText(Api.PageListItem.Cons_pageListItemText(flags: InstantPageListItem.apiFlags(fromChecked: checked), text: value.apiRichText()))
        case let .blocks(blocks, _, checked):
            return .pageListItemBlocks(Api.PageListItem.Cons_pageListItemBlocks(flags: InstantPageListItem.apiFlags(fromChecked: checked), blocks: blocks.compactMap { $0.apiInputBlock() }))
        case .unknown:
            return .pageListItemText(Api.PageListItem.Cons_pageListItemText(flags: 0, text: .textPlain(Api.RichText.Cons_textPlain(text: ""))))
        }
    }
    
    func apiInputPageOrderedListItem() -> Api.PageListOrderedItem {
        switch self {
        case let .text(value, num, checked):
            var flags: Int32 = InstantPageListItem.apiFlags(fromChecked: checked)

            if num != nil {
                flags |= (1 << 2)
            }
            return .pageListOrderedItemText(Api.PageListOrderedItem.Cons_pageListOrderedItemText(flags: flags, num: num, text: value.apiRichText(), value: nil, type: nil))
        case let .blocks(blocks, num, checked):
            var flags: Int32 = InstantPageListItem.apiFlags(fromChecked: checked)

            if num != nil {
                flags |= (1 << 2)
            }

            return .pageListOrderedItemBlocks(Api.PageListOrderedItem.Cons_pageListOrderedItemBlocks(flags: flags, num: num, blocks: blocks.compactMap { $0.apiInputBlock() }, value: nil, type: nil))
        case .unknown:
            return .pageListOrderedItemText(Api.PageListOrderedItem.Cons_pageListOrderedItemText(flags: 0, num: nil, text: .textPlain(Api.RichText.Cons_textPlain(text: "")), value: nil, type: nil))
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
    
    func inputPageTableCell() -> Api.PageTableCell {
        var flags: Int32 = 0
        
        switch self.alignment {
        case .left:
            break
        case .center:
            flags |= (1 << 3)
        case .right:
            flags |= (1 << 4)
        }
        
        switch self.verticalAlignment {
        case .top:
            break
        case .middle:
            flags |= (1 << 5)
        case .bottom:
            flags |= (1 << 6)
        }
        
        if self.header {
            flags |= (1 << 0)
        }
        
        var inputText: Api.RichText?
        if let text = self.text {
            inputText = text.apiRichText()
            if inputText != nil {
                flags |= (1 << 7)
            }
        }
        
        var inputColspan: Int32?
        if self.colspan != 0 {
            inputColspan = self.colspan
            flags |= (1 << 1)
        }
        
        var inputRowspan: Int32?
        if self.rowspan != 0 {
            inputRowspan = self.rowspan
            flags |= (1 << 2)
        }
        
        return .pageTableCell(Api.PageTableCell.Cons_pageTableCell(flags: flags, text: inputText, colspan: inputColspan, rowspan: inputRowspan))
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
    
    func inputPageTableRow() -> Api.PageTableRow {
        return .pageTableRow(Api.PageTableRow.Cons_pageTableRow(cells: self.cells.map { $0.inputPageTableCell() }))
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
            case let .pageBlockButtonRow(data):
                self = .buttonRow(alignment: InstantPageButtonRowAlignment(apiFlags: data.flags), buttons: data.buttons.map(InstantPageButton.init(apiButton:)))
            case let .pageBlockDocument(data):
                self = .document(id: MediaId(namespace: Namespaces.Media.CloudFile, id: data.documentId), caption: InstantPageCaption(apiCaption: data.caption))
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
                // The wire carries the code block's language and this dropped it, hard-coding nil, while
                // the outgoing side below sends it — so a page survived a send and came back
                // language-less. Empty means "none", matching what `apiBlock()` writes for nil.
                let language = pageBlockPreformattedData.language
                self = .preformatted(text: RichText(apiText: text), language: language.isEmpty ? nil : language)
            case let .pageBlockFooter(pageBlockFooterData):
                let text = pageBlockFooterData.text
                self = .footer(RichText(apiText: text))
            case .pageBlockDivider:
                self = .divider
            case let .pageBlockAnchor(pageBlockAnchorData):
                let name = pageBlockAnchorData.name
                self = .anchor(name)
            case let .pageBlockBlockquote(pageBlockBlockquoteData):
                let (flags, text, caption) = (pageBlockBlockquoteData.flags, pageBlockBlockquoteData.text, pageBlockBlockquoteData.caption)
                self = .blockQuote(blocks: [.paragraph(RichText(apiText: text))], caption: RichText(apiText: caption), collapsed: (flags & (1 << 0)) != 0)
            case let .pageBlockBlockquoteBlocks(pageBlockBlockquoteBlocksData):
                // `pageBlockBlockquoteBlocks` has no `collapsed` flag, so a quote arriving in this form is
                // not collapsed as far as the wire is concerned — `false`, not "unknown". Keeping every
                // cloud-received quote non-nil is what lets `==` read the field without spurious inequality
                // against locally-composed blocks (which always hold a concrete Bool).
                self = .blockQuote(blocks: pageBlockBlockquoteBlocksData.blocks.map { InstantPageBlock(apiBlock: $0) }, caption: RichText(apiText: pageBlockBlockquoteBlocksData.caption), collapsed: false)
            case let .pageBlockPullquote(pageBlockPullquoteData):
                let (text, caption) = (pageBlockPullquoteData.text, pageBlockPullquoteData.caption)
                self = .pullQuote(text: RichText(apiText: text), caption: RichText(apiText: caption))
            case let .pageBlockPhoto(pageBlockPhotoData):
                let (flags, photoId, caption, url, webpageId) = (pageBlockPhotoData.flags, pageBlockPhotoData.photoId, pageBlockPhotoData.caption, pageBlockPhotoData.url, pageBlockPhotoData.webpageId)
                var webpageMediaId: MediaId?
                if (flags & (1 << 0)) != 0, let webpageId = webpageId, webpageId != 0 {
                    webpageMediaId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: webpageId)
                }
                self = .image(id: MediaId(namespace: Namespaces.Media.CloudImage, id: photoId), caption: InstantPageCaption(apiCaption: caption), url: url, webpageId: webpageMediaId, spoiler: (flags & (1 << 1)) != 0)
            case let .pageBlockVideo(pageBlockVideoData):
                let (flags, videoId, caption) = (pageBlockVideoData.flags, pageBlockVideoData.videoId, pageBlockVideoData.caption)
                self = .video(id: MediaId(namespace: Namespaces.Media.CloudFile, id: videoId), caption: InstantPageCaption(apiCaption: caption), autoplay: (flags & (1 << 0)) != 0, loop: (flags & (1 << 1)) != 0, spoiler: (flags & (1 << 2)) != 0)
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
                self = .table(title: RichText(apiText: title), rows: rows.map({ InstantPageTableRow(apiTableRow: $0) }), bordered: (flags & (1 << 0)) != 0, striped: (flags & (1 << 1)) != 0, compact: (flags & (1 << 2)) != 0)
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
            case let .pageBlockHeading1(pageBlockHeading1):
                self = .heading(text: RichText(apiText: pageBlockHeading1.text), level: 1)
            case let .pageBlockHeading2(pageBlockHeading2):
                self = .heading(text: RichText(apiText: pageBlockHeading2.text), level: 2)
            case let .pageBlockHeading3(pageBlockHeading3):
                self = .heading(text: RichText(apiText: pageBlockHeading3.text), level: 3)
            case let .pageBlockHeading4(pageBlockHeading4):
                self = .heading(text: RichText(apiText: pageBlockHeading4.text), level: 4)
            case let .pageBlockHeading5(pageBlockHeading5):
                self = .heading(text: RichText(apiText: pageBlockHeading5.text), level: 5)
            case let .pageBlockHeading6(pageBlockHeading6):
                self = .heading(text: RichText(apiText: pageBlockHeading6.text), level: 6)
            case let .pageBlockMath(pageBlockMath):
                self = .formula(latex: pageBlockMath.source)
            case let .pageBlockThinking(pageBlockThinking):
                self = .thinking(RichText(apiText: pageBlockThinking.text))
            case .inputPageBlockMap:
                self = .unsupported
        }
    }
    
    func apiInputBlock() -> Api.PageBlock? {
        return self.apiInputBlock(mediaIdRemap: [:])
    }

    func apiInputBlock(mediaIdRemap: [MediaId: Int64]) -> Api.PageBlock? {
        switch self {
        case .unsupported, .title, .subtitle, .kicker, .header, .subheader, .cover, .channelBanner, .authorDate, .relatedArticles, .webEmbed, .postEmbed, .thinking:
            return nil
        case let .heading(text, level):
            let block: Api.PageBlock
            switch level {
            case 0, 1:
                block = .pageBlockHeading1(Api.PageBlock.Cons_pageBlockHeading1(text: text.apiRichText()))
            case 2:
                block = .pageBlockHeading2(Api.PageBlock.Cons_pageBlockHeading2(text: text.apiRichText()))
            case 3:
                block = .pageBlockHeading3(Api.PageBlock.Cons_pageBlockHeading3(text: text.apiRichText()))
            case 4:
                block = .pageBlockHeading4(Api.PageBlock.Cons_pageBlockHeading4(text: text.apiRichText()))
            case 5:
                block = .pageBlockHeading5(Api.PageBlock.Cons_pageBlockHeading5(text: text.apiRichText()))
            default:
                block = .pageBlockHeading6(Api.PageBlock.Cons_pageBlockHeading6(text: text.apiRichText()))
            }
            return block
        case let .formula(latex):
            return .pageBlockMath(Api.PageBlock.Cons_pageBlockMath(source: latex))
        case let .paragraph(value):
            return .pageBlockParagraph(Api.PageBlock.Cons_pageBlockParagraph(text: value.apiRichText()))
        case let .preformatted(text, language):
            return .pageBlockPreformatted(Api.PageBlock.Cons_pageBlockPreformatted(text: text.apiRichText(), language: language ?? ""))
        case let .footer(value):
            return .pageBlockFooter(Api.PageBlock.Cons_pageBlockFooter(text: value.apiRichText()))
        case .divider:
            return .pageBlockDivider
        case let .anchor(value):
            return .pageBlockAnchor(Api.PageBlock.Cons_pageBlockAnchor(name: value))
        case let .list(items, ordered):
            if ordered {
                return .pageBlockOrderedList(Api.PageBlock.Cons_pageBlockOrderedList(flags: 0, items: items.map { $0.apiInputPageOrderedListItem() }, start: nil, type: nil))
            } else {
                return .pageBlockList(Api.PageBlock.Cons_pageBlockList(items: items.map { $0.apiInputPageListItem() }))
            }
        case let .blockQuote(blocks, caption, collapsed):
            let quoteFlags: Int32 = collapsed == true ? (1 << 0) : 0
            if blocks.isEmpty {
                return .pageBlockBlockquote(Api.PageBlock.Cons_pageBlockBlockquote(flags: quoteFlags, text: RichText.empty.apiRichText(), caption: caption.apiRichText()))
            }
            if blocks.count == 1, case let .paragraph(text) = blocks[0] {
                return .pageBlockBlockquote(Api.PageBlock.Cons_pageBlockBlockquote(flags: quoteFlags, text: text.apiRichText(), caption: caption.apiRichText()))
            }
            // `pageBlockBlockquoteBlocks` has no `collapsed` flag in the schema, so a multi-block quote
            // sends without it and arrives expanded. Not an oversight — see the "Known gap" section of
            // docs/superpowers/specs/2026-07-31-inline-button-split-and-blockquote-collapsed-design.md.
            // Fixing it needs `pageBlockBlockquoteBlocks flags:# collapsed:flags.0?true` server-side.
            return .pageBlockBlockquoteBlocks(Api.PageBlock.Cons_pageBlockBlockquoteBlocks(blocks: blocks.compactMap { $0.apiInputBlock(mediaIdRemap: mediaIdRemap) }, caption: caption.apiRichText()))
        case let .pullQuote(text, caption):
            return .pageBlockPullquote(Api.PageBlock.Cons_pageBlockPullquote(text: text.apiRichText(), caption: caption.apiRichText()))
        case let .image(id, caption, url, webpageId, spoiler):
            var flags: Int32 = 0
            if url != nil && webpageId != nil {
                flags |= 1 << 0
            }
            if spoiler {
                flags |= 1 << 1
            }
            let photoId = mediaIdRemap[id] ?? id.id
            return .pageBlockPhoto(Api.PageBlock.Cons_pageBlockPhoto(flags: flags, photoId: photoId, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText())), url: url, webpageId: webpageId?.id))
        case let .video(id, caption, autoplay, loop, spoiler):
            var flags: Int32 = 0
            if autoplay {
                flags |= 1 << 0
            }
            if loop {
                flags |= 1 << 1
            }
            if spoiler {
                flags |= 1 << 2
            }
            let videoId = mediaIdRemap[id] ?? id.id
            return .pageBlockVideo(Api.PageBlock.Cons_pageBlockVideo(flags: flags, videoId: videoId, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText()))))
        case let .audio(id, caption):
            let audioId = mediaIdRemap[id] ?? id.id
            return .pageBlockAudio(Api.PageBlock.Cons_pageBlockAudio(audioId: audioId, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText()))))
        case let .document(id, caption):
            // Same media-id remap as .audio: on send, local ids are rewritten to cloud ids.
            let documentId = mediaIdRemap[id] ?? id.id
            return .pageBlockDocument(Api.PageBlock.Cons_pageBlockDocument(documentId: documentId, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText()))))
        case let .buttonRow(alignment, buttons):
            return .pageBlockButtonRow(Api.PageBlock.Cons_pageBlockButtonRow(flags: alignment.apiFlags, buttons: buttons.map { $0.apiPageButton() }))
        case let .collage(items, caption):
            return .pageBlockCollage(Api.PageBlock.Cons_pageBlockCollage(items: items.compactMap { $0.apiInputBlock(mediaIdRemap: mediaIdRemap) }, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText()))))
        case let .slideshow(items, caption):
            return .pageBlockSlideshow(Api.PageBlock.Cons_pageBlockSlideshow(items: items.compactMap { $0.apiInputBlock(mediaIdRemap: mediaIdRemap) }, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText()))))
        case let .table(title, rows, bordered, striped, compact):
            var flags: Int32 = 0
            if bordered {
                flags |= (1 << 0)
            }
            if striped {
                flags |= (1 << 1)
            }
            if compact {
                flags |= (1 << 2)
            }
            return .pageBlockTable(Api.PageBlock.Cons_pageBlockTable(flags: flags, title: title.apiRichText(), rows: rows.map { $0.inputPageTableRow() }))
        case let .details(title, blocks, expanded):
            var flags: Int32 = 0
            if expanded {
                flags |= (1 << 0)
            }
            return .pageBlockDetails(Api.PageBlock.Cons_pageBlockDetails(flags: flags, blocks: blocks.compactMap { $0.apiInputBlock(mediaIdRemap: mediaIdRemap) }, title: title.apiRichText()))
        case let .map(latitude, longitude, zoom, dimensions, caption):
            return .inputPageBlockMap(Api.PageBlock.Cons_inputPageBlockMap(geo: .inputGeoPoint(Api.InputGeoPoint.Cons_inputGeoPoint(flags: 0, lat: latitude, long: longitude, accuracyRadius: nil)), zoom: zoom, w: dimensions.width, h: dimensions.height, caption: .pageCaption(Api.PageCaption.Cons_pageCaption(text: caption.text.apiRichText(), credit: caption.credit.apiRichText()))))
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
