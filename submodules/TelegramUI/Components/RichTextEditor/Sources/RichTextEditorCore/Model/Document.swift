import Foundation

// Used by Document's lenient [Block] decode: consumes one JSON element without throwing, so an
// unknown or removed block kind is skipped rather than making the whole document fail to load.
private struct AnyCodableSkip: Decodable {}

public struct Document: Codable, Equatable {
    public var schemaVersion: Int
    public var blocks: [Block]
    /// Whole-document writing-direction override. `.auto` = per-paragraph auto-detect.
    public var layoutDirection: DocumentLayoutDirection

    public init(schemaVersion: Int = 1, blocks: [Block] = [],
                layoutDirection: DocumentLayoutDirection = .auto) {
        self.schemaVersion = schemaVersion
        self.blocks = blocks
        self.layoutDirection = layoutDirection
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, blocks, layoutDirection }

    // Custom decode so a document missing `schemaVersion`/`layoutDirection` defaults sanely (the
    // synthesized decode would throw on a missing key). Encode is synthesized over CodingKeys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        // Lenient [Block] decode: unknown/removed block kinds (e.g. old "collapsedQuote") are skipped
        // rather than throwing, so persisted data with removed block types still loads cleanly.
        var arr = try c.nestedUnkeyedContainer(forKey: .blocks)
        var out: [Block] = []
        while !arr.isAtEnd {
            let before = arr.currentIndex
            if let b = try? arr.decode(Block.self) {
                out.append(b)
            } else if arr.currentIndex == before {
                // The failed decode did NOT advance the index — consume the bad element manually
                // so the loop can proceed to the next one.
                _ = try? arr.decode(AnyCodableSkip.self)
            }
            // If the failed decode DID advance the index (implementation-defined), the loop
            // naturally continues at the next element.
        }
        blocks = out
        layoutDirection = try c.decodeIfPresent(DocumentLayoutDirection.self, forKey: .layoutDirection) ?? .auto
    }
}

public typealias RichTextEditorCoreDocument = Document
