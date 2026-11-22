#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecHost

/// What VoiceOver reads for the engine's text, and the axis its cursor moves on.
///
/// The engine draws every attachment atom as ONE `U+FFFC`, and its own `accessibilityValue` is that
/// raw text, so a custom emoji read as nothing (or as "object replacement character") where the model,
/// the chat's input state and the legacy composer all hold its alt text (composer harness p14,
/// `HarnessAccessibilityTests`). Each atom now reads as:
///
/// - **custom emoji**: its alt text (the emoji it stands for), as legacy's text view holds it;
/// - **inline formula**: its LaTeX source, which is also what the chat currency carries for it;
/// - **inline button**: its label, the text the pill shows;
/// - **button row**: its buttons' labels, joined by ", ";
/// - **media**: the host's localized name for each item's kind (`accessibilityMediaName`), joined by
///   ", " for an album; nothing when the host supplies no names (the package has no strings);
/// - **collapsed quote**: its preview text;
/// - anything else (an internal marker): nothing.
///
/// For the emoji and the formula this is exactly the composer's flat axis rule (p13,
/// `composerAxisAtomLength`): an atom counts by its model text. Unlike the composer axis, every block
/// is on it (details, tables and captions included), because VoiceOver reads everything on screen.
///
/// **The offsets have to follow.** UIKit's accessibility support for a `UITextInput` responder reads
/// the selection from `-selectedTextRange` (engine axis) and the characters from `accessibilityValue`;
/// with the value expanded and the range not, VoiceOver's cursor would sit one character early per
/// expanded atom before it. So the host maps both directions (`TGIDObservingBlockTextView`'s
/// `_accessibilitySelectedTextRange` / `_accessibilitySetSelectedTextRange:`), and an offset INSIDE an
/// atom's reading snaps to the nearer boundary, a range widens over every atom it touches: the
/// composer axis's rounding rule. The AX runtime's line / column queries still ask the engine through
/// `UITextInput` directly and stay on the engine axis.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// The accessibility reading of the whole text: the string, and every attachment atom in it on the
    /// engine's canonical axis with the length its reading takes.
    internal struct AccessibilityText {
        var string: String
        /// (engine offset of the atom's `U+FFFC`, length of its reading on the value's axis), in order.
        var atoms: [(engineOffset: Int, length: Int)]
    }

    internal func accessibilityReading(of attachment: Any) -> String {
        if let emoji = attachment as? EmojiTextAttachment {
            return emoji.ref.altText ?? ""
        }
        if let formula = attachment as? FormulaTextAttachment {
            return formula.latex
        }
        if let button = attachment as? ButtonTextAttachment {
            return button.button.labelText
        }
        if let row = attachment as? ButtonRowTextAttachment {
            return row.shape.buttons.map(\.labelText).filter { !$0.isEmpty }.joined(separator: ", ")
        }
        if let media = attachment as? MediaTextAttachment {
            guard let name = accessibilityMediaName else { return "" }
            return media.shape.items.compactMap { name($0.kind) }.filter { !$0.isEmpty }.joined(separator: ", ")
        }
        if let quote = attachment as? CollapsedQuoteTextAttachment {
            // The preview holds its own atoms as `U+FFFC` (a custom emoji inside the folded quote):
            // read those the same way, never the bare character (composer harness p19,
            // `HarnessCollapsedQuoteAccessibilityTests`).
            return accessibilityReading(ofAttributed: quote.previewText)
        }
        return ""
    }

    /// An attributed string's reading: its text with every attachment character replaced by the
    /// attachment's reading (`accessibilityReading(of:)`).
    internal func accessibilityReading(ofAttributed text: NSAttributedString) -> String {
        let string = text.string as NSString
        let result = NSMutableString()
        var cursor = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length), options: []) { value, range, _ in
            guard let value else { return }
            for offset in range.location ..< NSMaxRange(range) {
                guard string.character(at: offset) == 0xFFFC else { continue }
                result.append(string.substring(with: NSRange(location: cursor, length: offset - cursor)))
                result.append(self.accessibilityReading(of: value))
                cursor = offset + 1
            }
        }
        result.append(string.substring(from: cursor))
        // An attachment character without an attachment attribute reads as nothing, like an internal
        // marker does.
        return (result as String).replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    /// The engine's text, blocks joined by "\\n" as its canonical axis joins them, with each atom
    /// replaced by its reading.
    internal func accessibilityText() -> AccessibilityText {
        let result = NSMutableString()
        var atoms: [(engineOffset: Int, length: Int)] = []
        var engineStart = 0
        for (index, block) in engine.attributedBlocks.enumerated() {
            if index > 0 { result.append("\n") }
            let length = block.length
            var cursor = 0
            if length > 0 {
                block.enumerateAttribute(.attachment, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
                    guard let value else { return }
                    let string = block.string as NSString
                    for offset in range.location ..< NSMaxRange(range) {
                        // Only the attachment CHARACTER is an atom: an attribute that spills onto a
                        // neighbouring character is not.
                        guard string.character(at: offset) == 0xFFFC else { continue }
                        result.append(string.substring(with: NSRange(location: cursor, length: offset - cursor)))
                        let reading = self.accessibilityReading(of: value)
                        result.append(reading)
                        atoms.append((engineStart + offset, (reading as NSString).length))
                        cursor = offset + 1
                    }
                }
                result.append((block.string as NSString).substring(from: cursor))
            }
            engineStart += length + 1
        }
        return AccessibilityText(string: result as String, atoms: atoms)
    }

    internal func accessibilityOffset(fromEngineOffset offset: Int, in text: AccessibilityText) -> Int {
        var mapped = offset
        for atom in text.atoms where atom.engineOffset < offset {
            mapped += atom.length - 1
        }
        return mapped
    }

    internal func engineOffset(fromAccessibilityOffset offset: Int, in text: AccessibilityText, rounding: ComposerAxisRounding) -> Int {
        // Walk the atoms: the value's axis runs level with the engine's between atoms, shifted by the
        // atoms already passed.
        var shift = 0
        for atom in text.atoms {
            let atomStart = atom.engineOffset + shift
            if offset <= atomStart {
                break
            }
            let atomEnd = atomStart + atom.length
            if offset < atomEnd {
                let snapUp: Bool
                switch rounding {
                case .down: snapUp = false
                case .up: snapUp = true
                case .nearest: snapUp = (offset - atomStart) * 2 >= atom.length
                }
                return atom.engineOffset + (snapUp ? 1 : 0)
            }
            shift += atom.length - 1
        }
        return max(0, offset - shift)
    }

    internal func accessibilityRange(fromEngineRange range: NSRange) -> NSRange {
        let text = accessibilityText()
        let start = accessibilityOffset(fromEngineOffset: range.location, in: text)
        let end = accessibilityOffset(fromEngineOffset: NSMaxRange(range), in: text)
        return NSRange(location: start, length: max(0, end - start))
    }

    internal func engineRange(fromAccessibilityRange range: NSRange) -> NSRange {
        let text = accessibilityText()
        guard range.length > 0 else {
            return NSRange(location: engineOffset(fromAccessibilityOffset: range.location, in: text, rounding: .nearest), length: 0)
        }
        let start = engineOffset(fromAccessibilityOffset: range.location, in: text, rounding: .down)
        let end = engineOffset(fromAccessibilityOffset: NSMaxRange(range), in: text, rounding: .up)
        return NSRange(location: start, length: max(0, end - start))
    }

    internal func installAccessibilityReading() {
        engine.tgid_accessibilityValueProvider = { [weak self] in
            self?.accessibilityText().string
        }
        engine.tgid_accessibilityRangeFromCanonicalRange = { [weak self] range in
            self?.accessibilityRange(fromEngineRange: range) ?? range
        }
        engine.tgid_canonicalRangeFromAccessibilityRange = { [weak self] range in
            self?.engineRange(fromAccessibilityRange: range) ?? range
        }
    }
}
#endif
