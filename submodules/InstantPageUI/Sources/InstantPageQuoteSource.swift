import Foundation
import TelegramCore

/// Carries, on every run of laid-out rich text, which quotable node it shows and which flat range of
/// that node (UTF-16 offsets into `RichText.plainText`) the run stands for. This is what maps a text
/// selection to a rich reply quote, and a quote back to the text it highlights.
let InstantPageQuoteLeafAttribute = NSAttributedString.Key("InstantPageQuoteLeafAttribute")

final class InstantPageQuoteLeaf: NSObject {
    let node: InstantPageTextNodeId
    let flatStart: Int
    let flatLength: Int
    /// The run is drawn as something other than its flat text (an emoji, a formula, a pill, a
    /// formatted date, an inline image): any of its characters stands for the whole flat range.
    let isAtomic: Bool

    init(node: InstantPageTextNodeId, flatStart: Int, flatLength: Int, isAtomic: Bool) {
        self.node = node
        self.flatStart = flatStart
        self.flatLength = flatLength
        self.isAtomic = isAtomic
    }

    // Value equality: two layouts of the same text must compare equal, and runs that stand for
    // different flat text never do (their starts differ), so NSAttributedString keeps them apart.
    // Adjacent atoms of no text at one offset (an inline image, an empty anchor) may merge, which
    // changes nothing: together they still stand for no text there.
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? InstantPageQuoteLeaf else {
            return false
        }
        return self.node == other.node && self.flatStart == other.flatStart && self.flatLength == other.flatLength && self.isAtomic == other.isAtomic
    }

    override var hash: Int {
        return self.flatStart &* 31 &+ self.flatLength
    }
}

/// The running flat offset of one node's `attributedStringForRichText` recursion.
final class InstantPageQuoteSourceCursor {
    let node: InstantPageTextNodeId
    var flatOffset: Int = 0

    init(node: InstantPageTextNodeId) {
        self.node = node
    }
}

extension RichText {
    /// For a run `attributedStringForRichText` draws as something other than its text, the flat
    /// length it stands for; nil for text drawn as itself.
    var instantPageQuoteAtomFlatLength: Int? {
        switch self {
        case .image:
            return 0
        case let .anchor(text, _):
            if case .empty = text {
                return 0
            }
            return nil
        case .formula, .textCustomEmoji, .textDate, .textButton:
            return (self.plainText as NSString).length
        default:
            return nil
        }
    }
}
