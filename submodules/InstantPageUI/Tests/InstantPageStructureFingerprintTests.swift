import XCTest
import TelegramCore
@testable import InstantPageUI

private func makePage(_ blocks: [InstantPageBlock]) -> InstantPage {
    return InstantPage(blocks: blocks, media: [:], isComplete: true, rtl: false, url: "", views: nil)
}

private func fingerprint(_ blocks: [InstantPageBlock]) -> Int {
    return instantPageStructureFingerprint(makePage(blocks))
}

private func makeCaption() -> InstantPageCaption {
    return InstantPageCaption(text: .empty, credit: .empty)
}

private func makeImage(id: Int64) -> InstantPageBlock {
    return .image(id: EngineMedia.Id(namespace: 0, id: id), caption: makeCaption(), url: nil, webpageId: nil, spoiler: false)
}

final class InstantPageStructureFingerprintTests: XCTestCase {
    // MARK: Identity changes must NOT move the fingerprint.
    //
    // These are the cases that keep the Local->Cloud send flip and the in-place toggles off the
    // crossfade path.

    /// Presentation payload — heading level, so `# H1` -> `## H2` stays same-content.
    func testHeadingLevelPreservesFingerprint() {
        XCTAssertEqual(
            fingerprint([.heading(text: .plain("t"), level: 1)]),
            fingerprint([.heading(text: .plain("t"), level: 3)])
        )
    }

    /// MediaIds are excluded, which is what keeps the Local->Cloud send flip off the crossfade path.
    func testMediaIdPreservesFingerprint() {
        XCTAssertEqual(fingerprint([makeImage(id: 1)]), fingerprint([makeImage(id: 999)]))
    }

    /// Optional VALUE is payload: ticking a checkbox must not dissolve the bubble.
    func testCheckboxValuePreservesFingerprint() {
        XCTAssertEqual(
            fingerprint([.list(items: [.text(.plain("t"), nil, false)], ordered: false)]),
            fingerprint([.list(items: [.text(.plain("t"), nil, true)], ordered: false)])
        )
    }

    /// `ordered` is a payload too — a bulleted list becoming numbered stays same-content.
    func testListOrderingPreservesFingerprint() {
        XCTAssertEqual(
            fingerprint([.list(items: [.text(.plain("t"), nil, nil)], ordered: false)]),
            fingerprint([.list(items: [.text(.plain("t"), nil, nil)], ordered: true)])
        )
    }

    /// `collapsed` and `expanded` have their own animations and must not trip a rebuild.
    func testQuoteCollapseAndDetailsExpansionPreserveFingerprint() {
        XCTAssertEqual(
            fingerprint([.blockQuote(blocks: [.paragraph(.plain("t"))], caption: .empty, collapsed: false)]),
            fingerprint([.blockQuote(blocks: [.paragraph(.plain("t"))], caption: .empty, collapsed: true)])
        )
        XCTAssertEqual(
            fingerprint([.details(title: .plain("t"), blocks: [.paragraph(.plain("b"))], expanded: false)]),
            fingerprint([.details(title: .plain("t"), blocks: [.paragraph(.plain("b"))], expanded: true)])
        )
    }

    /// The whole reason MediaIds are excluded: the send flip rewrites every id in the page,
    /// including the INLINE ones inside RichText, while nothing visible changes.
    func testInlineImageIdPreservesFingerprint() {
        func inlineImage(id: Int64) -> InstantPageBlock {
            return .paragraph(.concat([
                .plain("before"),
                .image(id: EngineMedia.Id(namespace: 0, id: id), dimensions: PixelDimensions(width: 10, height: 10)),
                .plain("after")
            ]))
        }
        XCTAssertEqual(fingerprint([inlineImage(id: 1)]), fingerprint([inlineImage(id: 999)]))
    }

    /// A custom emoji is keyed by its `alt`, not its `fileId` — same identity discipline.
    func testCustomEmojiFileIdPreservesFingerprint() {
        XCTAssertEqual(
            fingerprint([.paragraph(.textCustomEmoji(fileId: 1, alt: "🙂"))]),
            fingerprint([.paragraph(.textCustomEmoji(fileId: 999, alt: "🙂"))])
        )
    }

    /// `textDate` carries a model timestamp; the relative string is produced at layout time. The
    /// refresh timer re-lays-out from this same value, so it must never trip a dissolve.
    func testTextDateModelIsStableAcrossRefreshes() {
        XCTAssertEqual(
            fingerprint([.paragraph(.textDate(text: .plain("fallback"), date: 1_700_000_000, format: nil))]),
            fingerprint([.paragraph(.textDate(text: .plain("fallback"), date: 1_700_000_000, format: nil))])
        )
    }

    // MARK: Content changes MUST move the fingerprint.

