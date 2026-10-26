import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** Two things VoiceOver reads from the engine composer differ from the legacy composer's:
///
/// 1. **The "Message" hint is on the wrong element.** The panel sets the placeholder as the input's
///    accessibility hint (`inputAccessibilityHint`). The legacy backend puts it on its `UITextView`, the
///    element the AX runtime exposes as the text area. The engine backend puts it on
///    `RichTextEngineEditorView`, a plain container; the text area is the `TGIDObservingBlockTextView`
///    inside it, and that has no hint. On K1 (`axe describe-ui`, iOS 27.0):
///
///        legacy   TextArea  value "First paragraph.\nSecond paragraph."  help "Message"
///        engine   Group     id composer.editor.RichTextEngineEditorView  help "Message"
///                   TextArea value "First paragraph.\nSecond paragraph."  help None
///
///    So when VoiceOver focuses the engine's text area it does not say "Message".
///
/// 2. **A custom emoji reads as U+FFFC.** `IDBlockTextView.accessibilityValue` returns the engine's raw
///    text, in which a custom emoji (and an inline formula, a media atom, an inline button) is one
///    attachment character. The model, the chat's input state and the legacy composer all carry the
///    emoji's own text:
///
///        "Sum ", formula, " is ", custom emoji 😀, " fine"
///        engine accessibilityValue  "Sum \u{FFFC} is \u{FFFC} fine"
///        model / chat plainText     "Sum a^2+b^2 is 😀 fine"
///        legacy text view text      "… 😀 …" (the emoji's alt text, with a custom-emoji attribute)
///
///    VoiceOver reads U+FFFC as nothing (or as "object replacement character"), so the emoji is skipped.
///    The formula is recorded here but not asserted: what a formula should read as is a product choice.
///
/// **How it was seen.** p14 roam, 2026-09-24 (accessibility editing): a hosted probe compared the
/// engine's `UIAccessibility` answers with the legacy composer's and a stock `UITextView`'s, and
/// `axe describe-ui` on K1 dumped the real AX tree for both backends.
///
/// **Suspected cause.** (1) `RichTextEditorChatInputNode.inputAccessibilityHint` forwards to
/// `editorView.accessibilityHint` (`ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift`)
/// instead of to the engine's text view. (2) `-[IDBlockTextView accessibilityValue]` is `self.text`
/// (`RichTextInputDecUpstream/TextView/IDBlockTextView.m`), with no substitution for attachment atoms.
///
/// **Fixed (p14, 2026-09-24):** (1) `RichTextEngineEditorView` forwards `accessibilityHint` / `Label` to the
/// engine view. (2) The host answers `accessibilityValue` with each atom's reading and maps the AX selection
/// onto that value's axis (`RichTextEngineEditorView+Accessibility.swift`).
///
/// **Not a harness artifact**: the hint comes from the panel's own `updateLayout`, and the value from
/// the engine view's own override; the harness supplies neither. In the hosted process the AX bundle is
/// not active, so traits and `isAccessibilityElement` are 0 / false for every text view including a
/// stock one, and are not compared here; K1's AX tree is the evidence that the engine view IS the
/// exposed text area.
///
/// **Tier 1**: both answers are plain properties of the views the AX runtime exposes.
@available(iOS 18.4, *)
final class HarnessAccessibilityTests: XCTestCase {
    private static func legacyTextView(_ root: HarnessRootViewController) throws -> UITextView {
        func find(_ view: UIView) -> UITextView? {
            if let textView = view as? UITextView {
                return textView
            }
            for subview in view.subviews {
                if let found = find(subview) {
                    return found
                }
            }
            return nil
        }
        let host = try XCTUnwrap(root.panelHost)
        return try XCTUnwrap(find(host.panel.view), "precondition: no legacy text view")
    }

