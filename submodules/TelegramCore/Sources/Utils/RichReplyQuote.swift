import Foundation
import Postbox

public extension EngineMessageReplyQuote {
    /// A quote of a rich message: `richText` is what travels as `quote_rich`, `text` and
    /// `entities` its flat form, which every display and search path reads.
    init(richText: [RichText], offset: Int?, media: Media?) {
        let flat = richReplyQuoteTextAndEntities(richText)
        self.init(text: flat.text, offset: offset, entities: flat.entities, media: media, richText: richText)
    }
}

extension RichText {
    /// A formatting wrapper's single child, and how to rebuild the wrapper around a replacement.
    /// Nil for leaves, atoms and `concat`.
    var richQuoteWrapper: (child: RichText, rebuild: (RichText) -> RichText)? {
        switch self {
        case let .bold(text):
            return (text, { .bold($0) })
        case let .italic(text):
            return (text, { .italic($0) })
        case let .underline(text):
            return (text, { .underline($0) })
        case let .strikethrough(text):
            return (text, { .strikethrough($0) })
        case let .fixed(text):
            return (text, { .fixed($0) })
        case let .url(text, url, webpageId):
            return (text, { .url(text: $0, url: url, webpageId: webpageId) })
        case let .email(text, email):
            return (text, { .email(text: $0, email: email) })
        case let .subscript(text):
            return (text, { .subscript($0) })
        case let .superscript(text):
            return (text, { .superscript($0) })
        case let .marked(text):
            return (text, { .marked($0) })
        case let .phone(text, phone):
            return (text, { .phone(text: $0, phone: phone) })
        case let .anchor(text, name):
            return (text, { .anchor(text: $0, name: name) })
        case let .textAutoEmail(text):
            return (text, { .textAutoEmail(text: $0) })
        case let .textAutoPhone(text):
            return (text, { .textAutoPhone(text: $0) })
        case let .textAutoUrl(text):
            return (text, { .textAutoUrl(text: $0) })
        case let .textBankCard(text):
            return (text, { .textBankCard(text: $0) })
        case let .textTonAddress(text):
            return (text, { .textTonAddress(text: $0) })
        case let .textBotCommand(text):
            return (text, { .textBotCommand(text: $0) })
        case let .textCashtag(text):
            return (text, { .textCashtag(text: $0) })
        case let .textHashtag(text):
            return (text, { .textHashtag(text: $0) })
        case let .textMention(text):
            return (text, { .textMention(text: $0) })
        case let .textMentionName(text, peerId):
            return (text, { .textMentionName(text: $0, peerId: peerId) })
        case let .textSpoiler(text):
            return (text, { .textSpoiler(text: $0) })
        case .empty, .plain, .concat, .image, .formula, .textCustomEmoji, .textDate, .textButton:
            return nil
        }
    }

    /// A run a quote holds whole or not at all: formulas, custom emoji, dates and inline buttons
    /// cannot be cut, and an inline image has no text to cut.
    var isRichQuoteAtom: Bool {
        switch self {
        case .image, .formula, .textCustomEmoji, .textDate, .textButton:
            return true
        default:
            return false
        }
    }

    /// The UTF-16 length of `plainText`, the axis every rich-quote offset is measured on.
    var richQuoteFlatLength: Int {
        return (self.plainText as NSString).length
    }
}

/// The flat form of rich-quote fragments: their plain texts joined by `\n` (the string
/// `quote_offset` indexes), with the entities flat quotes keep (bold, italic, underline,
/// strikethrough, spoiler, custom emoji).
public func richReplyQuoteTextAndEntities(_ fragments: [RichText]) -> (text: String, entities: [MessageTextEntity]) {
    var text = ""
    var length = 0
    var entities: [MessageTextEntity] = []
    for (index, fragment) in fragments.enumerated() {
        if index != 0 {
            text.append("\n")
            length += 1
        }
        appendRichQuoteFlatText(fragment, text: &text, length: &length, entities: &entities)
    }
    entities.sort(by: { $0.range.lowerBound < $1.range.lowerBound })
    return (text, entities)
}

