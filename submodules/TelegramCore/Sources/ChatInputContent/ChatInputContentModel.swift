import Foundation
import Postbox

public struct ChatInputRun: Equatable, Codable {
    public var text: String
    public var attributes: ChatInputInlineAttributes
    public init(text: String, attributes: ChatInputInlineAttributes = ChatInputInlineAttributes()) {
        self.text = text
        self.attributes = attributes
    }
}

public struct ChatInputInlineAttributes: Equatable, Codable {
    public var bold: Bool
    public var italic: Bool
    public var monospace: Bool
    public var strikethrough: Bool
    public var underline: Bool
    public var spoiler: Bool
    public var formula: String?
    public var entity: ChatInputInlineEntity?
    public init(
        bold: Bool = false,
        italic: Bool = false,
        monospace: Bool = false,
        strikethrough: Bool = false,
        underline: Bool = false,
        spoiler: Bool = false,
        formula: String? = nil,
        entity: ChatInputInlineEntity? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.monospace = monospace
        self.strikethrough = strikethrough
        self.underline = underline
        self.spoiler = spoiler
        self.formula = formula
        self.entity = entity
    }
}

public enum ChatInputInlineEntity: Equatable, Codable {
    case mention(EnginePeer.Id)
    case url(String)
    case date(Int32)
    case customEmoji(fileId: Int64, file: TelegramMediaFile?, enableAnimation: Bool)
    /// An inline `RichText.textButton`. The carrying run's text MUST be exactly one `U+FFFC`.
    case button(ChatInputButton)

    public static func == (lhs: ChatInputInlineEntity, rhs: ChatInputInlineEntity) -> Bool {
        switch (lhs, rhs) {
        case let (.mention(a), .mention(b)): return a == b
        case let (.url(a), .url(b)): return a == b
        case let (.date(a), .date(b)): return a == b
        // `file` is a heavy media reference that is reconstructed from a side cache (and dropped by
        // the canonical ChatTextInputStateText form); identity is the fileId + animation flag.
        case let (.customEmoji(aId, _, aAnim), .customEmoji(bId, _, bAnim)): return aId == bId && aAnim == bAnim
        case let (.button(a), .button(b)): return a == b
        default: return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case peerId
        case url
        case date
        case fileId
        case enableAnimation
        case button
    }

    private enum Kind: Int32, Codable {
        case mention
        case url
        case date
        case customEmoji
        case button
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode the discriminator as the raw `Int32` (NOT `Kind.self`): the Postbox `AdaptedPostbox*coder` does
        // not support the `singleValueContainer` that a `RawRepresentable` enum's synthesized Codable uses.
        let kindValue = try container.decode(Int32.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindValue) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown discriminator \(kindValue)")
        }
        switch kind {
        case .mention:
            let peerId = try container.decode(Int64.self, forKey: .peerId)
            self = .mention(EnginePeer.Id(peerId))
        case .url:
            self = .url(try container.decode(String.self, forKey: .url))
        case .date:
            self = .date(try container.decode(Int32.self, forKey: .date))
        case .customEmoji:
            let fileId = try container.decode(Int64.self, forKey: .fileId)
            let enableAnimation = try container.decode(Bool.self, forKey: .enableAnimation)
            // `file` is not persisted (reconstructed from a side cache); decode as nil.
            self = .customEmoji(fileId: fileId, file: nil, enableAnimation: enableAnimation)
        case .button:
            self = .button(try container.decode(ChatInputButton.self, forKey: .button))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .mention(peerId):
            try container.encode(Kind.mention.rawValue, forKey: .kind)
            // Deliberately a flat Int64 (not `encode(peerId)`): `EnginePeer.Id`/`PeerId` is itself Codable but wraps
            // the value in a nested `{internalValue:}` container — the flat form is the leaner persisted shape and
            // round-trips exactly (`PeerId(toInt64()) == self`). Keep flat; do not "simplify" to `encode(peerId)`.
            try container.encode(peerId.toInt64(), forKey: .peerId)
        case let .url(value):
            try container.encode(Kind.url.rawValue, forKey: .kind)
            try container.encode(value, forKey: .url)
        case let .date(value):
            try container.encode(Kind.date.rawValue, forKey: .kind)
            try container.encode(value, forKey: .date)
        case let .customEmoji(fileId, _, enableAnimation):
            try container.encode(Kind.customEmoji.rawValue, forKey: .kind)
            // `file` is intentionally not persisted; only fileId + enableAnimation are encoded.
            try container.encode(fileId, forKey: .fileId)
            try container.encode(enableAnimation, forKey: .enableAnimation)
        case let .button(button):
            try container.encode(Kind.button.rawValue, forKey: .kind)
            try container.encode(button, forKey: .button)
        }
    }
}

// Used by ChatInputContent's lenient [ChatInputBlock] decode: each element in the objectArray is
// decoded by a fresh AdaptedPostboxDecoder, so catching the error per-element is safe and does not
// corrupt the array cursor. Unknown / removed block kinds (e.g. old "collapsedQuote" rawValue 2)
// produce block = nil, which the outer init filters out with compactMap.
private struct _LenientChatInputBlock: Decodable {
    let block: ChatInputBlock?
    init(from decoder: Decoder) throws {
        block = try? ChatInputBlock(from: decoder)
    }
}

public struct ChatInputContent: Equatable {
    public var schemaVersion: Int32
    public var blocks: [ChatInputBlock]
    public init(schemaVersion: Int32 = 1, blocks: [ChatInputBlock] = []) {
        self.schemaVersion = schemaVersion
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case blocks
    }

