#if canImport(UIKit)
import UIKit
import RichTextEditorDifferentialHarness
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// Task 9b — **the Telegram half of the differential host.**
///
/// The Objective-C `IDTextInputTestHost` cannot construct the editor: `RichTextEditorView` is a
/// plain Swift class with no `@objc`, its `UITextInput` witness (`DocumentCanvasView`) is
/// `internal`, and SwiftPM gives an Objective-C target no Swift interop header for a Swift target in
/// the same package. Adding `@objc` to production code to make an Objective-C test constructible was
/// rejected outright. So the construction happens HERE, in Swift with `@testable` access, and the
/// host calls in through the provider seam declared in `IDTelegramHostProvider.h` (ours; every
/// vendored file stays byte-identical).
///
/// **What the host still owns**, deliberately unchanged from the vendored original: the window and
/// root view controller, the key/hidden decision (the inline-formatting family runs on a hidden
/// window), the trait application, the initial selection, and teardown. This factory owns only what
/// is genuinely Telegram-specific — building the editor, seeding the document, and handing over the
/// attributed projection.
///
/// ## `IDTextInputHostKindMinimal` — say what it is, because the enum cannot
///
/// `IDTextInputHostKind` is vendored and has exactly three cases (`Stock`, `Reference`, `Minimal`),
/// and the vendored runner executes **all three** for every scenario. InputDec had two of its own
/// implementations to put in the two non-stock slots; Telegram has one. This factory therefore
/// builds a **fresh, independently constructed editor** for both non-stock kinds, and the
/// reference-vs-minimal pair the runner reports is a **determinism / execution-order check**, not a
/// third implementation: the runner drives the two at different points of its order (one order runs
/// `Stock, Reference, Minimal`, the other `Minimal, Reference, Stock`), so a difference between them
/// means state leaked across instances or the result depended on when it ran. That is a real
/// property worth asserting — but calling it a third implementation would be a lie, and reading a
/// reference-vs-minimal agreement as "two backends agree" would be the exact false comfort this
/// phase exists to prevent. Task 9d names it in its expectations; when a second Telegram input
/// backend exists, it takes the `Minimal` slot and the check becomes a genuine one.
enum TelegramDifferentialInputFactory {

    /// The vendored host's own geometry. Reproduced rather than re-chosen: the corpus re-derives
    /// stock behaviour live, so both arms have to be laid out the same way for the comparison to
    /// mean anything.
    static let editorFrame = CGRect(x: 35, y: 120, width: 320, height: 480)
    static let textInsets = UIEdgeInsets(top: 11, left: 9, bottom: 13, right: 9)

    static func install() {
        IDTextInputTestHost.id_setTelegramInputFactory { kind, scenario, errorOut in
            build(kind: kind, scenario: scenario, errorOut: errorOut)
        }
    }

    static func uninstall() {
        IDTextInputTestHost.id_setTelegramInputFactory(nil)
    }

    // MARK: - Construction