private func appendRichQuoteFlatText(_ richText: RichText, text: inout String, length: inout Int, entities: inout [MessageTextEntity]) {
    let start = length
    var entityType: MessageTextEntityType?
    switch richText {
    case .empty, .image:
        break
    case let .plain(string):
        text.append(string)
        length += (string as NSString).length
    case let .concat(texts):
        for child in texts {
            appendRichQuoteFlatText(child, text: &text, length: &length, entities: &entities)
        }
    case let .textCustomEmoji(fileId, alt):
        text.append(alt)
        length += (alt as NSString).length
        entityType = .CustomEmoji(stickerPack: nil, fileId: fileId)
    case .formula, .textDate, .textButton:
        let flat = richText.plainText
        text.append(flat)
        length += (flat as NSString).length
    default:
        if let wrapper = richText.richQuoteWrapper {
            appendRichQuoteFlatText(wrapper.child, text: &text, length: &length, entities: &entities)
        }
        switch richText {
        case .bold:
            entityType = .Bold
        case .italic:
            entityType = .Italic
        case .underline:
            entityType = .Underline
        case .strikethrough:
            entityType = .Strikethrough
        case .textSpoiler:
            entityType = .Spoiler
        default:
            break
        }
    }
    if let entityType, length > start {
        entities.append(MessageTextEntity(range: start ..< length, type: entityType))
    }
}

/// One quotable text node of a rich message (an `InstantPage`), the unit the rich-quote spec
/// addresses. The scheme is described on `instantPageQuotableNodes`; the renderer stamps the same
/// ids on laid-out text.
public struct InstantPageTextNodeId: Hashable {
    public enum Part: Hashable {
        case text
        case captionText
        case captionCredit
        case title
        case cell(row: Int, column: Int)
    }

    public var blockPath: [Int]
    public var part: Part

    public init(blockPath: [Int], part: Part) {
        self.blockPath = blockPath
        self.part = part
    }
}

public struct InstantPageQuotableNode: Equatable {
    public let id: InstantPageTextNodeId
    public let text: RichText
    /// `text.plainText`: what the node contributes to the flat text `quote_offset` indexes.
    public let flatText: String
    /// Content this build cannot read (an undecodable block, a list item of unknown kind) lies between
    /// this node and the previous one. The server may count text in it, so no quote crosses it.
    public let followsOpaqueContent: Bool

    public init(id: InstantPageTextNodeId, text: RichText, followsOpaqueContent: Bool = false) {
        self.id = id
        self.text = text
        self.flatText = text.plainText
        self.followsOpaqueContent = followsOpaqueContent
    }

    var flatLength: Int {
        return (self.flatText as NSString).length
    }
}

public extension InstantPageBlock {
    /// Whether the rich-quote spec's node table lists this block. The ones it omits (title,
    /// subtitle, header, subheader, kicker, author/date, document, cover, embeds, related
    /// articles, channel banner, divider, anchor, button row, unsupported) contribute nothing.
    var isRichQuoteSource: Bool {
        switch self {
        case .paragraph, .heading, .footer, .thinking, .preformatted, .formula, .blockQuote, .pullQuote, .list, .table, .details, .image, .video, .audio, .map, .collage, .slideshow:
            return true
        default:
            return false
        }
    }
}

public extension InstantPage {
    /// The page's quotable text nodes in document order, empty ones skipped.
    var quotableNodes: [InstantPageQuotableNode] {
        return instantPageQuotableNodes(self.blocks)
    }
}