    /// The flat plain text, identical to `attributedString(from: self).string`: the flat-axis blocks joined by a
    /// single "\n", a paragraph/code block contributing its runs' text and a `.blockQuote(collapsed: true)`
    /// contributing one " " placeholder. A `.media`/`.table` block is OFF the flat axis — it contributes
    /// no character AND no separator (matching `attributedString(from:)`, which drops them, and the editor's
    /// `composerParagraphs()`, which skips them); a non-text block has no flat-text/caret representation. Lets
    /// `inputText`-string readers move to the model — a round-trip-parity test guards the equivalence.
    public var plainText: String {
        var result = ""
        var hasEmitted = false
        for block in self.blocks {
            switch block {
            case let .paragraph(paragraph):
                if hasEmitted { result.append("\n") }
                hasEmitted = true
                result.append(paragraph.text)
            case let .code(code):
                if hasEmitted { result.append("\n") }
                hasEmitted = true
                result.append(code.text)
            case let .pullQuote(pq):
                if hasEmitted { result.append("\n") }
                hasEmitted = true
                result.append(pq.text)
            case let .blockQuote(bq):
                if hasEmitted { result.append("\n") }
                hasEmitted = true
                if bq.collapsed {
                    result.append(" ")
                } else {
                    result.append(bq.content.plainText)
                }
            case .media, .table, .details, .buttonRow:
                // Off the flat axis: no character AND no separator (see `blockFlatLength`). Matches
                // `attributedString(from:)` (drops them) and the editor's `composerParagraphs()` (skips them).
                // A detail block round-trips via the structured Codable + InstantPage path, not flat text.
                break
            }
        }
        return result
    }

    /// The UTF-16 length, identical to `attributedString(from: self).length` (a custom emoji is one U+FFFC unit).
    public var length: Int {
        return (self.plainText as NSString).length
    }

    /// Whether the composer has NO content — cheaper than `plainText.isEmpty` (it never builds the string).
    /// Matches `plainText.isEmpty` / `length == 0` for text content, but is **content-aware, not flat-text-aware**:
    /// a single `.media`/`.table` block has empty flat text yet is NOT empty (a medium/table IS content), so
    /// `isEmpty == false` while `plainText.isEmpty == true` there. Empty iff there are no blocks, or exactly one
    /// block whose text is empty (2+ blocks always carry an inter-block "\n"; a `.media`/`.table`/`.blockQuote`
    /// is non-empty).
    public var isEmpty: Bool {
        guard self.blocks.count <= 1 else {
            return false
        }
        guard let block = self.blocks.first else {
            return true
        }
        switch block {
        case let .paragraph(paragraph):
            return paragraph.text.isEmpty
        case let .code(code):
            return code.text.isEmpty
        case .media:
            return false
        case .table:
            return false
        case let .pullQuote(pq):
            return pq.text.isEmpty
        case .blockQuote:
            return false
        case .details:
            return false
        case .buttonRow:
            return false
        }
    }

    /// Like `isEmpty`, but a block whose text is only whitespace/newlines counts as empty. Unlike `isEmpty`
    /// this is NOT short-circuited on block COUNT: several blank paragraphs are still "empty" here (their only
    /// content is inter-block newlines), whereas `isEmpty` treats 2+ blocks as non-empty. A `.media`/`.table`/
    /// `.blockQuote` block is still content (never whitespace-empty). Used by the composer's expand-button
    /// affordance, which must stay hidden for a field that is tall only because of blank lines.
    public var isEmptyWhitespaceTrimmed: Bool {
        return self.blocks.allSatisfy { block in
            switch block {
            case let .paragraph(paragraph):
                return paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case let .code(code):
                return code.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case let .pullQuote(pq):
                return pq.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .media, .table, .blockQuote, .details, .buttonRow:
                return false
            }
        }
    }

    /// Options that tune which blocks `isEntityExpressible(options:)` accepts on the plain text + entities path.
    public struct EntityExpressibleOptions: OptionSet {
        public let rawValue: Int32
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Treat a blockquote as NOT entity-expressible, so quote-bearing content is routed onto the rich
        /// (InstantPage) path even though message entities could represent it.
        /// The default (no options) keeps a flat non-collapsed single-paragraph blockquote entity-expressible.
        public static let quotesRequireRichContent = EntityExpressibleOptions(rawValue: 1 << 0)
    }

    /// Whether this content can be represented as plain text + message entities (the `.textEntities`
    /// branch) rather than requiring a structured `InstantPage` (the `.instantPage` branch). True for
    /// every block today; the deliberate switch with no `default` forces a compile decision the day a
    /// non-entity-expressible block type is introduced.
    ///
    /// `options` narrows what counts as entity-expressible — see `EntityExpressibleOptions`.
    public func isEntityExpressible(options: EntityExpressibleOptions = []) -> Bool {
        return self.blocks.allSatisfy { block in
            switch block {
            case let .paragraph(paragraph):
                if chatInputRunsContainFormula(paragraph.runs) {
                    return false
                }
                if chatInputRunsContainButton(paragraph.runs) {
                    return false
                }
                // A heading or a list paragraph carries structure the message-entity set can't express.
                if paragraph.list != nil {
                    return false
                }
                switch paragraph.style {
                case .body:
                    return true
                case .heading1, .heading2, .heading3:
                    return false
                }
            case let .code(code):
                return !chatInputRunsContainFormula(code.runs) && !chatInputRunsContainButton(code.runs)
            case .media: return false
            case .table: return false
            case .pullQuote:
                return false
            case let .blockQuote(bq):
                if !bq.author.isEmpty { return false }
                // FLAT-ONLY rule: expressible only when the quote is non-collapsed AND every child block is
                // a plain body paragraph with no list membership (the message-entity blockquote can represent
                // exactly one level of flat-text quote).
                if options.contains(.quotesRequireRichContent) { return false }
                guard !bq.collapsed else { return false }
                if !bq.content.isEntityExpressible() {
                    return false
                }
                return bq.content.blocks.allSatisfy {
                    if case let .paragraph(p) = $0, case .body = p.style, p.list == nil { return true }
                    return false
                }
            case .details:
                // A detail (folding) block carries structure the message-entity set can't express → rich path.
                return false
            case .buttonRow:
                // A button has no message-entity form at all → rich path. LOAD-BEARING: returning true
                // here would send the message as plain text + entities and destroy the buttons.
                return false
            }
        }
    }
}

private func chatInputRunsContainFormula(_ runs: [ChatInputRun]) -> Bool {
    for run in runs {
        if run.attributes.formula != nil {
            return true
        }
    }
    return false
}

