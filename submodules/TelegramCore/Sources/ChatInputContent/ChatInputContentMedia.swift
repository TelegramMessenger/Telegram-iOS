import Foundation
import Postbox

public extension ChatInputContent {
    /// Every medium this content references, anywhere — including inside blockquotes and details.
    /// Order is document order; duplicates are NOT removed (callers that need a set deduplicate by
    /// `EngineMedia.Id`).
    var allMedia: [EngineMedia] {
        var result: [EngineMedia] = []
        ChatInputContent.collectMedia(in: self.blocks, into: &result)
        return result
    }

    private static func collectMedia(in blocks: [ChatInputBlock], into result: inout [EngineMedia]) {
        for block in blocks {
            switch block {
            case let .media(media):
                for item in media.items {
                    result.append(EngineMedia(item.media))
                }
            case let .blockQuote(quote):
                collectMedia(in: quote.content.blocks, into: &result)
            case let .details(details):
                collectMedia(in: details.content.blocks, into: &result)
            case .table:
                // A ChatInputTableCell holds `runs: [ChatInputRun]`, not nested blocks, so a table
                // cannot contain media on this side. (The EDITOR's TableBlock.Cell does have
                // `blocks` — hence the different walk in RichTextAttachmentScreen. Do not copy one
                // into the other.)
                break
            case .paragraph, .code, .pullQuote, .buttonRow:
                break
            }
        }
    }
}
