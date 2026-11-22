import Foundation

// Run-list primitives for `ChatInputContent.replacingFlatRange`. Pure functions over `[ChatInputRun]`
// with no knowledge of blocks: the flat axis measures in UTF-16 units, so these do too.

/// Total UTF-16 length of a run list — the unit the flat axis (`plainText`) is measured in.
func chatInputRunsUTF16Length(_ runs: [ChatInputRun]) -> Int {
    return runs.reduce(0) { $0 + ($1.text as NSString).length }
}

/// The sub-list covering `[lo, hi)` UTF-16 units, splitting runs at the boundaries and carrying each
/// piece's attributes. An empty or inverted range yields nothing.
func chatInputRunsSlice(_ runs: [ChatInputRun], fromUTF16 lo: Int, toUTF16 hi: Int) -> [ChatInputRun] {
    guard hi > lo else {
        return []
    }
    var result: [ChatInputRun] = []
    var cursor = 0
    for run in runs {
        let text = run.text as NSString
        let length = text.length
        let a = max(lo, cursor)
        let b = min(hi, cursor + length)
        if a < b {
            result.append(ChatInputRun(text: text.substring(with: NSRange(location: a - cursor, length: b - a)),
                                       attributes: run.attributes))
        }
        cursor += length
        if cursor >= hi {
            break
        }
    }
    return result
}

/// Splits a run list at every `"\n"` into one group per line, carrying attributes across the split.
/// Always returns at least one group, and an empty line yields an EMPTY group (which becomes an empty
/// paragraph) rather than being dropped.
func chatInputRunsSplitOnNewlines(_ runs: [ChatInputRun]) -> [[ChatInputRun]] {
    var groups: [[ChatInputRun]] = []
    var current: [ChatInputRun] = []
    for run in runs {
        let pieces = run.text.components(separatedBy: "\n")
        for (index, piece) in pieces.enumerated() {
            if index > 0 {
                groups.append(current)
                current = []
            }
            if !piece.isEmpty {
                current.append(ChatInputRun(text: piece, attributes: run.attributes))
            }
        }
    }
    groups.append(current)
    return groups
}