/// True when any run carries an inline button entity. A button has no message-entity form, so its
/// presence forces the rich `.instantPage` send path exactly as a formula does.
private func chatInputRunsContainButton(_ runs: [ChatInputRun]) -> Bool {
    for run in runs {
        if case .button = run.attributes.entity {
            return true
        }
    }
    return false
}

extension ChatInputContent: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? c.decode(Int32.self, forKey: .schemaVersion)) ?? 1
        // Lenient [ChatInputBlock] decode: the AdaptedPostbox objectArray decodes each element via a fresh
        // child decoder, so wrapping in _LenientChatInputBlock catches per-element failures without
        // corrupting the array cursor. Unknown/removed kinds (e.g. old "collapsedQuote" rawValue 2)
        // decode to block == nil and are filtered out. Mirrors Document's lenient block decode.
        let lenient = try c.decode([_LenientChatInputBlock].self, forKey: .blocks)
        blocks = lenient.compactMap(\.block)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(blocks, forKey: .blocks)
    }
}

/// A structured blockquote block carrying arbitrary nested `ChatInputContent`.
/// Mirrors `InstantPage.blockQuote`; the `collapsed` flag maps 1:1 to the wire field.
/// `collapsed == true` is the folded (hidden) state (one " " placeholder on the flat axis);
/// `collapsed == false` is the visible expanded state (inner content on the flat axis).
public struct ChatInputBlockQuote: Equatable {
    public var content: ChatInputContent
    public var collapsed: Bool
    /// Optional attribution ("author") line. `[]` = empty. Off the flat axis (never in plainText). Per-node.
    public var author: [ChatInputRun]
    public init(content: ChatInputContent, collapsed: Bool, author: [ChatInputRun] = []) {
        self.content = content
        self.collapsed = collapsed
        self.author = author
    }
}

extension ChatInputBlockQuote: Codable {
    private enum CodingKeys: String, CodingKey { case content, collapsed, author }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try c.decode(ChatInputContent.self, forKey: .content)
        self.collapsed = try c.decode(Bool.self, forKey: .collapsed)
        self.author = try c.decodeIfPresent([ChatInputRun].self, forKey: .author) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        try c.encode(collapsed, forKey: .collapsed)
        try c.encode(author, forKey: .author)
    }
}

/// A structured detail (folding) block carrying an editable title (summary) + arbitrary nested content.
/// Mirrors `InstantPage.details`; `expanded` maps 1:1 to the wire field (the inverse of a blockQuote's
/// `collapsed`). Off the flat caret axis (like `.media`/`.table`) — it round-trips via this structured
/// Codable + the InstantPage path, not via flat text.
public struct ChatInputDetails: Equatable {
    public var content: ChatInputContent
    public var title: [ChatInputRun]
    public var expanded: Bool
    public init(content: ChatInputContent, title: [ChatInputRun] = [], expanded: Bool = true) {
        self.content = content
        self.title = title
        self.expanded = expanded
    }
}

extension ChatInputDetails: Codable {
    private enum CodingKeys: String, CodingKey { case content, title, expanded }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try c.decode(ChatInputContent.self, forKey: .content)
        self.title = try c.decodeIfPresent([ChatInputRun].self, forKey: .title) ?? []
        self.expanded = try c.decodeIfPresent(Bool.self, forKey: .expanded) ?? true
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        try c.encode(title, forKey: .title)
        try c.encode(expanded, forKey: .expanded)
    }
}

public enum ChatInputBlock: Equatable, Codable {
    case paragraph(ChatInputParagraph)
    case code(ChatInputCode)
    // rawValue 2 (old "collapsedQuote") is permanently retired. Old drafts containing kind=2 are
    // lenient-skipped by ChatInputContent.init(from:). Do NOT reuse rawValue 2.
    /// An attached medium (image or video). Mirrors the editor `Block.media`; one placeholder in the flat text.
    case media(ChatInputMedia)
    /// A table. Mirrors the editor `Block.table`; one placeholder in the flat text (cell content is off-string).
    case table(ChatInputTable)
    /// A pull-quote block. Mirrors the editor `Block.pullQuote`. Always non-entity-expressible (forces the
    /// rich InstantPage path). On the flat axis — contributes its runs' text and an inter-block "\n" separator.
    case pullQuote(ChatInputPullQuote)
    /// A structured blockquote block carrying arbitrary nested content. Mirrors `InstantPage.blockQuote`.
    /// Collapsed → 1 " " placeholder on the flat axis; expanded → inner content on the flat axis.
    case blockQuote(ChatInputBlockQuote)
    case details(ChatInputDetails)
    case buttonRow(ChatInputButtonRow)

    private enum CodingKeys: String, CodingKey {
        case kind
        case paragraph
        case code
        case media
        case table
        case pullQuote
        case blockQuote
        case details
        case buttonRow
    }

