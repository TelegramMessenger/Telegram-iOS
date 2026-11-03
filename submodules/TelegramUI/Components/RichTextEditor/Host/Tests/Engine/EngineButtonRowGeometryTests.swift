import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-buttons Task 3 — the row is DRAWN, and a role with no view is a reported defect.
@available(iOS 18.4, *)
final class EngineButtonRowGeometryTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func button(_ label: String) -> ButtonRef {
        ButtonRef(label: [TextRun(text: label)], action: .url("https://example.com"))
    }
    private func row(_ id: String, _ n: Int, _ alignment: ButtonRowAlignment = .justify) -> Block {
        .buttonRow(ButtonRowBlock(id: BlockID(id), buttons: (0 ..< n).map { button("B\($0)") },
                                  alignment: alignment))
    }

    func test_everyRowRoleOwnsARowView() {
        editor.document = Document(blocks: [row("r1", 2), row("r2", 1)])
        editor.layoutIfNeeded()
        XCTAssertEqual(Set(editor.buttonRowViews.keys), [BlockID("r1"), BlockID("r2")])
    }

    func test_aRowRoleWithNoViewIsReportedByTheCompletenessCheck() {
        editor.document = Document(blocks: [row("r1", 2)])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.derivedViewShortfall(), [])
        // Neuter the pool the way the check exists to catch: a view culled while its role lives.
        editor.buttonRowViews[BlockID("r1")]?.removeFromSuperview()
        editor.buttonRowViews[BlockID("r1")] = nil
        XCTAssertEqual(editor.derivedViewShortfall(), ["button row missing for r1"])
    }

    func test_aViewIsCulledWhenTheRowGoes() {
        editor.document = Document(blocks: [row("r1", 2)])
        editor.layoutIfNeeded()
        XCTAssertFalse(editor.buttonRowViews.isEmpty)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p")))])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.buttonRowViews.isEmpty)
    }

    func test_theAtomReservesThePackedHeight() {
        editor.document = Document(blocks: [row("r", 2)])
        editor.layoutIfNeeded()
        let frame = editor.engine.id_attachmentFrame(forCanonicalOffset: 0)
        XCTAssertEqual(frame.height, 40.0, accuracy: 0.5, "one visual row at blockRowHeight")
    }

    func test_nineJustifiedPillsReserveTwoRows() {
        editor.document = Document(blocks: [row("r", 9)])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_attachmentFrame(forCanonicalOffset: 0).height,
                       86.0, accuracy: 0.5, "40 + blockSpacing 6 + 40")
    }

    /// A style change must not un-stamp the "\u{2026}" control. It is not derived from the mapper or
    /// the deferred configuration — it is stamped from whether a host is listening — so every
    /// applier that swaps the bridge has to carry it, and each one used to construct the bridge
    /// inline instead (`remakeBridge`). It is part of the MEASUREMENT, so losing it silently
    /// re-packs every row to a width the sent message will not have, which is why the width is
    /// asserted here and not only the flag.
    func test_aStyleChangeKeepsTheRowsMenuAffordance() {
        editor.onRequestButtonRowMenu = { _ in }
        editor.document = Document(blocks: [row("r", 1)])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.bridge.showsButtonRowMenuAffordance, "precondition: a host is listening")
        let before = editor.engine.id_attachmentFrame(forCanonicalOffset: 0).width

        editor.quoteStyle = QuoteStyle(leadingInset: 9.0, topInset: 4.0, bottomInset: 4.0)
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.bridge.showsButtonRowMenuAffordance, "a quote-geometry change is not a host going away")
        XCTAssertEqual(editor.engine.id_attachmentFrame(forCanonicalOffset: 0).width, before, accuracy: 0.5,
                       "so the row is packed against the same width")
    }

    func test_aQuotedRowIsMeasuredAgainstTheIndentedColumn() {
        editor.document = Document(blocks: [row("r", 1)])
        editor.layoutIfNeeded()
        let top = editor.engine.id_attachmentFrame(forCanonicalOffset: 0).width
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [row("r", 1)], author: [])),
        ])
        editor.layoutIfNeeded()
        let quoted = editor.engine.id_attachmentFrame(forCanonicalOffset: 0).width
        XCTAssertEqual(top - quoted,
                       editor.bridge.styleSheet.quoteIndent + editor.bridge.styleSheet.quoteTrailingInset,
                       accuracy: 0.5,
                       "probe P1: TextKit proposes the full container width, so the atom subtracts BOTH "
                       + "of the quote's insets — the trailing half joined it 2026-09-11")
    }
}
