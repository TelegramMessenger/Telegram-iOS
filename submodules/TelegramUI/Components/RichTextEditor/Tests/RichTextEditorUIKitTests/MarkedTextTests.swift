#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class InputDelegateSpy: NSObject, UITextInputDelegate {
    var textWillChangeCount = 0, textDidChangeCount = 0
    var selectionWillChangeCount = 0, selectionDidChangeCount = 0
    func selectionWillChange(_ ti: UITextInput?) { selectionWillChangeCount += 1 }
    func selectionDidChange(_ ti: UITextInput?) { selectionDidChangeCount += 1 }
    func textWillChange(_ ti: UITextInput?) { textWillChangeCount += 1 }
    func textDidChange(_ ti: UITextInput?) { textDidChangeCount += 1 }
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange ti: UITextInput?) {}
}

@available(iOS 16.0, *)
final class MarkedTextTests: XCTestCase {
    // Shared harness: two body paragraphs, laid out, first-responder-free (witnesses don't need focus).
    func makeCanvas(_ texts: [String] = ["Alpha", "Beta"]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }
    func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }

    func test_predictionTraits_areEnabled() {
        let v = makeCanvas()
        if #available(iOS 17.0, *) {   // inline predictions are iOS 17+ (absent below)
            XCTAssertEqual(v.inlinePredictionType, .yes)
        }
        XCTAssertEqual(v.autocorrectionType, .yes)
        XCTAssertEqual(v.spellCheckingType, .yes)
    }

    func test_setMarkedText_insertsProvisionalText_andSetsMarkedRange() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)                 // empty first paragraph
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "nihao")
        let m = v.markedTextRange as? DocumentTextRange
        XCTAssertEqual(m?.from.offset, v.boxes[0].textStart)
        XCTAssertEqual(m?.to.offset, v.boxes[0].textStart + 5)
        XCTAssertEqual(v.head, v.boxes[0].textStart + 5) // caret at end of marked text (selectedRange)
    }

    func test_setMarkedText_repeated_replacesInPlace() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))   // grow composition
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "nihao") // not "ninihao"
        XCTAssertEqual((v.markedTextRange as? DocumentTextRange)?.to.offset, v.boxes[0].textStart + 5)
    }

    func test_unmarkText_commits_keepsText_clearsRange() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        v.unmarkText()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "nihao") // committed, not deleted
        XCTAssertNil(v.markedTextRange)
    }

    func test_setMarkedText_emptyString_clearsComposition() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        v.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))         // cancel
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "")
        XCTAssertNil(v.markedTextRange)
    }

    func test_insertText_whileMarked_replacesMarkedRange_andCommits() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        v.insertText("X")                              // confirming keystroke replaces the composition
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "X")
        XCTAssertNil(v.markedTextRange)
    }

    func test_deleteBackward_whileMarked_commitsFirst() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        v.deleteBackward()
        XCTAssertNil(v.markedTextRange)                // composition committed
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "n")  // then one char deleted
    }

    func test_settingSelection_whileMarked_commits() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        caret(v, v.boxes[1].textStart)                 // move caret away
        XCTAssertNil(v.markedTextRange)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "ni")  // kept, committed
    }

    func test_composition_isOneUndoStep() {
        let v = makeCanvas(["", "Beta"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart)
        um.beginUndoGrouping()
        v.setMarkedText("n", selectedRange: NSRange(location: 1, length: 0))
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        v.unmarkText()
        um.endUndoGrouping()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "nihao")
        um.undo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "")   // whole word removed at once
        um.redo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "nihao")
    }

    func test_cancelledComposition_registersNoUndo() {
        let v = makeCanvas(["", "Beta"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        v.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))      // cancel
        XCTAssertFalse(um.canUndo)                                              // nothing to undo
    }

    func test_markedDecorationRects_matchSelectionRectsOfMarkedRange() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        let expected = v.selectionRects(globalFrom: v.markedRange!.from, globalTo: v.markedRange!.to)
        XCTAssertEqual(v.markedTextDecorations(), expected)
        XCTAssertFalse(expected.isEmpty)
    }

    func test_markedDecorationRects_emptyWhenNotComposing() {
        let v = makeCanvas()
        XCTAssertTrue(v.markedTextDecorations().isEmpty)
    }

    func test_reload_bracketsTextChange() {
        let v = makeCanvas(["Alpha"])
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.reload([.paragraph(ParagraphBlock(id: BlockID("z"), runs: [TextRun(text: "Replaced")]))], width: 300)
        XCTAssertEqual(v.currentBlocks().count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Replaced")
        XCTAssertGreaterThanOrEqual(spy.textWillChangeCount, 1)
        XCTAssertGreaterThanOrEqual(spy.textDidChangeCount, 1)
    }

    func test_composition_replacesNonEmptySelection() {
        let v = makeCanvas(["Alpha", "Beta"])
        // Select "lph" inside Alpha, then begin composing.
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: v.boxes[0].textStart + 4)
        v.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "AXa")   // "lph" replaced
        XCTAssertEqual((v.markedTextRange as? DocumentTextRange)?.from.offset, v.boxes[0].textStart + 1)
        XCTAssertEqual((v.markedTextRange as? DocumentTextRange)?.to.offset, v.boxes[0].textStart + 2)
    }

    func test_backspaceWithinComposition_shrinksMarkedText() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        // IME backspace during composition arrives as a shorter setMarkedText, NOT deleteBackward.
        v.setMarkedText("niha", selectedRange: NSRange(location: 4, length: 0))
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "niha")
        XCTAssertEqual((v.markedTextRange as? DocumentTextRange)?.to.offset, v.boxes[0].textStart + 4)
        XCTAssertEqual(v.head, v.boxes[0].textStart + 4)
    }

    func test_setMarkedText_inImageCaption_fallsBackToPlainInsert_noStrandedComposition() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "a", naturalSize: Size2D(width: 100, height: 80),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Body")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        // Put the caret inside the caption (a leaf region that is NOT a top-level body BlockBox).
        let captionLeaf = v.allLeafRegions().first { $0.layout.attributedString.string.contains("Cap") }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(captionLeaf.globalStart + 3),
                                                DocumentTextPosition(captionLeaf.globalStart + 3))
        v.setMarkedText("zz", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNil(v.markedTextRange)                                   // never composed here
        XCTAssertTrue(v.text(in: DocumentTextRange(DocumentTextPosition(captionLeaf.globalStart),
                                                   DocumentTextPosition(captionLeaf.globalStart + 5)))!.contains("zz"))
    }

    func test_setCaret_whileMarked_commits_noStaleRange() {
        let v = makeCanvas(["Alpha", "Beta"])
        // compose "X" in p0 at its start
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedTextRange)
        // gesture caret move into p1 (the path tap/drag use)
        v.setCaret(global: v.boxes[1].textStart)
        XCTAssertNil(v.markedTextRange)                                   // composition finalized
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "XAlpha")  // provisional kept, not stranded
        // a NEW composition now edits p1 (where the caret actually is), NOT the stale p0 range
        v.setMarkedText("Z", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "ZBeta")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "XAlpha") // p0 untouched
    }

    // MARK: Inline predictions (system ghost text) — distinct from CJK composition

    func test_prediction_vs_composition_isDistinguishedBySelectedRange() {
        let v = makeCanvas(["co", "x"])
        let ts = v.boxes[0].textStart
        caret(v, ts + 2)
        // A PREDICTION arrives with the caret at the START (sel {0,0}); the ghost trails the caret.
        v.setMarkedText("untry", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(v.markedTextIsPrediction)
        v.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))     // keyboard clears it
        XCTAssertFalse(v.markedTextIsPrediction)
        // A COMPOSITION keeps the caret at the END (sel at the text's length).
        caret(v, v.boxes[1].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertFalse(v.markedTextIsPrediction)
    }

    /// TASK 9d / PHASE 0b — the differential oracle found this against stock UIKit, and it is a REAL
    /// DEFECT, not an oracle artifact: all 9 inline-prediction scenarios produced a wrong document.
    ///
    /// **The mechanism.** `legacyReplace(globalFrom:globalTo:text:)` captures its `lo`/`hi` BEFORE
    /// entering `editing { }`, and `performEditing`'s first statement is `finalizeMarkedText()`. When the
    /// composition is a PREDICTION (`markedTextIsPrediction`, i.e. `selectedRange == {0,0}`), that
    /// prologue calls `dismissPrediction()`, which REMOVES the ghost — so the document shrinks by the
    /// ghost's length and the caller's offsets are stale by exactly that much. The replace then eats
    /// that many extra characters PAST the intended range.
    ///
    /// **Why it is caret-governed and not structural:** a COMPOSITION (caret at the end) takes
    /// `commitMarkedText()`, which moves nothing, so the same call is correct. That is precisely why the
    /// IME family passed these fields and the inline-prediction family failed.
    ///
    /// RED BEFORE THE FIX: the trailing "Beta" loses its first two characters to the stale range.
    func test_replaceOverALivePrediction_doesNotEatCharactersPastTheRange() {
        let v = makeCanvas(["coBeta"])
        let ts = v.boxes[0].textStart
        caret(v, ts + 2)
        // A prediction: ghost "untry" trailing the caret, selected range {0,0}.
        v.setMarkedText("untry", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(v.markedTextIsPrediction, "precondition: this must be the PREDICTION path")
        guard let m = v.markedTextRange as? DocumentTextRange else {
            return XCTFail("precondition: a marked range must exist")
        }
        // The keyboard replaces exactly the ghost with the accepted word.
        v.legacyReplace(globalFrom: m.from.offset, globalTo: m.to.offset, text: "untry")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "countryBeta",
                       "the replacement must consume ONLY the ghost; the stale-offset bug eats "
                       + "\(m.to.offset - m.from.offset) characters of the following text")
    }

    func test_prediction_dismissedOnGestureCaretMove_notCommitted() {
        let v = makeCanvas(["co"])
        let ts = v.boxes[0].textStart
        caret(v, ts + 2)
        v.setMarkedText("untry", selectedRange: NSRange(location: 0, length: 0))   // ghost → "country"
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "country")
        v.setCaret(global: ts + 7)                                                // user taps elsewhere
        XCTAssertNil(v.markedTextRange)
        // The ghost is DISMISSED (removed), NOT committed — it is keyboard-owned provisional text.
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "co")
    }

    func test_predictionMarkedText_hasNoUnderlineDecoration() {
        let v = makeCanvas(["co"])
        let ts = v.boxes[0].textStart
        caret(v, ts + 2)
        v.setMarkedText("untry", selectedRange: NSRange(location: 0, length: 0))   // prediction
        XCTAssertTrue(v.markedTextIsPrediction)
        XCTAssertTrue(v.markedTextDecorations().isEmpty)   // grey ghost, NOT underlined
    }

    func test_compositionMarkedText_keepsUnderlineDecoration() {
        let v = makeCanvas(["", "x"])
        let ts = v.boxes[0].textStart
        caret(v, ts)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))   // composition (caret at end)
        XCTAssertFalse(v.markedTextIsPrediction)
        XCTAssertFalse(v.markedTextDecorations().isEmpty)   // underline present
    }

    func test_markedUnderline_rendersInSelectionOverlay() {
        // The IME marked-text underline is now drawn by the on-top `selectionHighlight` overlay (not the
        // canvas's own draw(_:)). Guard: a non-prediction composition has underline rects, and the overlay
        // renders without crashing and produces pixels.
        let v = makeCanvas(["", "x"])
        let ts = v.boxes[0].textStart
        caret(v, ts)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))   // composition (caret at END)
        XCTAssertFalse(v.markedTextDecorations().isEmpty, "there is a marked range to underline")
        v.selectionHighlight.frame = v.bounds
        let img = UIGraphicsImageRenderer(bounds: v.selectionHighlight.bounds).image { _ in
            v.selectionHighlight.drawHierarchy(in: v.selectionHighlight.bounds, afterScreenUpdates: true)
        }
        XCTAssertNotNil(img.cgImage)
    }

    func test_setGhostForeground_isRenderingOnly_doesNotModifyStorage() {
        let layout = BlockLayout(attributedString: NSAttributedString(string: "country"), width: 300)
        layout.setGhostForeground(.placeholderText, start: 3, end: 7)
        XCTAssertEqual(layout.attributedString.string, "country")          // text unchanged
        var hasForeground = false                                          // NO colour in the backing store
        layout.attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: 7)) { val, _, _ in
            if val != nil { hasForeground = true }
        }
        XCTAssertFalse(hasForeground)                                      // grey is a rendering attribute only
        layout.setGhostForeground(nil, start: 0, end: 0)                   // clears without crashing
    }

    func test_predictionAcceptViaTap_thenKeyboardReplace_doesNotDuplicateWord() {
        // Faithful replay of the on-device duplication bug: ghost inserted → user taps (setCaret) →
        // keyboard clears its (now-gone) ghost and replaces the typed prefix with the full word.
        // The ghost must be dismissed on the tap, else the keyboard's replace double-applies → "countryuntry".
        let v = makeCanvas(["co"])
        let ts = v.boxes[0].textStart
        caret(v, ts + 2)
        v.setMarkedText("untry", selectedRange: NSRange(location: 0, length: 0))   // ghost → "country"
        v.setCaret(global: ts + 7)                                                // tap (was committing the ghost)
        v.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))        // keyboard clears (no-op now)
        v.replace(DocumentTextRange(DocumentTextPosition(ts), DocumentTextPosition(ts + 2)),
                  withText: "country")                                            // keyboard replaces "co" → "country"
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "country")  // NOT "countryuntry"
    }

    func test_selectAllText_whileComposing_finalizes_soTypingReplacesSelection() {
        // Holistic-review finding: applySelection (Select All / word / paragraph) must finalize marked text,
        // else insertText's `if let m = markedRange` branch replaces the stale ghost instead of the selection.
        let v = makeCanvas(["Alpha", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0))   // composition → "XAlpha"
        XCTAssertNotNil(v.markedTextRange)
        v.selectAllText()                                                     // Select-All path (applySelection)
        XCTAssertNil(v.markedTextRange)                                       // composition finalized, not stale
        XCTAssertNotEqual(v.selFrom, v.selTo)                                 // a real ranged selection
        v.insertText("Z")                                                    // replaces the WHOLE selection
        XCTAssertEqual(v.currentParagraphs().map(\.text).joined(separator: "\n"), "Z")  // not "ZAlpha\nBeta"
    }

    func test_resignFirstResponder_whileMarked_commits() {
        let v = makeCanvas(["", "Beta"])
        caret(v, v.boxes[0].textStart)
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        _ = v.resignFirstResponder()
        XCTAssertNil(v.markedTextRange)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "ni")
    }

    func test_structuralEdit_whileMarked_commitsCompositionThenEdits() {
        // A structural/format edit (via editing{}) during an active composition must FIRST commit the
        // composition — so markedRange is finalized (not stale) and the provisional text is preserved and
        // undoable, rather than corrupted or silently dropped.
        let v = makeCanvas(["Alpha", "Beta"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        v.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0))  // compose → "AlphaX"
        // The composition is committed by editing{}'s first line, then the format edit runs. Both register
        // undo into the open group (one run-loop event = one undo step in production); the point under test
        // is that the composition is FINALIZED (markedRange nil) and its text survives, not the step count.
        um.beginUndoGrouping(); v.setAlignment(.center); um.endUndoGrouping()  // a structural/format edit via editing{}
        XCTAssertNil(v.markedTextRange)                                       // composition finalized, not stale
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "AlphaX")  // provisional text preserved
        XCTAssertEqual((v.boxes[0] as! BlockBox).paragraphAttributes.alignment, .center)  // the format edit applied
        // Undoing the edit reverts both the format and the committed composition cleanly back to "Alpha".
        um.undo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
        XCTAssertNil(v.markedTextRange)
    }
}
#endif