/// The quotable text nodes of `blocks` in document order, per the spec's table. Ids: a block's
/// index path; blockquote, details, collage and slideshow children extend their parent's path; a
/// list item's own text is `listPath + [item]`, its blocks `listPath + [item, block]`; table cells
/// are `.cell(row:, column:)` with `column` the index in `row.cells`.
public func instantPageQuotableNodes(_ blocks: [InstantPageBlock]) -> [InstantPageQuotableNode] {
    var result = QuotableNodeCollector()
    appendQuotableNodes(blocks, pathPrefix: [], to: &result)
    return result.nodes
}

private struct QuotableNodeCollector {
    var nodes: [InstantPageQuotableNode] = []
    /// Opaque content was passed since the last node; the next node records it.
    var passedOpaqueContent = false
}

private func appendQuotableNode(_ text: RichText, path: [Int], part: InstantPageTextNodeId.Part, to result: inout QuotableNodeCollector) {
    let node = InstantPageQuotableNode(id: InstantPageTextNodeId(blockPath: path, part: part), text: text, followsOpaqueContent: result.passedOpaqueContent)
    if !node.flatText.isEmpty {
        result.nodes.append(node)
        result.passedOpaqueContent = false
    }
}

private func appendQuotableCaption(_ caption: InstantPageCaption, path: [Int], to result: inout QuotableNodeCollector) {
    appendQuotableNode(caption.text, path: path, part: .captionText, to: &result)
    appendQuotableNode(caption.credit, path: path, part: .captionCredit, to: &result)
}

private func appendQuotableNodes(_ blocks: [InstantPageBlock], pathPrefix: [Int], to result: inout QuotableNodeCollector) {
    for (index, block) in blocks.enumerated() {
        let path = pathPrefix + [index]
        switch block {
        case let .paragraph(text), let .footer(text), let .thinking(text):
            appendQuotableNode(text, path: path, part: .text, to: &result)
        case let .heading(text, _):
            appendQuotableNode(text, path: path, part: .text, to: &result)
        case let .preformatted(text, _):
            appendQuotableNode(text, path: path, part: .text, to: &result)
        case let .formula(latex):
            appendQuotableNode(.formula(latex: latex), path: path, part: .text, to: &result)
        case let .blockQuote(children, caption, _):
            appendQuotableNodes(children, pathPrefix: path, to: &result)
            appendQuotableNode(caption, path: path, part: .captionText, to: &result)
        case let .pullQuote(text, caption):
            appendQuotableNode(text, path: path, part: .text, to: &result)
            appendQuotableNode(caption, path: path, part: .captionText, to: &result)
        case let .list(items, _):
            for (itemIndex, item) in items.enumerated() {
                switch item {
                case let .text(text, _, _):
                    appendQuotableNode(text, path: path + [itemIndex], part: .text, to: &result)
                case let .blocks(itemBlocks, _, _):
                    appendQuotableNodes(itemBlocks, pathPrefix: path + [itemIndex], to: &result)
                case .unknown:
                    result.passedOpaqueContent = true
                }
            }
        case let .table(title, rows, _, _, _):
            appendQuotableNode(title, path: path, part: .title, to: &result)
            for (rowIndex, row) in rows.enumerated() {
                for (cellIndex, cell) in row.cells.enumerated() {
                    if let text = cell.text {
                        appendQuotableNode(text, path: path, part: .cell(row: rowIndex, column: cellIndex), to: &result)
                    }
                }
            }
        case let .details(title, children, _):
            appendQuotableNode(title, path: path, part: .title, to: &result)
            appendQuotableNodes(children, pathPrefix: path, to: &result)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .audio(_, caption), let .map(_, _, _, _, caption):
            appendQuotableCaption(caption, path: path, to: &result)
        case let .collage(items, caption), let .slideshow(items, caption):
            appendQuotableNodes(items, pathPrefix: path, to: &result)
            appendQuotableCaption(caption, path: path, to: &result)
        case .unsupported:
            result.passedOpaqueContent = true
        default:
            break
        }
    }
}

/// The string `quote_offset` indexes: every node's flat text in document order, joined by `\n`.
public func richReplyQuoteFlatText(_ nodes: [InstantPageQuotableNode]) -> String {
    return nodes.map(\.flatText).joined(separator: "\n")
}

