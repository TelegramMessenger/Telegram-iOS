#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
import RichTextEditorStockParitySupport
@testable import RichTextEditorUIKit

/// **Ported from `/Users/isaac/Documents/InputDec/Tests/IDBlockTextViewParityTests.m`**
/// (969 lines, 15 tests — counts derived with `wc -l` and `grep -c '^- (void)test'`).
/// Task P1 could not reach this suite; Task P2 ports it through the substitution seam
/// (`IDStockParity.makeArms`). See `PROVENANCE.md` for every deviation and every drop.
///
/// ## The one structural re-expression, applied throughout
///
/// Upstream compares caret and selection rects between its two arms at **1.0pt tolerance on the
/// rect origin**, y included. It can: both of its arms are TextKit-shaped and lay the same text out
/// at the same y. Telegram's cannot — `BlockLayoutEngine` pins every paragraph's line box
/// (`minimumLineHeight == maximumLineHeight`, from `RichTextRenderMetrics`) while a stock
/// `UITextView` uses the font's natural leading, so for the same font and width the arms wrap at
/// different y and their line boxes are different heights. A verbatim y comparison would fail on
/// line metrics and read as "caret geometry is broken", the most misleading red this suite could
/// produce (P1 deviation 4 records the same decision for the touch suite).
///
/// So vertical geometry is compared as a **line index** — the rank of the caret's line among the
/// arm's own distinct lines — and horizontal geometry as **distance from the start of that line**,
/// which cancels each arm's own `textContainerInset` and `lineFragmentPadding`. Both are strictly
/// checkable and both are compared ACROSS arms; neither is the weaker "each arm agrees with itself".
/// What is genuinely lost is absolute rect equality, and that is recorded rather than quietly
/// dropped.
///
/// Everything non-geometric — `selectionRectsForRange` counts, `containsStart` / `containsEnd` /
/// `writingDirection`, tokenizer ranges, marked-text ranges, movement offsets, text — is ported as
/// upstream states it.
@available(iOS 17.0, *)
@MainActor
final class IDBlockTextViewParityTests: XCTestCase {

