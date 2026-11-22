import Foundation

/// A block quote: a recursive container of child blocks with a collapse flag. Mirrors the InstantPage wire
/// `.blockQuote(blocks:, caption:, collapsed:)`. Children may be ANY block, including nested block quotes.
public struct BlockQuote: Equatable {
    public var id: BlockID
    public var children: [Block]
    public var collapsed: Bool
    /// Optional attribution ("author") line rendered below the quote content. Always-present; `[]` = empty.
    /// Render-only bold (see BlockQuoteBox); bold never persists here. Off the flat plainText axis. Per-node
    /// (each nested block quote carries its own).
    public var author: [TextRun]

    public init(id: BlockID, children: [Block] = [], collapsed: Bool = false, author: [TextRun] = []) {
        self.id = id; self.children = children; self.collapsed = collapsed; self.author = author
    }

    /// Total UTF-16 length of the author line.
    public var authorUTF16Count: Int { author.reduce(0) { $0 + $1.utf16Count } }
}

extension BlockQuote: Codable {
    private enum CodingKeys: String, CodingKey { case id, children, collapsed, author }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(BlockID.self, forKey: .id)
        self.children = try c.decode([Block].self, forKey: .children)
        self.collapsed = try c.decode(Bool.self, forKey: .collapsed)
        self.author = try c.decodeIfPresent([TextRun].self, forKey: .author) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(children, forKey: .children)
        try c.encode(collapsed, forKey: .collapsed)
        try c.encode(author, forKey: .author)
    }
}