/// Where a rich quote's flat text sits among `nodes`: the occurrence nearest to `offset` (the first
/// one without it), as each covered node's flat range. Empty when the text is not there.
public func richReplyQuoteNodeRanges(nodes: [InstantPageQuotableNode], quoteText: String, offset: Int?) -> [(id: InstantPageTextNodeId, range: Range<Int>)] {
    guard !quoteText.isEmpty else {
        return []
    }
    let flat = richReplyQuoteFlatText(nodes) as NSString
    var match: NSRange?
    var searchStart = 0
    while searchStart < flat.length {
        let found = flat.range(of: quoteText, options: [], range: NSRange(location: searchStart, length: flat.length - searchStart))
        if found.location == NSNotFound {
            break
        }
        if let current = match, let offset {
            if abs(found.location - offset) < abs(current.location - offset) {
                match = found
            }
        } else if match == nil {
            match = found
        }
        if offset == nil {
            break
        }
        searchStart = found.location + 1
    }
    guard let match else {
        return []
    }
    var result: [(id: InstantPageTextNodeId, range: Range<Int>)] = []
    var nodeStart = 0
    for node in nodes {
        let nodeEnd = nodeStart + node.flatLength
        let lower = max(match.location, nodeStart)
        let upper = min(match.location + match.length, nodeEnd)
        if lower < upper {
            result.append((id: node.id, range: (lower - nodeStart) ..< (upper - nodeStart)))
        }
        nodeStart = nodeEnd + 1
    }
    return result
}

/// The part of `text` covering the flat range `range` (UTF-16 offsets into `text.plainText`):
/// formatting kept around what survives, a subtree wholly inside the range kept as it is, an atom
/// overlapping the range kept whole. Nil when nothing survives.
func richQuoteSlice(_ text: RichText, range: Range<Int>) -> RichText? {
    var offset = 0
    return richQuoteSlice(text, range: range, offset: &offset)
}

/// One walk over `text`: `offset` arrives at the subtree's flat start and leaves at its end, so no
/// subtree's length is computed twice. A container decides whether it lies wholly inside the range
/// after walking its children, when its end is known.
private func richQuoteSlice(_ text: RichText, range: Range<Int>, offset: inout Int) -> RichText? {
    let start = offset
    if text.isRichQuoteAtom {
        let end = start + text.richQuoteFlatLength
        offset = end
        if start == end {
            return range.lowerBound <= start && start < range.upperBound ? text : nil
        }
        return start < range.upperBound && end > range.lowerBound ? text : nil
    }
    var sliced: RichText?
    switch text {
    case let .plain(string):
        let characters = string as NSString
        offset = start + characters.length
        let lower = max(range.lowerBound, start) - start
        let upper = min(range.upperBound, offset) - start
        if lower < upper {
            sliced = .plain(characters.substring(with: NSRange(location: lower, length: upper - lower)))
        }
    case let .concat(texts):
        var parts: [RichText] = []
        for child in texts {
            if let part = richQuoteSlice(child, range: range, offset: &offset) {
                parts.append(part)
            }
        }
        sliced = parts.isEmpty ? nil : .concat(parts)
    default:
        if let wrapper = text.richQuoteWrapper {
            sliced = richQuoteSlice(wrapper.child, range: range, offset: &offset).map(wrapper.rebuild)
        }
    }
    let end = offset
    if start == end || end <= range.lowerBound || start >= range.upperBound {
        return nil
    }
    if range.lowerBound <= start && end <= range.upperBound {
        return text
    }
    return sliced
}

/// `offset` moved off a position no fragment may start or end at: out of an atom (to its start, or
/// to its end when `roundUp`) and out of the middle of a grapheme cluster (a surrogate pair, an
/// emoji with a skin tone, a flag, a joined sequence).
func richQuoteSnap(_ text: RichText, offset: Int, roundUp: Bool) -> Int {
    var position = 0
    var result = offset
    richQuoteSnap(text, offset: offset, roundUp: roundUp, position: &position, result: &result)
    return result
}

