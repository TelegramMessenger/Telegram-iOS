#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

@available(iOS 13.0, *)
final class SyntaxHighlightTests: XCTestCase {
    /// Records every request the canvas makes and lets a test answer them on demand.
    final class StubHighlighter {
        private(set) var requests: [(language: String, text: String)] = []
        private var pending: [([RichTextSyntaxToken]) -> Void] = []

        func provider(_ language: String, _ text: String, _ completion: @escaping ([RichTextSyntaxToken]) -> Void) {
            self.requests.append((language, text))
            self.pending.append(completion)
        }

        func answerAll(with tokens: [RichTextSyntaxToken]) {
            let pending = self.pending
            self.pending = []
            for completion in pending { completion(tokens) }
        }
    }

    private func makeCanvas(_ blocks: [Block], stub: StubHighlighter) -> DocumentCanvasView {
        let canvas = DocumentCanvasView()
        canvas.syntaxHighlightDebounceInterval = 0   // fire on the next runloop turn, not after 300ms
        canvas.syntaxHighlighter = { language, text, completion in stub.provider(language, text, completion) }
        canvas.setBlocks(blocks, width: 320)
        return canvas
    }

    /// Spins the main runloop so the debounced pass — and any answer delivered from it — actually runs.
    /// NOT `DispatchQueue.main.async { fulfill }`: `asyncAfter` is timer-backed, so a plain async block
    /// enqueued afterwards can run FIRST and the wait returns before the pass has fired.
    private func settle(_ interval: TimeInterval = 0.1) {
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }

    func test_requestsAHighlightForACodeBlockWithALanguage() {
        let stub = StubHighlighter()
        // Hold the canvas: the debounced pass captures `self` weakly, so a canvas nobody retains is
        // deallocated before the pass fires and the test measures nothing.
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "Swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        XCTAssertEqual(canvas.boxes.count, 1)
        XCTAssertEqual(stub.requests.count, 1)
        guard stub.requests.count == 1 else { return }
        XCTAssertEqual(stub.requests[0].language, "swift")   // normalized before it leaves the editor
        XCTAssertEqual(stub.requests[0].text, "let x = 1")
    }