    private enum Kind: Int32, Codable {
        case paragraph  = 0  // NEVER renumber: these are the persisted-draft discriminators.
        case code       = 1
        // 2 was collapsedQuote — retired. Kept as a gap so downstream rawValues are stable.
        case media      = 3
        case table      = 4
        case pullQuote  = 5
        case blockQuote = 6
        case details    = 7
        // NEVER renumber. 8 is the next free value: 2 is a deliberate gap (retired collapsedQuote).
        case buttonRow  = 8
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode the discriminator as the raw `Int32` (NOT `Kind.self`): the Postbox `AdaptedPostbox*coder` does
        // not support the `singleValueContainer` that a `RawRepresentable` enum's synthesized Codable uses.
        let kindValue = try container.decode(Int32.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindValue) else {
            // Unknown / removed kind (e.g. old "collapsedQuote" rawValue 2). Throw so that
            // ChatInputContent's lenient unkeyed-container loop can skip this block cleanly.
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown discriminator \(kindValue)")
        }
        switch kind {
        case .paragraph:
            self = .paragraph(try container.decode(ChatInputParagraph.self, forKey: .paragraph))
        case .code:
            self = .code(try container.decode(ChatInputCode.self, forKey: .code))
        case .media:
            self = .media(try container.decode(ChatInputMedia.self, forKey: .media))
        case .table:
            self = .table(try container.decode(ChatInputTable.self, forKey: .table))
        case .pullQuote:
            self = .pullQuote(try container.decode(ChatInputPullQuote.self, forKey: .pullQuote))
        case .blockQuote:
            self = .blockQuote(try container.decode(ChatInputBlockQuote.self, forKey: .blockQuote))
        case .details:
            self = .details(try container.decode(ChatInputDetails.self, forKey: .details))
        case .buttonRow:
            self = .buttonRow(try container.decode(ChatInputButtonRow.self, forKey: .buttonRow))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .paragraph(paragraph):
            try container.encode(Kind.paragraph.rawValue, forKey: .kind)
            try container.encode(paragraph, forKey: .paragraph)
        case let .code(code):
            try container.encode(Kind.code.rawValue, forKey: .kind)
            try container.encode(code, forKey: .code)
        case let .media(media):
            try container.encode(Kind.media.rawValue, forKey: .kind)
            try container.encode(media, forKey: .media)
        case let .table(table):
            try container.encode(Kind.table.rawValue, forKey: .kind)
            try container.encode(table, forKey: .table)
        case let .pullQuote(pq):
            try container.encode(Kind.pullQuote.rawValue, forKey: .kind)
            try container.encode(pq, forKey: .pullQuote)
        case let .blockQuote(bq):
            try container.encode(Kind.blockQuote.rawValue, forKey: .kind)
            try container.encode(bq, forKey: .blockQuote)
        case let .details(d):
            try container.encode(Kind.details.rawValue, forKey: .kind)
            try container.encode(d, forKey: .details)
        case let .buttonRow(row):
            try container.encode(Kind.buttonRow.rawValue, forKey: .kind)
            try container.encode(row, forKey: .buttonRow)
        }
    }
}

public struct ChatInputParagraph: Equatable, Codable {
    public var style: ChatInputParagraphStyle
    /// List membership (bullet/ordered + indent level), nil for a non-list paragraph. Mirrors the editor
    /// `ParagraphBlock.list`.
    public var list: ChatInputListMembership?
    public var runs: [ChatInputRun]
    public init(style: ChatInputParagraphStyle = .body, list: ChatInputListMembership? = nil, runs: [ChatInputRun] = []) {
        self.style = style
        self.list = list
        self.runs = runs
    }
    public var text: String { runs.map(\.text).joined() }
}

public enum ChatInputParagraphStyle: Equatable, Codable {
    case body
    // rawValue 1 (old "quote") is permanently retired. Old drafts decode this as .body (lenient).
    case heading1
    case heading2
    case heading3

    private enum CodingKeys: String, CodingKey {
        case kind
    }

    private enum Kind: Int32, Codable {
        case body     = 0
        // 1 was quote — retired; lenient decode falls back to .body for any unknown kind.
        case heading1 = 2
        case heading2 = 3
        case heading3 = 4
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode the discriminator as the raw `Int32` (NOT `Kind.self`): the Postbox `AdaptedPostbox*coder` does
        // not support the `singleValueContainer` that a `RawRepresentable` enum's synthesized Codable uses.
        let kindValue = try container.decode(Int32.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindValue) else {
            // Unknown / removed kind (e.g. old "quote" rawValue 1) — degrade to .body.
            self = .body
            return
        }
        switch kind {
        case .body:
            self = .body
        case .heading1:
            self = .heading1
        case .heading2:
            self = .heading2
        case .heading3:
            self = .heading3
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .body:
            try container.encode(Kind.body.rawValue, forKey: .kind)
        case .heading1:
            try container.encode(Kind.heading1.rawValue, forKey: .kind)
        case .heading2:
            try container.encode(Kind.heading2.rawValue, forKey: .kind)
        case .heading3:
            try container.encode(Kind.heading3.rawValue, forKey: .kind)
        }
    }
}

public struct ChatInputCode: Equatable, Codable {
    public var language: String?
    public var runs: [ChatInputRun]
    public init(language: String? = nil, runs: [ChatInputRun] = []) {
        self.language = language
        self.runs = runs
    }
    public var text: String { runs.map(\.text).joined() }
}

public struct ChatInputPullQuote: Equatable {
    public var runs: [ChatInputRun]
    /// Optional attribution ("author") line. `[]` = empty. Off the flat axis (never in plainText).
    public var author: [ChatInputRun]
    public init(runs: [ChatInputRun] = [], author: [ChatInputRun] = []) { self.runs = runs; self.author = author }
    public var text: String { runs.map(\.text).joined() }
}

extension ChatInputPullQuote: Codable {
    private enum CodingKeys: String, CodingKey { case runs, author }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.runs = try c.decode([ChatInputRun].self, forKey: .runs)
        self.author = try c.decodeIfPresent([ChatInputRun].self, forKey: .author) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(runs, forKey: .runs)
        try c.encode(author, forKey: .author)
    }
}

// MARK: - Structural value types (Document-parity)
//
// Each raw enum below carries a CUSTOM keyed `Codable` that encodes/decodes its `.rawValue` as an `Int32`
// via a keyed container — never the synthesized `RawRepresentable` Codable, which uses a `singleValueContainer`
// the Postbox `AdaptedPostbox*coder` does not support (it crashes at runtime). The dependent structs below can
// then synthesize `Codable`, because every member is itself Postbox-safe.

/// A list marker style. Mirrors the editor list marker.
public enum ChatInputListMarker: Int32, Equatable, Codable {
    case bullet = 0
    case ordered = 1
    case checklist = 2

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int32.self, forKey: .raw)
        guard let v = ChatInputListMarker(rawValue: value) else {
            throw DecodingError.dataCorruptedError(forKey: .raw, in: container, debugDescription: "Unknown ChatInputListMarker \(value)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .raw)
    }
}

