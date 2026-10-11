import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **Not a product defect: an oracle for the p17 fuzz flake (default seed 28, step 17).** An external
/// push landed and then the paste from the step before it showed up in the pushed content, with undo
/// still offered. UIKit's plain-text paste is ASYNCHRONOUS in the engine AND in a stock `UITextView`.
/// It lands 20-30 ms after `paste:` (6-9 run-loop spins, measured p18), so a content set made in that
/// window is overtaken by the paste in both:
///
///     "abc", caret 3, Paste "pasted", set the text to "remote draft" before any run-loop turn
///       engine: "remote draft pasted", canUndo true
///       stock:  "remote draft pasted", canUndo true
///
/// The fuzz's step settle (0.02 s) was shorter than the paste, so the next op could run first. The fuzz
/// now waits `FuzzConfig.pasteSettle` after every paste op. A user cannot get a Send or a draft sync
/// into those 20-30 ms with any regularity. This test pins that the engine does what stock does, so a
/// change on either side shows up here.
///
/// **Tier 1**: `paste:` on the view, the chat's external set (`HarnessPanelHost.setInputContent`).
final class HarnessPasteLatencyOracleTests: XCTestCase {
    private func stock(pasting pasted: String) throws -> (text: String, canUndo: Bool) {
        let root = try HarnessEngine.root()
        let oracle = UITextView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0))
        root.view.addSubview(oracle)
        defer { _ = oracle.resignFirstResponder(); oracle.removeFromSuperview() }
        oracle.text = "abc"
        _ = oracle.becomeFirstResponder()
        oracle.selectedRange = NSRange(location: 3, length: 0)
        HarnessEngine.settle(root)
        UIPasteboard.general.string = pasted
        oracle.paste(nil)
        oracle.text = "remote draft"
        HarnessEngine.settle(root, seconds: 0.5)
        return (oracle.text ?? "", oracle.undoManager?.canUndo ?? false)
    }

    private func engine(pasting pasted: String) throws -> (text: String, canUndo: Bool) {
        guard #available(iOS 18.4, *) else { throw XCTSkip("the engine editor needs iOS 18.4") }
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText("abc"))
        driver.setViewSelection(NSRange(location: 3, length: 0))
        driver.settle(0.2)
        UIPasteboard.general.string = pasted
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        driver.host.setInputContent(HarnessContent.plainText("remote draft"))
        driver.settle(0.5)
        return (driver.viewText(), driver.undoManager?.canUndo ?? false)
    }

    func testAPasteOvertakenByAContentSetMatchesAStockTextView() throws {
        let stock = try self.stock(pasting: "pasted")
        let engine = try self.engine(pasting: "pasted")
        XCTAssertEqual(stock.text, "remote draft pasted", "precondition: the stock paste is no longer asynchronous; the fuzz's pasteSettle may be unnecessary")
        XCTAssertEqual(engine.text, stock.text)
        XCTAssertEqual(engine.canUndo, stock.canUndo)
    }

    func testAMultiLinePasteOvertakenByAContentSetMatchesAStockTextView() throws {
        let stock = try self.stock(pasting: "line one\nline two")
        let engine = try self.engine(pasting: "line one\nline two")
        XCTAssertEqual(engine.text, stock.text)
        XCTAssertEqual(engine.canUndo, stock.canUndo)
    }
}