    /// The headline case this reversal is for: an edit that rewrites words but keeps the shape.
    func testTextEditChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.paragraph(.plain("a"))]),
            fingerprint([.paragraph(.plain("completely different text"))])
        )
    }

    /// Case tags are hashed alongside the leaves, so wrapping a word in bold counts as a change.
    func testFormattingOnlyChangeChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.paragraph(.concat([.plain("a"), .plain("b")]))]),
            fingerprint([.paragraph(.concat([.plain("a"), .bold(.plain("b"))]))])
        )
    }

    /// A link whose label is unchanged but whose target moved is a content change.
    func testLinkUrlChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.paragraph(.url(text: .plain("here"), url: "https://a.example", webpageId: nil))]),
            fingerprint([.paragraph(.url(text: .plain("here"), url: "https://b.example", webpageId: nil))])
        )
    }

    /// Captions are user-visible text hanging off media blocks.
    func testCaptionEditChangesFingerprint() {
        func captioned(_ text: String) -> InstantPageBlock {
            return .image(
                id: EngineMedia.Id(namespace: 0, id: 1),
                caption: InstantPageCaption(text: .plain(text), credit: .empty),
                url: nil,
                webpageId: nil,
                spoiler: false
            )
        }
        XCTAssertNotEqual(fingerprint([captioned("first")]), fingerprint([captioned("second")]))
    }

    /// Table cells were previously counted but not read.
    func testTableCellTextChangesFingerprint() {
        func table(_ cellText: String) -> InstantPageBlock {
            let cell = InstantPageTableCell(text: .plain(cellText), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)
            return .table(title: .empty, rows: [InstantPageTableRow(cells: [cell])], bordered: false, striped: false, compact: false)
        }
        XCTAssertNotEqual(fingerprint([table("a")]), fingerprint([table("b")]))
    }

    /// Recursion must reach text nested inside containers, not just top-level blocks.
    func testNestedTextEditChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.details(title: .plain("t"), blocks: [.paragraph(.plain("a"))], expanded: true)]),
            fingerprint([.details(title: .plain("t"), blocks: [.paragraph(.plain("b"))], expanded: true)])
        )
    }

    /// A formula's latex source is its entire visible content and has no RichText to carry it.
    func testFormulaLatexChangesFingerprint() {
        XCTAssertNotEqual(fingerprint([.formula(latex: "x^2")]), fingerprint([.formula(latex: "x^3")]))
    }

    func testAddedBlockChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.paragraph(.plain("a"))]),
            fingerprint([.paragraph(.plain("a")), .paragraph(.plain("b"))])
        )
    }

    func testReorderedBlocksChangeFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.paragraph(.plain("a")), .divider]),
            fingerprint([.divider, .paragraph(.plain("a"))])
        )
    }

    /// The case the positional item-view reuse gets wrong: a block changing kind in place.
    func testParagraphBecomingHeadingChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.paragraph(.plain("t"))]),
            fingerprint([.heading(text: .plain("t"), level: 1)])
        )
    }

    func testAddedListItemChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.list(items: [.text(.plain("a"), nil, nil)], ordered: false)]),
            fingerprint([.list(items: [.text(.plain("a"), nil, nil), .text(.plain("b"), nil, nil)], ordered: false)])
        )
    }

    /// Optional PRESENCE is shape: a checkbox marker appearing is a real relayout.
    func testCheckboxPresenceChangesFingerprint() {
        XCTAssertNotEqual(
            fingerprint([.list(items: [.text(.plain("t"), nil, nil)], ordered: false)]),
            fingerprint([.list(items: [.text(.plain("t"), nil, false)], ordered: false)])
        )
    }

    /// Nesting must be unambiguous — a child count is emitted before each collection, so a block
    /// moving into or out of a container cannot collide with the flat arrangement.
    func testNestingIsUnambiguous() {
        XCTAssertNotEqual(
            fingerprint([.blockQuote(blocks: [.paragraph(.plain("a"))], caption: .empty, collapsed: nil), .paragraph(.plain("b"))]),
            fingerprint([.blockQuote(blocks: [.paragraph(.plain("a")), .paragraph(.plain("b"))], caption: .empty, collapsed: nil)])
        )
    }

    func testTableRowAndCellCountsChangeFingerprint() {
        let cell = InstantPageTableCell(text: .plain("c"), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)
        let oneRow = [InstantPageTableRow(cells: [cell])]
        let twoRows = [InstantPageTableRow(cells: [cell]), InstantPageTableRow(cells: [cell])]
        let wideRow = [InstantPageTableRow(cells: [cell, cell])]
        XCTAssertNotEqual(
            fingerprint([.table(title: .empty, rows: oneRow, bordered: false, striped: false, compact: false)]),
            fingerprint([.table(title: .empty, rows: twoRows, bordered: false, striped: false, compact: false)])
        )
        XCTAssertNotEqual(
            fingerprint([.table(title: .empty, rows: oneRow, bordered: false, striped: false, compact: false)]),
            fingerprint([.table(title: .empty, rows: wideRow, bordered: false, striped: false, compact: false)])
        )
    }

    /// `compact` is presentation payload, like `bordered`/`striped` — it must NOT perturb the
    /// structure fingerprint (which gates streaming re-reveal).
    func testTableCompactDoesNotChangeFingerprint() {
        let cell = InstantPageTableCell(text: .plain("c"), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)
        let rows = [InstantPageTableRow(cells: [cell])]
        XCTAssertEqual(
            fingerprint([.table(title: .empty, rows: rows, bordered: false, striped: false, compact: false)]),
            fingerprint([.table(title: .empty, rows: rows, bordered: false, striped: false, compact: true)])
        )
    }

    /// Recursion must reach nested containers, not stop at the top level.
    func testNestedBlockChangeIsDetected() {
        XCTAssertNotEqual(
            fingerprint([.details(title: .plain("t"), blocks: [.paragraph(.plain("a"))], expanded: true)]),
            fingerprint([.details(title: .plain("t"), blocks: [.paragraph(.plain("a")), .divider], expanded: true)])
        )
    }

    func testButtonCountChangesFingerprint() {
        let button = InstantPageButton(text: .plain("b"), action: .text, color: nil)
        XCTAssertNotEqual(
            fingerprint([.buttonRow(alignment: .justify, buttons: [button])]),
            fingerprint([.buttonRow(alignment: .justify, buttons: [button, button])])
        )
    }
}
