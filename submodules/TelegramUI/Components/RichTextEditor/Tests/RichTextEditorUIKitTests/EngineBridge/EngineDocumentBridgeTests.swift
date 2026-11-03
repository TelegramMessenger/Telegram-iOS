#if canImport(UIKit)
import XCTest
@testable import RichTextEditorCore
@testable import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R2's gate: Document -> attributed -> Document round-trips predictably for paragraph documents.
///
/// It is NOT a strict identity: `AttributedStringMapper.characterAttributes(from:)` unconditionally
/// pins `CharacterAttributes.fontSize` to the rendered font's point size on every read-back (see
/// that function's doc comment — deliberate, load-bearing, kept as-is per Global Constraint 2). A
/// `fontSize: nil` run therefore comes back with an explicit size after ONE round trip. The
/// preservation tests below account for this by excluding `fontSize` from their comparison; the
/// idempotence test asserts the property that actually matters — that this normalization does not
/// keep drifting on repeated application.
///
/// Fix round 2: `document(fromAttributedBlocks:engineIdentifiers:reusingStructureOf:)` reuses whole
/// `ParagraphBlock`s (not just `BlockID`s) — paragraph `style`/`paragraph`/`list` are genuinely
/// unrecoverable from an attributed string, so the host must carry them across the round trip.
///
/// C1: that reuse is keyed on the ENGINE's own block identity (`NSUUID`), not on array position —
/// see the bridge's doc comment for the worked mid-document failure positional reuse produced. Every
/// fixture here therefore mints one `UUID` per fixture block and passes the identity table the real
/// view keeps (`RichTextEngineEditorView.structureByEngineIdentity`). `EngineEditorDocumentTests
/// .test_returnInTheMiddleOfADocumentKeepsTheFollowingBlocksOwnIdentityAndStructure` drives the same
/// rule end to end through a live engine.
@available(iOS 18.4, *)
final class EngineDocumentBridgeTests: XCTestCase {
    private let bridge = EngineDocumentBridge(mapper: AttributedStringMapper())

