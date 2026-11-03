import Foundation

/// A pull quote: one text-only block holding multi-line rich text (interior "\n"s), rendered centered +
/// italic inside a content-hugging tinted pill with corner quote marks. Unlike a paragraph, its runs may
/// contain "\n" — the whole block is one editable unit. Unlike a code block, its runs keep full inline
/// formatting (bold/underline/link/color/emoji); the italic + center are render-only and never stored here.
public struct PullQuote: Equatable {
    public var id: BlockID
    public var runs: [TextRun]
    /// Optional attribution ("author") line rendered below the quote. Always-present region; `[]` = empty.
    /// Render-only bold (see PullQuoteBox); bold never persists here. Off the flat plainText axis.
    public var author: [TextRun]

    public init(id: BlockID, runs: [TextRun] = [], author: [TextRun] = []) {
        self.id = id
        self.runs = runs
        self.author = author
    }

    /// The plain text of the block (runs concatenated; may contain "\n").
    public var text: String { runs.map(\.text).joined() }

    /// Total UTF-16 length of the block's text.
    public var utf16Count: Int { runs.reduce(0) { $0 + $1.utf16Count } }

    /// Total UTF-16 length of the author line.
    public var authorUTF16Count: Int { author.reduce(0) { $0 + $1.utf16Count } }
}

extension PullQuote: Codable {
    private enum CodingKeys: String, CodingKey { case id, runs, author }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(BlockID.self, forKey: .id)
        self.runs = try c.decode([TextRun].self, forKey: .runs)
        self.author = try c.decodeIfPresent([TextRun].self, forKey: .author) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(runs, forKey: .runs)
        try c.encode(author, forKey: .author)
    }
}
