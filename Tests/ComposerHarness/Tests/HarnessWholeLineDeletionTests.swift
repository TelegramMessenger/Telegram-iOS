import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke (CORRUPTS THE SENT MODEL).** Deleting a WHOLE line — selected from its first
/// character to the start of the next line, which is what ⇧↓ from a line's start, a drag to the next
/// line's start, or a line-select gives — gives the NEXT line the deleted line's block role:
///
///     [p "mid"] [h1 "Title"] [p "end"], select 0..<4 ("mid⏎"), Backspace
///       engine:  [p "Title"] [p "end"]                    the heading is lost
///     [h1 "Head"] [p "body"], select 0..<5, Backspace
///       engine:  [h1 "body"]                              the body line becomes a heading
///     [p "mid"] [quote [p "quoted"]], select 0..<4, Backspace
///       engine:  [p "quoted"]                             the quote is dissolved
///       legacy:  [quote [p "quoted"]]                     (control, inside)
///     [1. "one"] [p "mid"] [1. "three"], select 4..<8, Cut → "three" leaves the list
///     [p "mid"] [code "let"], select 0..<4, Backspace → [p ""] [code "let"] (a blank line stays)
///
/// The same for a checklist item (its check is lost with the membership) and Cut. A stock
/// `UITextView` keeps the next paragraph's style (paragraph attributes belong to the paragraph that
/// survives; oracle inside). Typing OVER the same selection legitimately takes the deleted line's
/// role (stock does too: the typed text's paragraph starts with the replaced text's attributes) and
/// a deletion that keeps part of the first line merges into it — both are passing controls.
///
/// **How it was seen.** p16 roam, 2026-09-25: hosted probes over every block kind below a line.
///
/// **Suspected cause.** `replaceAcrossBlocks` (`RichTextEngineEditorView+SurfaceGate.swift`, the
/// merge branch): `survivor = currentRoles[first]` whenever the start is not a covered container, even
/// when the range starts at the first block's offset 0 and ends at the last block's offset 0 — i.e.
/// the first block is deleted whole and the last is not touched. With empty replacement text the
/// last block's role should survive. The code case is the truncate branch (`endIsLeaf`), which keeps
/// the emptied start block and the separator.
///
/// **Tier 1**: the selection and the edit are the `UITextInput` / edit-menu calls the keyboard makes.
final class HarnessWholeLineDeletionTests: XCTestCase {
    private typealias S = HarnessP16

    private func delete(_ blocks: [ChatInputBlock], _ lower: Int, _ upper: Int, cut: Bool = false, typing: String? = nil) throws -> ChatInputContent {
        let arranged = try S.arrange(blocks)
        defer { S.finish(arranged) }
        S.select(arranged, lower, upper)
        if let typing {
            S.type(arranged, typing)
        } else if cut {
            S.perform(arranged, #selector(UIResponderStandardEditActions.cut(_:)))
        } else {
            S.backspace(arranged)
        }
        return S.content(arranged)
    }

    private func assertContent(_ content: ChatInputContent, _ expected: [ChatInputBlock], _ message: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        let expected = FuzzModel.normalized(ChatInputContent(blocks: expected))
        XCTAssertEqual(S.describe(content), S.describe(expected), message, file: file, line: line)
    }

    func testBackspaceOverTheLineAboveAHeadingKeepsTheHeading() throws {
        let content = try self.delete([S.paragraph("mid"), S.paragraph("Title", style: .heading1), S.paragraph("end")], 0, 4)
        self.assertContent(content, [S.paragraph("Title", style: .heading1), S.paragraph("end")],
                           "deleting the whole line above a heading turned the heading into body text")
    }

    func testBackspaceOverAHeadingLineLeavesTheNextLineBody() throws {
        let content = try self.delete([S.paragraph("Head", style: .heading1), S.paragraph("body"), S.paragraph("end")], 0, 5)
        self.assertContent(content, [S.paragraph("body"), S.paragraph("end")],
                           "deleting a whole heading line turned the body line below it into a heading")
    }

    func testBackspaceOverTheLineAboveAQuoteKeepsTheQuote() throws {
        let blocks = [S.paragraph("mid"), S.quote([S.paragraph("quoted")])]
        // Legacy control: the quote survives the deletion of the line above it.
        var legacy: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(legacy) }
        let value = try HarnessLegacy.arrange(ChatInputContent(blocks: blocks))
        legacy = value
        value.textView.selectedRange = NSRange(location: 0, length: 4)
        HarnessEngine.settle(value.root)
        value.textView.deleteBackward()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(S.describe(FuzzModel.normalized(HarnessLegacy.content(value))), S.describe(ChatInputContent(blocks: [S.quote([S.paragraph("quoted")])])),
                       "control: legacy keeps the quote")
        HarnessLegacy.restore(value)
        legacy = nil

        let content = try self.delete(blocks, 0, 4)
        self.assertContent(content, [S.quote([S.paragraph("quoted")])],
                           "deleting the whole line above a block quote dissolved the quote")
    }