/// List membership for a paragraph: marker style + 0-based indent level + optional checked state (checklist
/// items only). Mirrors the editor `ListMembership`.
public struct ChatInputListMembership: Equatable, Codable {
    public var marker: ChatInputListMarker
    public var level: Int32
    /// Whether this checklist item is checked. `nil` for bullet/ordered list items (marker ≠ `.checklist`).
    /// Synthesized `Codable` uses `encodeIfPresent`/`decodeIfPresent` for optional fields: a `nil` value is
    /// omitted on encode and an absent key decodes to `nil` — old payloads (no `checked` key) are back-compat.
    public var checked: Bool?
    public init(marker: ChatInputListMarker, level: Int32, checked: Bool? = nil) {
        self.marker = marker
        self.level = level
        self.checked = checked
    }
}

/// The medium's kind (image, video, location, audio, or document). Mirrors the editor `MediaKind`.
///
/// NOTE: `init(from:)` below throws on an unknown raw value, so an OLDER build decoding a
/// cross-device-synced draft containing `.document` (raw 4) fails that draft's decode. Accepted, and
/// consistent with the precedent set when `ChatInputListMarker.checklist` was added.
public enum ChatInputMediaKind: Int32, Equatable, Codable {
    case image = 0
    case video = 1
    case location = 2
    case audio = 3
    case document = 4

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int32.self, forKey: .raw)
        guard let v = ChatInputMediaKind(rawValue: value) else {
            throw DecodingError.dataCorruptedError(forKey: .raw, in: container, debugDescription: "Unknown ChatInputMediaKind \(value)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .raw)
    }
}

/// Horizontal alignment of a medium. Mirrors the editor `MediaAlignment`.
public enum ChatInputMediaAlignment: Int32, Equatable, Codable {
    case left = 0
    case center = 1
    case right = 2

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int32.self, forKey: .raw)
        guard let v = ChatInputMediaAlignment(rawValue: value) else {
            throw DecodingError.dataCorruptedError(forKey: .raw, in: container, debugDescription: "Unknown ChatInputMediaAlignment \(value)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .raw)
    }
}

/// Per-cell text alignment for a table cell. Mirrors the editor `TextAlignment` (markdown delimiter-row colons).
public enum ChatInputTextAlignment: Int32, Equatable, Codable {
    case left = 0
    case center = 1
    case right = 2
    case justified = 3

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int32.self, forKey: .raw)
        guard let v = ChatInputTextAlignment(rawValue: value) else {
            throw DecodingError.dataCorruptedError(forKey: .raw, in: container, debugDescription: "Unknown ChatInputTextAlignment \(value)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .raw)
    }
}

/// Per-cell vertical alignment for a table. Mirrors the editor's cell vertical-alignment setting.
public enum ChatInputTableVerticalAlignment: Int32, Equatable, Codable {
    case top = 0
    case middle = 1
    case bottom = 2

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int32.self, forKey: .raw)
        guard let v = ChatInputTableVerticalAlignment(rawValue: value) else {
            throw DecodingError.dataCorruptedError(forKey: .raw, in: container, debugDescription: "Unknown ChatInputTableVerticalAlignment \(value)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .raw)
    }
}

/// A 2D size in points. Synthesized `Codable` (both members are `Double`).
public struct ChatInputSize: Equatable, Codable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// An RGBA color (0...1 channels). Synthesized `Codable` (all members are `Double`).
public struct ChatInputColor: Equatable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// One medium (image or video) inside a `ChatInputMedia` container. Carries a concrete `Media` (resolved from
/// the editor's opaque `mediaID` at conversion time). Mirrors the editor `MediaItem`.
public struct ChatInputMediaItem: Equatable {
    public var media: Media
    public var kind: ChatInputMediaKind
    public var naturalSize: ChatInputSize
    /// Telegram-style spoiler: the medium renders behind an animated "dust" overlay until tapped.
    /// Optional Codable (absent key → `false`), so pre-spoiler drafts/messages decode unchanged.
    public var isSpoiler: Bool
    public init(media: Media, kind: ChatInputMediaKind, naturalSize: ChatInputSize, isSpoiler: Bool = false) {
        self.media = media
        self.kind = kind
        self.naturalSize = naturalSize
        self.isSpoiler = isSpoiler
    }
    public static func == (lhs: ChatInputMediaItem, rhs: ChatInputMediaItem) -> Bool {
        return lhs.media.isEqual(to: rhs.media) && lhs.kind == rhs.kind && lhs.naturalSize == rhs.naturalSize && lhs.isSpoiler == rhs.isSpoiler
    }
}

extension ChatInputMediaItem: Codable {
    private enum CodingKeys: String, CodingKey { case media, mediaType, kind, naturalSize, isSpoiler }
    // Concrete-`Media`-type discriminator (see ChatInputMedia notes — the same scheme, per item).
    private enum MediaType: Int32 { case image = 0; case file = 1; case map = 2 }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .media)
        let mediaDecoder = PostboxDecoder(buffer: MemoryBuffer(data: raw.data))
        let mediaTypeValue = try container.decode(Int32.self, forKey: .mediaType)
        guard let mediaType = MediaType(rawValue: mediaTypeValue) else {
            throw DecodingError.dataCorruptedError(forKey: .mediaType, in: container, debugDescription: "Unsupported media type \(mediaTypeValue)")
        }
        switch mediaType {
        case .image: self.media = TelegramMediaImage(decoder: mediaDecoder)
        case .file: self.media = TelegramMediaFile(decoder: mediaDecoder)
        case .map: self.media = TelegramMediaMap(decoder: mediaDecoder)
        }
        self.kind = try container.decode(ChatInputMediaKind.self, forKey: .kind)
        self.naturalSize = try container.decode(ChatInputSize.self, forKey: .naturalSize)
        self.isSpoiler = try container.decodeIfPresent(Bool.self, forKey: .isSpoiler) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let mediaType: MediaType
        if self.media is TelegramMediaImage { mediaType = .image }
        else if self.media is TelegramMediaMap { mediaType = .map }
        else if self.media is TelegramMediaFile { mediaType = .file }
        else { mediaType = .file }
        try container.encode(mediaType.rawValue, forKey: .mediaType)
        try container.encode(PostboxEncoder().encodeObjectToRawData(self.media), forKey: .media)
        try container.encode(self.kind, forKey: .kind)
        try container.encode(self.naturalSize, forKey: .naturalSize)
        try container.encode(self.isSpoiler, forKey: .isSpoiler)
    }
}

