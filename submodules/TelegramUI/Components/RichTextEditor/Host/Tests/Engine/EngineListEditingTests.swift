import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The two ways OUT of a list, neither of which existed on this rung.
///
/// A list item is a paragraph wearing a `ListMembership`, so both exits just take the membership
/// off — which is why their absence looked like nothing at all rather than like a broken feature.
/// Measured before the fix (device report, 2026-09-04): Backspace at the start of the FIRST item did
/// nothing whatsoever, because the engine merges a block into the one before it and the first block
/// has none — the bullet could not be removed and the item could not be deleted. Backspace at the
/// start of any other item silently dragged its text into the item above. Return on an empty item
/// made another empty item, for ever.
@available(iOS 18.4, *)
final class EngineListEditingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    private func item(_ id: String, _ text: String, _ marker: ListMarker = .bullet, level: Int = 0) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), list: ListMembership(marker: marker, level: level),
                                  runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func load(_ blocks: [Block], caret: Int) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: caret, length: 0)
    }
    private func texts() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    /// Each block's list membership as `marker@level`, or `-` for a plain paragraph.
    private func lists() -> [String] {
        editor.currentRoles.map { role in
            role.shape.paragraph?.list.map { "\($0.marker)@\($0.level)" } ?? "-"
        }
    }

    // MARK: - Backspace at the start of an item

    /// The reported bug. Nothing precedes the first item, so the engine's merge had nothing to do
    /// and the item was stuck: un-listable, undeletable.
    func test_backspaceAtTheStartOfTheOnlyItemEndsTheList() {
        load([item("a", "abc")], caret: 0)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["abc"], "the text is kept")
        XCTAssertEqual(lists(), ["-"], "and it is no longer a list item")
    }

    /// …and once it is an ordinary paragraph it deletes like one, which is what "cannot delete the
    /// first item" actually meant.
    func test_andThenItsTextDeletesNormally() {
        load([item("a", "a")], caret: 1)
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["-"])
        editor.engineSelectedRange = NSRange(location: 1, length: 0)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), [""], "the character is gone; nothing is stuck")
    }

    func test_backspaceInAnEmptyOnlyItemEndsTheList() {
        load([item("a", "")], caret: 0)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["-"])
    }

    /// The item's text is NOT dragged into the item above — that merge is what the rule replaces.
    func test_backspaceAtTheStartOfALaterItemEndsTheListWithoutMerging() {
        load([item("a", "abc"), item("b", "def")], caret: 4)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["abc", "def"], "still two blocks — nothing merged")
        XCTAssertEqual(lists(), ["bullet@0", "-"], "the second stopped being an item; the first did not")
    }

    /// A nested item outdents one level first, so Backspace walks it out rather than jumping.
    func test_backspaceAtTheStartOfANestedItemOutdentsIt() {
        load([item("a", "abc"), item("b", "def", level: 2)], caret: 4)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@1"], "one level, not out of the list")
        XCTAssertEqual(texts(), ["abc", "def"])
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@0"])
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "-"], "and only then out")
    }

    /// A list item after a plain paragraph ends its list rather than merging into the paragraph.
    func test_backspaceAtAnItemAfterAParagraphDoesNotMergeIntoIt() {
        load([para("p", "before"), item("a", "abc")], caret: 7)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["before", "abc"])
        XCTAssertEqual(lists(), ["-", "-"])
    }

    /// Backspace mid-text is untouched by any of this.
    func test_backspaceInsideAnItemsTextStillDeletesACharacter() {
        load([item("a", "abc")], caret: 2)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["ac"])
        XCTAssertEqual(lists(), ["bullet@0"], "still a list item")
    }

    func test_endingAListWithBackspaceIsUndoable() {
        load([item("a", "abc")], caret: 0)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["-"])
        editor.engine.undoManager?.undo(); turn()
        XCTAssertEqual(lists(), ["bullet@0"], "undo puts the bullet back")
        XCTAssertEqual(texts(), ["abc"])
    }

    // MARK: - The level is TWO things, and both must move

    private func textIndent(_ index: Int) -> CGFloat {
        let block = editor.engine.attributedBlocks[index]
        guard block.length > 0,
              let style = block.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        else { return -1 }
        return style.firstLineHeadIndent
    }
    private func markerX(_ id: String) -> CGFloat? {
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        return editor.listMarkerViews[BlockID(id)]?.frame.minX
    }

    /// A list level is the BULLET's position and the TEXT's indent. The marker is a host view read
    /// from the role, so it follows a role change at once; the indent lives in the block's
    /// `NSParagraphStyle` inside the engine's own text and does not. Outdenting moved the bullet and
    /// left the text where it was (device, 2026-09-05) — the two are asserted together here so they
    /// cannot drift apart again.
    func test_outdentingMovesTheTextsIndentAndNotOnlyTheBullet() {
        load([item("a", "one"), item("b", "two", .bullet, level: 2)], caret: 4)
        let seededIndent = textIndent(1), seededMarker = markerX("b")
        editor.indent(); turn()   // level 3 — the path that always worked
        let deeperIndent = textIndent(1), deeperMarker = markerX("b")
        XCTAssertGreaterThan(deeperIndent, seededIndent, "Tab moves the text")
        XCTAssertGreaterThan(deeperMarker ?? 0, seededMarker ?? 0, "and the bullet")

        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.engine.deleteBackward(); turn()   // back to level 2, via the role-only rule
        XCTAssertEqual(textIndent(1), seededIndent, accuracy: 0.5,
                       "Backspace moves the text back too, not just the bullet")
        XCTAssertEqual(markerX("b") ?? -1, seededMarker ?? -2, accuracy: 0.5)
    }

    /// Ending a list takes the indent with it: otherwise the paragraph reads as still being an item,
    /// which is what "it just breaks the list, it keeps the item inset" described.
    func test_endingAListTakesTheIndentWithIt() {
        load([item("a", "one")], caret: 0)
        XCTAssertGreaterThan(textIndent(0), 0, "an item is indented to begin with")
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(lists(), ["-"])
        XCTAssertEqual(textIndent(0), 0, accuracy: 0.5, "and a plain paragraph is not")
    }

    /// Undo has to put BOTH back.
    func test_undoRestoresTheLevelAndTheIndentTogether() {
        load([item("a", "one"), item("b", "two", .bullet, level: 2)], caret: 4)
        let before = textIndent(1)
        editor.engine.deleteBackward(); turn()
        XCTAssertNotEqual(textIndent(1), before, accuracy: 0.5)
        editor.engine.undoManager?.undo(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@2"], "the level came back")
        XCTAssertEqual(textIndent(1), before, accuracy: 0.5, "and so did the indent")
    }

    /// Un-listing an item in the MIDDLE splits the list: the items around it stay items, and an
    /// ordered list numbers the two halves independently.
    func test_endingAListInTheMiddleSplitsIt() {
        load([item("a", "one", .ordered), item("b", "two", .ordered), item("c", "three", .ordered),
              item("d", "four", .ordered)], caret: 8)
        editor.engine.deleteBackward(); turn()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(lists(), ["ordered@0", "ordered@0", "-", "ordered@0"])
        XCTAssertEqual(textIndent(2), 0, accuracy: 0.5, "the split item is no longer indented")
        let labels = editor.listMarkerLabels()
        XCTAssertEqual([labels[BlockID("a")], labels[BlockID("b")]], ["1.", "2."], "the first half keeps counting")
        XCTAssertEqual(labels[BlockID("d")], "1.", "the second half starts over")
    }

    // MARK: - The other delivery shape

    /// UIKit delivers a Backspace at a block's start to a bare `UITextInput` either as a collapsed
    /// caret or as a RANGE covering the join with the block above, and the host view routes a
    /// non-empty selection to the GATE rather than to the caret handler. Both shapes are the same
    /// keystroke and must take the same rule: before this they diverged, and the range shape — the
    /// one a device actually produces — merged the item into the one above instead.
    func test_backspaceDeliveredAsTheJoinRangeOutdentsJustTheSame() {
        load([item("a", "abc"), item("b", "def", level: 1)], caret: 0)
        editor.engineSelectedRange = NSRange(location: 3, length: 1)   // the "\n" join
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["abc", "def"], "not merged")
        XCTAssertEqual(lists(), ["bullet@0", "bullet@0"], "outdented, exactly as the caret shape does")
    }

    func test_theJoinRangeEndsATopLevelItemJustTheSame() {
        load([item("a", "abc"), item("b", "def")], caret: 0)
        editor.engineSelectedRange = NSRange(location: 3, length: 1)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["abc", "def"])
        XCTAssertEqual(lists(), ["bullet@0", "-"])
    }

    /// A join range whose lower block is NOT a list item still merges — the rule is about list
    /// items, and nothing else changed.
    func test_theJoinRangeStillMergesTwoPlainParagraphs() {
        load([para("a", "abc"), para("b", "def")], caret: 0)
        editor.engineSelectedRange = NSRange(location: 3, length: 1)
        editor.engine.deleteBackward(); turn()
        XCTAssertEqual(texts(), ["abcdef"], "an ordinary merge, untouched")
    }

    // MARK: - Tab

    func test_tabIndentsAListItemAndShiftTabOutdentsIt() {
        load([item("a", "one"), item("b", "two")], caret: 5)
        guard let commands = editor.keyCommands, commands.count == 2 else {
            return XCTFail("expected Tab and Shift-Tab in a list, got \(editor.keyCommands?.count ?? 0)")
        }
        XCTAssertEqual(commands.map(\.input), ["\t", "\t"])
        XCTAssertEqual(commands.map(\.modifierFlags), [[], .shift])

        editor.indent(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@1"], "Tab adds a level")
        editor.outdent(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@0"], "Shift-Tab takes it away")
    }

    /// Tab belongs to the system anywhere else — binding it document-wide would swallow it in
    /// ordinary prose.
    func test_tabIsNotBoundOutsideAListOrATable() {
        load([para("p", "prose")], caret: 2)
        XCTAssertNil(editor.keyCommands)
    }

    /// Indenting is per-ITEM, so a selection spanning several indents all of them — that is what
    /// `indent()` already does, and Tab inherits it rather than reimplementing a caret-only version.
    func test_tabIndentsEveryItemASelectionTouches() {
        load([item("a", "one"), item("b", "two"), item("c", "three")], caret: 0)
        editor.engineSelectedRange = NSRange(location: 0, length: 9)   // "one\ntwo\nt"
        editor.indent(); turn()
        XCTAssertEqual(lists(), ["bullet@1", "bullet@1", "bullet@1"])
    }

    // MARK: - Return: the double-return escape, both ends

    func test_returnAtTheEndOfAnItemStillContinuesTheList() {
        load([item("a", "abc")], caret: 3)
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@0"], "one Return still makes another item")
    }

    /// BOTTOM: the second Return, on the empty item the first one made, ends the list — leaving a
    /// plain paragraph after it.
    func test_returnOnAnEmptyTrailingItemEndsTheList() {
        load([item("a", "abc")], caret: 3)
        editor.engine.insertText("\n"); turn()
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(texts(), ["abc", ""], "no third block was made")
        XCTAssertEqual(lists(), ["bullet@0", "-"], "the empty item became a plain paragraph")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
    }

    /// TOP: two Returns at the start of the first item leave a plain paragraph BEFORE the list, with
    /// the caret in it. The second Return acts on the item ABOVE the caret — the first Return left
    /// the caret on the content line, not on the empty item it created.
    func test_twoReturnsAtTheTopOfAListOpenALineAboveIt() {
        load([item("a", "abc")], caret: 0)
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@0"], "the first Return makes an empty item above")
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(texts(), ["", "abc"], "still two blocks")
        XCTAssertEqual(lists(), ["-", "bullet@0"], "the empty one became the paragraph before the list")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0), "caret in it")
    }

    /// The top rule is for the START of a list only: an empty item in the MIDDLE ends the list where
    /// it stands (the bottom rule), rather than reaching back and un-listing something above it.
    func test_anEmptyItemInTheMiddleEndsTheListWhereItStands() {
        load([item("a", "one"), item("b", ""), item("c", "two")], caret: 4)
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(texts(), ["one", "", "two"])
        XCTAssertEqual(lists(), ["bullet@0", "-", "bullet@0"])
    }

    func test_endingAListWithReturnIsUndoable() {
        load([item("a", "abc"), item("b", "")], caret: 4)
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(lists(), ["bullet@0", "-"])
        editor.engine.undoManager?.undo(); turn()
        XCTAssertEqual(lists(), ["bullet@0", "bullet@0"], "undo puts the item back")
    }

    /// Ending a list keeps the item's own kind and level information out of it — an ordered list's
    /// numbering picks up again for the items that are still items.
    func test_endingAnOrderedItemRenumbersTheRest() {
        load([item("a", "one", .ordered), item("b", "two", .ordered), item("c", "three", .ordered)],
             caret: 4)
        editor.engine.deleteBackward(); turn()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(lists(), ["ordered@0", "-", "ordered@0"])
        let labels = editor.listMarkerLabels()
        XCTAssertEqual(labels[BlockID("a")], "1.")
        XCTAssertEqual(labels[BlockID("c")], "1.", "the plain paragraph restarts the numbering")
    }
}
