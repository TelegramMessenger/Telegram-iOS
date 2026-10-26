#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasImageEditTests: XCTestCase {
    private func canvas(_ texts: [String]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks(texts.enumerated().map { .paragraph(ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])) },
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    /// The medium's natural size. (The editor no longer CPU-draws a UIImage — media is a host-supplied
    /// view keyed by `mediaID`; these edit/undo/structure tests need only the block's natural size.)
    private func imgSize() -> CGSize { CGSize(width: 60, height: 40) }

    func test_insertImage_atEndOfParagraph_addsImageBlockAfter() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        let size = imgSize()
        v.insertMedia(mediaID: "k1", naturalSize: size, kind: .image)
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart)     // caret in the caption
    }

    func test_insertMedia_whenUnfocused_doesNotStealFocus_butSetsModelCaret() {
        // Inserting media (e.g. from a picker) must NOT grab first responder / pop the keyboard when the
        // editor was not focused. The media block is still inserted and the MODEL caret is placed at its
        // caption, so a later tap/focus lands there — but the editor stays unfocused.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.makeKeyAndVisible()
        let v = canvas(["Alpha"])
        window.addSubview(v)
        v.layoutIfNeeded()
        caret(v, v.boxes[0].textStart + 5)
        XCTAssertFalse(v.isFirstResponder, "precondition: not focused before the insert")
        v.insertMedia(mediaID: "k1", naturalSize: imgSize(), kind: .image)
        XCTAssertFalse(v.isFirstResponder, "inserting media must NOT steal focus when the editor was unfocused")
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "the media block was inserted")
        let media = v.boxes.first { $0 is MediaBlockBox }!
        XCTAssertEqual(v.head, media.textStart, "the model caret is placed at the new media's caption")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
        // Hygiene: don't leak a key window into sibling tests.
        v.removeFromSuperview()
        window.isHidden = true
        window.resignKey()
    }

    func test_insertMedia_whenFocused_keepsFocus() {
        // When the editor IS focused, inserting media keeps focus (unchanged) and lands the caret in the caption.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.makeKeyAndVisible()
        let v = canvas(["Alpha"])
        window.addSubview(v)
        v.layoutIfNeeded()
        _ = v.becomeFirstResponder()
        XCTAssertTrue(v.isFirstResponder, "precondition: focused before the insert")
        caret(v, v.boxes[0].textStart + 5)
        v.insertMedia(mediaID: "k1", naturalSize: imgSize(), kind: .image)
        XCTAssertTrue(v.isFirstResponder, "an already-focused editor stays focused")
        let media = v.boxes.first { $0 is MediaBlockBox }!
        XCTAssertEqual(v.head, media.textStart, "caret in the caption")
        // Hygiene.
        _ = v.resignFirstResponder()
        v.removeFromSuperview()
        window.isHidden = true
        window.resignKey()
    }

    func test_typingIntoEmptyCaption_staysCentered() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        let size = imgSize()
        v.insertMedia(mediaID: "kc", naturalSize: size, kind: .image)
        let imgBox = v.boxes[1] as! MediaBlockBox
        caret(v, imgBox.textStart)                       // start of the EMPTY caption
        // The caption is render-only centered; typing into an empty caption must carry that centering,
        // not fall back to left-aligned. (Before the fix, the empty-region typing path used .body/.default
        // = left, because a caption's ref is .caption(id), not .paragraph(id).)
        XCTAssertEqual((v.typingAttributesAtGlobal(imgBox.textStart)[.paragraphStyle] as? NSParagraphStyle)?.alignment,
                       .center)
        v.insertText("Hi")
        XCTAssertEqual(imgBox.caption.attributedString.string, "Hi")
        let ps = imgBox.caption.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(ps?.alignment, .center)           // typed text is centered, like the placeholder
    }

    func testInsertAudioLandsCaretInFollowingParagraph() {
        // canvas seeded with a single empty body paragraph; caret in it.
        let v = canvas([""])
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "doc:1", naturalSize: CGSize(width: 1, height: 1), kind: .audio)
        // After: [audio, body paragraph]; caret in the trailing paragraph (NOT in the audio gap).
        XCTAssertEqual(v.boxes.count, 2)
        guard let audioBox = v.boxes[0] as? MediaBlockBox, audioBox.isAudio else {
            return XCTFail("block 0 should be audio")
        }
        XCTAssertTrue(v.boxes[1] is BlockBox, "block 1 should be a paragraph")
        // caret is inside block 1's text region, not at the audio gap.
        XCTAssertGreaterThan(v.head, audioBox.nodeStart)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands at the start of the trailing paragraph")
    }

    func test_insertImage_onEmptyParagraph_replacesParagraph() {
        let v = canvas([""])                             // a single empty paragraph
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "ke", naturalSize: imgSize(), kind: .image)
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is replaced by the image, not left beside it")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart, "caret lands in the image's caption")
    }

    func test_insertImage_onEmptyParagraphBetweenContent_replacesIt() {
        let v = canvas(["A", "", "B"])                   // A, empty middle paragraph, B
        caret(v, v.boxes[1].textStart)
        v.insertMedia(mediaID: "km", naturalSize: imgSize(), kind: .image)
        XCTAssertEqual(v.boxes.count, 3, "A | image | B — the empty paragraph is replaced, not split into two empties")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "A")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "B")
    }

    func test_insertImage_midParagraph_splitsAroundImage() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 2)               // after "Al"
        let size = imgSize()
        v.insertMedia(mediaID: "k2", naturalSize: size, kind: .image)
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Al")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "pha")
    }

    func test_insertImage_isUndoable() {
        let v = canvas(["Alpha"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart + 5)
        let size = imgSize()
        um.beginUndoGrouping(); v.insertMedia(mediaID: "k3", naturalSize: size, kind: .image); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 2)
        um.undo()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox })
    }

    private func docWithImage() -> DocumentCanvasView {
        let v = canvas(["Above", "Below"])
        caret(v, v.boxes[0].textStart + 5)
        let size = imgSize()
        v.insertMedia(mediaID: "k", naturalSize: size, kind: .image)   // → ["Above", image, "Below"]
        return v
    }

    func test_backspaceAtGap_nonEmptyPrev_deletesPrevLastChar_keepsImage() {
        // Caret at the media's leading gap (a plain, NON-tap-selected caret — `caret()` goes through the
        // selectedTextRange setter, which clears imageSelection, exactly like the OS). Backspace acts on the
        // PREVIOUS block: it deletes that block's last grapheme and the image is kept.
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        v.deleteBackward()
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "the image is kept")
        XCTAssertEqual(v.boxes.count, 3, "no block added or removed")
        XCTAssertEqual((v.boxes[0] as? BlockBox)?.currentParagraph().text, "Abov", "previous block's last char deleted")
        XCTAssertEqual((v.boxes[2] as? BlockBox)?.currentParagraph().text, "Below", "following block untouched")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 4, "caret moved into the previous block, after 'Abov'")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtGap_emptyPrev_deletesEmptyBlock_keepsImage() {
        // Empty previous paragraph before the image → Backspace at the gap deletes that empty paragraph
        // (the image is kept), and the caret stays at the image's now-shifted gap.
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")                              // Enter at gap → ["Above", "", image, "Below"]
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.textLength, 0, "precondition: empty paragraph before the image")
        let imageBox = v.boxes.first { $0 is MediaBlockBox }!
        caret(v, imageBox.nodeStart)                    // gap before the image
        v.deleteBackward()
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "the image is kept")
        XCTAssertEqual(v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }, ["Above", nil, "Below"],
                       "the empty paragraph is removed; image (nil text) sits between Above and Below")
        let newImage = v.boxes[1] as! MediaBlockBox
        XCTAssertEqual(v.head, newImage.nodeStart, "caret stays at the image's (shifted) gap")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtGap_prevIsMedia_stepsOntoIt_noDelete() {
        // Two adjacent images. A plain gap caret at the SECOND image → Backspace steps the caret onto the
        // FIRST image (its gap) without deleting anything; a further Backspace would then act on it.
        let v = canvas(["Above", "Below"])
        caret(v, v.boxes[0].textStart + 5)              // end of "Above"
        v.insertMedia(mediaID: "a", naturalSize: imgSize(), kind: .image)   // ["Above", imgA, "Below"]
        let below = v.boxes[2]
        caret(v, below.textStart)                       // start of "Below"
        v.insertMedia(mediaID: "b", naturalSize: imgSize(), kind: .image)   // ["Above", imgA, imgB, "Below"]
        XCTAssertTrue(v.boxes[1] is MediaBlockBox && v.boxes[2] is MediaBlockBox, "precondition: two adjacent images")
        let imgB = v.boxes[2] as! MediaBlockBox
        let imgA = v.boxes[1] as! MediaBlockBox
        caret(v, imgB.nodeStart)                         // plain gap caret at the second image
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 4, "nothing deleted")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox && v.boxes[2] is MediaBlockBox, "both images kept")
        // `prevTextPosition` steps onto the previous atom's nearest text slot: for a captionless image
        // that is its (empty) caption start (`textStart == nodeStart + 2`), not the gap. A further
        // Backspace there hits the caption-start branch and deletes imgA — i.e. it acts on the atom.
        XCTAssertEqual(v.head, imgA.textStart, "caret stepped onto the previous image's caption start")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtGap_prevIsTable_isSafeNoOp_caretStaysAtGap() {
        // Previous block is a TABLE — a non-text atom whose prevTextPosition is a non-renderable structural
        // boundary. Backspace at the image's gap must NOT hide the caret or delete the table; it leaves the
        // caret visibly at the gap (a safe no-op).
        func cell(_ id: String, _ t: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
        }
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                              rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40)))
        ], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        let img = v.boxes[1] as! MediaBlockBox
        caret(v, img.nodeStart)                          // plain gap caret at the image (previous block is the table)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2, "nothing deleted")
        XCTAssertTrue(v.boxes[0] is TableBlockBox, "the table is kept")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "the image is kept")
        XCTAssertEqual(v.head, img.nodeStart, "caret stays at the image gap (renderable), not hidden at the table boundary")
        XCTAssertTrue(v.isRenderablePosition(v.head), "caret remains at a renderable position")
    }

    func test_backspaceAtGap_leadingImage_isNoOp() {
        // The image is the document's FIRST block. A plain gap caret + Backspace is a no-op (nothing to the
        // left) — the image is kept and the doc is unchanged. (A leading image is still deletable by tapping it.)
        let v = canvas([""])                            // single empty paragraph
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "k", naturalSize: imgSize(), kind: .image)   // replaces the empty para → [image]
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        caret(v, v.boxes[0].nodeStart)                  // plain gap caret at the leading image
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "no-op: nothing deleted")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "the leading image is kept")
    }

    func test_backspaceAtCaptionStart_replacesImageWithEmptyParagraph() {
        // Backspace at the start of a caption replaces the whole media block with an empty body paragraph
        // (in place), caret there — it does NOT delete-and-merge the caret into the block above.
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].textStart)                  // start of the EMPTY caption
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the media is replaced")
        XCTAssertEqual(v.boxes.count, 3, "replaced in place — block count unchanged")
        XCTAssertEqual(v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }, ["Above", "", "Below"])
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.currentParagraph().style, .body)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the new empty paragraph")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceOnEmptyCaption_whenImageIsOnlyBlock_leavesEmptyParagraph() {
        // Deleting the document's only block must never leave a zero-block document — it leaves a single
        // empty paragraph. (A lone [image] is reachable since inserting on an empty paragraph replaces it.)
        let v = canvas([""])                            // single empty paragraph
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "ko", naturalSize: imgSize(), kind: .image)   // replaces the empty para → [image]
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        caret(v, v.boxes[0].textStart)                  // caret in the empty caption
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the image is deleted")
        XCTAssertEqual(v.boxes.count, 1, "the document keeps a single empty paragraph — never zero blocks")
        XCTAssertTrue(v.boxes[0] is BlockBox)
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    func test_backspaceWithSelectionCoveringImageNode_replacesImageWithEmptyParagraph() {
        // Tapping an empty image caption places a collapsed caret, but UIKit then EXPANDS it (via the
        // selectedTextRange setter) into a selection covering the whole image node [nodeStart, captionEnd] —
        // the "object replacement" atom. Backspace over that selection replaces the media with an empty body
        // paragraph IN PLACE (caret there), not deleting-and-merging into the block above.
        let v = docWithImage()                           // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        // Reproduce the OS expansion exactly: anchor at the image's gap, head at the (empty) caption start.
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(im.nodeStart), DocumentTextPosition(im.textStart))
        XCTAssertNotEqual(v.selFrom, v.selTo, "precondition: a real selection spanning the image node")
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the media is replaced")
        XCTAssertEqual(v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }, ["Above", "", "Below"])
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the new empty paragraph")
    }

    func test_backspaceOnTapSelectedImage_replacesWithEmptyParagraph() {
        // A tap-SELECTED media block (structural selection) + Backspace replaces the media with an empty body
        // paragraph IN PLACE (caret there) — it does NOT move the caret up into the paragraph above.
        let v = docWithImage()                          // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        v.selectImage(im)
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the media is replaced")
        XCTAssertEqual(v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }, ["Above", "", "Below"])
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.currentParagraph().style, .body)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the new empty paragraph, not the block above")
        XCTAssertNil(v.imageSelection, "the image structural selection is cleared")
    }

    func test_backspaceOnTapSelectedImage_iosObjectReplacementRange_replacesWithEmptyParagraph() {
        // Reproduces the REAL iOS runtime sequence (captured from the device log): tap-select the image
        // (selectImage), then iOS OVERRIDES the selection — via the selectedTextRange setter, which clears
        // imageSelection — to a RANGE whose head lands at the media's gap but anchors in the PRECEDING block
        // (iOS's object geometry is offset from our position model). Without the fix, deleteBackward took the
        // selection-replace path and deleted the preceding text, KEEPING the media. It must replace the media.
        let v = docWithImage()                           // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        v.selectImage(im)                                // structural selection (imageSelection set, caret at gap)
        let gap = im.nodeStart
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(gap - 2), DocumentTextPosition(gap))
        XCTAssertNil(v.imageSelection, "precondition: iOS cleared the structural image selection")
        XCTAssertNotEqual(v.selFrom, v.selTo, "precondition: a real (object-replacement) range selection")
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the media is replaced (not the preceding text)")
        XCTAssertEqual(v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }, ["Above", "", "Below"])
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the new empty paragraph")
    }

    func test_backspaceAtGap_objectReplacementRange_actsOnPrevBlock() {
        // The real iOS delivery for a plain (non-tap-selected) gap caret Backspace can be an object-
        // replacement RANGE [prevEnd … gap] pushed through the selectedTextRange setter (which clears
        // imageSelection). It must behave exactly like the collapsed-caret gap Backspace: delete the
        // previous block's last char, keep the image — NOT relocate-without-deleting.
        let v = docWithImage()                          // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        let prevEnd = v.boxes[0].textStart + v.boxes[0].textLength   // end of "Above"
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(prevEnd), DocumentTextPosition(im.nodeStart))
        XCTAssertNil(v.imageSelection, "precondition: not a tap-selection")
        v.deleteBackward()
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "image kept")
        XCTAssertEqual((v.boxes[0] as? BlockBox)?.currentParagraph().text, "Abov", "previous block's last char deleted")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 4, "caret moved into the previous block")
    }

    func test_backspaceAtStartOfNonEmptyCaption_replacesImageWithEmptyParagraph() {
        // Backspace at the START of a caption replaces the media block (and its caption) with an empty body
        // paragraph in place — the caption text is discarded (consistent with the empty-caption case).
        let v = docWithImage()                          // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        caret(v, im.textStart)
        v.insertText("Cap")                             // caption is now "Cap"
        caret(v, im.textStart)                          // caret back to the caption START
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the media is replaced (caption discarded)")
        XCTAssertEqual(v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }, ["Above", "", "Below"])
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the new empty paragraph")
    }

    private func imageThenEmptyParagraph() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40))),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: []))   // empty paragraph after the image
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_backspaceAtStartOfEmptyParagraphAfterImage_removesParagraph_keepsImage() {
        // The reported bug: caret at the start of an EMPTY paragraph directly below an image. Backspace
        // must remove the empty PARAGRAPH (not the image), parking the caret at the image's caption end.
        let v = imageThenEmptyParagraph()               // [image, ""]
        XCTAssertEqual(v.boxes.count, 2)
        caret(v, v.boxes[1].textStart)                  // start of the empty paragraph
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is removed; the image is NOT deleted")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "the image is kept")
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength, "caret parks at the image's caption end")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtStartOfEmptyParagraphAfterImage_isUndoable() {
        let v = imageThenEmptyParagraph()               // [image, ""]
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].textStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 1, "empty paragraph removed")
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "image kept")
        um.undo()
        XCTAssertEqual(v.boxes.count, 2, "undo restores the empty paragraph")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.textLength, 0)
    }

    func test_backspaceAtStartOfNonEmptyParagraphAfterImage_keepsImageAndText_movesCaretIntoCaption() {
        // Backspace at the start of a NON-EMPTY paragraph below an image must NOT delete the image and
        // must NOT delete the paragraph's text — it just steps the caret back to the image's caption end.
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[2].textStart)                  // start of "Below" (box after the image)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 3, "nothing is deleted")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "the image is kept")
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "Below", "the paragraph text is intact")
        XCTAssertEqual(v.head, v.boxes[1].textStart + v.boxes[1].textLength, "caret moved to the image's caption end")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtGapDeletingEmptyPrev_isUndoable() {
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")                              // ["Above", "", image, "Below"]
        let imageBox = v.boxes.first { $0 is MediaBlockBox }!
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, imageBox.nodeStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "the image is kept")
        XCTAssertEqual(v.boxes.count, 3, "the empty previous paragraph is removed")
        um.undo()
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "undo keeps the media")
        XCTAssertEqual(v.boxes.count, 4, "undo restores the empty previous paragraph")
        XCTAssertEqual(v.head, v.anchor, "undo restores a collapsed caret")
        XCTAssertTrue(v.isRenderablePosition(v.head), "restored caret is at a renderable position")
        XCTAssertEqual(v.head, v.boxes[2].nodeStart, "undo restores the caret to the image's gap")
    }

    func test_backspaceAtGap_nonEmptyPrev_isUndoable() {
        // Non-empty previous block: Backspace at the image's gap deletes that block's last char; undo restores it.
        let v = docWithImage()                          // ["Above", image, "Below"]
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual((v.boxes[0] as? BlockBox)?.currentParagraph().text, "Abov", "char deleted")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "image kept")
        um.undo()
        XCTAssertEqual((v.boxes[0] as? BlockBox)?.currentParagraph().text, "Above", "undo restores the char")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "image still present after undo")
    }

    func test_typingAtGapBeforeImage_insertsParagraphBeforeImage() {
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        v.insertText("Hi")
        XCTAssertEqual(v.boxes.count, 4)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Hi")  // new paragraph before image
        XCTAssertTrue(v.boxes[2] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart + 2)                         // caret at end of "Hi"
        guard case .media(let out) = v.boxes[2].currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.caption.map(\.text).joined(), "")                     // caption untouched
    }

    func test_enterAtGapBeforeImage_insertsEmptyParagraphBeforeImage() {
        let v = docWithImage()
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 4)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "")    // empty paragraph before image
        XCTAssertTrue(v.boxes[2] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart)                            // caret in the empty paragraph
    }

    func test_typingAtGapBeforeImage_isUndoable() {
        let v = docWithImage()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].nodeStart)
        um.beginUndoGrouping(); v.insertText("Hi"); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 4)
        um.undo()
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertFalse(v.boxes.contains { ($0 as? BlockBox)?.currentParagraph().text == "Hi" })
    }

    func test_typingAtGapBeforeLeadingImage_insertsParagraphAtDocumentStart() {
        let v = canvas(["Below"])
        caret(v, v.boxes[0].textStart)                  // start of "Below"
        let size = imgSize()
        v.insertMedia(mediaID: "k0", naturalSize: size, kind: .image)  // → [image, "Below"]
        caret(v, v.boxes[0].nodeStart)                  // gap before the leading image
        v.insertText("Top")
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Top")  // new first block
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3)
    }

    // MARK: - Select All + backspace removes a covered image (regardless of its position)

    private func leadingImage() -> DocumentCanvasView {
        let v = canvas(["Below"])
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "kl", naturalSize: imgSize(), kind: .image)   // → [image, "Below"]
        return v
    }
    private func trailingImage() -> DocumentCanvasView {
        let v = canvas(["Above"])
        caret(v, v.boxes[0].textStart + 5)
        v.insertMedia(mediaID: "kt", naturalSize: imgSize(), kind: .image)   // → ["Above", image]
        return v
    }

    func test_selectAll_thenBackspace_removesMiddleImage() {
        let v = docWithImage()                           // ["Above", image, "Below"]
        v.selectAllText()
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "Select All + backspace removes the image")
        XCTAssertEqual(v.boxes.count, 1, "the document collapses to one empty paragraph")
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    func test_selectAll_thenBackspace_removesTrailingImage() {
        let v = trailingImage()                          // ["Above", image]
        v.selectAllText()
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "Select All + backspace removes a trailing image")
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    func test_selectAll_thenBackspace_removesLeadingImage() {
        let v = leadingImage()                           // [image, "Below"]
        v.selectAllText()
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "Select All + backspace removes a leading image")
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    // MARK: - Backspace as object-replacement range after image (iOS range-form delivery)

    // iOS delivers Backspace in an empty paragraph immediately AFTER a non-paragraph atom (image / table /
    // code / collapsed quote) as an object-replacement RANGE running from the atom's text end to the empty
    // paragraph's start — the same offset-geometry pattern as the code-block case. The range-form branch in
    // deleteBackward() must handle all atoms via isNonParagraphAtom, not just CodeBlockBox. Before the fix
    // the branch was code-only, so an empty paragraph after an IMAGE fell through to applySelectionReplaceOutcome
    // and was stranded (block count stayed 3; the empty paragraph was not removed).
    func test_backspaceObjectReplacementRangeAfterImage_removesEmptyParagraph() {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40))),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [])),   // empty paragraph after the image
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        let image = v.boxes[1], emptyPara = v.boxes[2]
        // Simulate iOS's object-replacement range: anchor at the image's caption end, head at the empty paragraph's start.
        v.setSelectionAnchor(global: v.prevTextPosition(before: emptyPara.textStart))
        v.setSelectionHead(global: emptyPara.textStart)
        XCTAssertNotEqual(v.selFrom, v.selTo, "precondition: a real (object-replacement) range selection")

        v.deleteBackward()

        XCTAssertEqual(v.boxes.count, 2, "the empty trailing paragraph is removed")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "the image is kept")
        XCTAssertEqual(v.head, image.textStart + image.textLength, "caret parks at the image's caption end")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    // MARK: - Select All + backspace removes a covered audio block

    private func docWithAudio() -> DocumentCanvasView {
        // Seeds a document with [paragraph "ab", audio, paragraph ""] via insertMedia at the end of "ab".
        // Audio insert always appends a trailing empty paragraph so the caret has a text home.
        let v = canvas(["ab"])
        caret(v, v.boxes[0].textStart + 2)               // end of "ab"
        v.insertMedia(mediaID: "doc:1", naturalSize: CGSize(width: 1, height: 1), kind: .audio)
        // After insert: ["ab", audio, ""] — 3 blocks (the trailing empty paragraph is mandatory for audio).
        return v
    }

    func test_selectAll_thenBackspace_removesAudio() {
        // seed: [paragraph "ab", audio, paragraph ""]; select-all + delete
        let v = docWithAudio()
        // Precondition: doc contains an audio block.
        XCTAssertTrue(v.boxes.contains { ($0 as? MediaBlockBox)?.isAudio == true }, "precondition: audio block present")
        v.selectAllText()
        v.deleteBackward()
        // Audio is gone; document is a single empty paragraph.
        XCTAssertFalse(v.boxes.contains { ($0 as? MediaBlockBox)?.isAudio == true },
                       "Select All + backspace should remove the audio block")
        XCTAssertEqual(v.boxes.count, 1, "the document collapses to one block")
        XCTAssertTrue(v.boxes[0] is BlockBox, "the remaining block is a paragraph")
    }

    // MARK: - Enter in a media caption

    func test_enterAtEndOfCaption_addsEmptyParagraphAfterImage() {
        // Caret at the END of a caption → a new EMPTY body paragraph appears immediately after the
        // image; the caption is unchanged; the caret lands in the new paragraph.
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "k",
                              naturalSize: Size2D(width: 60, height: 40),
                              caption: [TextRun(text: "Caption")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Below")]))
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        let imgBox = v.boxes[0] as! MediaBlockBox
        caret(v, imgBox.textStart + imgBox.textLength)      // caret at end of "Caption"
        v.insertText("\n")

        XCTAssertEqual(v.boxes.count, 3, "a new body paragraph is inserted after the image")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "image stays at index 0")
        guard case .media(let m) = v.boxes[0].currentBlock() else { return XCTFail("box 0 must be media") }
        XCTAssertEqual(m.caption.map(\.text).joined(), "Caption", "caption is unchanged")
        guard let newPara = v.boxes[1] as? BlockBox else { return XCTFail("box 1 must be a BlockBox") }
        XCTAssertEqual(newPara.currentParagraph().style, .body, "new paragraph has body style")
        XCTAssertEqual(newPara.textLength, 0, "new paragraph is empty")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands at the start of the new paragraph")
        XCTAssertEqual(v.head, v.anchor, "caret is collapsed")
    }

    func test_enterMidCaption_movesTailToNewParagraph() {
        // Caret in the MIDDLE of a caption → head stays as caption, tail moves to a new body paragraph.
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "k",
                              naturalSize: Size2D(width: 60, height: 40),
                              caption: [TextRun(text: "HelloWorld")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Below")]))
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        let imgBox = v.boxes[0] as! MediaBlockBox
        caret(v, imgBox.textStart + 5)                      // after "Hello"
        v.insertText("\n")

        XCTAssertEqual(v.boxes.count, 3, "a new paragraph is inserted after the image")
        guard case .media(let m) = v.boxes[0].currentBlock() else { return XCTFail("box 0 must be media") }
        XCTAssertEqual(m.caption.map(\.text).joined(), "Hello", "head stays as the caption")
        guard let newPara = v.boxes[1] as? BlockBox else { return XCTFail("box 1 must be a BlockBox") }
        XCTAssertEqual(newPara.currentParagraph().runs.map(\.text).joined(), "World",
                       "tail moves to the new paragraph")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands at the start of the new paragraph")
        XCTAssertEqual(v.head, v.anchor, "caret is collapsed")
    }

    func test_enterAtStartOfCaption_movesWholeCaptionDown() {
        // Caret at the START of a caption → caption becomes empty, whole text moves to a new body paragraph.
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "k",
                              naturalSize: Size2D(width: 60, height: 40),
                              caption: [TextRun(text: "Caption")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Below")]))
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        let imgBox = v.boxes[0] as! MediaBlockBox
        caret(v, imgBox.textStart)                          // caret at caption start
        v.insertText("\n")

        XCTAssertEqual(v.boxes.count, 3, "a new paragraph is inserted after the image")
        guard case .media(let m) = v.boxes[0].currentBlock() else { return XCTFail("box 0 must be media") }
        XCTAssertEqual(m.caption.map(\.text).joined(), "", "caption is now empty")
        guard let newPara = v.boxes[1] as? BlockBox else { return XCTFail("box 1 must be a BlockBox") }
        XCTAssertEqual(newPara.currentParagraph().runs.map(\.text).joined(), "Caption",
                       "whole caption text moves to the new paragraph")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands at the start of the new paragraph")
        XCTAssertEqual(v.head, v.anchor, "caret is collapsed")
    }

    func test_enterMidCaption_preservesTailRunFormatting() {
        // Caption has a plain "Hello" then a bold "World"; split at 5 → tail paragraph retains bold.
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "k",
                              naturalSize: Size2D(width: 60, height: 40),
                              caption: [TextRun(text: "Hello"),
                                        TextRun(text: "World", attributes: CharacterAttributes(bold: true))])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Below")]))
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        let imgBox = v.boxes[0] as! MediaBlockBox
        caret(v, imgBox.textStart + 5)                      // between "Hello" and "World"
        v.insertText("\n")

        XCTAssertEqual(v.boxes.count, 3, "a new paragraph is inserted after the image")
        guard let newPara = v.boxes[1] as? BlockBox else { return XCTFail("box 1 must be a BlockBox") }
        XCTAssertEqual(newPara.currentParagraph().runs.map(\.text).joined(), "World",
                       "tail text is correct")
        XCTAssertTrue(newPara.currentParagraph().runs.contains(where: { $0.attributes.bold }),
                      "bold formatting is preserved in the tail")
    }
}
#endif