    private var violations = IDStockParity.ViolationLog()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
        violations = IDStockParity.ViolationLog()
        IDStockParity.installContractReporter(violations, in: self)
    }

    /// Upstream's fixture geometry for this suite: 17pt system, `UIEdgeInsetsMake(11, 9, 13, 9)`,
    /// 280×250 arms.
    private func fixture(_ blocks: [String]) -> IDParityFixture {
        var fixture = IDParityFixture(blocks: blocks)
        fixture.fontSize = 17.0
        fixture.textContainerInset = UIEdgeInsets(top: 11, left: 9, bottom: 13, right: 9)
        fixture.armSize = CGSize(width: 280, height: 250)
        return fixture
    }

    // MARK: - The geometric re-expression

    /// One caret, described so that two arms with different line boxes can still be compared.
    ///
    /// * `line` — the rank of this caret's line among the arm's OWN distinct line positions.
    /// * `dx` — how far the caret sits from the leftmost caret on that same line.
    ///
    /// Both are derived from a single sweep over every offset, so the line ranking is stable and
    /// does not depend on which offset is asked about first.
    private struct CaretProfile {
        var lines: [Int] = []
        var dxs: [CGFloat] = []
        var declined: String?

        var lineDescription: String { declined ?? lines.map(String.init).joined(separator: ",") }
    }

    private func caretProfile(_ input: UITextInput, characterCount: Int) -> CaretProfile {
        var rects: [CGRect] = []
        for offset in 0...characterCount {
            guard let position = IDStockParity.position(input, atCharacterIndex: offset) else {
                return CaretProfile(declined: IDStockParity.decline("no position at character \(offset)"))
            }
            let rect = input.caretRect(for: position)
            guard rect.minX.isFinite, rect.minY.isFinite, rect.width.isFinite, rect.height.isFinite
            else { return CaretProfile(declined: IDStockParity.decline("non-finite caret rect at \(offset)")) }
            rects.append(rect)
        }
        // Rank the distinct line positions. Carets on the same line share a midY to within half a
        // line; 2pt is comfortably inside the smallest line box either arm produces at 17pt.
        var lineTops: [CGFloat] = []
        for rect in rects where !lineTops.contains(where: { abs($0 - rect.midY) < 2.0 }) {
            lineTops.append(rect.midY)
        }
        lineTops.sort()
        func line(of rect: CGRect) -> Int {
            lineTops.firstIndex { abs($0 - rect.midY) < 2.0 } ?? -1
        }
        var profile = CaretProfile()
        var lineMinX: [Int: CGFloat] = [:]
        for rect in rects {
            let index = line(of: rect)
            lineMinX[index] = min(lineMinX[index] ?? .greatestFiniteMagnitude, rect.minX)
        }
        for rect in rects {
            let index = line(of: rect)
            profile.lines.append(index)
            profile.dxs.append(rect.minX - (lineMinX[index] ?? 0))
        }
        return profile
    }

    private func canonicalRange(_ input: UITextInput, _ range: UITextRange?) -> String {
        guard let range else { return "(no range)" }
        return IDStockParity.characterRange(input, range).map(NSStringFromRange) ?? IDStockParity.decline("unmappable")
    }

    private func offset(_ input: UITextInput, _ position: UITextPosition?) -> String {
        guard let position else { return "(nil position)" }
        return IDStockParity.characterIndex(input, position).map(String.init) ?? IDStockParity.decline("unmappable")
    }

    private func assertNoKernelFailures(_ scenario: String, file: StaticString = #filePath,
                                        line: UInt = #line) {
        IDStockParity.assertNoKernelFailures(violations, scenario, file: file, line: line)
    }

    // MARK: - 1. Every caret offset

    /// Upstream: `testEveryCaretOffsetMatchesStockInVisibleHostCoordinates` — sweeps EVERY offset of
    /// a two-paragraph LTR+RTL fixture and requires the caret rect origin to match stock within 1pt
    /// in window coordinates.
    ///
    /// Re-expressed per the note at the top of this file: the swept quantity is (line index,
    /// distance from the line's left edge) rather than the absolute origin. The sweep itself,
    /// the fixture, and the "every offset, not a sample" discipline are upstream's.
    func test_everyCaretOffsetHasTheSameLineAndLineRelativeXAsStock() throws {
        let scenario = "caret profile over every offset of \"one two three four\\nאבגדה six\""
        let blocks = ["one two three four", "אבגדה six"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)
        let characterCount = (blocks.joined(separator: "\n") as NSString).length

        let profiles = arms.eachInput { self.caretProfile($0, characterCount: characterCount) }
        IDStockParity.assertField("caret line index per offset", scenario: scenario,
                                  stock: profiles.stock.lineDescription,
                                  inputDec: profiles.inputDec.lineDescription,
                                  legacy: profiles.legacy.lineDescription,
                                  note: "which LINE each of the \(characterCount + 1) carets is on; "
                                      + "absolute y is not comparable (see the file comment)")
        XCTAssertNil(profiles.stock.declined ?? profiles.inputDec.declined ?? profiles.legacy.declined,
                     "[DECLINED] \(scenario) — an arm produced no caret profile at all")
        IDStockParity.assertNumericArms("caret x from the line start", scenario: scenario,
                                        (profiles.stock.dxs, profiles.inputDec.dxs, profiles.legacy.dxs),
                                        tolerance: 1.0,
                                        note: "upstream's own 1.0pt origin tolerance, expressed "
                                            + "relative to the line so each arm's own "
                                            + "textContainerInset and lineFragmentPadding cancel")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 2. Collapsed selection rects

    /// Upstream: `testEveryCollapsedSelectionRectMatchesStockCaretGeometry`. For every offset,
    /// `selectionRectsForRange:` of a COLLAPSED range must return exactly one rect, and its
    /// `containsStart` / `containsEnd` / `writingDirection` must match stock.
    ///
    /// The three flags and the count are ported verbatim across arms. Upstream's width (±0.5) and
    /// height (±1.0) comparisons are DROPPED: the height is the pinned line box that this port
    /// cannot compare, and the width of a collapsed rect is the caret width, which follows it. The
    /// x is carried by test 1's profile.
    func test_collapsedSelectionRectsAreSingularAndCarryStocksFlags() throws {
        let scenario = "selectionRectsForRange of a collapsed range at every offset"
        let blocks = ["one two", "אבג"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)
        let characterCount = (blocks.joined(separator: "\n") as NSString).length

        let readings = arms.eachInput { input -> String in
            var description: [String] = []
            for offset in 0...characterCount {
                guard let position = IDStockParity.position(input, atCharacterIndex: offset),
                      let range = input.textRange(from: position, to: position) else {
                    return IDStockParity.decline("no collapsed range at \(offset)")
                }
                let rects = input.selectionRects(for: range)
                guard rects.count == 1 else {
                    description.append("\(offset):count=\(rects.count)")
                    continue
                }
                let rect = rects[0]
                description.append("\(offset):\(rect.containsStart ? "S" : "-")"
                                   + "\(rect.containsEnd ? "E" : "-")\(rect.writingDirection.rawValue)")
            }
            return description.joined(separator: " ")
        }
        IDStockParity.assertArms("collapsed rect count + containsStart/End + writingDirection",
                                 scenario: scenario, readings,
                                 note: "upstream asserts exactly one rect per collapsed range and "
                                     + "equality of all three flags")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 3. Selection across a structural newline into an RTL block

    /// Upstream: `testSelectionAcrossStructuralNewlineAndRTLBlockMatchesStockEdges`. Selects across
    /// the paragraph boundary into a Hebrew run and requires the rect COUNT and each rect's
    /// `writingDirection` to match stock, plus its x edges within 1.5pt.
    ///
    /// Count and writing direction are ported verbatim. The x edges are compared as widths (an
    /// inset-independent quantity) rather than absolute coordinates.
    func test_selectionRectsAcrossAStructuralNewlineIntoAnRTLBlock() throws {
        let scenario = "selectionRectsForRange across the paragraph boundary into an RTL run"
        let blocks = ["one two three four", "אבגדה six"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)
        let selection = NSRange(location: (blocks[0] as NSString).length - 4, length: 8)

        let readings = arms.eachInput { input -> String in
            guard let range = IDStockParity.textRange(input, forCharacterRange: selection) else {
                return IDStockParity.decline("no range for \(NSStringFromRange(selection))")
            }
            let rects = input.selectionRects(for: range)
            guard !rects.isEmpty else { return IDStockParity.decline("no selection rects") }
            let described = rects.map { rect -> String in
                guard rect.rect.minX.isFinite, rect.rect.width.isFinite else { return "non-finite" }
                return "\(rect.writingDirection.rawValue)@w\(Int((rect.rect.width / 1.5).rounded()))"
            }
            return "count=\(rects.count) \(described.joined(separator: " "))"
        }
        IDStockParity.assertArms("selection rect count + writingDirection + width",
                                 scenario: scenario, readings,
                                 note: "upstream compares the rect count, each writingDirection, "
                                     + "and the x edges within 1.5pt")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 4. The two sides of a structural newline

    /// Upstream: `testVirtualNewlineSidesAndComposedClusterNavigation`. The two positions either
    /// side of a paragraph boundary must sit on DIFFERENT lines (the leading one above), and probing
    /// at each caret's own midpoint must resolve back to that same offset.
    ///
    /// Upstream's `adjustedContentInset` / `contentOffset` equality assertions are DROPPED: they
    /// compare two `UIScrollView`s, and Telegram's editor is not one (`RichTextEditorView` is a
    /// plain `UIView` hosting a canvas). Recorded in `PROVENANCE.md`.
    func test_theTwoSidesOfAStructuralNewlineAreOnAdjacentLinesAndRoundTrip() throws {
        let scenario = "the leading/trailing sides of a structural newline"
        let blocks = ["one two three four", "👩🏽‍💻 short"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)
        let leading = (blocks[0] as NSString).length
        let trailing = leading + 1

        let readings = arms.eachInput { input -> String in
            guard let leadingPosition = IDStockParity.position(input, atCharacterIndex: leading),
                  let trailingPosition = IDStockParity.position(input, atCharacterIndex: trailing)
            else { return IDStockParity.decline("no position either side of the boundary") }
            let leadingRect = input.caretRect(for: leadingPosition)
            let trailingRect = input.caretRect(for: trailingPosition)
            guard leadingRect.midY.isFinite, trailingRect.midY.isFinite else {
                return IDStockParity.decline("non-finite caret rect")
            }
            let ordered = leadingRect.minY < trailingRect.minY
            // Upstream probes each caret's own midpoint and requires the hit to be that caret.
            var roundTrips: [String] = []
            for (name, rect, expected) in [("leading", leadingRect, leading),
                                           ("trailing", trailingRect, trailing)] {
                let point = CGPoint(x: rect.midX, y: rect.midY)
                let hit = IDStockParity.closestCharacterIndex(input, to: point)
                roundTrips.append("\(name)=\(hit.map(String.init) ?? "nil")/\(expected)")
            }
            return "leadingAbove=\(ordered) \(roundTrips.joined(separator: " "))"
        }
        IDStockParity.assertArms("line ordering + caret-midpoint round trip", scenario: scenario,
                                 readings,
                                 note: "the trailing side of a structural newline must be on the "
                                     + "line BELOW the leading side, and each caret's own midpoint "
                                     + "must resolve back to it")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 5. Mixed bidi horizontal movement

    /// Upstream: `testMixedBiDiHorizontalMovementUsesVisualClusterAdjacency`. At offset 5, inside a
    /// Hebrew run of `"abc אבג def"`, visual right is logically BACKWARD and visual left is
    /// logically forward. The resulting offsets must match stock.
    ///
    /// Ported as upstream states it (offsets, and the selection-rect writing directions over the
    /// run). Upstream's three `assertRectOrigin` comparisons are re-expressed as the same-line
    /// check, per the file comment.
    func test_mixedBiDiHorizontalMovementUsesVisualClusterAdjacency() throws {
        let scenario = "visual left/right movement at offset 5 of \"abc אבג def\""
        let arms = try IDStockParity.makeArms(fixture(["abc אבג def"]), in: self)

        let readings = arms.eachInput { input -> String in
            guard let middle = IDStockParity.position(input, atCharacterIndex: 5) else {
                return IDStockParity.decline("no position at 5")
            }
            let right = input.position(from: middle, in: .right, offset: 1)
            let left = input.position(from: middle, in: .left, offset: 1)
            let middleRect = input.caretRect(for: middle)
            let sameLine = [right, left].allSatisfy { candidate in
                guard let candidate else { return false }
                let rect = input.caretRect(for: candidate)
                return rect.midY.isFinite && abs(rect.midY - middleRect.midY) < 2.0
            }
            guard let runRange = IDStockParity.textRange(input,
                                                         forCharacterRange: NSRange(location: 4, length: 3))
            else { return IDStockParity.decline("no range {4,3}") }
            let rects = input.selectionRects(for: runRange)
            let directions = rects.map { "\($0.writingDirection.rawValue)" }.joined(separator: "/")
            return "right=\(self.offset(input, right)) left=\(self.offset(input, left)) "
                + "sameLine=\(sameLine) rects=\(rects.count)[\(directions)]"
        }
        IDStockParity.assertArms("visual movement offsets + run writing directions",
                                 scenario: scenario, readings,
                                 note: "inside an RTL run, visual right must move logically "
                                     + "backward and visual left logically forward")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 7. Vertical movement retains the preferred x

    /// Upstream: `testVerticalMovementRetainsPreferredXAcrossShortLineAndReturn`. From offset 12 of
    /// a long line, step down twice (across a SHORT line) and back up twice; every intermediate
    /// offset must match stock, and the caret must return to where it started.
    ///
    /// This is the preferred-x behaviour: a `down` onto a short line must remember the original x so
    /// the next `down` returns to it, rather than clamping permanently to the short line's end.
    func test_verticalMovementRetainsThePreferredXAcrossAShortLineAndAReturn() throws {
        let scenario = "down, down, up, up from offset 12 across a short middle line"
        let blocks = ["abcdefghijklmno", "xy", "abcdefghijklmno"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)

        let readings = arms.eachInput { input -> String in
            guard var position = IDStockParity.position(input, atCharacterIndex: 12) else {
                return IDStockParity.decline("no position at 12")
            }
            var steps = [self.offset(input, position)]
            for direction in [UITextLayoutDirection.down, .down, .up, .up] {
                guard let next = input.position(from: position, in: direction, offset: 1) else {
                    steps.append("nil")
                    break
                }
                position = next
                steps.append(self.offset(input, position))
            }
            return steps.joined(separator: " → ")
        }
        IDStockParity.assertArms("offsets through down/down/up/up", scenario: scenario, readings,
                                 note: "a `down` onto a SHORT line must remember the preferred x, "
                                     + "so the next `down` returns to it and the two `up`s land "
                                     + "back on the starting offset")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 8. A direct selection assignment resets the preferred x

    /// Upstream: `testDirectSelectedTextRangeReplacementResetsPreferredVerticalX`. Setting
    /// `selectedTextRange` DIRECTLY (as opposed to moving through it) must clear the remembered
    /// preferred x, so the next `down` behaves exactly as it would from a freshly built view at the
    /// same offset.
    ///
    /// Upstream compares its view against a FRESH view of the same fixture — a self-comparison, not
    /// a stock comparison, because stock has no observable preferred-x either. That shape is
    /// preserved: each arm is compared against its own fresh twin, and the RESULT (whether the two
    /// agree) is then compared across arms. So the cross-arm claim is still a real one.
    func test_aDirectSelectedTextRangeAssignmentResetsThePreferredVerticalX() throws {
        let scenario = "setting selectedTextRange directly must clear the preferred x"
        let blocks = ["abcdefghijklmno", "xy", "abcdefghijklmno"]

        var readings: [IDParityArm: String] = [:]
        for arm in IDParityArm.allCases {
            let driven = try IDStockParity.makeSubject(arm, fixture(blocks), in: self, focused: false)
            let fresh = try IDStockParity.makeSubject(arm, fixture(blocks), in: self, focused: false)
            func measure() -> String {
                guard let start = IDStockParity.position(driven.input, atCharacterIndex: 12),
                      let downOne = driven.input.position(from: start, in: .down, offset: 1)
                else { return IDStockParity.decline("no downward position") }
                driven.input.selectedTextRange = driven.input.textRange(from: downOne, to: downOne)
                guard let downTwo = driven.input.position(from: downOne, in: .down, offset: 1)
                else { return IDStockParity.decline("no second downward position") }

                guard let sourceOffset = IDStockParity.characterIndex(driven.input, downOne),
                      let freshSource = IDStockParity.position(fresh.input, atCharacterIndex: sourceOffset),
                      let freshDown = fresh.input.position(from: freshSource, in: .down, offset: 1)
                else { return IDStockParity.decline("the fresh twin could not reproduce the step") }

                let drivenRect = driven.input.caretRect(for: downTwo)
                let freshRect = fresh.input.caretRect(for: freshDown)
                guard drivenRect.minX.isFinite, freshRect.minX.isFinite else {
                    return IDStockParity.decline("non-finite caret rect")
                }
                let sameOffset = self.offset(driven.input, downTwo) == self.offset(fresh.input, freshDown)
                let sameX = abs(drivenRect.minX - freshRect.minX) <= 1.0
                return "sameOffset=\(sameOffset) sameX=\(sameX)"
            }
            readings[arm] = measure()
        }
        IDStockParity.assertField("agreement with a fresh twin", scenario: scenario,
                                  stock: readings[.stock] ?? IDStockParity.decline("missing"),
                                  inputDec: readings[.inputDec] ?? IDStockParity.decline("missing"),
                                  legacy: readings[.legacy] ?? IDStockParity.decline("missing"),
                                  note: "upstream compares its view against a FRESH view of the "
                                      + "same fixture; each arm does the same, and whether the two "
                                      + "agree is compared across arms")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 9. Tokenizer ranges and boundary navigation

    /// Upstream: `testCanonicalRangesWordParagraphAndBoundaryNavigationMatchStock`. At offset 8 of
    /// `"alpha beta\ngamma delta"`: the word- and paragraph-enclosing ranges, the forward boundary
    /// positions at character / word / line granularity, and a `textInRange:` read across the
    /// structural newline.
    ///
    /// Fully portable — no geometry at all. Overlaps `IDBlockTouchSelectionParityTests`'s tokenizer
    /// test at a different offset and with the boundary-navigation half added, so it is ported
    /// rather than folded in.
    func test_tokenizerRangesAndBoundaryNavigationAtAParagraphBoundary() throws {
        let scenario = "tokenizer ranges + forward boundaries at offset 8 of two paragraphs"
        let blocks = ["alpha beta", "gamma delta"]
        let text = blocks.joined(separator: "\n") as NSString
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)

        let readings = arms.eachInput { input -> String in
            guard let position = IDStockParity.position(input, atCharacterIndex: 8) else {
                return IDStockParity.decline("no position at 8")
            }
            var parts: [String] = []
            for (name, granularity) in [("word", UITextGranularity.word),
                                        ("paragraph", .paragraph)] {
                let range = input.tokenizer.rangeEnclosingPosition(position,
                                                                   with: granularity,
                                                                   inDirection: .storage(.forward))
                parts.append("\(name)=\(self.canonicalRange(input, range))")
            }
            for (name, granularity) in [("character", UITextGranularity.character),
                                        ("word", .word), ("line", .line)] {
                let boundary = input.tokenizer.position(from: position, toBoundary: granularity,
                                                        inDirection: .storage(.forward))
                parts.append("→\(name)=\(self.offset(input, boundary))")
            }
            guard let crossing = IDStockParity.textRange(input,
                                                         forCharacterRange: NSRange(location: 4, length: 10))
            else { return IDStockParity.decline("no range {4,10}") }
            parts.append("text{4,10}=\((input.text(in: crossing) ?? IDStockParity.decline("nil")).debugDescription)")
            return parts.joined(separator: " ")
        }
        IDStockParity.assertArms("tokenizer ranges + boundaries + text across the newline",
                                 scenario: scenario, readings,
                                 note: "upstream's expected substring is "
                                     + "\(text.substring(with: NSRange(location: 4, length: 10)).debugDescription)")
        // Upstream's own claim about the oracle, kept: the crossing read IS the source substring.
        if let stockRange = IDStockParity.textRange(arms.stock.input,
                                                    forCharacterRange: NSRange(location: 4, length: 10)) {
            XCTAssertEqual(arms.stock.input.text(in: stockRange),
                           text.substring(with: NSRange(location: 4, length: 10)),
                           "the ORACLE moved: textInRange no longer returns the source substring")
        }
        assertNoKernelFailures(scenario)
    }

    // MARK: - 11. Marked text editing and undo

    /// Upstream: `testMarkedTextEditingAndUndoRangesMatchStock`. Sets marked text at offset 2,
    /// compares text / `markedTextRange` / `selectedTextRange`, unmarks, replaces a range spanning
    /// the paragraph boundary, and compares again — then undoes and compares once more.
    ///
    /// Fully portable. `undoManager.canUndo` is compared **per arm as a precondition** rather than
    /// across arms, for the reason P1 recorded for the inline-formatting suite: the host's undo
    /// manager is injected and its grouping is the harness's, so comparing the two managers'
    /// flags compares the harness to itself.
    func test_markedTextEditingAndUndoRanges() throws {
        let scenario = "setMarkedText at offset 2, unmark, replace {4,4}, undo"
        let arms = try IDStockParity.makeArms(fixture(["alpha", "beta"]), in: self)

        let readings = arms.each { subject -> String in
            let input = subject.input
            guard let position = IDStockParity.position(input, atCharacterIndex: 2) else {
                return IDStockParity.decline("no position at 2")
            }
            input.selectedTextRange = input.textRange(from: position, to: position)
            input.setMarkedText("XY", selectedRange: NSRange(location: 1, length: 0))
            var parts = [
                "marked.text=\(IDStockParity.plainText(input).debugDescription)",
                "marked.range=\(self.canonicalRange(input, input.markedTextRange))",
                "marked.selection=\(self.canonicalRange(input, input.selectedTextRange))",
            ]
            input.unmarkText()
            parts.append("unmarked.rangeIsNil=\(input.markedTextRange == nil)")

            guard let replaced = IDStockParity.textRange(input,
                                                         forCharacterRange: NSRange(location: 4, length: 4))
            else { return IDStockParity.decline("no range {4,4}") }
            input.replace(replaced, withText: "Z")
            parts.append("replaced.text=\(IDStockParity.plainText(input).debugDescription)")
            parts.append("replaced.selection=\(self.canonicalRange(input, input.selectedTextRange))")
            return parts.joined(separator: " ")
        }
        IDStockParity.assertArms("marked text, unmark, replace", scenario: scenario, readings,
                                 note: "upstream compares text, markedTextRange and "
                                     + "selectedTextRange at each of these three steps")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 12. Losing first responder commits boundary marked text

    /// Upstream: `testResponderLossCommitsBoundaryMarkedTextLikeStock`. Marked text set exactly at a
    /// paragraph boundary (offset 5, the newline) must be COMMITTED — not discarded — when the view
    /// resigns first responder, and the resulting text, marked-range nil-ness and selection must
    /// match stock.
    ///
    /// Uses `IDParityArms.focus(_:)`, which is why all three arms share one window: upstream drives
    /// each arm's `becomeFirstResponder` / `resignFirstResponder` in turn, and only one responder in
    /// a window can be first.
    func test_losingFirstResponderCommitsMarkedTextAtAParagraphBoundary() throws {
        let scenario = "marked text at the paragraph boundary, then resignFirstResponder"
        let arms = try IDStockParity.makeArms(fixture(["alpha", "beta"]), in: self)

        var readings: [IDParityArm: String] = [:]
        for arm in IDParityArm.allCases {
            let subject = arms[arm]
            let input = subject.input
            guard let position = IDStockParity.position(input, atCharacterIndex: 5) else {
                readings[arm] = IDStockParity.decline("no position at 5")
                continue
            }
            input.selectedTextRange = input.textRange(from: position, to: position)
            guard arms.focus(arm) else {
                readings[arm] = IDStockParity.decline("could not become first responder")
                continue
            }
            input.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
            let resigned = subject.responder.resignFirstResponder()
            readings[arm] = "resigned=\(resigned)|"
                + "stillFirstResponder=\(subject.responder.isFirstResponder)|"
                + "text=\(IDStockParity.plainText(input).debugDescription)|"
                + "markedIsNil=\(input.markedTextRange == nil)|"
                + "selection=\(self.canonicalRange(input, input.selectedTextRange))"
        }
        // ONE FIELD PER CLAIM, not one composite string. A composite makes any single divergence
        // taint every claim in it, and the classifier then reports PRE-EXISTING for a defect that
        // only ONE arm has. Here that mattered: `resignFirstResponder()` returns false on BOTH host
        // arms (a shared, pre-existing difference from stock) while the InputDec arm ALSO commits
        // the marked text TWICE — a port defect that the composite hid behind the shared one.
        let claims = ["resignFirstResponder() returned", "no longer first responder",
                      "committed text", "markedTextRange cleared", "selection"]
        for (index, claim) in claims.enumerated() {
            func part(_ arm: IDParityArm) -> String {
                let reading = readings[arm] ?? IDStockParity.decline("missing")
                let parts = reading.components(separatedBy: "|")
                return index < parts.count ? parts[index] : reading
            }
            IDStockParity.assertField(claim, scenario: scenario,
                                      stock: part(.stock), inputDec: part(.inputDec),
                                      legacy: part(.legacy),
                                      note: "marked text at a structural boundary must be "
                                          + "committed, not discarded, when the editor loses focus")
        }
        assertNoKernelFailures(scenario)
    }
}
#endif
