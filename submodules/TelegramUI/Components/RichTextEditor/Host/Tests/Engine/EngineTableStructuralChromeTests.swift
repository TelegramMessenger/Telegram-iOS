import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-tables rung B — the structural chrome VIEW.
///
/// It cannot be the existing `TableChromeView`: that one is grid-sized, sits BEHIND the cells and is
/// non-interactive, while the grips sit outside the grid and the outline must sit above the text.
@available(iOS 18.4, *)
final class EngineTableStructuralChromeTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private func table(_ id: String = "t") -> Block {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID(id)
        for r in 0..<2 {
            for c in 0..<2 {
                built.rows[r].cells[c].blocks = [para("\(id)-\(r)\(c)", "x")]
            }
        }
        return .table(built)
    }

    private func chromeView() -> TableStructuralChromeView? {
        window.layoutIfNeeded()
        return editor.tableStructuralChromeViews[BlockID("t")]
    }

    func test_aTableTheCaretIsInGetsStructuralChrome() {
        editor.document = Document(blocks: [table()])
        XCTAssertNotNil(chromeView())
    }

    func test_aTableTheCaretIsNotInGetsNone() {
        editor.document = Document(blocks: [table(), para("p", "after")])
        guard let after = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("p") }) else {
            return XCTFail("no paragraph role")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        XCTAssertNil(chromeView())
    }

    func test_theCaretLeavingTearsTheChromeDown() {
        editor.document = Document(blocks: [table(), para("p", "after")])
        // A document set parks the caret at the document's END — the paragraph — so put it in the
        // table first, which is what makes this a test of the chrome being torn DOWN.
        guard let cell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }),
              let after = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("p") }) else {
            return XCTFail("no roles")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: cell), length: 0)
        XCTAssertNotNil(chromeView(), "precondition: the caret is in the table")
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        XCTAssertNil(chromeView())
    }

    /// The outline draws OVER the text, so the view must be above the placed run that holds the cells.
    func test_theChromeSitsAboveTheTablesCells() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let chromeIndex = editor.engine.subviews.firstIndex(of: chrome) else {
            return XCTFail("chrome is not an engine subview")
        }
        let runIndex = editor.engine.subviews.firstIndex { $0 is UIScrollView }
        if let runIndex {
            XCTAssertGreaterThan(chromeIndex, runIndex, "the chrome draws above the cells")
        }
    }

    /// The chrome view IS the table's clip window: the same window the engine clips the cells to, so
    /// a grip and a cell stop being visible at the same x. At the top level that window is the whole
    /// canvas — the table sits a text inset into it, and its grips live in that inset.
    func test_theChromeIsTheTablesClipWindow() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView(),
              let index = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID("t") }),
              let tableFrame = editor.tableFrame(forTableAt: index),
              let clip = editor.tableClipX(forTableAt: index) else { return XCTFail("no frames") }
        let knobOverhang = EngineTableStructuralChrome.knobOverhang
        XCTAssertEqual(clip.min, 0, accuracy: 0.5, "the canvas' own left edge")
        XCTAssertEqual(clip.max, editor.engine.bounds.width, accuracy: 0.5, "and its right")
        XCTAssertEqual(chrome.frame.minX, clip.min, accuracy: 0.5)
        XCTAssertEqual(chrome.frame.maxX, clip.max, accuracy: 0.5)
        XCTAssertEqual(chrome.currentTableOrigin.x, tableFrame.minX - clip.min, accuracy: 0.5,
                       "and the table sits where the window puts it")
        XCTAssertEqual(chrome.frame.minY, tableFrame.minY - knobOverhang, accuracy: 0.5)
        XCTAssertEqual(chrome.frame.height,
                       knobOverhang + tableFrame.height + EngineTableStructuralChrome.gripHeight, accuracy: 0.5)
    }

    /// And the engine clips the CELLS to that same window, from the same rule.
    func test_theEngineClipsTheCellsToTheSameWindow() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        guard let index = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID("t") }),
              let clip = editor.tableClipX(forTableAt: index),
              let run = editor.engine.id_placedRunContentViewForBlock(at: UInt(index))?.superview
        else { return XCTFail("no run") }
        let inEngine = run.convert(run.bounds, to: editor.engine)
        XCTAssertEqual(inEngine.minX, clip.min, accuracy: 0.5)
        XCTAssertEqual(inEngine.maxX, clip.max, accuracy: 0.5)
    }

    func test_theChromeShowsAnOutlineAndThreeGrips() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        chrome.layoutIfNeeded()
        XCTAssertNotNil(chrome.drawnOutlineRect)
        XCTAssertEqual(chrome.drawnHandleRects.count, 3, "a row grip in each gutter, and the column's")
        XCTAssertEqual(chrome.drawnKnobRects.count, 4, "the focus chrome's four corner knobs")
    }

    /// A pool without a row in `EngineDerivedViewExpectation` is a pool the completeness check
    /// silently stops checking.
    func test_theCompletenessCheckKnowsAboutTheStructuralChrome() {
        editor.document = Document(blocks: [table()])
        editor.selectTableRows(0...0)
        window.layoutIfNeeded()
        XCTAssertEqual(EngineDerivedViewExpectation(roles: editor.currentRoles).structuralChrome.isEmpty,
                       false, "a table in the roles expects a structural chrome view")
    }

    // MARK: Tapping a grip

    /// The grip rects the view actually shows, in its own space — the same rects the tap resolves
    /// against, so the test cannot pass on geometry the user never sees.
    private func drawnGrips(_ chrome: TableStructuralChromeView) -> [CGRect] {
        chrome.drawnHandleRects
    }

    func test_tappingTheRowGripSelectsThatRow() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        // The row grip is the one to the LEFT of the table's own origin.
        guard let grip = drawnGrips(chrome).first(where: { $0.minX < chrome.currentTableOrigin.x })
        else { return XCTFail("no row grip") }
        editor.handleTableStructuralTap(atPointInChrome: CGPoint(x: grip.midX, y: grip.midY))
        XCTAssertNotNil(editor.structuralRowRange())
    }

    func test_tappingTheColumnGripSelectsThatColumn() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let grip = columnGrip(of: chrome) else { return XCTFail("no column grip") }
        editor.handleTableStructuralTap(atPointInChrome: CGPoint(x: grip.midX, y: grip.midY))
        XCTAssertNotNil(editor.structuralColumnRange())
    }

    /// The mirrored grip in the RIGHT gutter selects the same rows as the one on the left.
    func test_tappingTheTrailingRowGripSelectsThatRow() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView(), let grid = editor.tableGrids[BlockID("t")] else {
            return XCTFail("no chrome")
        }
        guard let grip = drawnGrips(chrome).first(where: {
            $0.width <= EngineTableStructuralChrome.gripWidth + 0.5
                && $0.minX > chrome.currentTableOrigin.x + grid.size.width / 2
        }) else { return XCTFail("no trailing row grip") }
        editor.handleTableStructuralTap(atPointInChrome: CGPoint(x: grip.midX, y: grip.midY))
        XCTAssertNotNil(editor.structuralRowRange())
    }

    func test_tappingElsewhereSelectsNothing() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        _ = drawnGrips(chrome)
        editor.handleTableStructuralTap(atPointInChrome: CGPoint(x: chrome.bounds.midX, y: chrome.bounds.midY))
        XCTAssertNil(editor.structuralRowRange())
        XCTAssertNil(editor.structuralColumnRange())
    }

    /// The tap is the grip's, so the engine must not also place a caret under it — and the refusal is
    /// measured against the grip's OWN box, not an inflated target. R7-details records the cost of the
    /// other choice: 12pt of slop on the details chevron reached past the title's first glyph, so
    /// tapping the first character folded the block instead of placing a caret.
    func test_theEngineRefusesTextInteractionOverAGripAndNotBesideIt() {
        editor.document = Document(blocks: [table()])
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let grip = drawnGrips(chrome).first(where: { $0.minX < chrome.currentTableOrigin.x })
        else { return XCTFail("no row grip") }
        let inside = chrome.convert(CGPoint(x: grip.midX, y: grip.midY), to: editor.engine)
        XCTAssertFalse(editor.textInteractionMayBegin(at: inside))
        let outside = chrome.convert(CGPoint(x: grip.maxX + 8, y: grip.midY), to: editor.engine)
        XCTAssertTrue(editor.textInteractionMayBegin(at: outside),
                      "one point past the grip's own box, interaction is the text's again")
    }

    // MARK: The body is not the chrome's

    /// The centre of the cell diagonally opposite the focused one: table body, clear of every knob.
    private func bodyPoint(in chrome: TableStructuralChromeView) -> CGPoint {
        guard let grid = editor.tableGrids[BlockID("t")],
              let cell = grid.cells.first(where: { $0.row == 1 && $0.column == 1 }) else { return .zero }
        let placed = chrome.viewRect(cell.rect)
        return CGPoint(x: placed.midX, y: placed.midY)
    }

    private func rowGrip(of chrome: TableStructuralChromeView) -> CGRect? {
        drawnGrips(chrome).first { $0.width <= EngineTableStructuralChrome.gripWidth + 0.5 }
    }
    private func columnGrip(of chrome: TableStructuralChromeView) -> CGRect? {
        drawnGrips(chrome).first { $0.height <= EngineTableStructuralChrome.gripHeight + 0.5 }
    }

    /// A document set parks the caret in the LAST cell; these tests want the FIRST focused, so the
    /// body point (the opposite cell's centre) is clear of the focused cell's own knob boxes.
    private func focusFirstCell() {
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 0), length: 0)
    }

    /// The view spans the whole table so its grips can hang outside the grid, but over the BODY it
    /// must not exist for touches: the run's horizontal pan is hosted by the stack canvas beneath —
    /// which this view is not inside — and the engine's text tap is cancelled by this view's own.
    /// Measured on K3 (2026-09-10): with the caret in a wide table, a swipe scrolled nothing and a tap
    /// on another cell moved no caret.
    func test_theChromeClaimsOnlyItsGrips() {
        editor.document = Document(blocks: [table()])
        focusFirstCell()
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let grip = rowGrip(of: chrome), let knob = chrome.drawnKnobRects.first else {
            return XCTFail("no controls drawn")
        }
        XCTAssertTrue(chrome.point(inside: CGPoint(x: grip.midX, y: grip.midY), with: nil))
        // A KNOB CLAIMS NO TOUCH. Its box is 44pt — a drag target, and far too big for a tap: over an
        // 87x34 focused cell the four knob boxes covered 77% of it, and while they were hit-testable
        // every touch there died on a view with only a pan attached, so neither a caret nor the edit
        // menu could be placed. The drag is the editor's `tableKnobPan` now, which competes for the
        // gesture without owning the touch.
        XCTAssertFalse(chrome.point(inside: CGPoint(x: knob.midX, y: knob.midY), with: nil))
        XCTAssertFalse(chrome.point(inside: bodyPoint(in: chrome), with: nil))
    }

    func test_aTouchOnACellReachesTheEngineNotTheChrome() {
        editor.document = Document(blocks: [table()])
        focusFirstCell()
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        let hit = window.hitTest(chrome.convert(bodyPoint(in: chrome), to: window), with: nil)
        XCTAssertNotNil(hit)
        XCTAssertFalse(hit === chrome, "the body is the engine's, not the chrome's")
        XCTAssertTrue(hit?.isDescendant(of: editor.engine) == true)
    }

    /// The column grip and the knob on the cell's RIGHT edge: both inside the engine's bounds. The
    /// row grip hangs into the page margin, which this harness's editor does not have, so a window
    /// hit-test cannot reach it here — `test_theChromeClaimsOnlyItsControls` covers it directly.
    func test_aGripTakesItsTouchAndAKnobLeavesItToTheText() {
        editor.document = Document(blocks: [table()])
        focusFirstCell()
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let grip = columnGrip(of: chrome), chrome.drawnKnobRects.count > 1 else {
            return XCTFail("no controls drawn")
        }
        let knob = chrome.drawnKnobRects[1]
        // A GRIP takes the touch, which is the point of it being a view: it is a tap target.
        let gripHit = window.hitTest(chrome.convert(CGPoint(x: grip.midX, y: grip.midY), to: window), with: nil)
        XCTAssertTrue(gripHit is TableStructuralControlView, "grip hit \(String(describing: gripHit))")
        XCTAssertTrue(gripHit?.superview === chrome)
        // A KNOB does not: the touch goes to the ENGINE, so the tap under a 44pt drag target still
        // places a caret and opens the edit menu. Its drag is the editor's pan.
        let knobHit = window.hitTest(chrome.convert(CGPoint(x: knob.midX, y: knob.midY), to: window), with: nil)
        XCTAssertFalse(knobHit is TableStructuralControlView, "knob hit \(String(describing: knobHit))")
        XCTAssertTrue(knobHit?.isDescendant(of: editor.engine) == true,
                      "a touch over a knob belongs to the text under it")
    }

    // MARK: The document's scroll yields to a knob drag

    /// A knob drag is vertical as often as not, and the engine — a scroll view whose content fits —
    /// still begins its own pan on any vertical movement, cancelling the knob's under it. On K3
    /// (2026-09-10) a horizontal knob drag extended the selection and a vertical one did nothing.
    /// Legacy's `GripYieldingScrollView` is the same yield: the scroll pan declines a touch on a knob,
    /// and only a knob — a grip is a tap target, and a drag from it is still the document's scroll.
    func test_theScrollPanYieldsOverAKnobAndNotOverAGripOrTheBody() {
        editor.document = Document(blocks: [table()])
        focusFirstCell()
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let mayScroll = editor.engine.tgid_shouldBeginScrollPanHandler else { return XCTFail("no hook") }
        guard let grip = rowGrip(of: chrome), let knob = chrome.drawnKnobRects.first else {
            return XCTFail("no controls drawn")
        }
        XCTAssertFalse(mayScroll(chrome.convert(CGPoint(x: knob.midX, y: knob.midY), to: editor.engine)))
        XCTAssertTrue(mayScroll(chrome.convert(CGPoint(x: grip.midX, y: grip.midY), to: editor.engine)))
        XCTAssertTrue(mayScroll(chrome.convert(bodyPoint(in: chrome), to: editor.engine)))
    }

    // MARK: Knobs on the table's outer borders

    /// A knob sits ON the outline, and the outline sits on the table's outer border, so a knob on the
    /// top or right edge hangs outside the grid. The view must hold the whole circle: `draw` cannot
    /// paint outside its own bounds, and on K3 (2026-09-11) the knobs on the top and right borders
    /// were cut in half. The 2×2 table fills the editor's width, so its right border is the run's edge.
    func test_everyKnobIsDrawnWholeInsideTheChrome() {
        editor.document = Document(blocks: [table()])
        // The top-right cell: its top knob is on the table's top border, its right knob on the right.
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 1), length: 0)
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        _ = drawnGrips(chrome)
        XCTAssertEqual(chrome.drawnKnobRects.count, 4)
        let radius = EngineTableStructuralChrome.knobRadius
        for knob in chrome.drawnKnobRects {
            let circle = CGRect(x: knob.midX - radius, y: knob.midY - radius, width: radius * 2, height: radius * 2)
            XCTAssertTrue(chrome.bounds.contains(circle), "knob at \(knob) is cut by the view's bounds \(chrome.bounds)")
        }
    }

    // MARK: A knob keeps its drag and gives up the tap

    /// The knobs' 44pt boxes — legacy's size — reach 22pt into the neighbouring cells, and on a row
    /// ~43pt tall that is the CENTRE of the cell above and below the focused one. A tap there hit a
    /// knob and placed nothing, which read as "it is very difficult to place a cursor in a cell" (K3,
    /// 2026-09-11). A tap is never a knob's: only a drag is. The engine's text tap is allowed over a
    /// knob, the chrome's own tap recogniser declines the touch so it cannot cancel the text tap, and
    /// the chrome's pan takes only touches that begin on a knob.
    func test_aTapOverAKnobIsTheTextsAndADragIsTheChromes() {
        editor.document = Document(blocks: [table()])
        focusFirstCell()
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        guard let grip = rowGrip(of: chrome), chrome.drawnKnobRects.count > 1 else { return XCTFail("no controls") }
        let knob = chrome.drawnKnobRects[1]
        let knobPoint = CGPoint(x: knob.midX, y: knob.midY)
        let gripPoint = CGPoint(x: grip.midX, y: grip.midY)
        let knobInEngine = chrome.convert(knobPoint, to: editor.engine)
        XCTAssertTrue(editor.textInteractionMayBegin(at: knobInEngine, isTap: true), "a tap on a knob places the caret")
        XCTAssertFalse(editor.textInteractionMayBegin(at: knobInEngine, isTap: false), "a drag on a knob is the knob's")
        XCTAssertFalse(editor.textInteractionMayBegin(at: chrome.convert(gripPoint, to: editor.engine), isTap: true),
                       "a grip is a tap target of its own")
        // The split is now what each control CARRIES, not a delegate deciding per touch: a grip has a
        // tap and no pan, a knob a pan and no tap. So a tap over a knob is never received by the
        // chrome at all, and cannot cancel the text's.
        // The split is what each control CARRIES — and a knob carries NOTHING, because a view that
        // owns the touch owns the tap with it. This test used to assert the veto above AND that the
        // knob took its own touches; the two cannot both hold, since the veto is only consulted for
        // a touch the text view actually receives. The veto said "a tap on a knob places the caret"
        // while the knob's view quietly swallowed it — passing test, broken behaviour, 77% of a
        // focused cell dead (K3: "almost impossible to invoke the context menu by tapping in a cell").
        let controls = chrome.controlViews.filter { !$0.isHidden }
        XCTAssertFalse(controls.isEmpty)
        for control in controls {
            let recognizers = control.gestureRecognizers ?? []
            switch control.payload {
            case .grip:
                XCTAssertEqual(recognizers.count, 1)
                XCTAssertTrue(recognizers.first is UITapGestureRecognizer, "a grip is a tap target")
            case .knob:
                XCTAssertTrue(recognizers.isEmpty, "a knob carries no recogniser: the drag is the editor's")
                XCTAssertFalse(control.isUserInteractionEnabled, "a knob is drawing only")
            }
        }
        XCTAssertNil(chrome.gestureRecognizers?.first, "the container itself is not a control")
        XCTAssertFalse(chrome.hitTest(knobPoint, with: nil)?.superview === chrome,
                       "a knob leaves the touch to the text under it")
        // The drag did not disappear with the recogniser: it moved up to the editor.
        XCTAssertTrue(editor.gestureRecognizers?.contains(editor.tableKnobPan) == true,
                      "the knob's drag is a pan on the editor")
        XCTAssertEqual(chrome.hitTest(gripPoint, with: nil)?.superview, chrome, "a grip takes its own touches")
    }
    // MARK: The grips' look

    private struct Bitmap {
        let width: Int, height: Int, bytes: [UInt8]
        func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * width + x) * 4 + 3] }
        func isAccent(_ x: Int, _ y: Int) -> Bool {
            let index = (y * width + x) * 4
            return bytes[index] > 200 && bytes[index + 1] < 80 && bytes[index + 2] < 80
        }
    }

    /// The control's LAYER TREE rendered into a buffer this can read back. The look is a view tree
    /// now — a bar layer with two rounded corners and three dot layers — so rendering the tree is
    /// what asks the same question `draw(_:)` used to be asked: what does this control show.
    private func render(_ control: TableStructuralControlView) -> Bitmap {
        let width = Int(control.bounds.width.rounded()), height = Int(control.bounds.height.rounded())
        let count = width * height * 4
        let raw = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 8)
        defer { raw.deallocate() }
        memset(raw, 0, count)
        guard let context = CGContext(data: raw, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Bitmap(width: 0, height: 0, bytes: [])
        }
        control.setNeedsLayout()
        control.layoutIfNeeded()
        control.layer.render(in: context)
        let bytes = Array(UnsafeBufferPointer(start: raw.assumingMemoryBound(to: UInt8.self), count: count))
        return Bitmap(width: width, height: height, bytes: bytes)
    }

    /// Runs of opaque pixels down the middle of a row grip: one per dot.
    private func dotRuns(_ bitmap: Bitmap, accented: Bool) -> Int {
        let x = bitmap.width / 2
        var runs = 0, inside = false
        for y in 0..<bitmap.height {
            let on = bitmap.alpha(x, y) > 128 && (accented ? !bitmap.isAccent(x, y) : true)
            if on && !inside { runs += 1 }
            inside = on
        }
        return runs
    }

    private func rowGrip(active: Bool) -> TableStructuralControlView {
        let control = TableStructuralControlView(payload: .grip(.rows(0...0), active: active, side: .leading))
        control.frame = CGRect(x: 0, y: 0, width: EngineTableStructuralChrome.gripWidth, height: 60)
        control.update(payload: .grip(.rows(0...0), active: active, side: .leading), accent: .red)
        return control
    }

    /// Legacy's `drawHandleDots`: a grip is THREE DOTS, and nothing else, until its row or column is
    /// the structural selection. The engine editor drew a filled accent capsule in both states.
    func test_anIdleGripIsThreeDotsAndNoBar() {
        let bitmap = render(rowGrip(active: false))
        XCTAssertEqual(dotRuns(bitmap, accented: false), 3, "a row grip is a vertical ⋮")
        for y in 0..<bitmap.height where (0..<bitmap.width).contains(where: { bitmap.isAccent($0, y) }) {
            return XCTFail("an idle grip drew the accent at row \(y)")
        }
    }

    /// Selected, the dots sit on an accent bar and invert — and the bar rounds only the two corners
    /// AWAY from the table, so it reads as a half-capsule hanging out of the grid.
    func test_aSelectedGripIsThreeInvertedDotsOnAHalfCapsuleBar() {
        let bitmap = render(rowGrip(active: true))
        XCTAssertEqual(dotRuns(bitmap, accented: true), 3, "the dots are drawn over the bar")
        XCTAssertTrue(bitmap.isAccent(bitmap.width - 2, bitmap.height / 2), "no bar under the dots")
        // The row grip's LEFT corners are round, its right ones square against the table's border.
        // Read from the layer, not the buffer: `render(in:)` ignores `maskedCorners`.
        let grip = rowGrip(active: true)
        grip.layoutIfNeeded()
        XCTAssertEqual(grip.shownBarCorners, [.layerMinXMinYCorner, .layerMinXMaxYCorner])
        XCTAssertNil(rowGrip(active: false).shownBarCorners, "an idle grip has no bar at all")
    }

    /// The state the look turns on is the chrome's own selection, so a grip cannot be drawn selected
    /// while its row is not — the two used to be independent, and every grip drew as selected.
    func test_onlyTheSelectedRowsGripIsDrawnSelected() {
        editor.document = Document(blocks: [table()])
        focusFirstCell()
        guard let chrome = chromeView() else { return XCTFail("no chrome") }
        for control in chrome.controlViews {
            if case let .grip(_, active, _) = control.payload {
                XCTAssertFalse(active, "nothing is selected yet")
            }
        }
        editor.selectTableRows(0...0)
        window.layoutIfNeeded()
        var rows = 0, columns = 0
        for control in chrome.controlViews {
            guard case let .grip(kind, active, _) = control.payload else { continue }
            if case .rows = kind { rows += 1; XCTAssertTrue(active, "the selected row's grip") }
            if case .columns = kind { columns += 1; XCTAssertFalse(active, "the column grip is not") }
        }
        XCTAssertEqual(rows, 2, "one in each gutter")
        XCTAssertEqual(columns, 1)
    }
}
