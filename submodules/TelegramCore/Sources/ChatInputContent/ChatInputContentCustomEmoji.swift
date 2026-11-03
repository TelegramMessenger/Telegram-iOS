import Foundation
import Postbox

// Resolving custom-emoji FILES on the composer's structural content.
//
// A `ChatInputContent` arriving from anywhere but the sticker keyboard — a pasted rich message, a
// restored draft, an edit-load — carries `.customEmoji(fileId:file:enableAnimation:)` runs with
// `file == nil`; the id is on the wire, the `TelegramMediaFile` is not. The chat layer resolves those
// asynchronously and writes the files back into the composer state.
//
// **That write-back must happen on the MODEL, never on the derived `inputText`.** Rebuilding the state
// via `ChatTextInputState(inputText:selectionRange:)` runs `chatInputContent(from:)` over a flattened
// `NSAttributedString`, which knows nothing about headings, lists, quotes, tables or media — so the
// resolution silently retyped every structural block as a body paragraph. Visible as: paste a rich
// message with custom emoji, watch the headings render, then vanish a moment later when the sticker
// resolution lands. Hence these two helpers, which walk the block tree instead.

private func chatInputRunsResolvingCustomEmoji(_ runs: [ChatInputRun], files: [Int64: TelegramMediaFile]) -> [ChatInputRun] {
    return runs.map { run in
        var run = run
        switch run.attributes.entity {
        case let .customEmoji(fileId, file, enableAnimation):
            // Only fill a MISSING file. An already-resolved run is left alone so a stale entry in
            // `files` can never downgrade it.
            if file == nil, let resolved = files[fileId] {
                run.attributes.entity = .customEmoji(fileId: fileId, file: resolved, enableAnimation: enableAnimation)
            }
        case let .button(button):
            // An inline button nests its own label runs, which may hold emoji of their own.
            var button = button
            button.label = chatInputRunsResolvingCustomEmoji(button.label, files: files)
            run.attributes.entity = .button(button)
        case .mention, .url, .date, .none:
            break
        }
        return run
    }
}

private func chatInputRunsCollectingUnresolvedCustomEmoji(_ runs: [ChatInputRun], into result: inout Set<Int64>) {
    for run in runs {
        switch run.attributes.entity {
        case let .customEmoji(fileId, file, _):
            if file == nil {
                result.insert(fileId)
            }
        case let .button(button):
            chatInputRunsCollectingUnresolvedCustomEmoji(button.label, into: &result)
        case .mention, .url, .date, .none:
            break
        }
    }
}

extension ChatInputContent {
    /// Rebuilds every block with its runs transformed. The `switch` is EXHAUSTIVE (no `default`) on
    /// purpose: a new `ChatInputBlock` case must state where its runs live, rather than silently
    /// carrying emoji that never resolve.
    private func mappingRuns(_ transform: ([ChatInputRun]) -> [ChatInputRun]) -> ChatInputContent {
        var result = self
        result.blocks = self.blocks.map { block in
            switch block {
            case var .paragraph(paragraph):
                paragraph.runs = transform(paragraph.runs)
                return .paragraph(paragraph)
            case var .code(code):
                code.runs = transform(code.runs)
                return .code(code)
            case var .media(media):
                media.caption = transform(media.caption)
                return .media(media)
            case var .table(table):
                table.rows = table.rows.map { row in
                    var row = row
                    row.cells = row.cells.map { cell in
                        var cell = cell
                        cell.runs = transform(cell.runs)
                        return cell
                    }
                    return row
                }
                return .table(table)
            case var .pullQuote(pullQuote):
                pullQuote.runs = transform(pullQuote.runs)
                pullQuote.author = transform(pullQuote.author)
                return .pullQuote(pullQuote)
            case var .blockQuote(blockQuote):
                blockQuote.content = blockQuote.content.mappingRuns(transform)
                blockQuote.author = transform(blockQuote.author)
                return .blockQuote(blockQuote)
            case var .details(details):
                details.content = details.content.mappingRuns(transform)
                details.title = transform(details.title)
                return .details(details)
            case var .buttonRow(buttonRow):
                buttonRow.buttons = buttonRow.buttons.map { button in
                    var button = button
                    button.label = transform(button.label)
                    return button
                }
                return .buttonRow(buttonRow)
            }
        }
        return result
    }

    /// Walks every block for `.customEmoji` runs still missing their `TelegramMediaFile`.
    ///
    /// Reads the MODEL, so it also sees emoji the flat `inputText` projection drops entirely — inside a
    /// table cell, a collapsed quote, a media caption — which the previous flat scan never resolved.
    public func unresolvedCustomEmojiFileIds() -> Set<Int64> {
        var result = Set<Int64>()
        _ = self.mappingRuns { runs in
            chatInputRunsCollectingUnresolvedCustomEmoji(runs, into: &result)
            return runs
        }
        return result
    }

    /// A copy with each `.customEmoji` run whose `fileId` appears in `files` given its resolved file.
    ///
    /// **Attribute-only: no text and no block structure changes**, so a `ChatInputSelection` taken
    /// against the receiver stays valid against the result. Callers rely on that to keep the caret
    /// across an async resolution.
    public func resolvingCustomEmojiFiles(_ files: [Int64: TelegramMediaFile]) -> ChatInputContent {
        guard !files.isEmpty else {
            return self
        }
        return self.mappingRuns { chatInputRunsResolvingCustomEmoji($0, files: files) }
    }
}