    func testBackspaceOverTheLineAboveACheckedItemKeepsTheItem() throws {
        let content = try self.delete([S.paragraph("mid"), S.item("done", .checklist, checked: true)], 0, 4)
        self.assertContent(content, [S.item("done", .checklist, checked: true)],
                           "deleting the whole line above a checked item dropped its list membership and its check")
    }

    func testCutOfALineBetweenListItemsKeepsTheNextItem() throws {
        let content = try self.delete([S.item("one", .ordered), S.paragraph("mid"), S.item("three", .ordered)], 4, 8, cut: true)
        self.assertContent(content, [S.item("one", .ordered), S.item("three", .ordered)],
                           "cutting the whole line between two list items took the next item out of the list")
    }

    func testBackspaceOverTheLineAboveACodeBlockLeavesNoBlankLine() throws {
        let code = ChatInputBlock.code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let")]))
        let content = try self.delete([S.paragraph("mid"), code, S.paragraph("end")], 0, 4)
        self.assertContent(content, [code, S.paragraph("end")],
                           "deleting the whole line above a code block left a blank line in its place")
    }

    // MARK: controls

    /// Control: TYPING over the same selection takes the deleted line's role (as stock does).
    func testControlTypingOverTheLineAboveAHeadingTakesTheLinesRole() throws {
        let content = try self.delete([S.paragraph("mid"), S.paragraph("Title", style: .heading1)], 0, 4, typing: "X")
        self.assertContent(content, [S.paragraph("XTitle")], "control")
    }

    /// Control: a deletion keeping part of the first line merges the next line into it.
    func testControlPartialDeletionMergesIntoTheFirstLine() throws {
        let content = try self.delete([S.paragraph("mid"), S.paragraph("Title", style: .heading1)], 2, 4)
        self.assertContent(content, [S.paragraph("miTitle")], "control")
    }

    /// Control (p16 fix wave): a COMPOSITION over the same selection does what typing does. Its
    /// selection is decided as a deletion first, and the whole-line rule took that deletion, so the
    /// composition landed in the heading where typing lands in the first line (and, fuzz seed 63, a
    /// selection ending at a quote's author line kept the quote typing drops). The fuzz's own
    /// compose-versus-type invariant decides.
    @available(iOS 18.4, *)
    func testControlACompositionOverWholeLinesDoesWhatTypingDoes() throws {
        let cases: [(ChatInputContent, (Int, Int))] = [
            (ChatInputContent(blocks: [S.paragraph("mid"), S.paragraph("Title", style: .heading1)]), (0, 4)),
            // "Remote" 0..<6, "quoted line" 7..<18, the quote's empty author line at 19.
            (ChatInputContent(blocks: [S.paragraph("Remote"), S.quote([S.paragraph("quoted line")]), S.paragraph("end")]), (0, 19)),
        ]
        for (start, selection) in cases {
            let driver = try EngineFuzzDriver()
            let verifier = FuzzEngineVerifier.nonFatal()
            defer {
                verifier.restore()
                _ = driver.node.resignInputFirstResponder()
            }
            HarnessComposerFuzzTests.perform(driver, start: start, ops: [])
            XCTAssertNil(HarnessComposerFuzzTests.composeViolation(.korean, .insertFinal, selecting: selection, on: driver),
                         "over \(selection) of \(S.describe(start))")
        }
    }

    /// Oracle: a stock `UITextView` keeps the next paragraph's own paragraph style.
    func testControlStockKeepsTheNextParagraphsStyle() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 320.0, height: 120.0))
        root.view.addSubview(textView)
        defer { textView.removeFromSuperview() }
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let text = NSMutableAttributedString(string: "mid\n", attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
        text.append(NSAttributedString(string: "Title", attributes: [.font: UIFont.systemFont(ofSize: 17.0), .paragraphStyle: centered]))
        textView.attributedText = text
        textView.selectedRange = NSRange(location: 0, length: 4)
        textView.deleteBackward()
        XCTAssertEqual(textView.text, "Title")
        let style = textView.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .center, "oracle: stock keeps the surviving paragraph's style")
    }
}
