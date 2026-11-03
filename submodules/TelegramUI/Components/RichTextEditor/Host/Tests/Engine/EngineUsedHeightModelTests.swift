import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// What the ENGINE's used height is under each placement mode — measured through
/// `id_usedSizeForBlockAtIndex:`, which is TextKit 2's `usageBoundsForTextContainer`
/// (`IDBlockLayout.m:143,186`), NOT TextKit 1's `usedRect(for:)`.
///
/// **This is the measurement the arm choice depends on, and it exists because the first one was
/// taken in the wrong text system.** The fork in the spec was measured with `NSLayoutManager` — the
/// LEGACY canvas's engine — and the two need not agree about whether a trailing `lineSpacing` counts
/// toward the used height. If it does, `.exact` measures `n * pitch` and the existing
/// `EngineBlockSpacing.trailingLineBoxOverhang` keeps working unchanged; if it does not, `.exact`
/// measures `fontBox + (n-1) * pitch` and is `ceil(fontBox) - fontBox` short per block, which is what
/// `.safe` and `.exactWithTrailingSpacing` each answer differently.
///
/// See the RichTextEditor `CLAUDE.md`, "A block's FRAME is a line box; the rhythm below it is the renderer's".
@available(iOS 18.4, *)
final class EngineUsedHeightModelTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }

    override func tearDown() {
        // Restored here rather than in the loop: a failed assertion leaves the loop early, and a mode
        // left set would then leak into every later test in the bundle.
        EngineDocumentBridge.v2BaselinePlacement = .off
        window.isHidden = true; window = nil; editor = nil
        super.tearDown()
    }

    private func usedHeight(ofBlockWith text: String) -> CGFloat {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)]))
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        return editor.engine.id_usedSizeForBlock(at: 0).height
    }

    /// One line, and a string long enough to wrap at 320pt. The DIFFERENCE per line is the pitch and
    /// must be the same under every mode — that is the invariant the whole change rests on, since the
    /// rhythm and the sent bubble must not move. The ONE-LINE value is what tells the arms apart.
    func test_recordTheUsedHeightModelUnderEveryMode() {
        let short = "Handy"
        let long = String(repeating: "Handy handy ", count: 12)
        var recorded: [(EngineDocumentBridge.V2BaselinePlacement, CGFloat, CGFloat)] = []

        for mode in [EngineDocumentBridge.V2BaselinePlacement.off, .safe, .exact, .exactWithTrailingSpacing] {
            EngineDocumentBridge.v2BaselinePlacement = mode
            let one = usedHeight(ofBlockWith: short)
            let many = usedHeight(ofBlockWith: long)
            recorded.append((mode, one, many))
            print("RTE-R8 mode=\(mode) oneLine=\(one) wrapped=\(many)")
            XCTAssertGreaterThan(many, one, "mode \(mode): the wrapped fixture must actually wrap")
        }

        // The pitch must not move. Derived per mode as (wrapped - oneLine) / (lines - 1); the line
        // count is unknown here, so compare the DELTAS across modes instead, which is the same claim
        // without needing it: same text, same width, same wrap, so the per-line advance is the only
        // thing that could differ.
        let deltas = recorded.map { $0.2 - $0.1 }
        for (index, delta) in deltas.enumerated() {
            XCTAssertEqual(delta, deltas[0], accuracy: 0.01,
                           "mode \(recorded[index].0) moved baseline-to-baseline — the rhythm and the "
                           + "sent bubble would move with it")
        }
    }
}
