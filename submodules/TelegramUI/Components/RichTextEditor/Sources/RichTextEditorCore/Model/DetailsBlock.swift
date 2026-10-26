import Foundation

/// A detail (folding) block: a recursive container of child blocks with an always-visible, editable title
/// (summary) line and an `expanded` flag. Mirrors the InstantPage wire `.details(title:, blocks:, expanded:)`.
/// Children may be ANY block, including nested detail blocks. `expanded` is the INVERSE of `BlockQuote.collapsed`
/// (true = open) and maps directly to `InstantPageBlock.details(expanded:)`. The title is always present (unlike
/// the block-quote author, which is content-gated). Title render styling never persists (see DetailsBox read-back).
public struct DetailsBlock: Equatable {
    public var id: BlockID
    public var title: [TextRun]
    public var children: [Block]
    public var expanded: Bool

    public init(id: BlockID, title: [TextRun] = [], children: [Block] = [], expanded: Bool = true) {
        self.id = id
        self.title = title
        self.children = children
        self.expanded = expanded
    }

    /// Total UTF-16 length of the title line.
    public var titleUTF16Count: Int { title.reduce(0) { $0 + $1.utf16Count } }
}

extension DetailsBlock: Codable {
    private enum CodingKeys: String, CodingKey { case id, title, children, expanded }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(BlockID.self, forKey: .id)
        self.title = try c.decodeIfPresent([TextRun].self, forKey: .title) ?? []
        self.children = try c.decode([Block].self, forKey: .children)
        self.expanded = try c.decodeIfPresent(Bool.self, forKey: .expanded) ?? true
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(children, forKey: .children)
        try c.encode(expanded, forKey: .expanded)
    }
}