    private func paragraphs(_ texts: [String]) -> Document {
        Document(blocks: texts.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                      runs: text.isEmpty ? [] : [TextRun(text: text)]))
        })
    }

    /// Unwraps a paragraph-only document's blocks to the `[ParagraphBlock]` shape the identity table
    /// holds. Every fixture in this suite is paragraph-only by construction.
    private func paragraphBlocks(of document: Document) -> [ParagraphBlock] {
        document.blocks.map { block in
            guard case let .paragraph(p) = block else {
                fatalError("test fixture must be paragraph-only")
            }
            return p
        }
    }

    /// One engine identifier per block, in order — the shape `tgid_blockIdentifiers` returns.
    private func identifiers(_ count: Int) -> [UUID] { (0..<count).map { _ in UUID() } }

    /// The identity table the view owns: engine `NSUUID` -> the paragraph it last resolved to.
    private func table(_ ids: [UUID], _ blocks: [ParagraphBlock]) -> [UUID: Block] {
        Dictionary(uniqueKeysWithValues: zip(ids, blocks.map { Block.paragraph($0) }))
    }

    /// Round-trips a paragraph-only document through the bridge with every block's identity intact —
    /// i.e. the engine reporting the same blocks it was given, which is what a pure re-read is.
    private func roundTrip(_ document: Document,
                           through bridge: EngineDocumentBridge? = nil) -> Document {
        let bridge = bridge ?? self.bridge
        let previous = paragraphBlocks(of: document)
        let ids = identifiers(previous.count)
        return bridge.document(fromAttributedBlocks: bridge.attributedBlocks(for: document),
                               engineIdentifiers: ids,
                               reusingStructureOf: table(ids, previous))
    }

    /// Compares two documents on every field EXCEPT `CharacterAttributes.fontSize`, which
    /// `AttributedStringMapper.characterAttributes(from:)` pins to the rendered font's point size on
    /// every read-back by design (see that function's doc comment) — so a `fontSize: nil` run does
    /// not survive a single round trip unchanged, even though everything else about it does.
    /// Nulling `fontSize` on both sides before a whole-struct `==` compares every OTHER
    /// `CharacterAttributes` field (bold, italic, underline, strikethrough, inlineCode, fontFamily,
    /// foreground, highlight, link, baselineOffset, emoji, formula, button, spoiler) without having
    /// to enumerate them by hand and risk missing one if a field is added later.
    private func assertRoundTripsExceptFontSize(_ lhs: Document, _ rhs: Document,
                                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.schemaVersion, rhs.schemaVersion, file: file, line: line)
        XCTAssertEqual(lhs.layoutDirection, rhs.layoutDirection, file: file, line: line)
        XCTAssertEqual(lhs.blocks.count, rhs.blocks.count, file: file, line: line)
        for (l, r) in zip(lhs.blocks, rhs.blocks) {
            guard case let .paragraph(lp) = l, case let .paragraph(rp) = r else {
                XCTFail("expected only paragraph blocks", file: file, line: line)
                continue
            }
            XCTAssertEqual(lp.id, rp.id, file: file, line: line)
            XCTAssertEqual(lp.style, rp.style, file: file, line: line)
            XCTAssertEqual(lp.paragraph, rp.paragraph, file: file, line: line)
            XCTAssertEqual(lp.list, rp.list, file: file, line: line)
            XCTAssertEqual(lp.runs.count, rp.runs.count, file: file, line: line)
            for (lRun, rRun) in zip(lp.runs, rp.runs) {
                XCTAssertEqual(lRun.text, rRun.text, file: file, line: line)
                var lAttrs = lRun.attributes; lAttrs.fontSize = nil
                var rAttrs = rRun.attributes; rAttrs.fontSize = nil
                XCTAssertEqual(lAttrs, rAttrs, file: file, line: line)
            }
        }
    }

    func test_roundTripPreservesPlainParagraphs() {
        let original = paragraphs(["alpha", "beta", "gamma"])
        assertRoundTripsExceptFontSize(roundTrip(original), original)
    }

    func test_roundTripPreservesAnEmptyParagraph() {
        let original = paragraphs(["alpha", "", "gamma"])
        assertRoundTripsExceptFontSize(roundTrip(original), original)
    }

    func test_roundTripPreservesBoldRuns() {
        var attributes = CharacterAttributes.plain
        attributes.bold = true
        let original = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"),
            runs: [TextRun(text: "plain "), TextRun(text: "bold", attributes: attributes)]))])
        assertRoundTripsExceptFontSize(roundTrip(original), original)
    }

    /// Fix round 2, CRITICAL: `style`/`paragraph`/`list` are genuinely unrecoverable from an
    /// attributed string — `attributedString(for:)` only CONSUMES them to build an `NSParagraphStyle`
    /// rendering artifact. Without this test the other preservation tests are vacuous on exactly
    /// these fields, since their fixtures are all default-valued (default-compares-equal-to-default
    /// proves nothing). This one uses a heading style, a non-natural alignment, and list membership —
    /// all non-default — and proves all three survive.
    func test_roundTripPreservesParagraphStructure() {
        var paragraphAttributes = ParagraphAttributes.default
        paragraphAttributes.alignment = .center
        let list = ListMembership(marker: .bullet, level: 1)
        let original = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"),
            style: .heading1,
            paragraph: paragraphAttributes,
            list: list,
            runs: [TextRun(text: "heading text")]))])
        guard case let .paragraph(backParagraph) = roundTrip(original).blocks.first else {
            return XCTFail("expected one paragraph block")
        }
        XCTAssertEqual(backParagraph.style, .heading1)
        XCTAssertEqual(backParagraph.paragraph, paragraphAttributes)
        XCTAssertEqual(backParagraph.list, list)
    }

    /// Fix round 2: the SECOND bug the structure fix touches. `runs(from:style:)` feeds `style` into
    /// `AttributedStringMapper`'s `boldIsAmbient` comparison base. A heading's ambient weight/family
    /// (serif + medium by default, vs. body's sans + regular) must not be misread as an explicit
    /// user `bold` — which it would risk being if the bridge read the run back at the wrong
    /// (default `.body`) style instead of the heading's own. Would have been invisible forever: a
    /// vacuous structure test would never catch it, since it is about a CHARACTER attribute, not a
    /// paragraph one.
    func test_aHeadingRoundTripsWithoutAcquiringExplicitBold() {
        let original = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), style: .heading1, runs: [TextRun(text: "Heading")]))])
        guard case let .paragraph(backParagraph) = roundTrip(original).blocks.first else {
            return XCTFail("expected one paragraph block")
        }
        XCTAssertEqual(backParagraph.runs.count, 1)
        XCTAssertFalse(backParagraph.runs[0].attributes.bold,
                       "the heading's ambient weight was misclassified as an explicit user bold")
    }

    /// The `style:` argument's REAL gate. `test_aHeadingRoundTripsWithoutAcquiringExplicitBold`
    /// above cannot exercise it and never could: `heading1` is serif at `.medium`, which
    /// `FontResolver` produces as a WEIGHT rather than the `.traitBold` symbolic trait, so
    /// `AttributedStringMapper`'s `boldIsAmbient` is never reached and the `style:` argument is
    /// never consulted. Deleting `style:` from the `runs(from:)` call left every test on this branch
    /// green — which is the definition of an unguarded lever.
    ///
    /// `style:` drives a second consumer that IS reachable with an ordinary fixture: the per-style
    /// default-foreground stripping (`characterAttributes(from:style:)` — "a foreground equal to the
    /// theme's per-style default is the render-injected default -> treat as unset"). A `.caption`
    /// run's default is `theme.secondaryText`; every other style's is `theme.primaryText`. Read a
    /// caption back at the WRONG style and its injected default no longer matches the comparison
    /// base, so it survives as an EXPLICIT colour in the model — silently un-themable from then on.
    ///
    /// The theme must be one where the two colours actually DIFFER: `RichTextEditorTheme.default`
    /// sets both to `.black`, so on the stock theme the wrong style still strips and this test would
    /// be as vacuous as the heading one. That is the anti-vacuity assertion at the top.
    func test_aCaptionsDefaultForegroundIsStrippedOnlyWhenReadAtItsOwnStyle() {
        var theme = RichTextEditorTheme.default
        theme.primaryText = .black
        theme.secondaryText = .darkGray
        XCTAssertNotEqual(theme.primaryText.rgba, theme.secondaryText.rgba,
                          "the fixture theme does not distinguish the two per-style defaults, so "
                          + "this test could not tell a right style from a wrong one")
        let bridge = EngineDocumentBridge(mapper: AttributedStringMapper(theme: theme))

        let original = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), style: .caption, runs: [TextRun(text: "a caption")]))])
        guard case let .paragraph(back) = roundTrip(original, through: bridge).blocks.first else {
            return XCTFail("expected one paragraph block")
        }
        XCTAssertEqual(back.style, .caption)
        XCTAssertEqual(back.runs.count, 1)
        XCTAssertNil(back.runs[0].attributes.foreground,
                     "the caption's own default foreground round-tripped as an EXPLICIT colour — "
                     + "the run was read back at the wrong paragraph style, so the stripping "
                     + "compared against the wrong per-style default")
    }

    /// The positive control for the test above, and the reason it is not merely asserting a nil.
    /// Read the SAME caption back at `.body` — the default a dropped `style:` argument falls to —
    /// and the injected `secondaryText` must survive as an explicit foreground. Without this, a
    /// bridge that stripped every foreground unconditionally would also pass the test above.
    func test_readingACaptionAtTheWrongStyleLeavesAnExplicitForeground() {
        var theme = RichTextEditorTheme.default
        theme.primaryText = .black
        theme.secondaryText = .darkGray
        let mapper = AttributedStringMapper(theme: theme)
        let caption = ParagraphBlock(id: BlockID("p0"), style: .caption, runs: [TextRun(text: "a caption")])
        let rendered = mapper.attributedString(for: caption)
        let atBody = mapper.runs(from: rendered, style: .body)
        XCTAssertEqual(atBody.count, 1)
        XCTAssertEqual(atBody[0].attributes.foreground, theme.secondaryText.rgba,
                       "reading a caption at .body must NOT strip its foreground — if it does, the "
                       + "sibling test proves nothing about the style: argument")
    }

    /// The property that actually matters (coordinator ruling): first-pass normalization of
    /// `fontSize` is harmless, but DRIFT is not — a document that kept changing on every read-back
    /// would accumulate damage across an editing session. Apply the round trip twice and require the
    /// second application to be a full, unqualified no-op on the first application's result.
    ///
    /// The fixture carries several non-default CHARACTER attributes (bold, italic, foreground, link,
    /// spoiler — one run each, so the link's foreground-suppression doesn't mask another field) AND
    /// non-default PARAGRAPH structure (a heading style, a non-natural alignment, list membership),
    /// so the equality check has real content to lose if either round-trip direction is unstable.
    func test_theRoundTripDoesNotDriftOnRepeatedApplication() {
        var bold = CharacterAttributes.plain; bold.bold = true
        var italic = CharacterAttributes.plain; italic.italic = true
        var colored = CharacterAttributes.plain; colored.foreground = RGBAColor(red: 0.8, green: 0.1, blue: 0.1)
        var linked = CharacterAttributes.plain; linked.link = "https://example.com"
        var spoiler = CharacterAttributes.plain; spoiler.spoiler = true

        var paragraphAttributes = ParagraphAttributes.default
        paragraphAttributes.alignment = .center

        let original = Document(blocks: [
            .paragraph(ParagraphBlock(
                id: BlockID("p0"),
                style: .heading1,
                paragraph: paragraphAttributes,
                list: ListMembership(marker: .bullet, level: 1),
                runs: [
                    TextRun(text: "bold ", attributes: bold),
                    TextRun(text: "italic ", attributes: italic),
                    TextRun(text: "colored ", attributes: colored),
                    TextRun(text: "linked ", attributes: linked),
                    TextRun(text: "spoiler", attributes: spoiler),
                ])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [])),
        ])
        let a = roundTrip(original)
        let b = roundTrip(a)
        XCTAssertEqual(a, b)
    }

    /// A block carrying an identifier the table has seen keeps its `BlockID`; one carrying an
    /// identifier the engine minted this edit gets a fresh one. Under the old positional rule this
    /// read "index 0 is known, index 1 is past the end"; under identity it reads what it says.
    func test_aNewBlockGetsAFreshIDRatherThanCollidingWithAnExistingOne() {
        let attributes: [NSAttributedString.Key: Any] = [:]
        let known = UUID()
        let minted = UUID()
        let back = bridge.document(fromAttributedBlocks: [
            NSAttributedString(string: "alpha", attributes: attributes),
            NSAttributedString(string: "split", attributes: attributes),
        ], engineIdentifiers: [known, minted],
           reusingStructureOf: [known: .paragraph(ParagraphBlock(id: BlockID("p0"), runs: []))])
        XCTAssertEqual(back.blocks.count, 2)
        XCTAssertEqual(back.blocks[0].id, BlockID("p0"))
        XCTAssertNotEqual(back.blocks[1].id, BlockID("p0"), "the new block reused an existing BlockID")
    }

    /// C1's headline case, at the bridge's own level: the engine created a block in the MIDDLE, so
    /// the block after it keeps ITS OWN identifier — and therefore its own `BlockID` and heading
    /// structure. Positional reuse hands index 1 (the new blank line) the heading and index 2 a
    /// default body; identity cannot express that. The end-to-end form, driven through a live
    /// engine's Return handling, is `EngineEditorDocumentTests
    /// .test_returnInTheMiddleOfADocumentKeepsTheFollowingBlocksOwnIdentityAndStructure`.
    func test_aBlockCreatedInTheMiddleDoesNotStealTheFollowingBlocksStructure() {
        let uA = UUID(), uNew = UUID(), uB = UUID()
        let previous: [UUID: Block] = [
            uA: .paragraph(ParagraphBlock(id: BlockID("pA"), runs: [TextRun(text: "A")])),
            uB: .paragraph(ParagraphBlock(id: BlockID("pB"), style: .heading1, runs: [TextRun(text: "B")])),
        ]
        let back = bridge.document(fromAttributedBlocks: [
            NSAttributedString(string: "A"),
            NSAttributedString(string: ""),
            NSAttributedString(string: "B"),
        ], engineIdentifiers: [uA, uNew, uB], reusingStructureOf: previous)
        XCTAssertEqual(back.blocks.count, 3)
        guard case let .paragraph(first) = back.blocks[0],
              case let .paragraph(middle) = back.blocks[1],
              case let .paragraph(last) = back.blocks[2] else {
            return XCTFail("expected three paragraphs")
        }
        XCTAssertEqual(first.id, BlockID("pA"))
        XCTAssertEqual(first.style, .body)
        XCTAssertNotEqual(middle.id, BlockID("pB"), "the new middle block took the heading's identity")
        XCTAssertEqual(middle.style, .body, "the heading migrated onto the newly created blank line")
        XCTAssertEqual(last.id, BlockID("pB"), "the following block lost its own identity")
        XCTAssertEqual(last.style, .heading1, "the following block's heading was silently demoted")
    }

    /// IMPORTANT 2: the merge direction. The user can backspace across a paragraph boundary, merging
    /// several blocks into fewer — `blocks.count < previous.count`. Position 0 must keep ITS OWN
    /// identity and structure (not silently reset to defaults just because its neighbors vanished),
    /// and the surviving array must simply be shorter: the merged-away entries in `previous` are
    /// dropped without error (there is no crash to observe — the point is that the test runs at all).
    func test_fewerBlocksThanPreviousKeepsPositionZeroIdentityAndStructureAndDropsTheRest() {
        var paragraphAttributes = ParagraphAttributes.default
        paragraphAttributes.alignment = .right
        let list = ListMembership(marker: .ordered, level: 0)
        let original = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), style: .heading2, paragraph: paragraphAttributes,
                                      list: list, runs: [TextRun(text: "alpha")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "beta")])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "gamma")])),
        ])
        let previous = paragraphBlocks(of: original)
        let ids = identifiers(previous.count)
        // Simulate a backspace-merge: the engine now reports ONE block holding the concatenated
        // text, and — per `IDBlockDocument.m`'s three-span rule — that block keeps the FIRST
        // affected block's identifier.
        let merged = [NSAttributedString(string: "alphabetagamma")]
        let back = bridge.document(fromAttributedBlocks: merged,
                                   engineIdentifiers: [ids[0]],
                                   reusingStructureOf: table(ids, previous))
        XCTAssertEqual(back.blocks.count, 1)
        guard case let .paragraph(backParagraph) = back.blocks.first else {
            return XCTFail("expected one paragraph block")
        }
        XCTAssertEqual(backParagraph.id, BlockID("p0"))
        XCTAssertEqual(backParagraph.style, .heading2)
        XCTAssertEqual(backParagraph.paragraph, paragraphAttributes)
        XCTAssertEqual(backParagraph.list, list)
    }

    /// Global Constraint 6: a custom block must TRAP at R2, not vanish. A silent drop here would
    /// read as data loss the moment a user pastes a table. The trap itself is a `preconditionFailure`
    /// and cannot be caught in-process by XCTest (Ruling in the task brief's pre-flight), so it is not
    /// exercised here — see the doc comment on `EngineDocumentBridge.attributedBlocks(for:)`, and R7
    /// in the Host app for where the trap is actually exercised. This test only pins the paragraph-only
    /// case, which the trap's presence must not disturb.
    func test_paragraphOnlyDocumentsMapToOneBlockEach() {
        let document = paragraphs(["only paragraphs here"])
        XCTAssertEqual(bridge.attributedBlocks(for: document).count, 1)
    }
}
#endif