private func richQuoteSnap(_ text: RichText, offset: Int, roundUp: Bool, position: inout Int, result: inout Int) {
    let start = position
    if text.isRichQuoteAtom {
        let end = start + text.richQuoteFlatLength
        position = end
        if start < offset && offset < end {
            result = roundUp ? end : start
        }
        return
    }
    switch text {
    case let .plain(string):
        let local = offset - start
        var boundary = 0
        for character in string {
            let next = boundary + character.utf16.count
            if boundary < local && local < next {
                result = start + (roundUp ? next : boundary)
            }
            boundary = next
        }
        position = start + boundary
    case let .concat(texts):
        for child in texts {
            richQuoteSnap(child, offset: offset, roundUp: roundUp, position: &position, result: &result)
        }
    default:
        if let wrapper = text.richQuoteWrapper {
            richQuoteSnap(wrapper.child, offset: offset, roundUp: roundUp, position: &position, result: &result)
        }
    }
}

/// What a fragment may carry: an inline button becomes its label as plain text (the server rejects
/// `textButton` in a quote) and an inline image is dropped (images are not quoted).
func richQuoteNormalized(_ text: RichText) -> RichText? {
    switch text {
    case .image:
        return nil
    case let .textButton(button):
        let label = button.text.plainText
        return label.isEmpty ? nil : .plain(label)
    case let .concat(texts):
        let parts = texts.compactMap(richQuoteNormalized)
        return parts.isEmpty ? nil : .concat(parts)
    default:
        if let wrapper = text.richQuoteWrapper {
            return richQuoteNormalized(wrapper.child).map(wrapper.rebuild)
        }
        return text
    }
}

public struct RichQuoteBoundary: Equatable {
    public var node: InstantPageTextNodeId
    /// A UTF-16 offset into the node's flat text.
    public var flatOffset: Int

    public init(node: InstantPageTextNodeId, flatOffset: Int) {
        self.node = node
        self.flatOffset = flatOffset
    }
}

public let richReplyQuoteMaxFragmentCount = 32