/// Mirrors the editor's `MediaDisplayMode` — how a multi-item container lays out (mosaic → `.collage`,
/// slideshow → `.slideshow`). Meaningful only for `items.count >= 2`; default `.mosaic`.
///
/// Like the `Int32` raw enums above, this carries a CUSTOM keyed `Codable` that encodes its `String` `.rawValue`
/// under a keyed container — never the synthesized `RawRepresentable` Codable, which uses a `singleValueContainer`
/// the Postbox `AdaptedPostbox*coder` does not support (it crashes at runtime, e.g. when a draft's
/// `ChatInputMedia` block is persisted).
public enum ChatInputMediaDisplayMode: String, Equatable, Codable {
    case mosaic
    case slideshow

    private enum CodingKeys: String, CodingKey {
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .raw)
        guard let v = ChatInputMediaDisplayMode(rawValue: value) else {
            throw DecodingError.dataCorruptedError(forKey: .raw, in: container, debugDescription: "Unknown ChatInputMediaDisplayMode \(value)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .raw)
    }
}

/// An attached media container (one or more images/videos) with a single inline caption. Mirrors the editor
/// `MediaBlock` — items carry concrete `Media` (resolved from the editor's opaque `mediaID` at conversion time).
public struct ChatInputMedia: Equatable {
    public var items: [ChatInputMediaItem]
    /// Display width in points; nil = natural width. Honored only when `items.count == 1`.
    public var displayWidth: Double?
    /// Honored only when `items.count == 1`.
    public var alignment: ChatInputMediaAlignment
    /// Layout mode for a multi-item container; honored only when `items.count >= 2`. Default `.mosaic`.
    public var displayMode: ChatInputMediaDisplayMode
    public var caption: [ChatInputRun]

    public init(items: [ChatInputMediaItem], displayWidth: Double? = nil,
                alignment: ChatInputMediaAlignment = .center, displayMode: ChatInputMediaDisplayMode = .mosaic,
                caption: [ChatInputRun] = []) {
        self.items = items
        self.displayWidth = displayWidth
        self.alignment = alignment
        self.displayMode = displayMode
        self.caption = caption
    }

    /// Convenience single-media initializer — reproduces the pre-container API.
    public init(media: Media, kind: ChatInputMediaKind, naturalSize: ChatInputSize,
                displayWidth: Double? = nil, alignment: ChatInputMediaAlignment = .center,
                displayMode: ChatInputMediaDisplayMode = .mosaic,
                caption: [ChatInputRun] = []) {
        self.init(items: [ChatInputMediaItem(media: media, kind: kind, naturalSize: naturalSize)],
                  displayWidth: displayWidth, alignment: alignment, displayMode: displayMode, caption: caption)
    }

    // Single-media convenience accessors (FIRST item).
    public var media: Media { items[0].media }
    public var kind: ChatInputMediaKind { items[0].kind }
    public var naturalSize: ChatInputSize { items[0].naturalSize }

    public static func == (lhs: ChatInputMedia, rhs: ChatInputMedia) -> Bool {
        return lhs.items == rhs.items
            && lhs.displayWidth == rhs.displayWidth
            && lhs.alignment == rhs.alignment
            && lhs.displayMode == rhs.displayMode
            && lhs.caption == rhs.caption
    }
}

extension ChatInputMedia: Codable {
    private enum CodingKeys: String, CodingKey {
        case items, displayWidth, alignment, displayMode, caption
        // Legacy (pre-container) single-media keys:
        case media, mediaType, kind, naturalSize
    }
    private enum MediaType: Int32 { case image = 0; case file = 1; case map = 2 }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayWidth = try container.decodeIfPresent(Double.self, forKey: .displayWidth)
        self.alignment = try container.decode(ChatInputMediaAlignment.self, forKey: .alignment)
        self.displayMode = try container.decodeIfPresent(ChatInputMediaDisplayMode.self, forKey: .displayMode) ?? .mosaic
        self.caption = try container.decode([ChatInputRun].self, forKey: .caption)
        if let items = try container.decodeIfPresent([ChatInputMediaItem].self, forKey: .items) {
            self.items = items
        } else {
            // Legacy single-media payload → one item.
            let raw = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .media)
            let mediaDecoder = PostboxDecoder(buffer: MemoryBuffer(data: raw.data))
            let mediaTypeValue = try container.decode(Int32.self, forKey: .mediaType)
            guard let mediaType = MediaType(rawValue: mediaTypeValue) else {
                throw DecodingError.dataCorruptedError(forKey: .mediaType, in: container, debugDescription: "Unsupported media type \(mediaTypeValue)")
            }
            let media: Media
            switch mediaType {
            case .image: media = TelegramMediaImage(decoder: mediaDecoder)
            case .file: media = TelegramMediaFile(decoder: mediaDecoder)
            case .map: media = TelegramMediaMap(decoder: mediaDecoder)
            }
            let kind = try container.decode(ChatInputMediaKind.self, forKey: .kind)
            let naturalSize = try container.decode(ChatInputSize.self, forKey: .naturalSize)
            self.items = [ChatInputMediaItem(media: media, kind: kind, naturalSize: naturalSize)]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.items, forKey: .items)
        try container.encodeIfPresent(self.displayWidth, forKey: .displayWidth)
        try container.encode(self.alignment, forKey: .alignment)
        try container.encode(self.displayMode, forKey: .displayMode)
        try container.encode(self.caption, forKey: .caption)
    }
}

/// A table column: width only (alignment is per-cell — see `ChatInputTableCell`).
public struct ChatInputColumnSpec: Equatable, Codable {
    public var width: Double
    public init(width: Double) {
        self.width = width
    }
}