    func testTheEngineTextAreaCarriesTheMessageHint() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText("First paragraph."))
        XCTAssertEqual(driver.editor.accessibilityHint, "Message", "precondition: the panel did not set its hint on the engine editor")
        XCTAssertEqual(driver.view.accessibilityHint, "Message", "the engine's text area (the element VoiceOver focuses) has no \"Message\" hint")
    }

    /// Control: the legacy composer's text view carries it.
    func testTheLegacyTextViewCarriesTheMessageHint() throws {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        HarnessEngine.settle(root)
        XCTAssertEqual(try Self.legacyTextView(root).accessibilityHint, "Message")
    }

    private static func emojiContent() -> ChatInputContent {
        return ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run("Nice "), HarnessEdited.emoji(), HarnessEdited.run(" day")])])
    }

    func testACustomEmojiReadsAsItsTextNotAnAttachmentCharacter() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(Self.emojiContent())
        XCTAssertEqual(fuzzEscaped(driver.model().plainText), fuzzEscaped("Nice 😀 day"), "precondition: the model does not carry the emoji's text")
        let value = driver.view.accessibilityValue ?? ""
        XCTAssertEqual(fuzzEscaped(value), fuzzEscaped("Nice 😀 day"), "VoiceOver reads the custom emoji as an attachment character")
    }

    /// The readings chosen for the other atoms (p14 fix): a formula reads as its LaTeX (the model's own
    /// text for it, and the composer axis's length), an inline button as its label.
    func testAFormulaReadsAsItsLatexAndAnInlineButtonAsItsLabel() throws {
        let driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: driver.host)
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run("Sum "), HarnessEdited.formula("a^2+b^2"), HarnessEdited.run(" is "), HarnessEdited.emoji(), HarnessEdited.run(" "), HarnessEdited.pill("Go")])]))
        XCTAssertEqual(fuzzEscaped(driver.viewText()), fuzzEscaped("Sum \u{FFFC} is \u{FFFC} \u{FFFC}"), "precondition: the formula, emoji and pill are not attachment atoms in the engine")
        XCTAssertEqual(fuzzEscaped(driver.view.accessibilityValue ?? ""), fuzzEscaped("Sum a^2+b^2 is 😀 Go"))
    }

    private static let selectedRangeKey = "_accessibilitySelectedTextRange"

    private static func accessibilitySelectedRange(_ view: UIView) -> NSRange? {
        return (view.value(forKey: Self.selectedRangeKey) as? NSValue)?.rangeValue
    }

    private static func setAccessibilitySelectedRange(_ view: UIView, _ range: NSRange) throws {
        let selector = NSSelectorFromString("_accessibilitySetSelectedTextRange:")
        XCTAssertTrue(view.responds(to: selector), "precondition: the engine view does not answer VoiceOver's selection setter")
        typealias Setter = @convention(c) (AnyObject, Selector, NSRange) -> Void
        unsafeBitCast(view.method(for: selector), to: Setter.self)(view, selector, range)
    }

    /// The AX runtime reads characters out of `accessibilityValue` at the offsets of
    /// `_accessibilitySelectedTextRange`, so once an atom's reading is longer than its one engine
    /// character the two must be on the SAME axis, or VoiceOver's cursor sits one character early per
    /// expanded atom.
    func testVoiceOversSelectionIsOnTheValuesAxis() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(Self.emojiContent())
        let value = (driver.view.accessibilityValue ?? "") as NSString
        XCTAssertEqual(value.length, 11, "precondition: \"Nice 😀 day\"")

        // Engine offset 7 is after "Nice ", the emoji and the space: " day" follows on BOTH axes.
        driver.setViewSelection(NSRange(location: 7, length: 0))
        driver.settle(0.1)
        let caret = try XCTUnwrap(Self.accessibilitySelectedRange(driver.view))
        XCTAssertEqual(caret, NSRange(location: 8, length: 0), "VoiceOver's caret is on the engine's axis")
        XCTAssertEqual(value.substring(from: caret.location), "day")

        // A selection over the emoji reads as the emoji.
        driver.setViewSelection(NSRange(location: 5, length: 1))
        driver.settle(0.1)
        let emoji = try XCTUnwrap(Self.accessibilitySelectedRange(driver.view))
        XCTAssertEqual(value.substring(with: emoji), "😀")

        // VoiceOver moving its cursor maps back: after "day"'s "d", and inside the emoji's surrogate
        // pair (snaps to the nearer boundary, never half an atom).
        try Self.setAccessibilitySelectedRange(driver.view, NSRange(location: 9, length: 0))
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 8, length: 0))
        try Self.setAccessibilitySelectedRange(driver.view, NSRange(location: 6, length: 0))
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 6, length: 0))
        try Self.setAccessibilitySelectedRange(driver.view, NSRange(location: 5, length: 2))
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 5, length: 1))
    }

    /// Control: the legacy composer's text holds the emoji's alt text, which is what its AX value reads.
    func testTheLegacyComposerHoldsACustomEmojisText() throws {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        let host = try XCTUnwrap(root.panelHost)
        host.setInputContent(Self.emojiContent())
        HarnessEngine.settle(root)
        XCTAssertEqual(fuzzEscaped(try Self.legacyTextView(root).text), fuzzEscaped("Nice 😀 day"))
    }
}
