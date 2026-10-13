import Foundation

/// An InstantPage button — the shared model behind an inline `RichText.textButton` (carried on a
/// one-`U+FFFC` `TextRun` via `CharacterAttributes.button`) and a member of a `ButtonRowBlock`.
///
/// The label lives INSIDE the button rather than being the carrying run's text. A button is an atom
/// in every text-shaping helper the InstantPage renderer has, and making the label flow text would
/// put a caret inside a pill.
public struct ButtonRef: Codable, Equatable {
    public var label: [TextRun]
    public var action: ButtonAction
    /// `nil` = the default (neutral) pill colour.
    public var color: ButtonColor?
    /// The schema's `richButtonStyle.link` bit. Independent of `color` so `link + danger` round-trips
    /// losslessly even though the renderer makes `link` win.
    public var isLink: Bool

    public init(label: [TextRun], action: ButtonAction, color: ButtonColor? = nil, isLink: Bool = false) {
        self.label = label
        self.action = action
        self.color = color
        self.isLink = isLink
    }

    /// The label's plain text — what a plain-text field in a host property sheet shows.
    public var labelText: String { label.map(\.text).joined() }
}

/// What a button does. Only `.url` is authorable in the editor; the rest exist to PRESERVE an
/// incoming button through the edit round-trip.
///
/// `.unsupported` is how this Telegram-free module carries the actions it cannot name (callback,
/// web view, payment, …). `kind` and `payload` are produced and consumed EXCLUSIVELY by
/// `ButtonActionCodec` in `RichTextEditorMessageConversion`; nothing in Core interprets either.
public enum ButtonAction: Codable, Equatable {
    case url(String)
    case copyText(String)
    case disabled
    case unsupported(kind: String, payload: String)

    private enum CodingKeys: String, CodingKey { case type, value, kind }
    private enum Kind: String, Codable { case url, copyText, disabled, unsupported }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .url:         self = .url(try c.decode(String.self, forKey: .value))
        case .copyText:    self = .copyText(try c.decode(String.self, forKey: .value))
        case .disabled:    self = .disabled
        case .unsupported: self = .unsupported(kind: try c.decode(String.self, forKey: .kind),
                                               payload: try c.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .url(value):
            try c.encode(Kind.url, forKey: .type)
            try c.encode(value, forKey: .value)
        case let .copyText(value):
            try c.encode(Kind.copyText, forKey: .type)
            try c.encode(value, forKey: .value)
        case .disabled:
            try c.encode(Kind.disabled, forKey: .type)
        case let .unsupported(kind, payload):
            try c.encode(Kind.unsupported, forKey: .type)
            try c.encode(kind, forKey: .kind)
            try c.encode(payload, forKey: .value)
        }
    }
}

/// Raw values are PERSISTED and must equal `ReplyMarkupButton.Style.Color` in TelegramCore.
public enum ButtonColor: Int32, Codable, Equatable {
    case primary = 0
    case danger = 1
    case success = 2
}

/// Raw values are PERSISTED and must equal `InstantPageButtonRowAlignment` in TelegramCore.
/// `justify = 0` is what lets cached pages keep the old layout with no migration.
public enum ButtonRowAlignment: Int32, Codable, Equatable {
    case justify = 0
    case left = 1
    case center = 2
    case right = 3
}

/// A block-level row of buttons — `InstantPageBlock.buttonRow`. The row owns the alignment; a pill
/// does not, so a malformed per-pill alignment is not representable.
public struct ButtonRowBlock: Codable, Equatable {
    public var id: BlockID
    public var buttons: [ButtonRef]
    public var alignment: ButtonRowAlignment

    public init(id: BlockID, buttons: [ButtonRef] = [], alignment: ButtonRowAlignment = .justify) {
        self.id = id
        self.buttons = buttons
        self.alignment = alignment
    }
}

public extension Document {
    /// Rewrites every `.unsupported` button action to `.disabled`, recursing containers and table cells.
    ///
    /// Applied when a fragment is PASTED into a document. An `.unsupported` action is an opaque blob —
    /// a callback payload, a web-app URL, a payment binding — that belongs to the message it arrived in.
    /// Pasted somewhere else it can never work, and the editor cannot show or edit it, so carrying it
    /// would produce a button that silently does nothing on the recipient's side. `.disabled` is the
    /// honest representation, and it is exactly what the wire uses for a button whose action was
    /// stripped (`inlineButtonTypeDisabled`).
    ///
    /// Deliberately NOT applied on the edit round-trip: reopening a message for edit must preserve its
    /// original actions verbatim, which is the whole point of the opaque carrier. That path goes through
    /// the `document` setter, not a fragment splice.
    ///
    /// `.copyText` is left alone — its payload is self-contained text that still works anywhere.
    func convertingUnsupportedButtonActions() -> Document {
        Document(schemaVersion: schemaVersion, blocks: convertUnsupportedButtonActions(blocks))
    }
}

private func convertUnsupportedButtonAction(_ button: ButtonRef) -> ButtonRef {
    guard case .unsupported = button.action else {
        return button
    }
    var result = button
    result.action = .disabled
    return result
}

private func convertUnsupportedButtonActions(_ runs: [TextRun]) -> [TextRun] {
    runs.map { run in
        guard let button = run.attributes.button else {
            return run
        }
        var result = run
        result.attributes.button = convertUnsupportedButtonAction(button)
        return result
    }
}

private func convertUnsupportedButtonActions(_ blocks: [Block]) -> [Block] {
    blocks.map { block in
        switch block {
        case let .buttonRow(row):
            var result = row
            result.buttons = row.buttons.map(convertUnsupportedButtonAction)
            return .buttonRow(result)
        case let .paragraph(paragraph):
            var result = paragraph
            result.runs = convertUnsupportedButtonActions(paragraph.runs)
            return .paragraph(result)
        case let .code(code):
            var result = code
            result.runs = convertUnsupportedButtonActions(code.runs)
            return .code(result)
        case let .pullQuote(pq):
            var result = pq
            result.runs = convertUnsupportedButtonActions(pq.runs)
            result.author = convertUnsupportedButtonActions(pq.author)
            return .pullQuote(result)
        case let .media(media):
            var result = media
            result.caption = convertUnsupportedButtonActions(media.caption)
            return .media(result)
        case let .blockQuote(bq):
            var result = bq
            result.children = convertUnsupportedButtonActions(bq.children)
            result.author = convertUnsupportedButtonActions(bq.author)
            return .blockQuote(result)
        case let .details(d):
            var result = d
            result.title = convertUnsupportedButtonActions(d.title)
            result.children = convertUnsupportedButtonActions(d.children)
            return .details(result)
        case let .table(table):
            var result = table
            result.rows = table.rows.map { row in
                var newRow = row
                newRow.cells = row.cells.map { cell in
                    var newCell = cell
                    newCell.blocks = convertUnsupportedButtonActions(cell.blocks)
                    return newCell
                }
                return newRow
            }
            return .table(result)
        }
    }
}