    private static func build(kind: IDTextInputHostKind,
                              scenario: IDTextInputScenario,
                              errorOut: NSErrorPointer) -> IDTelegramInputHandle? {
        guard kind != .stock else {
            errorOut?.pointee = error("the Telegram factory was asked for the stock host kind; "
                                      + "the host builds stock itself, verbatim from the original")
            return nil
        }

        let editor = RichTextEditorView(frame: editorFrame)

        // `spellCheckingType` reaches the editor through its OWN façade knob, not through the
        // `UITextInputTraits` setter the host will send afterwards. The canvas's six implemented
        // trait setters are no-ops by design (the editor's deviation D4) and its `spellCheckingType`
        // getter reads `isSpellCheckingEnabled`, so this is the only spelling that actually applies
        // the scenario's request. `UITextSpellCheckingTypeYes == 2`, `No == 1`, `Default == 0`;
        // default is treated as ON, matching `UITextView`.
        let spellChecking = (scenario.initialTraits["spellCheckingType"] as? NSNumber)?.intValue ?? 0
        editor.isSpellCheckingEnabled = (spellChecking != 1)

        // Suppress the software keyboard exactly as the vendored host does for its own inputs — it
        // subclasses to override `inputView`; the editor already vends `customInputView` from its
        // `inputView` override, so the same 1x0 view goes in through the public knob.
        editor.customInputView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0))

        // One top-level paragraph per line of `initialText`, matching the vendored host's
        // `attributedBlocksFromCanonical:`, which splits on "\n" for its own block editor.
        let lines = scenario.initialText.components(separatedBy: "\n")
        editor.document = Document(blocks: lines.map {
            .paragraph(ParagraphBlock(id: BlockID.generate(), runs: [TextRun(text: $0)]))
        })
        editor.update(size: editorFrame.size, insets: .zero, contentMargins: textInsets)

        let canvas = editor.canvas
        guard let range = canvas.textRange(from: canvas.beginningOfDocument,
                                           to: canvas.endOfDocument),
              let projected = canvas.legacyAttributedText(in: range),
              projected.string == (canvas.text(in: range) ?? "") else {
            errorOut?.pointee = error(
                "the editor's attributed projection does not reproduce its own canonical text for "
                + "scenario \(scenario.identifier); a storage-derived comparison built on it would "
                + "be reading the wrong characters")
            return nil
        }

        return IDTelegramInputHandle(
            input: canvas,
            ownerView: editor,
            attributedTextProjection: { [weak canvas] range in canvas?.legacyAttributedText(in: range) },
            // TASK 9c. `blocks` is a comparison field of all 68 scenarios, and the vendored recorder
            // answered it from the custom view's REAL block list (splitting the canonical text is
            // what it did for STOCK). Splitting on both sides would make `blocks` a restatement of
            // `canonical`; the editor's own list can disagree with its own text projection, which is
            // the one thing this field can catch that `canonical` cannot.
            blockTexts: { [weak canvas] in canvas?.differentialTopLevelBlockTexts() },
            // TASK 9c. The caret's typing attributes — the editor's answer to "what would the next
            // character carry", i.e. the semantic of `UITextView.typingAttributes` that the vendored
            // recorder reads for the stock arm. Sourced here because `textStylingAtPosition:` (the
            // original's neutral fallback) is an `@optional` member the canvas does not implement.
            typingAttributes: { [weak canvas] range in canvas?.differentialTypingAttributes(at: range) },
            // TASK 9d. The `toggleInlineTrait` transaction kind. The vendored driver downcast its
            // input to `IDBlockTextView` here; there is no neutral `UITextInput` spelling of
            // "toggle bold over the selection", so the editor answers through its OWN public
            // command — the same entry point the formatting menu uses.
            //
            // **Deliberately not compensated for a caret.** `characterFormatTargets()` returns `[]`
            // for a collapsed selection, so `toggleBold()` at a caret is inert while a `UITextView`
            // carries the toggle in `typingAttributes`. Synthesising a pending format here would
            // hide the divergence the inline-formatting family exists to find. The toggle reports
            // that it RAN; whether it changed anything is what the snapshot measures.
            inlineTraitToggle: { [weak editor] name in
                guard let editor else { return false }
                switch name {
                case "bold": editor.toggleBold()
                case "italic": editor.toggleItalic()
                case "underline": editor.toggleUnderline()
                case "strikethrough": editor.toggleStrikethrough()
                default: return false
                }
                return true
            })
    }

    private static func error(_ description: String) -> NSError {
        NSError(domain: IDTextInputTestHostErrorDomain, code: 1,
                userInfo: [NSLocalizedDescriptionKey: description])
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The attributed twin of `text(in:)`: same leaf-region walk, same
    /// "\n"-at-a-crossed-top-level-paragraph-boundary rule, attributes carried.
    ///
    /// It takes the `UITextRange` rather than a pair of offsets on purpose. The `UITextInput`
    /// position axis is SPARSE — a top-level paragraph boundary occupies two position slots while
    /// the text projection emits one "\n" — so an index computed from
    /// `offsetFromPosition:toPosition:` and an index into the projected string are the same number
    /// only before the first boundary. Handing the range straight through keeps the conversion
    /// inside the editor, which is the only party that can do it.
    ///
    /// The range is opened through `LegacyTextIdentity.globalRange(of:)` rather than by downcasting
    /// to `LegacyTextRange`. R6 (`InputBackendSourceBoundaryTests`) scans only
    /// `Sources/RichTextEditorUIKit`, so a downcast here would have been green — and would still
    /// have been a second place that knows what the backend's UIKit identity objects are, in a file
    /// written specifically to characterise the seam.
    func legacyAttributedText(in range: UITextRange) -> NSAttributedString? {
        guard let global = LegacyTextIdentity.globalRange(of: range) else { return nil }
        return legacyAttributedText(globalFrom: global.from, globalTo: global.to)
    }

    /// TASK 9c — the `blocks` comparison field: the editor's TOP-LEVEL text blocks, in document
    /// order, each projected through the SAME `legacyPlainText` rule that produces the canonical
    /// text. Using that rule per block (rather than reading the region's raw string) is what keeps
    /// the two derivations comparable: an inline atom expands to its plain-text form in both, so a
    /// difference between `blocks` and `canonical` can only ever mean a real disagreement about
    /// where the block boundaries are.
    ///
    /// The filter matches `composerParagraphs()`'s: the top-level boxes that carry editable text.
    /// A document of only paragraphs — which is every scenario in the corpus — yields one entry per
    /// paragraph.
    func differentialTopLevelBlockTexts() -> [String] {
        boxes.compactMap { box -> String? in
            guard box is BlockBox || box is CodeBlockBox || box is PullQuoteBox,
                  let region = box.leafRegions().first else { return nil }
            return legacyPlainText(globalFrom: region.globalStart,
                                   globalTo: region.globalStart + region.length) ?? ""
        }
    }

    /// TASK 9c — the `typingInlineTraits` comparison field at a COLLAPSED selection: the attributes
    /// the caret would type with, which for this editor is `typingAttributesAtGlobal` (the leaf
    /// region's attributes at the caret, body defaults at a structural boundary).
    ///
    /// **This editor has no PENDING caret format**, and that is deliberately not papered over here:
    /// `characterFormatTargets()` is empty for a caret, so `toggleBold()` at a caret is inert and the
    /// next character is not bold, while a `UITextView` carries the toggle in `typingAttributes`.
    /// Reporting the editor's real answer makes that a difference the oracle SHOWS. Declining the
    /// field, or synthesising a pending format, would hide a genuine behavioural divergence — which
    /// is the opposite of what a differential corpus is for.
    func differentialTypingAttributes(at range: UITextRange) -> [NSAttributedString.Key: Any]? {
        guard let global = LegacyTextIdentity.globalRange(of: range) else { return nil }
        return typingAttributesAtGlobal(global.from)
    }
}
#endif
