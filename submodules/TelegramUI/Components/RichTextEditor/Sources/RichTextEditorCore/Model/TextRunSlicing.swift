import Foundation

/// Returns the runs covering the UTF-16 sub-range `[lo, hi)`, bisecting any run that straddles a
/// boundary and preserving each run's `CharacterAttributes`. Out-of-range endpoints are clamped.
public func sliceRuns(_ runs: [TextRun], fromUTF16 lo: Int, toUTF16 hi: Int) -> [TextRun] {
    let total = runs.reduce(0) { $0 + $1.utf16Count }
    let a = max(0, min(lo, total))
    let b = max(a, min(hi, total))
    guard a < b else { return [] }
    var out: [TextRun] = []
    var consumed = 0
    for run in runs {
        let len = run.utf16Count
        let runLo = consumed, runHi = consumed + len
        consumed = runHi
        let lo2 = max(a, runLo), hi2 = min(b, runHi)
        guard lo2 < hi2 else { continue }
        if lo2 == runLo && hi2 == runHi {
            out.append(run)
        } else {
            let ns = run.text as NSString
            let sub = ns.substring(with: NSRange(location: lo2 - runLo, length: hi2 - lo2))
            out.append(TextRun(text: sub, attributes: run.attributes))
        }
    }
    return out
}

/// Returns `runs` with `text` inserted (as a plain, attribute-less run) at UTF-16 `offset`.
public func insertingText(_ text: String, into runs: [TextRun], atUTF16 offset: Int) -> [TextRun] {
    let total = runs.reduce(0) { $0 + $1.utf16Count }
    let off = max(0, min(offset, total))
    return sliceRuns(runs, fromUTF16: 0, toUTF16: off)
        + [TextRun(text: text)]
        + sliceRuns(runs, fromUTF16: off, toUTF16: total)
}
