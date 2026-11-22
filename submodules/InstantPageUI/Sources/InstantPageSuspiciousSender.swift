import Foundation
import TelegramCore

/// The page as a chat shows it from a suspicious sender (`CachedUserData.isSuspiciousPeer`: the
/// chat's report/block panel is still up), matching what a plain message from them shows.
///
/// - Links, emails, mentions, hashtags and cashtags, bank cards and TON addresses become plain text:
///   the set a plain message from them loses (`MessageTextEntity.isShownFromSuspiciousPeer`). Phone
///   numbers, bot commands, dates, anchors and custom emoji stay. An image block loses its link.
/// - Buttons are not shown. An inline pill becomes nothing; a link-styled button is drawn as a link,
///   so its label stays as plain text. A button row keeps its place with no buttons, which lays out
///   to nothing and adds no spacing (`layoutBlockSequence` advances only on height).
///
/// Every block keeps its index: block paths are rich-quote node ids and structural paths, so the
/// original page's ids still address the same blocks here.
public func instantPageForSuspiciousSender(_ page: InstantPage) -> InstantPage {
    return InstantPage(
        blocks: page.blocks.map(suspiciousSenderBlock),
        media: page.media,
        isComplete: page.isComplete,
        rtl: page.rtl,
        url: page.url,
        views: page.views
    )
}

private func suspiciousSenderBlock(_ block: InstantPageBlock) -> InstantPageBlock {
    switch block {
    case .unsupported, .formula, .divider, .anchor, .channelBanner:
        return block
    case let .title(text):
        return .title(suspiciousSenderText(text))
    case let .subtitle(text):
        return .subtitle(suspiciousSenderText(text))
    case let .authorDate(author, date):
        return .authorDate(author: suspiciousSenderText(author), date: date)
    case let .header(text):
        return .header(suspiciousSenderText(text))
    case let .subheader(text):
        return .subheader(suspiciousSenderText(text))
    case let .heading(text, level):
        return .heading(text: suspiciousSenderText(text), level: level)
    case let .paragraph(text):
        return .paragraph(suspiciousSenderText(text))
    case let .preformatted(text, language):
        return .preformatted(text: suspiciousSenderText(text), language: language)
    case let .footer(text):
        return .footer(suspiciousSenderText(text))
    case let .list(items, ordered):
        return .list(items: items.map(suspiciousSenderListItem), ordered: ordered)
    case let .blockQuote(blocks, caption, collapsed):
        return .blockQuote(blocks: blocks.map(suspiciousSenderBlock), caption: suspiciousSenderText(caption), collapsed: collapsed)
    case let .pullQuote(text, caption):
        return .pullQuote(text: suspiciousSenderText(text), caption: suspiciousSenderText(caption))
    case let .image(id, caption, _, _, spoiler):
        return .image(id: id, caption: suspiciousSenderCaption(caption), url: nil, webpageId: nil, spoiler: spoiler)
    case let .video(id, caption, autoplay, loop, spoiler):
        return .video(id: id, caption: suspiciousSenderCaption(caption), autoplay: autoplay, loop: loop, spoiler: spoiler)
    case let .audio(id, caption):
        return .audio(id: id, caption: suspiciousSenderCaption(caption))
    case let .document(id, caption):
        return .document(id: id, caption: suspiciousSenderCaption(caption))
    case let .buttonRow(alignment, _):
        return .buttonRow(alignment: alignment, buttons: [])
    case let .cover(inner):
        return .cover(suspiciousSenderBlock(inner))
    case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling, coverId):
        return .webEmbed(url: url, html: html, dimensions: dimensions, caption: suspiciousSenderCaption(caption), stretchToWidth: stretchToWidth, allowScrolling: allowScrolling, coverId: coverId)
    case let .postEmbed(url, webpageId, avatarId, author, date, blocks, caption):
        return .postEmbed(url: url, webpageId: webpageId, avatarId: avatarId, author: author, date: date, blocks: blocks.map(suspiciousSenderBlock), caption: suspiciousSenderCaption(caption))
    case let .collage(items, caption):
        return .collage(items: items.map(suspiciousSenderBlock), caption: suspiciousSenderCaption(caption))
    case let .slideshow(items, caption):
        return .slideshow(items: items.map(suspiciousSenderBlock), caption: suspiciousSenderCaption(caption))
    case let .kicker(text):
        return .kicker(suspiciousSenderText(text))
    case let .thinking(text):
        return .thinking(suspiciousSenderText(text))
    case let .table(title, rows, bordered, striped, compact):
        let rows = rows.map { row in
            return InstantPageTableRow(cells: row.cells.map { cell in
                return InstantPageTableCell(text: cell.text.flatMap(suspiciousSenderText), header: cell.header, alignment: cell.alignment, verticalAlignment: cell.verticalAlignment, colspan: cell.colspan, rowspan: cell.rowspan)
            })
        }
        return .table(title: suspiciousSenderText(title), rows: rows, bordered: bordered, striped: striped, compact: compact)
    case let .details(title, blocks, expanded):
        return .details(title: suspiciousSenderText(title), blocks: blocks.map(suspiciousSenderBlock), expanded: expanded)
    case let .relatedArticles(title, articles):
        return .relatedArticles(title: suspiciousSenderText(title), articles: articles)
    case let .map(latitude, longitude, zoom, dimensions, caption):
        return .map(latitude: latitude, longitude: longitude, zoom: zoom, dimensions: dimensions, caption: suspiciousSenderCaption(caption))
    }
}