/// A table cell — INLINE-ONLY (a flat run list; no nested blocks). Per-cell H+V alignment.
public struct ChatInputTableCell: Equatable, Codable {
    public var runs: [ChatInputRun]
    public var background: ChatInputColor?
    public var horizontalAlignment: ChatInputTextAlignment
    public var verticalAlignment: ChatInputTableVerticalAlignment
    /// Per-cell header/highlight flag (replaces the old whole-row header).
    public var isHeader: Bool
    /// Number of grid columns this cell spans (default 1). Mirrors the editor `Cell.colspan`.
    public var colspan: Int
    /// Number of grid rows this cell spans (default 1). Mirrors the editor `Cell.rowspan`.
    public var rowspan: Int
    public init(runs: [ChatInputRun] = [], background: ChatInputColor? = nil,
                horizontalAlignment: ChatInputTextAlignment = .center, verticalAlignment: ChatInputTableVerticalAlignment = .top,
                isHeader: Bool = false, colspan: Int = 1, rowspan: Int = 1) {
        self.runs = runs
        self.background = background
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.isHeader = isHeader
        self.colspan = colspan
        self.rowspan = rowspan
    }
    private enum CodingKeys: String, CodingKey { case runs, background, horizontalAlignment, verticalAlignment, isHeader, colspan, rowspan }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runs = try c.decodeIfPresent([ChatInputRun].self, forKey: .runs) ?? []
        background = try c.decodeIfPresent(ChatInputColor.self, forKey: .background)
        horizontalAlignment = try c.decodeIfPresent(ChatInputTextAlignment.self, forKey: .horizontalAlignment) ?? .center
        verticalAlignment = try c.decodeIfPresent(ChatInputTableVerticalAlignment.self, forKey: .verticalAlignment) ?? .top
        isHeader = try c.decodeIfPresent(Bool.self, forKey: .isHeader) ?? false
        // Decoded (and encoded, below) as `Int32`, NOT `Int`: the Postbox `AdaptedPostbox*coder` has no
        // `Int`-typed encode/decode overload (only Int32/Int64) — its keyed containers either assert (encode)
        // or silently mismatch (decode) on a bare `Int`. `colspan`/`rowspan` stay `Int` in the public model
        // (mirroring the editor `Cell.colspan`/`rowspan`); only the wire representation is `Int32`.
        colspan = try c.decodeIfPresent(Int32.self, forKey: .colspan).map(Int.init) ?? 1
        rowspan = try c.decodeIfPresent(Int32.self, forKey: .rowspan).map(Int.init) ?? 1
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(runs, forKey: .runs)
        try c.encodeIfPresent(background, forKey: .background)
        try c.encode(horizontalAlignment, forKey: .horizontalAlignment)
        try c.encode(verticalAlignment, forKey: .verticalAlignment)
        try c.encode(isHeader, forKey: .isHeader)
        try c.encode(Int32(colspan), forKey: .colspan)
        try c.encode(Int32(rowspan), forKey: .rowspan)
    }
}

/// A table row. `isHeader` is derived from the cells (per-cell is the source of truth).
public struct ChatInputTableRow: Equatable {
    public var height: Double?
    public var cells: [ChatInputTableCell]
    public var isHeader: Bool { !cells.isEmpty && cells.allSatisfy { $0.isHeader } }
    /// `isHeader: true` seeds every cell as a header cell; `false` leaves each cell's own flag untouched.
    public init(height: Double? = nil, isHeader: Bool = false, cells: [ChatInputTableCell] = []) {
        self.height = height
        self.cells = isHeader ? cells.map { var c = $0; c.isHeader = true; return c } : cells
    }
}

extension ChatInputTableRow: Codable {
    private enum CodingKeys: String, CodingKey { case height, cells; case legacyIsHeader = "isHeader" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        height = try c.decodeIfPresent(Double.self, forKey: .height)
        var decodedCells = try c.decodeIfPresent([ChatInputTableCell].self, forKey: .cells) ?? []
        if (try c.decodeIfPresent(Bool.self, forKey: .legacyIsHeader)) == true {
            decodedCells = decodedCells.map { var cell = $0; cell.isHeader = true; return cell }
        }
        cells = decodedCells
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(height, forKey: .height)
        try c.encode(cells, forKey: .cells)
        // Deliberately omits `isHeader` — derived from cells.
    }
}

/// A table. Synthesized `Codable`.
public struct ChatInputTable: Equatable, Codable {
    public var columns: [ChatInputColumnSpec]
    public var rows: [ChatInputTableRow]
    /// Render-only: halve every cell's interior padding. Mirrors `pageBlockTable`'s `compact` flag.
    public var compact: Bool
    /// `pageBlockTable`'s `bordered` flag. Defaults TRUE — a table persisted before this field existed
    /// was always bordered, and the forward converter hard-coded `bordered: true`.
    public var bordered: Bool
    public init(columns: [ChatInputColumnSpec] = [], rows: [ChatInputTableRow] = [], compact: Bool = false,
                bordered: Bool = true) {
        self.columns = columns
        self.rows = rows
        self.compact = compact
        self.bordered = bordered
    }
    private enum CodingKeys: String, CodingKey { case columns, rows, compact, bordered }
    // Custom decode so drafts persisted before `compact` / `bordered` existed still load. Encoding stays
    // synthesized.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        columns = try c.decodeIfPresent([ChatInputColumnSpec].self, forKey: .columns) ?? []
        rows = try c.decodeIfPresent([ChatInputTableRow].self, forKey: .rows) ?? []
        compact = try c.decodeIfPresent(Bool.self, forKey: .compact) ?? false
        // Absent => true: an older draft's table was always bordered.
        bordered = try c.decodeIfPresent(Bool.self, forKey: .bordered) ?? true
    }
}

/// One step descending the block tree: pick a block at this level, then which of its nested-content slots to
/// descend into. `slot` is unused at the LEAF step (a text block has no nested content) — 0 by convention.
public struct ChatInputPathStep: Equatable {
    public var blockIndex: Int
    public var slot: Int
    public init(blockIndex: Int, slot: Int = 0) {
        self.blockIndex = blockIndex
        self.slot = slot
    }
}