/// The rich reply quote for a selection running from `start` to `end` across `nodes` (a page's
/// `quotableNodes`), shaped the way the server validates it: the first node's suffix, every node in
/// between whole, the last node's prefix. Spaces and newlines at either end are trimmed (moving the
/// offset); at most `richReplyQuoteMaxFragmentCount` fragments and `maxLength` UTF-16 units of
/// joined text are kept, cutting the tail on a valid boundary. Nil when nothing is quotable.
public func makeRichReplyQuote(nodes: [InstantPageQuotableNode], start: RichQuoteBoundary, end: RichQuoteBoundary, maxLength: Int, media: Media? = nil) -> EngineMessageReplyQuote? {
    guard let startIndex = nodes.firstIndex(where: { $0.id == start.node }), let endIndex = nodes.firstIndex(where: { $0.id == end.node }) else {
        return nil
    }
    var lower = (index: startIndex, offset: max(0, min(start.flatOffset, nodes[startIndex].flatLength)))
    var upper = (index: endIndex, offset: max(0, min(end.flatOffset, nodes[endIndex].flatLength)))
    if (upper.index, upper.offset) < (lower.index, lower.offset) {
        swap(&lower, &upper)
    }

    func isTrimmable(_ character: unichar) -> Bool {
        return character == 0x20 || character == 0x0a
    }
    while (lower.index, lower.offset) < (upper.index, upper.offset) {
        let flat = nodes[lower.index].flatText as NSString
        if lower.offset >= flat.length {
            lower = (index: lower.index + 1, offset: 0)
        } else if isTrimmable(flat.character(at: lower.offset)) {
            lower.offset += 1
        } else {
            break
        }
    }
    while (lower.index, lower.offset) < (upper.index, upper.offset) {
        let flat = nodes[upper.index].flatText as NSString
        if upper.offset <= 0 {
            upper = (index: upper.index - 1, offset: nodes[upper.index - 1].flatLength)
        } else if isTrimmable(flat.character(at: upper.offset - 1)) {
            upper.offset -= 1
        } else {
            break
        }
    }
    lower.offset = richQuoteSnap(nodes[lower.index].text, offset: lower.offset, roundUp: false)
    upper.offset = richQuoteSnap(nodes[upper.index].text, offset: upper.offset, roundUp: true)
    guard (lower.index, lower.offset) < (upper.index, upper.offset) else {
        return nil
    }

    var fragments: [RichText] = []
    var remaining = maxLength
    var index = lower.index
    while index <= upper.index && fragments.count < richReplyQuoteMaxFragmentCount {
        let node = nodes[index]
        if index > lower.index && node.followsOpaqueContent {
            // The server may count text this build cannot read here: end with the node before it.
            break
        }
        if !fragments.isEmpty {
            remaining -= 1
        }
        let from = index == lower.index ? lower.offset : 0
        var to = index == upper.index ? upper.offset : node.flatLength
        var isCut = false
        if to - from > remaining {
            to = richQuoteSnap(node.text, offset: from + max(0, remaining), roundUp: false)
            // A cut is a new end of the quote: trimmed like the selection's own.
            let flat = node.flatText as NSString
            while to > from && isTrimmable(flat.character(at: to - 1)) {
                to -= 1
            }
            to = richQuoteSnap(node.text, offset: to, roundUp: false)
            isCut = true
        }
        if to > from, let sliced = richQuoteSlice(node.text, range: from ..< to), let fragment = richQuoteNormalized(sliced) {
            fragments.append(fragment)
            remaining -= fragment.richQuoteFlatLength
        } else if !isCut {
            // A node of the run produced nothing: the rest would not be contiguous with it.
            return nil
        }
        if isCut {
            break
        }
        index += 1
    }
    guard !fragments.isEmpty else {
        return nil
    }

    var offset = lower.offset
    for previous in nodes[0 ..< lower.index] {
        offset += previous.flatLength + 1
    }
    return EngineMessageReplyQuote(richText: fragments, offset: offset, media: media)
}

public extension InstantPage {
    /// The rich quote of the whole page, or of its head when the page is longer than the limits.
    func wholeRichReplyQuote(maxLength: Int, media: Media?) -> EngineMessageReplyQuote? {
        let nodes = self.quotableNodes
        guard let first = nodes.first, let last = nodes.last else {
            return nil
        }
        return makeRichReplyQuote(nodes: nodes, start: RichQuoteBoundary(node: first.id, flatOffset: 0), end: RichQuoteBoundary(node: last.id, flatOffset: last.flatLength), maxLength: maxLength, media: media)
    }
}

private struct RichQuoteStyle: OptionSet {
    let rawValue: Int
    static let bold = RichQuoteStyle(rawValue: 1 << 0)
    static let italic = RichQuoteStyle(rawValue: 1 << 1)
    static let underline = RichQuoteStyle(rawValue: 1 << 2)
    static let strikethrough = RichQuoteStyle(rawValue: 1 << 3)
    static let lowered = RichQuoteStyle(rawValue: 1 << 4)
    static let raised = RichQuoteStyle(rawValue: 1 << 5)
    static let spoiler = RichQuoteStyle(rawValue: 1 << 6)
}

/// One unit of the comparison form: a UTF-16 unit or an atom, with the formatting the server
/// compares exactly. Links, mentions, monospace, marks and buttons reduce to their text.
private enum RichQuoteUnit: Equatable {
    case character(UInt16, RichQuoteStyle)
    case atom(String, RichQuoteStyle)
}