private func suspiciousSenderListItem(_ item: InstantPageListItem) -> InstantPageListItem {
    switch item {
    case .unknown:
        return item
    case let .text(text, num, checked):
        return .text(suspiciousSenderText(text), num, checked)
    case let .blocks(blocks, num, checked):
        return .blocks(blocks.map(suspiciousSenderBlock), num, checked)
    }
}

private func suspiciousSenderCaption(_ caption: InstantPageCaption) -> InstantPageCaption {
    return InstantPageCaption(text: suspiciousSenderText(caption.text), credit: suspiciousSenderText(caption.credit))
}

private func suspiciousSenderText(_ text: RichText) -> RichText {
    switch text {
    case .empty, .plain, .image, .formula, .textCustomEmoji:
        return text
    case let .bold(child):
        return .bold(suspiciousSenderText(child))
    case let .italic(child):
        return .italic(suspiciousSenderText(child))
    case let .underline(child):
        return .underline(suspiciousSenderText(child))
    case let .strikethrough(child):
        return .strikethrough(suspiciousSenderText(child))
    case let .fixed(child):
        return .fixed(suspiciousSenderText(child))
    case let .subscript(child):
        return .subscript(suspiciousSenderText(child))
    case let .superscript(child):
        return .superscript(suspiciousSenderText(child))
    case let .marked(child):
        return .marked(suspiciousSenderText(child))
    case let .textSpoiler(child):
        return .textSpoiler(text: suspiciousSenderText(child))
    case let .concat(children):
        return .concat(children.map(suspiciousSenderText))
    case let .phone(child, phone):
        return .phone(text: suspiciousSenderText(child), phone: phone)
    case let .anchor(child, name):
        return .anchor(text: suspiciousSenderText(child), name: name)
    case let .textAutoPhone(child):
        return .textAutoPhone(text: suspiciousSenderText(child))
    case let .textBotCommand(child):
        return .textBotCommand(text: suspiciousSenderText(child))
    case let .textDate(child, date, format):
        return .textDate(text: suspiciousSenderText(child), date: date, format: format)
    case let .url(child, _, _), let .email(child, _), let .textAutoEmail(child), let .textAutoUrl(child), let .textBankCard(child), let .textTonAddress(child), let .textCashtag(child), let .textHashtag(child), let .textMention(child), let .textMentionName(child, _):
        return suspiciousSenderText(child)
    case let .textButton(button):
        return button.isLink ? suspiciousSenderText(button.text) : .empty
    }
}
