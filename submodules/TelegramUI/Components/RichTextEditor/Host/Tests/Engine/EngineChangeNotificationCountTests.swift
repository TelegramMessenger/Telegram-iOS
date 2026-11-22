import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// `onChange` fires EXACTLY ONCE per edit — counted over a run-loop window, not waited for.
///
/// The difference matters. The other tests of this contract arm an `XCTestExpectation` and wait for
/// it: `wait(for:)` returns on the FIRST delivery, so a second one arriving a run-loop turn later
/// lands after the test has finished and is never seen. Every case below fired TWICE under exactly
/// those tests passing (measured 2026-09-04): a multi-line insert or paste into a list item, and
/// every paragraph mutator — `setParagraphStyle`, `setList`, `setAlignment`, `indent`, `outdent`.
/// The second delivery came from the caret restore each of them ends with, and from a selection
/// change made while a list-continuation reconciliation was suppressing the edit's own
/// notification. `onChange` is what the composer runs a full layout pass from.
///
/// **The instrument has a trap of its own, and it produced a wrong answer here first.** Seeding the
/// document and the caret is itself a selection change, which schedules a delivery of its own; with
/// the counter installed straight afterwards, that setup delivery is counted against the edit and
/// every mutator reads as 2 whatever the code does. `measure` therefore drains one run-loop turn
/// after the setup and before installing the counter. Both fixes were then confirmed by reverting
/// each in turn and watching the count go back to 2 — an instrument that cannot produce the other
/// answer is not a measurement.
@available(iOS 18.4, *)
final class EngineChangeNotificationCountTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
        XCTAssertTrue(editor.becomeFirstResponder())
    }
    override func tearDown() { editor.onChange = nil; window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
    private func para(_ id: String, _ text: String, list: ListMembership? = nil) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), list: list, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private var bullet: ListMembership { ListMembership(marker: .bullet, level: 1) }

    /// Deliveries during `act`, plus the run-loop turn that follows it — long enough for a delivery
    /// scheduled a turn later to be counted rather than missed.
    private func deliveries(seeding blocks: [Block], caret: Int, _ act: () -> Void) -> Int {
        editor.document = Document(blocks: blocks)
        editor.composerSelectedRange = NSRange(location: caret, length: 0)
        turn()   // drain what the SETUP scheduled, or it is counted against the edit below
        var calls = 0
        editor.onChange = { calls += 1 }
        act()
        turn()
        editor.onChange = nil
        return calls
    }

    /// Like `deliveries(seeding:caret:_:)`, but the caret is set on the ENGINE axis — the composer
    /// axis cannot address a media atom or its caption. Seeded BEFORE the drain, or the caret's own
    /// selection-driven delivery is counted against the edit.
    private func engineDeliveries(seeding blocks: [Block], engineCaret: NSRange, _ act: () -> Void) -> Int {
        editor.document = Document(blocks: blocks)
        editor.engineSelectedRange = engineCaret
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        act()
        turn()
        editor.onChange = nil
        return calls
    }

    // MARK: - Typing and pasting

    func test_aReturnInAPlainParagraphDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "plain")], caret: 5) { editor.insertText("\n") }, 1)
    }

    func test_typingDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "plain")], caret: 5) { editor.insertText("x") }, 1)
    }

    /// One new block: the list-continuation reconciliation's release is the one delivery.
    func test_aReturnInAListItemDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "first", list: bullet)], caret: 5) { editor.insertText("\n") }, 1)
    }

    /// Several new blocks from ONE edit, all empty.
    func test_twoReturnsInAListItemDeliverOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "first", list: bullet)], caret: 5) { editor.insertText("\n\n") }, 1)
    }

    /// Several new blocks WITH text — the case that fired twice, and the one that crashed
    /// `EngineListContinuationTests`' two multi-block cases on a repeat `fulfill`.
    func test_aMultiLineInsertIntoAListItemDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "first", list: bullet)], caret: 5) {
            editor.insertText("\nsecond\nthird")
        }, 1)
    }

    /// Ending a list with Backspace is a role-only change that delivers its own notification. An
    /// extra `deliverChangeNotificationNow()` beside it — which the first cut of that rule had —
    /// fires a second one for the same keystroke.
    func test_backspaceEndingAListDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "item", list: bullet)], caret: 0) {
            editor.engine.deleteBackward()
        }, 1)
    }

    func test_returnEndingAListDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "item", list: bullet), para("p1", "", list: bullet)],
                                  caret: 5) { editor.insertText("\n") }, 1)
    }

    // MARK: - The paragraph mutators

    /// Every one of these ends by putting the caret back, and that restore is part of the mutation:
    /// left to schedule its own delivery it arrived a turn behind the mutator's.
    func test_setParagraphStyleDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "plain")], caret: 2) { editor.setParagraphStyle(.heading1) }, 1)
    }

    func test_setListDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "plain")], caret: 2) { editor.setList(.bullet) }, 1)
    }

    func test_setAlignmentDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "plain")], caret: 2) { editor.setAlignment(.center) }, 1)
    }

    func test_indentAndOutdentEachDeliverOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "item", list: bullet)], caret: 2) { editor.indent() }, 1)
        XCTAssertEqual(deliveries(seeding: [para("p0", "item", list: bullet)], caret: 2) { editor.outdent() }, 1)
    }

    // MARK: - Media (R7-media)

    private func photoItem(_ id: String) -> MediaItem { MediaItem(mediaID: id, kind: .image, naturalSize: Size2D(width: 1000, height: 500)) }
    private func photo(_ id: String, _ caption: String = "") -> Block {
        .media(MediaBlock(id: BlockID(id), items: [photoItem("m-\(id)")], caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }

    func test_insertMediaDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "text")], caret: 4) {
            editor.insertMedia(mediaID: "new", naturalSize: CGSize(width: 800, height: 600), kind: .image, caption: [])
        }, 1)
    }

    func test_deleteMediaBlockDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "text"), photo("a", "cap")], caret: 4) {
            editor.deleteMediaBlock(id: BlockID("a"))
        }, 1)
    }

    func test_aSpoilerToggleDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [photo("a", "cap")], caret: 0) {
            editor.toggleMediaSpoiler(blockID: BlockID("a"), itemIndex: nil)
        }, 1)
    }

    /// Engine axis of `[para("p0","text"), photo("a","cap")]` is `"text\n▣\ncap"`: the atom is at
    /// offset 5 (block 5..6), so the caret after it is 6 and the atom's own range is `(5, 1)`. The
    /// composer axis cannot address either, so the caret is seeded on the engine axis, BEFORE the
    /// drain (ruling 9) — setting it inside `act` would count the caret move's own selection-driven
    /// delivery against the edit.
    func test_theSecondDeletionStepDeliversOnce() {
        XCTAssertLessThanOrEqual(engineDeliveries(seeding: [para("p0", "text"), photo("a", "cap")],
                                                  engineCaret: NSRange(location: 6, length: 0)) {
            editor.engine.deleteBackward()
        }, 1, "selecting the atom is a caret move; a caret move's own selection-driven delivery is today's behaviour, not this rung's")
        XCTAssertEqual(engineDeliveries(seeding: [para("p0", "text"), photo("a", "cap")],
                                        engineCaret: NSRange(location: 5, length: 1)) {
            editor.engine.deleteBackward()
        }, 1)
    }

    private func album(_ id: String, _ count: Int) -> Block {
        .media(MediaBlock(id: BlockID(id), items: (1...count).map { MediaItem(mediaID: "\(id)-\($0)", kind: .image, naturalSize: Size2D(width: 1000, height: 500)) },
                          caption: [TextRun(text: "cap")]))
    }

    func test_insertDocumentDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "text")], caret: 4) {
            editor.insertDocument(Document(blocks: [album("al", 2)]))
        }, 1)
    }

    func test_addMediaItemDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [photo("a", "cap")], caret: 0) {
            editor.addMediaItem(blockID: BlockID("a"), mediaID: "b", naturalSize: CGSize(width: 10, height: 10), kind: .video)
        }, 1)
    }

    func test_toggleMediaDisplayModeDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [album("a", 2)], caret: 0) {
            editor.toggleMediaDisplayMode(blockID: BlockID("a"))
        }, 1)
    }

    func test_deleteMediaItemDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [album("a", 2)], caret: 0) {
            editor.deleteMediaItem(blockID: BlockID("a"), itemIndex: 0)
        }, 1)
    }

    /// `insertMedia` over a NON-EMPTY selection is two edits — the selection delete through the
    /// gate, then the insert — and they must still deliver ONE notification between them. The
    /// selection is seeded on the ENGINE axis BEFORE the drain (ruling 9): set inside `act`, the
    /// selection change's own delivery would be counted against the command.
    func test_insertMediaOverASelectionDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [para("p0", "hello world")],
                                        engineCaret: NSRange(location: 5, length: 6)) {
            editor.insertMedia(mediaID: "new", naturalSize: CGSize(width: 800, height: 600), kind: .image, caption: [])
        }, 1)
    }

    /// `[photo("a","cap")]` alone is `"▣\ncap"`: offset 0 is before the atom, the gap text lands in.
    func test_typingAtTheGapDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [photo("a", "cap")], engineCaret: NSRange(location: 0, length: 0)) {
            editor.engine.insertText("x")
        }, 1)
    }

    // MARK: - The quote exits (nesting design §6.2)

    private func quote(_ id: String, _ children: [Block]) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children))
    }

    /// The LIFT is a role-only change (`performHostStructuralChange`), whose whole reason for
    /// existing is that a structural change without an edit reached no settle and no delivery. It
    /// sets no caret, deliberately: a caret set after that frame's own flush schedules a second
    /// delivery a run-loop turn later, which is how every paragraph mutator used to fire twice.
    func test_backspaceLiftingAQuotesFirstChildDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [quote("q", [para("a", "one"),
                                                              quote("q2", [para("b", "two"), para("c", "three")])])],
                                        engineCaret: NSRange(location: 4, length: 0)) {
            editor.engine.deleteBackward()
        }, 1)
    }

    /// The UNWRAP is an edit (it removes the quote's author line) whose caret restore sits INSIDE
    /// the frame for the same reason.
    func test_backspaceUnwrappingALoneQuoteChildDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [quote("q", [para("a", "one"),
                                                              quote("q2", [para("b", "two")]),
                                                              para("c", "three")])],
                                        engineCaret: NSRange(location: 4, length: 0)) {
            editor.engine.deleteBackward()
        }, 1)
    }

    /// Removing an EMPTY first child is a plan-carrying edit with the caret set after it — safe
    /// only because the edit's notification is still owed at that point, so the caret's own
    /// schedule declines rather than adding a second.
    func test_backspaceRemovingAnEmptyFirstQuoteChildDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [quote("q", [quote("q2", [para("b", ""), para("c", "three")])])],
                                        engineCaret: NSRange(location: 0, length: 0)) {
            editor.engine.deleteBackward()
        }, 1)
    }

    /// And the boundary rule's nested empty-block removal, which became an edit in the same change.
    func test_backspaceRemovingAnEmptyBlockAfterANestedQuoteDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [quote("q", [quote("q2", [para("b", "two")]), para("c", "")])],
                                        engineCaret: NSRange(location: 5, length: 0)) {
            editor.engine.deleteBackward()
        }, 1)
    }

    private func rangeReplace(_ range: NSRange, _ text: String) {
        guard let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: range.location),
              let end = editor.engine.position(from: start, offset: range.length),
              let textRange = editor.engine.textRange(from: start, to: end) else { return XCTFail("no range") }
        editor.engine.replace(textRange, withText: text)
    }

    /// The empty-container dissolve reached through the gate's RANGE door. The rule itself notifies
    /// nothing — the veto path settles and delivers for it — so a delivery left inside the shared rule
    /// would land beside that one and read as 2.
    func test_theRangeDoorDissolveOfAWhollyEmptyQuoteDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [quote("q", [para("a", ""), para("b", ""), para("c", "")])],
                                        engineCaret: NSRange(location: 1, length: 0)) {
            rangeReplace(NSRange(location: 0, length: 1), "")
        }, 1)
    }

    /// And its CONTAINER arm, whose `document =` set the `isApplyingHostDocument` guard swallows: the
    /// veto path delivers only because the rule marks structure touched, so without that mark this
    /// reads 0 rather than 2.
    func test_theRangeDoorDissolveOfAnEmptyCodeBlockDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: []))],
                                        engineCaret: NSRange(location: 6, length: 0)) {
            rangeReplace(NSRange(location: 5, length: 1), "")
        }, 1)
    }

    /// The BOUNDARY rule reached through the gate's RANGE door, which R7-details added as its fifth.
    /// Same contract as the two dissolves above and the same failure mode: the rule delivered for
    /// itself while it had one door, and at the gate that delivery lands beside the veto path's.
    ///
    /// The structural arm — an empty paragraph after a container is REMOVED — is the one that reads
    /// 2, and its first delivery is also PRE-SETTLE: the rule's `performHostStructuralEdit`
    /// degenerates to a bare body at the gate, so a consumer reading `document` from it sees a
    /// document `normalisePresentation` has not touched yet.
    func test_theRangeDoorBoundaryRemovalOfAnEmptyBlockAfterACodeBlockDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [.code(CodeBlock(id: BlockID("c"), language: "swift",
                                                                  runs: [TextRun(text: "x")])),
                                                  para("p", "")],
                                        engineCaret: NSRange(location: 8, length: 0)) {
            rangeReplace(NSRange(location: 7, length: 1), "")
        }, 1)
    }

    /// And the WALL arm, which issues no edit at all and only moves the caret.
    ///
    /// This one does NOT pin the defect its sibling above does, and could not: the wall arm never
    /// sets `structureTouchedThisEdit`, so the gate's veto path never delivered for it, and before
    /// the delivery moved out of the rule its synchronous flush simply cancelled the queued
    /// selection-driven one — 1 either way. It guards the other direction, a future ZERO, which is
    /// the live risk now that this arm's notification comes from the caret's own selection change a
    /// run-loop turn later rather than from the rule itself.
    func test_theRangeDoorBoundaryWallAfterACodeBlockDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [.code(CodeBlock(id: BlockID("c"), language: "swift",
                                                                  runs: [TextRun(text: "x")])),
                                                  para("p", "text")],
                                        engineCaret: NSRange(location: 8, length: 0)) {
            rangeReplace(NSRange(location: 7, length: 1), "")
        }, 1)
    }

    // MARK: - The Quote toggle commands (nesting design §8)

    /// The selection is seeded on the ENGINE axis BEFORE the drain (ruling 9): setting it inside
    /// `act` would count the selection's own selection-driven delivery against the edit, so a
    /// command that delivered NOTHING would still read 1 — the shape that cannot fail for the mode
    /// it is meant to pin. That shape is pinned separately, below.
    func test_wrapInBlockQuoteDeliversOnce() {
        XCTAssertEqual(engineDeliveries(seeding: [para("p0", "one"), para("p1", "two")],
                                        engineCaret: NSRange(location: 0, length: 7)) {
            editor.wrapInBlockQuote()
        }, 1)
    }

    func test_quoteToggledOffDeliversOnce() {
        let quoted = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [para("p0", "one"), para("p1", "two")]))
        XCTAssertEqual(deliveries(seeding: [quoted], caret: 0) { editor.wrapInBlockQuote() }, 1)
    }

    func test_unwrapBlockQuoteLevelDeliversOnce() {
        let quoted = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [para("p0", "one")]))
        XCTAssertEqual(deliveries(seeding: [quoted], caret: 0) { editor.unwrapBlockQuoteLevel() }, 1)
    }

    // MARK: - A selection change immediately before the command, in the same run-loop turn
    //
    // Production reaches this shape: `RichTextAttachmentScreen.focusEditorAtDocumentEndIfNeeded`
    // moves the caret right before dispatching a Format-menu action, in the same turn. That
    // selection change schedules its OWN coalesced fallback (`scheduleSelectionDrivenOnChange`)
    // before the command below ever runs; the command's own synchronous delivery must absorb it
    // (see `isSelectionOnChangeScheduled`'s doc comment) or the pair delivers `onChange` twice for
    // one edit. Each case sets the selection to a REAL range INSIDE the counted window, immediately
    // before calling the command — deliberately the shape `test_wrapInBlockQuoteDeliversOnce` used
    // to have, and moved here once that test's own trap (it cannot fail for the mode it is meant to
    // pin) was found.

    func test_wrapInBlockQuoteAfterASelectionChangeInTheSameTurnDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "one"), para("p1", "two")], caret: 0) {
            editor.engineSelectedRange = NSRange(location: 0, length: 7)
            editor.wrapInBlockQuote()
        }, 1)
    }

    func test_quoteToggledOffAfterASelectionChangeInTheSameTurnDeliversOnce() {
        let quoted = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [para("p0", "one"), para("p1", "two")]))
        XCTAssertEqual(deliveries(seeding: [quoted], caret: 0) {
            editor.engineSelectedRange = NSRange(location: 0, length: 3)
            editor.wrapInBlockQuote()
        }, 1)
    }

    func test_unwrapBlockQuoteLevelAfterASelectionChangeInTheSameTurnDeliversOnce() {
        let quoted = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [para("p0", "one")]))
        XCTAssertEqual(deliveries(seeding: [quoted], caret: 0) {
            editor.engineSelectedRange = NSRange(location: 0, length: 3)
            editor.unwrapBlockQuoteLevel()
        }, 1)
    }

    /// One of the five paragraph mutators, standing for all of them (they share
    /// `deliveringOneChangeNotification`): the funnel fix is general, not quote-specific.
    func test_setListAfterASelectionChangeInTheSameTurnDeliversOnce() {
        XCTAssertEqual(deliveries(seeding: [para("p0", "plain")], caret: 0) {
            editor.engineSelectedRange = NSRange(location: 0, length: 5)
            editor.setList(.bullet)
        }, 1)
    }

    /// Reading the toolbar's traits must not schedule work that reads them again.
    ///
    /// The engine answers a trait for its CURRENT selection, so asking about each cell of a
    /// structural selection means parking the selection there and putting it back. Each park reached
    /// the selection funnel, which schedules a host `onChange`; the article host answers one by
    /// re-running its component update, which asks for the traits — which parked the selection
    /// again. A structural selection therefore left the editor in a run-loop-cadence LOOP, and
    /// scrolling the table fought it for the main thread (K3, 2026-09-11: "scrolling a table lags a
    /// lot"). Counted over a window rather than waited for, like everything else in this file.
    func test_readingTheToolbarsTraitsOverAStructuralSelectionSchedulesNothing() {
        var table = TableBlock.empty(rows: 2, columns: 3)
        table.id = BlockID("t")
        for row in 0..<2 {
            for column in 0..<3 {
                table.rows[row].cells[column].blocks = [para("c\(row)\(column)", "text")]
            }
        }
        editor.document = Document(blocks: [.table(table)])
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 0), length: 0)
        editor.selectTableRows(0...0)
        turn()   // drain what the selection itself scheduled

        var calls = 0
        editor.onChange = { calls += 1 }
        for _ in 0..<5 { _ = editor.currentInlineTraits() }   // the host, five updates over
        turn()
        editor.onChange = nil
        XCTAssertEqual(calls, 0, "the probe reported its own parked selections as changes")
        XCTAssertNotNil(editor.tableStructuralSelection, "and it put the selection back")
    }

    /// The other half: the answer is cached, so a host that asks on every update pays once. The probe
    /// parks the selection once per cell per ask, and `setSelectedTextRange:` runs UIKit's whole
    /// selection-change coordination each time.
    func test_theToolbarsTraitsAreComputedOncePerChange() {
        var table = TableBlock.empty(rows: 2, columns: 3)
        table.id = BlockID("t")
        for row in 0..<2 {
            for column in 0..<3 {
                table.rows[row].cells[column].blocks = [para("c\(row)\(column)", "text")]
            }
        }
        editor.document = Document(blocks: [.table(table)])
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 0), length: 0)
        editor.selectTableRows(0...0)
        turn()

        _ = editor.currentInlineTraits()
        XCTAssertNotNil(editor.cachedStructuralTraits, "the first ask computes it")
        let cached = editor.cachedStructuralTraits
        _ = editor.currentInlineTraits()
        XCTAssertEqual(editor.cachedStructuralTraits?.bold, cached?.bold, "the second reads it")
        // Anything that can change the answer drops it.
        editor.selectTableRows(0...1)
        XCTAssertNil(editor.cachedStructuralTraits, "a new selection means new traits")
    }
}