private func richQuoteUnits(_ text: RichText) -> [RichQuoteUnit] {
    var result: [RichQuoteUnit] = []
    appendRichQuoteUnits(text, style: [], to: &result)
    return result
}

private func appendRichQuoteUnits(_ text: RichText, style: RichQuoteStyle, to result: inout [RichQuoteUnit]) {
    switch text {
    case .empty, .image:
        break
    case let .plain(string):
        result.append(contentsOf: string.utf16.map { RichQuoteUnit.character($0, style) })
    case let .concat(texts):
        for child in texts {
            appendRichQuoteUnits(child, style: style, to: &result)
        }
    case let .formula(latex):
        result.append(.atom("math:" + latex, style))
    case let .textCustomEmoji(fileId, _):
        result.append(.atom("emoji:\(fileId)", style))
    case let .textDate(inner, date, _):
        result.append(.atom("date:\(date):" + inner.plainText, style))
    case let .textButton(button):
        result.append(contentsOf: button.text.plainText.utf16.map { RichQuoteUnit.character($0, style) })
    case let .bold(child):
        appendRichQuoteUnits(child, style: style.union(.bold), to: &result)
    case let .italic(child):
        appendRichQuoteUnits(child, style: style.union(.italic), to: &result)
    case let .underline(child):
        appendRichQuoteUnits(child, style: style.union(.underline), to: &result)
    case let .strikethrough(child):
        appendRichQuoteUnits(child, style: style.union(.strikethrough), to: &result)
    case let .subscript(child):
        appendRichQuoteUnits(child, style: style.union(.lowered), to: &result)
    case let .superscript(child):
        appendRichQuoteUnits(child, style: style.union(.raised), to: &result)
    case let .textSpoiler(child):
        appendRichQuoteUnits(child, style: style.union(.spoiler), to: &result)
    default:
        if let wrapper = text.richQuoteWrapper {
            appendRichQuoteUnits(wrapper.child, style: style, to: &result)
        }
    }
}

/// A partial page's nodes are the full page's up to its last, which may be cut short; the rest of
/// the page is missing. The quote is located by `offset` (the sender's flat offset into the full
/// page): one starting before the last shown node is checked node by node, the cut node only as far
/// as it is shown, and fragments past it are unverifiable. Any other quote is let through: it
/// starts where this page cannot see.
private func richReplyQuoteMatchesPartialPage(_ fragmentUnits: [[RichQuoteUnit]], nodes: [InstantPageQuotableNode], nodeUnits: [[RichQuoteUnit]], offset: Int?) -> Bool {
    guard let offset, let last = nodes.indices.last else {
        return true
    }
    var first: Int?
    var nodeStart = 0
    for index in nodes.indices where index != last {
        let nodeEnd = nodeStart + nodes[index].flatLength
        if offset >= nodeStart && offset < nodeEnd {
            first = index
            break
        }
        nodeStart = nodeEnd + 1
    }
    guard let first else {
        return true
    }
    func isPrefix(_ prefix: [RichQuoteUnit], of units: [RichQuoteUnit]) -> Bool {
        return prefix.count <= units.count && Array(units[..<prefix.count]) == prefix
    }
    for (k, units) in fragmentUnits.enumerated() {
        let index = first + k
        let node = nodeUnits[index]
        if index == last {
            // The cut node is a prefix of the full one; what lies past it is not shown.
            return isPrefix(node, of: units) || isPrefix(units, of: node)
        }
        if fragmentUnits.count == 1 {
            return richQuoteUnits(node, contain: units)
        }
        if k == 0 {
            guard units.count <= node.count, Array(node[(node.count - units.count)...]) == units else {
                return false
            }
        } else if k == fragmentUnits.count - 1 {
            guard node.starts(with: units) else {
                return false
            }
        } else if node != units {
            return false
        }
    }
    return true
}

