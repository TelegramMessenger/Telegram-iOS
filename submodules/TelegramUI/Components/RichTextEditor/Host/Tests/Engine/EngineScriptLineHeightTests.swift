import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **A line's height must not depend on the script that is typed into it.**
///
/// `StyleSheet` pins every text line to a box (`minimumLineHeight == maximumLineHeight`), and the V2
/// renderer advances by a pitch derived from the PARAGRAPH's font alone —
/// `lineAscent = floor(A + D)` of that font, raised only by an inline attachment, never by a glyph
/// run's own metrics (`InstantPageV2Layout.swift:4280,4560`). So a bubble renders Arabic on exactly
/// the same grid as Latin.
///
/// A text system does not, and the reason is narrow: **`maximumLineHeight` clamps ascent + descent
/// but NOT the font's leading**, which is added on top of the clamped box. Latin has none
/// (`.SFUI-Regular` reports `leading == 0`), so the pin looked absolute until a run substituted a
/// face that does. Measured at 17pt body against a 21pt box, one line:
///
/// | script | substituted face | leading | line |
/// | --- | --- | --- | --- |
/// | Latin | `.SFUI-Regular` | 0 | 21.0 |
/// | Hebrew | `.SFHebrew-Regular` | 0 | 21.0 |
/// | Devanagari | `.SFDevanagari-Regular` | 0 | 21.0 — though its 26.08 font box is CLAMPED by 5pt |
/// | Korean | `.AppleSDGothicNeoI-Regular` | 0.51 | 21.51 |
/// | Thai | `.ThonburiUI-Regular` | 1.1355 | 22.1355 |
/// | Arabic | `.SFArabic-Regular` | 1.1621 | 22.1621 |
///
/// Devanagari is the control that names the mechanism: the tallest font box of the six inflates the
/// line by NOTHING, because the pin does clamp ascent and descent. Only leading escapes it.
///
/// **And it compounds per line in TextKit 2, which is the engine's system.** A two-line Arabic
/// paragraph measured 46.324 against the grid's 44.0 — one leading per line, where TextKit 1 added
/// one for the whole block. So the defect grows with the paragraph rather than being a fixed
/// once-per-block error.
///
/// Fixed by refusing font leading outright (`RichTextFontLeading`), which is V2's own rule rather
/// than a correction applied on top of it.
@available(iOS 18.4, *)
final class EngineScriptLineHeightTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    /// One word per script, each long enough to force the substitution and short enough to hold one
    /// line at 320pt.
    private static let scripts: [(name: String, text: String)] = [
        ("latin", "Handy"),
        ("arabic", "\u{645}\u{631}\u{62d}\u{628}\u{627}"),
        ("thai", "\u{e2a}\u{e27}\u{e31}\u{e2a}\u{e14}\u{e35}"),
        ("korean", "\u{c548}\u{b155}"),
        ("hebrew", "\u{5e9}\u{5dc}\u{5d5}\u{5dd}"),
        ("devanagari", "\u{928}\u{92e}\u{938}\u{94d}\u{924}\u{947}"),
        ("chinese", "\u{4f60}\u{597d}"),
        ("japanese", "\u{3053}\u{3093}\u{306b}\u{3061}\u{306f}"),
    ]

    override func setUp() {
        super.setUp()
        // Pinned rather than inherited: `EngineUsedHeightModelTests` leaves the placement on `.off`
        // in its own tearDown, and under `.off` the pin has no `lineSpacing` to absorb a leading
        // with — so an inherited arm would turn these into a measurement of a mode nothing ships.
        EngineDocumentBridge.v2BaselinePlacement = .safe
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() {
        EngineDocumentBridge.v2BaselinePlacement = .safe
        window.isHidden = true; window = nil; editor = nil
        super.tearDown()
    }

    @discardableResult
    private func show(_ text: String) -> CGFloat {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)]))
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        return editor.engine.id_usedSizeForBlock(at: 0).height
    }

    /// The pinned box and the baseline-to-baseline pitch the bridge actually rendered with, read off
    /// the block rather than re-derived — so these cases keep meaning what they say under any
    /// placement arm.
    private func grid() -> (box: CGFloat, pitch: CGFloat) {
        let block = editor.engine.attributedBlocks[0]
        guard let style = block.attribute(.paragraphStyle, at: 0,
                                          effectiveRange: nil) as? NSParagraphStyle else {
            XCTFail("the rendered block carries no paragraph style"); return (0, 0)
        }
        return (style.maximumLineHeight, style.maximumLineHeight + style.lineSpacing)
    }

    /// One line is the box, whatever is on it.
    func test_aLineDoesNotGrowWhenItsScriptSubstitutesATallerFont() {
        for (name, text) in Self.scripts {
            let used = show(text)
            let (box, _) = grid()
            XCTAssertEqual(used, box, accuracy: 0.001,
                           "\(name): one line measured \(used) against a \(box)pt pinned box — the "
                           + "substituted face inflated it")
        }
    }

    /// **The user-visible symptom**: the composer's field must not grow the moment Arabic is typed
    /// into a line that already holds Latin. One line, two faces, one box.
    func test_typingArabicIntoALatinLineDoesNotChangeTheFieldsHeight() {
        let latin = editor.height(forWidth: 320)
        _ = show("Handy")
        let justLatin = editor.height(forWidth: 320)
        _ = show("Handy \u{645}\u{631}\u{62d}\u{628}\u{627}")
        let mixed = editor.height(forWidth: 320)
        XCTAssertEqual(mixed, justLatin, accuracy: 0.001,
                       "the field grew \(mixed - justLatin)pt when Arabic was typed into the line")
        XCTAssertGreaterThan(justLatin, latin - 1, "fixture sanity: \(latin)")
    }

    /// **Every paragraph lands on the line grid**, which is the claim that survives wrapping: N lines
    /// measure `box + (N-1) * pitch`, so `(used - box)` is an exact multiple of the pitch. Written
    /// this way rather than as a line count because it catches the per-line compounding without
    /// needing to know N — under the defect a two-line Arabic block sat 2.32 off the grid, a
    /// three-line one 3.49.
    func test_aWrappedParagraphStaysOnTheLineGridInEveryScript() {
        for (name, text) in Self.scripts {
            let long = String(repeating: text + " ", count: 30)
            let used = show(long)
            let (box, pitch) = grid()
            XCTAssertGreaterThan(used, box + pitch * 0.5, "\(name): the fixture did not wrap")
            let lines = (used - box) / pitch
            XCTAssertEqual(lines, (lines).rounded(), accuracy: 0.001,
                           "\(name): \(used) is \((used - box).truncatingRemainder(dividingBy: pitch))"
                           + " off a \(box) + k×\(pitch) grid")
        }
    }

    // MARK: - The lift must not follow the substituted face

    /// **The line must not JUMP as you type** — reported from K3 as "when typing Arabic, the line
    /// moves up and down (likely depending on the symbols typed)".
    ///
    /// It does, and the cause is that **the engine rewrites `.font` in its own storage to the face
    /// CoreText substituted**, while the mapper and the bridge both wrote the style's font. Measured:
    /// a body paragraph's stored run comes back `.SFArabic-Regular` for Arabic, `.ThonburiUI-Regular`
    /// for Thai, `.SFUI-Regular` for Latin — and `EngineBlockSpacing.v2BaselineDrop` reads that font
    /// to compute `pinned - (ascender - descender)`:
    ///
    /// | face | font box | drop against a 21pt pin |
    /// | --- | --- | --- |
    /// | `.SFUI-Regular` | 20.287 | **0.7129** |
    /// | `.SFArabic-Regular` | 21.117 | 0 (clamped, the box is TALLER than the pin) |
    ///
    /// The drop is a net-zero inset pair, so the block's top inset — and every glyph in it — moved by
    /// 0.7129pt. And `spacingLineAttributes` samples the **last character** of the block, so the
    /// answer flipped on the keystroke: `"Hi \u{645}"` read 0 and `"\u{645} Hi"` read 0.7129 for
    /// the same two runs in the other order. That is the jitter, once per typed character that
    /// changes script.
    ///
    /// **V2 never sees a substituted face** — it reads the paragraph's font once and advances on it
    /// — so the correction back to V2's baseline must be computed from the same font V2 uses, not
    /// from what the text system chose to draw a particular glyph with.
    func test_theLiftDoesNotFollowTheFaceCoreTextSubstituted() {
        var drops: [(String, CGFloat, CGFloat)] = []
        for (name, text) in Self.scripts {
            _ = show(text)
            drops.append((name, editor.v2BaselineDrop(atRole: 0),
                          editor.engine.id_frameForBlock(at: UInt(0)).minY))
        }
        guard let reference = drops.first else { return XCTFail("no fixtures") }
        for (name, drop, top) in drops {
            XCTAssertEqual(drop, reference.1, accuracy: 0.001,
                           "\(name): drop \(drop) against \(reference.0)'s \(reference.1) — the "
                           + "lift followed the substituted face")
            XCTAssertEqual(top, reference.2, accuracy: 0.001,
                           "\(name): the block's glyphs sit at \(top), \(reference.0)'s at "
                           + "\(reference.2)")
        }
    }

    /// The same defect at the granularity it was seen: the block must not move when one more
    /// character is typed onto the end of the line.
    ///
    /// Both orders are driven, because the sampler reads the LAST character — a fixture that only
    /// ever appended Arabic would move once and then sit still, and would pass a one-sided check.
    func test_theBlockDoesNotMoveAsCharactersOfEitherScriptAreTyped() {
        let arabic = "\u{645}\u{631}\u{62d}\u{628}\u{627}"
        var tops: [(String, CGFloat)] = []
        for text in ["H", "Hi", "Hi ", "Hi \u{645}", "Hi \u{645}\u{631}", "Hi \u{645}\u{631} ",
                     "Hi \u{645}\u{631} o", arabic, arabic + " ", arabic + " Hi"] {
            _ = show(text)
            tops.append((text, editor.engine.id_frameForBlock(at: UInt(0)).minY))
        }
        guard let first = tops.first else { return XCTFail("no fixtures") }
        for (text, top) in tops {
            XCTAssertEqual(top, first.1, accuracy: 0.001,
                           "the line jumped to \(top) (from \(first.1)) at \"\(text)\"")
        }
    }

    /// **The same claim on the path the user is actually on.** The cases above set a document, which
    /// goes through the bridge's render; typing goes straight into the engine, which is where the
    /// `.font` substitution happens and where the base-font marker has to be maintained rather than
    /// stamped. UIKit calls `insertText:` directly on the engine for a keyboard edit, so that is what
    /// this drives.
    func test_theBlockDoesNotMoveWhileArabicIsTypedCharacterByCharacter() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hi")]))
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        _ = editor.becomeFirstResponder()
        let settled = editor.engine.id_frameForBlock(at: UInt(0)).minY

        var typed = ""
        for character in " \u{645}\u{631}\u{62d}\u{628}\u{627} ok \u{645}" {
            editor.engine.insertText(String(character))
            editor.setNeedsLayout(); editor.layoutIfNeeded()
            typed.append(character)
            XCTAssertEqual(editor.engine.id_frameForBlock(at: UInt(0)).minY, settled, accuracy: 0.001,
                           "the line jumped after typing \"\(typed)\"")
        }
    }
}
