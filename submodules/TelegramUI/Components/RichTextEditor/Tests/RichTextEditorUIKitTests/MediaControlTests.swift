#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MediaControlTests: XCTestCase {
    /// Two media blocks sharing one `mediaID` but distinct `BlockID`s — deleting one occurrence must NOT
    /// touch the other (the mediaID-is-not-unique guard).
    func test_deleteMediaBlock_removesOnlyTheGivenOccurrence() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img1"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .media(MediaBlock(id: BlockID("img2"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "End")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        v.deleteMediaBlock(id: BlockID("img2"))

        let mediaIDs = v.boxes.compactMap { ($0 as? MediaBlockBox)?.id }
        XCTAssertTrue(mediaIDs.contains(BlockID("img1")), "the untouched occurrence survives")
        XCTAssertFalse(mediaIDs.contains(BlockID("img2")), "only the targeted occurrence is removed")
    }
}

extension MediaControlTests {
    private final class StubMediaView: UIView, RichTextMediaItemView {
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }

    /// The editor installs `onControlTapped` on the hosted view; firing it emits a request with the right
    /// control/mediaID, and the request's `delete()` removes that block.
    func test_moreControlTap_emitsRequest_andDeletes() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in StubMediaView() }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "End")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        v.setNeedsLayout(); v.layoutIfNeeded()

        var received: MediaControlRequest?
        v.onRequestMediaControl = { received = $0 }

        let hosted = v.hostedMediaViewForTesting(BlockID("img"))
        XCTAssertNotNil(hosted?.onControlTapped, "editor installed the control-tap hook on the media view")
        let anchor = UIView()
        hosted?.onControlTapped?(.more, nil, anchor, CGRect(x: 0, y: 0, width: 36, height: 36))

        XCTAssertEqual(received?.control, .more)
        XCTAssertEqual(received?.mediaID, "x")
        XCTAssertNil(received?.itemIndex, "a whole-block control (the more menu) carries no itemIndex")
        XCTAssertTrue(received?.view === anchor, "the request anchors on the tapped control's view")

        received?.delete()
        XCTAssertFalse(v.boxes.contains { ($0 as? MediaBlockBox)?.id == BlockID("img") },
                       "the request's delete removes the media block")
    }
}

// MARK: - Task 7: add-more / delete-one editor ops

extension MediaControlTests {
    func test_addMediaItem_growsContainer() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 100, height: 100))),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        v.addMediaItem(blockID: BlockID("b1"), mediaID: "m2",
                       naturalSize: CGSize(width: 50, height: 50), kind: .video)

        guard case let .media(block)? = v.currentBlocks().first else { return XCTFail("expected a media block") }
        XCTAssertEqual(block.items.count, 2)
        XCTAssertEqual(block.items[1].mediaID, "m2")
        XCTAssertEqual(block.items[1].kind, .video)
    }

    func test_deleteMediaItem_collapsesToSingle() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), items: [
                MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
                MediaItem(mediaID: "m2", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
            ])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        v.deleteMediaItem(blockID: BlockID("b1"), itemIndex: 0)

        guard case let .media(block)? = v.currentBlocks().first else { return XCTFail("expected a media block") }
        XCTAssertEqual(block.items.map(\.mediaID), ["m2"])
    }

    func test_deleteMediaItem_lastItemRemovesBlock() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 100, height: 100))),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        v.deleteMediaItem(blockID: BlockID("b1"), itemIndex: 0)

        // The block collapses via the existing media-delete → empty-paragraph path (no media block remains).
        XCTAssertFalse(v.currentBlocks().contains { if case .media = $0 { return true }; return false })
    }

    /// Adjacent correctness guard (found in Task 5 review): splitting a media caption on Enter must
    /// preserve EVERY item in a multi-item (mosaic) container, not just the first — the split rebuild in
    /// `insertParagraphBreak` (`+Editing.swift`) used to call the legacy single-media `MediaBlock` init,
    /// which silently dropped `items[1...]`.
    func test_enterInCaption_ofMultiItemContainer_preservesAllItems() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), items: [
                MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
                MediaItem(mediaID: "m2", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
            ], caption: [TextRun(text: "Caption")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        guard let mediaBox = v.boxes.first as? MediaBlockBox else { return XCTFail("expected a media box") }
        let midCaption = mediaBox.textStart + 3   // caret inside "Caption"
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(midCaption), DocumentTextPosition(midCaption))
        v.insertText("\n")   // Enter in the caption: split → [media(caption head), body(caption tail)]

        guard case let .media(block)? = v.currentBlocks().first else { return XCTFail("expected a media block to survive the split") }
        XCTAssertEqual(block.items.map(\.mediaID), ["m1", "m2"],
                       "the split must preserve every item in the container, not just the first")
    }
}

// MARK: - Final-review Finding 2: re-render the hosted view when a block's items change

extension MediaControlTests {
    private final class CountingStubMediaView: UIView, RichTextMediaItemView {
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }

    /// `syncMediaItemViews` must recreate (not merely resize) the hosted view when a block's `items`
    /// change — add-more / delete-one — because the reused `MediaItemNodeView` can't be re-fed a changed
    /// item list in place. Drives the REAL canvas: a call-counting provider, a seeded 1-item media block,
    /// forced layout passes (`simulateParentLayout`, matching the file's other canvas-direct tests), then
    /// `addMediaItem`/`deleteMediaItem`. Also asserts an UNCHANGED re-layout does NOT re-invoke the
    /// provider (pure-resize / redundant-layout reuse still holds).
    func test_syncMediaItemViews_recreatesHostedView_onItemsChange_notOnUnchangedRelayout() {
        let v = DocumentCanvasView()
        var provideCount = 0
        v.mediaViewProvider = { _, _, _, _ in provideCount += 1; return CountingStubMediaView() }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 100, height: 100))),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        v.layoutIfNeeded()
        v.simulateParentLayout()   // install AFTER the initial layout, per the helper's contract

        XCTAssertEqual(provideCount, 1, "provider invoked once for the initial 1-item block")

        // A pure re-layout with UNCHANGED items must NOT re-invoke the provider (reuse holds).
        v.setNeedsLayout(); v.layoutIfNeeded()
        XCTAssertEqual(provideCount, 1, "unchanged re-layout reuses the hosted view")
        v.setNeedsLayout(); v.layoutIfNeeded()
        XCTAssertEqual(provideCount, 1, "still reused across a second unchanged re-layout")

        // Add-more grows 1 -> 2 items: the signature changes, so the view is recreated.
        v.addMediaItem(blockID: BlockID("b1"), mediaID: "m2",
                       naturalSize: CGSize(width: 50, height: 50), kind: .video)
        XCTAssertEqual(provideCount, 2, "provider re-invoked after items grow from 1 to 2")
        XCTAssertEqual(v.hostedMediaItemSignatureForTesting(BlockID("b1")), "mosaic|m1#image#100x100#s0|m2#video#50x50#s0")

        // Delete-one shrinks 2 -> 1 item: the signature changes again, so the view is recreated once more.
        v.deleteMediaItem(blockID: BlockID("b1"), itemIndex: 1)
        XCTAssertEqual(provideCount, 3, "provider re-invoked after items shrink from 2 to 1")
        XCTAssertEqual(v.hostedMediaItemSignatureForTesting(BlockID("b1")), "mosaic|m1#image#100x100#s0")
    }
}
#endif
