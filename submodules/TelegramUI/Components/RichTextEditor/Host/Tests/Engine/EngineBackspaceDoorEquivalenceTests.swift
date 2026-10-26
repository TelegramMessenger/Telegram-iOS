import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// ONE Backspace, two deliveries, one document.
///
/// UIKit delivers a Backspace at a block's start either as a collapsed caret there or as the RANGE
/// covering the join with the block above, and which one a device chooses is not ours to predict.
/// Every rule for that position therefore has two doors — and while the ORDER lived in two
/// hand-written lists (one in `tgid_deleteBackwardHandler`, one in `decideTextInput`) the two
/// drifted three separate times:
///
/// * the boundary WALL reached the caret door only, so the same keystroke walled through one door
///   and MERGED a details' first body child into its title through the other;
/// * the details-title rule was asked fifth at the gate and sixth at the caret door;
/// * the dissolve was gated on the join at the gate and on nothing at the caret door.
///
/// Each was found on a device, one at a time, because nothing anywhere compared the two doors. This
/// suite is that comparison: for every rule in `backspaceJoinRules`, the same document and the same
/// keystroke through both doors must produce the same roles, the same text and the same caret.
///
/// **A passing run here is only worth what the instrument can fail on** — see
/// `test_theHarnessCanSeeTheTwoDoorsDisagree`, which drives a keystroke whose two deliveries are
/// genuinely different and checks that this comparison reports it.
@available(iOS 18.4, *)
final class EngineBackspaceDoorEquivalenceTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    // MARK: - Fixtures

    private func para(_ id: String, _ text: String, list: ListMembership? = nil) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), list: list, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block]) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, author: []))
    }
    private func details(_ id: String, title: String, _ children: [Block]) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: title.isEmpty ? [] : [TextRun(text: title)],
                              children: children, expanded: true))
    }
    /// A 2x2 table whose cells all read "x" — four cell roles, so the block after it is role 4.
    private func grid(_ id: String) -> Block {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID(id)
        for r in 0..<2 {
            for c in 0..<2 { built.rows[r].cells[c].blocks = [para("\(id)-\(r)\(c)", "x")] }
        }
        return .table(built)
    }

    private func photo(_ id: String, _ caption: String = "") -> Block {
        .media(MediaBlock(id: BlockID(id),
                          items: [MediaItem(mediaID: "m-\(id)", kind: .image,
                                            naturalSize: Size2D(width: 1000, height: 500))],
                          caption: caption.isEmpty ? [] : [TextRun(text: caption)]))
    }
    /// A button row — the SECOND atom kind the three atom rules answer for since R9-buttons. One
    /// default pill, which is what `insertButtonRow` mints.
    private func row(_ id: String) -> Block {
        .buttonRow(ButtonRowBlock(id: BlockID(id), buttons: [ButtonRef(label: [], action: .url(""))]))
    }
    /// A FOLDED quote — the THIRD atom kind the three atom rules answer for since R7-collapse. Like
    /// a row it is captionless, so its unit is a single role.
    private func folded(_ id: String) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: [para("\(id)-body", "hidden")],
                               collapsed: true, author: []))
    }
    private var bullet: ListMembership { ListMembership(marker: .bullet, level: 1) }

    // MARK: - The comparison

    /// What a keystroke left behind. Roles AND text AND caret: a door that produces the right text
    /// with the wrong structure is the exact defect this exists to catch.
    private struct Outcome: Equatable, CustomStringConvertible {
        var roles: [String]
        var strings: [String]
        var caret: NSRange
        /// A rule may leave a table STRUCTURALLY selected, which is a second axis the document and the
        /// caret say nothing about — so the doors are compared on it too, or one could select and the
        /// other not while everything else matched.
        var structural: String
        var description: String {
            "\n  roles=\(roles)\n  strings=\(strings)\n  caret=\(caret)\n  structural=\(structural)"
        }
    }

    private func freshEditor(_ blocks: [Block]) {
        editor?.removeFromSuperview()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }

    private func outcome() -> Outcome {
        let roles = editor.currentRoles.map { role -> String in
            let kind: String
            if role.owningTable != nil { kind = "cell" }
            else if let secondary = role.secondaryKind { kind = "\(secondary)" }
            else {
                switch role.shape {
                case .media: kind = "media"
                case .buttonRow: kind = "buttonRow"
                case .code: kind = "code"
                case .pullQuote: kind = "pullQuote"
                case .collapsedQuote: kind = "collapsedQuote"
                case .paragraph: kind = "p"
                }
            }
            return "\(kind)@\(role.containerDepth)"
        }
        let structural = editor.tableStructuralSelection
            .map { "\($0.table.rawValue):\($0.kind)" } ?? "none"
        return Outcome(roles: roles,
                       strings: editor.engine.attributedBlocks.map(\.string),
                       caret: editor.engineSelectedRange,
                       structural: structural)
    }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

    /// Drives the SAME keystroke through both doors on a fresh copy of the same document.
    ///
    /// The caret door is a collapsed caret at the start of role `roleIndex`; the range door is the
    /// one-character range covering the join with the block above — the two shapes UIKit actually
    /// delivers. Both are settled a run-loop turn before being read, symmetrically, so neither is
    /// compared mid-flight.
    private func bothDoors(_ blocks: [Block], roleIndex: Int,
                           file: StaticString = #filePath, line: UInt = #line) -> (caret: Outcome, range: Outcome) {
        freshEditor(blocks)
        let offset = editor.flatOffset(ofRoleAt: roleIndex)
        XCTAssertGreaterThan(offset, 0, "role \(roleIndex) has no join above it to Backspace over",
                             file: file, line: line)
        editor.engineSelectedRange = NSRange(location: offset, length: 0)
        editor.engine.deleteBackward()
        turn()
        let viaCaret = outcome()

        freshEditor(blocks)
        // The selection MUST be on the join before the replace. UIKit always puts it there — the
        // range door IS a selection being replaced — and rules like `unwrapContainer` read
        // `engineSelectedRange` on entry to decide where the caret lands. Without this the door is
        // driven with whatever selection the document set left behind (its END), and all three
        // container rules "disagreed" across doors by exactly that: a harness artifact, not a defect.
        editor.engineSelectedRange = NSRange(location: offset - 1, length: 1)
        let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: offset - 1)!
        let end = editor.engine.position(from: start, offset: 1)!
        editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: "")
        turn()
        let viaRange = outcome()

        return (viaCaret, viaRange)
    }

    private func assertDoorsAgree(_ blocks: [Block], roleIndex: Int,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let both = bothDoors(blocks, roleIndex: roleIndex, file: file, line: line)
        XCTAssertEqual(both.caret, both.range,
                       "the two deliveries of one Backspace produced different documents",
                       file: file, line: line)
    }

    // MARK: - One case per rule in `backspaceJoinRules`

    func test_mediaCaptionRuleAgreesAcrossDoors() {
        assertDoorsAgree([para("p0", "one"), photo("m", "cap")], roleIndex: 2)
    }

    func test_beforeMediaAtomRuleAgreesAcrossDoors() {
        assertDoorsAgree([para("p0", "one"), photo("m", "cap")], roleIndex: 1)
    }

    func test_afterMediaUnitRuleAgreesAcrossDoors() {
        assertDoorsAgree([photo("m", "cap"), para("p1", "after")], roleIndex: 2)
    }

    func test_afterMediaUnitRuleAgreesAcrossDoors_whenTheBlockIsEmpty() {
        assertDoorsAgree([photo("m", "cap"), para("p1", "")], roleIndex: 2)
    }

    func test_beforeAtomUnitRuleAgreesAcrossDoorsForAButtonRow() {
        assertDoorsAgree([para("p0", "one"), row("r")], roleIndex: 1)
    }

    func test_afterAtomUnitRuleAgreesAcrossDoorsForAButtonRow() {
        assertDoorsAgree([row("r"), para("p1", "after")], roleIndex: 1)
    }

    /// The two atom kinds meet: a row whose previous block is a media atom, and the reverse. Since
    /// the three rules lost their kind these must behave identically through both doors.
    func test_theTwoAtomKindsAgreeAcrossDoorsWhenAdjacent() {
        assertDoorsAgree([photo("m", "cap"), row("r")], roleIndex: 2)
        assertDoorsAgree([row("r"), photo("m", "cap")], roleIndex: 1)
    }
    func test_beforeAtomUnitRuleAgreesAcrossDoorsForAFoldedQuote() {
        assertDoorsAgree([para("p0", "one"), folded("q")], roleIndex: 1)
    }
    func test_afterAtomUnitRuleAgreesAcrossDoorsForAFoldedQuote() {
        assertDoorsAgree([folded("q"), para("p1", "after")], roleIndex: 1)
    }
    func test_afterAtomUnitRuleAgreesAcrossDoorsForAFoldedQuote_whenTheBlockIsEmpty() {
        assertDoorsAgree([folded("q"), para("p1", "")], roleIndex: 1)
    }
    /// All THREE kinds now, in both orders each. The region-boundary wall answers `false` for a
    /// folded quote only because the atom rules claim the keystroke first, and a wall that reached
    /// one door only is the first of the three drifts this suite's header records.
    func test_theThreeAtomKindsAgreeAcrossDoorsWhenAdjacent() {
        assertDoorsAgree([folded("q"), photo("m", "cap")], roleIndex: 1)
        assertDoorsAgree([photo("m", "cap"), folded("q")], roleIndex: 2)
        assertDoorsAgree([folded("q"), row("r")], roleIndex: 1)
        assertDoorsAgree([row("r"), folded("q")], roleIndex: 1)
    }

    func test_dissolveEmptyContainerRuleAgreesAcrossDoors() {
        assertDoorsAgree([para("before", "x"), quote("q", [para("a", "")])], roleIndex: 1)
    }

    func test_listItemRuleAgreesAcrossDoors() {
        assertDoorsAgree([para("p0", "first", list: bullet), para("p1", "second", list: bullet)], roleIndex: 1)
    }

    func test_quoteChildRuleAgreesAcrossDoors() {
        assertDoorsAgree([para("before", "x"), quote("q", [para("a", "one"), para("b", "two")])], roleIndex: 1)
    }

    func test_precedingTableRuleAgreesAcrossDoors() {
        assertDoorsAgree([grid("t"), para("p1", "after")], roleIndex: 4)
    }

    func test_precedingTableRuleAgreesAcrossDoors_whenTheParagraphIsEmpty() {
        assertDoorsAgree([grid("t"), para("p1", "")], roleIndex: 4)
    }

    func test_detailsTitleRuleAgreesAcrossDoors() {
        assertDoorsAgree([para("before", "x"), details("d", title: "Notes", [para("a", "one")])], roleIndex: 1)
    }

    func test_regionBoundaryRuleAgreesAcrossDoors() {
        assertDoorsAgree([details("d", title: "Notes", [para("a", "one")])], roleIndex: 1)
    }

    /// The boundary rule's other arm: the block AFTER a container travels rather than merging.
    func test_regionBoundaryAfterAQuoteAgreesAcrossDoors() {
        assertDoorsAgree([quote("q", [para("a", "one")]), para("after", "z")], roleIndex: 1)
    }

    // MARK: - The order is the array's, not a door's

    /// The details-title rule used to sit fifth at the gate and sixth at the caret door. The claim
    /// was that the difference is inert, because neither the list rule nor the quote-child rule can
    /// fire on a `.detailsTitle` role — but nothing measured it. This is the shape that would tell:
    /// a details whose title sits inside a quote, where BOTH orders have a candidate rule to reach.
    func test_aDetailsTitleInsideAQuoteTakesTheSameRuleThroughBothDoors() {
        assertDoorsAgree([para("before", "x"),
                          quote("q", [details("d", title: "Notes", [para("a", "one")])])],
                         roleIndex: 1)
    }

    // MARK: - Delivery is the DOOR's, and it happens exactly once

    /// Deliveries during the keystroke and the run-loop turn after it.
    ///
    /// Seeding the document and the caret is itself a change that schedules a delivery, so the setup
    /// is drained BEFORE the counter is installed — without that every case reads as one more than
    /// it is, whatever the code does. `EngineChangeNotificationCountTests` documents that trap at
    /// length; this is the same instrument pointed at the two doors.
    private func deliveries(_ blocks: [Block], roleIndex: Int, viaRangeDoor: Bool) -> Int {
        freshEditor(blocks)
        let offset = editor.flatOffset(ofRoleAt: roleIndex)
        editor.engineSelectedRange = viaRangeDoor
            ? NSRange(location: offset - 1, length: 1)
            : NSRange(location: offset, length: 0)
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        if viaRangeDoor {
            let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: offset - 1)!
            let end = editor.engine.position(from: start, offset: 1)!
            editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: "")
        } else {
            editor.engine.deleteBackward()
        }
        turn()
        editor.onChange = nil
        return calls
    }

    /// A rule reports whether it already reached the consumer (`BackspaceRuleOutcome`); the DOOR
    /// delivers when it did not — the caret door by flushing, the gate by marking
    /// `structureTouchedThisEdit` for its veto path. A delivery written into a RULE instead lands
    /// beside the door's, and the same keystroke notifies twice: measured at 2 on the boundary rule,
    /// which is why the contract is a return value now rather than a convention about which rules
    /// remember to flush.
    func test_everyBackspaceRuleDeliversExactlyOnceThroughEitherDoor() {
        let cases: [(name: String, blocks: [Block], roleIndex: Int)] = [
            ("mediaCaption", [para("p0", "one"), photo("m", "cap")], 2),
            ("beforeMediaAtom", [para("p0", "one"), photo("m", "cap")], 1),
            ("afterMediaUnit", [photo("m", "cap"), para("p1", "after")], 2),
            ("beforeAtomUnit/row", [para("p0", "one"), row("r")], 1),
            ("afterAtomUnit/row", [row("r"), para("p1", "after")], 1),
            ("dissolveEmptyContainer", [para("before", "x"), quote("q", [para("a", "")])], 1),
            ("listItem", [para("p0", "first", list: bullet), para("p1", "second", list: bullet)], 1),
            ("quoteChild", [para("before", "x"), quote("q", [para("a", "one"), para("b", "two")])], 1),
            ("detailsTitle", [para("before", "x"), details("d", title: "Notes", [para("a", "one")])], 1),
            ("regionBoundary", [details("d", title: "Notes", [para("a", "one")])], 1),
        ]
        for item in cases {
            XCTAssertEqual(deliveries(item.blocks, roleIndex: item.roleIndex, viaRangeDoor: false), 1,
                           "\(item.name), caret door")
            XCTAssertEqual(deliveries(item.blocks, roleIndex: item.roleIndex, viaRangeDoor: true), 1,
                           "\(item.name), range door")
        }
    }

    /// The counter must be able to report a number other than 1, or every assertion above is
    /// satisfied by an instrument that counts nothing.
    func test_theDeliveryCounterCanReportMoreThanOne() {
        freshEditor([para("p0", "one"), para("p1", "two")])
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        editor.engine.insertText("a")
        turn()
        editor.engine.insertText("b")
        turn()
        editor.onChange = nil
        XCTAssertEqual(calls, 2, "two edits, two deliveries — the counter is live")
    }

    // MARK: - Neuter: the comparison must be able to report a difference

    /// A matrix of `XCTAssertEqual`s that cannot fail proves nothing, and this suite's whole value is
    /// its ability to fail. A Backspace at the start of a plain paragraph after another plain
    /// paragraph is handled by NO rule in the table: the caret door returns false and the engine
    /// merges the two, while the range door falls through to `replaceAcrossBlocks`. Both are correct
    /// and they agree — so to prove the instrument can see a disagreement, compare two deliveries
    /// that are genuinely of DIFFERENT keystrokes and require the comparison to notice.
    func test_theHarnessCanSeeTheTwoDoorsDisagree() {
        freshEditor([para("p0", "one"), para("p1", "two")])
        let offset = editor.flatOffset(ofRoleAt: 1)
        editor.engineSelectedRange = NSRange(location: offset, length: 0)
        editor.engine.deleteBackward()
        turn()
        let afterABackspace = outcome()

        freshEditor([para("p0", "one"), para("p1", "two")])
        editor.engineSelectedRange = NSRange(location: offset, length: 0)
        editor.engine.insertText("Z")
        turn()
        let afterATypedCharacter = outcome()

        XCTAssertNotEqual(afterABackspace, afterATypedCharacter,
                          "the comparison reports nothing, so every agreement above is vacuous")
    }
}
