import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a WIDTH change (rotation, Split View, Stage Manager, an iPad size
/// class change: anything that re-lays the panel out at a new width) re-wraps the text in the same layout
/// pass, but the drawn cursor and selection highlight stay at the OLD geometry until a later run-loop turn.
/// So the frame committed with the new text shows the cursor and highlight where they were before:
///
///     "lorem ipsum…" (6 x), caret at 60, 402 → 300   caretRect (0, 72)   cursor view still at (205, 26)
///     selection 20..<90, 402 → 300                    geometry 12 / 165 / 165 wide, drawn 114 / 267 / 178:
///                                                     the highlight runs past the new right edge
///
/// After one more run-loop turn both are right. The model, the selection range and every geometry answer
/// (`caretRect`, `selectionRects`) are right at once. A stock `UITextView` resized the same way has its
/// cursor and highlight right when `layoutIfNeeded()` returns (control below).
///
/// **How it was seen.** p14 roam, 2026-09-24 (width changes mid-edit): a probe compared
/// `UITextSelectionDisplayInteraction.cursorView` / `highlightView.selectionRects` with the geometry
/// answers straight after a synchronous layout pass at the new width.
///
/// **Suspected cause.** `IDBlockTextView.layoutSubviews` (`RichTextInputDecUpstream/TextView/IDBlockTextView.m`)
/// flushes the selection display (`id_flushSelectionDisplayUpdate`) only when
/// `id_selectionDisplayFlushPending` is set, which only a DOCUMENT change does. A width change re-wraps
/// every line but is not a document change, so the display is left to UIKit's deferred
/// zero-delay timer: the lag the flush exists to remove for typing. The same comment explains why a
/// stock view is not late: UIKit's own canvas posts a viewport-layout notification at the end of its
/// layout.
///
/// **Fixed (p14, 2026-09-24):** `-[IDBlockTextView layoutSubviews]` flushes the selection display when the
/// pass's wrap width or `textContainerInset` differs from the last pass's.
///
/// **Tier 1**: the drawn views are read off the public `UITextSelectionDisplayInteraction`; the width is
/// changed through the root's own layout driver (the panel's `updateLayout(width:)`), as the chat does.
@available(iOS 18.4, *)
final class HarnessWidthChangeSelectionDisplayTests: XCTestCase {
    private static let text = String(repeating: "lorem ipsum dolor sit amet ", count: 6)

    private static func displayInteraction(_ view: UIView) -> UITextSelectionDisplayInteraction? {
        return view.interactions.compactMap { $0 as? UITextSelectionDisplayInteraction }.first
    }

    private static func drawnCursor(_ view: UIView & UITextInput) throws -> CGRect {
        let cursor = try XCTUnwrap(Self.displayInteraction(view)?.cursorView, "precondition: no selection display interaction")
        return cursor.superview.map { $0.convert(cursor.frame, to: view.textInputView) } ?? cursor.frame
    }

    private static func geometryCaret(_ view: UIView & UITextInput) throws -> CGRect {
        let range = try XCTUnwrap(view.selectedTextRange)
        return view.convert(view.caretRect(for: range.end), to: view.textInputView)
    }

    private static func drawnHighlight(_ view: UIView & UITextInput) throws -> [CGRect] {
        let highlight = try XCTUnwrap(Self.displayInteraction(view)?.highlightView, "precondition: no selection display interaction")
        return highlight.selectionRects.map { $0.rect.integral }
    }

    private static func geometryHighlight(_ view: UIView & UITextInput) throws -> [CGRect] {
        let range = try XCTUnwrap(view.selectedTextRange)
        return view.selectionRects(for: range).map { $0.rect.integral }
    }

    private static func near(_ a: CGRect, _ b: CGRect) -> Bool {
        return abs(a.midX - b.midX) <= 2.0 && abs(a.midY - b.midY) <= 2.0
    }

    private func run(select range: NSRange, _ body: (EngineFuzzDriver, UIView & UITextInput) throws -> Void) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
            driver.settle(0.2)
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(ChatInputContent(blocks: [HarnessEngine.paragraph(Self.text), HarnessEngine.paragraph("Second line here.")]))
        driver.setViewSelection(range)
        driver.settle(0.3)
        XCTAssertEqual(driver.viewSelection(), range, "precondition: the selection did not land")
        try body(driver, try XCTUnwrap(driver.view as? (UIView & UITextInput)))
    }

    /// The width change, with only the synchronous layout pass the chat's own layout runs (no run-loop turn).
    private func narrow(_ driver: EngineFuzzDriver) {
        driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 874.0)
        driver.root.view.layoutIfNeeded()
    }

    func testTheCursorFollowsAWidthChangeInTheSameLayoutPass() throws {
        try self.run(select: NSRange(location: 60, length: 0)) { driver, input in
            XCTAssertTrue(Self.near(try Self.drawnCursor(input), try Self.geometryCaret(input)), "precondition: the cursor is not drawn at the caret before the change")
            let before = try Self.geometryCaret(input)
            self.narrow(driver)
            let after = try Self.geometryCaret(input)
            XCTAssertFalse(Self.near(before, after), "precondition: the caret did not move with the re-wrap")
            let drawn = try Self.drawnCursor(input)
            XCTAssertTrue(Self.near(drawn, after), "the cursor is drawn at \(drawn) after the width change, the caret is at \(after) (it was at \(before))")
            driver.settle(0.3)
            XCTAssertTrue(Self.near(try Self.drawnCursor(input), try Self.geometryCaret(input)), "control: a run-loop turn later the cursor is at the caret")
        }
    }

    func testTheSelectionHighlightFollowsAWidthChangeInTheSameLayoutPass() throws {
        try self.run(select: NSRange(location: 20, length: 70)) { driver, input in
            XCTAssertEqual(try Self.drawnHighlight(input), try Self.geometryHighlight(input), "precondition: the highlight is not drawn at the selection before the change")
            self.narrow(driver)
            XCTAssertEqual(try Self.drawnHighlight(input), try Self.geometryHighlight(input), "the highlight is drawn at the old wrap after the width change")
            driver.settle(0.3)
            XCTAssertEqual(try Self.drawnHighlight(input), try Self.geometryHighlight(input), "control: a run-loop turn later the highlight matches")
        }
    }

    /// Control: a stock `UITextView` resized the same way has its cursor and highlight right at once.
    func testAStockTextViewFollowsAWidthChangeInTheSameLayoutPass() throws {
        let root = try HarnessEngine.root()
        let stock = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 390.0, height: 200.0))
        stock.font = UIFont.systemFont(ofSize: 17.0)
        stock.text = Self.text + "\nSecond line here."
        root.view.addSubview(stock)
        defer {
            stock.resignFirstResponder()
            stock.removeFromSuperview()
        }
        XCTAssertTrue(stock.becomeFirstResponder())
        for range in [NSRange(location: 60, length: 0), NSRange(location: 20, length: 70)] {
            stock.frame.size.width = 390.0
            stock.selectedRange = range
            HarnessEngine.settle(root)
            let before = try Self.geometryCaret(stock)
            stock.frame.size.width = 288.0
            stock.layoutIfNeeded()
            if range.length == 0 {
                XCTAssertFalse(Self.near(before, try Self.geometryCaret(stock)), "precondition: the caret did not move with the re-wrap")
                XCTAssertTrue(Self.near(try Self.drawnCursor(stock), try Self.geometryCaret(stock)), "stock: the cursor lags the width change")
            } else {
                XCTAssertEqual(try Self.drawnHighlight(stock), try Self.geometryHighlight(stock), "stock: the highlight lags the width change")
            }
        }
    }
}