    func test_doesNotRequestWithoutALanguageOrWithoutCode() {
        let stub = StubHighlighter()
        // A fourth, VALID block is the control: without it this test passes just as happily against a
        // canvas that requests nothing at all (which is exactly what a deallocated one does).
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("a"), language: nil, runs: [TextRun(text: "let x = 1")])),
            .code(CodeBlock(id: BlockID("b"), language: "  ", runs: [TextRun(text: "let x = 1")])),
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [])),
            .code(CodeBlock(id: BlockID("d"), language: "swift", runs: [TextRun(text: "valid")])),
        ], stub: stub)
        settle()
        XCTAssertEqual(canvas.boxes.count, 4)
        XCTAssertEqual(stub.requests.count, 1, "only the fourth block is eligible")
        XCTAssertEqual(stub.requests.first?.text, "valid")
    }

    func test_burstOfEditsCoalescesIntoOneRequestCarryingTheFinalText() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: []))], stub: stub)
        settle()
        stub.answerAll(with: [])
        let codeStart = canvas.boxes[0].textStart
        canvas.setCaret(global: codeStart)
        canvas.insertText("a")
        canvas.insertText("b")
        canvas.insertText("c")
        settle()
        XCTAssertEqual(stub.requests.count, 1, "three keystrokes must debounce into one pass")
        XCTAssertEqual(stub.requests[0].text, "abc")
    }

    func test_anAnsweredSpecIsNotRequestedAgain() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "ab")]))], stub: stub)
        settle()
        stub.answerAll(with: [])
        XCTAssertEqual(stub.requests.count, 1)
        canvas.scheduleSyntaxHighlightPass()
        settle()
        XCTAssertEqual(stub.requests.count, 1, "the same (language, text) must be served from the cache")
    }

    // An unknown language answers with an empty token list, which is cached like any other answer — so it
    // is attempted once, not on every pass.
    func test_anEmptyAnswerIsCachedLikeAnyOther() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "brainfuck", runs: [TextRun(text: "+++")]))], stub: stub)
        settle()
        stub.answerAll(with: [])
        canvas.scheduleSyntaxHighlightPass()
        settle()
        XCTAssertEqual(stub.requests.count, 1)
    }

    func test_evictsAnAnswerWhoseCodeBlockIsGone() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "ab")]))], stub: stub)
        settle()
        stub.answerAll(with: [])
        canvas.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "x")]))], width: 320)
        settle()
        XCTAssertTrue(canvas.syntaxHighlightCacheIsEmptyForTesting)
    }

    func test_tokensColourTheirRangesInTheCodeLayout() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        stub.answerAll(with: [RichTextSyntaxToken(range: NSRange(location: 0, length: 3), color: .red)])
        let box = canvas.boxes[0] as! CodeBlockBox
        XCTAssertEqual(box.layout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor.red)
        XCTAssertNotEqual(box.layout.attributedString.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor, UIColor.red)
    }

    // The editor's documented idempotence rule: an unconditional re-assign of a layout's string resets the
    // spoiler-hide ranges and spins `layoutIfNeeded`.
    func test_anIdenticalAnswerDoesNotReassignTheLayoutString() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        let tokens = [RichTextSyntaxToken(range: NSRange(location: 0, length: 3), color: .red)]
        stub.answerAll(with: tokens)
        let box = canvas.boxes[0] as! CodeBlockBox
        XCTAssertFalse(box.applySyntaxHighlight(tokens), "re-applying the same tokens must be a no-op")
    }

    func test_anEmptyAnswerLeavesTheBlockPlain() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        stub.answerAll(with: [])
        let box = canvas.boxes[0] as! CodeBlockBox
        let colour = box.layout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(colour, box.mapper.theme.primaryText)
    }

    // Colours are display-only: they must never round-trip into the model.
    func test_highlightNeverReachesTheModel() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "Swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        stub.answerAll(with: [RichTextSyntaxToken(range: NSRange(location: 0, length: 3), color: .red)])
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.text, "let x = 1")
        XCTAssertEqual(code.language, "Swift")   // as typed; the request normalized a COPY, not the model
    }

    // A token range that no longer fits the text (an answer arriving after an edit) is dropped WHOLE.
    func test_staleTokensAreRejectedWholesale() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "abc")]))], stub: stub)
        settle()
        let box = canvas.boxes[0] as! CodeBlockBox
        XCTAssertFalse(box.applySyntaxHighlight([
            RichTextSyntaxToken(range: NSRange(location: 0, length: 1), color: .red),
            RichTextSyntaxToken(range: NSRange(location: 2, length: 99), color: .red),
        ]))
        XCTAssertNotEqual(box.layout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor.red)
    }

    // MARK: - Runtime bugs found in the article editor (2026-08-25)

    // A code block draws into its OWN `BlockBackingView`; `setNeedsDisplay()` on the canvas does not
    // repaint it. Without an explicit repaint the colours sit in the layout while the block keeps its old
    // bitmap until some unrelated layout pass runs `syncBlockViews()` — which is what "not highlighted
    // until I move the cursor out of the code block" was.
    func test_applyingTokensRepaintsTheBlockView() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        let before = canvas.codeHighlightRepaintCountForTesting
        stub.answerAll(with: [RichTextSyntaxToken(range: NSRange(location: 0, length: 3), color: .red)])
        XCTAssertGreaterThan(canvas.codeHighlightRepaintCountForTesting, before,
                             "the block's backing view must be repainted when its colours change")
    }

    func test_anIdenticalAnswerDoesNotRepaint() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        let tokens = [RichTextSyntaxToken(range: NSRange(location: 0, length: 3), color: .red)]
        stub.answerAll(with: tokens)
        let after = canvas.codeHighlightRepaintCountForTesting
        canvas.applySyntaxHighlightsToBoxes()
        XCTAssertEqual(canvas.codeHighlightRepaintCountForTesting, after, "no change, no repaint")
    }

    // A theme change rebuilds every box FROM THE MODEL, which carries no colours. Waiting for the
    // debounced pass to repaint them shows a plain frame first — the "text loses highlight on a
    // dark/light switch" report. The cache already holds the answer, so a rebuild must apply it
    // synchronously.
    func test_aRebuildKeepsTheHighlightWithoutWaitingForAPass() {
        let stub = StubHighlighter()
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")]))], stub: stub)
        settle()
        stub.answerAll(with: [RichTextSyntaxToken(range: NSRange(location: 0, length: 3), color: .red)])

        // What `RichTextEditorView.theme`'s setter does: re-theme the mapper, then reload from the model.
        var dark = RichTextEditorTheme.default
        dark.primaryText = .white
        canvas.applyTheme(dark)
        canvas.reload(canvas.currentBlocks(), width: 320)

        // NO settle: the colours must be there in the very first frame after the rebuild.
        let box = canvas.boxes[0] as! CodeBlockBox
        XCTAssertEqual(box.layout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
                       UIColor.red, "a rebuild must re-apply the cached highlight synchronously")
        XCTAssertEqual(stub.requests.count, 1, "and must not re-request an answer it already has")
    }

}
#endif
