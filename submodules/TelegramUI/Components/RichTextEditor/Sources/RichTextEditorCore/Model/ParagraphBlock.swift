import Foundation

public struct ParagraphBlock: Codable, Equatable {
    public var id: BlockID
    public var style: ParagraphStyleName
    public var paragraph: ParagraphAttributes
    public var list: ListMembership?
    public var runs: [TextRun]

    public init(
        id: BlockID,
        style: ParagraphStyleName = .body,
        paragraph: ParagraphAttributes = .default,
        list: ListMembership? = nil,
        runs: [TextRun] = []
    ) {
        self.id = id
        self.style = style
        self.paragraph = paragraph
        self.list = list
        self.runs = runs
    }

    /// The plain text of the paragraph (runs concatenated).
    public var text: String { runs.map(\.text).joined() }

    /// Total UTF-16 length of the paragraph's text.
    public var utf16Count: Int { runs.reduce(0) { $0 + $1.utf16Count } }
}
