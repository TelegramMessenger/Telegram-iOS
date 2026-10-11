import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The hosted media view: positioned over the atom's attachment frame, widened by the bleed, pooled
/// by block id and re-provided on an items change, culled off-screen, tinted when the atom is
/// selected, and claiming the poster's taps.
@available(iOS 18.4, *)
final class EngineMediaLayoutTests: XCTestCase {
    final class StubMediaView: UIView, RichTextMediaItemView {
        var sizes: [CGSize] = []
        func update(size: CGSize) { sizes.append(size) }
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }

    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    private var provided: [(ids: [String], mode: MediaDisplayMode, existing: RichTextMediaItemView?)] = []
    private var reuseExisting = false

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        editor.registerMediaViewProvider { [weak self] items, _, mode, existing in
            guard let self else { return nil }
            self.provided.append((items.map(\.mediaID), mode, existing))
            if self.reuseExisting, let existing { return existing }
            return StubMediaView()
        }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; provided = []; super.tearDown() }

    private func item(_ id: String, kind: MediaKind = .image, w: Double = 1000, h: Double = 500, spoiler: Bool = false) -> MediaItem {
        MediaItem(mediaID: id, kind: kind, naturalSize: Size2D(width: w, height: h), isSpoiler: spoiler)
    }
    private func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)])) }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); editor.setNeedsLayout(); editor.layoutIfNeeded() }
    private func host(_ id: String) -> MediaAtomHostView? { editor.mediaAtomViews[BlockID(id)] }

    func test_theViewSitsOnTheAttachmentFrameAndIsUpdatedWithItsSize() {
        load([para("p0", "before"), .media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        let frame = editor.engine.id_attachmentFrame(forCanonicalOffset: 7)
        guard let host = host("a") else { return XCTFail("no hosted view") }
        XCTAssertTrue(host.superview === editor.engine, "parented into the engine's content, like emoji")
        XCTAssertEqual(host.frame, frame)
        XCTAssertEqual((host.hosted as? StubMediaView)?.sizes.last, frame.size)
        XCTAssertEqual(provided.count, 1)
        XCTAssertEqual(provided[0].ids, ["x"])
    }

    func test_theBleedWidensTheViewButNotTheAttachment() {
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 16)
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        let frame = editor.engine.id_attachmentFrame(forCanonicalOffset: 0)
        XCTAssertEqual(host("a")?.frame, frame.insetBy(dx: -16, dy: 0))
    }

    func test_aNarrowImageIsNotWidened() {
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 16)
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")], displayWidth: 120))])
        XCTAssertEqual(host("a")?.frame, editor.engine.id_attachmentFrame(forCanonicalOffset: 0))
        XCTAssertEqual(host("a")?.frame.width ?? 0, 120, accuracy: 0.5)
    }

    func test_anItemsChangeReProvidesWithTheExistingViewAndReusesItWhenReturned() {
        reuseExisting = true
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        let first = host("a")?.hosted
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x"), item("y")]))])
        XCTAssertEqual(provided.count, 2)
        XCTAssertTrue(provided[1].existing === first, "the existing view is handed back so cells can be reused in place")
        XCTAssertTrue(host("a")?.hosted === first)
    }

    func test_aSpoilerToggleReProvides() {
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x", spoiler: true)]))])
        XCTAssertEqual(provided.count, 2, "the spoiler flag is in the signature")
    }

    func test_anUnrelatedEditKeepsThePooledView() {
        load([para("p0", "before"), .media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        let view = host("a")?.hosted
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.insertText("!")
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertTrue(host("a")?.hosted === view)
        XCTAssertEqual(provided.count, 1)
    }

    func test_aRemovedMediaLosesItsView() {
        load([para("p0", "before"), .media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        XCTAssertNotNil(host("a"))
        load([para("p0", "before")])
        XCTAssertNil(host("a"))
        XCTAssertFalse(editor.engine.subviews.contains { $0 is MediaAtomHostView })
    }

    func test_aViewFarOffScreenIsHidden() {
        var blocks: [Block] = []
        for index in 0..<30 { blocks.append(para("p\(index)", "line \(index)")) }
        blocks.append(.media(MediaBlock(id: BlockID("a"), items: [item("x")])))
        load(blocks)
        XCTAssertEqual(host("a")?.isHidden, true, "more than 50pt below the visible rect")
        editor.engine.contentOffset = CGPoint(x: 0, y: editor.engine.contentSize.height - editor.engine.bounds.height)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(host("a")?.isHidden, false)
    }

    /// Spec §10: the "Add caption" prompt over an EMPTY caption line. A placeholder is a view, not
    /// content — the line itself is empty — so the only way to see the field at all is to find the
    /// label and check it sits on the line's own block frame.
    func test_anEmptyCaptionShowsThePromptOverItsLine() {
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")], caption: []))])
        let labels = editor.engine.subviews.compactMap { $0 as? SecondaryPlaceholderLabel }
        guard let prompt = labels.first(where: { $0.text == mediaCaptionPlaceholderText }) else {
            return XCTFail("no caption prompt among \(labels.map { $0.text ?? "nil" })")
        }
        let line = editor.engine.id_frameForBlock(at: 1)
        XCTAssertFalse(line.isNull)
        XCTAssertTrue(line.minY <= prompt.frame.midY && prompt.frame.midY <= line.maxY,
                      "the prompt sits on the caption's line: \(prompt.frame) vs \(line)")
    }

    func test_theWashFollowsTheSelection() {
        load([para("p0", "before"), .media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        XCTAssertEqual(atomIsWashed("a"), false)
        editor.engineSelectedRange = NSRange(location: 7, length: 1)   // the atom's character
        XCTAssertEqual(atomIsWashed("a"), true)
        editor.engineSelectedRange = NSRange(location: 0, length: 9)   // a drag across it
        XCTAssertEqual(atomIsWashed("a"), true)
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // a caret after it
        XCTAssertEqual(atomIsWashed("a"), false)
    }

    func test_aPosterTapSelectsTheAtom() {
        load([para("p0", "before"), .media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        host("a")?.onPosterTapped?()
        XCTAssertTrue(editor.engine.isFirstResponder)
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 1))
        XCTAssertEqual(atomIsWashed("a"), true)
    }

    func test_theHostClaimsThePosterAndForwardsToAControl() {
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        guard let host = host("a") else { return XCTFail() }
        let control = UIButton(frame: CGRect(x: 4, y: 4, width: 30, height: 30))
        host.hosted.addSubview(control)
        XCTAssertTrue(host.hitTest(CGPoint(x: 10, y: 10), with: nil) === control, "a control inside the provided view wins")
        XCTAssertTrue(host.hitTest(CGPoint(x: 100, y: 100), with: nil) === host, "the poster is the host's — a tap there selects the atom")
    }

    func test_theEnginesInteractionIsRefusedOverAMediaHost() {
        load([para("p0", "before"), .media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        guard let host = host("a") else { return XCTFail() }
        XCTAssertFalse(editor.textInteractionMayBegin(at: CGPoint(x: host.frame.midX, y: host.frame.midY)))
        XCTAssertTrue(editor.textInteractionMayBegin(at: CGPoint(x: 5, y: 5)))
        XCTAssertNotNil(editor.engine.tgid_shouldBeginTextInteractionHandler, "installed on the host view")
    }

    func test_theOverrideConsultsTheHandlerForATapButNeverForTheScrollPan() {
        load([.media(MediaBlock(id: BlockID("a"), items: [item("x")]))])
        var consulted = 0
        editor.engine.tgid_shouldBeginTextInteractionHandler = { _, _ in consulted += 1; return false }
        XCTAssertFalse(editor.engine.gestureRecognizerShouldBegin(UITapGestureRecognizer()), "a text-interaction recognizer is refused when the handler says so")
        XCTAssertEqual(consulted, 1)
        XCTAssertTrue(editor.engine.gestureRecognizerShouldBegin(editor.engine.panGestureRecognizer), "the scroll view's own pan is never vetoed")
        XCTAssertEqual(consulted, 1, "and the handler was not even consulted for it")
        // Restore the editor's own handler so the rest of the class is unaffected.
        editor.engine.tgid_shouldBeginTextInteractionHandler = { [weak editor] point, _ in editor?.textInteractionMayBegin(at: point) ?? true }
    }

    /// Whether a selection currently covers the atom's hosted view — what `isSelectedAtom` used to
    /// stand for, asked of the rects UIKit actually paints. A stronger claim than the flag was: it
    /// is about what reaches the screen rather than about a bit the wrapper kept.
    private func atomIsWashed(_ id: String) -> Bool {
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let host = host(id), let range = editor.engine.selectedTextRange else { return false }
        return editor.engine.selectionRects(for: range)
            .contains { $0.rect.insetBy(dx: 1, dy: 1).intersects(host.frame) }
    }
}
