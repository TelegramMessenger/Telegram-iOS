import Foundation

public enum ListNumbering {
    private static let bulletGlyphs = ["•", "◦", "▪"]

    /// Computes the marker label for each list paragraph in `blocks`, keyed by block id.
    /// Non-list paragraphs are absent from the result and reset all counters.
    public static func labels(for blocks: [ParagraphBlock]) -> [BlockID: String] {
        var result: [BlockID: String] = [:]
        var counters: [Int] = []   // counters[level] = current ordinal at that level

        func resetDeeper(than level: Int) {
            if counters.count > level + 1 { counters.removeSubrange((level + 1)...) }
        }

        for block in blocks {
            guard let list = block.list else {
                counters.removeAll()       // non-list paragraph resets everything
                continue
            }
            let level = max(0, list.level)
            while counters.count <= level { counters.append(0) }

            switch list.marker {
            case .bullet:
                resetDeeper(than: level)
                counters[level] = 0        // bullets don't count
                result[block.id] = bulletGlyphs[level % bulletGlyphs.count]
            case .ordered:
                counters[level] += 1
                resetDeeper(than: level)
                result[block.id] = orderedLabel(value: counters[level], level: level)
            case .checklist:
                resetDeeper(than: level)
                counters[level] = 0        // checkboxes don't count
                result[block.id] = (list.checked == true) ? "☑" : "☐"
            }
        }
        return result
    }

    private static func orderedLabel(value: Int, level: Int) -> String {
        switch level % 3 {
        case 0: return "\(value)."
        case 1: return "\(lowerAlpha(value))."
        default: return "\(lowerRoman(value))."
        }
    }

    private static func lowerAlpha(_ n: Int) -> String {
        // 1→a, 2→b, … 26→z, 27→aa
        var n = n, s = ""
        while n > 0 {
            let r = (n - 1) % 26
            s = String(UnicodeScalar(UInt8(97 + r))) + s
            n = (n - 1) / 26
        }
        return s
    }

    private static func lowerRoman(_ n: Int) -> String {
        let table: [(Int, String)] = [(1000,"m"),(900,"cm"),(500,"d"),(400,"cd"),(100,"c"),
            (90,"xc"),(50,"l"),(40,"xl"),(10,"x"),(9,"ix"),(5,"v"),(4,"iv"),(1,"i")]
        var n = n, s = ""
        for (v, sym) in table { while n >= v { s += sym; n -= v } }
        return s
    }
}
