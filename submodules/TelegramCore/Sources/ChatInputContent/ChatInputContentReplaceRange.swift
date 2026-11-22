import Foundation

// The structural replace-range.
//
// `ChatTextInputState.inputText` is a DERIVED flat projection of `ChatInputContent`, and rebuilding
// the model from a mutated copy of it (`ChatTextInputState(inputText:selectionRange:)`) re-derives
// every block through `chatInputContent(from:)` — which has no vocabulary for headings, lists,
// quotes, tables or media and so retypes them all as body paragraphs. Ten composer sites used to
// change a few characters that way, destroying the whole composer's structure as a side effect.
//
// This is the replacement: resolve a flat range to structural positions through the mapping the model
// already exposes, and splice runs into the block(s) it lands in. Everything else is untouched by
// construction.

/// The runs of a block whose text lives directly on the flat axis, or nil for a block that has none
/// (a quote, whose text is nested, or an off-axis block).
private func chatInputFlatTextRuns(of block: ChatInputBlock) -> [ChatInputRun]? {
    switch block {
    case let .paragraph(paragraph):
        return paragraph.runs
    case let .code(code):
        return code.runs
    case let .pullQuote(pullQuote):
        return pullQuote.runs
    case .blockQuote, .media, .table, .details, .buttonRow:
        return nil
    }
}

/// Rebuilds `block` around `runs`.
///
/// A `"\n"` splits a PARAGRAPH into siblings, because on the flat axis `"\n"` is what separates two
/// paragraphs. It does NOT split a code block or a pull quote: those carry interior newlines as
/// ordinary characters (`plainText` appends their text verbatim), so splitting one would shatter it.
private func chatInputRebuilt(_ block: ChatInputBlock, withRuns runs: [ChatInputRun]) -> [ChatInputBlock] {
    switch block {
    case let .paragraph(paragraph):
        return chatInputRunsSplitOnNewlines(runs).map { line in
            .paragraph(ChatInputParagraph(style: paragraph.style, list: paragraph.list, runs: line))
        }
    case let .code(code):
        return [.code(ChatInputCode(language: code.language, runs: runs))]
    case let .pullQuote(pullQuote):
        return [.pullQuote(ChatInputPullQuote(runs: runs, author: pullQuote.author))]
    case .blockQuote, .media, .table, .details, .buttonRow:
        return [block]
    }
}

public extension ChatInputContent {
    /// The inline entity at a flat offset, or nil. The emoji-suggestion sweep uses it to stop before
    /// re-replacing an occurrence it has already turned into an emoji — it searches plain text, and a
    /// custom emoji's `displayText` can equal the shortcode it replaced.
    func entityAt(flatOffset: Int) -> ChatInputInlineEntity? {
        let position = self.position(forFlatOffset: flatOffset)
        guard let step = position.path.first, self.blocks.indices.contains(step.blockIndex),
              let runs = chatInputFlatTextRuns(of: self.blocks[step.blockIndex]) else {
            return nil
        }
        var cursor = 0
        for run in runs {
            let length = (run.text as NSString).length
            if position.offset < cursor + length {
                return run.attributes.entity
            }
            cursor += length
        }
        return runs.last?.attributes.entity
    }

    /// Replaces the flat (`plainText`) UTF-16 range with `runs`, preserving every block outside it.
    /// Returns the new content and the flat offset just past the inserted runs.
    ///
    /// Use this instead of mutating `ChatTextInputState.inputText` and reconstructing the state — that
    /// round-trip flattens the whole composer (see the file comment).
    ///
    /// Returns the receiver unchanged when the range addresses something with no editable flat text: a
    /// collapsed quote's `" "` placeholder, or a cross-block range with a quote at either end (merging
    /// a quote endpoint is a further increment — refusing is visible, corrupting is not).
    func replacingFlatRange(_ range: NSRange, with runs: [ChatInputRun]) -> (content: ChatInputContent, caret: Int) {
        let total = (self.plainText as NSString).length
        let lo = min(max(range.location, 0), total)
        let hi = min(max(range.location + max(range.length, 0), lo), total)
        // Uniform across every mutating branch: the flat axis counts a paragraph separator as the one
        // "\n" that was already in `runs`, so the inserted extent is exactly the runs' UTF-16 length.
        let caret = lo + chatInputRunsUTF16Length(runs)

        let startPosition = self.position(forFlatOffset: lo)
        let endPosition = self.position(forFlatOffset: hi)
        guard let startStep = startPosition.path.first, let endStep = endPosition.path.first,
              self.blocks.indices.contains(startStep.blockIndex),
              self.blocks.indices.contains(endStep.blockIndex) else {
            return (self, lo)
        }
        let startIndex = startStep.blockIndex
        let endIndex = endStep.blockIndex

        if startIndex != endIndex {
            let headBlock = self.blocks[startIndex]
            let tailBlock = self.blocks[endIndex]
            // A quote at either end is refused rather than corrupted: merging one means either
            // recursing the head quote's interior or migrating the tail quote's blocks out of it, which
            // is a further increment. See the accepted limitation in the design doc.
            guard let headRuns = chatInputFlatTextRuns(of: headBlock),
                  let tailRuns = chatInputFlatTextRuns(of: tailBlock) else {
                return (self, lo)
            }
            let merged = chatInputRunsSlice(headRuns, fromUTF16: 0, toUTF16: startPosition.offset)
                + runs
                + chatInputRunsSlice(tailRuns, fromUTF16: endPosition.offset,
                                     toUTF16: chatInputRunsUTF16Length(tailRuns))
            // Off-axis blocks contribute neither a character nor a separator, so the flat range never
            // addressed them; they keep their relative order and follow the merged block.
            let survivors = self.blocks[(startIndex + 1) ..< endIndex].filter { !self.blockIsFlatParticipating($0) }
            var newBlocks = self.blocks
            newBlocks.replaceSubrange(startIndex ... endIndex,
                                      with: chatInputRebuilt(headBlock, withRuns: merged) + survivors)
            return (ChatInputContent(schemaVersion: self.schemaVersion, blocks: newBlocks), caret)
        }

        let block = self.blocks[startIndex]
        if case let .blockQuote(quote) = block {
            // A collapsed quote's placeholder is not editable text.
            guard !quote.collapsed else {
                return (self, lo)
            }
            // An expanded quote's interior is its own flat axis.
            let inner = quote.content.replacingFlatRange(
                NSRange(location: startPosition.offset, length: endPosition.offset - startPosition.offset),
                with: runs
            )
            var newBlocks = self.blocks
            newBlocks[startIndex] = .blockQuote(ChatInputBlockQuote(content: inner.content, collapsed: false,
                                                                    author: quote.author))
            return (ChatInputContent(schemaVersion: self.schemaVersion, blocks: newBlocks), caret)
        }
        guard let blockRuns = chatInputFlatTextRuns(of: block) else {
            return (self, lo)
        }

        let merged = chatInputRunsSlice(blockRuns, fromUTF16: 0, toUTF16: startPosition.offset)
            + runs
            + chatInputRunsSlice(blockRuns, fromUTF16: endPosition.offset,
                                 toUTF16: chatInputRunsUTF16Length(blockRuns))
        var newBlocks = self.blocks
        newBlocks.replaceSubrange(startIndex ... startIndex, with: chatInputRebuilt(block, withRuns: merged))
        return (ChatInputContent(schemaVersion: self.schemaVersion, blocks: newBlocks), caret)
    }
}