/// The boundaries of a selection that touched `runs` (each a node and the flat range of it the
/// selection covers), in document order: from the earliest node's lowest offset to the latest
/// node's highest. A selection's own first and last runs cannot be used, because display order is
/// not document order: a table's spanning cell is laid out after its last row's cells. Runs of
/// nodes `nodes` does not hold are ignored (an empty list item is laid out as a placeholder).
public func richQuoteSelectionBoundaries(nodes: [InstantPageQuotableNode], runs: [(id: InstantPageTextNodeId, range: Range<Int>)]) -> (start: RichQuoteBoundary, end: RichQuoteBoundary)? {
    var indices: [InstantPageTextNodeId: Int] = [:]
    for (index, node) in nodes.enumerated() where indices[node.id] == nil {
        indices[node.id] = index
    }
    var lower: (index: Int, offset: Int)?
    var upper: (index: Int, offset: Int)?
    for run in runs {
        guard let index = indices[run.id] else {
            continue
        }
        if lower.map({ (index, run.range.lowerBound) < ($0.index, $0.offset) }) ?? true {
            lower = (index, run.range.lowerBound)
        }
        if upper.map({ (index, run.range.upperBound) > ($0.index, $0.offset) }) ?? true {
            upper = (index, run.range.upperBound)
        }
    }
    guard let lower, let upper else {
        return nil
    }
    return (RichQuoteBoundary(node: nodes[lower.index].id, flatOffset: lower.offset), RichQuoteBoundary(node: nodes[upper.index].id, flatOffset: upper.offset))
}

private func richQuoteUnits(_ units: [RichQuoteUnit], contain run: [RichQuoteUnit]) -> Bool {
    guard !run.isEmpty, run.count <= units.count else {
        return false
    }
    for start in 0 ... units.count - run.count where units[start] == run[0] {
        if Array(units[start ..< start + run.count]) == run {
            return true
        }
    }
    return false
}

/// Whether the server would accept `fragments` as a quote of `nodes`: one fragment per node of a
/// contiguous run, the first a suffix of its node, the last a prefix, every one between equal to
/// its node (a single fragment may sit anywhere inside one node). Compared as the server compares:
/// text, bold/italic/underline/strikethrough/sub/superscript/spoiler exactly, custom emoji by
/// document, formulas by source, dates by value; links, mentions, monospace, marks and buttons as
/// text only. Length limits are not checked here.
///
/// `isPartialPage` is for a long rich message shown before Show more: see
/// `richReplyQuoteMatchesPartialPage` for what such a page can settle.
public func richReplyQuoteMatches(_ fragments: [RichText], nodes: [InstantPageQuotableNode], isPartialPage: Bool = false, offset: Int? = nil) -> Bool {
    guard !fragments.isEmpty, fragments.count <= richReplyQuoteMaxFragmentCount else {
        return false
    }
    let fragmentUnits = fragments.map { richQuoteUnits($0) }
    if fragmentUnits.contains(where: { $0.isEmpty }) {
        return false
    }
    let nodeUnits = nodes.map { richQuoteUnits($0.text) }
    if isPartialPage {
        return richReplyQuoteMatchesPartialPage(fragmentUnits, nodes: nodes, nodeUnits: nodeUnits, offset: offset)
    }
    if fragmentUnits.count == 1 {
        return nodeUnits.contains(where: { richQuoteUnits($0, contain: fragmentUnits[0]) })
    }
    guard nodeUnits.count >= fragmentUnits.count else {
        return false
    }
    let last = fragmentUnits.count - 1
    for first in 0 ... nodeUnits.count - fragmentUnits.count {
        let head = nodeUnits[first]
        guard fragmentUnits[0].count <= head.count, Array(head[(head.count - fragmentUnits[0].count)...]) == fragmentUnits[0] else {
            continue
        }
        var matches = true
        for k in 1 ..< last where nodeUnits[first + k] != fragmentUnits[k] {
            matches = false
            break
        }
        if matches && nodeUnits[first + last].starts(with: fragmentUnits[last]) {
            return true
        }
    }
    return false
}