/// A caret position: a non-empty path of `(blockIndex, slot)` steps through the (possibly nested) block tree to
/// a UTF-16 `offset` within the addressed text-leaf block. Today the editor produces only depth-1 paths (the
/// flat string contains only top-level, unfolded content); deeper paths are reserved for future nested editing.
public struct ChatInputPosition: Equatable {
    public var path: [ChatInputPathStep]
    public var offset: Int
    public init(path: [ChatInputPathStep], offset: Int) {
        self.path = path
        self.offset = offset
    }
}

public struct ChatInputSelection: Equatable {
    public var start: ChatInputPosition
    public var end: ChatInputPosition
    public init(start: ChatInputPosition, end: ChatInputPosition) {
        self.start = start
        self.end = end
    }
    public var isCollapsed: Bool { start == end }
}

public extension ChatInputContent {
    /// Whether a block lives on the flat caret axis (`plainText`): paragraphs, code, pullQuote, and blockQuote
    /// do (they contribute text / a " " placeholder + an inter-block "\n"); `.media`/`.table` do NOT (off-axis
    /// — no character, no separator), so a non-text block has no flat-text/caret position. Mirrors which blocks
    /// `attributedString(from:)` emits and the editor's `composerParagraphs()` keeps.
    func blockIsFlatParticipating(_ block: ChatInputBlock) -> Bool {
        switch block {
        case .paragraph, .code, .pullQuote, .blockQuote:
            return true
        case .media, .table, .details, .buttonRow:
            return false
        }
    }

    /// Flat (caret) extent of a top-level block in `plainText`: a paragraph/code block contributes its text
    /// length; a `.blockQuote(collapsed: true)` contributes 1 (its " " placeholder); a collapsed blockQuote's
    /// nested content is off-string; a `.media`/`.table` block contributes 0 (off-axis — see
    /// `blockIsFlatParticipating`).
    private func blockFlatLength(_ block: ChatInputBlock) -> Int {
        switch block {
        case let .paragraph(paragraph):
            return (paragraph.text as NSString).length
        case let .code(code):
            return (code.text as NSString).length
        case let .pullQuote(pq):
            return (pq.text as NSString).length
        case let .blockQuote(bq):
            // Collapsed → 1 (the " " placeholder); expanded → the recursed interior flat length
            // (the inner ChatInputContent's plainText already applies the same inter-block accounting).
            return bq.collapsed ? 1 : (bq.content.plainText as NSString).length
        case .media, .table, .details, .buttonRow:
            return 0
        }
    }

    /// Map a structural position to a flat UTF-16 offset into `plainText`. Only depth-1 positions (the editing
    /// surface today) round-trip exactly; a deeper path (into not-yet-unfolded nested content, which has no flat
    /// representation) clamps to the addressed top-level block's start. Off-axis (`.media`/`.table`) blocks
    /// contribute neither length nor a separator, so the flat space matches `plainText` exactly; a position that
    /// addresses an off-axis block (defensive — the editor never selects into one) clamps to that boundary.
    func flatOffset(for position: ChatInputPosition) -> Int {
        guard let first = position.path.first else {
            return 0
        }
        let count = self.blocks.count
        if count == 0 {
            return 0
        }
        let blockIndex = min(max(first.blockIndex, 0), count - 1)
        var flat = 0
        var hasEmitted = false
        for i in 0 ... blockIndex {
            let block = self.blocks[i]
            guard blockIsFlatParticipating(block) else {
                // Off-axis block: no flat position. If it is the addressed block, clamp to the current boundary
                // (== just after the previous participating block; it adds no separator).
                if i == blockIndex { return flat }
                continue
            }
            if hasEmitted { flat += 1 } // the inter-block "\n" preceding this participating block
            if i == blockIndex {
                if position.path.count == 1 {
                    let leafLength = blockFlatLength(block)
                    return flat + min(max(position.offset, 0), leafLength)
                }
                return flat
            }
            hasEmitted = true
            flat += blockFlatLength(block)
        }
        return flat
    }

    /// Map a flat UTF-16 offset (into `plainText`) to a structural position. Always a depth-1 path — the flat
    /// string only contains top-level, unfolded content. Off-axis (`.media`/`.table`) blocks are skipped (they
    /// hold no flat position), so an offset never resolves INTO one; offsets straddling an inter-block "\n"
    /// resolve cleanly (the "\n" is its own index: `endOfBlockI` and `startOfBlockI+1` are distinct).
    func position(forFlatOffset rawOffset: Int) -> ChatInputPosition {
        let total = (self.plainText as NSString).length
        let offset = min(max(rawOffset, 0), total)
        var cursor = 0
        var hasEmitted = false
        var lastParticipatingIndex = 0
        for (i, block) in self.blocks.enumerated() {
            guard blockIsFlatParticipating(block) else { continue }
            if hasEmitted { cursor += 1 } // step past the inter-block "\n" to this block's start
            hasEmitted = true
            let length = blockFlatLength(block)
            if offset <= cursor + length {
                return ChatInputPosition(path: [ChatInputPathStep(blockIndex: i)], offset: max(0, offset - cursor))
            }
            cursor += length
            lastParticipatingIndex = i
        }
        // Past the end, or no participating blocks at all: clamp to the last participating block's end (else the
        // last block / block 0 at offset 0).
        let clampIndex = hasEmitted ? lastParticipatingIndex : max(self.blocks.count - 1, 0)
        let clampLength = self.blocks.indices.contains(clampIndex) ? blockFlatLength(self.blocks[clampIndex]) : 0
        return ChatInputPosition(path: [ChatInputPathStep(blockIndex: clampIndex)], offset: clampLength)
    }
}

public extension ChatInputSelection {
    /// The ordered flat `NSRange` (into `content.plainText`) for this selection.
    func nsRange(in content: ChatInputContent) -> NSRange {
        let a = content.flatOffset(for: self.start)
        let b = content.flatOffset(for: self.end)
        let lo = min(a, b)
        let hi = max(a, b)
        return NSRange(location: lo, length: hi - lo)
    }

    /// Build a selection from a flat `NSRange` (into `content.plainText`).
    init(nsRange: NSRange, in content: ChatInputContent) {
        self.init(
            start: content.position(forFlatOffset: nsRange.location),
            end: content.position(forFlatOffset: nsRange.location + nsRange.length)
        )
    }
}
