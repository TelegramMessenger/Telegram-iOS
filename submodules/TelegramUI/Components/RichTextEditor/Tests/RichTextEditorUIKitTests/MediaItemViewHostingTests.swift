#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 17.0, *)
final class MediaItemViewHostingTests: XCTestCase {
    final class StubMediaView: UIView, RichTextMediaItemView {
        let mediaID: String
        var updatedSizes: [CGSize] = []
        init(mediaID: String) { self.mediaID = mediaID; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        func update(size: CGSize) { updatedSizes.append(size) }
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }

    /// Honors the media-view interaction contract (what the real `MediaItemNodeView` does): its `hitTest`
    /// returns the interactive control (`control`, standing in for the more button) ONLY when the touch
    /// lands on it, and nil (pass-through) everywhere else on the poster.
    final class ControlStubMediaView: UIView, RichTextMediaItemView {
        let control = UIView()
        init() {
            super.init(frame: .zero)
            control.frame = CGRect(x: 8, y: 8, width: 30, height: 30)
            addSubview(control)
        }
        required init?(coder: NSCoder) { fatalError() }
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return control.frame.contains(point) ? control : nil
        }
    }

    private func emptyDoc(_ blocks: [Block]) -> Document {
        Document(blocks: blocks)
    }

    func testProviderInvokedOncePerOccurrenceAndViewSized() {
        let editor = RichTextEditorView()
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        var requested: [String] = []
        editor.registerMediaViewProvider { items, _, _, _ in
            let mediaID = items.first?.mediaID ?? ""
            requested.append(mediaID)
            return StubMediaView(mediaID: mediaID)
        }
        editor.document = emptyDoc([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x")]))])
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.insertMedia(mediaID: "m1", naturalSize: CGSize(width: 200, height: 100), kind: .image)
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()

        XCTAssertEqual(requested, ["m1"], "provider invoked exactly once for the one media block")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 1)
        let view = editor.hostedMediaViewForTesting(forFirstMediaBlock: editor.document)
        XCTAssertNotNil(view as? StubMediaView)
        XCTAssertFalse((view as! StubMediaView).updatedSizes.isEmpty, "view.update(size:) was called during layout")
    }

    // A document set while the editor is still UNFRAMED (bounds == .zero) — the draft-restore / attachment-init
    // "content applied before layout" case — must NOT trigger a zero-width layout pass. A zero-width layout builds
    // the hosted media view at a 0×0 rect (and binds its fetch) only to redo it the instant the real frame lands.
    // The model is applied immediately (readable via the getter); the host's next framed `update(...)` lays it out.
    // Regression guard for the `document` setter gating its `performLayout` on `bounds.width > 0` (matching every
    // other setter in `RichTextEditorView`).
    func testZeroBoundsDocumentSetDefersMediaViewCreationUntilFramed() {
        let editor = RichTextEditorView()
        var requested: [String] = []
        editor.registerMediaViewProvider { items, _, _, _ in
            let mediaID = items.first?.mediaID ?? ""
            requested.append(mediaID); return StubMediaView(mediaID: mediaID)
        }
        // Phase 1: set a media document while UNFRAMED (bounds == .zero).
        editor.document = emptyDoc([
            .media(MediaBlock(id: BlockID("m0"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 200, height: 100)))
        ])
        XCTAssertTrue(requested.isEmpty, "no media view created while unframed (bounds == .zero)")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 0)
        XCTAssertEqual(editor.document.blocks.count, 1, "the model is applied even while unframed")

        // Phase 2: framing lays it out and creates the hosted media view.
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()
        XCTAssertEqual(requested, ["m1"], "media view created on the first framed layout")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 1)
    }

    // A UIKit layout pass (`layoutSubviews`) while the editor is still UNFRAMED must ALSO not build media
    // views — both `RichTextEditorView.layoutSubviews` (→ performLayout) and `DocumentCanvasView.layoutSubviews`
    // (→ layoutContent) gate on `bounds.width > 0`. Without those gates a stray zero-bounds layout pass (before
    // the host frames the view) creates the hosted media view at a 0×0 rect and binds its fetch. Complements the
    // document-setter gate above — this covers the layout-pass entry points.
    func testZeroBoundsLayoutPassDoesNotCreateMediaViews() {
        let editor = RichTextEditorView()
        var requested: [String] = []
        editor.registerMediaViewProvider { items, _, _, _ in
            let mediaID = items.first?.mediaID ?? ""
            requested.append(mediaID); return StubMediaView(mediaID: mediaID)
        }
        editor.document = emptyDoc([
            .media(MediaBlock(id: BlockID("m0"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 200, height: 100)))
        ])
        // Force a UIKit layout pass while unframed (bounds == .zero).
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertTrue(requested.isEmpty, "a zero-bounds layout pass creates no media views")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 0)

        // Framed → the layout pass now builds it.
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertEqual(requested, ["m1"], "media view created once a framed layout pass runs")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 1)
    }

    func testSameMediaIDInTwoBlocksProducesTwoIndependentViews() {
        let editor = RichTextEditorView()
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        var count = 0
        editor.registerMediaViewProvider { items, _, _, _ in
            count += 1; return StubMediaView(mediaID: items.first?.mediaID ?? "")
        }
        editor.document = emptyDoc([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x")]))])
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.insertMedia(mediaID: "dup", naturalSize: CGSize(width: 100, height: 100), kind: .image)
        editor.insertMedia(mediaID: "dup", naturalSize: CGSize(width: 100, height: 100), kind: .image)
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()
        XCTAssertEqual(count, 2, "same mediaID in two blocks -> two independent views")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 2)
    }

    // The `mediaOverlay` routes a touch to a media view's interactive control when the media view claims it
    // (hitTest returns something), and passes through (nil) otherwise so the canvas's own tap handling runs.
    // This is the editor-side half of "if the media view returns anything from hitTest, leave it be; if not,
    // use the default tap logic" — the gesture gate (`gestureRecognizer(_:shouldReceive:)`) consults exactly
    // this seam. The real interactive media view (`MediaItemNodeView` + `RichTextMediaContentComponent`) lives
    // in a Bazel-only module; `ControlStubMediaView` stands in for its hitTest contract here.
    func testMediaOverlayRoutesControlHitTestElsePassesThrough() {
        let editor = RichTextEditorView()
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        var stub: ControlStubMediaView?
        editor.registerMediaViewProvider { _, _, _, _ in let v = ControlStubMediaView(); stub = v; return v }
        editor.document = emptyDoc([
            .media(MediaBlock(id: BlockID("m0"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 200, height: 100)))
        ])
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()

        guard let stub, stub.superview != nil else { return XCTFail("media view was not hosted") }
        let canvas = editor.canvasForTesting

        // A touch on the control resolves to the control (the editor must "leave it be").
        let controlInStub = CGPoint(x: stub.control.frame.midX, y: stub.control.frame.midY)
        let controlCanvasPoint = stub.convert(controlInStub, to: canvas)
        XCTAssertTrue(canvas.mediaControlHitTest(atCanvasPoint: controlCanvasPoint) === stub.control,
                      "a touch on the media control routes to the control")

        // A touch on the poster (inside the media view, away from the control) passes through (nil).
        let posterInStub = CGPoint(x: stub.bounds.midX, y: stub.bounds.maxY - 2)
        let posterCanvasPoint = stub.convert(posterInStub, to: canvas)
        XCTAssertNil(canvas.mediaControlHitTest(atCanvasPoint: posterCanvasPoint),
                     "a touch on the poster area passes through so the editor's default tap logic runs")
    }
}
#endif
